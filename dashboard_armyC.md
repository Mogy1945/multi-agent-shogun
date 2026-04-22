# 軍C ダッシュボード

> **更新者**: 家老C（karoC）
> **最終更新**: 2026-04-22
> **歴史**: tcmd_233 (2026-04-22) で旧忍衆 (shinobicho/hanzo/sasuke/kotaro) から軍C (shogunC/karoC/ashigaruC{1..8}) に統合。以下の scmd / 自律改善ログは旧忍衆時代の歴史記録として温存。

## 🚨 要対応

- **小説『僕が消える前に』完成** — 全8章・約41,300字。殿レビュー待ち。成果物: `reports/novel_boku_ga_kieru_mae_ni.md`
- **#7正統王室軍 全ファイル完了** — UTF-16LE変換・dev_copyへの書き込み待ち

## 📊 完了済みscmd一覧

- scmd_019/020: v2移行検証 — CRITICAL不整合なし
- scmd_021: v4.0総括レポート — reports/v4_reform_summary.md
- scmd_022: 残課題消化+次世代調査 — SubAgent設計調査（パターンA推奨）
- scmd_023: SubAgent PoC Go判定+ツール強化 — 4/4成功、PreCompact hook実装、health_check.sh強化
- scmd_024: SubAgent Phase1実装 — shinobicho.md改修、shutsujin 22ペイン化、precompact_all.sh実装
- scmd_025: SubAgent Phase2実運用テスト — 通信ロスト0件、全体3分半（60%短縮）
- scmd_026: CRITICAL修正検証+残課題消化 — 半蔵:CRITICAL2件+HIGH2件全PASS、佐助:L修正不要確認+M修正済み、小太郎:v4_reform_summary_v2.md出力
- scmd_027: v4最終仕上げ+足軽SubAgent化調査 — summary最新化、スクリプト修正3件PASS、ashigaru_subagent_feasibility.md策定
- scmd_028: ダッシュボード整理+scripts全テスト+instructions品質検査 — 要対応11→2項目圧縮、scripts 16/16構文PASS・13/16実行PASS、instructions CRITICAL0件(HIGH1/MEDIUM2/LOW2)
- scmd_029: 品質検査指摘修正+v4最終総括 — HIGH1件+MEDIUM2件+LOW2件全修正、v4_reform_summary_v2.md最終更新(全課題対処完了、殿判断待ち2件+LOW将来改善2件のみ残存)
- scmd_030: 足軽SubAgent化Phase2レビュー — 半蔵:CLAUDE.md+shutsujin整合性OK(修正不要)、佐助:テンプレートレビュー(note/notes不一致等3件検出)、小太郎:karo.mdレビュー合格(重大問題なし)
- scmd_031: テンプレート修正+移行記録+v5ロードマップ — 半蔵:note→notes修正(ashigaru.md同期は要判断)、佐助:ashigaru_subagent_migration.md作成(Phase0-2記録+教訓整理)、小太郎:v5_roadmap_draft.md策定(動的スケーリングP1,将軍SubAgent化は段階的,全体13-18セッション)
- scmd_032: Phase2結果反映+整合性確認+全体サマリ — 半蔵:migration記録Phase2追記(B1-B8全成功75秒,ペイン25→6変遷表)、佐助:config/scripts4ファイル整合性OK(4パターン全正常)、小太郎:overnight_session_summary.md作成(11scmd+17tcmd+殿判断待ち6件)
- scmd_033: Phase3結果反映+reports整理+summary最終化 — 半蔵:migration記録Phase3追記(実戦運用可能ステータス到達)、佐助:reports/index.md作成(全103ファイル7カテゴリ分類)、小太郎:overnight_summary最終版(scmd12+tcmd19+殿判断待ち更新)
- scmd_034: Memory MCP→Auto Memory移行 — 半蔵:4エンティティをAuto Memory形式で保存(user1+feedback3)+MEMORY.md更新、佐助:instructions/6ファイルのMCP参照書き換え(旧参照残存なし確認済)、小太郎:CLAUDE.md6箇所修正(四層モデル・セッション開始・/clear復帰等)+config確認(MCP設定なし)
- scmd_035: 将軍システムAGI化調査+忍衆提言 — 半蔵:self-evolving agent10件調査(DGM,HyperAgents,SAGE等)+優先度ABC提案、佐助:Claude Code公式25+機能網羅(活用2/25+,カスタムSubAgent・SessionStartフック等11提言)、小太郎:AGI定義+LLM根本限界(MECW,ハルシネーション数学的不可避)+成長戦略4方針。統合レポート:reports/agi_review_shinobi.md
- scmd_036: 完全自律運用v5.0 instructions改修 — 半蔵:base.md§12「完全自律運用方針」追加(自律改善権限・安全弁・権限ルール・上様お伺い5項)、佐助:shinobicho.md自律改善責任セクション+shinobi.md prediction/observation+品質保証追加、小太郎:autonomous_improvement_log.mdテンプレート新設+dashboard自律改善ログセクション+初回3件記入
- scmd_037: shogun-web Phase 1 削除範囲調査 — 半蔵:HTML/ナビ構造精査(残5+城下町/削除5+command)、佐助:JS関数依存調査(topPage保全境界特定)、小太郎:バックエンド routes 18ファイル調査。殿方針最終化「keep側一切触らず・delete側のみ削除」
- scmd_038: shogun-web Phase 2 削除実行+初回コミット — 半蔵:HTML削除 3898→3209(−689行)・城下町タブ追加・_restoreFromHash整理、佐助:JS関数4つ削除(armyPage/shinobiPage/commandPage/projectsPage)+yaml-viewer.js物理削除 3209→2813、小太郎:静的検証全PASS→git管理外BLOCKED→殿判断「いい感じでよろ」→忍頭が案B採用(git init + 初回commit d28f15c)。最終 index.html 3898→2813(−1085行、−27.8%)
- scmd_001: camp-schedule-app 3点改修 — 半蔵:dungeon動線遮断(index.html+main.js)、佐助:ver0.4+news.json更新履歴追加、小太郎:pendingBattle残骸バグ修正(turn.js最小パッチ)。PR#7 merged→Vercel自動デプロイ

## 📋 Phase3 設計完了（11文書）

> 詳細アーカイブ参照: dashboard_shinobi_archive.md

## 🔄 自律改善ログ（最新5件）

> 全ログ: templates/autonomous_improvement_log.md 参照

| 日付 | ID | 実行者 | 対象 | 種別 | 結果 |
|------|-----|--------|------|------|------|
| 2026-04-07 | IMP-001 | 半蔵 | base.md | instructions改修 | PASS |
| 2026-04-07 | IMP-002 | 佐助 | shinobicho.md, shinobi.md | instructions改修 | PASS |
| 2026-04-07 | IMP-003 | 小太郎 | autonomous_improvement_log.md | テンプレート更新 | PASS |
| 2026-04-15 | IMP-004 | 忍頭 | instructions/shinobi.md | kaizen追記(Phase1でgit管理状態確認を必須化+後ろから削除戦略) | PASS |
| 2026-04-15 | IMP-005 | 忍頭 | /home/hatan/shogun-web/.git | git init + 初回commit d28f15c (scmd_038 BLOCKED解消、案B採用) | PASS |

## 📊 統計

- 完了任務数: 161（旧忍衆時代）
- 現在稼働: 0/8（軍C 足軽待機中）
- 軍C 足軽生存: ashigaruC1-C8（SubAgent方式、家老Cが必要時に起動）
- 詳細アーカイブ: dashboard_shinobi_archive.md（歴史資産）
