
complete -c breeze -n '__fish_use_subcommand' -xa "(breeze _complete)"

complete -c breeze -n '__fish_seen_subcommand_from add' -s s -l show-status -d 'Display status after git add'
complete -c breeze -n '__fish_seen_subcommand_from add' -s m -d 'Perform commit, and everything after this flag will the message'
