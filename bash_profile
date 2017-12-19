[ -z "$PS1" ] && return

# Ignore same successive entries and entries that start with space. See bash(1) for more options
export HISTCONTROL=ignoreboth
export HISTSIZE=5000
export HISTFILESIZE=5000

export LC_CTYPE=en_US.UTF-8
export CLICOLOR=1

source "${HOME}/.git-completion.bash"
source "${HOME}/.git-prompt.sh"
source "${HOME}/.config/bash/iterm2_shell_integration.bash"
export GIT_PS1_SHOWDIRTYSTATE='yep'

export TERM=xterm-256color

PS1='\[\e[34;1m\]\t \[\e[33;1m\][\h \[\e[37;1m\]\W\[\e[33;1m\]] \[\e[35;1m\]$(__git_ps1 "(%s)") \[\e[31;1m\]\$ \[\e[0m\]'


alias ls='ls -G'
alias grep='grep --color=auto'

if [ -d "${HOME}/.pyenv" ] >/dev/null; then
  export PATH="${HOME}/.pyenv/bin:${PATH}"
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)"
fi

export GEM_HOME="${HOME}/.gem"
if [ -d "${GEM_HOME}/bin" ] >/dev/null; then
  export PATH="${GEM_HOME}/bin:${PATH}"
fi

if [ -d "${HOME}/Documents/go" ] >/dev/null; then
  export GOPATH="${HOME}/Documents/go"
  export PATH="${GOPATH}/bin:${PATH}"
fi

if [ -d "${HOME}/.swiftenv/" ] >/dev/null; then
    export SWIFTENV_ROOT="${HOME}/.swiftenv"
    export PATH="${SWIFTENV_ROOT}/bin:${PATH}"
    eval "$(swiftenv init -)"
fi

if [ -d "${HOME}/.rbenv" ] > /dev/null; then
    export PATH="${HOME}/.rbenv/bin:${PATH}"
    eval "$(rbenv init -)"
fi

if [ -d "${HOME}/workspace/Cappuccino" ] > /dev/null;
then
    export NARWHAL_ENGINE=jsc
    export PATH="${HOME}/workspace/Cappuccino/narwhal/bin:$PATH"
    export CAPP_BUILD="${HOME}/workspace/Cappuccino/Build"
fi

if [ -d "${HOME}/workspace/bin" ] > /dev/null; then
    export PATH="${HOME}/workspace/bin:${PATH}"
fi

export EDITOR="vim"
export DIFF_VIEWER="vimdiff"

if [ "$(uname)" == "Darwin" ];
then
  export DIFF_VIEWER="ksdiff"
  export JAVA_HOME=$(/usr/libexec/java_home -v 1.8)
  if [ -f "$(brew --prefix)/etc/bash_completion" ]; then
    . "$(brew --prefix)/etc/bash_completion"
  fi
fi

shipped() {
    BRANCH=$(git branch | grep \* | awk '{print $2}')
    echo "Deleting ${BRANCH}"
    git checkout master
    git branch -D "${BRANCH}"
    git pull origin master
}

# Totally put this into a buddy's bashrc if they leave their screen unlocked
#osascript -e 'say "linux" using "Zarvox"'

# Work-related
alias ops7='ssh -a ops7'
if [ -d "${HOME}/workspace" ] >/dev/null; then
  cleanup_repo () {
    cd "${1}" || exit
    CURRENT_BRANCH=$( git branch | grep '\*' | awk '{ print $2 }')
    git checkout master
    git pull origin master
    git remote prune origin
    for branch in $(git branch --merged master | grep -v master)
    do
      git branch -D "${branch}"
    done
    git checkout "${CURRENT_BRANCH}"
  }
  update_repos () {
    (
      cleanup_repo "${HOME}/workspace/chef-repo"
      cleanup_repo "${HOME}/workspace/docs"
      cleanup_repo "${HOME}/workspace/webapp"
      cleanup_repo "${HOME}/workspace/JavaBackend"
      cleanup_repo "${HOME}/workspace/auth.tinyspeck.com"
      cleanup_repo "${HOME}/workspace/wwwTSAuth"
      cleanup_repo "${HOME}/workspace/checkpoint"
      cleanup_repo "${HOME}/workspace/data-java"
      cleanup_repo "${HOME}/workspace/data-etl"
      cleanup_repo "${HOME}/workspace/deploy.tinyspeck.com"
      cleanup_repo "${HOME}/workspace/flannel"
      cleanup_repo "${HOME}/workspace/slack-objc"
      cleanup_repo "${HOME}/workspace/slauth"
    )
  }
fi

if [ "$(hostname)" = 'ops7' -o "$(hostname)" = 'ops9' ];
then
  # Use local SSH Key
  unset SSH_AUTH_SOCK
  for PATHNAME in "/tmp/ssh-"*"/agent."* "/var/folders/"*"/"*"/"*"/ssh-"*"/agent."*
  do
      if [ ! -w "$PATHNAME" ]
      then continue
      fi
      if [ "$(SSH_AUTH_SOCK="$PATHNAME" ssh-add -l 2>&1)" != "Could not open a connection to your authentication agent." ]
      then export SSH_AUTH_SOCK="$PATHNAME"
      else
          rm -f "$PATHNAME"
          rmdir "$(dirname "$PATHNAME")" 2>"/dev/null" || :
      fi
  done
  if [ -z "$SSH_AUTH_SOCK" ]
  then
      eval "$(ssh-agent)"
      ssh-add
  fi
  if [ "$SSH_AUTH_SOCK" != "$HOME/.ssh/agent" ]
  then ln -fs "$SSH_AUTH_SOCK" "$HOME/.ssh/agent"
  fi
  export SSH_AUTH_SOCK="$HOME/.ssh/agent"


  # Go Bootstrapping
  export GOROOT="${HOME}/go"
  export PATH="${HOME}/go/bin:${PATH}"
fi
