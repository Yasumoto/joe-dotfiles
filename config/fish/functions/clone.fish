function clone
    set LOCATION $argv[1]
    if echo $LOCATION | grep -q https
        set PROVIDER (echo $LOCATION | cut -f3 -d/ | tr -d '[:space:]' )
        set OWNER (echo $LOCATION | cut -f4 -d/ )
        set REPO (echo $LOCATION | cut -f5 -d/ )
    else
        set PROVIDER (echo $LOCATION | cut -f1 -d: | cut -f2 -d\@)
        set OWNER (echo $LOCATION | cut -f2 -d: | cut -f1 -d/)
        set REPO (echo $LOCATION | cut -f2 -d: | cut -f2 -d/ | cut -f1 -d.)
    end

    set FILESYSTEM_LOCATION "/home/$USER/workspace/$PROVIDER/$OWNER"
    mkdir -p "$FILESYSTEM_LOCATION"
    git clone "$LOCATION" "$FILESYSTEM_LOCATION/$REPO"
end
