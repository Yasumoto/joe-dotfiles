{
  description = "Joe's Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    onepassword-shell-plugins = {
      url = "github:1Password/shell-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Keep herdr on its own nixpkgs + rust-overlay (do not follows nixpkgs).
    herdr.url = "github:ogulcancelik/herdr/v0.7.5";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      onepassword-shell-plugins,
      herdr,
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
            herdrPkgs = herdr.packages.${system};
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
        "darwin" = mkHomeConfiguration "aarch64-darwin" "joe";
        "darwin-joe.smith" = mkHomeConfiguration "aarch64-darwin" "joe.smith";
      };
    };
}
