#!/usr/bin/env bash
# HiveOS sources this script. It must set khs and stats in the caller's scope.

bc3_stats_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=h-manifest.conf
source "$bc3_stats_dir/h-manifest.conf"

khs=0
stats='{"hs":[0],"hs_units":"khs","total_khs":0,"temp":[0],"fan":[0],"uptime":0,"ver":"0.1.3_rc2","ar":[0,0],"algo":"sha3-256t","bus_numbers":[0],"solver":["unknown"]}'

bc3_stats_trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

declare -A bc3_rate_khs=() bc3_acc=() bc3_rej=() bc3_solver=()
declare -A bc3_bus=() bc3_temp=() bc3_fan=() bc3_cc=() bc3_indices=()
bc3_now=$(date +%s 2>/dev/null || printf '0')
bc3_rate_regex='^\[gpu([0-9]+)\]\[(bi|legacy)\][[:space:]]+\[speed\][[:space:]]+([0-9]+([.][0-9]+)?)[[:space:]]+(H/s|kH/s|MH/s|GH/s|TH/s)[[:space:]]+\|[[:space:]]+A[[:space:]]+([0-9]+)[[:space:]]+R[[:space:]]+([0-9]+)$'

for bc3_rate_file in "$CUSTOM_RATE_DIR"/gpu*.rate; do
    [[ -f $bc3_rate_file ]] || continue
    bc3_rate_name=${bc3_rate_file##*/}
    [[ $bc3_rate_name =~ ^gpu([0-9]+)[.]rate$ ]] || continue
    bc3_file_index=${BASH_REMATCH[1]}
    bc3_mtime=$(stat -c %Y "$bc3_rate_file" 2>/dev/null || printf '0')
    [[ $bc3_now =~ ^[0-9]+$ && $bc3_mtime =~ ^[0-9]+$ ]] || continue
    bc3_age=$((bc3_now - bc3_mtime))
    (( bc3_age >= 0 && bc3_age <= 15 )) || continue
    IFS= read -r bc3_rate_line < "$bc3_rate_file" || true
    [[ $bc3_rate_line =~ $bc3_rate_regex ]] || continue
    bc3_line_index=${BASH_REMATCH[1]}
    [[ $bc3_line_index == "$bc3_file_index" ]] || continue
    bc3_rate_value=${BASH_REMATCH[3]}
    bc3_rate_unit=${BASH_REMATCH[5]}
    case "$bc3_rate_unit" in
        H/s) bc3_multiplier=0.001 ;;
        kH/s) bc3_multiplier=1 ;;
        MH/s) bc3_multiplier=1000 ;;
        GH/s) bc3_multiplier=1000000 ;;
        TH/s) bc3_multiplier=1000000000 ;;
        *) continue ;;
    esac
    bc3_rate_khs[$bc3_file_index]=$(awk -v value="$bc3_rate_value" \
        -v multiplier="$bc3_multiplier" 'BEGIN { printf "%.3f", value * multiplier }')
    bc3_solver[$bc3_file_index]=${BASH_REMATCH[2]}
    bc3_acc[$bc3_file_index]=${BASH_REMATCH[6]}
    bc3_rej[$bc3_file_index]=${BASH_REMATCH[7]}
    bc3_indices[$bc3_file_index]=1
done

bc3_smi_output=''
if command -v nvidia-smi >/dev/null 2>&1; then
    if command -v timeout >/dev/null 2>&1; then
        bc3_smi_output=$(timeout 5 nvidia-smi \
            --query-gpu=index,pci.bus_id,temperature.gpu,fan.speed,compute_cap \
            --format=csv,noheader,nounits 2>/dev/null || true)
    else
        bc3_smi_output=$(nvidia-smi \
            --query-gpu=index,pci.bus_id,temperature.gpu,fan.speed,compute_cap \
            --format=csv,noheader,nounits 2>/dev/null || true)
    fi
fi

