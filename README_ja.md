# pg_qualstats — Windows x64 バイナリ

[English](README.md) | 日本語

[pg_qualstats](https://github.com/powa-team/pg_qualstats)の**非公式Windows x64バイナリ**を配布しています。WHERE句やJOIN条件に現れる絞り込み条件の統計情報を収集します。

## ダウンロードと対応環境

[最新の公開Release](https://github.com/pgextwin/pg_qualstats/releases/latest)から、利用中のPostgreSQLメジャーバージョンに一致するZIPを選んでください。[過去のReleases](https://github.com/pgextwin/pg_qualstats/releases)も参照できます。PostgreSQL **14〜18**向けの配布状況は[pgextwinカタログ](https://pgextwin.github.io/website/ja/)に掲載しています。PostgreSQL 14のコミュニティサポートは2026年11月12日に終了します。

## インストール

1. PostgreSQL環境のバックアップを取り、[上流ドキュメント](https://github.com/powa-team/pg_qualstats)で導入要件を確認します。
2. 既存ファイルの置き換え前にPostgreSQLを停止します。対応するZIPに含まれるlib/とshare/extension/以下を、PostgreSQLの同名ディレクトリに配置します。
3. PostgreSQLを起動し、利用するデータベースでCREATE EXTENSION pg_qualstats;を実行します。
4. 統計情報の収集やリセットに必要な設定は、上流ドキュメントを確認してください。 本番環境への導入前に検証環境で動作を確認してください。

ダウンロードしたZIPはReleaseのSHA256SUMS.txtで照合できます。SPDX形式のSBOM、脆弱性レポート、署名付き証明の提供状況はReleaseで確認できます。

## ライセンス

機能、設定、制限事項は上流の説明を参照してください。本配布は上流公式のWindows版ではありません。再配布条件は同梱のライセンス表記に従います。
