# pg_qualstats Windows binaries

[日本語](README_ja.md) | **English**

This repository provides **unofficial Windows x64 binaries** of [pg_qualstats](https://github.com/powa-team/pg_qualstats).

pg_qualstats collects statistics about predicates used in `WHERE` clauses and `JOIN` conditions. The resulting data can help identify frequently evaluated predicates, correlated columns, and potential indexing opportunities.

## Upstream

- repository: `powa-team/pg_qualstats`
- ref: `2.1.4`
- version: 2.1.4
- license: PostgreSQL-style; see `LICENSE`

pgextwin validates PostgreSQL 14–18 on Windows x64.

The first pgextwin package-set release is planned as:

~~~text
v2.1.4-windows.1
~~~

Assets use explicit PostgreSQL-major names:

~~~text
pg_qualstats-2.1.4-pg14-windows-x64.zip
...
pg_qualstats-2.1.4-pg18-windows-x64.zip
~~~

## Installation

1. Choose the ZIP matching the PostgreSQL **major version**.
2. Stop PostgreSQL before replacing extension binaries.
3. Copy `lib/pg_qualstats.dll` to PostgreSQL's `lib` directory.
4. Copy `share/extension/*` to PostgreSQL's `share/extension` directory.
5. Add `pg_qualstats` to `shared_preload_libraries`.
6. Restart PostgreSQL.
7. In each database where statistics are required, run:

~~~sql
CREATE EXTENSION pg_qualstats;
~~~

Example preload setting:

~~~conf
shared_preload_libraries = 'pg_qualstats'
~~~

If other extensions are already preloaded, use a comma-separated list rather than replacing them.

## Basic use

A simple predicate query:

~~~sql
SELECT *
FROM public.example
WHERE status = 1;
~~~

can then contribute statistics to pg_qualstats. Typical inspection queries include:

~~~sql
SELECT * FROM pg_qualstats;
SELECT * FROM pg_qualstats_pretty;
~~~

For deterministic testing or short diagnostic sessions, `pg_qualstats.sample_rate = 1` samples every eligible query. Review the upstream documentation before changing this in production because sampling and memory settings affect overhead.

## Windows build strategy

pg_qualstats 2.1.4 is compiled directly with MSVC x64 against the selected PostgreSQL installation.

The pgextwin build applies one source-layout compatibility edit in the disposable CI checkout. Upstream places a preprocessor conditional inside the argument list of a compatibility `ShmemInitHash(...)` macro call. GCC accepts that layout, while MSVC rejects the `#if/#else` tokens while collecting macro arguments. pgextwin moves the conditional outside the invocation while preserving the same hash flags.

No permanent forked source tree is maintained.

The Windows DLL export list is generated from:

- `Pg_magic_func`,
- `_PG_init`,
- every upstream `PG_FUNCTION_INFO_V1(...)` function,
- each corresponding `pg_finfo_<function>` symbol.

CI then validates the actual DLL export table with `dumpbin`.

## Functional CI

A successful compile is not sufficient. Every supported PostgreSQL major must pass:

1. exact upstream LICENSE verification,
2. MSVC x64 build of `pg_qualstats.dll`,
3. explicit DLL-export validation,
4. installation into the matching PostgreSQL Windows distribution,
5. PostgreSQL startup with `shared_preload_libraries=pg_qualstats`,
6. `CREATE EXTENSION pg_qualstats`,
7. creation of a real probe table,
8. execution of predicates on multiple columns,
9. verification that pg_qualstats collected predicate rows for the probe table,
10. verification that `pg_qualstats_pretty` exposes the collected statistics,
11. package creation and artifact upload.

Pull requests and pushes to `main` validate only. A branch named `release/<tag>` publishes a GitHub Release only after the complete matrix succeeds.

## Configuration notes

Important upstream settings include:

- `pg_qualstats.enabled`
- `pg_qualstats.track_constants`
- `pg_qualstats.max`
- `pg_qualstats.resolve_oids`
- `pg_qualstats.track_pg_catalog`
- `pg_qualstats.sample_rate`

The correct values depend on workload, memory budget, and the amount of diagnostic detail required. Use the upstream documentation as the authoritative reference.

Collected statistics are not durable across PostgreSQL server restarts.

## Licensing

The repository `LICENSE` is an exact copy of the pinned upstream pg_qualstats license. Release ZIPs copy `LICENSE` directly from the upstream checkout used for that package.

These binaries are unofficial pgextwin builds and are not official binary releases from pg_qualstats, PoWA, or PostgreSQL.
