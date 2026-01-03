{ config, pkgs, lib, ... }:

{
  programs.git = {
    enable = true;

    userName = "Joe Smith";
    userEmail = "yasumoto7@gmail.com";

    includes = [
      {
        condition = "gitdir:~/src/";
        contents = {
          user.email = "joe.smith@neuralink.com";
        };
      }
    ];

    aliases = {
      l = "log --pretty=oneline -n 20 --graph";
      s = "status -s";
    };

    delta = {
      enable = true;
      options = {
        features = "decorations";
        navigate = true;
      };
    };

    lfs.enable = true;

    extraConfig = {
      github.user = "Yasumoto";
      apply.whitespace = "fix";

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
      "*.com" "*.class" "*.dll" "*.exe" "*.o" "*.so"
      "*.7z" "*.dmg" "*.gz" "*.iso" "*.jar" "*.rar" "*.tar" "*.zip"
      "*.log" "*.sql" "*.sqlite"
      ".DS_Store" ".DS_Store?" "._*" ".Spotlight-V100" ".Trashes"
      "Icon?" "ehthumbs.db" "Thumbs.db"
      "*.swp" "*.swo"
      "node_modules" "npm-debug.log"
    ];
  };
}
