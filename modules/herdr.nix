{
  herdrPkgs,
  ...
}:

{
  # Agent-aware terminal multiplexer (https://herdr.dev/)
  # Packaged via the upstream flake; update with: nix flake update herdr
  home.packages = [
    herdrPkgs.herdr
  ];
}
