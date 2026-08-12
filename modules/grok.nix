{
  config,
  pkgs,
  lib,
  ...
}:

# Grok AWS Agent Toolkit wiring only.
#
# Do NOT put Slack back in here. A previous activation wrote
# mcp_servers.slack into ~/.grok/config.toml, which shadowed Grok's
# managed Space connector and broke OAuth (removed in b46cfa9).

let
  homeDir = config.home.homeDirectory;
  toolkitDir = "${homeDir}/workspace/github.com/aws/agent-toolkit-for-aws";
  proxy = "${homeDir}/.local/bin/aws-mcp-proxy";
  awsConfig = "${homeDir}/src/sw/ops/flakes/aws.config";

  # First profile is the process default (required to SigV4-handshake the
  # AWS MCP endpoint). It is intentionally the least-privilege everyday
  # corp read role — NOT nlk_org-admin. Per-call switching uses the
  # aws_profile tool argument; see ~/.grok/skills/aws-profile.
  awsProfiles = [
    "nlk_corp-readonly"
    "nlk_corp-admin"
    "nlk_corp"
    "nlk_org-admin"
    "network_network-readonly"
    "network_network-admin"
    "neuralink_dev-readonly"
    "neuralink_dev-admin"
    "neuralink_stg-readonly"
    "neuralink_stg-admin"
    "neuralink_prod-readonly"
    "neuralink_prod-admin"
    "infrastructure_dev-readonly"
    "infrastructure_dev-admin"
    "infrastructure_prod-readonly"
    "infrastructure_prod-admin"
    "clinical_dev-readonly"
    "clinical_dev-admin"
    "clinical_prod-readonly"
    "clinical_prod-admin"
    "implant_dev-readonly"
    "implant_dev-admin"
    "implant_prod-readonly"
    "implant_prod-admin"
    "lims_dev-readonly"
    "lims_dev-admin"
    "deploy_deploy-readonly"
    "deploy_deploy-admin"
    "admin_admin-readonly"
    "admin_admin-admin"
    "terraform_state_full_access"
    "BedrockAccess"
  ];

  skillPaths = [
    "${toolkitDir}/skills/core-skills"
    "${toolkitDir}/skills/specialized-skills/networking-and-content-delivery-skills/route53"
    "${toolkitDir}/skills/specialized-skills/networking-and-content-delivery-skills/configuring-vpc-endpoints-for-private-aws-service-access"
    "${toolkitDir}/skills/specialized-skills/networking-and-content-delivery-skills/sitetositevpn"
  ];
in
{
  home = {
    file.".local/bin/aws-mcp-proxy" = {
      source = ../dotfiles/grok/aws-mcp-proxy.sh;
      executable = true;
    };

    file.".grok/skills/aws-profile/SKILL.md" = {
      source = ../dotfiles/grok/skills/aws-profile/SKILL.md;
    };

    activation.grokAwsToolkit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      GROK_CONFIG="${homeDir}/.grok/config.toml"
      TOOLKIT="${toolkitDir}"
      PROXY="${proxy}"
      AWS_CONFIG="${awsConfig}"
      mkdir -p "${homeDir}/.grok" "$(dirname "$TOOLKIT")"

      if [ ! -d "$TOOLKIT/.git" ]; then
        echo "Cloning aws/agent-toolkit-for-aws into $TOOLKIT ..." >&2
        ${pkgs.git}/bin/git clone --depth 1 \
          https://github.com/aws/agent-toolkit-for-aws.git "$TOOLKIT"
      fi

      ${pkgs.python3}/bin/python3 - "$GROK_CONFIG" "$PROXY" "$AWS_CONFIG" "$TOOLKIT" <<'PY'
      import pathlib
      import sys

      path = pathlib.Path(sys.argv[1])
      proxy, aws_config, toolkit = sys.argv[2], sys.argv[3], sys.argv[4]
      profiles = ${builtins.toJSON awsProfiles}
      skill_paths = ${builtins.toJSON skillPaths}

      sections_to_strip = {
          "mcp_servers.aws-mcp",
          "mcp_servers.aws-mcp.env",
          "skills",
      }

      profile_args = ",\n".join(f'  "{p}"' for p in profiles)
      skill_args = ",\n".join(f'  "{p}"' for p in skill_paths)
      section = (
          "[mcp_servers.aws-mcp]\n"
          f'command = "{proxy}"\n'
          "args = [\n"
          '  "mcp-proxy-for-aws@1.6.4",\n'
          '  "https://aws-mcp.us-east-1.api.aws/mcp",\n'
          '  "--profile",\n'
          f"{profile_args},\n"
          '  "--metadata",\n'
          '  "AWS_REGION=us-west-2",\n'
          '  "INSTALL_SOURCE=joe-dotfiles-grok",\n'
          "]\n"
          "enabled = true\n"
          "startup_timeout_sec = 90\n"
          "\n"
          "[mcp_servers.aws-mcp.env]\n"
          f'AWS_CONFIG_FILE = "{aws_config}"\n'
          "\n"
          "[skills]\n"
          f"paths = [\n{skill_args},\n]\n"
      )

      text = path.read_text() if path.exists() else ""
      lines = text.splitlines(keepends=True)
      out = []
      i = 0
      while i < len(lines):
          stripped = lines[i].strip()
          if stripped.startswith("[") and stripped.endswith("]"):
              name = stripped[1:-1]
              if name in sections_to_strip:
                  i += 1
                  while i < len(lines):
                      s = lines[i].strip()
                      if s.startswith("[") and s.endswith("]"):
                          break
                      i += 1
                  continue
          out.append(lines[i])
          i += 1

      body = "".join(out).rstrip() + "\n\n" + section
      if not body.endswith("\n"):
          body += "\n"
      path.write_text(body)
      print(f"Merged AWS MCP + skills into {path}", file=sys.stderr)
      PY
    '';
  };
}
