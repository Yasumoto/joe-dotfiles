{
  pkgs,
  pkgs-unstable,
  lib,
  ...
}:

{
  home.packages = [
    # Use Go 1.26 from unstable because gogcli requires go >= 1.25.8, but nixpkgs stable only has 1.25.7
    (pkgs.buildGoModule.override { go = pkgs-unstable.go_1_26; } rec {
      pname = "gogcli";
      version = "unstable-2024-12-20";

      src = pkgs.fetchFromGitHub {
        owner = "steipete";
        repo = "gogcli";
        rev = "4b06fabb4c62551be5eb72b4624f95e84cdac2fd";
        hash = "sha256-IapgJWMA4RrOl4lcYBpavOYat1MyjE5fxSPZqcOxi1w=";
      };

      vendorHash = "sha256-8RKzJq4nlg7ljPw+9mtiv0is6MeVtkMEiM2UUdKPP3U=";

      ldflags = [
        "-X github.com/steipete/gogcli/internal/cmd.version=${version}"
        "-X github.com/steipete/gogcli/internal/cmd.commit=${src.rev}"
        "-X github.com/steipete/gogcli/internal/cmd.date=1970-01-01T00:00:00Z"
      ];

      # Build from the cmd/gog directory
      subPackages = [ "cmd/gog" ];

      # The output binary is 'gog' by default
      # Create an alias called 'gogcli' for consistency
      postInstall = ''
        ln -s $out/bin/gog $out/bin/gogcli
      '';

      meta = with lib; {
        description = "Fast, script-friendly CLI for Gmail, Calendar, Chat, Classroom, Drive, Docs, Slides, Sheets, and more";
        homepage = "https://github.com/steipete/gogcli";
        license = licenses.mit;
        maintainers = [ ];
        mainProgram = "gog";
      };
    })
  ];
}
