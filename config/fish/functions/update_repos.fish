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
    cleanup_repo $HOME"/workspace/slack/chef-repo"
    cleanup_repo $HOME"/workspace/slack/docs"
    cleanup_repo $HOME"/workspace/slack/webapp"
    cleanup_repo $HOME"/workspace/slack/JavaBackend"
    cleanup_repo $HOME"/workspace/slack/deploy.tinyspeck.com"
    cleanup_repo $HOME"/workspace/slack/slack-objc"
    cleanup_repo $HOME"/workspace/slack/auth.tinyspeck.com"
    cleanup_repo $HOME"/workspace/slack/checkpoint"
    cleanup_repo $HOME"/workspace/slack/data-java"
    cleanup_repo $HOME"/workspace/slack/data-etl"
    cleanup_repo $HOME"/workspace/slack/flannel"
    cleanup_repo $HOME"/workspace/slack/slauth"
    cleanup_repo $HOME"/workspace/boto/boto3"
    cleanup_repo $HOME"/workspace/swift-aws/aws-sdk-swift-core"
    cleanup_repo $HOME"/workspace/swift-aws/aws-sdk-swift"
    cleanup_repo $HOME"/workspace/apple/swift-corelibs-foundation"
    cleanup_repo $HOME"/workspace/apple/swift-package-manager"
    cleanup_repo $HOME"/workspace/apple/swift-llbuild"
    cleanup_repo $HOME"/workspace/apple/swift-nio"
    cleanup_repo $HOME"/workspace/apple/swift-nio-ssl"
    cd $CurrentDirectory
end
