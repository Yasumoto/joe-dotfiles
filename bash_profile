[ -z "$PS1" ] && return

# Ignore same successive entries and entries that start with space. See bash(1) for more options
export HISTCONTROL=ignoreboth
export HISTSIZE=5000
export HISTFILESIZE=5000

export LC_CTYPE=en_US.UTF-8
export CLICOLOR=1

source "${HOME}/.git-completion.bash"
source "${HOME}/.git-prompt.sh"
export GIT_PS1_SHOWDIRTYSTATE='yep'

PS1='\[\e[34;1m\]\t \[\e[33;1m\][\h \[\e[37;1m\]\W\[\e[33;1m\]] \[\e[35;1m\]$(__git_ps1 "(%s)") \[\e[31;1m\]\$ \[\e[0m\]'


alias ls='ls -G'
alias grep='grep --color=auto'

if [ -d "${HOME}/.pyenv" ] >/dev/null; then
  export PATH="${HOME}/.pyenv/bin:${PATH}"
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)"
fi

if [ -d "${HOME}/.gem/ruby/2.0.0/bin" ] >/dev/null; then
  export PATH="${HOME}/.gem/ruby/2.0.0/bin:${PATH}"
fi

if [ -d "${HOME}/Documents/go" ] >/dev/null; then
  export GOPATH=${HOME}/Documents/go
  export PATH="${GOPATH}/bin:${PATH}"
fi

if [ -d "${HOME}/workspace" ] >/dev/null; then
  cleanup_repo () {
    CURRENT_BRANCH=$( git branch | grep \* | awk '{ print $2 }')
    cd "${1}"; git checkout master; git pull origin master; git remote prune origin; git checkout "${CURRENT_BRANCH}"
  }
  update_repos () {
    $(
      cleanup_repo "${HOME}/workspace/chef-repo"
      cleanup_repo "${HOME}/workspace/docs"
      cleanup_repo "${HOME}/workspace/webapp"
      cleanup_repo "${HOME}/workspace/JavaBackend"
    )
  }
fi

export EDITOR="vim"
export DIFF_VIEWER="vimdiff"

if [ $(uname) == "Darwin" ];
then
  export DIFF_VIEWER="ksdiff"
  export JAVA_HOME=$(/usr/libexec/java_home -v 1.8)
  if [ -f $(brew --prefix)/etc/bash_completion ]; then
    . $(brew --prefix)/etc/bash_completion
  fi
fi

if [ $(hostname) = 'ops7' ];
then
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
  export GOROOT="${HOME}/go"
  export PATH="${HOME}/go/bin:${PATH}"
fi

# Totally put this into a buddy's bashrc if they leave their screen unlocked
#osascript -e 'say "linux" using "Zarvox"'
