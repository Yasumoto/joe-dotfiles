#!/bin/sh

# Setup a development Ubuntu box (should also work with WSL)

set -eux

sudo apt-get update

sudo apt-get upgrade

sudo apt-get install fish jq fortune-mod nmap nghttp2-client shellcheck pipenv powerline neofetch

chsh -s /usr/bin/fish

./_bootstrap_homedir_config_files.sh

./oh-my-fish/bin/install --offline

if uname -r | grep -qi wsl; then
    echo "Make sure you download the powerline-compatible font at:"
    echo "https://github.com/microsoft/cascadia-code/releases/tag/latest"
fi
