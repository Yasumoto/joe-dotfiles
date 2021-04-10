function update_submodules
    echo "Updating submodules in this repo"
    git submodule foreach git pull origin master
end
