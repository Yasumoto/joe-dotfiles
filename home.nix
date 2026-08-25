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
        vim
        gnupg
        eksctl
        packer
        vault
        terraform
        tfsec
        tflint
        terraform-ls
        prek # v0.2.30 or later needed for builtin hooks
        alejandra
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
        gopls
        bash-language-server
        dockerfile-language-server
        typescript-language-server
        typescript
        nil
        jdt-language-server
        yaml-language-server
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
      ".vimrc".source = ./dotfiles/vimrc;
      ".tmux.conf.local".source = ./dotfiles/tmux.conf.local;
      ".tmux.conf".source = ./dotfiles/.tmux.conf;
      ".config/starship.toml".source = ./dotfiles/starship.toml;
      ".config/starship-minimal.toml".source = ./dotfiles/starship-minimal.toml;
      ".config/ghostty/config".text = ''
        shell-integration-features = ssh-terminfo,ssh-env
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
      # Explicit legacy defaults (HM 26.05 changed defaults to false when stateVersion >= 26.05)
      withRuby = true;
      withPython3 = true;
      plugins = with pkgs.vimPlugins; [
        nvim-lspconfig
        nvim-cmp
        cmp-nvim-lsp
        cmp-nvim-lsp-signature-help
        cmp-path
        cmp-buffer
        cmp-cmdline
        copilot-lua
        copilot-cmp
        rustaceanvim
        popup-nvim
        plenary-nvim
        telescope-nvim
        telescope-fzf-native-nvim
        (nvim-treesitter.withPlugins (
          p: with p; [
            lua
            rust
            go
            python
            typescript
            javascript
            nix
            terraform
            bash
            fish
            json
            yaml
            toml
            markdown
            vim
            c
            cpp
          ]
        ))
        nord-vim
        vim-fugitive
        vim-terraform
        vim-protobuf
        vim-mustache-handlebars
        vim-fish
        vim-nix
        gitsigns-nvim
        indent-blankline-nvim
        neo-tree-nvim
        nvim-web-devicons
        nui-nvim
        lualine-nvim
        comment-nvim
        diffview-nvim
        harpoon
        barbar-nvim
        which-key-nvim
        trouble-nvim
      ];

      extraConfig = ''
        silent! autocmd! filetypedetect BufRead,BufNewFile *.tf
        autocmd BufRead,BufNewFile *.hcl set filetype=hcl
        autocmd BufRead,BufNewFile .terraformrc,terraform.rc set filetype=hcl
        autocmd BufRead,BufNewFile *.tf,*.tfvars set filetype=terraform
        autocmd BufRead,BufNewFile *.tfstate,*.tfstate.backup set filetype=json
        let g:terraform_fmt_on_save=1
        let g:terraform_align=1

        " Unique keymaps not defined in Lua on_attach
        nnoremap <silent> 1gD   <cmd>lua vim.lsp.buf.type_definition()<CR>
        nnoremap <silent> g0    <cmd>lua vim.lsp.buf.document_symbol()<CR>
        nnoremap <silent> gW    <cmd>lua vim.lsp.buf.workspace_symbol()<CR>
        nnoremap <silent> W     <cmd>lua vim.diagnostic.open_float()<CR>
        nnoremap <silent> ga    <cmd>lua vim.lsp.buf.code_action()<CR>

        set updatetime=500

        colorscheme nord
        nmap <silent> <C-M> :silent noh<CR> :echo "Highlights Cleared!"<CR>
        set mouse=

        highlight ExtraWhitespace guibg=#ff0000
        autocmd BufWinEnter * match ExtraWhitespace /\s\+$/
        autocmd InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
        autocmd InsertLeave * match ExtraWhitespace /\s\+$/
        autocmd BufWinLeave * call clearmatches()
      '';

      initLua = builtins.readFile ./modules/neovim-lua.lua;
    };
  };
}
