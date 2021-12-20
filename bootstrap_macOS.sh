#!/bin/sh

set -eu

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

# Enable the Develop menu and the Web Inspector in Safari
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true

# Enable “Do Not Track”
defaults write com.apple.Safari SendDoNotTrackHTTPHeader -bool true

# Enable the debug menu in Disk Utility
defaults write com.apple.DiskUtility DUDebugMenuEnabled -bool true
defaults write com.apple.DiskUtility advanced-image-options -bool true

./_bootstrap_homedir_config_files.sh

if ! command -v brew > /dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

brew update
brew install fish jq curl fortune nmap \
    the_silver_searcher homebrew/cask/ksdiff nghttp2 \
    shellcheck pyenv prometheus pipx neofetch \
    flake8 clang-format exa fd rg mosh tmux \
    starship zoxide git-delta terraform terraform-docs \
    tfsec tflint kubectl k9s helm minikube bat nvim fzf \
    n go fontforge markdownlint-cli homebrew/cask/ksdiff

# https://github.com/mklement0/n-install
if [ "$(which n)" = "" ]; then
  curl -L https://git.io/n-install | bash
fi

# https://github.com/Microsoft/pyright#command-line
if [ "$(which pyright)" = "" ]; then
  npm -g install pyright
fi

# https://github.com/bash-lsp/bash-language-server#installation
if [ "$(which bash-language-server)" = "" ]; then
  npm -g install bash-language-server
fi

if [ "$(which docker-langserver)" = "" ]; then
  npm -g install dockerfile-language-server-nodejs
fi

if [ "$(which gopls)" = "" ]; then
  go install golang.org/x/tools/gopls@latest
fi

#https://github.com/tonsky/FiraCode/wiki/Installing
brew tap homebrew/cask-fonts
brew install --cask font-fira-code

if ! grep fish /etc/shells; then
    sudo bash -c "echo '/opt/homebrew/bin/fish' >> /etc/shells"
fi

if [ "$SHELL" != /opt/homebrew/bin/fish ]; then
    chsh -s /opt/homebrew/bin/fish
fi

if [ ! -d "${HOME}/.local/share/omf" ]; then
    ./oh-my-fish/bin/install --offline
else
    echo "🐟 Already installed oh-my-fish"
fi

./install_fisher_plugins.fish

echo "🍎 All set!"
