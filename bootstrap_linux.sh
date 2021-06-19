#!/bin/sh

# Setup a development Ubuntu box (should also work with WSL)

set -eux

sudo apt-get update

sudo apt-get upgrade

sudo apt-get install vim fish jq fortune-mod nmap nghttp2-client shellcheck pipenv powerline neofetch curl fonts-cascadia-code

if command -v snap > /dev/null; then
    sudo snap install --classic code
else
    curl -L "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" -o ~/Downloads/vscode.deb
    sudo apt install ~/Downloads/vscode.deb
fi

chsh -s /usr/bin/fish

./_bootstrap_homedir_config_files.sh

./oh-my-fish/bin/install --offline

if uname -r | grep -qi wsl; then
    echo "Make sure you download the powerline-compatible font at:"
    echo "https://github.com/microsoft/cascadia-code/releases/tag/latest"
fi

if command -v dconf > /dev/null; then
    PROFILE_ID="$(dconf list /org/gnome/terminal/legacy/profiles:/)"
    dconf write "/org/gnome/terminal/legacy/profiles:/${PROFILE_ID}font" 'Cascadia Code PL 14'
    dconf write "/org/gnome/terminal/legacy/profiles:/${PROFILE_ID}palette" "['rgb(7,54,66)', 'rgb(220,50,47)', 'rgb(133,153,0)', 'rgb(181,137,0)', 'rgb(38,139,210)', 'rgb(211,54,130)', 'rgb(42,161,152)', 'rgb(238,232,213)', 'rgb(0,43,54)', 'rgb(203,75,22)', 'rgb(88,110,117)', 'rgb(101,123,131)', 'rgb(131,148,150)', 'rgb(108,113,196)', 'rgb(147,161,161)', 'rgb(253,246,227)']"
fi
