# Turn Soccer Phase 1 完了報告

> **tcmd**: tcmd_353  
> **cmd**: cmd_016  
> **担当**: 家老C  
> **完了日時**: 2026-05-11

---

## 成果物一覧

| 成果物 | パス / URL | 状態 |
|--------|-----------|------|
| GitHub リポ | https://github.com/Mogy1945/turn-soccer | ✅ private, main ブランチ |
| Vercel デプロイ URL | **https://turn-soccer.vercel.app** | ✅ READY |
| 企画書 | `/home/shuirein928/turn-soccer/DESIGN.md` | ✅ 11セクション完成 |
| HTML 雛形 | `/home/shuirein928/turn-soccer/index.html` | ✅ タイトル画面のみ |
| README | `/home/shuirein928/turn-soccer/README.md` | ✅ デプロイURL記載 |
| 初期 commit | `c9953d0` | ✅ push 4点立証済 |

---

## GitHub / Vercel 構成

- **リポ**: `Mogy1945/turn-soccer` (private)
- **Vercel プロジェクト**: `mogy1945s-projects/turn-soccer`
- **GitHub 連動**: ✅ main ブランチ push → 自動デプロイ設定済
- **push 4点立証**:
  - `ls-remote` = `c9953d0f` ✅
  - `git log origin/main..HEAD` 空 ✅
  - `git status` clean ✅
  - `git diff origin/main..HEAD` 空 ✅

---

## DESIGN.md 企画書概要（11セクション）

### 1. ゲーム概要
キャプテン翼 GB 方式のターン制選択肢サッカーゲーム。ボール保持選手ごとに「パス/ドリブル/シュート」を選択し、能力値 × 確率で成否判定。

### 2. ターン制ゲームループ
1 ハーフ = 45 ターン（前後半計 90 ターン）。攻撃→選択→確率判定→ボール移動→次ターンのサイクル。攻守切替は失敗判定またはタックル成功で発生。

### 3. 選択肢一覧
- **攻撃（汎用）**: パス(70〜90%) / ドリブル(40〜65%) / シュート(10〜50%) / クリア / キープ
- **個人専用**: スーパーシュート(FW)、スルーパス(テクニシャン)等、能力値しきい値で解放
- **守備（汎用）**: タックル / スライディング / マーク / プレッシャー

### 4. 確率テーブル
`最終成功率 = 基本成功率 × (攻撃能力 / 守備能力) × 状況補正 × ランダム係数`  
選手は 6 能力値 (shoot/pass/dribble/defense/physical/speed 各 1〜100)。

### 5. モード
- **11vs11 全選手操作**: 毎ターン自分で選択、戦術派向け
- **1選手専任**: 他 20 人は AI、主人公視点（段階 3 実装）

### 6. 画面レイアウト（ASCII モック付き）
```
┌─────────────┬─────────────────┐
│ 左: フィールド│ 右上: スタッツ    │
│ ミニマップ    │ ポゼッション/シュート│
│ (全選手+ボール)├─────────────────┤
│              │ 右下: 選択肢     │
│              │ 最大5ボタン      │
└─────────────┴─────────────────┘
```

### 7. AI 仕様
シンプルルールベース。ゴール前→70%シュート、中盤→パス優先、守備→隣接時タックル。段階 3 で強化予定。

### 8. データ構造
GameState (phase/turn/score/possession/ball/activePlayer) + Player (id/name/position/stats/skills/stamina) + Action (condition/baseSuccessRate/statModifier/onSuccess/onFail)。

### 9. 技術選定
**Vanilla JS + 単一 HTML 採択**（Mini Gather 同流儀、ビルドなし、殿「足すより削る」哲学、Vercel 静的デプロイ最小コスト）。

### 10. 段階ロードマップ

| 段階 | tcmd | 内容 |
|------|------|------|
| **Phase 1** ✅ | tcmd_353 | 企画+雛形+デプロイ |
| **Phase 2** | tcmd_354 想定 | MVP: ターン進行+選択肢+確率判定(11vs11 簡易) |
| **Phase 3** | 未定 | AI 強化+1選手専任+専用スキル |
| **Phase 4** | 未定 | BGM/SE+チーム編成+セーブ |

### 11. 完全無料運用
Vercel Hobby + GitHub private + Vanilla JS（依存ゼロ）。将来スコアランキング追加時は Firestore Spark 枠で対応可。

---

## 次段階推奨（Phase 2 仕様提案）

**tcmd_354 で実装すべき MVP 最小スコープ**:

```
優先度 S:
  - 22 選手の初期配置データ（JSON）
  - ターン進行ループ（45 ターン × 2 ハーフ）
  - 汎用選択肢 5 種（パス/ドリブル/シュート/キープ/クリア）
  - 確率判定ロジック（乱数 × shoot/pass/dribble 能力値）
  - フィールドグリッド描画（DOM or Canvas、選手位置表示）
  - スコア / 時間 表示
  - 勝敗判定 + 試合終了画面

優先度 A（Phase 2 後半）:
  - 守備選択肢（タックル/マーク）
  - ターンログ（何が起きたか 1 行表示）
  - AWAY チーム簡易 AI
```

**Phase 2 での家老C 推奨運用**: 足軽 C1（選手データ+確率ロジック）+ 足軽 C2（UI+描画） 2体並列→家老C 統合。推定 2〜3 時間。

---

## 備考

- Vercel CLI が `.vercel/` を自動作成し `.gitignore` に追加済み（.gitignore 最終行追記のみ）
- `vercel --prod --yes` 実行時に GitHub 連動が自動設定された（`--source` 不要）
- Vercel project name: `mogy1945s-projects/turn-soccer`（Vercel 側でのスコープ名）
