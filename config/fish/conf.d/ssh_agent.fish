if status --is-login
    exit
end

set -e SSH_AUTH_SOCK

for PATHNAME in /tmp/ssh-*/agent.*
    # If this isn't writable by us, get outta here
    if [ ! -w $PATHNAME ];
        continue
    end

    if [ "(SSH_AUTH_SOCK=$PATHNAME ssh-add -l 2>&1)" != "Could not open a connection to your authentication agent" ];
        set -gx SSH_AUTH_SOCK $PATHNAME
    else
        rm -f $PATHNAME
        rmdir (dirname $PATHNAME) 2> /dev/null || : # If that didn't work, that's fine
    end
end

# Wasn't able to restore an existing agent
if [ -z $SSH_AUTH_SOCK ]
    eval (ssh-agent -c)

    if [ (uname) = "Darwin" ];
        ssh-add --apple-use-keychain
    else
        ssh-add
    end
end

if [ $SSH_AUTH_SOCK != "$HOME/.ssh/agent" ]
    ln -fs $SSH_AUTH_SOCK "$HOME/.ssh/agent"
end

set -gx SSH_AUTH_SOCK "$HOME/.ssh/agent"
