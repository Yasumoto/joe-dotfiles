#function fish_prompt
    # https://github.com/justjanne/powerline-go
#    eval /usr/local/bin/powerline-go -cwd-mode dironly -hostname-only-if-ssh -error $status -jobs (jobs -p | wc -l)
#end

set fish_function_path $fish_function_path "/usr/local/lib/python3.9/site-packages/powerline/bindings/fish"
powerline-setup
