{
  config,
  pkgs,
  lib,
  ...
}:

let
  homeDir = config.home.homeDirectory;
in
{
  # Slack hosted MCP for Grok.
  #
  # Fixed callback ports only work via the *nested* oauth block — flat
  # oauth_client_id does not stick (confirmed by Grok Build team, 2026-07).
  # That yields redirect http://127.0.0.1:3118/callback.
  #
  # Cursor partner CLIENT_ID + CLI callback port 8787:
  # https://docs.slack.dev/ai/slack-mcp-server/connect-to-cursor
  # Nested oauth only (flat oauth_client_id ignores callbackPort).
  # Grok emits http://127.0.0.1:<callbackPort>/callback — Cursor CLI uses
  # http://localhost:8787/callback, so host may still mismatch.
  #
  # URL without /mcp: Slack PRM resource is https://mcp.slack.com; Grok's
  # resource-equality check fails on …/mcp and never installs AuthClient.
  home.activation.grokMcpSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    GROK_CONFIG="${homeDir}/.grok/config.toml"
    mkdir -p "${homeDir}/.grok"

    ${pkgs.python3}/bin/python3 - "$GROK_CONFIG" <<'PY'
    import pathlib
    import sys

    path = pathlib.Path(sys.argv[1])
    sections_to_strip = {"mcp_servers.slack", "mcp_servers.slack.oauth"}
    section = (
        "[mcp_servers.slack]\n"
        'url = "https://mcp.slack.com"\n'
        "enabled = true\n"
        "\n"
        "[mcp_servers.slack.oauth]\n"
        'clientId = "3660753192626.8903469228982"\n'
        "callbackPort = 8787\n"
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
    print(f"Merged Slack MCP into {path}", file=sys.stderr)
    PY
  '';
}
