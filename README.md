# BC3Miner Linux and HiveOS packages

Miner1 distributes the dev-fee-free BC3 SHA3-256T miner in Linux packages with
SHA-256 sidecars:

- `bc3miner-0.1.1-linux-x86_64.tar.gz` for CatStack automatic installation and
  standalone Ubuntu/MeowOS installation.
- `bc3miner-hiveos-0.1.2.tar.gz` for older and current HiveOS Custom Miner
  installation on validated RTX 40/50 GPUs.
- `bc3miner-hiveos-0.1.3_rc1.tar.gz` for HiveOS testing on RTX 20/30 GPUs.
  installation.

The CatStack bundle supports its validated RTX 40/50 fleet. The v0.1.3 RC
HiveOS package supports only RTX 20/30 hardware; it is not a replacement for
v0.1.2. CatStack's built-in BC3Miner definition downloads the first bundle
automatically when its BC3 flight sheet is applied. The remainder of this
README documents the HiveOS release candidate.

The wrapper inventories the complete GPU set before mining, then launches one
isolated process per GPU:

- Compute capability 7.5 / RTX 20 series: legacy solver.
- Compute capability 8.6 / RTX 30 series: legacy solver.

Selection uses each GPU's UUID, not a mutable CUDA ordinal. If any GPU is
unsupported, unidentified, or either payload fails checksum verification, no
miner process is started. The wrapper never changes power limits, clocks, fans,
or HiveOS overclock settings.

## Compatibility

- x86-64 HiveOS
- NVIDIA driver 580 or newer
- NVIDIA compute capability 7.5 and/or 8.6

The v0.1.3 RC payload was built on Ubuntu 22.04 and needs a current HiveOS
userspace. It does not replace system libraries. NVIDIA driver 580 or newer is
required. The older-HiveOS-compatible v0.1.2 package remains available for its
validated RTX 40/50 targets.

## Build locally

Build the RTX 20/30 release candidate with its checksum-pinned combined legacy
payload:

```bash
bash scripts/build-hiveos-package.sh \
  --sm75-sm86 /path/to/bc3miner \
  --sm75-sm86-sha256 3212518874a1a316f67be5e203fbb923a0c8644020e7281452fe16e174e57ab1
bash tests/test-hiveos-package.sh dist/bc3miner-hiveos-0.1.3_rc1.tar.gz
```

Outputs:

- `dist/bc3miner-hiveos-0.1.3_rc1.tar.gz`
- `dist/bc3miner-hiveos-0.1.3_rc1.tar.gz.sha256`

The CatStack/standalone bundle remains in the Miner1 v0.1.1 release; this
HiveOS builder does not rebuild that separate bundle.

## HiveOS flight sheet

After attaching the package tarball to a GitHub release, configure Custom Miner
with these values:

| Field | Value |
| --- | --- |
| Miner name | `bc3miner-hiveos` |
| Installation URL | `https://github.com/JustAResearcher/Miner1/releases/download/v0.1.3-rc1/bc3miner-hiveos-0.1.3_rc1.tar.gz` |
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
