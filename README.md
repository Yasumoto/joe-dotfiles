🚀 joe-dotfiles
===============

A collection of basic dot files

## 🍎 macOS

Run `./bootstrap_macOS.sh`, which will also call `./bootstrap_homedir_config_files.sh`

## 🐧 Ubuntu

```sh
sudo apt install git xclip
ssh-keygen -t ed25519 -C "yasumoto+$(hostname)"
cat ~/.ssh/id_ed25519.pub | xclip -sel clip
firefox https://github.com/settings/ssh/new
echo "🔐 Update your SSH key"
read

mkdir -p ~/workspace/github.com/Yasumoto
cd ~/workspace/github.com/Yasumoto
git clone git@github.com:Yasumoto/joe-dotfiles.git

cd ./joe-dotfiles
./bootstrap_linux.sh

./install_cli_tools.sh
```
