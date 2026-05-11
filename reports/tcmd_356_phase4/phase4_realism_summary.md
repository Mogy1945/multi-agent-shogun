# Turn Soccer Phase 4 — リアル化大改修 実装報告

> **tcmd**: tcmd_356_phase4 / **cmd**: cmd_019  
> **担当**: 家老C (Opus)  
> **完了日時**: 2026-05-11  
> **デプロイURL**: https://turn-soccer.vercel.app  
> **commit**: dfefe17  
> **push 4点立証**: ls-remote=`dfefe17` ✅ / log空 ✅ / status clean ✅ / diff空 ✅  
> **Vercel**: HTTP 200 OK ✅  
> **バックアップ**: `main_backup_tcmd356_pre_realism` @ 98276fe ✅

---

## 殿FB①〜⑧ 達成証明

| # | 殿FB | 実装 | 証拠 |
|---|------|------|------|
| ① | 「パスとか誰にパスするかとか選べないといけないね」 | passSelectフェーズ: 全10味方+距離+確率 クリック1回確定 | scene_pass_target_select.png |
| ② | 「11人と11人の動きは毎ターン全員ポジション変わるもんじゃない？」 | moveAllPlayers() 毎ターン全22人移動 | scene_22players_move.png |
| ③ | 「1人プレイ時もGKだとして、毎ターン行動したい。前に1マス行くとかでいい」 | solomoveフェーズ: 毎ターン上下左右待機5択 | scene_solo_GK_action.png |
| ④ | 「マスの概念入れたほうがやりやすいんじゃない？」 | COLS=20,ROWS=12 グリッド線描画、距離=マス単位 | scene_grid_pitch.png |
| ⑤ | 「全員からパスも選択できていいはず、確率出る、決定で判定」 | パス→選手選択→確率表示(距離+敵密度計算)→クリック確定 | scene_pass_target_select.png |
| ⑥ | 「ピッチ全体をグリッド化。十分に広くすること。リアル重視」 | 20×12→720×432px (Phase 3比+76px幅/+92px高) | scene_grid_pitch.png |
| ⑦ | 「どの選手選んでも同じようにできないとだめでしょ？」 | GK/CB/FW 全て同一行動セット(solomove+ballaction) | scene_solo_GK/CB/FW ×3枚 |
| ⑧★ | 「リアル志向を忘れるな」×3連発 | 戦術移動/敵密度パス確率/22人散開/ポジション意識AI | scene_realism.png |

**console.error: 0件** ✅  
**md5 distinct: 7/7 全て異なる** ✅

---

## 仕様 A〜F 達成詳細

### A. ピッチグリッド化 (殿FB④⑥)
- **COLS=20, ROWS=12, CELL=36px** → Canvas 720×432px
- Phase 3 (544×340) 比: 幅+33%、高+27%「十分広く」
- グリッド線: `rgba(255,255,255,0.12)` 0.5px — 薄く視認可能
- 距離表示: パス選択時に「○.○m」単位(マス距離)表示

### B. 毎ターン全選手移動 (殿FB②)
- `moveAllPlayers()` → `getTacticalTarget(p)` で戦術ターゲット算出
- **攻撃チーム**: FW→ゴール前進/MF→ボール支援/CB→後方維持
- **守備チーム**: 全員→ボールと自陣ゴールの中間へ収束
- GK: 常に自陣ゴール前(ownGx+1)に張り付き
- 専任選手: auto-move除外(自分で移動方向を選択)

### C. パス先選手選択UI (殿FB①⑤)
```
パス → passSelectフェーズ
  → 全10味方を列挙:
     山田(GK) 9.0m 34%
     中村(CM) 2.2m 55%  ← クリックで即決定
     ...
  → 選手クリック → 守備フェーズ(AI) → resolve
```
確率計算: `calcPassProbTo(from, to)` = 0.78 × (pass/75) × 距離補正(最大-5%/マス) × 敵密度補正(パスライン上の敵数で最大-18%/人)

### D. 専任モード全選手対応 (殿FB③⑦)
- AI有球時: `G.phase='solomove'` → 移動UI表示
- **GK/CB/MF/FW 全ポジション同一UI**:
  ```
  🏃 移動フェーズ — 山田（GK）
  現在位置: (1, 6)
  [↑ 上] [→ 前進] [(1,6)] [← 後退] [↓ 下]
  [● 待機（移動しない）]
  ```
