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

  # Claude Code sound hooks
  hooksDir = "${homeDirectory}/.claude/hooks";
  soundsDir = "${hooksDir}/sounds";
  hookCmd = sound: "sh ${hooksDir}/play-sound.sh ${soundsDir}/${sound}";
  claudeHooksConfig = builtins.toJSON {
    statusLine = {
      type = "command";
      command = "${homeDirectory}/.claude/statusline-async.sh";
    };
    hooks = {
      SessionStart = [
        {
          hooks = [
            {
              type = "command";
              command = hookCmd "PeonReady1.ogg";
            }
          ];
        }
      ];
      UserPromptSubmit = [
        {
          hooks = [
            {
              type = "command";
              command = hookCmd "PeonYes3.ogg";
            }
          ];
        }
      ];
      Notification = [
        {
          hooks = [
            {
              type = "command";
              command = hookCmd "PeonWhat3.ogg";
            }
          ];
        }
      ];
      Stop = [
        {
          hooks = [
            {
              type = "command";
              command = hookCmd "PeonBuildingComplete1.ogg";
            }
          ];
        }
      ];
    };
  };
in
{
  imports = [
    ./modules/fish.nix
    ./modules/git.nix
  ];

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

        # Voice interaction stack (STT/TTS for CLI agents)
        whisper-cpp # Fast local speech-to-text
        piper-tts # Fast local text-to-speech
        sox # Audio recording/playback (rec, play commands)

        # Voice wrapper for Claude CLI with session resume support
        (pkgs.writeShellScriptBin "voice-claude" ''
          set -euo pipefail

          # Config
          WHISPER_MODEL="''${WHISPER_MODEL:-$HOME/.local/share/whisper-models/ggml-base.en.bin}"
          PIPER_VOICE="''${PIPER_VOICE:-$HOME/.local/share/piper-voices/en_US-lessac-medium.onnx}"
          TMPDIR="''${TMPDIR:-/tmp}"
          VOICE_CLAUDE_SPEAK="''${VOICE_CLAUDE_SPEAK:-1}"

          # Parse arguments for session resume
          CLAUDE_ARGS=""
          while [[ $# -gt 0 ]]; do
            case $1 in
              --continue|-c)
                CLAUDE_ARGS="--continue"
                shift
                ;;
              --resume|-r)
                if [[ -z "''${2:-}" ]]; then
                  echo "Error: --resume requires a session ID" >&2
                  exit 1
                fi
                CLAUDE_ARGS="--resume $2"
                shift 2
                ;;
              --help|-h)
                echo "Usage: voice-claude [--continue | --resume <session_id>]"
                echo ""
                echo "Options:"
                echo "  --continue, -c           Resume the most recent session"
                echo "  --resume, -r <id>        Resume a specific session by ID"
                echo "  --help, -h               Show this help message"
                exit 0
                ;;
              *)
                echo "Error: Unknown option: $1" >&2
                echo "Usage: voice-claude [--continue | --resume <session_id>]" >&2
                exit 1
                ;;
            esac
          done

          # Check dependencies
          for cmd in whisper-cli piper rec play claude; do
            command -v "$cmd" &>/dev/null || { echo "Missing: $cmd" >&2; exit 1; }
          done

          # Check models
          [[ -f "$WHISPER_MODEL" ]] || { echo "Whisper model not found: $WHISPER_MODEL" >&2; exit 1; }
          [[ -f "$PIPER_VOICE" ]] || { echo "Piper voice not found: $PIPER_VOICE" >&2; exit 1; }

          audio_file="$TMPDIR/voice-claude-$$.wav"
          trap 'rm -f "$audio_file"' EXIT

          # Record with Ctrl-C to stop
          printf '\a'  # Bell to indicate start
          echo "Recording... (Ctrl-C when done)"
          rec -q -r 16000 -c 1 "$audio_file" gain -3 || true

          # Transcribe (no timestamps, multi-threaded)
          echo "Transcribing..."
          prompt=$(whisper-cli -m "$WHISPER_MODEL" -f "$audio_file" -nt -np -t "$(nproc)" 2>/dev/null | xargs)

          [[ -z "$prompt" ]] && { echo "No speech detected" >&2; exit 1; }
          echo "> $prompt"

          # Query Claude with optional session args
          echo "Asking Claude..."
          response=$(claude -p "$prompt" $CLAUDE_ARGS 2>/dev/null)
          echo ""
          echo "$response"

          # Speak response (unless disabled)
          if [[ "$VOICE_CLAUDE_SPEAK" == "1" ]]; then
            echo "$response" | piper --model "$PIPER_VOICE" --output_raw 2>/dev/null | \
              play -q -r 22050 -e signed -b 16 -c 1 -t raw -
          fi
        '')

        # TTS helper for agent-initiated speech output
        (pkgs.writeShellScriptBin "claude-speak" ''
          set -euo pipefail
          PIPER_VOICE="''${PIPER_VOICE:-$HOME/.local/share/piper-voices/en_US-lessac-medium.onnx}"

          # Check dependencies
          command -v piper &>/dev/null || { echo "Missing: piper" >&2; exit 1; }
          command -v play &>/dev/null || { echo "Missing: play (sox)" >&2; exit 1; }

          [[ -f "$PIPER_VOICE" ]] || { echo "Piper voice not found: $PIPER_VOICE" >&2; exit 1; }

          # Accept text from argument or stdin
          if [[ $# -gt 0 ]]; then
            text="$*"
          else
            text=$(cat)
          fi

          [[ -z "$text" ]] && { echo "Error: No text provided" >&2; exit 1; }

          # Synthesize and play
          echo "$text" | piper --model "$PIPER_VOICE" --output_raw 2>/dev/null | \
            play -q -r 22050 -e signed -b 16 -c 1 -t raw -
        '')

        # STT helper for agent-initiated voice input
        (pkgs.writeShellScriptBin "claude-listen" ''
          set -euo pipefail
          WHISPER_MODEL="''${WHISPER_MODEL:-$HOME/.local/share/whisper-models/ggml-base.en.bin}"
          TMPDIR="''${TMPDIR:-/tmp}"

          # Check dependencies
          command -v whisper-cli &>/dev/null || { echo "Missing: whisper-cli" >&2; exit 1; }
          command -v rec &>/dev/null || { echo "Missing: rec (sox)" >&2; exit 1; }

          [[ -f "$WHISPER_MODEL" ]] || { echo "Whisper model not found: $WHISPER_MODEL" >&2; exit 1; }

          audio_file="$TMPDIR/claude-listen-$$.wav"
          trap 'rm -f "$audio_file"' EXIT

          # Record with Ctrl-C to stop
          printf '\a'  # Bell to indicate start
          echo "Listening... (Ctrl-C when done)" >&2
          rec -q -r 16000 -c 1 "$audio_file" gain -3 || true

          # Transcribe and output to stdout (no timestamps, multi-threaded)
          whisper-cli -m "$WHISPER_MODEL" -f "$audio_file" -nt -np -t "$(nproc)" 2>/dev/null | xargs
        '')
      ]
      ++ lib.optionals pkgs.stdenv.isLinux [
        xclip
        powerline
        git-credential-manager
        pipewire # Provides pw-play for audio playback (Claude Code hooks)
      ];

    file = {
      ".bash_profile".source = ./dotfiles/bash_profile;
      ".vimrc".source = ./dotfiles/vimrc;
      ".tmux.conf.local".source = ./dotfiles/tmux.conf.local;
      ".tmux.conf".source = ./dotfiles/.tmux.conf;
      ".config/starship.toml".source = ./dotfiles/starship.toml;
      ".config/starship-minimal.toml".source = ./dotfiles/starship-minimal.toml;
      ".claude/CLAUDE.md".source = ./dotfiles/claude/CLAUDE.md;
      ".claude/skills/commit-push-open-mr/SKILL.md".source =
        ./dotfiles/claude/skills/commit-push-open-mr/SKILL.md;
      ".claude/statusline-async.sh" = {
        source = ./dotfiles/claude/statusline-async.sh;
        executable = true;
      };
      ".claude/gitlab-status.sh" = {
        source = ./dotfiles/claude/gitlab-status.sh;
        executable = true;
      };
      ".claude/aws-sso-status.sh" = {
        source = ./dotfiles/claude/aws-sso-status.sh;
        executable = true;
      };
      ".claude/k8s-token-status.sh" = {
        source = ./dotfiles/claude/k8s-token-status.sh;
        executable = true;
      };
      ".claude/hooks/play-sound.sh".source = ./dotfiles/claude/hooks/play-sound.sh;
      ".claude/hooks/sounds/PeonReady1.ogg".source = ./dotfiles/claude/hooks/sounds/PeonReady1.ogg;
      ".claude/hooks/sounds/PeonYes3.ogg".source = ./dotfiles/claude/hooks/sounds/PeonYes3.ogg;
      ".claude/hooks/sounds/PeonWhat3.ogg".source = ./dotfiles/claude/hooks/sounds/PeonWhat3.ogg;
      ".claude/hooks/sounds/PeonBuildingComplete1.ogg".source =
        ./dotfiles/claude/hooks/sounds/PeonBuildingComplete1.ogg;
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
      claudeHooksSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        SETTINGS="${homeDirectory}/.claude/settings.json"
        HOOKS_JSON='${claudeHooksConfig}'

        mkdir -p "$(dirname "$SETTINGS")"
        if [ ! -f "$SETTINGS" ]; then
          echo "$HOOKS_JSON" | ${pkgs.jq}/bin/jq . > "$SETTINGS"
        else
          ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$SETTINGS" <(echo "$HOOKS_JSON") > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
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
          # Ignore unknown SSH options like GSSAPIAuthentication (Kerberos)
          "IgnoreUnknown" = "GSSAPIAuthentication";
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
