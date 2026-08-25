{
  config,
  pkgs,
  lib,
  username,
  ...
}:

let
  homeDirectory =
    if pkgs.stdenv.isLinux then
      "/home/${username}"
    else if pkgs.stdenv.isDarwin then
      "/Users/${username}"
    else
      "/home/${username}";
  hmConfigName =
    if pkgs.stdenv.isDarwin then
      (if username == "joe.smith" then "darwin-joe.smith" else "darwin")
    else
      "linux";
in
{
  imports = [
    ./modules/fish.nix
    ./modules/git.nix
    ./modules/claude-code.nix
    # Slack for Grok is a Space connector (managed_gateway), not a local MCP.
    # Do not re-add mcp_servers.slack — it shadows the connector and fails OAuth.
    # grok.nix is AWS toolkit skills only (no MCP; see modules/grok.nix).
    ./modules/grok.nix
    ./modules/gogcli.nix
    ./modules/herdr.nix
  ];

  programs._1password-shell-plugins = {
    enable = true;
    plugins = with pkgs; [
      gh # GitHub CLI - uses 1Password for auth
    ];
  };

  home = {
    inherit username homeDirectory;
    stateVersion = "23.05";

    packages =
      with pkgs;
      [
        awscli2
        azure-cli
        clang-tools
        gcc
        htop
        fortune
        difftastic
        delta
        fd
        eza
        ripgrep
        zoxide
        starship
        gnupg
        eksctl
        packer
        vault
        terraform
        tfsec
        tflint
        terraform-ls
        prek # v0.2.30 or later needed for builtin hooks
        nixfmt
        statix
        taplo
        stylua
        kubectl
        kubernetes-helm
        home-assistant-cli # hass-cli — talk to HA (https://home.bjoli.com) from the terminal
        minikube
        stern
        ctop
        dive
        docker-compose
        k6
        procs
        gping
        viddy
        cheat
        navi
        pv
        glow
        cbonsai
        topgrade
        btop
        fastfetch
        git-lfs
        git-spice
        glab
        pyenv
        rustup
        pipenv
        shellcheck
        fnm
        gawk
        curl
        go
        pyright
        ruff
        gopls
        bash-language-server
        docker-language-server
        typescript-language-server
        typescript
        nixd
        yaml-language-server
        buf
        cascadia-code
        tmux
        mosh
        taskwarrior3
        nethack
        google-cloud-sdk

        # Voice interaction stack (xAI STT/TTS for CLI agents)
        # Scripts deployed via modules/claude-code.nix, shared library at ~/.local/share/voice-lib.sh
        ffmpeg
        jq
      ]
      ++ lib.optionals pkgs.stdenv.isLinux [
        xclip
        powerline
        git-credential-manager
        sox # Provides play command for xAI TTS output on Linux
        pipewire # Provides pw-play for audio playback (Claude Code hooks)
      ];

    file = {
      ".bash_profile".source = ./dotfiles/bash_profile;
      ".tmux.conf.local".source = ./dotfiles/tmux.conf.local;
      ".tmux.conf".source = ./dotfiles/.tmux.conf;
      ".config/starship.toml".source = ./dotfiles/starship.toml;
      ".config/starship-minimal.toml".source = ./dotfiles/starship-minimal.toml;
      ".config/ghostty/config".text = ''
        shell-integration-features = ssh-terminfo,ssh-env
        # Left Option is Meta so Neovim <A-…> (barbar) works; right Option still types Unicode.
        macos-option-as-alt = left
      '';
      ".config/opencode/tui.json".text = builtins.toJSON {
        "$schema" = "https://opencode.ai/tui.json";
        mouse = false;
      };
      # Claude Code config managed by modules/claude-code.nix

      # Wiki CLI utilities
      ".local/bin/wiki-search" = {
        source = ./scripts/wiki/wiki-search;
        executable = true;
      };
      ".local/bin/wiki-browse" = {
        source = ./scripts/wiki/wiki-browse;
        executable = true;
      };
      ".local/bin/wiki-lock" = {
        source = ./scripts/wiki/wiki-lock;
        executable = true;
      };
      ".local/bin/wiki-unlock" = {
        source = ./scripts/wiki/wiki-unlock;
        executable = true;
      };

      # Wiki snapshot/harvest utilities
      ".local/bin/wiki-snapshot-tmux" = {
        source = ./scripts/wiki/wiki-snapshot-tmux;
        executable = true;
      };
      ".local/bin/wiki-snapshot-work" = {
        source = ./scripts/wiki/wiki-snapshot-work;
        executable = true;
      };
      ".local/bin/wiki-harvest-conversations" = {
        source = ./scripts/wiki/wiki-harvest-conversations;
        executable = true;
      };

      # Recover frozen GNOME Wayland (amdgpu flip_done) via DPMS + gdctl modeset
      ".local/bin/gui-unstick" = {
        source = ./scripts/host/gui-unstick;
        executable = true;
      };
    };

    sessionPath = [
      "$HOME/.local/bin"
      "$HOME/.local/share/fnm/aliases/default/bin"
      "$HOME/.cargo/bin"
      "$HOME/go/bin"
      "$HOME/workspace/bin"
      "$HOME/src/sw/ops/bin/cache"
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      "/opt/homebrew/bin"
    ];

    # Disable broken SSH_ASKPASS on BlueFin (points to non-existent gnome-ssh-askpass)
    sessionVariables = lib.mkIf pkgs.stdenv.isLinux {
      SSH_ASKPASS = "";
      SUDO_ASKPASS = "";
    };

    activation = {
      installFnmLts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        FNM_DIR="${config.home.homeDirectory}/.local/share/fnm"
        if [ ! -d "$FNM_DIR/aliases/default" ]; then
          echo "Installing Node.js LTS via fnm..."
          PATH="${pkgs.fnm}/bin:$PATH" FNM_DIR="$FNM_DIR" ${pkgs.fnm}/bin/fnm install --lts
          PATH="${pkgs.fnm}/bin:$PATH" FNM_DIR="$FNM_DIR" ${pkgs.fnm}/bin/fnm default lts-latest
        fi
      '';
      # Claude settings activation moved to modules/claude-code.nix
      initWiki = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        WIKI_DIR="${config.home.homeDirectory}/wiki"
        if [ ! -d "$WIKI_DIR/.git" ]; then
          echo "Initializing LLM Wiki at $WIKI_DIR..."
          mkdir -p "$WIKI_DIR/raw" "$WIKI_DIR/wiki"
          ${pkgs.git}/bin/git init "$WIKI_DIR"
        fi
      '';
      prekSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        REPO_DIR="${config.home.homeDirectory}/workspace/github.com/Yasumoto/joe-dotfiles"
        if [ -d "$REPO_DIR" ] && [ -f "$REPO_DIR/.pre-commit-config.yaml" ]; then
          echo "Setting up prek in dotfiles repo..."
          cd "$REPO_DIR"
          PATH="${pkgs.git}/bin:$PATH" ${pkgs.prek}/bin/prek install --install-hooks
        fi
      '';
      # Stop a previously-started gpg-agent-ssh.socket and point the systemd
      # user environment at OpenSSH ssh-agent when gcr is not present.
      # (The unit file itself is masked declaratively below.)
      maskGpgAgentSsh = lib.mkIf pkgs.stdenv.isLinux (
        lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
          sys="${pkgs.systemd}/bin/systemctl"
          runtime="''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}"
          export XDG_RUNTIME_DIR="$runtime"
          export DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=$runtime/bus}"
          "$sys" --user stop gpg-agent-ssh.socket 2>/dev/null || true
          "$sys" --user unset-environment GSM_SKIP_SSH_AGENT_WORKAROUND 2>/dev/null || true
          if [ -S "$runtime/gcr/ssh" ]; then
            "$sys" --user set-environment SSH_AUTH_SOCK="$runtime/gcr/ssh" 2>/dev/null || true
          elif [ -S "$runtime/gcr/.ssh" ]; then
            "$sys" --user set-environment SSH_AUTH_SOCK="$runtime/gcr/.ssh" 2>/dev/null || true
          else
            "$sys" --user start ssh-agent.service 2>/dev/null || true
            if [ -S "$runtime/ssh-agent" ]; then
              "$sys" --user set-environment SSH_AUTH_SOCK="$runtime/ssh-agent" 2>/dev/null || true
            elif "$sys" --user show-environment 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q "^SSH_AUTH_SOCK=$runtime/gnupg/S.gpg-agent.ssh$"; then
              "$sys" --user unset-environment SSH_AUTH_SOCK 2>/dev/null || true
            fi
          fi
        ''
      );
    };
  };

  fonts.fontconfig.enable = !pkgs.stdenv.isDarwin;

  # systemd treats a 0-byte unit file as masked, so this wins over Ubuntu's
  # preset-enabled gpg-agent-ssh.socket without calling systemctl mask.
  xdg.configFile."systemd/user/gpg-agent-ssh.socket" = lib.mkIf pkgs.stdenv.isLinux {
    source = pkgs.emptyFile;
  };

  # Linux: OpenSSH ssh-agent via systemd --user ($XDG_RUNTIME_DIR/ssh-agent).
  # macOS: leave disabled — launchd already provides the agent + Keychain.
  services.ssh-agent.enable = pkgs.stdenv.isLinux;

  programs = {
    home-manager.enable = true;
    fzf.enable = true;
    zoxide.enable = true;
    starship.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    ssh = {
      enable = true;
      enableDefaultConfig = false;
      # Work-specific SSH config (silently ignored if the file doesn't exist)
      includes = [ "${homeDirectory}/src/sw/ops/nlk_speed_up_git/ssh.config" ];
      # Use upstream OpenSSH directive names (matchBlocks/extraOptions are deprecated)
      settings."*" = {
        IgnoreUnknown = "GSSAPIAuthentication,UseKeychain,AddKeysToAgent";
        AddKeysToAgent = "yes";
      }
      // lib.optionalAttrs pkgs.stdenv.isDarwin {
        UseKeychain = "yes";
      };
    };

    atuin = {
      enable = true;
      flags = [ "--disable-up-arrow" ];
    };

    bat.enable = true;
    gh = {
      enable = true;
      settings = {
        git_protocol = "https";
        editor = "";
      };
    };
    jq.enable = true;
    k9s.enable = true;

    neovim = {
      enable = true;
      defaultEditor = true;
      vimAlias = true;
      # Ruby/python providers unused; copilot-lua uses extraPackages nodejs, not the neovim node provider
      withRuby = false;
      withPython3 = false;
      extraPackages = with pkgs; [
        nodejs # copilot-lua language-server.js (not the neovim node provider)
        fd
        ripgrep
        pyright
        ruff
        gopls
        bash-language-server
        docker-language-server
        typescript-language-server
        terraform
        terraform-ls
        tflint
        nixd
        nixfmt
        lua-language-server
        jdt-language-server
        yaml-language-server
        vscode-langservers-extracted # jsonls
        clang-tools # clangd
        stylua
        taplo
        shfmt
        helm-ls
        fish-lsp
        buf
        marksman
        # rustaceanvim looks up rust-analyzer on PATH. Use rustup's toolchain
        # binary, not pkgs.rust-analyzer (sysroot mismatch with rustup rustc).
        rustup
        (writeShellScriptBin "rust-analyzer" ''
          ra="$(${lib.getExe rustup} which rust-analyzer 2>/dev/null)" || true
          if [ -n "$ra" ]; then
            exec "$ra" "$@"
          fi
          echo "rust-analyzer: run 'rustup component add rust-analyzer'" >&2
          exit 127
        '')
        (writeShellScriptBin "rustfmt" ''
          rf="$(${lib.getExe rustup} which rustfmt 2>/dev/null)" || true
          if [ -n "$rf" ]; then
            exec "$rf" "$@"
          fi
          echo "rustfmt: run 'rustup component add rustfmt'" >&2
          exit 127
        '')
      ];
      plugins = with pkgs.vimPlugins; [
        nvim-lspconfig
        conform-nvim
        SchemaStore-nvim
        blink-cmp
        blink-copilot
        copilot-lua
        rustaceanvim
        plenary-nvim
        telescope-nvim
        telescope-fzf-native-nvim
        (nvim-treesitter.withPlugins (
          p: with p; [
            lua
            rust
            go
            gomod
            gosum
            python
            typescript
            javascript
            tsx
            nix
            terraform
            hcl
            bash
            fish
            json
            yaml
            toml
            markdown
            markdown_inline
            vim
            vimdoc
            query
            c
            cpp
            dockerfile
            proto
            gitcommit
            regex
            helm
            gotmpl
          ]
        ))
        gbprod-nord
        vim-helm
        vim-fugitive
        gitsigns-nvim
        indent-blankline-nvim
        oil-nvim
        nvim-web-devicons
        lualine-nvim
        diffview-nvim
        harpoon
        barbar-nvim
        which-key-nvim
        trouble-nvim
      ];

      initLua = ''
        vim.g.joe_dotfiles_flake = [[${homeDirectory}/workspace/github.com/Yasumoto/joe-dotfiles]]
        vim.g.joe_hm_config = [[${hmConfigName}]]
      ''
      + builtins.readFile ./modules/neovim-lua.lua;
    };
  };
}
