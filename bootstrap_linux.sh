#!/bin/sh
#
#/ Usage: bootstrap_linux.sh
#/
#/ Setup a development Ubuntu box (should also work with WSL)
#/

usage() {
    grep "^#/" "$0" | cut -c"4-" >&2
    exit "$1"
}

while [ "$#" -gt 0 ]
do
    case "$1" in
        -h|--help) usage 0;;
        -*) usage 1;;
        *) break;;
    esac
done

set -eux

SCRIPT_DIRECTORY=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

sudo apt-get update

sudo apt-get upgrade

sudo apt-get install vim fish jq fortune-mod nmap nghttp2-client shellcheck pipenv powerline \
    neofetch curl fonts-cascadia-code tmux mosh apt-transport-https ca-certificates gnupg \
    lsb-release gnome-common gawk golang gopls


if [ "$SHELL" != "/usr/bin/fish" ]; then
    echo "🐟 Correcting your default shell"
    chsh -s /usr/bin/fish
fi

./_bootstrap_homedir_config_files.sh

if [ ! -d "/home/${USER}/.local/share/omf" ]; then
    ./oh-my-fish/bin/install --offline
else
    echo "🐟 Already installed oh-my-fish"
fi

if uname -r | grep -qi wsl; then
    echo "🪟🪟 You're on WSL!"
    echo "🖼️ Make sure you download the powerline-compatible font at:"
    echo "https://github.com/microsoft/cascadia-code/releases/tag/latest"
else
    if [ "$(which code)" = "" ] && command -v gnome-shell > /dev/null; then
        echo "🐧 ⚒️ You're on a real box, let's get vscode setup"
        if command -v snap > /dev/null; then
            sudo snap install --classic code
        else
            curl -L "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" -o ~/Downloads/vscode.deb
            sudo apt install ~/Downloads/vscode.deb
        fi
    fi
fi

if command -v dconf > /dev/null; then
    PROFILE_ID="$(dconf list /org/gnome/terminal/legacy/profiles:/)"
    if [ "${PROFILE_ID}" != "" ]; then
        dconf write "/org/gnome/terminal/legacy/profiles:/${PROFILE_ID}font" '"Cascadia Code PL 14"'
        dconf write "/org/gnome/terminal/legacy/profiles:/${PROFILE_ID}palette" "['rgb(7,54,66)', 'rgb(220,50,47)', 'rgb(133,153,0)', 'rgb(181,137,0)', 'rgb(38,139,210)', 'rgb(211,54,130)', 'rgb(42,161,152)', 'rgb(238,232,213)', 'rgb(0,43,54)', 'rgb(203,75,22)', 'rgb(88,110,117)', 'rgb(101,123,131)', 'rgb(131,148,150)', 'rgb(108,113,196)', 'rgb(147,161,161)', 'rgb(253,246,227)']"
    fi
fi

if [ "$(which irssi)" = "" ] > /dev/null; then
    echo "🗣️ Setting irssi config, "
    sudo apt install irssi
    mkdir -p "${HOME}/.irssi"
    IRSSI_CONFIG_PATH="${HOME}/.irssi/config"

    echo "🆓 What's your LiberaChat nickserv password?"
    read -r LIBERA_NICKSERV_PASSWORD
    echo "👣 What's your GIMPNet nickserv password?"
    read -r GIMPNET_NICKSERV_PASSWORD

    sed -e "s/LIBERA_NICKSERV_PASSWORD/${LIBERA_NICKSERV_PASSWORD}/g" "${SCRIPT_DIRECTORY}/irssi_config_template" | \
       sed -e "s/GIMPNET_NICKSERV_PASSWORD/${GIMPNET_NICKSERV_PASSWORD}/g" > \
       "${SCRIPT_DIRECTORY}/irssi_config"
    rm -rf "${IRSSI_CONFIG_PATH}"
    /bin/ln -s "${SCRIPT_DIRECTORY}/irssi_config" "${IRSSI_CONFIG_PATH}"
fi

echo "🐧 All set!"
