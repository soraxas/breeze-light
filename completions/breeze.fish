
function __breeze_light_using_add
    contains -- 'add' (commandline -poc)
end

function __breeze_light_needs_command
    set -l subcommands (breeze _complete | string replace -r '\t.*$' '')
    for arg in (commandline -poc)
        contains -- "$arg" $subcommands
        and return 1
    end
    return 0
end


set breeze_commands (string join '' $breeze_commands)

complete -c breeze -n '__breeze_light_needs_command' -xa "(breeze _complete)"

complete -c breeze -n '__breeze_light_using_add' -s s -l show-status -d 'Display status after git add'
complete -c breeze -n '__breeze_light_using_add' -s m -d 'Perform commit, and everything after this flag will the message'
