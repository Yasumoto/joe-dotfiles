#!/usr/bin/env bash
# Launch uvx without nix-shell Python leakage.
#
# Grok (and Claude) inherit direnv/nix PYTHONPATH + PYTHONNOUSERSITE, which
# makes uvx's isolated mcp-proxy-for-aws import nixpkgs typing_extensions
# 4.13 (no Sentinel) and die on handshake.
#
# Grok's MCP child also does not inherit direnv, so Neuralink SSO profiles
# in ops/flakes/aws.config are invisible unless we point boto3 at them.
set -euo pipefail

unset PYTHONPATH PYTHONHOME PYTHONNOUSERSITE

if [ -z "${AWS_CONFIG_FILE:-}" ]; then
  for candidate in \
    "${HOME}/src/sw/ops/flakes/aws.config" \
    "${HOME}/workspace/src/sw/ops/flakes/aws.config"; do
    if [ -f "$candidate" ]; then
      export AWS_CONFIG_FILE="$candidate"
      break
    fi
  done
fi

# credential_process in aws.config shells out to `aws` + `bash`.
# Grok's MCP child may have a stripped PATH (no nix profile).
export PATH="${HOME}/.nix-profile/bin:/pkg/env/global/bin:/usr/bin:/bin:${PATH}"

if [ -x "${HOME}/.local/bin/uvx" ]; then
  UVX="${HOME}/.local/bin/uvx"
elif command -v uvx >/dev/null 2>&1; then
  UVX="$(command -v uvx)"
else
  echo "aws-mcp-proxy: uvx not found (install uv / uvx)" >&2
  exit 127
fi

exec "$UVX" "$@"
