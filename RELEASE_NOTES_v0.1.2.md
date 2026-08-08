# BC3Miner HiveOS Legacy 0.1.2

- Adds an older-HiveOS-compatible `bc3miner-hiveos-0.1.2.tar.gz` package.
- Runs on Ubuntu 18.04-class HiveOS userspace (glibc 2.27) and newer.
- Keeps the exact validated RTX 40 BI kernel cubin and RTX 50 legacy solver
  cubins used by the production miners.
- Selects BI for compute capability 8.9 and legacy for compute capability 12.0,
  including mixed-generation rigs.
- Retains blocking CUDA synchronization, per-GPU HiveOS statistics, checksum
  validation, and the no-power/no-clock/no-fan-change policy.

NVIDIA driver 580 or newer is still required. The package was CPU-tested in an
Ubuntu 18.04 container and GPU-tested on an RTX 4070 Ti SUPER and RTX 5090.
