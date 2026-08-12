---
name: aws-profile
description: >-
  Always pass aws_profile on every AWS MCP tool call. Joe jumps AWS accounts
  constantly; the process default is nlk_corp-readonly and is usually the wrong
  account. Use when calling aws-mcp, call_aws, run_script, Cost Explorer,
  Route 53, VPC endpoints, or any AWS API.
user-invocable: false
---

# Force an AWS profile on every call

Neuralink SSO lives in `ops/flakes/aws.config`. The AWS MCP proxy starts as
`nlk_corp-readonly` only so SigV4 handshake can succeed. That default is the
wrong account for most work.

## Rules

1. On every `aws-mcp` / `call_aws` / `run_script` / `get_presigned_url` /
   `get_tasks` call, set `aws_profile` to a value from the tool's enum.
2. Never omit `aws_profile`. Never rely on `AWS_PROFILE` or the process default.
3. Never use `nlk_org-admin` unless the task is org-wide billing, Cost Explorer,
   Organizations, or the user named the payer account (`332100604756`).
4. If the target account is not obvious from the user's request, ask. Do not
   guess a `*-admin` or prod profile.

## Profile map

| Work | Profile |
| --- | --- |
| `env-corp/**`, `env-global/**`, corp VPC, hybrid DNS, IPsec/TGW | `nlk_corp-readonly` or `nlk_corp-admin` |
| Substrate network VPCs, VPC endpoints, peering | `network_network-readonly` or `network_network-admin` |
| `root-modules/<domain>/<env>` | `{domain}_{env}-readonly` or `{domain}_{env}-admin` |
| Org billing / Cost Explorer / COH | `nlk_org-admin` |
| Terraform state bucket/lock in corp | `terraform_state_full_access` |
| Bedrock in corp | `BedrockAccess` |

Prefer `*-readonly` unless the user asked to change something.
