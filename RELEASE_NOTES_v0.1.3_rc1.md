# BC3Miner HiveOS RTX 20/30 Release Candidate 0.1.3

- Adds a HiveOS Custom Miner package for compute capability 7.5 (RTX 20) and
  8.6 (RTX 30).
- Uses the legacy solver only, with a native `sm_75` / `sm_86` CUDA payload.
- Launches one process per GPU by UUID and reports per-GPU HiveOS statistics.
- Does not modify clocks, power limits, fans, or HiveOS overclock settings.
- Fails closed for all other compute capabilities; use the existing v0.1.2
  package for the validated RTX 40/50 path.

This is a prerelease. CPU vectors and archive checks pass, but no RTX 20/30
GPU has executed the candidate yet. Do not treat it as performance-validated
until a hardware canary verifies GPU hashes, accepted shares, and hashrate.
