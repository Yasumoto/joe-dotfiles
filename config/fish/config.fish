set -U EDITOR vim # WSL Ubuntu 20.04 needs this?

function fish_greeting
    neofetch
    echo
    fortune
    echo
end


if [ -d /usr/local/lib/python3.9/site-packages/powerline/bindings/fish ]
    set fish_function_path $fish_function_path /usr/local/lib/python3.9/site-packages/powerline/bindings/fish
end
if [ -d /usr/share/powerline/bindings/fish ]
    set fish_function_path $fish_function_path /usr/share/powerline/bindings/fish
    powerline-setup
end


set PATH $PATH "$HOME/.local/bin" "$HOME/workspace/go/bin" "$HOME/workspace/bin"

# https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#post-installation-actions
if [ -d /usr/local/cuda-11.3/bin ]
    set PATH $PATH "$HOME/.local/bin" /usr/local/cuda-11.3/bin
    set LD_LIBRARY_PATH "/usr/local/cuda-11.3/lib64:$LD_LIBRARY_PATH"
end
