# Binary distribution notice

Miner1 v0.1.1 distributes two Linux binary bundles: the
`bc3miner-0.1.1-linux-x86_64.tar.gz` CatStack/standalone package and the
`bc3miner-hiveos-0.1.1.tar.gz` HiveOS Custom Miner package. Each release asset
has a SHA-256 sidecar.

Miner1 v0.1.2 adds an older-HiveOS-compatible build of the HiveOS package.

Miner1 v0.1.3-rc2 adds an unvalidated SM 7.5/8.0/8.6 HiveOS candidate. It is a
separate prerelease and does not replace the validated v0.1.2 RTX 40/50 asset.

The HiveOS integration scripts are stored in this repository. BC3Miner solver
executables are not stored in git; the package builder accepts checksum-pinned,
validated payloads and embeds their exact identities in package metadata.

This repository does not claim that the BC3Miner solver source code is open
source. The HiveOS wrapper does not charge or add a developer fee.
