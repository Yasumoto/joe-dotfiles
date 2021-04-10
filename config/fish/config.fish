function fish_greeting
    fortune
end

set fish_function_path $fish_function_path "/usr/local/lib/python3.9/site-packages/powerline/bindings/fish"
powerline-setup

set PATH $PATH "$HOME/.local/bin"
