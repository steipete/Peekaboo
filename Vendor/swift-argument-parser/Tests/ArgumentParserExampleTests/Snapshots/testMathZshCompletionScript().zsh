#compdef math

__math_complete() {
    local -ar non_empty_completions=("${@:#(|:*)}")
    local -ar empty_completions=("${(M)@:#(|:*)}")
    _describe -V '' non_empty_completions -- empty_completions -P $'\'\''
}

__math_custom_complete() {
    local -a completions
    completions=("${(@f)"$("${command_name}" "${@}" "${command_line[@]}")"}")
    if [[ "${#completions[@]}" -gt 1 ]]; then
        __math_complete "${completions[@]:0:-1}"
    fi
}

__math_cursor_index_in_current_word() {
    if [[ -z "${QIPREFIX}${IPREFIX}${PREFIX}" ]]; then
        printf 0
    else
        printf %s "${#${(z)LBUFFER}[-1]}"
    fi
}

_math() {
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
    local -ar arg_specs=(
        '--version[Show the version.]'
        '(-h --help)'{-h,--help}'[Show help information.]'
        '(-): :->command'
        '(-)*:: :->arg'
    )
    _arguments -w -s -S : "${arg_specs[@]}" && ret=0
    case "${state}" in
    command)
        local -ar subcommands=(
            'add:Print the sum of the values.'
            'multiply:Print the product of the values.'
            'stats:Calculate descriptive statistics.'
            'help:Show subcommand help information.'
        )
        _describe -V subcommand subcommands
        ;;
    arg)
        case "${words[1]}" in
        add|multiply|stats|help)
            "_math_${words[1]}"
            ;;
        esac
        ;;
    esac

    return "${ret}"
}

_math_add() {
    local -i ret=1
    local -ar arg_specs=(
        '(--hex-output -x)'{--hex-output,-x}'[Use hexadecimal notation for the result.]'
        '*:values:'
        '--version[Show the version.]'
        '(-h --help)'{-h,--help}'[Show help information.]'
    )
    _arguments -w -s -S : "${arg_specs[@]}" && ret=0

    return "${ret}"
}

_math_multiply() {
    local -i ret=1
    local -ar arg_specs=(
        '(--hex-output -x)'{--hex-output,-x}'[Use hexadecimal notation for the result.]'
        '*:values:'
        '--version[Show the version.]'
        '(-h --help)'{-h,--help}'[Show help information.]'
    )
    _arguments -w -s -S : "${arg_specs[@]}" && ret=0

    return "${ret}"
}

_math_stats() {
    local -i ret=1
    local -ar arg_specs=(
        '--version[Show the version.]'
        '(-h --help)'{-h,--help}'[Show help information.]'
        '(-): :->command'
        '(-)*:: :->arg'
    )
    _arguments -w -s -S : "${arg_specs[@]}" && ret=0
    case "${state}" in
    command)
        local -ar subcommands=(
            'average:Print the average of the values.'
            'stdev:Print the standard deviation of the values.'
            'quantiles:Print the quantiles of the values (TBD).'
        )
        _describe -V subcommand subcommands
        ;;
    arg)
        case "${words[1]}" in
        average|stdev|quantiles)
            "_math_stats_${words[1]}"
            ;;
        esac
        ;;
    esac

    return "${ret}"
}

_math_stats_average() {
    local -i ret=1
    local -ar ___kind=('mean' 'median' 'mode')
    local -ar arg_specs=(
        '--kind[The kind of average to provide.]:kind:{__math_complete "${___kind[@]}"}'
        '*:values:'
        '--version[Show the version.]'
        '(-h --help)'{-h,--help}'[Show help information.]'
    )
    _arguments -w -s -S : "${arg_specs[@]}" && ret=0

    return "${ret}"
}

_math_stats_stdev() {
    local -i ret=1
    local -ar arg_specs=(
        '*:values:'
        '--version[Show the version.]'
        '(-h --help)'{-h,--help}'[Show help information.]'
    )
    _arguments -w -s -S : "${arg_specs[@]}" && ret=0

    return "${ret}"
}

_math_stats_quantiles() {
    local -i ret=1
    local -ar _one_of_four=('alphabet' 'alligator' 'branch' 'braggart')
    local -ar arg_specs=(
        ':one-of-four:{__math_complete "${_one_of_four[@]}"}'
        ':custom-arg:{__math_custom_complete ---completion stats quantiles -- positional@1 "${current_word_index}" "$(__math_cursor_index_in_current_word)"}'
        ':custom-deprecated-arg:{__math_custom_complete ---completion stats quantiles -- positional@2}'
        '*:values:'
        '--file:file:_files -g '\''*.txt *.md'\'''
        '--directory:directory:_files -/'
        '--shell:shell:{local -a list;list=(${(f)"$(head -100 '\''/usr/share/dict/words'\'' | tail -50)"});_describe -V "" list}'
        '--custom:custom:{__math_custom_complete ---completion stats quantiles -- --custom "${current_word_index}" "$(__math_cursor_index_in_current_word)"}'
        '--custom-deprecated:custom-deprecated:{__math_custom_complete ---completion stats quantiles -- --custom-deprecated}'
        '--version[Show the version.]'
        '(-h --help)'{-h,--help}'[Show help information.]'
    )
    _arguments -w -s -S : "${arg_specs[@]}" && ret=0

    return "${ret}"
}

_math_help() {
    local -i ret=1
    local -ar arg_specs=(
        '*:subcommands:'
        '--version[Show the version.]'
    )
    _arguments -w -s -S : "${arg_specs[@]}" && ret=0

    return "${ret}"
}

_math
