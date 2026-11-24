{
  config,
  pkgs,
  lib,
  isWork,
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
    # Official Slack MCP + skills — OAuth via Anthropic's registered Slack app
    # (https://docs.slack.dev/ai/slack-mcp-server/connect-to-claude)
    "slack@claude-plugins-official" = true;
    # AWS Agent Toolkit — core skills (billing/cost, IAM, CDK, …).
    # The plugin also ships an AWS MCP sidecar; that is disabled below.
    # One-time install if missing: /plugin marketplace update claude-plugins-official
    # then /plugin install aws-core@claude-plugins-official
    # https://github.com/aws/agent-toolkit-for-aws
    "aws-core@claude-plugins-official" = true;
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
    "glab api --method GET"
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
    ];
  };

  # MCP servers merged into ~/.claude.json (user scope).
  # Slack uses Anthropic's pre-registered OAuth client (no DCR) — same as the
  # official slack plugin. First use prompts a browser OAuth consent.
  claudeMcpOverlay = builtins.toJSON {
    mcpServers = {
      xai-docs = {
        type = "http";
        url = "https://docs.x.ai/api/mcp";
      };
      agent-voice = {
        command = "${homeDir}/.cargo/bin/agent-voice-mcp";
      };
      slack = {
        type = "http";
        url = "https://mcp.slack.com/mcp";
        oauth = {
          clientId = "1601185624273.8899143856786";
          callbackPort = 3118;
        };
      };
    }
    # Macs only (work and personal; not Linux). --autoConnect attaches to the
    # running Chrome; enable it once at chrome://inspect/#remote-debugging.
    // lib.optionalAttrs pkgs.stdenv.isDarwin {
      chrome-devtools = {
        command = "${pkgs.nodejs}/bin/npx";
        args = [
          "-y"
          "chrome-devtools-mcp@latest"
          "--autoConnect"
        ];
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
    # Keep aws-core skills; do not start the plugin's unsigned AWS MCP sidecar.
    # Claude's /mcp disable is per-project (see claudeMcpSetup); this covers
    # settings.json if/when Claude honors it at user scope.
    disabledMcpServers = [ "plugin:aws-core:aws-mcp" ];
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

      # aws-core ships skills + an AWS MCP sidecar. Keep the skills; disable
      # only the sidecar. Claude's /mcp disable writes disabledMcpServers on
      # the *current project* entry, so walk every project (and the top-level
      # key) so a new cwd does not start the unsigned proxy.
      ${pkgs.jq}/bin/jq --arg name "plugin:aws-core:aws-mcp" '
        def union($x): ((. // []) + [$x] | unique);
        .disabledMcpServers |= union($name)
        | if (.projects | type) == "object" then
            .projects |= with_entries(
              .value.disabledMcpServers |= union($name)
            )
          else . end
      ' "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp" && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"

      # Plugin updates restore .mcp.json. Empty the sidecar so Claude/Grok
      # do not even discover aws-mcp; skills still load from skills/.
      ${pkgs.findutils}/bin/find "${homeDir}/.claude/plugins/cache/claude-plugins-official/aws-core" \
        -name .mcp.json -type f -print0 2>/dev/null \
        | while IFS= read -r -d "" mcp; do
            echo '{"mcpServers":{}}' | ${pkgs.jq}/bin/jq . > "$mcp"
          done || true
    '';

    # Fix plugin hook permissions (plugin sync downloads without +x)
    fixPluginHookPerms = lib.hm.dag.entryAfter [ "claudeSettingsSetup" ] ''
      find "${homeDir}/.claude/plugins" -name "*.sh" -type f ! -perm -u+x -exec chmod +x {} + 2>/dev/null || true
    '';

    # isWork configs only: link ~/.claude/work-config's agents, scripts, skills
    # and commands into ~/.claude. work-config lives in my PERSONAL namespace on
    # the work forge; `nix run <this flake>#clone-work-repos` clones it.
    claudeWorkConfigLinks = lib.mkIf isWork (
      lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        WORK_CONFIG="$HOME/.claude/work-config"
        if [ ! -d "$WORK_CONFIG/.git" ]; then
          echo "WARNING: $WORK_CONFIG not found. Clone it with: nix run ~/workspace/github.com/Yasumoto/joe-dotfiles#clone-work-repos, then switch again." >&2
        fi

        # Link whatever is present.
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
        # home.file entries (e.g. commit-push-open-mr) coexist. First drop
        # links into work-config whose target is gone (a renamed or deleted
        # skill), so Claude and Grok don't list a skill that can't load.
        for link in "$HOME/.claude/skills"/* "$HOME/.claude/commands"/*; do
          [ -L "$link" ] && [ ! -e "$link" ] || continue
          case "$(readlink "$link")" in
            "$WORK_CONFIG"/*) rm -f "$link" ;;
          esac
        done
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
      ''
    );
  };
}
