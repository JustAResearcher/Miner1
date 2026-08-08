#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=h-manifest.conf
source "$SCRIPT_PATH/h-manifest.conf"

if [[ ! -r $CUSTOM_CONFIG_FILENAME ]]; then
    printf 'bc3miner-hiveos: missing config %s; re-apply the flight sheet\n' \
        "$CUSTOM_CONFIG_FILENAME" >&2
    exit 1
fi
# shellcheck disable=SC1090
source "$CUSTOM_CONFIG_FILENAME"
if ! declare -p BC3_ARGS 2>/dev/null | grep -q '^declare -a '; then
    printf 'bc3miner-hiveos: config does not define a BC3_ARGS array\n' >&2
    exit 1
fi
if [[ ! -x $SCRIPT_PATH/bc3miner ]]; then
    printf 'bc3miner-hiveos: launcher is missing or not executable\n' >&2
    exit 127
fi

mkdir -p "$(dirname "$CUSTOM_LOG_BASENAME")" "$CUSTOM_RATE_DIR" /run/hive
: > /run/hive/MINER_RUN
printf '%s\n' '{"status":"running"}' > /run/hive/miner_status.1

log_file="${CUSTOM_LOG_BASENAME}.log"
export BC3MINER_RATE_DIR=$CUSTOM_RATE_DIR

# HiveOS already owns the screen session. Stay in the foreground, mirror output
# to its log, then replace h-run.sh so Hive's duplicate-process guard is clear.
exec > >(exec tee -a "$log_file") 2>&1
printf 'bc3miner-hiveos %s starting\n' "$CUSTOM_VERSION"
exec "$SCRIPT_PATH/bc3miner" "${BC3_ARGS[@]}"
