joe-dotfiles
============

A collection of basic dot files

## macOS

Run `./bootstrap_macOS.sh`, which will also call `./bootstrap_homedir_config_files.sh`

## Ubuntu

```sh
sudo apt install git
ssh-keygen -t ed25519 -C "yasumoto7+$(hostname)@gmail.com"
mkdir -p ~/workspace/github.com/Yasumoto
cd ~/workspace/github.com/Yasumoto
git clone git@github.com:Yasumoto/joe-dotfiles.git
./bootstrap_linux.sh
```
