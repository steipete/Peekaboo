#!/bin/bash

__math_cursor_index_in_current_word() {
    local remaining="${COMP_LINE}"

    local word
    for word in "${COMP_WORDS[@]::COMP_CWORD}"; do
        remaining="${remaining##*([[:space:]])"${word}"*([[:space:]])}"
    done

    local -ir index="$((COMP_POINT - ${#COMP_LINE} + ${#remaining}))"
    if [[ "${index}" -le 0 ]]; then
        printf 0
    else
        printf %s "${index}"
    fi
}

# positional arguments:
#
# - 1: the current (sub)command's count of positional arguments
#
# required variables:
#
# - flags: the flags that the current (sub)command can accept
# - options: the options that the current (sub)command can accept
# - positional_number: value ignored
# - unparsed_words: unparsed words from the current command line
#
# modified variables:
#
# - flags: remove flags for this (sub)command that are already on the command line
# - options: remove options for this (sub)command that are already on the command line
# - positional_number: set to the current positional number
# - unparsed_words: remove all flags, options, and option values for this (sub)command
__math_offer_flags_options() {
    local -ir positional_count="${1}"
    positional_number=0

    local was_flag_option_terminator_seen=false
    local is_parsing_option_value=false

    local -ar unparsed_word_indices=("${!unparsed_words[@]}")
    local -i word_index
    for word_index in "${unparsed_word_indices[@]}"; do
        if "${is_parsing_option_value}"; then
            # This word is an option value:
            # Reset marker for next word iff not currently the last word
            [[ "${word_index}" -ne "${unparsed_word_indices[${#unparsed_word_indices[@]} - 1]}" ]] && is_parsing_option_value=false
            unset "unparsed_words[${word_index}]"
            # Do not process this word as a flag or an option
            continue
        fi

        local word="${unparsed_words["${word_index}"]}"
        if ! "${was_flag_option_terminator_seen}"; then
            case "${word}" in
            --)
                unset "unparsed_words[${word_index}]"
                # by itself -- is a flag/option terminator, but if it is the last word, it is the start of a completion
                if [[ "${word_index}" -ne "${unparsed_word_indices[${#unparsed_word_indices[@]} - 1]}" ]]; then
                    was_flag_option_terminator_seen=true
                fi
                continue
                ;;
            -*)
                # ${word} is a flag or an option
                # If ${word} is an option, mark that the next word to be parsed is an option value
                local option
                for option in "${options[@]}"; do
                    [[ "${word}" = "${option}" ]] && is_parsing_option_value=true && break
                done

                # Remove ${word} from ${flags} or ${options} so it isn't offered again
                local not_found=true
                local -i index
                for index in "${!flags[@]}"; do
                    if [[ "${flags[${index}]}" = "${word}" ]]; then
                        unset "flags[${index}]"
                        flags=("${flags[@]}")
                        not_found=false
                        break
                    fi
                done
                if "${not_found}"; then
                    for index in "${!options[@]}"; do
                        if [[ "${options[${index}]}" = "${word}" ]]; then
                            unset "options[${index}]"
                            options=("${options[@]}")
                            break
                        fi
                    done
                fi
                unset "unparsed_words[${word_index}]"
                continue
                ;;
            esac
        fi

        # ${word} is neither a flag, nor an option, nor an option value
        if [[ "${positional_number}" -lt "${positional_count}" ]]; then
            # ${word} is a positional
            ((positional_number++))
            unset "unparsed_words[${word_index}]"
        else
            if [[ -z "${word}" ]]; then
                # Could be completing a flag, option, or subcommand
                positional_number=-1
            else
                # ${word} is a subcommand or invalid, so stop processing this (sub)command
                positional_number=-2
            fi
            break
        fi
    done

    unparsed_words=("${unparsed_words[@]}")

    if\
        ! "${was_flag_option_terminator_seen}"\
        && ! "${is_parsing_option_value}"\
        && [[ ("${cur}" = -* && "${positional_number}" -ge 0) || "${positional_number}" -eq -1 ]]
    then
        COMPREPLY+=($(compgen -W "${flags[*]} ${options[*]}" -- "${cur}"))
    fi
}

__math_add_completions() {
    local completion
    while IFS='' read -r completion; do
        COMPREPLY+=("${completion}")
    done < <(IFS=$'\n' compgen "${@}" -- "${cur}")
}

