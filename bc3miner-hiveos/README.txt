BC3Miner HiveOS 0.1.1
=====================

Custom Miner name: bc3miner-hiveos

RTX 40-series / compute capability 8.9 uses the BI blocking solver.
RTX 50-series / compute capability 12.0 uses the legacy blocking solver.
Mixed rigs are supported; selection and process isolation use each GPU UUID.

Required:
  - Userspace compatible with the packaged payloads
  - NVIDIA driver 580+

Flight sheet:
  Algorithm: sha3-256t
  Template:  %WAL%.%WORKER_NAME%
  Pool:      stratum+tcp://stratum-us.argfamining.com:24153
  Pass:      x

The package changes no clocks, power limits, fans, or overclock settings.
