# BC3Miner Linux 0.1.1

- Publishes `bc3miner-0.1.1-linux-x86_64.tar.gz` plus its SHA-256 sidecar for
  CatStack automatic download and standalone Linux installation.
- Publishes `bc3miner-hiveos-0.1.1.tar.gz` plus its SHA-256 sidecar for HiveOS.
- Adds a HiveOS Custom Miner package with matching
  `bc3miner-hiveos-0.1.1.tar.gz` / `bc3miner-hiveos/` identity.
- Selects the checksum-pinned BI solver on RTX 40-series GPUs and the
  checksum-pinned legacy solver on RTX 50-series GPUs, independently per GPU.
- Supports mixed RTX 40/50 rigs using UUID-isolated child processes.
- Fails closed before mining on unsupported GPUs, incompatible runtimes, old
  drivers, or payload checksum failures.
- Reports fresh per-GPU hashrate, accepted/rejected shares, temperatures, fans,
  PCI buses, and selected solvers through HiveOS's `h-stats.sh` contract.
- Makes no power-limit, clock, fan, or overclock changes.

The HiveOS builder supports the pinned public BC3Miner v0.1.1 Linux archive and
explicitly supplied, separately validated HiveOS-compatible payloads. It
verifies and records every payload hash before packaging.
