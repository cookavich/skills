---
argument-hint: <query>
name: oracle
user-invocable: true
description: >-
  Second-opinion tool. Consults GPT-5.3-codex via OpenCode for planning,
  debugging, code review, or analysis. Use when the user asks for a
  "second opinion", "ask the oracle", "consult the oracle", "what does
  GPT think", or wants an independent perspective from a different model.
  Read-only — provides analysis only, never implements changes.
---

# Oracle

Use GPT-5.3-codex via OpenCode as a **read-only oracle** — a second opinion for planning, review, debugging, and analysis. The oracle provides its perspective; you synthesize and present results to the user.

**The oracle never implements changes.** It analyzes and recommends only.

## Arguments

Parse `$ARGUMENTS` for:

- **query** — the question or task for the oracle. **Required** — if empty, tell the user to provide a query and stop.

## Prerequisites

Run the check script before any oracle invocation:

```bash
bash oracle/scripts/check-opencode.sh -q
```

If it exits non-zero, display the error to the user and stop.

## Configuration

| Setting | Value | Notes |
|---------|-------|-------|
| Model | `gpt-5.3-codex` | Via GitHub Copilot provider |
| Reasoning | `xhigh` | Always maximum depth |
| Timeout | 600000ms | 10 minutes max |

See `references/opencode-flags.md` for full flag documentation.

## Workflow

### 1. Parse and Validate

1. Parse `$ARGUMENTS` for the query
2. Run `oracle/scripts/check-opencode.sh -q` — abort on failure

### 2. Construct Prompt

Build a focused prompt from the user's query and any relevant context (diffs, file contents, error messages, prior conversation). Keep it direct — state what you want the oracle to analyze and what kind of output you need.

**Rules for prompt construction:**
- Include relevant code or diffs inline when the oracle needs to see them
- State clearly that this is an analysis/review task — no implementation
- Ask for specific, actionable insights
- Request file paths and line references where applicable

### 3. Execute

Invoke via the wrapper script with a HEREDOC. Always set the Bash tool timeout to **600000ms**.

```bash
oracle/scripts/run-oracle.sh <<'EOF'
[constructed prompt]
EOF
```

For tasks that may exceed 10 minutes, use `run_in_background: true` on the Bash tool call:

```bash
ORACLE_OUTPUT="/tmp/oracle-${RANDOM}${RANDOM}.txt" \
oracle/scripts/run-oracle.sh <<'EOF'
[constructed prompt]
EOF
```

Then read `ORACLE_OUTPUT` when the background task completes.

### 4. Present Results

Read the output and present with attribution:

```
## Oracle Analysis

[Oracle output — summarize if >200 lines, preserve key details]

---
*Model: gpt-5.3-codex | Reasoning: xhigh*
```

Synthesize key insights and actionable items for the user. Highlight areas where the oracle's perspective differs from your own analysis.

**Important:** Do not implement changes suggested by the oracle. Present the analysis to the user and let them decide how to proceed. If the user then asks you to act on the oracle's recommendations, proceed normally.
