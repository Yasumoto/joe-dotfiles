function shipped
    set BRANCH (git branch | grep \* | awk '{print $2}')
    echo "Deleting $BRANCH"
    git checkout master
    git branch -D $BRANCH
    git pull origin master
end
