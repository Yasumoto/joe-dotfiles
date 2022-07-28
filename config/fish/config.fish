set -Ux EDITOR vim # WSL Ubuntu 20.04 needs this?

set -gx GPG_TTY (tty)

function fish_greeting
    if command -v fortune > /dev/null
        echo
        fortune
    end
    echo
end

function potentially_update_path
    if [ -d "$argv" ]
        set PATH $PATH "$argv"
    end
end

potentially_update_path "$HOME/.local/bin"
potentially_update_path "$HOME/.cargo/bin"
potentially_update_path "$HOME/workspace/go/bin"
potentially_update_path "$HOME/workspace/bin"
potentially_update_path "/opt/homebrew/bin"
potentially_update_path "$HOME/src/sw/ops/bin/cache"

# For LIMS
potentially_update_path "$HOME/.rbenv/versions/2.5.9/bin"
potentially_update_path "$HOME/.gem/ruby/2.5.0/bin"

if [ -d $HOME/.pyenv ]
  status is-login; and pyenv init --path | source
  status is-interactive; and pyenv init - | source
end

if [ -d "$HOME/n" ]
  set -x N_PREFIX "$HOME/n"; contains "$N_PREFIX/bin" $PATH; or set -a PATH "$N_PREFIX/bin"  # Added by n-install (see http://git.io/n-install-repo).
end

# Ubuntu
#if [ -d /usr/local/lib/python3.9/site-packages/powerline/bindings/fish ]
#    set fish_function_path $fish_function_path /usr/local/lib/python3.9/site-packages/powerline/bindings/fish
#end
#if [ -d /usr/share/powerline/bindings/fish ]
#    set fish_function_path $fish_function_path /usr/share/powerline/bindings/fish
#    powerline-setup
#end

# macOS
#if [ -d /Users/$USER/Library/Python/3.8/lib/python/site-packages ]
#    set fish_function_path $fish_function_path /Users/$USER/Library/Python/3.8/lib/python/site-packages/powerline/bindings/fish
#end
#if [ -d /Users/joesmith/Library/Python/3.8/bin ]
#    set PATH $PATH /Users/$USER/Library/Python/3.8/bin
#    powerline-setup
#end


# https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#post-installation-actions
if [ -d /usr/local/cuda-11.3/bin ]
    set PATH $PATH "$HOME/.local/bin" /usr/local/cuda-11.3/bin
    set LD_LIBRARY_PATH "/usr/local/cuda-11.3/lib64:$LD_LIBRARY_PATH"
end

starship init fish | source
zoxide init fish | source
