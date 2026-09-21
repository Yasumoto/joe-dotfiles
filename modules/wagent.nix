{
  config,
  pkgs,
  lib,
  ...
}:

# Wagent companion: snapshot Grok Build sessions into the WoW addon.
# Source checkout: ~/workspace/github.com/Yasumoto/wagent (private).
# Linux-only; the service no-ops if the checkout is missing.

let
  src = "${config.home.homeDirectory}/workspace/github.com/Yasumoto/wagent";
  python = pkgs.python3;
  wagent-sync = pkgs.writeShellApplication {
    name = "wagent-sync";
    runtimeInputs = [ python ];
    text = ''
      exec ${python}/bin/python3 "${src}/companion/wagent_sync.py" "$@"
    '';
  };
in
lib.mkIf pkgs.stdenv.isLinux {
  home.packages = [ wagent-sync ];

  systemd.user.services.wagent-sync = {
    Unit = {
      Description = "Wagent Grok session sync for World of Warcraft";
      After = [ "default.target" ];
      ConditionPathExists = "${src}/companion/wagent_sync.py";
    };
    Service = {
      ExecStart = "${wagent-sync}/bin/wagent-sync --watch 15";
      Restart = "always";
      RestartSec = "5";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
