{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = if pkgs.stdenv.isDarwin then "joe.smith" else "joe";
  home.homeDirectory = if pkgs.stdenv.isDarwin then "/Users/joe.smith" else "/home/joe";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.05"; # Please read the comment before changing.

  # For hashicorp tools
  nixpkgs.config.allowUnfree = true;

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    pkgs.clang-tools
    pkgs.gcc

    pkgs.fish
    pkgs.htop
    pkgs.fortune
    pkgs.delta
    pkgs.fd
    pkgs.eza
    pkgs.ripgrep
    pkgs.xclip
    pkgs.zoxide
    pkgs.starship
    pkgs.vim
    pkgs.git-lfs
    pkgs.pyenv
    pkgs.gnupg
    pkgs.nethack

    #pkgs.awscli2
    pkgs.eksctl
    #pkgs.vagrant
    pkgs.packer
    #pkgs.vault

    pkgs.tfsec
    pkgs.tflint
    pkgs.terraform-ls
    pkgs.kubectl
    pkgs.kubernetes-helm
    pkgs.minikube
    pkgs.cbonsai
    pkgs.ctop
    pkgs.dive
    pkgs.stern
    pkgs.procs
    pkgs.gping
    pkgs.docker-compose
    pkgs.viddy
    pkgs.cheat
    pkgs.k6
    pkgs.navi
    pkgs.pv

    pkgs.glow

    pkgs.pyright

    pkgs.cheat

    pkgs.topgrade

    pkgs.rustup

    pkgs.nmap
    pkgs.shellcheck
    pkgs.pipenv
    pkgs.powerline
    pkgs.neofetch
    pkgs.curl
    pkgs.cascadia-code
    pkgs.tmux
    pkgs.mosh
    pkgs.btop

    pkgs.gawk
    pkgs.gopls
    pkgs.nodePackages.bash-language-server
    pkgs.nodePackages.dockerfile-language-server-nodejs
    pkgs.nodePackages.typescript-language-server
    pkgs.nodePackages.typescript
    pkgs.nil

    pkgs.taskwarrior3
    pkgs.vit

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    ".config/nix/nix.conf".text = "experimental-features = nix-command flakes";

    ".bash_profile".source = dotfiles/bash_profile;
    ".git-completion.bash".source = dotfiles/git-completion.bash;
    ".git-prompt.sh".source = dotfiles/git-prompt.sh;
    ".vimrc".source = dotfiles/vimrc;
    ".gitignore".source = dotfiles/gitignore;
    ".gitconfig".source = dotfiles/gitconfig;
    ".tmux.conf.local".source = dotfiles/tmux.conf.local;
    ".tmux.conf".source = tmux/.tmux.conf;

    ".config/alacritty/alacritty.yml".source = dotfiles/alacritty.yml;
    ".config/starship.toml".source = dotfiles/starship.toml;

    ".vim" = {
      source = ./dotfiles/vim;
      recursive = true;
    };

    ".config/fish/conf.d/nix" = {
      source = ./dotfiles/fish_conf.d;
      recursive = true;
    };
  };


  # You can also manage environment variables but you will have to manually
  # source
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/joesmith/etc/profile.d/hm-session-vars.sh
  #
  # if you don't want to manage your shell through Home Manager.
  home.sessionVariables = {
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
    "$HOME/workspace/go/bin"
    "$HOME/workspace/bin"
    "/opt/homebrew/bin"
    "$HOME/src/sw/ops/bin/cache"
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.fish.enable = true;

  fonts.fontconfig.enable = true;

  programs.fzf.enable = true;

  programs.zoxide.enable = true;
  programs.starship.enable = true;

  programs.fish.functions = {
    clone = ''
      set LOCATION $argv[1]
      if echo $LOCATION | grep -q https
          set PROVIDER (echo $LOCATION | cut -f3 -d/ | tr -d '[:space:]' )
          set OWNER (echo $LOCATION | cut -f4 -d/ )
          set REPO (echo $LOCATION | cut -f5 -d/ )
      else
          set PROVIDER (echo $LOCATION | cut -f1 -d: | cut -f2 -d\@)
          set OWNER (echo $LOCATION | cut -f2 -d: | cut -f1 -d/)
          set REPO (echo $LOCATION | cut -f2 -d: | cut -f2 -d/ | cut -f1 -d.)
        if [ -n $REPO ]
            # This is a GitLab-ism
            set SUBPROJECT (echo $LOCATION | cut -f2 -d: | cut -f3 -d/ | cut -f1 -d.)
        end
      end

      if [ -n $SUBPROJECT ]
        set FILESYSTEM_LOCATION "$HOME/workspace/$PROVIDER/$OWNER/$SUBPROJECT"
      else
        set FILESYSTEM_LOCATION "$HOME/workspace/$PROVIDER/$OWNER"
      end

      #echo $PROVIDER
      #echo $OWNER
      #echo $REPO
      #echo $SUBPROJECT
      #echo $FILESYSTEM_LOCATION
      #return

      mkdir -p "$FILESYSTEM_LOCATION"
      git clone "$LOCATION" "$FILESYSTEM_LOCATION/$REPO"
      cd "$FILESYSTEM_LOCATION/$REPO"
    '';


    fireball = ''
      branch
      git status
      git reset --hard HEAD
      git status
      git status | grep '/' | tr -d '\t' | grep -v modified | xargs rm -r
      git status
    '';

    rebase_party = ''
      for filepath in ( git diff --name-only --diff-filter=U )
          nvim $filepath
          git add $filepath
          git status
      end

      git status
      git rebase --continue
      git status
    '';

    shipped = ''
      set BRANCH (git branch | grep \* | awk '{print $2}')
      echo "Deleting $BRANCH"
      git checkout master
      git branch -D $BRANCH
      git pull origin master
    '';

    update_submodules = "git submodule foreach git pull origin master";

    vault_login = ''
      set -e VAULT_TOKEN

      if [ -z (which vault) ]
        echo "No vault binary installed!"
        return
      end

      set KEEPASS_CLI keepassxc-cli
      if [ -z (which "$KEEPASS_CLI" ) ]
        set KEEPASS_CLI /Applications/KeePassXC.app/Contents/MacOS/keepassxc-cli
      end
      if [ -z (which "$KEEPASS_CLI" ) ]
        set KEEPASS_CLI flatpak run --branch=stable --arch=x86_64 --command=keepassxc-cli org.keepassxc.KeePassXC
      end

      set KEEPASS_VAULT ~/Documents/joe.smith.kdbx
      if [ ! -f "$KEEPASS_VAULT" ]
        set KEEPASS_VAULT ~/joe.smith.kdbx
      end

      set -Ux VAULT_TOKEN (VAULT_ADDR="https://vault.int.n7k.io:443" vault login -token-only -non-interactive -method=userpass username=joe.smith \
          password=( $KEEPASS_CLI  show -s -a Password $KEEPASS_VAULT Vault) )
      '';

  };
  # Already provided by sw_setup, see programs.fish.shellInit
  #programs.direnv.enable = true;
  programs.fish.shellInit = '' 
    direnv hook fish | source
  '';

  programs.atuin.enable = true;
  programs.atuin.flags = ["--disable-up-arrow"];
  programs.bat.enable = true;
  programs.jq.enable = true;
  programs.k9s.enable = true;
  programs.neovim.enable = true;
  programs.neovim.defaultEditor = true;
  programs.neovim.plugins = with pkgs.vimPlugins; [
    nvim-lspconfig
    nvim-cmp
    cmp-nvim-lsp
    cmp-nvim-lsp-signature-help
    cmp-path
    cmp-buffer
    copilot-vim

    # Adds extra functionality over rust analyzer
    # https://github.com/sharksforarms/vim-rust/blob/82b4b1a/neovim-init-lsp-cmp-rust-tools.vim
    rust-tools-nvim

    popup-nvim
    plenary-nvim
    telescope-nvim
    nvim-treesitter.withAllGrammars
    nord-vim
    fzf-vim
    #vim-go
    vim-fugitive
    vim-terraform
    vim-protobuf
    vim-mustache-handlebars
    vim-fish
    vim-nix

    # https://github.com/lewis6991/gitsigns.nvim
    gitsigns-nvim

    # https://github.com/lukas-reineke/indent-blankline.nvim
    indent-blankline-nvim

    # https://github.com/nvim-neo-tree/neo-tree.nvim
    neo-tree-nvim
    nvim-web-devicons
    nui-nvim

    # https://github.com/nvim-lualine/lualine.nvim
    lualine-nvim

    # https://www.youtube.com/watch?v=-InmtHhk2qM
    # https://github.com/numToStr/Comment.nvim
    comment-nvim

    # https://github.com/sindrets/diffview.nvim
    diffview-nvim
  ];

  programs.neovim.extraConfig = ''
    " https://mukeshsharma.dev/2022/02/08/neovim-workflow-for-terraform.html
    silent! autocmd! filetypedetect BufRead,BufNewFile *.tf
    autocmd BufRead,BufNewFile *.hcl set filetype=hcl]])
    autocmd BufRead,BufNewFile .terraformrc,terraform.rc set filetype=hcl
    autocmd BufRead,BufNewFile *.tf,*.tfvars set filetype=terraform
    autocmd BufRead,BufNewFile *.tfstate,*.tfstate.backup set filetype=json
    let g:terraform_fmt_on_save=1
    let g:terraform_align=1

    " Code navigation shortcuts
    " as found in :help lsp
    nnoremap <silent> <c-]> <cmd>lua vim.lsp.buf.definition()<CR>
    nnoremap <silent> K     <cmd>lua vim.lsp.buf.hover()<CR>
    nnoremap <silent> gD    <cmd>lua vim.lsp.buf.implementation()<CR>
    nnoremap <silent> <c-k> <cmd>lua vim.lsp.buf.signature_help()<CR>
    nnoremap <silent> 1gD   <cmd>lua vim.lsp.buf.type_definition()<CR>
    nnoremap <silent> gr    <cmd>lua vim.lsp.buf.references()<CR>
    nnoremap <silent> g0    <cmd>lua vim.lsp.buf.document_symbol()<CR>
    nnoremap <silent> gW    <cmd>lua vim.lsp.buf.workspace_symbol()<CR>
    nnoremap <silent> gd    <cmd>lua vim.lsp.buf.definition()<CR>

    " https://neovim.io/doc/user2/diagnostic.html#vim.diagnostic.open_float()
    nnoremap <silent> W     <cmd>lua vim.diagnostic.open_float()<CR>

    " Quick-fix
    nnoremap <silent> ga    <cmd>lua vim.lsp.buf.code_action()<CR>

    " Set updatetime for CursorHold
    " 500ms of no cursor movement to trigger CursorHold
    set updatetime=500
    " Show diagnostic popup on cursor hover
    autocmd CursorHold * lua vim.diagnostic.open_float()

    colorscheme nord

    " why the heck is this getting overridden
    nmap <silent> <C-M> :silent noh<CR> :echo "Highlights Cleared! bjoli"<CR>

    set mouse=
  '';
  programs.neovim.extraLuaConfig = ''
    local nvim_lsp = require'lspconfig'

    local opts = {
        tools = {
            autoSetHints = true,
            runnables = {
                use_telescope = true
            },
            inlay_hints = {
                show_parameter_hints = true,
                parameter_hints_prefix = "",
                other_hints_prefix = "",
            },
        },
    }

    require('rust-tools').setup(opts)

    local capabilities = require('cmp_nvim_lsp').default_capabilities(vim.lsp.protocol.make_client_capabilities())

    require('lspconfig')['pyright'].setup {
      capabilities = capabilities,
    }

    require'lspconfig'.rust_analyzer.setup{}

    -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#bashls
    require'lspconfig'.bashls.setup {
      capabilities = capabilities,
    }

    -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#dockerls
    require'lspconfig'.dockerls.setup {
      capabilities = capabilities,
    }

    -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#gopls
    -- https://github.com/golang/tools/tree/master/gopls
    require'lspconfig'.gopls.setup {
      capabilities = capabilities,
    }

    -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#terraformls
    -- https://github.com/hashicorp/terraform-ls
    require'lspconfig'.terraformls.setup {
      capabilities = capabilities,
    }

    -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#tflint
    require'lspconfig'.tflint.setup{
      capabilities = capabilities,
    }

    require('lspconfig')['ts_ls'].setup{
      capabilities = capabilities,
    }

    require('lspconfig').nil_ls.setup {
      autostart = true,
      capabilities = capabilities,
      settings = {
        ['nil'] = {
          formatting = {
            command = { "nixpkgs-fmt" },
          },
        },
      },
    }

    require'lspconfig'.clangd.setup{}

    require('gitsigns').setup {}

    require('nvim-web-devicons').setup { default = true; }
    require("neo-tree").setup { close_if_last_window = true } -- Close Neo-tree if it is the last window left in the tab
    require('Comment').setup()

    local cmp = require'cmp'
    cmp.setup({
      mapping = {
        ['<C-p>'] = cmp.mapping.select_prev_item(),
        ['<C-n>'] = cmp.mapping.select_next_item(),
        ['<C-d>'] = cmp.mapping.scroll_docs(-4),
        ['<C-f>'] = cmp.mapping.scroll_docs(4),
        ['<C-Space>'] = cmp.mapping.complete(),
        ['<C-e>'] = cmp.mapping.close(),
        ['<CR>'] = cmp.mapping.confirm({
          behavior = cmp.ConfirmBehavior.Insert,
          select = true,
        }),
      },

      -- Installed sources
      sources = {
        { name = 'nvim_lsp' },
        { name = 'path' },
        { name = 'buffer' },
        { name = 'nvim_lsp_signature_help' }
      },
    })


    require'nvim-treesitter.configs'.setup {
      -- Modules and its options go here
      highlight = { enable = true },
      incremental_selection = { enable = true },
      textobjects = { enable = true },
    }

    require('lualine').setup {}

    -- Use LSP as the handler for omnifunc.
    --    See `:help omnifunc` and `:help ins-completion` for more information.
    vim.api.nvim_buf_set_option(0, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

  '';

  programs.gnome-terminal = {
    enable = pkgs.hostPlatform.isLinux;
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
          "#21252B" "#B85960" "#98C379" "#C4A469"
          "#61AFEF" "#B57EDC" "#56B6C2" "#A9B2C3"
          "#5F6672" "#FF7A85" "#C6FF9E" "#FFD588"
          "#67BAFF" "#D192FF" "#71EFFF" "#DDE8FF"
        ];
      };

    };
  };
}
