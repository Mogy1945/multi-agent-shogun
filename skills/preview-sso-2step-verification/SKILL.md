---
name: preview-sso-2step-verification
description: Vercel SSO Deployment Protection 等で preview URL が 401 となり Playwright MCP 検証不能なケースの代替フロー。feature ブランチをローカル `python3 -m http.server` 並走で機能検証 → main merge → 本番 URL の curl キーワード grep + Playwright MCP 再検証の **2段検証** を定型化するスキル。SSO 保護下でも「preview をスキップして prod 直行」を安全に走らせる
---

# Preview SSO 2-Step Verification - SSO保護下の本番反映前検証スキル

## Overview

Vercel / Netlify / Cloudflare Pages 等の preview デプロイは、企業/個人 plan の **Deployment Protection** (SSO / Password / Vercel Authentication) を有効化すると外部からは 401 になる。Playwright MCP には SSO ログイン手段がないため、preview URL での自動検証フローが**そのままでは破綻する**。

本スキルは、preview を**スキップして本番に直行する**代替フローを定型化する。具体的には:

1. **feature ブランチ段階**で `python3 -m http.server <port>` を並走させ、ローカル静的サーバ上で Playwright MCP 検証を完結
2. PR 作成・マージ (preview の SSO 401 は無視してよい)
3. main merge 後の **Vercel 本番 deploy** を待機
4. 本番 URL に `curl` でキーワード grep (変更ファイル/関数名/CSS変数 が配信中か)
5. 本番 URL に Playwright MCP で navigate → 重要機能 1-2 項目 + console errors 0 を確認
6. 両方 OK なら完遂報告 + (UI 改変なら) 殿体感確認依頼フラグ

camp-schedule-app では cmd_232 (editorial-redesign) / cmd_235 (star-pulse) / cmd_237 (organic-star) / cmd_238 (sun-mode) / cmd_240 (color-only) / cmd_243 (battle-skill-grant) で計6タスク採用、SSO 保護プロジェクトの**標準検証フロー**としてデファクト化済。

「preview が 401 で見えないから検証できない」を「ローカル + 本番の2段で確実に取る」に置き換えるのが本スキルの本質。

## When to Use

- Vercel / Netlify 等で **Deployment Protection (SSO / Password)** が有効、preview URL が 401 を返す
- preview URL が見られないが、main merge 後の本番 deploy は public で見られる
- ローカルで一通り検証 → 本番でも一通り取り直したい (キャッシュ/相対パス/Firestore等の本番固有事象を吸収)
- UI/演出の変更で殿体感確認を最終的に求める前に、**自動検証で挙動とリグレッションを担保**したい
- 静的 HTML / CSS / JS が中心で、`python3 -m http.server` で動く構成

逆に以下は本スキル不要:
- preview URL に protection が無く Playwright MCP で直接当たれる
- バックエンドサーバが必須で `http.server` で代替不能 (Express/Next API 等)
- 完全クライアント側のみのコード (検証は localhost で十分、本番再検証不要)

## Instructions

### Step 1: ローカル静的サーバ並走

```bash
cd <project_root>
python3 -m http.server 18430 &
```

なぜ必要か: Vercel preview が SSO 401 で見えない → ローカル `localhost:18430` で同じ静的アセットを Playwright MCP に当てられる状態を作る。port は 18430 など固定し他開発と衝突回避。

### Step 2: localStorage クリア + cache-bust 付き Playwright navigate

```js
mcp__playwright__browser_navigate({ url: "http://localhost:18430/?bust=" + Date.now() })
mcp__playwright__browser_evaluate({
  function: `() => { localStorage.clear(); sessionStorage.clear(); return 'cleared'; }`
})
mcp__playwright__browser_navigate({ url: "http://localhost:18430/?bust=" + Date.now() })
```

なぜ必要か: 前回検証セッションの localStorage 残存 (kz_armyA_020) や CSS/JS のブラウザキャッシュ (kz_armyA_018) で「直したはずなのに Before 値が出る」偽陽性を潰す。クリア → reload で確実に新規セッションから検証。

### Step 3: ローカル機能検証 N 項目

```js
// 例: console error 0、DOM 構造、CSS 計測、Firestore 連動 (認証要なら別途)
mcp__playwright__browser_console_messages()
mcp__playwright__browser_snapshot()
mcp__playwright__browser_evaluate({ function: `() => getComputedStyle(document.body).background` })
```

なぜ必要か: PR を出す前に**ローカルでクリティカルパス全件 PASS** を取らないと、本番反映後に巻き戻し困難。最低限 console errors 0 / 主要 DOM 存在 / 計測値期待一致を取る。

