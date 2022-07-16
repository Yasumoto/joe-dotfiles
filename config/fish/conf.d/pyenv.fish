if uname -r | grep -qi wsl
    exit 0
end

if test -d "$HOME"/.pyenv/bin
    set PATH "$HOME"/.pyenv/bin $PATH
end

if not command -s pyenv > /dev/null
    echo "pyenv not found"
    exit 1
end

set -l pyenv_root ""

if test -z "$PYENV_ROOT"
    set pyenv_root ~/.pyenv
    set -gx PYENV_ROOT "$pyenv_root"
else
    set pyenv_root "$PYENV_ROOT"
end

if status --is-login
    set -x PATH "$pyenv_root/shims" $PATH
    set -x PYENV_SHELL fish
end
command mkdir -p "$pyenv_root/"{shims,versions}

pyenv init - | source
