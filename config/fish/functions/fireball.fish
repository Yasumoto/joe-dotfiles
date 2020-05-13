function fireball
    echo "Blowing away most conflicts"
    git branch
    git status
    git reset --hard HEAD
    git status
    git status | grep '/' | tr -d '\t' | grep -v modified | xargs rm -r
    git status
end
