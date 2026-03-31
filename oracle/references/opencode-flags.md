# OpenCode `run` Command Reference

## All Flags

| Flag | Short | Type | Description |
|------|-------|------|-------------|
| `--model` | `-m` | string | Model in `provider/model` format |
| `--variant` | | string | Reasoning effort (provider-specific: `low`, `medium`, `high`, `max`, `xhigh`) |
| `--format` | | string | Output format: `default` (formatted) or `json` (raw JSON events) |
| `--file` | `-f` | array | Attach file(s) to the message |
| `--dir` | | string | Directory to run in |
| `--title` | | string | Session title |
| `--agent` | | string | Agent to use |
| `--continue` | `-c` | boolean | Continue the last session |
| `--session` | `-s` | string | Session ID to continue |
| `--fork` | | boolean | Fork session before continuing (requires `--continue` or `--session`) |
| `--share` | | boolean | Share the session |
| `--thinking` | | boolean | Show thinking blocks |
| `--attach` | | string | Attach to a running opencode server |
| `--port` | | number | Port for the local server |
| `--pure` | | boolean | Run without external plugins |
| `--log-level` | | string | Log level: `DEBUG`, `INFO`, `WARN`, `ERROR` |

## Oracle Defaults

These are hardcoded in `run-oracle.sh` and not overridable:

| Setting | Value | Rationale |
|---------|-------|-----------|
| Model | `github-copilot/gpt-5.3-codex` | Latest GPT codex model via GitHub Copilot |
| Variant | `xhigh` | Maximum reasoning depth for oracle-quality analysis |
| Format | `default` | Human-readable formatted output |

## Optional Flags

These can be added to `run-oracle.sh` if needed in the future:

| Flag | Use Case |
|------|----------|
| `-f` / `--file` | Attach large files directly instead of inlining in the prompt |
| `--dir` | Set working directory for project-aware analysis |
| `--thinking` | Surface the model's chain-of-thought for transparency |

## Timeout

The Bash tool timeout should always be **600000ms** (10 minutes) for xhigh reasoning.

For tasks that may exceed 10 minutes, use `run_in_background: true` on the Bash tool call and set `ORACLE_OUTPUT` so `run-oracle.sh` writes to a known file you can read later.
