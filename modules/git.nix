{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.git = {
    enable = true;

    includes = [
      {
        condition = "gitdir:~/src/";
        contents = {
          user.email = "joe.smith@neuralink.com";
        };
      }
    ];

    lfs.enable = true;

    settings = {
      user = {
        name = "Joe Smith";
        email = "yasumoto7@gmail.com";
      };

      alias = {
        l = "log --pretty=oneline -n 20 --graph";
        s = "status -s";
      };

      github.user = "Yasumoto";
      apply.whitespace = "fix";

      credential = lib.mkMerge [
        {
          helper =
            if pkgs.stdenv.isDarwin then
              "osxkeychain"
            else
              "${pkgs.git-credential-manager}/bin/git-credential-manager";
        }
        (lib.mkIf pkgs.stdenv.isLinux {
          credentialStore = "secretservice";
        })
      ];

      color = {
        ui = "auto";
        branch = {
          current = "yellow reverse";
          local = "yellow";
          remote = "green";
        };
        status = {
          added = "yellow";
          changed = "green";
          untracked = "cyan";
        };
      };

      core.whitespace = "fix,-indent-with-non-tab,trailing-space,cr-at-eol";

      branch = {
        autosetupmerge = true;
        master = {
          remote = "origin";
          merge = "refs/heads/master";
        };
      };

      push.default = "current";
      pull.ff = "only";
      init.defaultBranch = "main";
    };

    ignores = [
      "*.com"
      "*.class"
      "*.dll"
      "*.exe"
      "*.o"
      "*.so"
      "*.7z"
      "*.dmg"
      "*.gz"
      "*.iso"
      "*.jar"
      "*.rar"
      "*.tar"
      "*.zip"
      "*.log"
      "*.sql"
      "*.sqlite"
      ".DS_Store"
      ".DS_Store?"
      "._*"
      ".Spotlight-V100"
      ".Trashes"
      "Icon?"
      "ehthumbs.db"
      "Thumbs.db"
      "*.swp"
      "*.swo"
      "node_modules"
      "npm-debug.log"
    ];
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      features = "decorations";
      navigate = true;
    };
  };
}
