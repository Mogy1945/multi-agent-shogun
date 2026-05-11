# Turn Soccer Phase 3 実装報告

> **tcmd**: tcmd_355_phase3 / **cmd**: cmd_018  
> **担当**: 家老C (Opus)  
> **完了日時**: 2026-05-11  
> **デプロイURL**: https://turn-soccer.vercel.app  
> **commit**: 98276fe  
> **push 4点立証**: ls-remote=`98276fe2` ✅ / log空 ✅ / status clean ✅ / diff空 ✅  
> **Vercel**: HTTP 200 OK ✅

---

## Phase 3 必須3項目 完了状況

| # | 要件 | 状況 | 詳細 |
|---|------|------|------|
| 1 | 1選手専任モード | ✅完了 | 選手選択画面(22選手カード+スキル表示)→専任プレイ・AI自動進行 |
| 2 | 個人スキル | ✅完了 | 5種スキル・専用確率テーブル・紫/橙スキルボタン表示 |
| 3 | AI強化 | ✅完了 | 距離評価+ポジション意識+スキル使用判断・AI思考ログ表示 |

**console.error: 0件** (Playwright実確認済み)

---

## 技術実装詳細

### 1選手専任モード

```
タイトル画面 → 「⭐ 1選手専任モード」クリック
  ↓
選手選択画面 (22選手カード: 名前/ポジション/能力値/スキル表示)
  ↓
専任選手選択 → launchGame('solo', pid)
  ↓
ゲーム画面: 右上「⭐ 専任: [名前]」バッジ (金色)
  専任選手に常時薄金リング
  専任のターン → 「⭐ あなたのターン！」バナー表示
  他選手のターン → autoAITurn() 700ms遅延で自動進行
```

### 個人スキル一覧

| スキル | 対象 | 種別 | 確率 | 特殊効果 |
|--------|------|------|------|---------|
| long_shot | FW | 攻撃 | 32% | 距離補正なし (遠距離シュート) |
| feint | FW, RM | 攻撃 | 62% | 専用DEF_MOD (タックル0.80/スライド0.70/マーク0.88/intercept0.65) |
| through_pass | CM | 攻撃 | 70% | 最前線選手へパス |
| long_kick | GK | 攻撃 | 80% | GK専用ロングキック |
| intercept | CB, RB, LB | 守備 | DEF_MOD 0.52 | 攻撃成功率を大幅低下 |

スキルボタン: 攻撃スキル=紫 (`.cbtn.skill`)、intercept=橙 (`.cbtn.skill-def`)

### AI強化ロジック

**aiChooseAttack(player)**:
- スキル優先判断 (long_shot: d≤10で38%確率選択、through_pass: d>4で30%、feint: d≤6で32%、long_kick: d>8)
- 距離評価: d≤2→65%シュート、d≤5かつFW→40%シュート、遠距離→80%パス

**aiChooseDefense(atkAct, attacker)**:
- interceptスキル保有者(CB/RB/LB)がdist≤3→55%でintercept使用
- shoot/long_shot対→55%tackle
- 近距離(dist≤2)→aggressive(50%tackle/22%slide/28%mark)
- 遠距離→70%mark

**autoAITurn()**:
- AI_DELAY=700ms の段階的遅延表示
- 「🤖 AI思考中...」表示 → 攻撃選択ログ → 守備自動選択
- ログに「🤖 [名前](AI): [アクション]を選択」表示

### Phase 2 からの差分

- `index.html`: 568行 → 1046行 (+478行、Phase 3追加)
- 新規: 選手選択画面 (select-screen)
- 新規: P()コンストラクタにskillsフィールド追加
- 新規: BASE/DEF_MOD/FEINT_DEF スキル確率テーブル
- 新規: aiChooseAttack() / aiChooseDefense() / autoAITurn()
- 新規: showSelectScreen() / buildSelectScreen() / selectSoloPlayer()
- 強化: initState(mode, soloPlayerPid) でモード対応
- 強化: updateChoices() でスキルボタン/専任バナー追加
- 強化: nextTurn() でAI自動進行分岐
- 強化: render() で専任選手リング/バッジ表示
- CSS追加: .pcard/.player-grid/.team-block/.your-turn-banner/.ai-banner/.cbtn.skill/.cbtn.skill-def/.mode-badge

---

## 視覚確認 (feedback_visual_verify_strict 準拠)

Read tool で以下画像を開いて目視確認済み:

| ファイル | 確認内容 | 結果 |
|---------|---------|------|
| `01_title.png` | タイトル画面 3ボタン (v0.3.0) | ✅ 11v11(緑)・専任(金)・操作説明(灰) |
| `02_select_screen.png` | 選手選択画面 22選手カード | ✅ HOME/AWAY各11枚・スキル表示・能力値表示 |
| `03_solo_game_start.png` | 専任モード開始 山田(GK) | ✅ 「⭐ 専任: 山田」バッジ・山田に金リング・ログ表示 |
| `04_solo_in_progress.png` | AI自動進行中 | ✅ 「🤖 AI思考中...」表示・AI選択ログ |
| `06_11v11_start.png` | 11v11 スキルボタン表示 | ✅ 吉田: ロングシュート★(紫)/フェイント★(紫) |
| `07_11v11_defense_phase.png` | 守備フェーズ | ✅ タックル/スライディング/マーク 正常 |
| `08_after_turn.png` | ターン後 | ✅ ✅吉田→木村 パス成功・統計更新・木村スキルボタン表示 |

---

## 次段階推奨 (Phase 4)

**tcmd_356 想定スコープ**:

```
優先度 S:
  - シュート演出強化 (ゴール時アニメーション/エフェクト)
  - ドリブル後の選手位置フィールド反映 (現在はグローバル状態のみ更新)

優先度 A:
  - ターンスキップ/自動進行オプション (全AI進行モード)
  - 対戦成績記録 (localStorage)
  - BGM/SE (Phase 4以降推奨)
```

**推奨足軽配分**: C1(演出) + C2(ドリブル位置更新) + C3(自動進行) の3体並列

---

*Phase 3 家老C完了 2026-05-11*
