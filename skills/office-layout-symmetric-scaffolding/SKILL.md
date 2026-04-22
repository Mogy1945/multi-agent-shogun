---
name: office-layout-symmetric-scaffolding
description: shogun-web 系ダッシュボードに新しい軍を追加する際の N 軍対称化テンプレ。officeLayout/routes/services/websocket/css/UI/data の9セクション差分を機械的に適用。「新しい軍を追加して」「N軍目のダッシュボード対応」「軍X化」等の指示時に使用。
category: scaffolding
army_scope: all
reference_implementation: "commit f59b80b (tcmd_236 cmd_B030, 33 files +1556/-1865)"
kz_140_streak_demonstrated: 9
---

# Office Layout Symmetric Scaffolding - N軍対称化スキル

## Overview

shogun-web（multi-agent-shogun のダッシュボードフロントエンド）に**新しい軍（armyC / armyD / …）を追加する際の 9 セクション差分を機械的に適用する**テンプレートスキル。

軍団構造が対称であることを前提に、既存軍（armyA / armyB）の記述パターンを grep で抽出 → 新軍（armyX）へ対称コピー → 色・配置等の自律判断ポイントだけ選定、という一貫フローを提供する。

### なぜ必要か

shogun-web は 9 種類のレイヤ（データ / JS / routes / services / websocket / CSS / 公開データ / HTML / docs）に軍情報が散在している。
新軍を追加する際、いずれか1層を忘れると「組織図は3軍だが Chat tabs は2軍」「routes は通るが CSS カラーが無くて透明」等の非対称バグが発生する。
本スキルは 9 セクション（S1–S9）を **チェックリストとして網羅**し、漏れを防ぐ。

### 実績

- **commit f59b80b（tcmd_236 cmd_B030）**: 2軍→3軍化（armyC 追加）を 33 files / +1556 / -1865 で完遂。4層検証全PASS、KZ-140 9連続コミット達成。

## When to Use

- 「新しい軍を追加して」「armyD / armyE / 軍X化」等の指示を受けたとき
- shogun-web の組織図に軍を増やしたい、または対称性を回復したいとき
- 既存軍の色・配置・conversations データを新軍へ複製したいとき
- N軍拡張時に「どこを触ればよいか分からない」状態を 9 セクションに落とし込みたいとき

## Skip when

- shogun-web 以外のプロジェクト（例: camp-schedule-app）には適用しない
- 軍の削除・merge（例: shinobi → armyC 統合）は別タスク（merge 系スキル）で対処
- 既存軍の色変更のみ等、scaffolding が不要な局所改修

---

## 9 Section 差分テンプレ（S1–S9）

各セクションは「対象ファイル → 抽出 grep → 新軍対称コピー要点」の3点セット。
既存軍 armyA / armyB / armyC の定義を必ず grep で抽出してから armyX を対称化すること。

### S1. データ層: `src/data/officeLayout.js`

**対象**: 軍の 10 キャラ（shogun{X} / karo{X} / ashigaru{X}1–8）を officeLayout に追加

**grep 抽出**:
```bash
grep -n "armyC\|shogunC\|karoC\|ashigaruC" src/data/officeLayout.js
```

**対称コピー要点**:
- 各キャラに `army: 'armyX'` / `initialRoom: <roomId>` / `sprite: <path>` を設定
- initialRoom は「1室集約」「軍別3室対称」等を選定（自律判断ポイント①）
- sprite は既存軍の命名規則に従う（`sprites/shogunX.png` 等）

### S2. public/js 層: `public/js/office-*.js` 7 ファイル

**対象**: `office-main.js / office-sprites.js / office-menu.js / office-life.js / office-state.js / office-conversations.js / office-events.js`

**grep 抽出**:
```bash
grep -rn "armyC\|shogunC\|karoC\|ashigaruC" public/js/office-*.js
```

