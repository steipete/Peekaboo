#compdef base-test

__base-test_complete() {
    local -ar non_empty_completions=("${@:#(|:*)}")
    local -ar empty_completions=("${(M)@:#(|:*)}")
    _describe -V '' non_empty_completions -- empty_completions -P $'\'\''
}

__base-test_custom_complete() {
    local -a completions
    completions=("${(@f)"$("${command_name}" "${@}" "${command_line[@]}")"}")
    if [[ "${#completions[@]}" -gt 1 ]]; then
        __base-test_complete "${completions[@]:0:-1}"
    fi
}

__base-test_cursor_index_in_current_word() {
    if [[ -z "${QIPREFIX}${IPREFIX}${PREFIX}" ]]; then
        printf 0
    else
        printf %s "${#${(z)LBUFFER}[-1]}"
    fi
}

_base-test() {
    emulate -RL zsh -G
    setopt extendedglob nullglob numericglobsort
    unsetopt aliases banghist

    local -xr SAP_SHELL=zsh
    local -x SAP_SHELL_VERSION
    SAP_SHELL_VERSION="$(builtin emulate zsh -c 'printf %s "${ZSH_VERSION}"')"
    local -r SAP_SHELL_VERSION

    local context state state_descr line
    local -A opt_args

    local -r command_name="${words[1]}"
    local -ar command_line=("${words[@]}")
    local -ir current_word_index="$((CURRENT - 1))"

    local -i ret=1
    local -ar ___kind=('one' 'two' 'custom-three')
    local -ar ___other_kind=('b1_zsh' 'b2_zsh' 'b3_zsh')
    local -ar ___path3=('c1_zsh' 'c2_zsh' 'c3_zsh')
    local -ar arg_specs=(
        '--name[The user'\''s name.]:name:'
        '--kind:kind:{__base-test_complete "${___kind[@]}"}'
        '--other-kind:other-kind:{__base-test_complete "${___other_kind[@]}"}'
        '--path1:path1:_files'
        '--path2:path2:_files'
        '--path3:path3:{__base-test_complete "${___path3[@]}"}'
        '--one'
        '--two'
        '--custom-three'
        '*--kind-counter'
        '*--rep1:rep1:'
        '*'{-r,--rep2}':rep2:'
        ':argument:{__base-test_custom_complete ---completion -- positional@0 "${current_word_index}" "$(__base-test_cursor_index_in_current_word)"}'
        ':nested-argument:{__base-test_custom_complete ---completion -- positional@1 "${current_word_index}" "$(__base-test_cursor_index_in_current_word)"}'
        '(-h --help)'{-h,--help}'[Show help information.]'
        '(-): :->command'
        '(-)*:: :->arg'
    )
    _arguments -w -s -S : "${arg_specs[@]}" && ret=0
    case "${state}" in
    command)
        local -ar subcommands=(
            'sub-command:'
            'escaped-command:'
            'help:Show subcommand help information.'
        )
        _describe -V subcommand subcommands
        ;;
    arg)
        case "${words[1]}" in
        sub-command|escaped-command|help)
            "_base-test_${words[1]}"
            ;;
        esac
        ;;
    esac

    return "${ret}"
}

_base-test_sub-command() {
    local -i ret=1
    local -ar arg_specs=(
        '(-h --help)'{-h,--help}'[Show help information.]'
    )
    _arguments -w -s -S : "${arg_specs[@]}" && ret=0

    return "${ret}"
}

_base-test_escaped-command() {
    local -i ret=1
    local -ar arg_specs=(
        '--o\:n\[e[Escaped chars\: '\''\[\]\\.]:path\[\:options\]:'
        ':two:{__base-test_custom_complete ---completion escaped-command -- positional@0 "${current_word_index}" "$(__base-test_cursor_index_in_current_word)"}'
        '(-h --help)'{-h,--help}'[Show help information.]'
    )
    _arguments -w -s -S : "${arg_specs[@]}" && ret=0

    return "${ret}"
}

_base-test_help() {
    local -i ret=1
    local -ar arg_specs=(
        '*:subcommands:'
    )
    _arguments -w -s -S : "${arg_specs[@]}" && ret=0

    return "${ret}"
}

_base-test