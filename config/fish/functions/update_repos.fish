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
    cleanup_repo $HOME"/workspace/slack-github.com/slack/chef-repo"
    cleanup_repo $HOME"/workspace/slack-github.com/slack/docs"
    cleanup_repo $HOME"/workspace/slack-github.com/slack/webapp"
    cleanup_repo $HOME"/workspace/slack-github.com/slack/JavaBackend"
    cleanup_repo $HOME"/workspace/slack-github.com/slack/deploy.tinyspeck.com"
    cleanup_repo $HOME"/workspace/slack-github.com/slack/auth.tinyspeck.com"
    cleanup_repo $HOME"/workspace/slack-github.com/slack/checkpoint"
    cleanup_repo $HOME"/workspace/slack-github.com/slack/data-java"
    cleanup_repo $HOME"/workspace/slack-github.com/slack/data-etl"
    cleanup_repo $HOME"/workspace/slack-github.com/slack/flannel"
    cleanup_repo $HOME"/workspace/slack-github.com/slack/slauth"
    cleanup_repo $HOME"/workspace/github.com/tinyspeck/slack-objc"
    cleanup_repo $HOME"/workspace/github.com/boto/boto3"
    cleanup_repo $HOME"/workspace/github.com/swift-aws/aws-sdk-swift-core"
    cleanup_repo $HOME"/workspace/github.com/swift-aws/aws-sdk-swift"
    cleanup_repo $HOME"/workspace/github.com/apple/swift-corelibs-foundation"
    cleanup_repo $HOME"/workspace/github.com/apple/swift-package-manager"
    cleanup_repo $HOME"/workspace/github.com/apple/llbuild"
    cleanup_repo $HOME"/workspace/github.com/apple/swift-nio"
    cleanup_repo $HOME"/workspace/github.com/apple/swift-nio-ssl"
    cd $CurrentDirectory
end
