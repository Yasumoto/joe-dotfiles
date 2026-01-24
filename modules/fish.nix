{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.fish = {
    enable = true;

    shellInit = ''
      direnv hook fish | source

      # Initialize fnm (Fast Node Manager)
      if command -v fnm > /dev/null
        fnm env --use-on-cd --shell fish | source
      end

      if test -d "$HOME/src/sw/ops/bin/cache"
        fish_add_path "$HOME/src/sw/ops/bin/cache"
      end

      # Set SSH_AUTH_SOCK for gcr-ssh-agent (GNOME Keyring) in distrobox
      if test -z "$SSH_AUTH_SOCK"
        if test -S "$XDG_RUNTIME_DIR/gcr/.ssh"
          set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/gcr/.ssh"
        else if test -S "$XDG_RUNTIME_DIR/ssh-agent"
          set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent"
        end
      end
    '';

    interactiveShellInit = ''
      # Use minimal starship config for SSH/mobile sessions (fixes Termius rendering)
      if set -q SSH_TTY
        set -gx STARSHIP_CONFIG "$HOME/.config/starship-minimal.toml"
      end

      if command -v fortune > /dev/null
        echo
        fortune
      end
      echo
    '';

    functions = {
      clone = ''
        set LOCATION $argv[1]
        if echo $LOCATION | grep -q https
          set PROVIDER (echo $LOCATION | cut -f3 -d/ | tr -d '[:space:]')
          set OWNER (echo $LOCATION | cut -f4 -d/)
          set REPO (echo $LOCATION | cut -f5 -d/)
        else
          set PROVIDER (echo $LOCATION | cut -f1 -d: | cut -f2 -d\@)
          set OWNER (echo $LOCATION | cut -f2 -d: | cut -f1 -d/)
          set REPO (echo $LOCATION | cut -f2 -d: | cut -f2 -d/ | cut -f1 -d.)
          if test -n "$REPO"
            set SUBPROJECT (echo $LOCATION | cut -f2 -d: | cut -f3 -d/ | cut -f1 -d.)
          end
        end

        if test -n "$SUBPROJECT"
          set FILESYSTEM_LOCATION "$HOME/workspace/$PROVIDER/$OWNER/$SUBPROJECT"
        else
          set FILESYSTEM_LOCATION "$HOME/workspace/$PROVIDER/$OWNER"
        end

        mkdir -p "$FILESYSTEM_LOCATION"
        git clone "$LOCATION" "$FILESYSTEM_LOCATION/$REPO"
        cd "$FILESYSTEM_LOCATION/$REPO"
      '';

      fireball = ''
        git status
        git reset --hard HEAD
        git clean -fd
        git status
      '';

      rebase_party = ''
        for filepath in (git diff --name-only --diff-filter=U)
          nvim $filepath
          git add $filepath
          git status
        end
        git status
        git rebase --continue
        git status
      '';

      shipped = ''
        set BRANCH (git branch --show-current)
        set DEFAULT_BRANCH (git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
        if test -z "$DEFAULT_BRANCH"
          set DEFAULT_BRANCH master
        end
        echo "Deleting $BRANCH, switching to $DEFAULT_BRANCH"
        git checkout $DEFAULT_BRANCH
        git branch -D $BRANCH
        git pull origin $DEFAULT_BRANCH
      '';

      whipped = ''
        # For worktrees: create new branch from origin/master, delete old branch, rename directory
        if test (count $argv) -eq 0
          echo "Usage: whipped <branch-suffix>"
          echo "Example: whipped fix-login → creates joe-YYYY-MM-DD-fix-login"
          return 1
        end

        set SUFFIX $argv[1]
        set OLD_BRANCH (git branch --show-current)
        set DEFAULT_BRANCH (git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
        if test -z "$DEFAULT_BRANCH"
          set DEFAULT_BRANCH master
        end

        # Build new branch name: joe-YYYY-MM-DD-suffix
        set DATE_STR (date +%Y-%m-%d)
        set NEW_BRANCH "joe-$DATE_STR-$SUFFIX"

        echo "Fetching origin/$DEFAULT_BRANCH..."
        git fetch origin $DEFAULT_BRANCH

        echo "Creating branch $NEW_BRANCH from origin/$DEFAULT_BRANCH..."
        git checkout -B $NEW_BRANCH origin/$DEFAULT_BRANCH

        echo "Deleting old branch $OLD_BRANCH..."
        git branch -D $OLD_BRANCH

        # Rename worktree directory
        set OLD_DIR (pwd)
        set PARENT_DIR (dirname $OLD_DIR)
        set NEW_DIR "$PARENT_DIR/$NEW_BRANCH"

        if test "$OLD_DIR" != "$NEW_DIR"
          echo "Renaming worktree directory..."
          cd $PARENT_DIR
          mv (basename $OLD_DIR) $NEW_BRANCH
          cd $NEW_DIR
          echo "Moved to $NEW_DIR"
        end

        echo "Done! Now on $NEW_BRANCH"
      '';

      update_submodules = "git submodule foreach git pull origin master";

      vault_login = ''
        set -e VAULT_TOKEN

        if not command -v vault > /dev/null
          echo "No vault binary installed!"
          return 1
        end

        # Allow override via environment variables
        set -q VAULT_ADDR; or set -l VAULT_ADDR "https://vault.int.n7k.io:443"
        set -q VAULT_USER; or set -l VAULT_USER "joe.smith"

        # Detect KeePassXC CLI - use Fish arrays instead of eval for safety
        set KEEPASS_CMD keepassxc-cli
        if not command -v "$KEEPASS_CMD" > /dev/null
          set KEEPASS_CMD /Applications/KeePassXC.app/Contents/MacOS/keepassxc-cli
        end
        if not command -v "$KEEPASS_CMD" > /dev/null
          if command -v flatpak > /dev/null; and flatpak list | grep -q org.keepassxc.KeePassXC
            # Fish array - safe from command injection
            set KEEPASS_CMD flatpak run --branch=stable --arch=x86_64 --command=keepassxc-cli org.keepassxc.KeePassXC
          else
            echo "No keepassxc-cli binary found! Install keepassxc-cli or the org.keepassxc.KeePassXC flatpak."
            return 1
          end
        end

        # Locate KeePass database
        set KEEPASS_VAULT ~/Documents/$VAULT_USER.kdbx
        if not test -f "$KEEPASS_VAULT"
          set KEEPASS_VAULT ~/$VAULT_USER.kdbx
        end

        # Validate database exists and is readable
        if not test -r "$KEEPASS_VAULT"
          echo "KeePass database not found or not readable: $KEEPASS_VAULT"
          return 1
        end

        # Retrieve token with proper error handling
        set token_result ($KEEPASS_CMD show -s -a Password $KEEPASS_VAULT Vault | tr -d '\n' | \
          VAULT_ADDR="$VAULT_ADDR" vault login -token-only -non-interactive -method=userpass username=$VAULT_USER password=-)

        if test $status -ne 0; or test -z "$token_result"
          echo "Vault login failed"
          return 1
        end

        set -Ux VAULT_TOKEN $token_result
        echo "Vault login successful"
      '';
    };
  };
}
