
function __breeze_light_using_add
    contains -- 'add' (commandline -poc)
end


set breeze_commands (string join '' $breeze_commands)

complete -c breeze  -xa 'status' -d 'Add numeric number to git status'
complete -c breeze  -xa 'add' -d 'Git add with numeric number'

complete -c breeze -n '__breeze_light_using_add' -s s -l show-status -d 'Display status after git add'