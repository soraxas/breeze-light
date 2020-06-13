

function breeze
    # if true, place [n] in front of the filename
    # else, place in front of the entire status.
    set -q __fish_breeze_show_num_before_fname
    or set -g __fish_breeze_show_num_before_fname "false"

    # get file status from git
    # in git status --porcelain, the first two character is for
    # file status, and the third is a space. This is consistent,
    # so we can simply use substring rather than complex regex
    set -l file_names (git status --porcelain | string sub --start 4)

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
            set -l idx 0
            set -l found false
            for file in $file_names
                set -l idx (math "$idx + 1")

                # check if this line contain the proposing file
                if not string match -q "*$file*" "$line"
                    continue
                end

                if test $__fish_breeze_show_num_before_fname = "true"
                    # This is to place number right before the filename
                    if string replace -f "$file" "[$idx] $file" $line
                        set found true
                        break
                    end

                else
                    # This is to place number right after the first ANSI escape color code

                    # this finds the index of the starting color code, in the format of:
                    # i j   ->  where i is the starting idx of the token and j is the length
                    if set -l start_color_code (string match --index -r '\e\[[0-9;]+m' $line | string split ' ')

                        # line prefix (i.e. whitespace + colorcode)
                        set -l prefix (string sub --length (math "$start_color_code[1] + $start_color_code[2] - 1") $line)
                        # line main (i.e. file status + the suffix bits)
                        set -l suffix (string sub --start (math "$start_color_code[1] + $start_color_code[2]") $line)

                        printf $prefix"[$idx] "
                        printf $suffix"\n"

                        set found true
                        break
                    end
                end
            end
            # if no action were able to perform, print the original line
            not $found
            and echo $line

        else
            # this line is not a file status line
            echo $line
        end
    end
end

breeze



function parse_user_input

    set -l file_names (git status --porcelain | string sub --start 4)

    set num_files (count $file_names)


    function __breeze_sanity_chk_start_num
        if not test $argv[1] -gt 0
            echo "[ERROR]: starting num '$argv[1]' must be > 0. Skipping."
            return 1
        end
        return 0
    end

    function __breeze_sanity_chk_end_num
        set -l num_files $argv[2]
        if not test $argv[1] -le $num_files 
            echo "[ERROR]: ending num '$argv[1]' must be <= range '$num_files'. Skipping."
            return 1
        end
        return 0
    end

    function __breeze_sanity_chk_start_end_num
        # ensure n is smaller than m
        if not test $argv[1] -lt $argv[2]
            echo "[ERROR]: starting num '$argv[1]' must be < ending num '$argv[2]'. Skipping."
            return 1
        end
        return 0
    end

    function __breeze_echo_range_files
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
            set -a target_files (echo $file_names[$arg])

        # for case n-m
        else if string match -q -r -- '^[0-9]+-[0-9]+$' $arg
            set -l idxes (string split '-' $arg)
            __breeze_sanity_chk_start_end_num $idxes[1] $idxes[2]
            or continue
            __breeze_sanity_chk_start_num $idxes[1]
            or continue
            __breeze_sanity_chk_end_num $idxes[2] $num_files
            or continue

            set -a target_files (__breeze_echo_range_files $idxes[1] $idxes[2] $file_names)

        # for case n- (implied end)
        else if string match -q -r -- '^[0-9]+-$' $arg
            # ensure n is > 0
            set arg (string sub --length (math (string length -- $arg)"-1") -- $arg)

            __breeze_sanity_chk_start_num $arg
            or continue
            __breeze_sanity_chk_end_num $arg $num_files
            or continue
          
            set -a target_files (__breeze_echo_range_files $arg $num_files $file_names)

        # for case -m (implied start)
        else if string match -q -r -- '^-[0-9]+$' $arg
            # ensure m is < num_files
            set arg (string sub --start 2 -- $arg)

            __breeze_sanity_chk_start_num $arg
            or continue
            __breeze_sanity_chk_end_num $arg $num_files
            or continue
          
            set -a target_files (__breeze_echo_range_files 1 $arg $file_names)

        # probably is file name
        else
            set -a target_files $arg
        end

        # echo $arg
    end
    echo $target_files
end
