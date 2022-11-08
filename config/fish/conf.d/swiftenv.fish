# https://swiftenv.fuller.li/en/latest/installation.html#via-a-git-clone
set -gx SWIFTENV_ROOT "$HOME/.swiftenv"

set -gx PATH "$SWIFTENV_ROOT/bin" $PATH

if which swiftenv > /dev/null;
    status --is-interactive; and source (swiftenv init -|psub);
end
