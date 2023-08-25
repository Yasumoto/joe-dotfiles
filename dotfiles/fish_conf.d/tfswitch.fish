if not command -s tfswitch > /dev/null
    exit 0
end

function switch_terraform --on-event fish_postexec
    string match --regex '^cd\s' "$argv" > /dev/null
    set --local is_command_cd $status

    string match --regex '^z\s' "$argv" > /dev/null
    set --local is_command_zoxide $status

    if test $is_command_cd -eq 0 || test $is_command_zoxide -eq 0
      if count *.tf > /dev/null

        grep -c "required_version" *.tf > /dev/null
        set --local tf_contains_version $status

        if test $tf_contains_version -eq 0
            command tfswitch -b ~/workspace/bin/terraform
        end
      end
    end
end
