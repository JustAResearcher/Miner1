#!/usr/bin/env bash
set -euo pipefail

readonly PACKAGE_NAME=bc3miner-hiveos
readonly PACKAGE_VERSION=0.1.2
readonly UPSTREAM_ROOT=bc3miner-0.1.1-linux-x86_64
readonly UPSTREAM_URL=https://github.com/JustAResearcher/BC3Miner/releases/download/v0.1.1/bc3miner-0.1.1-linux-x86_64.tar.gz
readonly UPSTREAM_SHA256=88bc37ba9116dadc714288414f79b9dba1b66ff20e615572e48377d5fb10a4be
readonly DEFAULT_SM89_SHA256=dde97ba0b332b3c0ade275c7ca209ced015513fdcbcee643e80502e9026406ad
readonly DEFAULT_SM120_SHA256=ba8d26ed6f0574d81a787d09a5a4022486b503989f870572da23cb06d1e91708

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
  $0 [UPSTREAM_ARCHIVE]
  $0 --sm89 PATH --sm89-sha256 HASH --sm120 PATH --sm120-sha256 HASH

With no arguments, the pinned public BC3Miner v0.1.1 archive is downloaded.
The explicit form is required to reproduce the older-HiveOS-compatible v0.1.2
release payloads.
EOF
}

