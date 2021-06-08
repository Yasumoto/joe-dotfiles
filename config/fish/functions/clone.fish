function clone
    set LOCATION $argv[1]
    if echo $LOCATION | grep -q https
        echo "Need to build transform"
        return
    end

    set PROVIDER (echo $LOCATION | cut -f1 -d: | cut -f2 -d\@)
    set OWNER (echo $LOCATION | cut -f2 -d: | cut -f1 -d/)
    set REPO (echo $LOCATION | cut -f2 -d: | cut -f2 -d/ | cut -f1 -d.)

    set FILESYSTEM_LOCATION "/home/$USER/workspace/$PROVIDER/$OWNER"
    mkdir -p "$FILESYSTEM_LOCATION"
    git clone "$LOCATION" "$FILESYSTEM_LOCATION/$REPO"
end
