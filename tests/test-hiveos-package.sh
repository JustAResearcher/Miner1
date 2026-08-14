#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    printf 'Usage: %s PACKAGE.tar.gz\n' "$0" >&2
    exit 2
fi

archive=$(readlink -f "$1")
sidecar="${archive}.sha256"
[[ -f $archive && -f $sidecar ]]
(
    cd "$(dirname "$archive")"
    sha256sum -c "$(basename "$sidecar")"
)

work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT
package_name=bc3miner-hiveos

while IFS= read -r entry; do
    case "$entry" in
        "$package_name"|"$package_name"/*) ;;
        *) printf 'test: archive entry escaped package root: %s\n' "$entry" >&2; exit 1 ;;
    esac
    case "/$entry/" in
        */../*) printf 'test: archive contains traversal: %s\n' "$entry" >&2; exit 1 ;;
    esac
done < <(tar -tzf "$archive")
if ! tar -tvzf "$archive" | awk '$1 !~ /^[d-]/ { exit 1 }'; then
    printf 'test: archive contains a link or special file\n' >&2
    exit 1
fi

tar -xzf "$archive" -C "$work_dir"
package_dir="$work_dir/$package_name"
cd "$package_dir"

[[ -x h-config.sh && -x h-run.sh && -x h-stats.sh && -x bc3miner ]]
[[ -x lib/sm75-sm80-sm86/bc3miner ]]
bash -n h-config.sh h-run.sh h-stats.sh bc3miner
sha256sum -c PAYLOAD_SHA256SUMS
lib/sm75-sm80-sm86/bc3miner --self-test --cpu-only
payload_actual=$(sha256sum lib/sm75-sm80-sm86/bc3miner | awk '{print $1}')
grep -Fqx "readonly SM75_SM80_SM86_SHA256=\"$payload_actual\"" bc3miner
grep -Fq "\"sm75_sm80_sm86_legacy\": \"$payload_actual\"" BUILD_INFO.json

fakebin="$work_dir/fakebin"
mkdir -p "$fakebin"
cat > "$fakebin/nvidia-smi" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *--query-gpu=driver_version*) printf '%s\n' '580.173.02' ;;
    *--query-gpu=index,uuid,name,compute_cap*) printf '%s\n' "${BC3_TEST_GPU_CSV:?}" ;;
    *--query-gpu=index,pci.bus_id,temperature.gpu,fan.speed,compute_cap*)
        printf '%s\n' "${BC3_TEST_STATS_CSV:-}" ;;
    *) exit 2 ;;
esac
EOF
chmod +x "$fakebin/nvidia-smi"
cat > "$fakebin/date" <<'EOF'
#!/usr/bin/env bash
if [[ $* == '+%s' && -n ${BC3_TEST_NOW:-} ]]; then
    printf '%s\n' "$BC3_TEST_NOW"
else
    exec /bin/date "$@"
fi
EOF
chmod +x "$fakebin/date"
export PATH="$fakebin:$PATH"

BC3_TEST_GPU_CSV='0, GPU-TURING, NVIDIA GeForce RTX 2080 Ti, 7.5' \
    ./bc3miner --list-gpu-plan > "$work_dir/sm75.plan"
grep -Fq 'GPU 0 uuid=GPU-TURING name=NVIDIA GeForce RTX 2080 Ti arch=sm_75 solver=legacy backend=legacy' "$work_dir/sm75.plan"

BC3_TEST_GPU_CSV='0, GPU-AMPERE-DC, NVIDIA CMP 170HX, 8.0' \
    ./bc3miner --list-gpu-plan > "$work_dir/sm80.plan"
grep -Fq 'GPU 0 uuid=GPU-AMPERE-DC name=NVIDIA CMP 170HX arch=sm_80 solver=legacy backend=legacy' \
    "$work_dir/sm80.plan"

BC3_TEST_GPU_CSV='0, GPU-AMPERE, NVIDIA GeForce RTX 3080, 8.6' \
    ./bc3miner --list-gpu-plan > "$work_dir/sm86.plan"
grep -Fq 'GPU 0 uuid=GPU-AMPERE name=NVIDIA GeForce RTX 3080 arch=sm_86 solver=legacy backend=legacy' \
    "$work_dir/sm86.plan"

BC3_TEST_GPU_CSV=$'0, GPU-TURING, NVIDIA GeForce RTX 2080 Ti, 7.5\n1, GPU-AMPERE-DC, NVIDIA CMP 170HX, 8.0\n2, GPU-AMPERE, NVIDIA GeForce RTX 3080, 8.6' \
    ./bc3miner --list-gpu-plan > "$work_dir/mixed.plan"
[[ $(wc -l < "$work_dir/mixed.plan") -eq 3 ]]
grep -Fq 'GPU 0 uuid=GPU-TURING name=NVIDIA GeForce RTX 2080 Ti arch=sm_75 solver=legacy backend=legacy' "$work_dir/mixed.plan"
grep -Fq 'GPU 1 uuid=GPU-AMPERE-DC name=NVIDIA CMP 170HX arch=sm_80 solver=legacy backend=legacy' \
    "$work_dir/mixed.plan"
grep -Fq 'GPU 2 uuid=GPU-AMPERE name=NVIDIA GeForce RTX 3080 arch=sm_86 solver=legacy backend=legacy' \
    "$work_dir/mixed.plan"

unsupported_rates="$work_dir/unsupported-rates"
if BC3MINER_RATE_DIR="$unsupported_rates" BC3_TEST_GPU_CSV='0, GPU-ADA, NVIDIA GeForce RTX 4070 Ti SUPER, 8.9' \
    ./bc3miner --list-gpu-plan > "$work_dir/unsupported.out" 2>&1; then
    printf 'test: unsupported GPU unexpectedly passed\n' >&2
    exit 1
fi
grep -Fq 'unsupported compute capability 8.9' "$work_dir/unsupported.out"
[[ ! -e $unsupported_rates ]]

config_file="$work_dir/bc3miner.conf"
CUSTOM_CONFIG_FILENAME="$config_file" \
CUSTOM_TEMPLATE='%WAL%.%WORKER_NAME%' \
CUSTOM_URL='stratum-us.argfamining.com:24153' \
CUSTOM_PASS=x CUSTOM_ALGO=sha3-256t \
WAL='bc1qtestwallet' WORKER_NAME='rig01' \
CUSTOM_USER_CONFIG=$'--batch 134217728\n--threads 128' \
    source ./h-config.sh
# shellcheck disable=SC1090
source "$config_file"
expected_args=(-o stratum+tcp://stratum-us.argfamining.com:24153 \
    -u bc1qtestwallet.rig01 -p x --batch 134217728 --threads 128)
[[ ${BC3_ARGS[*]} == "${expected_args[*]}" ]]

if CUSTOM_CONFIG_FILENAME="$work_dir/bad.conf" CUSTOM_TEMPLATE='%WAL%.%WORKER_NAME%' \
    CUSTOM_URL='pool-one:1,pool-two:2' WAL=wallet WORKER_NAME=rig \
    source ./h-config.sh >/dev/null 2>&1; then
    printf 'test: multiple pools unexpectedly passed\n' >&2
    exit 1
fi
if CUSTOM_CONFIG_FILENAME="$work_dir/bad.conf" CUSTOM_TEMPLATE='%WAL%.%WORKER_NAME%' \
    CUSTOM_URL='pool:1' WAL=wallet WORKER_NAME=rig CUSTOM_USER_CONFIG='--backend bi' \
    source ./h-config.sh >/dev/null 2>&1; then
    printf 'test: backend override unexpectedly passed\n' >&2
    exit 1
fi

rate_dir="$work_dir/rates"
mkdir -p "$rate_dir"
printf '%s\n' '[gpu0][legacy] [speed] 920.02 MH/s | A 3 R 1' > "$rate_dir/gpu0.rate"
printf '%s\n' '[gpu1][legacy] [speed] 1.024 GH/s | A 4 R 0' > "$rate_dir/gpu1.rate"
export BC3_TEST_STATS_CSV=$'0, 00000000:01:00.0, 61, 70, 7.5\n1, 00000000:0A:00.0, 65, 75, 8.6'
CUSTOM_RATE_DIR="$rate_dir" source ./h-stats.sh
[[ $khs == 1944020.000 ]]
[[ $stats == *'"hs":[920020.000,1024000.000]'* ]]
[[ $stats == *'"ar":[7,1]'* ]]
[[ $stats == *'"bus_numbers":[1,10]'* ]]
[[ $stats == *'"solver":["legacy","legacy"]'* ]]

touch -d '@1' "$rate_dir/gpu0.rate"
CUSTOM_RATE_DIR="$rate_dir" source ./h-stats.sh
[[ $khs == 1024000.000 ]]
[[ $stats == *'"hs":[0,1024000.000]'* ]]

printf '%s\n' '[gpu1][legacy] [speed] 999.00 GH/s | A 99 R 99' > "$rate_dir/gpu0.rate"
CUSTOM_RATE_DIR="$rate_dir" source ./h-stats.sh
[[ $khs == 1024000.000 ]]
[[ $stats == *'"hs":[0,1024000.000]'* ]]

boundary_rate_dir="$work_dir/boundary-rates"
mkdir -p "$boundary_rate_dir"
printf '%s\n' '[gpu0][legacy] [speed] 1.00 MH/s | A 1 R 0' > "$boundary_rate_dir/gpu0.rate"
touch -d '@1000' "$boundary_rate_dir/gpu0.rate"
export BC3_TEST_STATS_CSV='0, 00000000:01:00.0, 61, 70, 7.5'
export BC3_TEST_NOW=1015
CUSTOM_RATE_DIR="$boundary_rate_dir" source ./h-stats.sh
[[ $khs == 1000.000 ]]
export BC3_TEST_NOW=1016
CUSTOM_RATE_DIR="$boundary_rate_dir" source ./h-stats.sh
[[ $khs == 0.000 ]]
unset BC3_TEST_NOW

if grep -En -- '--power-limit|(^|[[:space:]])-pl([=[:space:]]|$)|--lock-gpu|nvidia-settings' \
    h-config.sh h-run.sh h-stats.sh bc3miner; then
    printf 'test: wrapper contains a power/clock/fan control command\n' >&2
    exit 1
fi

printf 'BC3Miner HiveOS package tests passed\n'