while IFS=',' read -r bc3_idx_raw bc3_bus_raw bc3_temp_raw bc3_fan_raw bc3_cc_raw; do
    bc3_idx=$(bc3_stats_trim "$bc3_idx_raw")
    [[ $bc3_idx =~ ^[0-9]+$ ]] || continue
    bc3_bus_raw=$(bc3_stats_trim "$bc3_bus_raw")
    bc3_temp_raw=$(bc3_stats_trim "$bc3_temp_raw")
    bc3_fan_raw=$(bc3_stats_trim "$bc3_fan_raw")
    bc3_cc_raw=$(bc3_stats_trim "$bc3_cc_raw")
    bc3_bus_prefix=${bc3_bus_raw%:*}
    bc3_bus_hex=${bc3_bus_prefix##*:}
    if [[ $bc3_bus_hex =~ ^[0-9A-Fa-f]+$ ]]; then
        bc3_bus[$bc3_idx]=$(printf '%d' "0x$bc3_bus_hex")
    else
        bc3_bus[$bc3_idx]=$bc3_idx
    fi
    [[ $bc3_temp_raw =~ ^[0-9]+$ ]] && bc3_temp[$bc3_idx]=$bc3_temp_raw || bc3_temp[$bc3_idx]=0
    [[ $bc3_fan_raw =~ ^[0-9]+$ ]] && bc3_fan[$bc3_idx]=$bc3_fan_raw || bc3_fan[$bc3_idx]=0
    bc3_cc[$bc3_idx]=$bc3_cc_raw
    bc3_indices[$bc3_idx]=1
done <<< "$bc3_smi_output"

declare -a bc3_sorted_indices=()
if [[ ${#bc3_indices[@]} -gt 0 ]]; then
    mapfile -t bc3_sorted_indices < <(printf '%s\n' "${!bc3_indices[@]}" | sort -n)
fi

declare -a bc3_hs_values=() bc3_temp_values=() bc3_fan_values=()
declare -a bc3_bus_values=() bc3_solver_values=()
bc3_total_khs=0
bc3_total_acc=0
bc3_total_rej=0

for bc3_idx in "${bc3_sorted_indices[@]}"; do
    bc3_value=${bc3_rate_khs[$bc3_idx]:-0}
    bc3_hs_values+=("$bc3_value")
    bc3_total_khs=$(awk -v a="$bc3_total_khs" -v b="$bc3_value" \
        'BEGIN { printf "%.3f", a + b }')
    bc3_total_acc=$((bc3_total_acc + ${bc3_acc[$bc3_idx]:-0}))
    bc3_total_rej=$((bc3_total_rej + ${bc3_rej[$bc3_idx]:-0}))
    bc3_temp_values+=("${bc3_temp[$bc3_idx]:-0}")
    bc3_fan_values+=("${bc3_fan[$bc3_idx]:-0}")
    bc3_bus_values+=("${bc3_bus[$bc3_idx]:-$bc3_idx}")
    bc3_solver_value=${bc3_solver[$bc3_idx]:-}
    if [[ -z $bc3_solver_value ]]; then
        case "${bc3_cc[$bc3_idx]:-}" in
            7.5|8.6) bc3_solver_value=legacy ;;
            *) bc3_solver_value=unknown ;;
        esac
    fi
    bc3_solver_values+=("\"$bc3_solver_value\"")
done

if [[ ${#bc3_hs_values[@]} -eq 0 ]]; then
    bc3_hs_values=(0)
    bc3_temp_values=(0)
    bc3_fan_values=(0)
    bc3_bus_values=(0)
    bc3_solver_values=('"unknown"')
    bc3_total_khs=0
fi

bc3_uptime=0
if command -v pgrep >/dev/null 2>&1; then
    bc3_pid=$(pgrep -fo -- "$bc3_stats_dir/bc3miner" 2>/dev/null || true)
    if [[ $bc3_pid =~ ^[0-9]+$ ]]; then
        bc3_uptime=$(ps -o etimes= -p "$bc3_pid" 2>/dev/null | tr -d '[:space:]')
        [[ $bc3_uptime =~ ^[0-9]+$ ]] || bc3_uptime=0
    fi
fi

bc3_join() {
    local IFS=,
    printf '%s' "$*"
}

bc3_hs_json=$(bc3_join "${bc3_hs_values[@]}")
bc3_temp_json=$(bc3_join "${bc3_temp_values[@]}")
bc3_fan_json=$(bc3_join "${bc3_fan_values[@]}")
bc3_bus_json=$(bc3_join "${bc3_bus_values[@]}")
bc3_solver_json=$(bc3_join "${bc3_solver_values[@]}")

# HiveOS reads these sourced caller-scope variables.
# shellcheck disable=SC2034
khs=$bc3_total_khs
# shellcheck disable=SC2034
printf -v stats \
    '{"hs":[%s],"hs_units":"khs","total_khs":%s,"temp":[%s],"fan":[%s],"uptime":%s,"ver":"%s","ar":[%s,%s],"algo":"sha3-256t","bus_numbers":[%s],"solver":[%s]}' \
    "$bc3_hs_json" "$bc3_total_khs" "$bc3_temp_json" "$bc3_fan_json" \
    "$bc3_uptime" "$CUSTOM_VERSION" "$bc3_total_acc" "$bc3_total_rej" \
    "$bc3_bus_json" "$bc3_solver_json"
