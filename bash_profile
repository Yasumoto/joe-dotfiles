[ -z "$PS1" ] && return

# don't put duplicate lines in the history. See bash(1) for more options
export HISTCONTROL=ignoredups
# ... and ignore same sucessive entries.
export HISTCONTROL=ignoreboth
#Make history size way bigger
export HISTSIZE=5000
export HISTFILESIZE=5000

# Allow multiple bash instances to all update the same history file
# some tuxradar article about bash for power users.
shopt -s histappend

PS1='\[\e[34;1m\]\t \[\e[33;1m\]\W \[\e[35;1m\]\$ \[\e[0m\]'
PS1="\[\033[G\]$PS1"

alias ls='ls -G'

export PATH=/usr/local/bin:$PATH

# brew/apt-get install fortune
if which fortune &>/dev/null; then
	echo -e '\n'
	fortune -a
fi

# Weird workaround for git commit+certain vim plugins and exit code
if [ $(uname) == "Darwin" ];
then
  export EDITOR="mvim -f"
fi

alias gc='git commit -a -s -m'

export NODE_PATH="/usr/local/lib/node_modules"

# Totally put this into a buddy's bashrc if they leave their screen unlocked
#osascript -e 'say "linux" using "Zarvox"'
