{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "joesmith";
  home.homeDirectory = "/home/joesmith";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    pkgs.fish
    pkgs.htop
    pkgs.fortune
    pkgs.delta
    pkgs.fd
    pkgs.ripgrep
    pkgs.xclip
    pkgs.zoxide
    pkgs.starship
    pkgs.vim
    pkgs.git-lfs

    pkgs.awscli2
    pkgs.eksctl
    pkgs.vagrant
    pkgs.packer

    pkgs.tfsec
    pkgs.tflint
    pkgs.terraform-ls
    pkgs.kubectl
    pkgs.helm
    pkgs.minikube
    pkgs.cbonsai
    pkgs.ctop
    pkgs.dive
    pkgs.stern
    pkgs.procs
    pkgs.dog
    pkgs.gping
    pkgs.docker-compose
    pkgs.viddy
    pkgs.cheat
    pkgs.k6
    pkgs.navi

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

    pkgs.taskwarrior
    pkgs.vit

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    (pkgs.nerdfonts.override { fonts = [ "CascadiaCode" ]; })

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

    ".config/fish/conf.d" = {
      source = ./dotfiles/fish_conf.d;
      recursive = true;
    };

    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
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
    # TODO(joe): This doesn't actually evaluate here
    # GPG_TTY = "(tty)";
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

  fonts.fontconfig.enable = true;

  programs.fzf.enable = true;
  programs.direnv.enable = true;

  programs.exa.enable = true;
  programs.exa.enableAliases = true;

  programs.fish.enable = true;

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
       [ -n $REPO ]
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
      for filepath in (git status | grep -E 'both (added|modified)' | awk '{print $3}' )
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

    substrate_credentials = ''
      set SUBSTRATE_OUTPUT (refreshment -p (which substrate) -r ~/src/sw/infrastructure/terraform)
      set AWS_ACCESS_KEY_ID (echo $SUBSTRATE_OUTPUT | cut -f3 -d" " | cut -f2 -d\" )
      set AWS_SECRET_ACCESS_KEY (echo $SUBSTRATE_OUTPUT | cut -f4 -d" " | cut -f2 -d\" )
      set AWS_SESSION_TOKEN (echo $SUBSTRATE_OUTPUT | cut -f5 -d" " | cut -f2 -d\" )
      python -c "from os import path; from configparser import ConfigParser; config = ConfigParser(); config.read(path.expanduser('~/.aws/credentials'))
    if '$AWS_ACCESS_KEY_ID' == "":
      print('Existing creds should already be wired in!')
    else:
      for profile_name in ['default', 'refreshment_substrate']:
        config.set(profile_name, 'aws_access_key_id', '$AWS_ACCESS_KEY_ID')
        config.set(profile_name, 'aws_secret_access_key', '$AWS_SECRET_ACCESS_KEY')
        config.set(profile_name, 'aws_session_token', '$AWS_SESSION_TOKEN')
      with open(path.expanduser('~/.aws/credentials'), 'w') as credentialsFile:
        config.write(credentialsFile)
    "
    '';

    update_submodules = "git submodule foreach git pull origin master";

    vault_login = ''
      set -e VAULT_TOKEN
    
      if [ -z (which vault) ]
        echo "No vault binary installed!"
        exit
      end
    
      vault login -non-interactive -method=userpass username=joe.smith \
          password=(keepassxc-cli show -s -a Password ~/Documents/joe.smith.kdbx Vault)
      '';
    
  };

  programs.atuin.enable = true;
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
    
    # Adds extra functionality over rust analyzer
    # https://github.com/sharksforarms/vim-rust/blob/82b4b1a/neovim-init-lsp-cmp-rust-tools.vim
    rust-tools-nvim
    
    popup-nvim
    plenary-nvim
    telescope-nvim
    nvim-treesitter
    nord-vim
    fzf-vim
    vim-go
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
    
    require('lspconfig')['tsserver'].setup{
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
    enable = true;
    showMenubar = false;

    profile.b1dcc9dd-5262-4d8d-a863-c897e6d979b9 = {
      audibleBell = false;

      default = true;
      visibleName = "Nord";

      showScrollbar = false;
      transparencyPercent = 5;
      font = "Cascadia Code PL 14";
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
