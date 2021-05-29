function fish_greeting
    echo
    fortune
    echo
end

set fish_function_path $fish_function_path "/usr/local/lib/python3.9/site-packages/powerline/bindings/fish"
set fish_function_path $fish_function_path "/usr/share/powerline/bindings/fish"
powerline-setup

set PATH $PATH "$HOME/.local/bin" "$HOME/workspace/go/bin" "$HOME/workspace/bin"
