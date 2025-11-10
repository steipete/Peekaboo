function __math_should_offer_completions_for -a expected_commands -a expected_positional_index
    set -l unparsed_tokens (__math_tokens -pc)
    set -l positional_index 0
    set -l commands

    switch $unparsed_tokens[1]
    case 'math'
        __math_parse_subcommand 0 'version' 'h/help'
        switch $unparsed_tokens[1]
        case 'add'
            __math_parse_subcommand -r 1 'x/hex-output' 'version' 'h/help'
        case 'multiply'
            __math_parse_subcommand -r 1 'x/hex-output' 'version' 'h/help'
        case 'stats'
            __math_parse_subcommand 0 'version' 'h/help'
            switch $unparsed_tokens[1]
            case 'average'
                __math_parse_subcommand -r 1 'kind=' 'version' 'h/help'
            case 'stdev'
                __math_parse_subcommand -r 1 'version' 'h/help'
            case 'quantiles'
                __math_parse_subcommand -r 4 'file=' 'directory=' 'shell=' 'custom=' 'custom-deprecated=' 'version' 'h/help'
            end
        case 'help'
            __math_parse_subcommand -r 1 'version'
        end
    end

    test "$commands" = "$expected_commands" -a \( -z "$expected_positional_index" -o "$expected_positional_index" -eq "$positional_index" \)
end

function __math_tokens
    if test (string split -m 1 -f 1 -- . "$FISH_VERSION") -gt 3
        commandline --tokens-raw $argv
    else
        commandline -o $argv
    end
end

function __math_parse_subcommand -S
    argparse -s r -- $argv
    set -l positional_count $argv[1]
    set -l option_specs $argv[2..]

    set -a commands $unparsed_tokens[1]
    set -e unparsed_tokens[1]

    set positional_index 0

    while true
        argparse -sn "$commands" $option_specs -- $unparsed_tokens 2> /dev/null
        set unparsed_tokens $argv
        set positional_index (math $positional_index + 1)
        if test (count $unparsed_tokens) -eq 0 -o \( -z "$_flag_r" -a "$positional_index" -gt "$positional_count" \)
            return 0
        end
        set -e unparsed_tokens[1]
    end
end

function __math_complete_directories
    set -l token (commandline -t)
    string match -- '*/' $token
    set -l subdirs $token*/
    printf '%s\n' $subdirs
end

function __math_custom_completion
    set -x SAP_SHELL fish
    set -x SAP_SHELL_VERSION $FISH_VERSION

    set -l tokens (__math_tokens -p)
    if test -z (__math_tokens -t)
        set -l index (count (__math_tokens -pc))
        set tokens $tokens[..$index] \'\' $tokens[(math $index + 1)..]
    end
    command $tokens[1] $argv $tokens
end

