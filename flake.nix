{
  description = "Joe's Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }:
    let
      mkHomeConfiguration =
        system:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          modules = [ ./home.nix ];
        };
    in
    {
      homeConfigurations = {
        "linux" = mkHomeConfiguration "x86_64-linux";
        "joe" = mkHomeConfiguration "aarch64-darwin";
        "joe.smith" = mkHomeConfiguration "aarch64-darwin";
      };
    };
}
