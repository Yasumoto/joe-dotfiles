{ config, pkgs, lib, ... }:

{
  programs.fish = {
    enable = true;

    shellInit = ''
      direnv hook fish | source

      if test -d "$HOME/go"
        set -gx GOPATH "$HOME/go"
        fish_add_path "$GOPATH/bin"
      end

      if test -d "$HOME/src/sw/ops/bin/cache"
        fish_add_path "$HOME/src/sw/ops/bin/cache"
      end
    '';

    interactiveShellInit = ''
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

      update_submodules = "git submodule foreach git pull origin master";

      vault_login = ''
        set -e VAULT_TOKEN

        if not command -v vault > /dev/null
          echo "No vault binary installed!"
          return 1
        end

        set KEEPASS_CLI keepassxc-cli
        if not command -v "$KEEPASS_CLI" > /dev/null
          set KEEPASS_CLI /Applications/KeePassXC.app/Contents/MacOS/keepassxc-cli
        end
        if not command -v "$KEEPASS_CLI" > /dev/null
          set KEEPASS_CLI "flatpak run --branch=stable --arch=x86_64 --command=keepassxc-cli org.keepassxc.KeePassXC"
        end

        set KEEPASS_VAULT ~/Documents/joe.smith.kdbx
        if not test -f "$KEEPASS_VAULT"
          set KEEPASS_VAULT ~/joe.smith.kdbx
        end

        set -Ux VAULT_TOKEN (eval $KEEPASS_CLI show -s -a Password $KEEPASS_VAULT Vault | \
          VAULT_ADDR="https://vault.int.n7k.io:443" vault login -token-only -non-interactive -method=userpass username=joe.smith password=-)
      '';
    };
  };
}
