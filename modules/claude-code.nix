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
    # Official Slack MCP + skills — OAuth via Anthropic's registered Slack app
    # (https://docs.slack.dev/ai/slack-mcp-server/connect-to-claude)
    "slack@claude-plugins-official" = true;
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

    # Clone work-specific config if a work monorepo is present at ~/src/sw.
    #
    # work-config lives in my PERSONAL namespace on the work forge, NOT the
    # monorepo's org namespace. The user used to be derived from ~/src/sw's
    # origin, but that yields the ORG (".../<org>/<repo>" -> "<org>"), so the
    # clone URL pointed at a repo that does not exist and always failed. A
    # personal namespace is not recoverable from the monorepo URL, so the user
    # is set explicitly below.
    #
    # The HOST is still derived from ~/src/sw's remote and never hardcoded --
    # this repo is public, so no internal hostname belongs in it.
    #
    # ~/src/sw is still the trigger (only wire up work config on work machines),
    # but it no longer gates the symlinking: an existing checkout must get
    # linked even if the clone is skipped or fails.
    cloneWorkConfig = lib.hm.dag.entryAfter [ "claudeSettingsSetup" ] ''
      WORK_REPO="$HOME/src/sw"
      WORK_CONFIG="$HOME/.claude/work-config"
      WORK_CONFIG_USER="joe.smith"

      if [ ! -d "$WORK_REPO/.git" ]; then
        echo "NOTE: $WORK_REPO not found — skipping Claude work-config (not a work machine?)." >&2
      else
        WORK_REMOTE=$(${pkgs.git}/bin/git -C "$WORK_REPO" remote get-url origin 2>/dev/null)
        # Host only, from git@HOST:ORG/REPO or https://HOST/ORG/REPO
        GIT_HOST=$(echo "$WORK_REMOTE" | ${pkgs.gnused}/bin/sed -n 's|.*@\([^:]*\):.*|\1|p; s|https\?://\([^/]*\)/.*|\1|p' | head -1)

        if [ -z "$GIT_HOST" ]; then
          echo "WARNING: could not derive a GitLab host from $WORK_REPO origin ($WORK_REMOTE)." >&2
        elif [ ! -d "$WORK_CONFIG/.git" ]; then
          # home-manager activation rewrites PATH to a minimal nix-store set that
          # does NOT include system ssh (/usr/bin/ssh) or openssh from
          # home.packages. git then fails with:
          #   error: cannot run ssh: No such file or directory
          # Point GIT_SSH_COMMAND at pkgs.openssh so the clone can actually run.
          #
          # Also discover a user SSH agent if the invoking shell didn't export
          # one. The private key is passphrase-protected, so without an unlocked
          # agent (gcr-ssh-agent / ssh-agent) auth fails even with ssh on PATH.
          if [ -z "''${SSH_AUTH_SOCK:-}" ] || [ ! -S "$SSH_AUTH_SOCK" ]; then
            runtimeDir="''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}"
            for sock in \
              "$runtimeDir/gcr/ssh" \
              "$runtimeDir/gcr/.ssh" \
              "$runtimeDir/ssh-agent" \
              "$runtimeDir/ssh-agent.socket"; do
              if [ -S "$sock" ]; then
                export SSH_AUTH_SOCK="$sock"
                break
              fi
            done
          fi

          # Do NOT swallow git's stderr: "repo not found" vs "permission denied
          # (publickey)" vs "cannot run ssh" are different problems and the
          # message is the only clue. BatchMode avoids a hung askpass prompt
          # during non-interactive activation.
          echo "Cloning Claude work-config from git@$GIT_HOST:$WORK_CONFIG_USER/work-config.git ..." >&2
          if ! GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -o BatchMode=yes" \
            ${pkgs.git}/bin/git clone "git@$GIT_HOST:$WORK_CONFIG_USER/work-config.git" "$WORK_CONFIG"; then
            echo "WARNING: work-config clone failed (see git error above). Agents, harness scripts, and work skills will be unavailable." >&2
            echo "         If it says 'Permission denied (publickey)', unlock your SSH key (ssh-add) or check https://$GIT_HOST/-/user_settings/ssh_keys" >&2
            echo "         If it says 'cannot run ssh', PATH during activation is missing openssh — this module should set GIT_SSH_COMMAND." >&2
          fi
        fi

        # Link whatever is present, regardless of whether we just cloned it.
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
    '';
  };
}
