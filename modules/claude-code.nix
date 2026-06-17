{
  config,
  pkgs,
  lib,
  ...
}:

let
  homeDir = config.home.homeDirectory;
  hooksDir = "${homeDir}/.claude/hooks";
  soundsDir = "${hooksDir}/sounds";
  hookCmd = sound: "${hooksDir}/play-sound.sh ${soundsDir}/${sound}";
  soundHook = sound: [
    {
      hooks = [
        {
          type = "command";
          command = hookCmd sound;
        }
      ];
    }
  ];

  # Declarative plugin list — true = enabled, false = explicitly disabled
  # (explicit false overrides any manual /plugin enable in settings.json)
  enabledPlugins = {
    "pyright-lsp@claude-plugins-official" = true;
    "typescript-lsp@claude-plugins-official" = true;
    "gopls-lsp@claude-plugins-official" = true;
    "ralph-loop@claude-plugins-official" = true;
    "hookify@claude-plugins-official" = true;
    "commit-commands@claude-plugins-official" = true;
    "playwright@claude-plugins-official" = false;
  };

  # Permission groups — passed through mkBashAllow to get Bash(cmd:*) form
  readOnlyCoreutils = [
    "ls"
    "cat"
    "head"
    "tail"
    "wc"
    "stat"
    "find"
    "md5sum"
    "sha256sum"
    "jq"
  ];
  bazelCmds = [
    "bazel query"
    "bazel info"
    "bazel build"
    "bazel test"
    "./bazel query"
    "./bazel info"
    "./bazel build"
    "./bazel test"
  ];
  glabReadCmds = [
    "glab api"
    "glab mr list"
    "glab mr view"
    "glab ci view"
    "glab ci trace"
    "glab ci list"
    "glab ci status"
    "glab issue list"
    "glab issue view"
  ];
  kubectlReadVerbs = [
    "get"
    "describe"
    "logs"
    "top"
    "config"
  ];
  # NB: the flag-prefix forms must stay glob-style — `:*` is literal prefix-match
  # syntax that does not interpret `*` as a glob, so `kubectl --context *get:*`
  # would match nothing. Keep the trailing space + `*` glob.
  kubectlPerms =
    (map (v: "Bash(kubectl ${v}:*)") kubectlReadVerbs)
    ++ (lib.concatMap (flag: map (v: "Bash(kubectl ${flag} *${v} *)") kubectlReadVerbs) [
      "--context"
      "-n"
    ]);

  mkBashAllow = cmds: map (c: "Bash(${c}:*)") cmds;

  globalPermissions = {
    allow = [
      "Read(**)"
      "Glob(**)"
      "Grep(**)"
      "Bash(git:*)"
    ]
    ++ mkBashAllow glabReadCmds
    ++ kubectlPerms
    ++ mkBashAllow readOnlyCoreutils
    ++ mkBashAllow bazelCmds;
    deny = [
      "Bash(terraform*)"
      # Device-code auth is being removed from work skills; block the auth-subcommand
      # forms the skills actually use. Avoid substring-matching `--device-code` so
      # git/rg searches for the string still work.
      "Bash(* auth --device-code*)"
      "Bash(*_api.py auth --device-code*)"
    ];
  };

  claudeMcpOverlay = builtins.toJSON {
    mcpServers = {
      xai-docs = {
        type = "http";
        url = "https://docs.x.ai/api/mcp";
      };
      agent-voice = {
        command = "${homeDir}/.cargo/bin/agent-voice-mcp";
      };
    };
  };

  claudeSettingsOverlay = builtins.toJSON {
    statusLine = {
      type = "command";
      command = "${homeDir}/.claude/statusline-async.sh";
    };
    hooks = {
      SessionStart = soundHook "PeonReady1.ogg";
      UserPromptSubmit = soundHook "PeonYes3.ogg";
      Notification = soundHook "PeonWhat3.ogg";
      Stop = soundHook "PeonBuildingComplete1.ogg";
      PostToolUse = [
        {
          matcher = "Edit|Write|MultiEdit";
          hooks = [
            {
              type = "command";
              command = "${hooksDir}/pre-commit-check.sh";
            }
          ];
        }
      ];
      PostCompact = [
        {
          hooks = [
            {
              type = "command";
              command = "${hooksDir}/dump-memory.sh";
            }
          ];
        }
      ];
    };
    fileSuggestion = {
      type = "command";
      command = "${homeDir}/.claude/file-suggestion.sh";
    };
    inherit enabledPlugins;
    permissions = globalPermissions;
    autoDreamEnabled = true;
  };

  # One home.file entry per skill directory, so ~/.claude/skills stays a real
  # directory and the activation script can drop work-config skill symlinks
  # alongside the public ones. A whole-directory source would make the parent
  # itself a symlink into the read-only Nix store.
  skillsSrc = ../dotfiles/claude/skills;
  publicSkills = lib.mapAttrs' (name: _: {
    name = ".claude/skills/${name}";
    value.source = "${skillsSrc}/${name}";
  }) (lib.filterAttrs (_: type: type == "directory") (builtins.readDir skillsSrc));
