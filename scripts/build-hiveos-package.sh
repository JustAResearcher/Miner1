#!/usr/bin/env bash
set -euo pipefail

readonly PACKAGE_NAME=bc3miner-hiveos
readonly PACKAGE_VERSION=0.1.3_rc2

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_dir="$repo_root/$PACKAGE_NAME"
output_dir="$repo_root/dist"
archive="$output_dir/${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz"
work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT

for command_name in sha256sum tar gzip install mktemp sed awk tr; do
    command -v "$command_name" >/dev/null 2>&1 || {
        printf 'build: required command not found: %s\n' "$command_name" >&2
        exit 1
    }
done

usage() {
    cat >&2 <<EOF
Usage:
  $0 --sm75-sm80-sm86 PATH --sm75-sm80-sm86-sha256 HASH

Builds the HiveOS Turing/Ampere release candidate from one checksum-pinned
legacy solver binary containing native sm_75, sm_80, and sm_86 cubins.
EOF
}

payload=''
payload_sha256=''
while [[ $# -gt 0 ]]; do
    case "$1" in
        --sm75-sm80-sm86)
            [[ $# -ge 2 ]] || { usage; exit 2; }
            payload=$2
            shift 2
            ;;
        --sm75-sm80-sm86-sha256)
            [[ $# -ge 2 ]] || { usage; exit 2; }
            payload_sha256=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'build: unknown option: %s\n' "$1" >&2
            usage
            exit 2
            ;;
    esac
done

[[ -f $payload ]] || { printf 'build: --sm75-sm80-sm86 must name a regular file\n' >&2; exit 2; }
[[ $payload_sha256 =~ ^[0-9a-f]{64}$ ]] || {
    printf 'build: --sm75-sm80-sm86-sha256 must be 64 hexadecimal characters\n' >&2
    exit 2
}

payload_copy="$work_dir/bc3miner-sm75-sm80-sm86"
install -m 0755 "$payload" "$payload_copy"
printf '%s  %s\n' "$payload_sha256" "$payload_copy" | sha256sum -c -
"$payload_copy" --self-test --cpu-only

stage_root="$work_dir/stage"
stage_dir="$stage_root/$PACKAGE_NAME"
install -d -m 0755 "$stage_dir/lib/sm75-sm80-sm86"
for executable in h-config.sh h-run.sh h-stats.sh bc3miner; do
    install -m 0755 "$source_dir/$executable" "$stage_dir/$executable"
done
for document in h-manifest.conf BUILD_INFO.json README.txt; do
    install -m 0644 "$source_dir/$document" "$stage_dir/$document"
done
install -m 0755 "$payload_copy" "$stage_dir/lib/sm75-sm80-sm86/bc3miner"

sed -i \
    -e "s|^readonly SM75_SM80_SM86_SHA256=.*|readonly SM75_SM80_SM86_SHA256=\"$payload_sha256\"|" \
    "$stage_dir/bc3miner"
sed -i \
    -e "s|__SM75_SM80_SM86_SHA256__|$payload_sha256|g" \
    "$stage_dir/BUILD_INFO.json"
printf '%s  %s\n' "$payload_sha256" 'lib/sm75-sm80-sm86/bc3miner' > "$stage_dir/PAYLOAD_SHA256SUMS"

(
    cd "$stage_dir"
    sha256sum -c PAYLOAD_SHA256SUMS
    bash -n h-config.sh h-run.sh h-stats.sh bc3miner
    grep -Fqx "readonly SM75_SM80_SM86_SHA256=\"$payload_sha256\"" bc3miner
    ! grep -q '__[A-Z0-9_]*__' BUILD_INFO.json
)

mkdir -p "$output_dir"
rm -f -- "$archive" "${archive}.sha256"
(
    cd "$stage_root"
    tar --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 \
        --numeric-owner -cf - "$PACKAGE_NAME" | gzip -n > "$archive"
)
(
    cd "$output_dir"
    sha256sum "$(basename "$archive")" > "$(basename "$archive").sha256"
)

printf 'Built %s\n' "$archive"
printf 'Checksum: '
cat "${archive}.sha256"
