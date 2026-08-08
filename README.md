# BC3Miner Linux packages

Miner1 distributes the dev-fee-free BC3 SHA3-256T miner in Linux packages with
SHA-256 sidecars:

- `bc3miner-0.1.1-linux-x86_64.tar.gz` for CatStack automatic installation and
  standalone Ubuntu/MeowOS installation.
- `bc3miner-hiveos-0.1.2.tar.gz` for older and current HiveOS Custom Miner
  installation.

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

The v0.1.2 HiveOS payloads require at most GLIBC 2.14 and have no dynamic
GLIBCXX dependency. They were validated in Ubuntu 18.04 with glibc 2.27. The
wrapper detects an incompatible runtime and exits; it never replaces system
libraries. NVIDIA driver 580 or newer is still required.

## Build locally

The builder can consume the public v0.1.1 Linux package for current systems,
but reproducing the v0.1.2 older-HiveOS release requires the two explicitly
validated compatibility payloads:

```bash
bash scripts/build-hiveos-package.sh \
  --sm89 /path/to/validated/sm89/bc3miner \
  --sm89-sha256 26629330c9d19ef85a44307f8a0ca07c0842ac28e6db3bd25a39f6447089ec62 \
  --sm120 /path/to/validated/sm120/bc3miner \
  --sm120-sha256 381cd83b27e2291c973e4d90139ff998b40e9cd44663117629551759fc1c59ca
bash tests/test-hiveos-package.sh dist/bc3miner-hiveos-0.1.2.tar.gz
```

Outputs:

- `dist/bc3miner-hiveos-0.1.2.tar.gz`
- `dist/bc3miner-hiveos-0.1.2.tar.gz.sha256`

The CatStack/standalone bundle remains in the Miner1 v0.1.1 release; this
HiveOS builder does not rebuild that separate bundle.

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
| Installation URL | `https://github.com/JustAResearcher/Miner1/releases/download/v0.1.2/bc3miner-hiveos-0.1.2.tar.gz` |
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