upstream_input=''
sm89_payload=''
sm120_payload=''
sm89_sha256=''
sm120_sha256=''
explicit_payloads=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sm89)
            [[ $# -ge 2 ]] || { usage; exit 2; }
            sm89_payload=$2
            explicit_payloads=1
            shift 2
            ;;
        --sm89-sha256)
            [[ $# -ge 2 ]] || { usage; exit 2; }
            sm89_sha256=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')
            explicit_payloads=1
            shift 2
            ;;
        --sm120)
            [[ $# -ge 2 ]] || { usage; exit 2; }
            sm120_payload=$2
            explicit_payloads=1
            shift 2
            ;;
        --sm120-sha256)
            [[ $# -ge 2 ]] || { usage; exit 2; }
            sm120_sha256=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')
            explicit_payloads=1
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            printf 'build: unknown option: %s\n' "$1" >&2
            usage
            exit 2
            ;;
        *)
            [[ -z $upstream_input ]] || {
                printf 'build: more than one upstream archive was supplied\n' >&2
                usage
                exit 2
            }
            upstream_input=$1
            shift
            ;;
    esac
done

if [[ $explicit_payloads -eq 1 ]]; then
    [[ -z $upstream_input ]] || {
        printf 'build: an upstream archive cannot be combined with explicit payloads\n' >&2
        exit 2
    }
    [[ -f $sm89_payload && -f $sm120_payload ]] || {
        printf 'build: both explicit payload paths must be regular files\n' >&2
        usage
        exit 2
    }
    [[ $sm89_sha256 =~ ^[0-9a-f]{64}$ && $sm120_sha256 =~ ^[0-9a-f]{64}$ ]] || {
        printf 'build: both explicit payload SHA-256 values must be 64 hexadecimal characters\n' >&2
        usage
        exit 2
    }
    explicit_dir="$work_dir/explicit"
    install -d -m 0755 "$explicit_dir"
    install -m 0755 "$sm89_payload" "$explicit_dir/bc3miner-sm89"
    install -m 0755 "$sm120_payload" "$explicit_dir/bc3miner-sm120"
    sm89_payload="$explicit_dir/bc3miner-sm89"
    sm120_payload="$explicit_dir/bc3miner-sm120"
    payload_source=explicit-validated-payloads
    source_archive_sha256=not-applicable
else
    sm89_sha256=$DEFAULT_SM89_SHA256
    sm120_sha256=$DEFAULT_SM120_SHA256
    upstream_archive="$work_dir/upstream.tar.gz"
    if [[ -n $upstream_input ]]; then
        cp -- "$upstream_input" "$upstream_archive"
    elif command -v curl >/dev/null 2>&1; then
        curl --fail --location --retry 3 --output "$upstream_archive" "$UPSTREAM_URL"
    elif command -v wget >/dev/null 2>&1; then
        wget --tries=3 --output-document="$upstream_archive" "$UPSTREAM_URL"
    else
        printf 'build: curl or wget is required to download the pinned upstream archive\n' >&2
        exit 1
    fi

    printf '%s  %s\n' "$UPSTREAM_SHA256" "$upstream_archive" | sha256sum -c -
    while IFS= read -r entry; do
        case "$entry" in
            "$UPSTREAM_ROOT"|"$UPSTREAM_ROOT"/*) ;;
            *) printf 'build: upstream archive entry escaped root: %s\n' "$entry" >&2; exit 1 ;;
        esac
        case "/$entry/" in
            */../*) printf 'build: upstream archive contains traversal: %s\n' "$entry" >&2; exit 1 ;;
        esac
    done < <(tar -tzf "$upstream_archive")
    if ! tar -tvzf "$upstream_archive" | awk '$1 !~ /^[d-]/ { exit 1 }'; then
        printf 'build: upstream archive contains a link or special file\n' >&2
        exit 1
    fi

    tar -xzf "$upstream_archive" -C "$work_dir"
    upstream_dir="$work_dir/$UPSTREAM_ROOT"
    sm89_payload="$upstream_dir/lib/sm89/bc3miner"
    sm120_payload="$upstream_dir/lib/sm120/bc3miner"
    payload_source=public-bc3miner-v0.1.1
    source_archive_sha256=$UPSTREAM_SHA256
fi

printf '%s  %s\n' "$sm89_sha256" "$sm89_payload" | sha256sum -c -
printf '%s  %s\n' "$sm120_sha256" "$sm120_payload" | sha256sum -c -
"$sm89_payload" --self-test --cpu-only
"$sm120_payload" --self-test --cpu-only

stage_root="$work_dir/stage"
stage_dir="$stage_root/$PACKAGE_NAME"
install -d -m 0755 "$stage_dir/lib/sm89" "$stage_dir/lib/sm120"
install -m 0755 "$source_dir/h-config.sh" "$stage_dir/h-config.sh"
install -m 0755 "$source_dir/h-run.sh" "$stage_dir/h-run.sh"
install -m 0755 "$source_dir/h-stats.sh" "$stage_dir/h-stats.sh"
install -m 0755 "$source_dir/bc3miner" "$stage_dir/bc3miner"
install -m 0644 "$source_dir/h-manifest.conf" "$stage_dir/h-manifest.conf"
install -m 0644 "$source_dir/BUILD_INFO.json" "$stage_dir/BUILD_INFO.json"
install -m 0644 "$source_dir/README.txt" "$stage_dir/README.txt"
install -m 0755 "$sm89_payload" "$stage_dir/lib/sm89/bc3miner"
install -m 0755 "$sm120_payload" "$stage_dir/lib/sm120/bc3miner"

sed -i \
    -e "s|^readonly SM89_SHA256=.*|readonly SM89_SHA256=\"$sm89_sha256\"|" \
    -e "s|^readonly SM120_SHA256=.*|readonly SM120_SHA256=\"$sm120_sha256\"|" \
    "$stage_dir/bc3miner"
sed -i \
    -e "s|__PAYLOAD_SOURCE__|$payload_source|g" \
    -e "s|__SOURCE_ARCHIVE_SHA256__|$source_archive_sha256|g" \
    -e "s|__SM89_SHA256__|$sm89_sha256|g" \
    -e "s|__SM120_SHA256__|$sm120_sha256|g" \
    "$stage_dir/BUILD_INFO.json"
printf '%s  %s\n%s  %s\n' \
    "$sm89_sha256" 'lib/sm89/bc3miner' \
    "$sm120_sha256" 'lib/sm120/bc3miner' > "$stage_dir/PAYLOAD_SHA256SUMS"

(
    cd "$stage_dir"
    sha256sum -c PAYLOAD_SHA256SUMS
    bash -n h-config.sh h-run.sh h-stats.sh bc3miner
    grep -Fqx "readonly SM89_SHA256=\"$sm89_sha256\"" bc3miner
    grep -Fqx "readonly SM120_SHA256=\"$sm120_sha256\"" bc3miner
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
