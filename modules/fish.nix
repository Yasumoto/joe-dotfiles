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
        # Constants
        set MAIN_REPO "$HOME/src/sw"
        set MASTER_WORKTREE "$HOME/src/master"
        set WORKTREE_PARENT "$HOME/src"

        # Get current directory and git info
        set CURRENT_DIR (pwd)
        set GIT_DIR (git rev-parse --git-dir 2>/dev/null)

        # Determine if we're in the master worktree
        set IN_MASTER_WORKTREE 0
        if test "$CURRENT_DIR" = "$MASTER_WORKTREE"
          set IN_MASTER_WORKTREE 1
        end

        # Validate suffix if provided (prevent command injection)
        if test (count $argv) -gt 0
          set SUFFIX $argv[1]
          if not string match -qr '^[a-zA-Z0-9_-]+$' "$SUFFIX"
            echo "Error: Suffix must contain only letters, numbers, hyphens, and underscores"
            return 1
          end
        end

        # === CASE 1: In master worktree, no args - prompt for suffix ===
        if test $IN_MASTER_WORKTREE -eq 1 -a (count $argv) -eq 0
          echo "You're in the master worktree. Please provide a suffix for the new worktree."
          read -l -P "Suffix: " suffix_input
          if test -z "$suffix_input"
            echo "Aborted."
            return 0
          end
          # Recursive call with suffix
          whipped $suffix_input
          return $status
        end

        # === CASE 2: In master worktree, with suffix - create new worktree ===
        if test $IN_MASTER_WORKTREE -eq 1 -a (count $argv) -gt 0
          set SUFFIX $argv[1]
          set DATE_STR (date +%Y-%m-%d)
          set NEW_BRANCH "joe-$DATE_STR-$SUFFIX"
          set NEW_WORKTREE "$WORKTREE_PARENT/$NEW_BRANCH"

          echo "Pulling origin/master in master worktree..."
          if not git pull origin master
            echo "Error: Failed to pull origin/master"
            return 1
          end

          echo "Creating new worktree at $NEW_WORKTREE with branch $NEW_BRANCH..."
          if not git worktree add -b $NEW_BRANCH "$NEW_WORKTREE" origin/master
            echo "Error: Failed to create worktree"
            return 1
          end

          cd $NEW_WORKTREE
          echo "Done! Now in $NEW_WORKTREE on $NEW_BRANCH"
          return 0
        end

        # === CASE 3: Not in master worktree, no args - CLEANUP MODE ===
        if test (count $argv) -eq 0
          # Safety: verify we're in a worktree, not the main repo
          if not string match -q "*.git/worktrees/*" "$GIT_DIR"
            echo "Error: Not in a git worktree. This command only works in worktrees."
            echo "Use 'shipped' instead if you're in the main repo."
            return 1
          end

          # Safety: never destroy the master worktree
          if test "$CURRENT_DIR" = "$MASTER_WORKTREE"
            echo "Error: Cannot destroy the master worktree at $MASTER_WORKTREE"
            echo "This worktree is intended to be persistent."
            return 1
          end

          set BRANCH (git branch --show-current)
          set WORKTREE_DIR (pwd)

          # Confirmation prompt
          echo "This will destroy:"
          echo "  Worktree: $WORKTREE_DIR"
          echo "  Branch:   $BRANCH"
          echo ""
          read -l -P "Proceed? [y/N] " confirm
          if test "$confirm" != "y" -a "$confirm" != "Y"
            echo "Aborted."
            return 0
          end

          # Navigate to main repo first (required before removing worktree)
          cd $MAIN_REPO

          # Remove the worktree (--force handles uncommitted changes)
          if not git worktree remove --force "$WORKTREE_DIR"
            echo "Error: Failed to remove worktree"
            return 1
          end

          # Delete the local branch
          git branch -D $BRANCH

          echo "Done! Worktree and branch cleaned up."
          return 0
        end

        # === CASE 4: Not in master worktree, with suffix - RECYCLE MODE ===
        set SUFFIX $argv[1]
        set OLD_BRANCH (git branch --show-current)
        set DATE_STR (date +%Y-%m-%d)
        set NEW_BRANCH "joe-$DATE_STR-$SUFFIX"

        # Ensure master worktree exists
        if not test -d "$MASTER_WORKTREE"
          echo "Master worktree not found. Creating it at $MASTER_WORKTREE..."
          cd $MAIN_REPO
          if not git worktree add "$MASTER_WORKTREE" master
            echo "Error: Failed to create master worktree"
            return 1
          end
        end

        # Pull origin/master in the master worktree
        echo "Updating master worktree..."
        cd $MASTER_WORKTREE
        if not git pull origin master
          echo "Error: Failed to pull origin/master in master worktree"
          cd $CURRENT_DIR
          return 1
        end

        # Return to original worktree
        cd $CURRENT_DIR

        # Create new branch from origin/master
        echo "Creating branch $NEW_BRANCH from origin/master..."
        if not git checkout -B $NEW_BRANCH origin/master
          echo "Error: Failed to create new branch"
          return 1
        end

        # Delete old branch
        echo "Deleting old branch $OLD_BRANCH..."
        git branch -D $OLD_BRANCH

        # Rename worktree directory
        set OLD_DIR (pwd)
        set NEW_DIR "$WORKTREE_PARENT/$NEW_BRANCH"

        if test "$OLD_DIR" != "$NEW_DIR"
          echo "Renaming worktree directory..."

          # Get the main repository path
          set REPO_PATH (git rev-parse --path-format=absolute --git-common-dir | sed 's@/\.git$@@')

          # Navigate to main repo to run worktree move
          cd $REPO_PATH

          # Use git worktree move instead of mv so git tracks the change
          if not git worktree move "$OLD_DIR" "$NEW_DIR"
            echo "Error: Failed to move worktree"
            return 1
          end

          cd $NEW_DIR
          echo "Moved to $NEW_DIR"
        end

        # Allow direnv if .envrc exists
        if test -f .envrc
          direnv allow
          echo "Ran direnv allow"
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