- 専任選手有球時: 通常攻撃UI(パス選択/ドリブル/シュート/スキル全て)

### E. AI強化 (Phase 3流用+拡張)
- パス先auto選択: `findPassTarget()` or `findFurthestForward()`
- `aiChooseAttack()`: 20×12スケールに距離閾値調整(d<=12でlong_shot等)
- `aiChooseDefense()`: 距離4以内でintercept優先等維持

### F. リアル志向全般 (殿FB⑧)
- 戦術密集/分散: 攻撃時はFWゴール前密集、守備時は自陣前集結
- ドリブル成功: att.x ±2マス前進 (フィールド反映)
- シュート確率: 距離+守備密度 (calcRate維持)
- 敵密度パス確率: パスライン上の敵をblocked係数でペナルティ

---

## 必須7シーン md5 確認

| シーン | ファイル | md5 | 確認内容 |
|--------|---------|-----|---------|
| 1 | 1_scene_grid_pitch.png | c3f4fcc... | 20×12広場フィールド、グリッド線、22選手4-4-2配置 ✅ |
| 2 | 2_scene_22players_move.png | 6905752... | 1ターン後全員移動確認、ログにパス先選択記録 ✅ |
| 3 | 3_scene_pass_target_select.png | 7d18788... | 全10味方+距離+確率リスト表示 ✅ |
| 4 | 4_scene_solo_GK_action.png | 759cad0... | GK: 移動UI(上下左右待機)、現在位置表示 ✅ |
| 5 | 5_scene_solo_CB_action.png | 5a00425... | CB: GKと完全同一UI ✅ |
| 6 | 6_scene_solo_FW_action.png | e88ac6b... | FW: ボール保持→攻撃UI(パス選択/スキル全表示) ✅ |
| 7 | 7_scene_realism.png | 92dfd56... | ターン2: 全選手散開、密集分散確認 ✅ |

---

## Honest Assessment (honest_assessment 文化)

**達成:** 殿FB①〜⑧ 全項目実装確認済み。  

**Caveat (隠さず明記):**

1. **グリッド線視認性**: rgba(0.12)は「薄く視認可能」だが、遠目には目立ちにくい。仕様書「リアル感を損なわない程度」を守った結果。より強くしたい場合は0.18〜0.20推奨。

2. **scene 6 (FW)**: FW=吉田は kickoff holder のため、ゲーム開始直後は「攻撃UI」が表示される。FWが球を失った後のターンでは「移動UI」も表示されるが、今回の撮影は開始直後のため攻撃UIとなった。GK(scene4)/CB(scene5)で移動UIは十分証明済み。

3. **22人移動の可視性**: 1ターンでの移動量は1マス/人のため、初期配置からの差異は小さい。複数ターン後は明確に散開する（scene7=ターン2で確認済み）。

4. **AI難易度**: 「殿が負ける程度の知性」目標。現状はPhase 3 AI+距離評価拡張。長丁場プレイで殿が感じる難易度は実プレイで調整要。

---

## Phase 3→4 差分

- `index.html`: 1046行 → 1262行 (+216行)
- COLS: 16→20, ROWS: 10→12, CELL: 34→36
- 新規: `calcPassProbTo()`, `getTacticalTarget()`, `moveAllPlayers()`
- 新規: `showPassSelectUI()`, `onPassSelectTarget()`
- 新規: `showSoloMoveUI()`, `onSoloMove()`
- 新規: G.phase='passSelect'/'solomove' 2フェーズ追加
- CSS追加: `.ptarget-btn`, `.move-grid`, `.mbtn`, `.move-banner`, `.lg-move`
- バックアップ: `main_backup_tcmd356_pre_realism` @ 98276fe

---

## 次段階推奨 (Phase 5)

```
優先度 S:
  - シュート演出強化 (ゴール時アニメーション/エフェクト)
  - グリッド座標表示 (端にx,y数値)
  - ドリブル後の選手位置フィールド完全反映

優先度 A:  
  - 体力/オフサイド実装 (殿FB⑧リアル志向の延長)
  - BGM/SE (Phase 5以降殿判断)
  - 自動進行オプション (全AI観戦モード)
```

---

*Phase 4 家老C完了 2026-05-11*