### Step 4: PR 作成 → main merge

```bash
gh pr create --base main --head <feature_branch> --title '...' --body '...'
# preview URL は SSO 401 なので CI チェック (Vercel deployment) は CLEAN になっていれば OK
gh pr merge <PR#> --squash
```

なぜ必要か: preview の SSO 401 は**チェック失敗ではない** (deploy 自体は成功し、保護で見えないだけ)。Vercel CI が `success` なら merge 可。preview を「見えないから危険」と誤解しない。

### Step 5: 本番 URL で curl キーワード grep

```bash
# Vercel deploy 完了 (通常 main merge から 30-90 秒) を待つ
sleep 60
# 変更したファイル/関数名/CSS変数等が配信されているか確認
curl -s 'https://<project>.vercel.app/path/to/file.js' | grep -E '(関数名|CSS変数|定数)'
```

なぜ必要か: 「main merge したのに本番がまだ古い」事故を防ぐ。Vercel deploy が成功・反映されて初めて curl で変更キーワードが grep にヒットする。`Cache-Control` ヘッダや CDN 反映遅延も併せて吸収。

### Step 6: 本番 Playwright で重要機能 + console errors 0

```js
mcp__playwright__browser_navigate({ url: "https://<project>.vercel.app/?bust=" + Date.now() })
mcp__playwright__browser_evaluate({ function: `() => { localStorage.clear(); return 'cleared'; }` })
mcp__playwright__browser_navigate({ url: "https://<project>.vercel.app/?bust=" + Date.now() })
mcp__playwright__browser_console_messages()
// 重要機能 1-2 項目 + tcmd_xxx 系の既存演出リグレッション 0 件確認
```

なぜ必要か: ローカル `http.server` では拾えない**本番固有の事象** (CDN 経由で url() 相対パスが解決されない / Firestore unauthenticated 挙動 / Service Worker キャッシュ 等) を本番で取り直す。ローカル PASS だけで完遂報告すると本番のみ壊れているケースを見逃す (kz_armyA_015 が実例)。

完遂条件: ローカル + 本番 両方 PASS、UI 改変なら殿体感確認依頼フラグを立てる。

## Examples

### Example 1: Firestore 認証要プロジェクト (cmd_243 camp-schedule-app battle)

camp-schedule-app は battle ロジックが Firestore 連動だが、未認証時は participants collection で「Document references must have an even number of segments」エラーが出る (既存仕様)。

ローカル http.server 検証では `/battle/` 単体で動的 import + DOM 操作のみ取り、Firestore 連動部分はスキップ。本番 Playwright でも同様、`/battle/` の DRAW_COUNT/タイトル文言/console errors を取る。Firestore 認証要のフル検証は殿の手元で行う前提で、自動検証は「Firestore 周りに副作用 0 件」が示せれば OK。

```bash
# ローカル
cd /home/hatan/camp-schedule-app && python3 -m http.server 18430 &
# Playwright で http://localhost:18430/battle/?bust=$(date +%s)
# → DRAW_COUNT=1 配信確認 / renderGachaCards タイトル動的化確認 / console errors 0

# PR #36 squash merge → Vercel deploy
sleep 60
curl -s 'https://camp-schedule-app.vercel.app/battle/assets/js/gacha.js' | grep -E '(DRAW_COUNT = 1|cmd_243)'
# → 配信確認

# Playwright 本番 https://camp-schedule-app.vercel.app/?bust=...
# → tobi-raised 太陽モード演出 (.star-aura 赤橙) リグレッション 0 件確認
```

### Example 2: 静的 HTML ダッシュボード (cmd_232 editorial-redesign)

camp-schedule-app の TOP は静的 HTML + CSS が中心で `http.server` で完全再現可能。SSO preview 401 のため、ローカル 9 項目検証 → main merge → 本番 curl + Playwright で同じ 9 項目を再検証。

```bash
cd /home/hatan/camp-schedule-app && python3 -m http.server 18430 &
# Playwright で 9 項目検証 (16参加者表示/4ピル/台帳/フッター/レイアウト 等)
# 全 PASS で PR #20 → squash merge
sleep 60
curl -s 'https://camp-schedule-app.vercel.app/' | grep -E '(class="participants-grid"|--text-primary)'
# Playwright 本番で 9 項目再検証 → 全 PASS
```

ローカル 9/9 + 本番 9/9 = 18/18 でリグレッション 0 件を客観担保、preview 401 を完全回避。

