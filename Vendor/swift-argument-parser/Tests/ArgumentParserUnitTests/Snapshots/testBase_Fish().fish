function __base-test_should_offer_completions_for -a expected_commands -a expected_positional_index
    set -l unparsed_tokens (__base-test_tokens -pc)
    set -l positional_index 0
    set -l commands

    switch $unparsed_tokens[1]
    case 'base-test'
        __base-test_parse_subcommand 2 'name=' 'kind=' 'other-kind=' 'path1=' 'path2=' 'path3=' 'one' 'two' 'custom-three' 'kind-counter' 'rep1=' 'r/rep2=' 'h/help'
        switch $unparsed_tokens[1]
        case 'sub-command'
            __base-test_parse_subcommand 0 'h/help'
        case 'escaped-command'
            __base-test_parse_subcommand 1 'o:n[e=' 'h/help'
        case 'help'
            __base-test_parse_subcommand -r 1 
        end
    end

    test "$commands" = "$expected_commands" -a \( -z "$expected_positional_index" -o "$expected_positional_index" -eq "$positional_index" \)
end

function __base-test_tokens
    if test (string split -m 1 -f 1 -- . "$FISH_VERSION") -gt 3
        commandline --tokens-raw $argv
    else
        commandline -o $argv
    end
end

function __base-test_parse_subcommand -S
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

function __base-test_complete_directories
    set -l token (commandline -t)
    string match -- '*/' $token
    set -l subdirs $token*/
    printf '%s\n' $subdirs
end

function __base-test_custom_completion
    set -x SAP_SHELL fish
    set -x SAP_SHELL_VERSION $FISH_VERSION

    set -l tokens (__base-test_tokens -p)
    if test -z (__base-test_tokens -t)
        set -l index (count (__base-test_tokens -pc))
        set tokens $tokens[..$index] \'\' $tokens[(math $index + 1)..]
    end
    command $tokens[1] $argv $tokens
end

complete -c 'base-test' -f
complete -c 'base-test' -n '__base-test_should_offer_completions_for "base-test"' -l 'name' -d 'The user\'s name.' -rfka ''
complete -c 'base-test' -n '__base-test_should_offer_completions_for "base-test"' -l 'kind' -rfka 'one two custom-three'
complete -c 'base-test' -n '__base-test_should_offer_completions_for "base-test"' -l 'other-kind' -rfka 'b1_fish b2_fish b3_fish'
complete -c 'base-test' -n '__base-test_should_offer_completions_for "base-test"' -l 'path1' -rF
complete -c 'base-test' -n '__base-test_should_offer_completions_for "base-test"' -l 'path2' -rF
complete -c 'base-test' -n '__base-test_should_offer_completions_for "base-test"' -l 'path3' -rfka 'c1_fish c2_fish c3_fish'
complete -c 'base-test' -n '__base-test_should_offer_completions_for "base-test"' -l 'one'
complete -c 'base-test' -n '__base-test_should_offer_completions_for "base-test"' -l 'two'
complete -c 'base-test' -n '__base-test_should_offer_completions_for "base-test"' -l 'custom-three'
complete -c 'base-test' -n '__base-test_should_offer_completions_for "base-test"' -l 'kind-counter'
complete -c 'base-test' -n '__base-test_should_offer_completions_for "base-test"' -l 'rep1' -rfka ''
complete -c 'base-test' -n '__base-test_should_offer_completions_for "base-test"' -s 'r' -l 'rep2' -rfka ''
complete -c 'base-test' -n '__base-test_should_offer_completions_for "base-test" 1' -fka '(__base-test_custom_completion ---completion -- positional@0 (count (__base-test_tokens -pc)) (__base-test_tokens -tC))'
complete -c 'base-test' -n '__base-test_should_offer_completions_for "base-test" 2' -fka '(__base-test_custom_completion ---completion -- positional@1 (count (__base-test_tokens -pc)) (__base-test_tokens -tC))'
complete -c 'base-test' -n '__base-test_should_offer_completions_for "base-test"' -s 'h' -l 'help' -d 'Show help information.'
complete -c 'base-test' -n '__base-test_should_offer_completions_for "base-test" 3' -fa 'sub-command' -d ''
complete -c 'base-test' -n '__base-test_should_offer_completions_for "base-test" 3' -fa 'escaped-command' -d ''
complete -c 'base-test' -n '__base-test_should_offer_completions_for "base-test" 3' -fa 'help' -d 'Show subcommand help information.'
complete -c 'base-test' -n '__base-test_should_offer_completions_for "base-test sub-command"' -s 'h' -l 'help' -d 'Show help information.'
complete -c 'base-test' -n '__base-test_should_offer_completions_for "base-test escaped-command"' -l 'o:n[e' -d 'Escaped chars: \'[]\\.' -rfka ''
complete -c 'base-test' -n '__base-test_should_offer_completions_for "base-test escaped-command" 1' -fka '(__base-test_custom_completion ---completion escaped-command -- positional@0 (count (__base-test_tokens -pc)) (__base-test_tokens -tC))'
complete -c 'base-test' -n '__base-test_should_offer_completions_for "base-test escaped-command"' -s 'h' -l 'help' -d 'Show help information.'