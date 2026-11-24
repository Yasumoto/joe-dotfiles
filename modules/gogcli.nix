{
  pkgs,
  lib,
  ...
}:

{
  programs.fish.functions = {
    # Google Workspace CLI (gogcli) helpers
    gog-accounts = ''
      gog account --list
    '';

    gog-gmail-list = ''
      # Quick Gmail list (last 10 threads)
      gog gmail thread --list --limit 10
    '';

    gog-send = ''
      # Send email via gogcli
      if test (count $argv) -lt 2
        echo "Usage: gog-send <to@example.com> <subject> [body]"
        return 1
      end

      set to $argv[1]
      set subject $argv[2]
      set body ""
      if test (count $argv) -ge 3
        set body $argv[3]
      end

      gog gmail send --to "$to" --subject "$subject" --body "$body"
    '';

    gog-status = ''
      # Check gogcli auth status
      echo "=== Google Workspace CLI Status ==="
      gog account --list
      echo ""
      echo "To authenticate: gog account --add <account-name>"
      echo "To use: gog gmail thread --list"
    '';
  };

  home.packages = [
    # Stable 26.05 ships Go 1.26.x (gogcli needs go >= 1.25.8)
    (pkgs.buildGoModule rec {
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
