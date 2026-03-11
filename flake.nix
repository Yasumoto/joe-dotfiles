{
  description = "Joe's Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    onepassword-shell-plugins = {
      url = "github:1Password/shell-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      onepassword-shell-plugins,
      ...
    }:
    let
      mkHomeConfiguration =
        system: username:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          extraSpecialArgs = {
            inherit username;
          };
          modules = [
            ./home.nix
            onepassword-shell-plugins.hmModules.default
          ];
        };
    in
    {
      homeConfigurations = {
        "linux" = mkHomeConfiguration "x86_64-linux" "joe";
        "joe" = mkHomeConfiguration "aarch64-darwin" "joe";
        "joe.smith" = mkHomeConfiguration "aarch64-darwin" "joe.smith";
      };
    };
}
