#!/bin/bash
# check-opencode.sh - Validate OpenCode CLI availability
#
# Exit codes:
#   0 - OpenCode CLI is ready (installed and responding)
#   1 - OpenCode CLI is not installed
#   2 - OpenCode CLI is not responding (timeout)
#
# Options:
#   -v, --verbose   Show detailed status
#   -q, --quiet     Suppress output on success
#   -h, --help      Show this help message

set -euo pipefail

# Bash 3.2-compatible timeout shim for macOS (no GNU coreutils)
if ! command -v timeout &>/dev/null; then
    timeout() {
        local secs=$1; shift
        "$@" &
        local pid=$!
        ( sleep "$secs" && kill "$pid" 2>/dev/null ) &
        local watchdog=$!
        wait "$pid" 2>/dev/null
        local rc=$?
        kill "$watchdog" 2>/dev/null
        wait "$watchdog" 2>/dev/null 2>&1
        return $rc
    }
fi

VERBOSE=0
QUIET=0
TIMEOUT_SECS=5

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Validate OpenCode CLI availability.

Options:
  -v, --verbose   Show detailed status information
  -q, --quiet     Suppress output on success (exit code only)
  -h, --help      Show this help message

Exit codes:
  0  OpenCode CLI is ready
  1  OpenCode CLI is not installed
  2  OpenCode CLI is not responding
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -v|--verbose) VERBOSE=1; shift ;;
        -q|--quiet) QUIET=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done

log() {
    if [ $QUIET -eq 0 ]; then echo "$@"; fi
}

log_verbose() {
    if [ $VERBOSE -eq 1 ]; then echo "$@"; fi
}

log_error() {
    echo "$@" >&2
}

# Locate the OpenCode binary
OPENCODE_BIN="${OPENCODE_BIN:-}"
if [ -z "$OPENCODE_BIN" ]; then
    OPENCODE_BIN="$(command -v opencode 2>/dev/null || true)"
    if [ -z "$OPENCODE_BIN" ] && [ -x "$HOME/.opencode/bin/opencode" ]; then
        OPENCODE_BIN="$HOME/.opencode/bin/opencode"
    fi
fi

# Check 1: Is OpenCode installed?
if [ -z "$OPENCODE_BIN" ] || [ ! -x "$OPENCODE_BIN" ]; then
    log_error "ERROR: OpenCode CLI is not installed or not in PATH."
    log_error ""
    log_error "Install OpenCode:"
    log_error "  curl -fsSL https://opencode.ai/install | bash"
    log_error ""
    log_error "Or set OPENCODE_BIN to the path of the opencode binary."
    log_error ""
    log_error "Documentation: https://github.com/opencode-ai/opencode"
    exit 1
fi

log_verbose "Found: $OPENCODE_BIN"

# Check 2: Is OpenCode responding?
if ! version=$(timeout "$TIMEOUT_SECS" "$OPENCODE_BIN" --version 2>/dev/null); then
    log_error "ERROR: OpenCode CLI is installed but not responding (timeout after ${TIMEOUT_SECS}s)."
    log_error "Try running 'opencode --version' manually to diagnose."
    exit 2
fi

log_verbose "Version: $version"

# Success
if [ $VERBOSE -eq 1 ]; then
    log "opencode ready ($version)"
elif [ $QUIET -eq 0 ]; then
    log "opencode ready"
fi

exit 0
