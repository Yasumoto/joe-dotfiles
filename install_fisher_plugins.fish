#!/usr/bin/env fish

if ! functions -q fisher
    curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher
end

if ! fisher list PatrickF1/fzf.fish
  fisher install PatrickF1/fzf.fish
end
