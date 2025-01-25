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

git submodule init
git submodule update

if grep -q fedora /etc/os-release; then
	sudo dnf update
elif [ "$(uname)" = "Darwin" ]; then
	# System defaults from
	# https://github.com/mathiasbynens/dotfiles/blob/master/.macos

	# Disable the sound effects on boot
	sudo nvram SystemAudioVolume=" "

	# Expand save panel by default
	defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
	defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

	# Disable automatic capitalization as it’s annoying when typing code
	defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

	# Disable smart quotes as they’re annoying when typing code
	defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

	# Disable auto-correct
	defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

	# Trackpad: enable tap to click for this user and for the login screen
	defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
	defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
	defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

	# Display full POSIX path as Finder window title
	defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

	# Show the ~/Library folder
	chflags nohidden ~/Library

	# Enable the debug menu in Disk Utility
	defaults write com.apple.DiskUtility DUDebugMenuEnabled -bool true
	defaults write com.apple.DiskUtility advanced-image-options -bool true

else
	sudo apt-get update
	sudo apt-get upgrade
	sudo apt install vim curl fish mosh tmux apt-transport-https \
		ca-certificates gnupg lsb-release apt-file build-essential
		#gnome-shell-extensions gnome-common gnome-tweaks # if you're on gnome

	sudo apt-file update
fi

#if [ "${SHELL}" != "/usr/bin/fish" ]; then
#    echo "🐟 Correcting your default shell"
#    chsh -s /usr/bin/fish
#fi

if uname -r | grep -qi wsl; then
    echo "🪟🪟 You're on WSL!"
    echo "🖼️ Make sure you download the powerline-compatible font at:"
    echo "https://github.com/microsoft/cascadia-code/releases/tag/latest"
fi

if [ "$(which nix)" != "" ] > /dev/null; then

	# Home Manager
	# https://nix-community.github.io/home-manager/index.xhtml#sec-install-standalone
	if [ "$(which home-manager)" = "" ] > /dev/null; then
	nix-channel --add https://github.com/nix-community/home-manager/archive/release-24.11.tar.gz home-manager
	nix-channel --update

	nix-shell '<home-manager>' -A install
	fi

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

#fish -c "clone https://github.com/arcticicestudio/nord-gnome-terminal.git"

set +x
echo "************************"

echo "Manual 1password install required:"
echo "https://support.1password.com/install-linux/"
echo

echo "https://wiki.gnome.org/action/show/Projects/GnomeShellIntegration/Installation?action=show&redirect=Projects%2FGnomeShellIntegrationForChrome%2FInstallation#Meson_installation"
echo "https://extensions.gnome.org/extension/779/clipboard-indicator/"

echo "home-manager -b gimmehjimmeh switch -f ~/workspace/github.com/Yasumoto/joe-dotfiles/home.nix"

echo "All set!"
