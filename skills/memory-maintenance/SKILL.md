# memory-maintenance — 週次メモリ整理ハーネス

## 目的
AGENTS.md Memory 節の蓄積規約（L0 索引は薄く・索引と実体の一致・daily の蒸留・剪定）を**自動で定着させる**。検知 → 整理の実行 → git コミット → 報告までを週次で回す。ワークスペースが git 管理下なら、**整理まで自動実行してよい**（巻き戻せるため）。

## トリガー
- cron ジョブ「weekly-memory-maintenance」（例: 月曜 8:30, isolated セッション）
- 手動で「メモリ整理して」と言われたときもこの手順に従う

## 手順

1. **機械チェック**
   `bash skills/memory-maintenance/check.sh`
   出力: (a) 索引カバレッジ (b) 死にポインタ (c) 肥大・daily 滞留 (d) git 状態。読み取り専用・副作用なし。

2. **pre スナップショットコミット**
   整理に入る前に、未コミット差分があれば丸ごとコミットして巻き戻し点を作る:
   `git -C ~/openclaw-workspace add -A && git -C ~/openclaw-workspace commit -m "chore(memory): pre-maintenance snapshot"`
   （差分ゼロなら skip。これで整理による変更が独立した diff になる）

3. **整理を実行**（下の「自動でやってよいこと / だめなこと」に従う）
   - **索引再同期**: (a) で欠落/更新漏れがあれば索引の差分再同期を実行（FTS-only・非破壊）。
   - **死にポインタ修正**: 参照先を実在パスに直す。参照先自体が消えて久しいなら参照行ごと削除。
   - **daily ログの蒸留**: 14 日超の `memory/YYYY-MM-DD.md` を読み、未来のセッションに必要な durable な事実・決定だけを適切なトピックファイル（なければ新設）へ昇格し、`MEMORY.md` の索引行を更新する。**daily ファイル自体は消さない**（raw ログとして memory search で辿れる資産）。蒸留済みの daily には先頭に `<!-- distilled: YYYY-MM-DD -->` を 1 行入れて二重処理を防ぐ。
   - **MEMORY.md の剪定**: 100 行/3KB 超なら詳細をトピックファイルへ切り出す。陳腐化した行は新事実で上書きし、矛盾を残さない。「この行を消したらミスするか？」が No の行は削除。
   - **肥大トピックの分割**: 200 行超のトピックファイルは、見出し単位で別ファイルへ切り出すか剪定。ただし **`memory/users/` 配下は対象外**（下記）。

4. **post コミット**
   `git -C ~/openclaw-workspace add -A && git -C ~/openclaw-workspace commit -m "chore(memory): weekly maintenance — <やったことの要約>"`
   変更がなければ skip。

5. **報告**
   送信先: cron の delivery チャンネルにそのまま出力される前提で最終メッセージを書く。含めるもの:
   - 検知事項の要約（死にポインタ N 件、蒸留した daily N 件、など）
   - 実施した整理の内容（`git diff --stat HEAD~1` 相当の要約でよい。ファイル全文は貼らない）
   - 見送った項目と理由（人間判断が要るもの）
   - 問題なしの週は「異常なし」と 1〜2 行で。**質 > 量**、マークダウンテーブル禁止・箇条書きで。

## 自動でやってよいこと / だめなこと

**OK（git で巻き戻せる範囲の整理）:**
- `MEMORY.md` と `memory/*.md`（トピックファイル）の編集・新設・索引行の更新
- daily ログからトピックへの蒸留（コピー + distilled マーク付与）
- 索引の差分再同期

**NG（自動実行禁止・提案どまり）:**
- **ファイル削除**（daily ログ含む。剪定は「行の削除・上書き」まで）
- **`memory/users/` 配下の書き換え**（*.jsonl / *.json / *.md 等は hooks・scripts が読み書きするデータ。パス契約があるので触らない）
- **`memory/hooks/` の書き換え**（ワークフロー定義。メモリではない）
- 索引 DB の直接操作・VACUUM・force reindex
- git の履歴操作（reset / rebase / push）。コミット追加のみ可

判断に迷うもの（例: このトピックはもう不要では？大きなリストラクチャ）は実行せず、報告に「提案」として載せてオーナーの指示を待つ。

## 設計意図
- check.sh は LLM 不要・読み取り専用の検査部。**判断と編集だけを LLM が担う**分業。
- pre/post の 2 コミット構成で、「整理でどう変わったか」が単独の diff として残り、`git revert` 一発で巻き戻せる。
- daily を消さないのは、raw ログが memory search の検索資産であり、蒸留の failure（拾い漏れ）の保険になるため。
