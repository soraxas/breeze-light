
set __breeze_light_subcommands \
    "status:Git status with numeric number inserted" \
    "add:Git add with numeric number" \
    "checkout:Git checkout with numeric number" \
    "diff:Git diff with numeric number" \
    "_complete:Print out completions string"

# main function
function breeze
    set -l cmd $argv[1]
    set -e argv[1]
    
    if test "$cmd" = "status"
        __breeze_light_show_status

    else if test "$cmd" = "diff"
        git diff (__breeze_light_parse_user_input $argv)

    else if test "$cmd" = "checkout"
        git checkout (__breeze_light_parse_user_input $argv)
    
    else if test "$cmd" = "add"

        argparse --ignore-unknown 's/show-status' -- $argv

        # check for message flag
        set -l msg_idx (contains --index -- '-m' $argv)
        if test -n  "$msg_idx"
            if test $msg_idx -lt (count $argv)
                # there are messages after the -m message. (sanity check)
                set commit_msg $argv[(math "$msg_idx + 1")..-1]
                set argv -- $argv[1..(math "$msg_idx - 1")]
            end
        end
        
        # add if it is non-empty
        set -l target_files (__breeze_light_parse_user_input $argv)
        test -n "$target_files"
        and eval "git add $target_files"
        test $status -eq 0
        or return $status
        
        set_color green
        echo -e ">"
        for f in $target_files
          test -n "$f"; and echo -e "> Added $f"
        end
        echo -e ">"

        # perform commit with the message being all args after the flag
        set -q commit_msg
        and echo "> Committing with message '$commit_msg'"
        and set_color normal
        and git commit -sm "$commit_msg"

        # perform show status if -s is specified
        set -q _flag_show_status
        and __breeze_light_show_status

    else if test "$cmd" = "_complete"
        printf "%s\t%s\n" (string split ':' $__breeze_light_subcommands)

    else
        printf "Usage: breeze <COMMAND> [COMMAND OPTIONS]\n\n"
        printf "COMMAND: %s\n" "status"
        printf "         %s\t\n" "add [-s|--show-status] [-m <COMMIT_MSG>]"
        printf "\n"
        printf "%-8s\t%s\n" (string split ':' $__breeze_light_subcommands)
        printf "\n"
        printf "OPTIONS:\n"
        printf "%s\n" "-s --show-status"
        printf "\t%s\n" "Display status afterwards, for easy reference."
        printf "%s\n" "-m"
        printf "\t%s\n" "Immediately commit, and everything after this flag will the message."
        return 1
    end

end


function __breeze_light_helper_get_bracket_num
    # This helps to align the bracket numbers
    # by prefixing spaces
    set -l num_length (string length $argv[1])
    set -l max_num_length (string length $argv[2])
    set -l spaces_needed (string repeat ' ' -n (math "$max_num_length - $num_length"))
    echo "$spaces_needed"'['$argv[1]']'
end


function __breeze_light_get_filelist -d "retrieve list of files from this repo"
    # get file status from git
    # in git status --porcelain, the first two character is for
    # file status, and the third is a space. This is consistent,
    # so we can simply use substring rather than complex regex
    # set -l file_names (git status --porcelain | string sub --start 4)
    # Going to use git status short instead, as it supports relative path
    set -l file_names (git status --short | string sub --start 4)
    # if a file is renamed, it will be shown as XXXXX -> YYYYYY
    # add the two to file list as well.
    set -l i 1
    set -l num_files (count $file_names)
    while test $i -le $num_files
        # try to split
        set -l try_split (string split -- ' -> ' $file_names[$i])
        if test (count $try_split) -eq 2
            # append both to end of list
            set -a file_names $try_split[1]
            set -a file_names $try_split[2]
        end
        set i (math "$i + 1")
    end
    printf '%s\n' $file_names
end



