{ config, pkgs, lib, ... }:

let
  username =
    if pkgs.stdenv.isLinux then
      "joe"
    else if pkgs.stdenv.isDarwin then
      (if builtins.pathExists /Users/joe.smith/src then "joe.smith" else "joe")
    else
      "joe";

  homeDirectory =
    if pkgs.stdenv.isLinux then
      "/home/joe"
    else if pkgs.stdenv.isDarwin then
      "/Users/${username}"
    else
      "/home/joe";
in
{
  imports = [
    ./modules/fish.nix
    ./modules/git.nix
  ];

  home.username = username;
  home.homeDirectory = homeDirectory;
  home.stateVersion = "23.05";

  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    awscli2
    clang-tools
    gcc
    fish
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
    tfsec
    tflint
    terraform-ls
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
    pyenv
    rustup
    pipenv
    shellcheck
    nodejs
    gawk
    curl
    go
    pyright
    gopls
    nodePackages.bash-language-server
    dockerfile-language-server-nodejs
    nodePackages.typescript-language-server
    nodePackages.typescript
    nil
    jdt-language-server
    yaml-language-server
    cascadia-code
    tmux
    mosh
    taskwarrior3
    vit
    nethack
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    xclip
    powerline
  ];

  home.file = {
    ".bash_profile".source = ./dotfiles/bash_profile;
    ".vimrc".source = ./dotfiles/vimrc;
    ".tmux.conf.local".source = ./dotfiles/tmux.conf.local;
    ".tmux.conf".source = ./tmux/.tmux.conf;
    ".config/starship.toml".source = ./dotfiles/starship.toml;
    ".config/starship-minimal.toml".source = ./dotfiles/starship-minimal.toml;
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
    "$HOME/go/bin"
    "$HOME/workspace/bin"
  ] ++ lib.optionals pkgs.stdenv.isDarwin [
    "/opt/homebrew/bin"
  ];

  # Disable broken SSH_ASKPASS on BlueFin (points to non-existent gnome-ssh-askpass)
  home.sessionVariables = lib.mkIf pkgs.stdenv.isLinux {
    SSH_ASKPASS = "";
    SUDO_ASKPASS = "";
  };

  programs.home-manager.enable = true;
  fonts.fontconfig.enable = true;
  programs.fzf.enable = true;
  programs.zoxide.enable = true;
  programs.starship.enable = true;
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  programs.atuin = {
    enable = true;
    flags = [ "--disable-up-arrow" ];
  };

  programs.bat.enable = true;
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
      editor = "";
    };
  };
  programs.jq.enable = true;
  programs.k9s.enable = true;

  services.ssh-agent.enable = pkgs.stdenv.isLinux;

  programs.neovim = {
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
      (nvim-treesitter.withPlugins (p: with p; [
        lua rust go python typescript javascript nix terraform bash fish json yaml toml markdown vim c cpp
      ]))
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

  programs.gnome-terminal = {
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
          "#21252B" "#B85960" "#98C379" "#C4A469"
          "#61AFEF" "#B57EDC" "#56B6C2" "#A9B2C3"
          "#5F6672" "#FF7A85" "#C6FF9E" "#FFD588"
          "#67BAFF" "#D192FF" "#71EFFF" "#DDE8FF"
        ];
      };
    };
  };
}
