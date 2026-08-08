#!/usr/bin/env bash
# HiveOS sources this file after loading the rig and flight-sheet variables.
# Do not enable set -e or set -u in the caller's shell.

bc3_config_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=h-manifest.conf
source "$bc3_config_dir/h-manifest.conf"

bc3_config_fail() {
    printf 'bc3miner-hiveos config: %s\n' "$*" >&2
    return 1
}

bc3_config_trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

if [[ -z ${CUSTOM_TEMPLATE:-} ]]; then
    bc3_config_fail 'wallet and worker template is empty'
    return 1 2>/dev/null || exit 1
fi
if [[ -z ${CUSTOM_URL:-} ]]; then
    bc3_config_fail 'pool URL is empty'
    return 1 2>/dev/null || exit 1
fi

bc3_algo=$(printf '%s' "${CUSTOM_ALGO:-}" | tr '[:upper:]' '[:lower:]')
case "$bc3_algo" in
    ''|bc3|sha256t|sha3-256t) ;;
    *)
        bc3_config_fail "unsupported algorithm '$CUSTOM_ALGO'; expected BC3/SHA3-256T"
        return 1 2>/dev/null || exit 1
        ;;
esac

bc3_worker=${WORKER_NAME:-${RIG_NAME:-}}
if [[ -z $bc3_worker ]]; then
    bc3_worker=$(hostname -s 2>/dev/null || hostname 2>/dev/null || true)
fi
bc3_wallet=${WAL:-${EWAL:-${WALLET:-${WALLET_ADDRESS:-}}}}
bc3_user=$CUSTOM_TEMPLATE

