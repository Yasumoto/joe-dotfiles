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

sudo apt-get update

sudo apt-get upgrade

sudo apt install vim curl fish mosh tmux apt-transport-https \
	ca-certificates gnupg lsb-release gnome-common apt-file build-essential

sudo apt-file update

curl -L https://nixos.org/nix/install | sh -s -- --daemon

#if [ "${SHELL}" != "/usr/bin/fish" ]; then
#    echo "🐟 Correcting your default shell"
#    chsh -s /usr/bin/fish
#fi

if uname -r | grep -qi wsl; then
    echo "🪟🪟 You're on WSL!"
    echo "🖼️ Make sure you download the powerline-compatible font at:"
    echo "https://github.com/microsoft/cascadia-code/releases/tag/latest"
fi

#SCRIPT_DIRECTORY=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
#
#if [ "$(which irssi)" = "" ] > /dev/null; then
#    echo "🗣️ Setting irssi config, "
#    sudo apt install irssi
#    mkdir -p "${HOME}/.irssi"
#    IRSSI_CONFIG_PATH="${HOME}/.irssi/config"
#
#    echo "🆓 What's your LiberaChat nickserv password?"
#    read -r LIBERA_NICKSERV_PASSWORD
#
#    sed -e "s/LIBERA_NICKSERV_PASSWORD/${LIBERA_NICKSERV_PASSWORD}/g" "${SCRIPT_DIRECTORY}/irssi_config_template" | \
#       "${SCRIPT_DIRECTORY}/irssi_config"
#    rm -rf "${IRSSI_CONFIG_PATH}"
#    /bin/ln -s "${SCRIPT_DIRECTORY}/irssi_config" "${IRSSI_CONFIG_PATH}"
#fi

fish -c "clone https://github.com/arcticicestudio/nord-gnome-terminal.git"

echo "Manual 1password install required:"
echo "https://support.1password.com/install-linux/"

echo "🐧 All set!"
