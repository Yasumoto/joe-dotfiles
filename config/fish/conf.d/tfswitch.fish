if not command -s tfswitch > /dev/null
    echo "tfswitch not found"
    exit 1
end

function switch_terraform --on-event fish_postexec
    string match --regex '^cd\s' "$argv" > /dev/null
    set --local is_command_cd $status

    if test $is_command_cd -eq 0
      if count *.tf > /dev/null

        grep -c "required_version" *.tf > /dev/null
        set --local tf_contains_version $status

        if test $tf_contains_version -eq 0
            command tfswitch
        end
      end
    end
end
