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
# macOS: Nix's git avoids /usr/bin/git's Xcode tools prompt
nix shell nixpkgs#git -c git clone git@github.com:Yasumoto/joe-dotfiles.git
cd joe-dotfiles

# Picks this machine's OS and $USER (joe or joe.smith) automatically:
nix run home-manager/release-26.05 -- switch -b backup --flake ~/workspace/github.com/Yasumoto/joe-dotfiles

# Personal machines (username `joe`):
nix run home-manager/release-26.05 -- switch -b backup --flake ~/workspace/github.com/Yasumoto/joe-dotfiles#personal

prek install
```

Except with `#personal`, a switch also clones any missing `~/src/sw`, `~/.claude/work-config`, `~/wiki`
and `~/agent-inbox`. Connect Tailscale and load an SSH key that GitLab and epona accept
first (on macOS, `ssh-add --apple-use-keychain ~/.ssh/id_ed25519`: Nix's ssh doesn't read
the Keychain). A failed clone stops the switch; fix it and switch again. Afterwards, run
`./ops/bin/nlk_sw_setup.sh` in `~/src/sw`.

### 🍎 macOS Extras

After `home-manager switch`, enable Remote Login (SSH) and set up mosh:

```sh
# Enable SSH (or via System Settings > General > Sharing > Remote Login)
sudo systemsetup -setremotelogin on

# Add ~/.nix-profile/bin to sshd's PATH so mosh-server (and other Nix tools) are found
echo "SetEnv PATH=$HOME/.nix-profile/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" | sudo tee /etc/ssh/sshd_config.d/050-path.conf
sudo launchctl kickstart -k system/com.openssh.sshd

# Allow mosh-server through the firewall (re-run after mosh Nix store path changes)
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add $(which mosh-server)
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp $(which mosh-server)
```

Not installed by this flake:

- Claude Code (`~/.local/bin/claude`) and the Grok CLI
- KeePassXC, for `vault_login`
- `agent-voice-mcp`: `cargo install --path .` in its checkout (Claude Code expects
  `~/.cargo/bin/agent-voice-mcp`)

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