### Example 3: 本番でのみ発覚した 404 (kz_armyA_015 url() 相対パス)

cmd_225 hotfix で、`stars.svg` を `style.css` から `url(./stars.svg)` 参照したが、`style.css` の配置階層と HTML の階層が異なるため**本番で 404**。ローカルでは偶然同階層に置いていたため気づかず通過した、典型的な「本番固有の事象」事例。

```bash
# ローカル: 偶然動作 (style.css と stars.svg が同階層に置かれていた)
# → Playwright で console errors 0 確認、PR merge

# 本番: stars.svg 404
curl -I 'https://camp-schedule-app.vercel.app/stars.svg'  # → 404
# → 急ぎ hotfix PR で url() を絶対パス /assets/stars.svg に修正
```

教訓: 本スキル Step 6 を**サボらず**「本番 Playwright で console/network errors 0」を必ず取れ。ローカル PASS は本番 PASS を保証しない。`url()` の相対パス解決起点は **CSS ファイル自身**であって HTML ではない (kz_armyA_015 永続教訓)。

## Guidelines / Failure Modes (Pitfalls)

### Pitfall 1: ブラウザキャッシュで Before 値固着

- Playwright MCP で navigate しても、ブラウザは強キャッシュで前回 CSS/JS を返すことがある
- 必ず `?bust=${Date.now()}` を URL に付与、CSS/JS は `link[rel=stylesheet]` の href にも `?bust=` 注入推奨
- 症状: 修正したはずなのに変化なし / 古い console エラーが出続ける → 9割キャッシュ
- Related: `wcag-contrast-playwright-auditor` の Related Workflow 節に link cache-bust スニペット同梱

### Pitfall 2: localStorage / sessionStorage 残存 (kz_armyA_020 取込)

- 前回 Playwright セッションでセットした userId / token / localStorage キーが残ると、次回検証で**ログイン済挙動**になり「未ログイン状態の表示が壊れている」事象を見落とす
- Step 2 で `localStorage.clear(); sessionStorage.clear();` を冒頭1ステップ標準化
- IndexedDB / Cookie もクリアしたい場合は context レベル新規作成のほうが確実
- 偽陽性ケース: 「未ログイン時に台帳表示されてはいけない」検証で、前回セッションの userId 残存により台帳が表示されてしまい「正常」判定 → 本番で初発覚

### Pitfall 3: url() 相対パス 404 (kz_armyA_015 永続教訓)

- CSS の `url(./img.svg)` は **CSS ファイルの配置階層**を起点に解決される (HTML 起点ではない)
- ローカル `http.server` で偶然 `style.css` と `img.svg` が同階層なら通る、本番で階層分離されると 404
- 対策:
  - CSS 内の url() は**絶対パス推奨** (`/assets/img.svg`)
  - 本スキル Step 6 の本番 Playwright で console/network errors 0 を必ず取る
  - 開発時から HTML / CSS / 画像を別階層に配置して `http.server` で確認

### Pitfall 4: SSO 401 を「deploy 失敗」と誤解

- Vercel preview URL を curl すると 401 が返るが、これは **deploy 成功後の認証保護**
- Vercel CI チェックは `success` (deployment 自体は成立)、merge ブロックされていない
- 「preview 401 だから merge できない」と判断するのは誤り。CI が CLEAN/MERGEABLE なら main merge 進行可
- 確認方法: `gh pr checks <PR#>` で deployment が success か、`gh pr view <PR#> --json mergeable,mergeStateStatus` で MERGEABLE/CLEAN か

### Pitfall 5: 本番 deploy 反映の待機不足

- main merge 直後に curl すると、Vercel CDN がまだ旧バージョンを返すことがある
- Step 5 の `sleep 60` は最低ライン、変更が大きい (新規ファイル追加等) なら 90-120 秒待機
- ポーリング: `until curl -s '<url>' | grep -q '<keyword>'; do sleep 10; done` で確実に反映を捕捉
- レート制限注意: curl 連打せず 5-10 秒間隔

### Pitfall 6: ローカル PASS = 本番 PASS の誤解

- `http.server` は完全な静的サーバ、Vercel/Netlify は CDN・ヘッダ・rewrites 等が乗る
- ローカルで動いても本番で:
  - `Cache-Control: max-age=...` で予期せぬキャッシュ
  - rewrites/redirects ルールで URL が変わる
  - 環境変数依存コードが undefined で落ちる
- 本スキル Step 6 を必ず実行、ローカル PASS だけで完遂報告しない

## Related Workflow

### preview SSO 401 の判別

