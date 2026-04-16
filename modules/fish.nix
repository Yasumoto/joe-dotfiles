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

      # macOS: launchd provides ssh-agent automatically (since 10.5 Leopard)
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
      # Fish calls this function to set up key bindings — proper place for bind commands
      fish_user_key_bindings = ''
        # tcd: Ctrl+G inserts a Terraform root-module path at cursor via fzf
        bind \cg __tcd_widget
      '';

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
        # Constants — ~/src/sw is both the main repo and where master lives
        set MAIN_REPO "$HOME/src/sw"
        set WORKTREE_PARENT "$HOME/src"

        # Get current directory and git info
        set CURRENT_DIR (pwd)
        set WORKTREE_ROOT (git rev-parse --show-toplevel 2>/dev/null)
        set GIT_DIR (git rev-parse --git-dir 2>/dev/null)

        # Determine if we're in the main repo (master)
        set IN_MAIN_REPO 0
        if test "$WORKTREE_ROOT" = "$MAIN_REPO"
          set IN_MAIN_REPO 1
        end

        # Validate suffix if provided (prevent command injection)
        if test (count $argv) -gt 0
          set SUFFIX $argv[1]
          if not string match -qr '^[a-zA-Z0-9_-]+$' "$SUFFIX"
            echo "Error: Suffix must contain only letters, numbers, hyphens, and underscores"
            return 1
          end
        end

        # === CASE 1: In main repo, no args - prompt for suffix ===
        if test $IN_MAIN_REPO -eq 1 -a (count $argv) -eq 0
          echo "You're in the main repo. Please provide a suffix for the new worktree."
          read -l -P "Suffix: " suffix_input
          if test -z "$suffix_input"
            echo "Aborted."
            return 0
          end
          # Recursive call with suffix
          whipped $suffix_input
          return $status
        end

        # === CASE 2: In main repo, with suffix - create new worktree ===
        if test $IN_MAIN_REPO -eq 1 -a (count $argv) -gt 0
          set SUFFIX $argv[1]
          set DATE_STR (date +%Y-%m-%d)
          set NEW_BRANCH "joe-$DATE_STR-$SUFFIX"
          set NEW_WORKTREE "$WORKTREE_PARENT/$NEW_BRANCH"

          echo "Pulling origin/master..."
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

          # Allow direnv if .envrc exists
          if test -f .envrc
            direnv allow
            echo "Ran direnv allow"
          end

          echo "Done! Now in $NEW_WORKTREE on $NEW_BRANCH"
          return 0
        end

        # === CASE 3: Not in main repo, no args - CLEANUP MODE ===
        if test (count $argv) -eq 0
          # Safety: verify we're in a worktree, not the main repo
          if not string match -q "*.git/worktrees/*" "$GIT_DIR"
            echo "Error: Not in a git worktree. This command only works in worktrees."
            echo "Use 'shipped' instead if you're in the main repo."
            return 1
          end

          # Safety: never destroy the main repo
          if test "$WORKTREE_ROOT" = "$MAIN_REPO"
            echo "Error: Cannot destroy the main repo at $MAIN_REPO"
            return 1
          end

          set BRANCH (git branch --show-current)
          set WORKTREE_DIR $WORKTREE_ROOT

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

        # === CASE 4: Not in main repo, with suffix - RECYCLE MODE ===
        set SUFFIX $argv[1]
        set OLD_BRANCH (git branch --show-current)
        set DATE_STR (date +%Y-%m-%d)
        set NEW_BRANCH "joe-$DATE_STR-$SUFFIX"

        # Fetch latest master
        echo "Fetching origin/master..."
        if not git fetch origin master
          echo "Error: Failed to fetch origin/master"
          return 1
        end

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
        set OLD_DIR $WORKTREE_ROOT
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

      nipped = ''
        set -l MAIN_REPO "$HOME/src/sw"
        set -l WORKTREE_PARENT "$HOME/src"
        set -l input $argv[1]

        if test -z "$input"
          echo "Usage: nipped <MR_URL | branch_name>"
          echo ""
          echo "Examples:"
          echo "  nipped https://git.int.n7k.io/neuralink/sw/-/merge_requests/37192"
          echo "  nipped claude-code/stim-terraform"
          return 1
        end

        set -l branch ""

        if string match -q 'http*' "$input"
          set -l mr_number (string match -r '/merge_requests/(\d+)' "$input")[2]
          if test -z "$mr_number"
            echo "nipped: could not parse MR number from URL"
            return 1
          end

          set -l host (string match -r 'https?://([^/]+)' "$input")[2]
          set -l project_path (string match -r "https?://[^/]+/(.+)/-/merge_requests/" "$input")[2]

          if test -z "$host" -o -z "$project_path"
            echo "nipped: could not parse host/project from URL"
            return 1
          end

          echo "Resolving MR !$mr_number on $host..."
          set branch (GITLAB_HOST="$host" glab api "projects/$project_path/merge_requests/$mr_number" 2>/dev/null | jq -r '.source_branch')

          if test -z "$branch" -o "$branch" = "null"
            # Try URL-encoded project path
            set -l encoded_path (string replace -a '/' '%2F' "$project_path")
            set branch (GITLAB_HOST="$host" glab api "projects/$encoded_path/merge_requests/$mr_number" 2>/dev/null | jq -r '.source_branch')
          end

          if test -z "$branch" -o "$branch" = "null"
            echo "nipped: could not resolve branch for MR !$mr_number"
            return 1
          end

          echo "Resolved to branch: $branch"
        else
          set branch "$input"
        end

        set -l dir_name (string replace -a '/' '-' "$branch")
        set -l worktree_dir "$WORKTREE_PARENT/$dir_name"

        if test -d "$worktree_dir"
          echo "Worktree already exists, jumping in..."
          cd "$worktree_dir"
          if test -f .envrc
            direnv allow
            sleep 1
          end
          echo "→ nipped into $dir_name"
          return 0
        end

        echo "Fetching origin/$branch..."
        if not git -C "$MAIN_REPO" fetch origin "$branch"
          echo "nipped: failed to fetch origin/$branch"
          return 1
        end

        echo "Creating worktree at $worktree_dir..."
        if not git -C "$MAIN_REPO" worktree add --track -b "$branch" "$worktree_dir" "origin/$branch" 2>/dev/null
          # Branch may already exist locally, try without -b
          if not git -C "$MAIN_REPO" worktree add "$worktree_dir" "$branch" 2>/dev/null
            # Last resort: detached HEAD on the remote ref
            if not git -C "$MAIN_REPO" worktree add "$worktree_dir" "origin/$branch"
              echo "nipped: failed to create worktree"
              return 1
            end
          end
        end

        cd "$worktree_dir"

        if test -f .envrc
          direnv allow
          sleep 1
        end

        echo "→ nipped $branch into $dir_name"
      '';

      claude-sounds = ''
        switch "$argv[1]"
          case on
            touch ~/.claude/sounds-enabled
            echo "Claude Code sounds enabled"
          case off
            rm -f ~/.claude/sounds-enabled
            echo "Claude Code sounds disabled"
          case '*'
            if test -f ~/.claude/sounds-enabled
              echo "on"
            else
              echo "off"
            end
        end
      '';

      update_submodules = "git submodule foreach git pull origin master";

      vault_login = ''
        # Erase from both scopes so vault login doesn't see any stale token
        # (inherited global from tmux can shadow universal)
        set -e -g VAULT_TOKEN 2>/dev/null
        set -e -U VAULT_TOKEN 2>/dev/null

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

        # Update tmux environment so new panes inherit the fresh token
        # (prevents stale inherited global from shadowing the universal)
        if set -q TMUX
          tmux setenv VAULT_TOKEN $token_result
        end

        echo "Vault login successful"
      '';

      # 1Password helpers
      op-item = ''
        # Quick item lookup: op-item "GitHub Token"
        op item get "$argv[1]" --fields password 2>/dev/null; or op item get "$argv[1]"
      '';

      op-read = ''
        # Read secret reference: op-read "op://vault/item/field"
        op read "$argv[1]"
      '';

      op-env = ''
        # Run command with 1Password env injection: op-env "op://vault/item/TOKEN" my-command
        op run --env-file=/dev/stdin -- $argv[2..-1] < (echo "$argv[1]")
      '';

      # tcd — Terraform root-module navigator with fzf + zoxide
      # Discovers all TF roots under infrastructure/, categorizes by Substrate env vs corp,
      # and provides an interactive fuzzy picker with preview pane.

      __tcd_discover = ''
        set -l git_root (git rev-parse --show-toplevel 2>/dev/null)
        or set git_root (pwd)

        set -l cache_file /tmp/tcd_cache_(echo $git_root | string replace -a / _).txt
        set -l cache_max_age 300

        if not contains -- --no-cache $argv
          if test -f "$cache_file"
            # GNU stat uses -c %Y, BSD stat uses -f %m
            set -l file_mtime (stat -c %Y "$cache_file" 2>/dev/null; or stat -f %m "$cache_file" 2>/dev/null)
            set -l now (date +%s)
            set -l cache_age (math "$now - $file_mtime")
            if test "$cache_age" -lt "$cache_max_age"
              cat "$cache_file"
              return 0
            end
          end
        end

        set -l roots
        if command -q fd
          set roots (fd -t f '(main\.tf|backend\.tf|terragrunt\.hcl)$' \
            -E '.terraform' -E 'node_modules' -E '.git' \
            "$git_root/infrastructure/" 2>/dev/null \
            | xargs -I'{}' dirname '{}' \
            | sort -u)
        else
          set roots (find "$git_root/infrastructure/" \
            \( -name main.tf -o -name backend.tf -o -name terragrunt.hcl \) \
            -not -path '*/.terraform/*' \
            -not -path '*/node_modules/*' \
            -not -path '*/.git/*' \
            2>/dev/null \
            | xargs -I'{}' dirname '{}' \
            | sort -u)
        end

        set -l filtered
        for d in $roots
          if string match -q '*/modules/*' "$d"
            continue
          end
          set -l rel (string replace "$git_root/" "" "$d")
          set -a filtered $rel
        end

        printf '%s\n' $filtered > "$cache_file"
        printf '%s\n' $filtered
      '';

      tcd = ''
        set -l env_filter ""
        set -l no_cache 0
        set -l argidx 1

        while test $argidx -le (count $argv)
          switch $argv[$argidx]
            case --env -e
              set argidx (math $argidx + 1)
              set env_filter $argv[$argidx]
            case --refresh -r
              set no_cache 1
            case --help -h
              echo "tcd - Terraform root-module navigator"
              echo ""
              echo "Usage: tcd [OPTIONS] [QUERY]"
              echo ""
              echo "Options:"
              echo "  -e, --env ENV    Filter: dev/stg/prod/admin (Substrate) or corp (everything else)"
              echo "  -r, --refresh    Rebuild the cache"
              echo "  -h, --help       Show this help"
              echo ""
              echo "Examples:"
              echo "  tcd              Interactive fuzzy finder"
              echo "  tcd neuralink    Pre-filter for 'neuralink'"
              echo "  tcd -e prod      Only show prod root modules"
              echo "  tcd -e corp      Show non-Substrate roots (services, env-corp, etc.)"
              echo "  tcd -r           Refresh cache then pick"
              echo ""
              echo "Keybinding: Ctrl+G inserts a TF root path at the cursor"
              return 0
            case '*'
              break
          end
          set argidx (math $argidx + 1)
        end

        set -l initial_query ""
        if test $argidx -le (count $argv)
          set initial_query (string join " " $argv[$argidx..-1])
        end

        set -l git_root (git rev-parse --show-toplevel 2>/dev/null)
        if test $status -ne 0
          echo "tcd: not in a git repository"
          return 1
        end

        set -l discover_args
        if test $no_cache -eq 1
          set discover_args --no-cache
        end
        set -l roots (__tcd_discover $discover_args)

        if test (count $roots) -eq 0
          echo "tcd: no Terraform root modules found"
          return 1
        end

        # Substrate envs (dev/stg/prod/admin) live under root-modules/DOMAIN/ENV/...
        # "corp" means everything NOT under root-modules/
        if test -n "$env_filter"
          set -l filtered
          for r in $roots
            switch $env_filter
              case corp
                if not string match -q '*/root-modules/*' "$r"
                  set -a filtered $r
                end
              case dev stg prod admin
                if string match -q "*/root-modules/*/$env_filter/*" "$r"
                  set -a filtered $r
                end
              case '*'
                string match -q "*$env_filter*" "$r"; and set -a filtered $r
            end
          end
          set roots $filtered
          if test (count $roots) -eq 0
            echo "tcd: no root modules found for '$env_filter'"
            return 1
          end
        end

        set -l n_total (count $roots)
        set -l n_substrate (printf '%s\n' $roots | grep -c '/root-modules/')
        set -l n_corp (math $n_total - $n_substrate)
        set -l header_text "$n_total roots: $n_substrate substrate, $n_corp corp  |  Ctrl+R: refresh"

        set -l preview_cmd
        if command -q eza
          set preview_cmd "eza --tree --level=2 --color=always --icons $git_root/{} 2>/dev/null; echo; echo '--- .tf files ---'; head -5 $git_root/{}/*.tf 2>/dev/null | head -30"
        else
          set preview_cmd "ls -la $git_root/{} 2>/dev/null; echo; echo '--- .tf files ---'; head -5 $git_root/{}/*.tf 2>/dev/null | head -30"
        end

        set -l selected (printf '%s\n' $roots | fzf \
          --ansi \
          --query "$initial_query" \
          --header "$header_text" \
          --preview "$preview_cmd" \
          --preview-window "right:50%:wrap" \
          --height "70%" \
          --reverse \
          --border rounded \
          --prompt "tcd> " \
          --pointer "▶" \
          --marker "✓" \
          --bind "ctrl-r:reload(__tcd_discover --no-cache | tr ' ' '\n')" \
          --color "header:italic:dim,prompt:bold:green,pointer:green,marker:green" \
        )

        if test -z "$selected"
          return 0
        end

        set -l target "$git_root/$selected"
        if test -d "$target"
          cd "$target"
          zoxide add (pwd)
          if test -f .envrc
            direnv allow
            sleep 1
          end
          # Auto-init if terraform hasn't been initialized yet
          if test -f main.tf -o -f backend.tf
            if not test -d .terraform
              echo "→ running terraform init..."
              terraform init
            end
          end
          echo "→ tcd to $selected"
        else
          echo "tcd: directory not found: $target"
          return 1
        end
      '';

      __tcd_widget = ''
        set -l current_token (commandline --current-token)

        set -l git_root (git rev-parse --show-toplevel 2>/dev/null)
        if test $status -ne 0
          commandline -f repaint
          return
        end

        set -l roots (__tcd_discover)
        if test (count $roots) -eq 0
          commandline -f repaint
          return
        end

        set -l n_total (count $roots)
        set -l header_text "$n_total TF roots  |  Tab: multi-select  |  Ctrl+R: refresh"

        set -l preview_cmd
        if command -q eza
          set preview_cmd "eza --tree --level=2 --color=always --icons $git_root/{} 2>/dev/null; echo; echo '--- key files ---'; ls $git_root/{}/*.tf $git_root/{}/*.tfvars 2>/dev/null"
        else
          set preview_cmd "ls -la $git_root/{} 2>/dev/null; echo; head -3 $git_root/{}/*.tf 2>/dev/null | head -20"
        end

        set -l initial_query ""
        if test -n "$current_token"
          set initial_query "$current_token"
        end

        set -l selected (printf '%s\n' $roots | fzf \
          --ansi \
          --multi \
          --query "$initial_query" \
          --header "$header_text" \
          --preview "$preview_cmd" \
          --preview-window "right:50%:wrap" \
          --height "70%" \
          --reverse \
          --border rounded \
          --prompt "tf-root> " \
          --pointer "▶" \
          --marker "✓" \
          --bind "ctrl-r:reload(__tcd_discover --no-cache | tr ' ' '\n')" \
          --color "header:italic:dim,prompt:bold:cyan,pointer:cyan,marker:cyan" \
        )

        if test -z "$selected"
          commandline -f repaint
          return
        end

        set -l insertion (string join " " $selected)

        if test -n "$current_token"
          commandline --current-token --replace -- "$insertion"
        else
          commandline --insert -- "$insertion"
        end

        for sel in $selected
          set -l full_path "$git_root/$sel"
          if test -d "$full_path"
            zoxide add "$full_path"
          end
        end

        commandline -f repaint
      '';

      tcd_refresh = ''
        __tcd_discover --no-cache >/dev/null
        set -l count (count (__tcd_discover))
        echo "tcd: cache refreshed ($count root modules indexed)"
      '';

      # Google Workspace CLI (gogcli) helpers
      gog-accounts = ''
        gog account --list
      '';

      gog-gmail-list = ''
        # Quick Gmail list (last 10 threads)
        gog gmail thread --list --limit 10
      '';

      gog-send = ''
        # Send email via gogcli
        if test (count $argv) -lt 2
          echo "Usage: gog-send <to@example.com> <subject> [body]"
          return 1
        end

        set to $argv[1]
        set subject $argv[2]
        set body ""
        if test (count $argv) -ge 3
          set body $argv[3]
        end

        gog gmail send --to "$to" --subject "$subject" --body "$body"
      '';

      gog-status = ''
        # Check gogcli auth status
        echo "=== Google Workspace CLI Status ==="
        gog account --list
        echo ""
        echo "To authenticate: gog account --add <account-name>"
        echo "To use: gog gmail thread --list"
      '';
    };
  };
}
