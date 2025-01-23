#!/bin/sh

if [ "$(which flatpak)" = "" ]; then
  sudo apt install flatpak

  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

  echo "Please reboot! Flathub should be wired up for ya."
fi

flatpak install -y flathub org.keepassxc.KeePassXC

#flatpak install -y flathub com.slack.Slack

flatpak install -y flathub re.sonny.Junction

flatpak install -y flathub de.haeckerfelix.Shortwave

#flatpak install -y flathub org.gnome.Solanum
#
#flatpak install -y flathub org.gnome.Builder
#
#flatpak install -y flathub com.rafaelmardojai.Blanket
#
#flatpak install -y flathub org.gnome.Connections

flatpak install -y flathub com.discordapp.Discord

flatpak install -y flathub com.valvesoftware.Steam

flatpak install -y flathub org.videolan.VLC

flatpak install -y flathub org.gimp.GIMP

#flatpak install -y flathub com.obsproject.Studio

flatpak install -y flathub org.gnome.Boxes

flatpak install -y flathub codes.merritt.FeelingFinder

# https://gitlab.com/azymohliad/watchmate
#flatpak install -y flathub io.gitlab.azymohliad.WatchMate