__math_custom_complete() {
    if [[ -n "${cur}" || -z ${COMP_WORDS[${COMP_CWORD}]} || "${COMP_LINE:${COMP_POINT}:1}" != ' ' ]]; then
        local -ar words=("${COMP_WORDS[@]}")
    else
        local -ar words=("${COMP_WORDS[@]::${COMP_CWORD}}" '' "${COMP_WORDS[@]:${COMP_CWORD}}")
    fi

    "${COMP_WORDS[0]}" "${@}" "${words[@]}"
}

_math() {
    trap "$(shopt -p);$(shopt -po)" RETURN
    shopt -s extglob
    set +o history +o posix

    local -xr SAP_SHELL=bash
    local -x SAP_SHELL_VERSION
    SAP_SHELL_VERSION="$(IFS='.';printf %s "${BASH_VERSINFO[*]}")"
    local -r SAP_SHELL_VERSION

    local -r cur="${2}"
    local -r prev="${3}"

    local -i positional_number
    local -a unparsed_words=("${COMP_WORDS[@]:1:${COMP_CWORD}}")

    local -a flags=(--version -h --help)
    local -a options=()
    __math_offer_flags_options 0

    # Offer subcommand / subcommand argument completions
    local -r subcommand="${unparsed_words[0]}"
    unset 'unparsed_words[0]'
    unparsed_words=("${unparsed_words[@]}")
    case "${subcommand}" in
    add|multiply|stats|help)
        # Offer subcommand argument completions
        "_math_${subcommand}"
        ;;
    *)
        # Offer subcommand completions
        COMPREPLY+=($(compgen -W 'add multiply stats help' -- "${cur}"))
        ;;
    esac
}

_math_add() {
    flags=(--hex-output -x --version -h --help)
    options=()
    __math_offer_flags_options 1
}

_math_multiply() {
    flags=(--hex-output -x --version -h --help)
    options=()
    __math_offer_flags_options 1
}

_math_stats() {
    flags=(--version -h --help)
    options=()
    __math_offer_flags_options 0

    # Offer subcommand / subcommand argument completions
    local -r subcommand="${unparsed_words[0]}"
    unset 'unparsed_words[0]'
    unparsed_words=("${unparsed_words[@]}")
    case "${subcommand}" in
    average|stdev|quantiles)
        # Offer subcommand argument completions
        "_math_stats_${subcommand}"
        ;;
    *)
        # Offer subcommand completions
        COMPREPLY+=($(compgen -W 'average stdev quantiles' -- "${cur}"))
        ;;
    esac
}

_math_stats_average() {
    flags=(--version -h --help)
    options=(--kind)
    __math_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--kind')
        __math_add_completions -W 'mean'$'\n''median'$'\n''mode'
        return
        ;;
    esac
}

_math_stats_stdev() {
    flags=(--version -h --help)
    options=()
    __math_offer_flags_options 1
}

_math_stats_quantiles() {
    flags=(--version -h --help)
    options=(--file --directory --shell --custom --custom-deprecated)
    __math_offer_flags_options 4

    # Offer option value completions
    case "${prev}" in
    '--file')
        __math_add_completions -o plusdirs -fX '!*.@(txt|md)'
        return
        ;;
    '--directory')
        __math_add_completions -d
        return
        ;;
    '--shell')
        __math_add_completions -W "$(eval 'head -100 '\''/usr/share/dict/words'\'' | tail -50')"
        return
        ;;
    '--custom')
        __math_add_completions -W "$(__math_custom_complete ---completion stats quantiles -- --custom "${COMP_CWORD}" "$(__math_cursor_index_in_current_word)")"
        return
        ;;
    '--custom-deprecated')
        __math_add_completions -W "$(__math_custom_complete ---completion stats quantiles -- --custom-deprecated)"
        return
        ;;
    esac

    # Offer positional completions
    case "${positional_number}" in
    1)
        __math_add_completions -W 'alphabet'$'\n''alligator'$'\n''branch'$'\n''braggart'
        return
        ;;
    2)
        __math_add_completions -W "$(__math_custom_complete ---completion stats quantiles -- positional@1 "${COMP_CWORD}" "$(__math_cursor_index_in_current_word)")"
        return
        ;;
    3)
        __math_add_completions -W "$(__math_custom_complete ---completion stats quantiles -- positional@2)"
        return
        ;;
    esac
}

_math_help() {
    flags=(--version)
    options=()
    __math_offer_flags_options 1
}

complete -o filenames -F _math math
