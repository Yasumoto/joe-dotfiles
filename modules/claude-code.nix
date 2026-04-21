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
  hookCmd = sound: "sh ${hooksDir}/play-sound.sh ${soundsDir}/${sound}";

  # Declarative plugin list — add/remove here
  enabledPlugins = {
    "pyright-lsp@claude-plugins-official" = true;
    "typescript-lsp@claude-plugins-official" = true;
    "gopls-lsp@claude-plugins-official" = true;
    "ralph-loop@claude-plugins-official" = true;
    "hookify@claude-plugins-official" = true;
    "commit-commands@claude-plugins-official" = true;
  };

  kubectlReadVerbs = [
    "get"
    "describe"
    "logs"
    "top"
    "config"
  ];
  kubectlPerms =
    (map (v: "Bash(kubectl ${v} *)") kubectlReadVerbs)
    ++ (lib.concatMap (flag: map (v: "Bash(kubectl ${flag} *${v} *)") kubectlReadVerbs) [
      "--context"
      "-n"
    ]);

  # Read-only permissions that apply globally across all checkouts and worktrees
  # No hardcoded repo paths — portable across macOS and Linux
  globalPermissions = {
    allow = [
      "Read(**)"
      "Glob(**)"
      "Grep(**)"
      "Bash(git *)"
      "Bash(glab api *)"
      "Bash(glab mr list *)"
      "Bash(glab mr view *)"
      "Bash(glab ci view *)"
      "Bash(glab ci trace *)"
      "Bash(glab ci list *)"
      "Bash(glab ci status *)"
      "Bash(glab issue list *)"
      "Bash(glab issue view *)"
    ]
    ++ kubectlPerms
    ++ [
      "Bash(jq *)"
      "Bash(python3:*)"
      "Bash(find:*)"
      "Bash(ls *)"
      "Bash(ls:*)"
      "Bash(wc *)"
      "Bash(head *)"
      "Bash(tail *)"
      "Bash(cat *)"
      "Bash(stat *)"
      "Bash(md5sum *)"
      "Bash(sha256sum *)"
      "Bash(bazel query *)"
      "Bash(bazel info *)"
      "Bash(bazel build *)"
      "Bash(bazel test *)"
    ];
    deny = [
      "Bash(terraform*)"
    ];
  };

  # Generate the settings.json content that gets merged at activation
  # MCP servers go in ~/.claude.json (user scope), not settings.json
  claudeMcpOverlay = builtins.toJSON {
    mcpServers = {
      xai-docs = {
        type = "http";
        url = "https://docs.x.ai/api/mcp";
      };
    };
  };

  claudeSettingsOverlay = builtins.toJSON {
    statusLine = {
      type = "command";
      command = "${homeDir}/.claude/statusline-async.sh";
    };
    hooks = {
      SessionStart = [
        {
          hooks = [
            {
              type = "command";
              command = hookCmd "PeonReady1.ogg";
            }
          ];
        }
      ];
      UserPromptSubmit = [
        {
          hooks = [
            {
              type = "command";
              command = hookCmd "PeonYes3.ogg";
            }
          ];
        }
      ];
      Notification = [
        {
          hooks = [
            {
              type = "command";
              command = hookCmd "PeonWhat3.ogg";
            }
          ];
        }
      ];
      Stop = [
        {
          hooks = [
            {
              type = "command";
              command = hookCmd "PeonBuildingComplete1.ogg";
            }
          ];
        }
      ];
      PostCompact = [
        {
          hooks = [
            {
              type = "command";
              command = "cat ${homeDir}/.claude/projects/*/memory/MEMORY.md 2>/dev/null || true";
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
in
{
  home.file = {
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

    # Sound hooks
    ".claude/hooks/play-sound.sh".source = ../dotfiles/claude/hooks/play-sound.sh;
    ".claude/hooks/sounds/PeonReady1.ogg".source = ../dotfiles/claude/hooks/sounds/PeonReady1.ogg;
    ".claude/hooks/sounds/PeonYes3.ogg".source = ../dotfiles/claude/hooks/sounds/PeonYes3.ogg;
    ".claude/hooks/sounds/PeonWhat3.ogg".source = ../dotfiles/claude/hooks/sounds/PeonWhat3.ogg;
    ".claude/hooks/sounds/PeonBuildingComplete1.ogg".source =
      ../dotfiles/claude/hooks/sounds/PeonBuildingComplete1.ogg;

    # Skills
    ".claude/skills/commit-push-open-mr/SKILL.md".source =
      ../dotfiles/claude/skills/commit-push-open-mr/SKILL.md;

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
    ".local/bin/claude-speak" = {
      source = ../dotfiles/claude/claude-speak.sh;
      executable = true;
    };
    ".local/bin/claude-listen" = {
      source = ../dotfiles/claude/claude-listen.sh;
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
            ${pkgs.git}/bin/git clone "git@$GIT_HOST:$GIT_USER/claude-work-config.git" "$WORK_CONFIG" 2>/dev/null || \
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
        fi
      fi
    '';
  };
}