in
{
  home.file = publicSkills // {
    # CLAUDE.md — personal workflow conventions
    ".claude/CLAUDE.md".source = ../dotfiles/claude/CLAUDE.md;

    # File suggestion script — custom @ autocomplete via git ls-files + fzf
    ".claude/file-suggestion.sh" = {
      source = ../dotfiles/claude/file-suggestion.sh;
      executable = true;
    };

    # Statusline scripts
    ".claude/statusline-async.sh" = {
      source = ../dotfiles/claude/statusline-async.sh;
      executable = true;
    };
    ".claude/gitlab-status.sh" = {
      source = ../dotfiles/claude/gitlab-status.sh;
      executable = true;
    };
    ".claude/aws-sso-status.sh" = {
      source = ../dotfiles/claude/aws-sso-status.sh;
      executable = true;
    };
    ".claude/k8s-token-status.sh" = {
      source = ../dotfiles/claude/k8s-token-status.sh;
      executable = true;
    };

    # Hooks — whole-directory source. (Skills are wired up per-directory above
    # so work-config skills can coexist with public ones.)
    ".claude/hooks".source = ../dotfiles/claude/hooks;

    # Voice scripts — shared library + individual commands
    ".local/share/voice-lib.sh".source = ../dotfiles/claude/voice-lib.sh;
    ".local/bin/claude-drive" = {
      source = ../dotfiles/claude/claude-drive.sh;
      executable = true;
    };
    ".local/bin/voice-claude" = {
      source = ../dotfiles/claude/voice-claude.sh;
      executable = true;
    };
    ".local/bin/grok-speak" = {
      source = ../dotfiles/claude/grok-speak.sh;
      executable = true;
    };
    ".local/bin/grok-listen" = {
      source = ../dotfiles/claude/grok-listen.sh;
      executable = true;
    };
  };

  home.activation = {
    # Merge Claude settings (hooks, plugins, statusline) into ~/.claude/settings.json
    # Preserves any manual additions (model, env vars) while ensuring hooks and plugins are set
    claudeSettingsSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      SETTINGS="${homeDir}/.claude/settings.json"
      OVERLAY='${claudeSettingsOverlay}'

      mkdir -p "$(dirname "$SETTINGS")"
      if [ ! -f "$SETTINGS" ]; then
        echo "$OVERLAY" | ${pkgs.jq}/bin/jq . > "$SETTINGS"
      else
        ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$SETTINGS" <(echo "$OVERLAY") > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
      fi
    '';

    # Merge MCP servers into ~/.claude.json (user scope — available across all projects)
    claudeMcpSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      CLAUDE_JSON="${homeDir}/.claude.json"
      MCP_OVERLAY='${claudeMcpOverlay}'

      if [ ! -f "$CLAUDE_JSON" ]; then
        echo "$MCP_OVERLAY" | ${pkgs.jq}/bin/jq . > "$CLAUDE_JSON"
      else
        ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$CLAUDE_JSON" <(echo "$MCP_OVERLAY") > "$CLAUDE_JSON.tmp" && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
      fi
    '';

    # Fix plugin hook permissions (plugin sync downloads without +x)
    fixPluginHookPerms = lib.hm.dag.entryAfter [ "claudeSettingsSetup" ] ''
      find "${homeDir}/.claude/plugins" -name "*.sh" -type f ! -perm -u+x -exec chmod +x {} + 2>/dev/null || true
    '';

    # Clone work-specific config if a work monorepo is present at ~/src/sw
    # Derives GitLab host and username from that repo's remote origin
    cloneWorkConfig = lib.hm.dag.entryAfter [ "claudeSettingsSetup" ] ''
      WORK_REPO="$HOME/src/sw"
      if [ -d "$WORK_REPO/.git" ]; then
        WORK_REMOTE=$(${pkgs.git}/bin/git -C "$WORK_REPO" remote get-url origin 2>/dev/null)
        # Extract host and user from git@HOST:USER/REPO or https://HOST/USER/REPO
        GIT_HOST=$(echo "$WORK_REMOTE" | ${pkgs.gnused}/bin/sed -n 's|.*@\([^:]*\):.*|\1|p; s|https\?://\([^/]*\)/.*|\1|p' | head -1)
        GIT_USER=$(echo "$WORK_REMOTE" | ${pkgs.gnused}/bin/sed -n 's|.*[:/]\([^/]*\)/[^/]*$|\1|p' | head -1)

        if [ -n "$GIT_HOST" ] && [ -n "$GIT_USER" ]; then
          WORK_CONFIG="$HOME/.claude/work-config"
          if [ ! -d "$WORK_CONFIG/.git" ]; then
            echo "Cloning Claude work-config from $GIT_HOST..." >&2
            ${pkgs.git}/bin/git clone "git@$GIT_HOST:$GIT_USER/work-config.git" "$WORK_CONFIG" 2>/dev/null || \
              echo "WARNING: Failed to clone work-config repo. Agents and harness scripts will be unavailable." >&2
          fi
          if [ -d "$WORK_CONFIG/agents" ]; then
            ln -sfn "$WORK_CONFIG/agents" "$HOME/.claude/agents"
          else
            echo "WARNING: $WORK_CONFIG/agents not found. Claude agents unavailable." >&2
          fi
          if [ -d "$WORK_CONFIG/scripts" ]; then
            ln -sfn "$WORK_CONFIG/scripts" "$HOME/.claude/scripts"
          else
            echo "WARNING: $WORK_CONFIG/scripts not found. Harness script unavailable." >&2
          fi
          # Symlink each work-config skill + command individually so public-repo
          # home.file entries (e.g. commit-push-open-mr) coexist.
          if [ -d "$WORK_CONFIG/skills" ]; then
            mkdir -p "$HOME/.claude/skills"
            for skill in "$WORK_CONFIG/skills"/*/; do
              [ -d "$skill" ] || continue
              ln -sfn "$skill" "$HOME/.claude/skills/$(basename "$skill")"
            done
          fi
          if [ -d "$WORK_CONFIG/commands" ]; then
            mkdir -p "$HOME/.claude/commands"
            for cmd in "$WORK_CONFIG/commands"/*.md; do
              [ -f "$cmd" ] || continue
              ln -sfn "$cmd" "$HOME/.claude/commands/$(basename "$cmd")"
            done
          fi
        fi
      fi
    '';
  };
}
