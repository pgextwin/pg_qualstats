# pg_qualstats Windows バイナリ

[English](README.md) | **日本語**

このリポジトリでは、[pg_qualstats](https://github.com/powa-team/pg_qualstats) 2.1.4 の **非公式 Windows x64 バイナリ**を提供します。

pg_qualstatsは、SQLの `WHERE` 条件や `JOIN` 条件に現れるpredicate（絞り込み条件）の統計を収集するPostgreSQL Extensionです。頻繁に評価される条件、同時に利用される列、index候補の分析などに利用できます。

## upstream

- repository: `powa-team/pg_qualstats`
- ref: `2.1.4`
- version: 2.1.4
- license: PostgreSQL-style（`LICENSE` 参照）

pgextwinではPostgreSQL 14〜18をWindows x64で検証します。

初回Release tagは次を予定しています。

~~~text
v2.1.4-windows.1
~~~

ZIP名:

~~~text
pg_qualstats-2.1.4-pg14-windows-x64.zip
...
pg_qualstats-2.1.4-pg18-windows-x64.zip
~~~

## 導入

1. PostgreSQLの**メジャーバージョンに一致するZIP**を選びます。
2. PostgreSQLを停止します。
3. `lib/pg_qualstats.dll` をPostgreSQLの `lib` へコピーします。
4. `share/extension/*` をPostgreSQLの `share/extension` へコピーします。
5. `shared_preload_libraries` に `pg_qualstats` を追加します。
6. PostgreSQLを再起動します。
7. 統計を利用するDBで次を実行します。

~~~sql
CREATE EXTENSION pg_qualstats;
~~~

設定例:

~~~conf
shared_preload_libraries = 'pg_qualstats'
~~~

すでに別Extensionをpreloadしている場合は、既存値を消さずカンマ区切りで追加してください。

## 基本的な利用

例えば次のようなpredicateを含むSQLを実行すると:

~~~sql
SELECT *
FROM public.example
WHERE status = 1;
~~~

条件の実行統計がpg_qualstatsへ蓄積されます。

確認例:

~~~sql
SELECT * FROM pg_qualstats;
SELECT * FROM pg_qualstats_pretty;
~~~

短時間の検証で全eligible queryをsampleしたい場合は `pg_qualstats.sample_rate = 1` を利用できます。本番ではoverheadやmemory利用に影響するため、upstreamドキュメントを確認して設定してください。

## Windows build

pg_qualstats 2.1.4は、対象PostgreSQLのheader/import libraryを使ってMSVC x64で直接compileします。

pgextwinではbuild用の一時checkoutに対して、1点だけMSVC互換処理を行います。

upstream 2.1.4では、互換用 `ShmemInitHash(...)` macroの引数中に `#if/#else` が存在します。GCCでは通りますが、MSVCはmacro引数の収集中にこのpreprocessor tokenを受け付けません。

そこでpgextwinでは、同じhash flagを保ったまま条件分岐をmacro呼び出しの外側へ移動します。upstream sourceを恒久forkするものではありません。

またDLL exportは次から明示生成します。

- `Pg_magic_func`
- `_PG_init`
- upstreamの全 `PG_FUNCTION_INFO_V1(...)` 関数
- 対応する全 `pg_finfo_<関数名>`

build後に `dumpbin` で実際のexport tableも検証します。

## CIの合格条件

各PostgreSQL majorで次まで確認します。

- upstream LICENSEの完全一致
- `pg_qualstats.dll` のMSVC x64 build
- DLL exportの明示検証
- Extension fileの配置
- `shared_preload_libraries=pg_qualstats` でPostgreSQL起動
- `CREATE EXTENSION pg_qualstats`
- probe table作成
- 複数predicateの実行
- `pg_qualstats` に対象tableのpredicate統計が記録されること
- `pg_qualstats_pretty` から人間向け形式で統計を取得できること
- Windows x64 ZIP生成

単なるcompile成功やDLL loadだけでは合格にしません。

## 主な設定

upstreamで提供される主なGUC:

- `pg_qualstats.enabled`
- `pg_qualstats.track_constants`
- `pg_qualstats.max`
- `pg_qualstats.resolve_oids`
- `pg_qualstats.track_pg_catalog`
- `pg_qualstats.sample_rate`

最適値はworkload、memory budget、必要な分析粒度で変わります。

収集された統計はPostgreSQL serverのrestartをまたいで永続化されません。

## ライセンス

このrepositoryの `LICENSE` はupstream 2.1.4のLICENSEと同一です。Release ZIPにもbuildに使用したupstream checkoutからLICENSEを直接同梱します。

本バイナリはpgextwinによる非公式配布であり、pg_qualstats、PoWA、PostgreSQLプロジェクトによる公式Windows binaryではありません。
