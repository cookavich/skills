#!/bin/bash
# run-oracle.sh - Send a prompt to GPT-5.3-codex via OpenCode and return clean output
#
# Reads prompt from stdin, invokes OpenCode with fixed model/reasoning settings,
# strips ANSI escapes, and prints the result to stdout (or to ORACLE_OUTPUT if set).
#
# Environment variables:
#   OPENCODE_BIN    - Path to opencode binary (default: auto-detect)
#   ORACLE_OUTPUT   - If set, write output to this file path (for background runs)

set -euo pipefail

MODEL="github-copilot/gpt-5.3-codex"
VARIANT="xhigh"

# Locate the OpenCode binary
OPENCODE_BIN="${OPENCODE_BIN:-}"
if [ -z "$OPENCODE_BIN" ]; then
    OPENCODE_BIN="$(command -v opencode 2>/dev/null || true)"
    if [ -z "$OPENCODE_BIN" ] && [ -x "$HOME/.opencode/bin/opencode" ]; then
        OPENCODE_BIN="$HOME/.opencode/bin/opencode"
    fi
fi

if [ -z "$OPENCODE_BIN" ] || [ ! -x "$OPENCODE_BIN" ]; then
    echo "ERROR: opencode not found. Run check-opencode.sh first." >&2
    exit 1
fi

# Read prompt from stdin into a temp file
PROMPT_FILE="$(mktemp -t oracle.prompt.XXXXXX)"
ERR_FILE="$(mktemp -t oracle.err.XXXXXX)"

cleanup() {
    rm -f "$PROMPT_FILE" "$ERR_FILE"
}
trap cleanup EXIT

cat >"$PROMPT_FILE"
if [ ! -s "$PROMPT_FILE" ]; then
    echo "ERROR: empty prompt. Provide instructions via stdin." >&2
    exit 1
fi

PROMPT="$(cat "$PROMPT_FILE")"

# Execute OpenCode
ORACLE_OUTPUT="${ORACLE_OUTPUT:-}"
RC=0

if ! "$OPENCODE_BIN" run \
    -m "$MODEL" \
    --variant "$VARIANT" \
    --format default \
    "$PROMPT" \
    >"$ERR_FILE.out" 2>"$ERR_FILE"; then
    RC=$?
    cat "$ERR_FILE" >&2
fi

# Strip ANSI escape codes (perl is reliable across macOS/Linux)
OUTPUT="$(perl -pe 's/\e\[[0-9;]*m//g' <"$ERR_FILE.out")"

# Write output
if [ -n "$ORACLE_OUTPUT" ]; then
    echo "$OUTPUT" >"$ORACLE_OUTPUT"
else
    echo "$OUTPUT"
fi

rm -f "$ERR_FILE.out"

exit $RC