complete -c 'math' -f
complete -c 'math' -n '__math_should_offer_completions_for "math"' -l 'version' -d 'Show the version.'
complete -c 'math' -n '__math_should_offer_completions_for "math"' -s 'h' -l 'help' -d 'Show help information.'
complete -c 'math' -n '__math_should_offer_completions_for "math" 1' -fa 'add' -d 'Print the sum of the values.'
complete -c 'math' -n '__math_should_offer_completions_for "math" 1' -fa 'multiply' -d 'Print the product of the values.'
complete -c 'math' -n '__math_should_offer_completions_for "math" 1' -fa 'stats' -d 'Calculate descriptive statistics.'
complete -c 'math' -n '__math_should_offer_completions_for "math" 1' -fa 'help' -d 'Show subcommand help information.'
complete -c 'math' -n '__math_should_offer_completions_for "math add"' -l 'hex-output' -s 'x' -d 'Use hexadecimal notation for the result.'
complete -c 'math' -n '__math_should_offer_completions_for "math add"' -l 'version' -d 'Show the version.'
complete -c 'math' -n '__math_should_offer_completions_for "math add"' -s 'h' -l 'help' -d 'Show help information.'
complete -c 'math' -n '__math_should_offer_completions_for "math multiply"' -l 'hex-output' -s 'x' -d 'Use hexadecimal notation for the result.'
complete -c 'math' -n '__math_should_offer_completions_for "math multiply"' -l 'version' -d 'Show the version.'
complete -c 'math' -n '__math_should_offer_completions_for "math multiply"' -s 'h' -l 'help' -d 'Show help information.'
complete -c 'math' -n '__math_should_offer_completions_for "math stats"' -l 'version' -d 'Show the version.'
complete -c 'math' -n '__math_should_offer_completions_for "math stats"' -s 'h' -l 'help' -d 'Show help information.'
complete -c 'math' -n '__math_should_offer_completions_for "math stats" 1' -fa 'average' -d 'Print the average of the values.'
complete -c 'math' -n '__math_should_offer_completions_for "math stats" 1' -fa 'stdev' -d 'Print the standard deviation of the values.'
complete -c 'math' -n '__math_should_offer_completions_for "math stats" 1' -fa 'quantiles' -d 'Print the quantiles of the values (TBD).'
complete -c 'math' -n '__math_should_offer_completions_for "math stats average"' -l 'kind' -d 'The kind of average to provide.' -rfka 'mean median mode'
complete -c 'math' -n '__math_should_offer_completions_for "math stats average"' -l 'version' -d 'Show the version.'
complete -c 'math' -n '__math_should_offer_completions_for "math stats average"' -s 'h' -l 'help' -d 'Show help information.'
complete -c 'math' -n '__math_should_offer_completions_for "math stats stdev"' -l 'version' -d 'Show the version.'
complete -c 'math' -n '__math_should_offer_completions_for "math stats stdev"' -s 'h' -l 'help' -d 'Show help information.'
complete -c 'math' -n '__math_should_offer_completions_for "math stats quantiles" 1' -fka 'alphabet alligator branch braggart'
complete -c 'math' -n '__math_should_offer_completions_for "math stats quantiles" 2' -fka '(__math_custom_completion ---completion stats quantiles -- positional@1 (count (__math_tokens -pc)) (__math_tokens -tC))'
complete -c 'math' -n '__math_should_offer_completions_for "math stats quantiles" 3' -fka '(__math_custom_completion ---completion stats quantiles -- positional@2)'
complete -c 'math' -n '__math_should_offer_completions_for "math stats quantiles"' -l 'file' -rfa '(set -l exts \'txt\' \'md\';for p in (string match -e -- \'*/\' (commandline -t);or printf \n)*.{$exts};printf %s\n $p;end;__fish_complete_directories (commandline -t) \'\')'
complete -c 'math' -n '__math_should_offer_completions_for "math stats quantiles"' -l 'directory' -rfa '(__math_complete_directories)'
complete -c 'math' -n '__math_should_offer_completions_for "math stats quantiles"' -l 'shell' -rfka '(head -100 \'/usr/share/dict/words\' | tail -50)'
complete -c 'math' -n '__math_should_offer_completions_for "math stats quantiles"' -l 'custom' -rfka '(__math_custom_completion ---completion stats quantiles -- --custom (count (__math_tokens -pc)) (__math_tokens -tC))'
complete -c 'math' -n '__math_should_offer_completions_for "math stats quantiles"' -l 'custom-deprecated' -rfka '(__math_custom_completion ---completion stats quantiles -- --custom-deprecated)'
complete -c 'math' -n '__math_should_offer_completions_for "math stats quantiles"' -l 'version' -d 'Show the version.'
complete -c 'math' -n '__math_should_offer_completions_for "math stats quantiles"' -s 'h' -l 'help' -d 'Show help information.'
complete -c 'math' -n '__math_should_offer_completions_for "math help"' -l 'version' -d 'Show the version.'
