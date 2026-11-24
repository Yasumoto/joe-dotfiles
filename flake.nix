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
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];

      # isWork: work-only config (e.g. linking ~/.claude/work-config). The work
      # repos are cloned separately: `nix run <flake>#clone-work-repos`.
      configs = {
        joe = {
          username = "joe";
          isWork = true;
        };
        "joe.smith" = {
          username = "joe.smith";
          isWork = true;
        };
        personal = {
          username = "joe";
          isWork = false;
        };
      };

      # hmConfigName is the attribute name in `configs`, so home.nix never has
      # to guess which config it is from the username.
      mkHomeConfiguration =
        system: hmConfigName:
        { username, isWork }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          extraSpecialArgs = {
            inherit username isWork hmConfigName;
            herdrPkgs = herdr.packages.${system};
          };
          modules = [
            ./home.nix
            onepassword-shell-plugins.hmModules.default
          ];
        };
    in
    {
      # Per-system, so a switch picks this machine's OS. home-manager builds
      # `<flake>#homeConfigurations."<name>"` (name defaults to $USER), and Nix
      # resolves that through legacyPackages.<system>. Don't add `user@host`
      # names: with no `#name`, home-manager would prefer them over $USER.
      # Not seen by `home-manager repl`, `nix flake check`, or `nix flake show`
      # (without --legacy).
      packages = nixpkgs.lib.genAttrs systems (system: {
        clone-work-repos = nixpkgs.legacyPackages.${system}.callPackage ./pkgs/clone-work-repos.nix { };
      });

      legacyPackages = nixpkgs.lib.genAttrs systems (system: {
        homeConfigurations = builtins.mapAttrs (mkHomeConfiguration system) configs;
      });
    };
}