```bash
# preview URL を curl
curl -I 'https://<branch>--<project>.vercel.app/'
# HTTP/2 401 + x-vercel-protection-bypass ヘッダ → SSO 保護
# HTTP/2 200 → 保護なし、直接 Playwright で当たれる
```

### Vercel deploy 完了の確認

```bash
# gh で最新 deployment status を取る
gh api repos/<owner>/<repo>/deployments --jq '.[0].statuses_url' \
  | xargs -I{} gh api {} --jq '.[0].state'
# success → 反映済 / pending → 待機継続
```

### キャッシュ無視で確実に新版取得

```js
// Playwright MCP で全 link[rel=stylesheet] に bust 注入
mcp__playwright__browser_evaluate({
  function: `() => {
    const ts = Date.now();
    document.querySelectorAll('link[rel=stylesheet]').forEach(l => {
      const u = new URL(l.href);
      u.searchParams.set('bust', ts);
      l.href = u.toString();
    });
    return 'css cache-busted at ' + ts;
  }`
})
```

### 関連スキル

- `wcag-contrast-playwright-auditor`: 本スキル Step 6 の本番 Playwright 内で WCAG コントラスト比を一括計測する場合に併用。Related Workflow の cache-bust スニペットを共用
- `playwright-animation-pause`: 本番アニメ peak フレームを `currentTime` 固定で撮影する場合に併用。本スキル Step 6 内に挿入する形

## 入出力仕様

### 入力
- `project_root` (絶対パス): ローカル `http.server` を立てるプロジェクトディレクトリ
- `local_port` (int): http.server ポート (慣例 18430)
- `prod_url` (URL): 本番 deploy URL
- `feature_branch` (string): PR 作成元ブランチ
- `verification_targets` (string[]): 検証対象 (DOM セレクタ / curl grep キーワード / 機能名)

### 出力
- ローカル検証結果 (console errors / DOM / computed style 等)
- 本番 curl grep 結果 (キーワードヒット数)
- 本番 Playwright 検証結果 (console errors / DOM / リグレッション 0 件 等)
- (UI 改変時) 殿体感確認依頼フラグ

## Checklist

```
- [ ] python3 -m http.server <port> 並走起動
- [ ] localStorage.clear + sessionStorage.clear (Step 2)
- [ ] navigate に ?bust=Date.now() 付与
- [ ] ローカル機能検証 N 項目 PASS (console errors 0 含)
- [ ] PR 作成 (preview 401 無視可、CI が CLEAN/MERGEABLE 確認)
- [ ] main merge (gh pr merge --squash)
- [ ] 本番 deploy 反映待機 (最低 sleep 60 / 確実なら until polling)
- [ ] 本番 curl で変更キーワード grep ヒット確認
- [ ] 本番 Playwright で localStorage.clear + cache-bust + 重要機能再検証
- [ ] 本番 console/network errors 0 (kz_armyA_015 教訓)
- [ ] (UI 改変なら) 殿体感確認依頼フラグを家老→将軍→大将軍経由で立てる
- [ ] http.server プロセス停止 (`kill %1` 等)
```

## Related kaizen / commands

- 起源: kz_armyA_019 (家老A、cmd_232 で Vercel SSO 401 を 2 段検証で回避、cmd_244 で skill 化)
- 同梱解消: kz_armyA_020 (Playwright 検証前 localStorage.clear 励行) を Pitfall 2 に取り込み同時 fixed
- 採用実績:
  - cmd_232: editorial-redesign (3ファイル cp置換 + 9項目検証)
  - cmd_235: star-pulse (5フレーム連続スクショ + 本番 computed style 一致)
  - cmd_237: organic-star (4アニメ複合 peak + 本番完全一致)
  - cmd_238: sun-mode (5アニメ複合 peak + tobi-raised body class)
  - cmd_240: color-only 差分 (-86 行純減 + tobi-raised 変数差替)
  - cmd_243: battle-skill-grant (DRAW_COUNT 5→1 + Monte Carlo + 太陽モード演出維持)
- 関連 kaizen:
  - kz_armyA_015 (url() 相対パス 404、本スキル Pitfall 3 として永続教訓化)
  - kz_armyA_018 (cache-bust ワンライナー、wcag-auditor の Related Workflow と共通利用)
  - kz_armyA_021 (Firestore ID 実在確認、本スキル Example 1 と関連: 認証要 Firestore のスコープ判断)
- 関連スキル:
  - `wcag-contrast-playwright-auditor`: 本番 Playwright 内で WCAG audit 併用
  - `playwright-animation-pause`: 本番アニメ peak frame 取得併用