**対称コピー要点**:
- 軍別 filter / グルーピング / スプライト読み込みに armyX ケースを追加
- 旧シノビ（shinobi/hanzo/sasuke/kotaro）系は既に消えている前提で、残存があれば clean-up
- `office-config.js` / `office-keyboard.js` は通常 N軍拡張では無変更（f59b80b 実績より）

### S3. routes 層: `src/routes/{agents,alert,shogun,status,tasks,pane,npc}.js` 7 ファイル

**対象**: 許可 army リスト / ARMY_TO_SHOGUN マップ / NPC army 参照

**grep 抽出**:
```bash
grep -rn "armyA\|armyB\|armyC" src/routes/
grep -rn "ARMY_TO_SHOGUN\|allowedArmies" src/routes/
```

**対称コピー要点**:
- allowed army リスト: `['armyA', 'armyB', 'armyC', 'armyX']` に拡張
- ARMY_TO_SHOGUN マップ: `{ armyA: 'shogunA', ..., armyX: 'shogunX' }`
- `npc.js` は officeLayout 読み込み後に自動認識されるが、army list filter があれば追記

### S4. services 層: `src/services/{agentPoller,fileWatcher,taishogunStream}.js`

**対象**: WATCH_TARGETS / poll 対象 / 正規表現フィルタ

**grep 抽出**:
```bash
grep -rn "WATCH_TARGETS\|armyA\|armyB\|armyC" src/services/
```

**対称コピー要点**:
- `fileWatcher.js` の WATCH_TARGETS に以下 6 件を追加:
  - `queue/armyX/shogun_to_karo.yaml`
  - `queue/armyX/tasks/`
  - `queue/armyX/reports/`
  - `queue/armyX/archive/commands.yaml`
  - `queue/armyX/kaizen.yaml`
  - `dashboard_armyX.md`
- `agentPoller.js` / `taishogunStream.js` の army 正規表現を `(armyA|armyB|armyC|armyX)` に拡張

### S5. websocket 層: `src/websocket/broadcaster.js`

**対象**: 軍別配信チャンネル

**grep 抽出**:
```bash
grep -n "shogunA_pane_update\|shogunC_pane_update" src/websocket/broadcaster.js
```

**対称コピー要点**:
- `shogunX_pane_update` チャンネル追加
- `karoX_pane_update` / `ashigaruX{1..8}_pane_update` は命名規則に従い自動展開

### S6. public/data 層: `public/data/{conversations,relationships}.json` + backup

**対象**: 軍X10キャラの conversations / relationships エントリ

**grep 抽出**:
```bash
grep -n "armyC\|shogunC" public/data/conversations.json
```

**対称コピー要点**:
- **Option A**: 既存データを全削除してクリーン起動（データ損失リスク）
- **Option B（推奨）**: 削除前に `conversations_pre_armyX_backup.json` / `relationships_pre_armyX_backup.json` を作成してから追加（f59b80b 実績）
- 自律判断ポイント②: データ削除方針

### S7. CSS 層: `public/css/dashboard.css`

**対象**: 軍カラートークン

**grep 抽出**:
```bash
grep -n "\-\-army-a\|\-\-army-b\|\-\-army-c" public/css/dashboard.css
```

**対称コピー要点**:
- `--army-x-base` / `--army-x-bright` を追加
- 既存軍の色相（A=青系 / B=赤系 / C=緑系）から空いた色相を選定（自律判断ポイント③）
- Army card border / Chat tab active / Kanban 軍別ボタンに反映

### S8. UI 層: `public/index.html`

**対象**: 組織図 / Army cards / Chat tabs / Kanban

**grep 抽出**:
```bash
grep -n "armyBlockW\|totalW\|armyC" public/index.html
```

**対称コピー要点**:
- 組織図 SVG: `totalW = armyBlockW * N + 90`（N = 軍数）
- Army cards grid: N 列対称配置
- Chat tabs: `N + 1` 件（大将軍 + N 将軍）
- Kanban: 軍X ボタン追加、kanban-column 軍別グルーピング

