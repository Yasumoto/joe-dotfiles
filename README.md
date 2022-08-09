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
