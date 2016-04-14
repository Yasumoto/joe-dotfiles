[ -z "$PS1" ] && return

# don't put duplicate lines in the history. See bash(1) for more options
export HISTCONTROL=ignoredups
# ... and ignore same sucessive entries.
export HISTCONTROL=ignoreboth
#Make history size way bigger
export HISTSIZE=5000
export HISTFILESIZE=5000

export LC_CTYPE=en_US.UTF-8
export CLICOLOR=1

source ~/.git-completion.bash
export GIT_PS1_SHOWDIRTYSTATE='yep'

PS1="\[\e[34;1m\]\t \[\e[33;1m\][\h \[\e[37;1m\]\W\[\e[33;1m\]] \[\e[35;1m\]$(__git_ps1 "(%s)") \[\e[31;1m\]\$ \[\e[0m\]"


alias ls='ls -G'
alias grep='grep --color=auto'

if which pyenv >/dev/null; then
  export PATH="${HOME}/.pyenv/bin:$PATH"
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)"
fi

export EDITOR="vim"
export DIFF_VIEWER="vimdiff"

# Weird workaround for git commit+certain vim plugins and exit code
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