function __breeze_light_show_status -d "add numeric to git status"
    # if true, place [n] in front of the filename
    # else, place in front of the entire status.
    set -q __fish_breeze_show_num_before_fname
    or set -g __fish_breeze_show_num_before_fname "false"

    set -l file_names (__breeze_light_get_filelist)
    set -l num_files (count $file_names)

    for line in (git -c color.status=always status)
        # A line that contains information about a gitfile will either be:
        #                 foo            <- for untracked
        #   modified:     bar
        #    deleted:     hello (new commits)
        #
        # i.e., three main variant
        # echo ---------------
        if string match -q -r '\e\[[0-9;]+m' $line

            # This line has some sort of escaped color code in it.
            # This must be a line that indicates a file within it

            # loop through the list of file and find exact match

            # keep track of the highest matched fname
            set -l max_match_length 0
            set -l idx -1
            for i in (seq 1 (count $file_names))
                set -l file $file_names[$i]
                # find a file that has the maximum matched characters
                if string match -q "*$file*" "$line"
                    set -l _tmp_length (string length -- $file)
                    if test $_tmp_length -gt $max_match_length
                        set max_match_length $_tmp_length
                        set idx $i
                    end
                end
            end

            if test $idx -le 0
                # couldn't find a matching file?
                # print the original line
                echo $line
                continue
            end

            if test $__fish_breeze_show_num_before_fname = "true"
                # This is to place number right before the filename
                string replace -f "$file" "[$idx] $file" $line

            else
                # This is to place number right after the first ANSI escape color code

                # this finds the index of the starting color code, in the format of:
                # i j   ->  where i is the starting idx of the token and j is the length
                if set -l start_color_code (string match --index -r '\e\[[0-9;]+m' $line | string split ' ')

                    # line prefix (i.e. whitespace + colorcode)
                    set -l prefix (string sub --length (math "$start_color_code[1] + $start_color_code[2] - 1") $line)
                    # line main (i.e. file status + the suffix bits)
                    set -l suffix (string sub --start (math "$start_color_code[1] + $start_color_code[2]") $line)

                    printf $prefix"%s " (__breeze_light_helper_get_bracket_num $idx $num_files)
                    printf $suffix"\n"
                end
            end

        else
            # this line is not a file status line
            echo $line
        end
    end
end


function __breeze_light_parse_user_input -d "parse user's numeric input to breeze"
    # set -l file_names (git status --porcelain | string sub --start 4)
    set -l file_names (__breeze_light_get_filelist)

    set -l num_files (count $file_names)

    function __breeze_light_sanity_chk_start_num
        if not test $argv[1] -gt 0
            echo "[ERROR]: starting num '$argv[1]' must be > 0. Skipping."
            return 1
        end
        return 0
    end

    function __breeze_light_sanity_chk_end_num
        set -l num_files $argv[2]
        if not test $argv[1] -le $num_files 
            echo "[ERROR]: ending num '$argv[1]' must be <= range '$num_files'. Skipping."
            return 1
        end
        return 0
    end

    function __breeze_light_sanity_chk_start_end_num
        # ensure n is smaller than m
        if not test $argv[1] -lt $argv[2]
            echo "[ERROR]: starting num '$argv[1]' must be < ending num '$argv[2]'. Skipping."
            return 1
        end
        return 0
    end

    function __breeze_light_echo_range_files
        set -l start_n $argv[1]
        set -l end_n $argv[2]
        set -e argv[1]
        set -e argv[1]
        for i in (seq $start_n $end_n)
            echo $argv[$i]
        end
    end
    # set -l num_files $argv[1]

    set -l target_files

    for arg in $argv

        # for normal case of one single numeric
        if string match -q -r -- '^[0-9]+$' $arg
            __breeze_light_sanity_chk_start_num $arg
            or continue
            __breeze_light_sanity_chk_end_num $arg $num_files
            or continue
            
            echo $file_names[$arg]

        # for case n-m
        else if string match -q -r -- '^[0-9]+-[0-9]+$' $arg
            set -l idxes (string split '-' $arg)
            __breeze_light_sanity_chk_start_end_num $idxes[1] $idxes[2]
            or continue
            __breeze_light_sanity_chk_start_num $idxes[1]
            or continue
            __breeze_light_sanity_chk_end_num $idxes[2] $num_files
            or continue

            __breeze_light_echo_range_files $idxes[1] $idxes[2] $file_names

        # for case n- (implied end)
        else if string match -q -r -- '^[0-9]+-$' $arg
            # ensure n is > 0
            set arg (string sub --length (math (string length -- $arg)"-1") -- $arg)

            __breeze_light_sanity_chk_start_num $arg
            or continue
            __breeze_light_sanity_chk_end_num $arg $num_files
            or continue
          
            __breeze_light_echo_range_files $arg $num_files $file_names

        # for case -m (implied start)
        else if string match -q -r -- '^-[0-9]+$' $arg
            # ensure m is < num_files
            set arg (string sub --start 2 -- $arg)

            __breeze_light_sanity_chk_start_num $arg
            or continue
            __breeze_light_sanity_chk_end_num $arg $num_files
            or continue
          
            __breeze_light_echo_range_files 1 $arg $file_names

        # probably is file name
        else
            echo $arg
        end

    end
end