if [[ -n $bc3_wallet ]]; then
    bc3_user=${bc3_user//%WAL%/$bc3_wallet}
fi
if [[ -n ${EWAL:-} ]]; then
    bc3_user=${bc3_user//%EWAL%/$EWAL}
fi
if [[ -n ${DWAL:-} ]]; then
    bc3_user=${bc3_user//%DWAL%/$DWAL}
fi
if [[ -n ${ZWAL:-} ]]; then
    bc3_user=${bc3_user//%ZWAL%/$ZWAL}
fi
if [[ -n $bc3_worker ]]; then
    bc3_user=${bc3_user//%WORKER_NAME%/$bc3_worker}
    bc3_user=${bc3_user//%WORKER%/$bc3_worker}
    bc3_user=${bc3_user//%RIG_NAME%/$bc3_worker}
fi

if [[ $bc3_user == *%* ]]; then
    bc3_config_fail "wallet template contains an unresolved Hive macro: $bc3_user"
    return 1 2>/dev/null || exit 1
fi
if [[ -z $bc3_user || $bc3_user =~ [[:space:]] ]]; then
    bc3_config_fail 'resolved wallet/worker value is empty or contains whitespace'
    return 1 2>/dev/null || exit 1
fi

bc3_pool_text=$CUSTOM_URL
declare -a bc3_pools=()
while IFS= read -r bc3_pool_item || [[ -n $bc3_pool_item ]]; do
    bc3_pool_item=$(bc3_config_trim "$bc3_pool_item")
    [[ -n $bc3_pool_item ]] && bc3_pools+=("$bc3_pool_item")
done < <(printf '%s' "$bc3_pool_text" | tr ',;[:space:]' '\n')

if [[ ${#bc3_pools[@]} -ne 1 ]]; then
    bc3_config_fail "exactly one pool is supported; found ${#bc3_pools[@]}"
    return 1 2>/dev/null || exit 1
fi

bc3_pool=${bc3_pools[0]}
case "$bc3_pool" in
    stratum+tcp://*) ;;
    stratum://*) bc3_pool="stratum+tcp://${bc3_pool#stratum://}" ;;
    tcp://*) bc3_pool="stratum+tcp://${bc3_pool#tcp://}" ;;
    *://*)
        bc3_config_fail "unsupported pool scheme in '$bc3_pool'; only plain TCP is supported"
        return 1 2>/dev/null || exit 1
        ;;
    *) bc3_pool="stratum+tcp://$bc3_pool" ;;
esac

bc3_endpoint=${bc3_pool#stratum+tcp://}
if [[ ! $bc3_endpoint =~ ^([A-Za-z0-9._-]+):([0-9]{1,5})$ ]]; then
    bc3_config_fail "invalid pool endpoint '$bc3_pool'; expected HOST:PORT"
    return 1 2>/dev/null || exit 1
fi
bc3_port=${BASH_REMATCH[2]}
if (( 10#$bc3_port < 1 || 10#$bc3_port > 65535 )); then
    bc3_config_fail "invalid pool port '$bc3_port'"
    return 1 2>/dev/null || exit 1
fi

bc3_pass=${CUSTOM_PASS:-x}
if [[ $bc3_pass =~ [[:space:]] ]]; then
    bc3_config_fail 'pool password contains whitespace'
    return 1 2>/dev/null || exit 1
fi

declare -a bc3_raw_extra=() bc3_extra=()
if [[ -n ${CUSTOM_USER_CONFIG:-} ]]; then
    while IFS= read -r bc3_extra_line || [[ -n $bc3_extra_line ]]; do
        bc3_extra_line=${bc3_extra_line%%#*}
        bc3_extra_line=$(bc3_config_trim "$bc3_extra_line")
        [[ -z $bc3_extra_line ]] && continue
        read -r -a bc3_extra_tokens <<< "$bc3_extra_line"
        bc3_raw_extra+=("${bc3_extra_tokens[@]}")
    done < <(printf '%s' "$CUSTOM_USER_CONFIG" | tr ';' '\n')
fi

bc3_i=0
while (( bc3_i < ${#bc3_raw_extra[@]} )); do
    bc3_token=${bc3_raw_extra[$bc3_i]}
    case "$bc3_token" in
        --batch)
            ((bc3_i += 1))
            if (( bc3_i >= ${#bc3_raw_extra[@]} )) ||
                [[ ! ${bc3_raw_extra[$bc3_i]} =~ ^[0-9]+$ ]]; then
                bc3_config_fail '--batch requires an integer value'
                return 1 2>/dev/null || exit 1
            fi
            bc3_value=${bc3_raw_extra[$bc3_i]}
            if (( 10#$bc3_value < 1 || 10#$bc3_value > 536870912 )); then
                bc3_config_fail '--batch must be between 1 and 536870912'
                return 1 2>/dev/null || exit 1
            fi
            bc3_extra+=(--batch "$bc3_value")
            ;;
        --threads)
            ((bc3_i += 1))
            if (( bc3_i >= ${#bc3_raw_extra[@]} )) ||
                [[ ! ${bc3_raw_extra[$bc3_i]} =~ ^[0-9]+$ ]]; then
                bc3_config_fail '--threads requires an integer value'
                return 1 2>/dev/null || exit 1
            fi
            bc3_value=${bc3_raw_extra[$bc3_i]}
            if (( 10#$bc3_value < 1 || 10#$bc3_value > 1024 )); then
                bc3_config_fail '--threads must be between 1 and 1024'
                return 1 2>/dev/null || exit 1
            fi
            bc3_extra+=(--threads "$bc3_value")
            ;;
        --backend|--backend=*|--device|--device=*|-o|--pool|--pool=*|-u|--user|--user=*|-p|--pass|--pass=*)
            bc3_config_fail "'$bc3_token' is wrapper-owned and cannot be set in extra arguments"
            return 1 2>/dev/null || exit 1
            ;;
        *)
            bc3_config_fail "unsupported extra argument '$bc3_token'; allowed: --batch N, --threads N"
            return 1 2>/dev/null || exit 1
            ;;
    esac
    ((bc3_i += 1))
done

declare -a bc3_args=(-o "$bc3_pool" -u "$bc3_user" -p "$bc3_pass")
bc3_args+=("${bc3_extra[@]}")

bc3_config_file=$CUSTOM_CONFIG_FILENAME
mkdir -p "$(dirname "$bc3_config_file")" || {
    bc3_config_fail "cannot create config directory for $bc3_config_file"
    return 1 2>/dev/null || exit 1
}
bc3_config_tmp=$(mktemp "${bc3_config_file}.tmp.XXXXXX") || {
    bc3_config_fail "cannot create temporary config beside $bc3_config_file"
    return 1 2>/dev/null || exit 1
}
if {
    printf '# generated by bc3miner-hiveos %s; do not edit\n' "$CUSTOM_VERSION"
    printf 'BC3_ARGS=('
    for bc3_arg in "${bc3_args[@]}"; do
        printf ' %q' "$bc3_arg"
    done
    printf ' )\n'
} > "$bc3_config_tmp" &&
    chmod 0600 "$bc3_config_tmp" &&
    mv -f -- "$bc3_config_tmp" "$bc3_config_file"; then
    :
else
    rm -f -- "$bc3_config_tmp"
    bc3_config_fail "cannot write $bc3_config_file"
    return 1 2>/dev/null || exit 1
fi

printf 'bc3miner-hiveos: configuration written for %s\n' "$bc3_pool"
return 0 2>/dev/null || exit 0