### S9. docs 層: `proposals/armyX_*.md`（任意）

**対象**: 後続提案・軍X固有の配置詳細等

**grep 抽出**:
```bash
ls proposals/ | grep -i army
```

**対称コピー要点**:
- 軍X B1 階 3室対称分割等の後続提案があれば `proposals/armyX_<topic>.md` に起票
- f59b80b では `proposals/armyc_b1_three_rooms_proposal.md` を添付

---

## 4 層検証チェックリスト

以下 4 層すべて PASS で完了とする。1つでも FAIL なら戻り修正。

- [ ] **L1 ビルド**: `cd /home/hatan/shogun-web && npm run build` 成功（0 error）
- [ ] **L2 Playwright 目視**: 以下 4 点を MCP で確認
  - 組織図 N 軍対称（totalW / 軍ブロック幅が正しい）
  - Army cards N 列表示
  - Chat tabs N+1 件（大将軍 + 全将軍）
  - office 配置でキャラが正しい部屋に出現
- [ ] **L3 残存ゼロ**: 旧軍（該当すれば shinobi / hanzo / sasuke / kotaro）参照が消滅（backup ファイル除外）
  ```bash
  grep -rn "shinobi\|hanzo\|sasuke\|kotaro" shogun-web/src shogun-web/public/js shogun-web/public/index.html \
    --exclude="*_pre_*_backup.json" | grep -v node_modules
  ```
- [ ] **L4 本体無変更**: `/home/hatan/multi-agent-shogun/` は本 scaffolding タスクで**触らない**（`git status` で未追跡変更ゼロを確認）

---

## 自律判断ポイント

本スキル適用時、以下 3 点は足軽が自律判断せよ（殿伺い不要）:

1. **カラーテーマ選定**
   - 既存軍の色相を grep で把握 → 空いた色相から補色・類似色で選定
   - 実績: A=青 / B=赤 / C=緑 → 次候補は紫・橙・黄・青緑等

2. **initialRoom 配置方針**
   - 「1室集約」or「B1 階 3 室対称分割」を選定
   - 3室分割なら `proposals/armyX_<N>_rooms_proposal.md` で後続提案化

3. **conversations.json 削除方針**
   - Option A: 全削除（データ損失リスクあり）
   - **Option B: `_pre_armyX_backup.json` を先に作成してから追加（推奨、f59b80b 踏襲）**

---

## 参照実装

**commit**: `f59b80b` — `feat: 軍C化対応 — 3軍対称ダッシュボード (tcmd_236)`

**規模**: 33 files changed / +1556 / -1865

**実施タスク**: `tcmd_236 cmd_B030`（ashigaruB1, armyc-migration branch, 2026-04-22）

**主要変更**:
- `src/data/officeLayout.js`: 227 行変更（shogun/karo/ashigaruC1-8 追加）
- `public/index.html`: 230 行変更（組織図 2→3 軍対称化、Chat tabs 2→3）
- `public/js/office-*.js` 7 ファイル: スプライト・life・menu・main・sprites・state 軍C対応
- `src/routes/*` 7 ファイル: allowed army 拡張、ARMY_TO_SHOGUN マップ armyC 登録
- `src/services/*` 3 ファイル: WATCH_TARGETS queue/armyC/ 6件追加、正規表現拡張
- `public/data/conversations.json` / `relationships.json`: 軍C10キャラエントリ追加 + `_pre_armyC_backup.json` 2 ファイル温存（Option B）
- `proposals/armyc_b1_three_rooms_proposal.md` 新規（後続提案）
- `dist/assets/` rebuild（index-DJEzryaw.css / office-Ccd1uMss.js / webworkerAll-CXu0YtSO.js / browserAll-D0We-ADQ.js）

**KZ-140 実績**: 9 連続コミット達成（具体ファイル名 staging のみ、`git add -A` / `git add .` 不使用）

