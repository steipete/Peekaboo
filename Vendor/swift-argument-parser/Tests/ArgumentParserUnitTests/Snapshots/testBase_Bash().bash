#!/bin/bash

__base-test_cursor_index_in_current_word() {
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
__base-test_offer_flags_options() {
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

__base-test_add_completions() {
    local completion
    while IFS='' read -r completion; do
        COMPREPLY+=("${completion}")
    done < <(IFS=$'\n' compgen "${@}" -- "${cur}")
}

__base-test_custom_complete() {
    if [[ -n "${cur}" || -z ${COMP_WORDS[${COMP_CWORD}]} || "${COMP_LINE:${COMP_POINT}:1}" != ' ' ]]; then
        local -ar words=("${COMP_WORDS[@]}")
    else
        local -ar words=("${COMP_WORDS[@]::${COMP_CWORD}}" '' "${COMP_WORDS[@]:${COMP_CWORD}}")
    fi

    "${COMP_WORDS[0]}" "${@}" "${words[@]}"
}

_base-test() {
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

    local -a flags=(--one --two --custom-three --kind-counter -h --help)
    local -a options=(--name --kind --other-kind --path1 --path2 --path3 --rep1 -r --rep2)
    __base-test_offer_flags_options 2

    # Offer option value completions
    case "${prev}" in
    '--name')
        return
        ;;
    '--kind')
        __base-test_add_completions -W 'one'$'\n''two'$'\n''custom-three'
        return
        ;;
    '--other-kind')
        __base-test_add_completions -W 'b1_bash'$'\n''b2_bash'$'\n''b3_bash'
        return
        ;;
    '--path1')
        __base-test_add_completions -f
        return
        ;;
    '--path2')
        __base-test_add_completions -f
        return
        ;;
    '--path3')
        __base-test_add_completions -W 'c1_bash'$'\n''c2_bash'$'\n''c3_bash'
        return
        ;;
    '--rep1')
        return
        ;;
    '-r'|'--rep2')
        return
        ;;
    esac

    # Offer positional completions
    case "${positional_number}" in
    1)
        __base-test_add_completions -W "$(__base-test_custom_complete ---completion -- positional@0 "${COMP_CWORD}" "$(__base-test_cursor_index_in_current_word)")"
        return
        ;;
    2)
        __base-test_add_completions -W "$(__base-test_custom_complete ---completion -- positional@1 "${COMP_CWORD}" "$(__base-test_cursor_index_in_current_word)")"
        return
        ;;
    esac

    # Offer subcommand / subcommand argument completions
    local -r subcommand="${unparsed_words[0]}"
    unset 'unparsed_words[0]'
    unparsed_words=("${unparsed_words[@]}")
    case "${subcommand}" in
    sub-command|escaped-command|help)
        # Offer subcommand argument completions
        "_base-test_${subcommand}"
        ;;
    *)
        # Offer subcommand completions
        COMPREPLY+=($(compgen -W 'sub-command escaped-command help' -- "${cur}"))
        ;;
    esac
}

_base-test_sub-command() {
    flags=(-h --help)
    options=()
    __base-test_offer_flags_options 0
}

_base-test_escaped-command() {
    flags=(-h --help)
    options=(--o:n[e)
    __base-test_offer_flags_options 1

    # Offer option value completions
    case "${prev}" in
    '--o:n[e')
        return
        ;;
    esac

    # Offer positional completions
    case "${positional_number}" in
    1)
        __base-test_add_completions -W "$(__base-test_custom_complete ---completion escaped-command -- positional@0 "${COMP_CWORD}" "$(__base-test_cursor_index_in_current_word)")"
        return
        ;;
    esac
}

_base-test_help() {
    :
}

complete -o filenames -F _base-test base-test