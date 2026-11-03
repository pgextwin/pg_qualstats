# pg_qualstats — Windows x64

[日本語](README_ja.md) | English

pgextwin provides **unofficial Windows x64 binaries** for [pg_qualstats](https://github.com/powa-team/pg_qualstats). pg_qualstats collects statistics about query predicates used in WHERE and JOIN clauses.

## Download and compatibility

Download the ZIP matching your PostgreSQL major from the [latest published Release](https://github.com/pgextwin/pg_qualstats/releases/latest) or [all Releases](https://github.com/pgextwin/pg_qualstats/releases). PostgreSQL **14–18** packages are listed in the [pgextwin catalog](https://pgextwin.github.io/website/en/). PostgreSQL 14 community support ends November 12, 2026. Historical downloads may remain available.

## Installation

1. Back up the PostgreSQL installation and read the [upstream documentation](https://github.com/powa-team/pg_qualstats).
2. Stop PostgreSQL before replacing files. Copy the contents of lib/ and share/extension/ from the ZIP for your PostgreSQL major into the corresponding directories.
3. Start PostgreSQL and run CREATE EXTENSION pg_qualstats; in each database requiring the extension.
4. Some functions may require configuration; refer to the upstream documentation for collecting and resetting statistics. Test in a non-production environment before deployment.

Use SHA256SUMS.txt attached to the Release to verify downloaded files. The Release may also include SPDX SBOMs, vulnerability reports and signed attestations.

## License

Features, configuration, and limitations are documented upstream. pgextwin is an independent community distribution, not an official upstream Windows package. Read the included license notices.