本スキル適用時は、このコミットを `git show f59b80b --stat` で確認し、差分パターンを踏襲せよ。

---

## KZ-140 準拠（必須遵守）

本スキルで生成したファイル群を staging する際:

- `git add -A` / `git add .` **絶対禁止**
- 具体ファイル名のみで staging
- shogun-web 側と multi-agent-shogun 側でリポジトリを分けて別々に commit
- backup ファイル（`_pre_armyX_backup.json`）は意図的 staging の対象、除外しない

---

## 参考

- 元ネタ commit: `f59b80b`（shogun-web リポジトリ）
- 先行タスク: `tcmd_236 cmd_B030`（ashigaruB1 実施、armyc-migration branch）
- 殿裁可: 2026-04-22 ①ローカル運用継続 ②本番すぐ反映 ③ skill 起票
- 本スキル起票タスク: `tcmd_239 cmd_B031`（ashigaruB1）

---

## Appendix B: Dev → Prod 切替手順 (将来用)

**前提**: shogun-web は Vite dev mode (`node server.js` → middleware が public/ を動的変換) で稼働中。
dist/ は `npm run build` で生成済だが未配信。将来 prod 配信へ切替える際の手順を以下に記す。

### B.1 現状

- dev mode: public/* を middleware が on-the-fly 変換、hashed asset (office-Ccd1uMss.js 等) は 404
- prod mode: dist/* の hashed asset を静的配信、immutable キャッシュ可能
- server.js の分岐: L133-136 が production (`express.static('dist')` + `sendFile('dist/index.html')`), L140-152 が dev (`vite.middlewares` + `root: 'public'`)。現行は dev 分岐で起動

### B.2 切替判断基準

- 殿画面の体感速度が dev mode で不足してきたら prod へ
- CDN 化 / 複数端末配信 / キャッシュヘッダ制御が必要になったら prod へ
- ビルドサイクル (src 変更→build→再起動) を許容できる運用体制が整ったら prod へ
- dev 特有のエラー ("ERROR: shogunC not found" 等の monitor 系) が実害を及ぼすようになったら prod へ

### B.3 切替手順

1. server.js を確認し、Vite middleware mode を dist 静的配信モードへ切替
   - 典型: `app.use(express.static('dist'))` + SPA fallback (`app.get('*', (req, res) => res.sendFile(path.resolve('dist/index.html')))`)
   - Vite の場合: `vite preview` を使うか、production build を Express で serve
   - 起動フラグ (`NODE_ENV=production node server.js` 等) で分岐できるよう引数/ENV 整備
2. 切替前に `npm run build` を確実に実行 (dist の hash が src と一致していること)
3. プロセス再起動: cmd_B032 と同手順 (kill → nohup で起動 → curl 疎通)
4. `curl -sS http://localhost:3000/ | grep -oE "office-[A-Za-z0-9]+\.js"` で新 hashed asset が配信されているか確認
5. 殿へ切替完了 send-keys + リロード依頼

### B.4 切替後のリスク

- src 変更のたびに rebuild + 再起動が必要 (dev mode のホットリロード失う)
- WebSocket 稼働中は数秒ダウンタイムあり (殿承認前提)
- dist の git 管理方針を決定要 (commit する or gitignore)
- build ログが本番復旧のクリティカルパスになる (失敗時即 rollback 手順整備要)

### B.5 tcmd_239 時点の裁可 (2026-04-22)

- A案 (dev 継続) 採択。B案は将来の選択肢として保留。
- cmd_B031 で merge HEAD=66eeda2 / build 成果物生成済、cmd_B032 で再起動済、cmd_B033 で本 Appendix を追記。
- 大将軍裁可: 殿『数秒ダウンタイム許容・リロードだけでOK』裁可と public/ 即反映により、dev mode でも体感上 prod 相当の運用が成立することを確認。
