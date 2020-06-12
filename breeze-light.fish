
function __fish_breeze_get_file_idx
    # set file_status (git status --porcelain)
    set file_status (git status --porcelain)
    # echo $file_status

    set -l file_names

    for line in $file_status
        # in git status --porcelain, the first two character is for
        # file status, and the third is a space. This is consistent,
        # so we can simply use substring rather than complex regex
        set -a file_names (string sub --start 4 $line )
    end

    # for file in $file_names
    #     set -l idx (contains -i -- $file $file_names)
    #     echo "[$idx] $file"
    # end

    return file_names
end

function breeze
    # if true, place [n] in front of the filename
    # else, place in front of the entire status.
    set -q __fish_breeze_num_before_filename
    or set -g __fish_breeze_num_before_filename "false"

    set -l file_names __fish_breeze_get_file_idx

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
            set -l idx 1
            set -l found false
            for file in $file_names
                if test $__fish_breeze_num_before_filename = "true"
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
                set idx (math "$idx + 1")
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