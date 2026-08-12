{
  config,
  pkgs,
  lib,
  ...
}:

# Grok AWS Agent Toolkit skills only.
#
# Do NOT put Slack back in here. A previous activation wrote
# mcp_servers.slack into ~/.grok/config.toml, which shadowed Grok's
# managed Space connector and broke OAuth (removed in b46cfa9).
#
# AWS MCP (mcp-proxy-for-aws) was tried and removed: the tools/list
# catalog is ~28KB of description text, over Grok's 20KB ingest cap,
# and the aws CLI + Neuralink SSO already does the real work.

let
  homeDir = config.home.homeDirectory;
  toolkitDir = "${homeDir}/workspace/github.com/aws/agent-toolkit-for-aws";

  skillPaths = [
    "${toolkitDir}/skills/core-skills"
    "${toolkitDir}/skills/specialized-skills/networking-and-content-delivery-skills/route53"
    "${toolkitDir}/skills/specialized-skills/networking-and-content-delivery-skills/configuring-vpc-endpoints-for-private-aws-service-access"
    "${toolkitDir}/skills/specialized-skills/networking-and-content-delivery-skills/sitetositevpn"
  ];
in
{
  home.activation.grokAwsToolkit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    GROK_CONFIG="${homeDir}/.grok/config.toml"
    TOOLKIT="${toolkitDir}"
    mkdir -p "${homeDir}/.grok" "$(dirname "$TOOLKIT")"

    if [ ! -d "$TOOLKIT/.git" ]; then
      echo "Cloning aws/agent-toolkit-for-aws into $TOOLKIT ..." >&2
      ${pkgs.git}/bin/git clone --depth 1 \
        https://github.com/aws/agent-toolkit-for-aws.git "$TOOLKIT"
    fi

    ${pkgs.python3}/bin/python3 - "$GROK_CONFIG" "$TOOLKIT" <<'PY'
    import pathlib
    import re
    import sys

    path = pathlib.Path(sys.argv[1])
    skill_paths = ${builtins.toJSON skillPaths}

    # Also strip leftover AWS MCP blocks from the earlier experiment.
    sections_to_strip = {
        "mcp_servers.aws-mcp",
        "mcp_servers.aws-mcp.env",
        "skills",
    }

    text = path.read_text() if path.exists() else ""
    lines = text.splitlines(keepends=True)
    out = []
    disabled = []
    i = 0
    while i < len(lines):
        stripped = lines[i].strip()
        if stripped.startswith("disabled_mcp_servers"):
            block = lines[i]
            if "[" in block and "]" not in block:
                i += 1
                while i < len(lines):
                    block += lines[i]
                    if "]" in lines[i]:
                        break
                    i += 1
            disabled.extend(re.findall(r'"([^"]+)"', block))
            i += 1
            continue
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

    # Claude's aws-core plugin still ships .mcp.json; Grok discovers that
    # sidecar. Keep it on the disable list so a new session does not spawn it.
    names = list(dict.fromkeys([*disabled, "aws-mcp"]))
    disabled_line = (
        "disabled_mcp_servers = ["
        + ", ".join(f'"{n}"' for n in names)
        + "]\n"
    )
    skill_args = ",\n".join(f'  "{p}"' for p in skill_paths)
    section = f"[skills]\npaths = [\n{skill_args},\n]\n"

    body = disabled_line + "\n" + "".join(out).lstrip()
    body = body.rstrip() + "\n\n" + section
    if not body.endswith("\n"):
        body += "\n"
    path.write_text(body)
    print(f"Merged AWS skills into {path}", file=sys.stderr)
    PY
  '';
}
