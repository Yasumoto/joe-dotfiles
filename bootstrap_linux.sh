#!/bin/sh

# Setup a development Ubuntu box (should also work with WSL)

sudo apt-get install fish jq fortune-mod nmap nghttp2-client shellcheck pipenv powerline

chsh -s /usr/bin/fish

./_bootstrap_homedir_config_files.sh

./oh-my-fish/bin/install --offline
