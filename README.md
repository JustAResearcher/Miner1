# BC3Miner Linux packages

Miner1 v0.1.1 distributes the dev-fee-free BC3 SHA3-256T miner in two Linux
packages, each with a SHA-256 sidecar:

- `bc3miner-0.1.1-linux-x86_64.tar.gz` for CatStack automatic installation and
  standalone Ubuntu/MeowOS installation.
- `bc3miner-hiveos-0.1.1.tar.gz` for HiveOS Custom Miner installation.

Both packages support NVIDIA RTX 40-series and RTX 50-series GPUs, including
mixed-generation rigs. CatStack's built-in BC3Miner definition downloads the
first bundle automatically when its BC3 flight sheet is applied. The remainder
of this README documents the HiveOS wrapper and build.

The wrapper inventories the complete GPU set before mining, then launches one
isolated process per GPU:

- Compute capability 8.9 / RTX 40 series: validated BI blocking solver.
- Compute capability 12.0 / RTX 50 series: validated legacy blocking solver.

Selection uses each GPU's UUID, not a mutable CUDA ordinal. If any GPU is
unsupported, unidentified, or either payload fails checksum verification, no
miner process is started. The wrapper never changes power limits, clocks, fans,
or HiveOS overclock settings.

## Compatibility

- x86-64 HiveOS
- NVIDIA driver 580 or newer
- NVIDIA compute capability 8.9 and/or 12.0

The default public BC3Miner v0.1.1 payloads require glibc 2.34 and GLIBCXX
3.4.29 (Ubuntu 22.04-class userspace). The builder also accepts separately
validated HiveOS-compatible payloads. The wrapper detects an incompatible
runtime and exits; it never replaces system libraries.

## Build locally

The builder downloads the public BC3Miner v0.1.1 Linux package and verifies its
pinned SHA-256 before extracting the two pinned solver payloads:

```bash
bash scripts/build-hiveos-package.sh
bash tests/test-hiveos-package.sh dist/bc3miner-hiveos-0.1.1.tar.gz
```

Outputs:

- `dist/bc3miner-hiveos-0.1.1.tar.gz`
- `dist/bc3miner-hiveos-0.1.1.tar.gz.sha256`

The CatStack/standalone bundle is produced by the BC3Miner Linux packaging
pipeline and is attached beside these HiveOS assets in the Miner1 v0.1.1
release; this HiveOS builder does not rebuild that separate bundle.

For an offline/reproducible rebuild, pass a previously downloaded, unmodified
upstream archive. It is checked against the same pinned digest:

```bash
bash scripts/build-hiveos-package.sh /path/to/bc3miner-0.1.1-linux-x86_64.tar.gz
```

To package separately validated HiveOS-compatible payloads, provide both files
and their required hashes explicitly. The builder copies the files into a
private staging directory, verifies both hashes, runs both CPU self-tests, and
embeds those hashes in the launcher and package metadata:

```bash
bash scripts/build-hiveos-package.sh \
  --sm89 /path/to/sm89/bc3miner \
  --sm89-sha256 64_HEX_CHARACTERS \
  --sm120 /path/to/sm120/bc3miner \
  --sm120-sha256 64_HEX_CHARACTERS
```

## HiveOS flight sheet

After attaching the package tarball to a GitHub release, configure Custom Miner
with these values:

| Field | Value |
| --- | --- |
| Miner name | `bc3miner-hiveos` |
| Installation URL | `https://github.com/JustAResearcher/Miner1/releases/download/v0.1.1/bc3miner-hiveos-0.1.1.tar.gz` |
| Hash algorithm | `sha3-256t` |
| Wallet and worker template | `%WAL%.%WORKER_NAME%` |
| Pool URL | `stratum+tcp://stratum-us.argfamining.com:24153` |
| Pass | `x` |

The pool field accepts one plain `HOST:PORT`, `stratum://HOST:PORT`, or
`stratum+tcp://HOST:PORT` endpoint. BC3Miner does not implement TLS or pool
failover, so the wrapper rejects TLS endpoints and multiple pools instead of
silently misconfiguring them.

Optional extra arguments are intentionally limited to the miner's production
tuning controls:

```text
--batch 134217728
--threads 128
```

Device and backend options are wrapper-owned and are rejected.

## Dashboard statistics

The launcher writes one atomic, short-lived rate record per GPU. `h-stats.sh`
validates the record filename, embedded GPU index, age, units, and share
counters before reporting per-GPU and total kH/s to HiveOS. Temperature, fan,
and PCI bus values come from `nvidia-smi` and stay aligned with the hardware GPU
indices.
