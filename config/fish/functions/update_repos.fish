function cleanup_repo
    echo $argv[1]
    cd $argv[1]; or return
    set CurrentBranch ( git branch | grep '\*' | awk '{ print $2 }')
    git checkout master
    git pull origin master
    git remote prune origin
    for branch in (git branch --merged master | grep -v master )
        git branch -D $branch
    end
    git checkout $CurrentBranch
end

function update_repos
    set CurrentDirectory (pwd)
    cleanup_repo $HOME"/workspace/chef-repo"
    cleanup_repo $HOME"/workspace/docs"
    cleanup_repo $HOME"/workspace/webapp"
    cleanup_repo $HOME"/workspace/JavaBackend"
    cleanup_repo $HOME"/workspace/deploy.tinyspeck.com"
    cleanup_repo $HOME"/workspace/wwwTSAuth"
    cleanup_repo $HOME"/workspace/slack-objc"
    cleanup_repo $HOME"/workspace/auth.tinyspeck.com"
    cleanup_repo $HOME"/workspace/checkpoint"
    cleanup_repo $HOME"/workspace/data-java"
    cleanup_repo $HOME"/workspace/data-etl"
    cleanup_repo $HOME"/workspace/flannel"
    cleanup_repo $HOME"/workspace/slauth"
    cleanup_repo $HOME"/workspace/Baseline/swift-corelibs-foundation"
    cleanup_repo $HOME"/workspace/Baseline/swift-package-manager"
    cd $CurrentDirectory
end
