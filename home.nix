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
    ./modules/gogcli.nix
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
        nixfmt-rfc-style
        statix
        taplo
        stylua
        kubectl
        kubernetes-helm
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
        neofetch
        git-lfs
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
        nodePackages.bash-language-server
        dockerfile-language-server
        nodePackages.typescript-language-server
        nodePackages.typescript
        nil
        jdt-language-server
        yaml-language-server
        cascadia-code
        tmux
        mosh
        taskwarrior3
        nethack
        google-cloud-sdk

        # Voice interaction stack (STT/TTS for CLI agents)
        # Scripts deployed via modules/claude-code.nix, shared library at ~/.local/share/voice-lib.sh
        whisper-cpp
        ffmpeg
      ]
      ++ lib.optionals pkgs.stdenv.isLinux [
        xclip
        powerline
        git-credential-manager
        sox # Provides play command for piper TTS output
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
      installWhisperModel = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        WHISPER_MODEL="${config.home.homeDirectory}/.local/share/whisper-models/ggml-base.en.bin"
        if [ ! -f "$WHISPER_MODEL" ]; then
          echo "Downloading Whisper base.en model..."
          mkdir -p "$(dirname "$WHISPER_MODEL")"
          ${pkgs.curl}/bin/curl -L -o "$WHISPER_MODEL" \
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin" || \
            echo "WARNING: Failed to download Whisper model. voice-claude will be unavailable." >&2
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
    };
  };

  fonts.fontconfig.enable = !pkgs.stdenv.isDarwin;

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
      matchBlocks."*" = {
        extraOptions = {
          # Ignore unknown SSH options (for compatibility across SSH clients)
          "IgnoreUnknown" = "GSSAPIAuthentication,UseKeychain,AddKeysToAgent";
          # Work-specific SSH config (silently ignored if file doesn't exist)
          "Include" = "${homeDirectory}/src/sw/ops/nlk_speed_up_git/ssh.config";
        }
        // lib.optionalAttrs pkgs.stdenv.isDarwin {
          # macOS keychain integration
          "UseKeychain" = "yes";
          "AddKeysToAgent" = "yes";
        };
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

      extraLuaConfig = builtins.readFile ./modules/neovim-lua.lua;
    };

    gnome-terminal = {
      enable = pkgs.stdenv.isLinux;
      showMenubar = false;
      profile.b1dcc9dd-5262-4d8d-a863-c897e6d979b9 = {
        audibleBell = false;
        default = true;
        visibleName = "Nord";
        showScrollbar = false;
        transparencyPercent = 5;
        font = "CaskaydiaCove Nerd Font Mono 14";
        colors = {
          foregroundColor = "#A9B2C3";
          backgroundColor = "#21252B";
          boldColor = "#D2DDF2";
          palette = [
            "#21252B"
            "#B85960"
            "#98C379"
            "#C4A469"
            "#61AFEF"
            "#B57EDC"
            "#56B6C2"
            "#A9B2C3"
            "#5F6672"
            "#FF7A85"
            "#C6FF9E"
            "#FFD588"
            "#67BAFF"
            "#D192FF"
            "#71EFFF"
            "#DDE8FF"
          ];
        };
      };
    };
  };
}
