🚀 joe-dotfiles
===============

A collection of basic dot files managed via [home-manager](https://github.com/nix-community/home-manager).


```sh
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# sudo apt install git xclip
ssh-keygen -t ed25519 -C "yasumoto7+$(hostname)@gmail.com"
cat ~/.ssh/id_ed25519.pub | xclip -sel clip


mkdir -p ~/workspace/github.com/Yasumoto
cd ~/workspace/github.com/Yasumoto
git clone git@github.com:Yasumoto/joe-dotfiles.git
cd joe-dotfiles

# Choose the appropriate configuration for your system:
# Linux:
nix run home-manager/release-25.11 -- switch --flake ~/workspace/github.com/Yasumoto/joe-dotfiles#linux

# macOS (personal):
nix run home-manager/release-25.11 -- switch --flake ~/workspace/github.com/Yasumoto/joe-dotfiles#joe

# macOS (corp):
nix run home-manager/release-25.11 -- switch --flake ~/workspace/github.com/Yasumoto/joe-dotfiles#joe.smith

prek install
```

### 🐧 Linux Extras

```sh
./install_flatpaks.sh
```

### Grub Themes

See [Gorgeous GRUB](https://github.com/Jacksaur/Gorgeous-GRUB)!

#### Virtuaverse
https://www.reddit.com/r/unixporn/comments/m5522z/grub2_had_some_fun_with_grub/
https://github.com/Patato777/dotfiles

Original Size:

```
GRUB_GFXMODE="1440x900x24"
```

#### Mario

https://www.reddit.com/r/unixporn/comments/oetme1/grub2_made_a_mario_theme/
https://github.com/Crylia/dotfiles

In the theme, font from 24 to:

```
"Super Mario Land (Game Boy) Regular 18"
```

#### Matter

https://github.com/mateosss/matter but [see the fork](https://github.com/Yasumoto/matter/tree/yasumoto-title-width)

https://fonts.google.com/specimen/Rye?category=Display&preview.size=32&preview.text=Ubuntu%20Windows&preview.text_type=custom

```sh
./matter.py -t -b -i ubuntu folder _ _ _ _ microsoft-windows-classic cog \
     -hl ef233c -fg ffd166 -bg 073b4c \
     -ff ./fonts/Rye-Regular.ttf \
     -fn Rye Regular -fs 32
```

## tmux

This repo uses [gpakosz/.tmux](https://github.com/gpakosz/.tmux) config tracked in `dotfiles/.tmux.conf`.

**To update from upstream:**
```sh
curl -fsSL https://raw.githubusercontent.com/gpakosz/.tmux/master/.tmux.conf > dotfiles/.tmux.conf
```
