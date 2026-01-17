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

git submodule update --init

nix run home-manager/release-25.11 -- switch -b (date +%Y_%m_%d_%H:%m:%S_gimmeh) -f ~/workspace/github.com/Yasumoto/joe-dotfiles/home.nix
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

## Tmux Plugins

This repo uses [gpakosz/.tmux](https://github.com/gpakosz/.tmux) submodule for tmux config.

**Enabled Plugins:**
- [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect): Save/restore tmux environment.
- [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum): Auto-save every 15 minutes, auto-restore on tmux start.
- [tmux-yank](https://github.com/tmux-plugins/tmux-yank): System clipboard yank (vi motions, xclip/wl-copy).
- [tmux-copycat](https://github.com/tmux-plugins/tmux-copycat): Fuzzy URLs/paths/logs (Ctrl-u → yank).
- [tmux-prefix-highlight](https://github.com/tmux-plugins/tmux-prefix-highlight): Status bar glows on &lt;prefix&gt; press.

**Key bindings:**
- Install/Update plugins: `&lt;prefix&gt; + I`
- Save: `&lt;prefix&gt; + Ctrl-s`
- Restore: `&lt;prefix&gt; + Ctrl-r`
- Reload tmux config: `&lt;prefix&gt; + r`

**Setup:**
1. `nix run home-manager/release-25.05 -- switch -b joe_backup -f ./home.nix`
2. `tmux kill-server 2>/dev/null || true`
3. `tmux new-session`
4. `&lt;prefix&gt; + I` to install plugins (if missing).
5. `&lt;prefix&gt; + r` to reload.

**Prefix:** Default `Ctrl-b`, secondary `Ctrl-a`.

