BC3Miner HiveOS RTX 20/30 Release Candidate 0.1.3
=====================

Custom Miner name: bc3miner-hiveos

RTX 20-series / compute capability 7.5 uses the legacy solver.
RTX 30-series / compute capability 8.6 uses the legacy solver.
Mixed RTX 20/30 rigs are supported; selection and process isolation use each
GPU UUID. Other compute capabilities fail closed.

Required:
  - Ubuntu 22.04-class userspace or newer
  - NVIDIA driver 580+

Flight sheet:
  Algorithm: sha3-256t
  Template:  %WAL%.%WORKER_NAME%
  Pool:      stratum+tcp://stratum-us.argfamining.com:24153
  Pass:      x

The package changes no clocks, power limits, fans, or overclock settings.
GPU correctness, accepted shares, and hashrate are unvalidated until a real
RTX 20-series and RTX 30-series canary completes.
