# One-off: clone the work repos a new machine needs. Run it before the first
# home-manager switch so that switch can link ~/.claude/work-config:
#
#   nix run ~/workspace/github.com/Yasumoto/joe-dotfiles#clone-work-repos
#
# Repos that already exist are skipped, so it is safe to rerun. A failed clone
# removes what it created and stops; fix the cause and run it again.
{
  writeShellApplication,
  git,
  git-lfs,
}:

writeShellApplication {
  name = "clone-work-repos";
  # System ssh stays on PATH (macOS's reads the Keychain), so passphrase and
  # first-contact host-key prompts work as usual.
  runtimeInputs = [
    git
    git-lfs
  ];
  text = ''
    GIT_HOST="git.int.n7k.io"
    EPONA="joe@joe-epona.n7k.ts.net"

    # clone DEST URL [git clone args...]
    clone() {
      local dest="$1" url="$2"
      shift 2
      if [ -e "$dest/.git" ]; then
        echo "$dest: already cloned"
        return 0
      elif [ -e "$dest" ]; then
        echo "error: $dest exists but is not a git checkout; move it aside and rerun." >&2
        exit 1
      fi
      echo "Cloning $url into $dest ..."
      mkdir -p "$(dirname "$dest")"
      # Pass the LFS filters here: before the first switch there is no git
      # config providing them, and ~/src/sw would check out LFS pointer files.
      if ! git \
        -c filter.lfs.process="git-lfs filter-process" \
        -c filter.lfs.smudge="git-lfs smudge -- %f" \
        -c filter.lfs.clean="git-lfs clean -- %f" \
        -c filter.lfs.required=true \
        clone "$@" "$url" "$dest"; then
        # A failed checkout (e.g. an LFS download) leaves $dest/.git behind,
        # which a rerun would skip. $dest did not exist before, so remove it.
        rm -rf "$dest"
        echo "error: cloning $url failed (see git's message above)." >&2
        echo "  'Permission denied (publickey)': ssh-add your key and check it is on https://$GIT_HOST/-/user_settings/ssh_keys or in epona's authorized_keys." >&2
        echo "  'Could not resolve hostname' or a timeout: connect Tailscale." >&2
        exit 1
      fi
    }

    clone "$HOME/src/sw" "git@$GIT_HOST:neuralink/sw.git"
    clone "$HOME/.claude/work-config" "git@$GIT_HOST:joe.smith/work-config.git"
    clone "$HOME/wiki" "$EPONA:wiki/" --origin epona
    clone "$HOME/agent-inbox" "$EPONA:agent-inbox/" --origin epona

    echo "Done. Run (or rerun) home-manager switch to link ~/.claude/work-config."
  '';
}
