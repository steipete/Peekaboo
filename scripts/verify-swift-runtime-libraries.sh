#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNTIME_SDK_ARGS=()
AUDIT_RUNTIME_EXPORTS=true
RPATHS_ONLY=false
if [ "${1:-}" = --rpaths-only ]; then
    RPATHS_ONLY=true
    shift
fi
if [ "${1:-}" = --standalone ]; then
    AUDIT_RUNTIME_EXPORTS=false
    shift
fi
if [ "${1:-}" = --runtime-sdk-root ] && [ "$#" -ge 2 ]; then
    RUNTIME_SDK_ARGS=(--sdk-root "$2")
    shift 2
fi

if { [ "$RPATHS_ONLY" = true ] && [ "$#" -ne 1 ]; } ||
   { [ "$RPATHS_ONLY" = false ] && [ "$#" -ne 2 ]; }; then
    echo "Usage: $0 [--standalone] [--runtime-sdk-root DIR] <executable> <runtime-library-directory>" >&2
    echo "       $0 --rpaths-only <mach-o>" >&2
    exit 2
fi

EXECUTABLE_PATH="$1"
LIBRARY_DIR="${2:-}"
EXPECTED_IDENTITY="${MAC_RELEASE_CODESIGN_IDENTITY:-}"
EXPECTED_TEAM_ID="${MAC_RELEASE_CODESIGN_TEAM_ID:-}"

if [ ! -f "$EXECUTABLE_PATH" ] || { [ "$RPATHS_ONLY" = false ] && [ ! -x "$EXECUTABLE_PATH" ]; }; then
    echo "Executable missing or not executable: $EXECUTABLE_PATH" >&2
    exit 1
fi

read_rpaths() {
    awk '
        $1 == "cmd" && $2 == "LC_RPATH" { in_rpath = 1; next }
        in_rpath && $1 == "path" {
            sub(/^[[:space:]]*path /, ""); sub(/ \(offset [0-9]+\)$/, "")
            print; in_rpath = 0
        }
    '
}

verify_rpaths() {
    local binary="$1" architectures architecture load_commands rpath
    architectures=$(lipo -archs "$binary") || {
        echo "Unable to inspect Mach-O architectures: $binary" >&2
        return 1
    }
    for architecture in $architectures; do
        load_commands=$(otool -arch "$architecture" -l "$binary") || return 1
        while IFS= read -r rpath; do
            case "$rpath" in
                /*)
                    case "$rpath" in
                        */../*|*/..|*/./*|*/.) ;;
                        /usr/lib|/usr/lib/*) continue ;;
                    esac
                    echo "Non-system absolute LC_RPATH ($architecture): $rpath ($binary)" >&2
                    return 1
                    ;;
            esac
        done < <(read_rpaths <<< "$load_commands")
    done
}

# Audit every slice, even without compatibility imports, and never trust build-host search paths.
verify_rpaths "$EXECUTABLE_PATH"
if [ "$RPATHS_ONLY" = true ]; then
    exit 0
fi

# Standalone developer builds use their selected SDK; release callers retain
# older-runtime export certification by default. Loader checks always run.
if [ "$AUDIT_RUNTIME_EXPORTS" = true ]; then
    # An availability-qualified Swift Ref can still emit this strong runtime import.
    # The Span back-deployment library does not provide it; dyld fails before main on macOS 26 and earlier.
    undefined_symbols=$(nm -arch all -m -u "$EXECUTABLE_PATH") || {
        echo "Unable to inspect Swift runtime imports: $EXECUTABLE_PATH" >&2
        exit 1
    }
    if awk '/\(undefined\)/ && !/ weak / && / _swift_initBorrow([[:space:]]|$)/ { found = 1 }
        END { exit !found }' <<< "$undefined_symbols"; then
        echo "Unsupported strong macOS 27 Swift runtime import: _swift_initBorrow ($EXECUTABLE_PATH)" >&2
        exit 1
    fi

    python3 "$SCRIPT_DIR/swift-runtime-exports.py" audit ${RUNTIME_SDK_ARGS[@]+"${RUNTIME_SDK_ARGS[@]}"} "$EXECUTABLE_PATH" || exit 1
fi

# dyld resolves @rpath separately for each Mach-O slice. A load command in
# arm64 does not provide a search path for an Intel dependency (or vice versa).
binary_architectures=$(lipo -archs "$EXECUTABLE_PATH")
for architecture in $binary_architectures; do
    compatibility_dependencies=$(otool -arch "$architecture" -L "$EXECUTABLE_PATH" | awk '
        $1 ~ /^@rpath\/libswiftCompatibility.*\.dylib$/ { print $1 }
    ')
    if [ -z "$compatibility_dependencies" ]; then
        echo "No Swift compatibility runtime dependencies ($architecture): $EXECUTABLE_PATH"
        continue
    fi

    loader_rpath_found=false
    load_commands=$(otool -arch "$architecture" -l "$EXECUTABLE_PATH")
    while IFS= read -r rpath; do
        case "$rpath" in
            @loader_path|@executable_path) loader_rpath_found=true ;;
        esac
    done < <(read_rpaths <<< "$load_commands")

    if [ "$loader_rpath_found" != true ]; then
        echo "Swift compatibility dependency has no executable-relative LC_RPATH ($architecture): $EXECUTABLE_PATH" >&2
        exit 1
    fi

    while IFS= read -r dependency; do
        [ -n "$dependency" ] || continue
        library_name=${dependency#@rpath/}
        library_path="$LIBRARY_DIR/$library_name"

        [ -f "$library_path" ] || {
            echo "Dangling Swift compatibility dependency: $dependency (missing $library_path)" >&2
            exit 1
        }
        codesign --verify --strict --verbose=2 "$library_path"
        verify_rpaths "$library_path"

        if [ -n "$EXPECTED_IDENTITY" ] && [ "$EXPECTED_IDENTITY" != "-" ]; then
            authority=$(codesign -dv --verbose=4 "$library_path" 2>&1 | sed -n 's/^Authority=//p' | sed -n '1p')
            [ "$authority" = "$EXPECTED_IDENTITY" ] || {
                echo "Swift compatibility library signer mismatch: expected '$EXPECTED_IDENTITY', got '$authority'" >&2
                exit 1
            }
        fi

        if [ -n "$EXPECTED_TEAM_ID" ]; then
            team_id=$(codesign -dv --verbose=4 "$library_path" 2>&1 | sed -n 's/^TeamIdentifier=//p' | sed -n '1p')
            [ "$team_id" = "$EXPECTED_TEAM_ID" ] || {
                echo "Swift compatibility library TeamIdentifier mismatch: expected '$EXPECTED_TEAM_ID', got '$team_id'" >&2
                exit 1
            }
        fi

        library_architectures=$(lipo -archs "$library_path")
        case " $library_architectures " in
            *" $architecture "*) ;;
            *)
                echo "Swift compatibility library is missing $architecture: $library_path" >&2
                exit 1
                ;;
        esac

        echo "Resolved Swift compatibility dependency: $dependency -> $library_path"
    done <<< "$compatibility_dependencies"
done
