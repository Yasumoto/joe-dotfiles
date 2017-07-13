function connect
    set newHostname $argv[1]
    scp ~/.config/bash/iterm2_shell_integration.bash $newHostname:
    ssh $newHostname "echo 'source /home/jmsmith/iterm2_shell_integration.bash' >> /home/jmsmith/.bashrc"
    ssh $newHostname
end
