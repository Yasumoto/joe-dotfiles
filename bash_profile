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

# Totally put this into a buddy's bashrc if they leave their screen unlocked
#osascript -e 'say "linux" using "Zarvox"'
