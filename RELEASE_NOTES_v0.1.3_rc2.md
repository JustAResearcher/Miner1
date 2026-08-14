# BC3Miner HiveOS SM 8.0 Release Candidate 0.1.3 RC2

- Adds a native `sm_80` cubin and launcher support for compute capability 8.0,
  including NVIDIA CMP 170HX.
- Retains the native `sm_75` and `sm_86` legacy-solver paths from RC1.
- Launches one process per GPU by UUID and reports per-GPU HiveOS statistics.
- Does not modify clocks, power limits, fans, or HiveOS overclock settings.
- Fails closed for all other compute capabilities; use v0.1.2 for the validated
  RTX 40/50 path.

This is a prerelease. CPU vectors, archive checks, and native-cubin inspection
pass, but no SM 8.0 GPU has executed it yet. A CMP 170HX canary must still
verify GPU hashes, accepted shares, hashrate, and power before production use.
