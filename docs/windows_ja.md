# pg_qualstats Windows x64 バイナリ利用ガイド

## 1. 対象

pgextwinのpg_qualstats packageはWindows x64向けです。

PostgreSQL 14〜18について、それぞれ専用ZIPを作成します。必ず対象PostgreSQLの**メジャーバージョンと一致するZIP**を使用してください。

例:

~~~text
pg_qualstats-2.1.4-pg17-windows-x64.zip
~~~

このZIPはPostgreSQL 17用です。

## 2. 配置

PostgreSQLを停止し、ZIPの内容を次のように配置します。

~~~text
ZIP\lib\pg_qualstats.dll
  -> <PostgreSQL>\lib\pg_qualstats.dll

ZIP\share\extension\pg_qualstats.control
ZIP\share\extension\pg_qualstats--*.sql
  -> <PostgreSQL>\share\extension\
~~~

## 3. preload

`postgresql.conf` の `shared_preload_libraries` に追加します。

~~~conf
shared_preload_libraries = 'pg_qualstats'
~~~

すでに別Extensionがある例:

~~~conf
shared_preload_libraries = 'pgaudit,pg_qualstats'
~~~

設定後はPostgreSQLを再起動します。

## 4. Extension作成

統計を確認したいDBで:

~~~sql
CREATE EXTENSION pg_qualstats;
~~~

確認:

~~~sql
SELECT extname, extversion
FROM pg_extension
WHERE extname = 'pg_qualstats';
~~~

## 5. 最小動作確認

テスト用table:

~~~sql
CREATE TABLE public.pgqs_test (
    id integer PRIMARY KEY,
    payload integer NOT NULL
);

INSERT INTO public.pgqs_test
SELECT g, g % 10
FROM generate_series(1,1000) AS g;
~~~

predicateを実行:

~~~sql
SELECT count(*) FROM public.pgqs_test WHERE payload = 3;
SELECT count(*) FROM public.pgqs_test WHERE payload = 7;
SELECT count(*) FROM public.pgqs_test WHERE id > 900;
~~~

収集結果を確認:

~~~sql
SELECT *
FROM pg_qualstats
WHERE lrelid = 'public.pgqs_test'::regclass;
~~~

読みやすいview:

~~~sql
SELECT *
FROM pg_qualstats_pretty;
~~~

## 6. sample_rate

`pg_qualstats.sample_rate` は、対象queryをどの割合でsampleするかを制御します。

動作確認では確実に収集するため:

~~~conf
pg_qualstats.sample_rate = 1
~~~

とできます。

本番で常時1にするとoverheadやmemory利用が増える可能性があります。通常運用ではupstreamのdefault/推奨とworkloadを確認して決定してください。

## 7. track_constants

`pg_qualstats.track_constants` を有効にすると、constant値ごとの統計を保持します。

分析粒度は上がりますが、必要entry数も増えます。constant単位の分析が不要なら無効化を検討できます。

## 8. max

`pg_qualstats.max` は保持するpredicate/query text entry数に影響します。

大量のdistinct predicateを扱う環境ではdefault値だけで十分とは限りません。memory利用とのバランスを確認してください。

## 9. 統計の永続性

pg_qualstatsの収集データはserver restartをまたいで永続化されません。

長期分析が必要な場合は、外部へ定期保存する仕組みやPoWA等の関連toolの利用を検討してください。

## 10. CIでの実動作確認

pgextwin CIでは各PostgreSQL majorについて:

1. upstream LICENSE検証
2. MSVC x64 build
3. DLL export検証
4. preload状態でPostgreSQL起動
5. `CREATE EXTENSION pg_qualstats`
6. probe table作成
7. predicate実行
8. `pg_qualstats` に統計が存在することを確認
9. `pg_qualstats_pretty` に統計が表示されることを確認
10. ZIP生成

まで実施します。

## 11. 正規の仕様情報

pgextwinはWindows binaryのbuild・検証・配布を担当します。

以下はupstreamドキュメントを優先してください。

- GUCの意味とdefault
- sampling overhead
- memory利用
- predicateの対応範囲
- queryidの扱い
- privilege
- upgrade
- PoWAとの連携
- versionごとの仕様変更
