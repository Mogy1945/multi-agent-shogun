---
name: wcag-contrast-playwright-auditor
description: Playwright MCP の `browser_evaluate` 内で `getComputedStyle` から取得した color / backgroundColor を、半透明レイヤを親要素遡上で alpha 合成しつつ WCAG 2.x 相対輝度に変換し、AA/AAA 判定込みのコントラスト比を実測するスキル。「目視で見えにくい」を**数値で証明**する定量検証パターン。複数セレクタ一括監査・cache-bust 併用で before/after 比較に使う
---

# WCAG Contrast Playwright Auditor - アクセシビリティ比率実測スキル

## Overview

UI のコントラスト不足は「目視で読みにくい」体感に依存する曖昧な不具合になりがち。本スキルは Playwright MCP の `browser_evaluate` を使って、`getComputedStyle` から取得した `color` と `backgroundColor` を **alpha 合成込み**で WCAG 2.1/2.2 準拠の相対輝度・コントラスト比に変換し、AA / AAA 通過判定まで返す定型パターンを提供する。

殿FB「選んでいない日程が見えにくい」(cmd_229) で、`.option-button` の rgba(0,0,0,0.05) テキストが夜キャンプ夜空背景上で **ratio 1.27 (AA 4.5 大幅未達)** と数値証明。修正後 `.option-button { color: var(--text-primary, #f2ede0); background: rgba(255,250,230,0.08) }` に変えて **11.07 (AAA 7:1 大幅超過)** を実測、PR 添付ログとして「客観的に直った」を担保した。

「読めるかどうか」を視覚特性に依存させず、**数値で完結**させるのが本スキルの本質。

## When to Use

- デザイン変更後のテキスト視認性回帰検証 (before/after で ratio 比較)
- 殿FB「見えにくい / 読めない」を**数値化して原因特定**したいとき
- WCAG AA (4.5:1) / AAA (7:1) 通過判定を PR 添付エビデンスとして残したいとき
- 半透明背景 (`rgba(R,G,B,0.05)` 等) を含むレイヤの**実効コントラスト**を計測したいとき
- 複数セレクタ (`.btn`, `.pill`, `.card-title` 等) を**一括監査**したいとき
- 夜モード / ダークテーマ / glass-morphism 等、**背景が複雑**で目視判断不可能な UI

逆に、不透明 (alpha=1) かつ単純な fg/bg 組み合わせなら axe-core / Lighthouse 等の汎用ツールで十分、本スキルは過剰。

## Instructions

### Step 1: ナビゲート + cache-bust (kz_armyA_018 併用)

```js
mcp__playwright__browser_navigate({ url: "<target_url>" })

// CSS編集後に古いキャッシュが残ると Before 値しか出ない → cache-bust 必須
mcp__playwright__browser_evaluate({
  function: `() => {
    const ts = Date.now();
    document.querySelectorAll('link[rel=stylesheet]').forEach(l => {
      const u = new URL(l.href);
      u.searchParams.set('bust', ts);
      l.href = u.toString();
    });
    return 'cache-busted at ' + ts;
  }`
})
```

これは Related Workflow (kz_armyA_018 の解) として本スキルとセット運用。

### Step 2: WCAG コントラスト比計算ロジック (Playwright 内 JS)

```js
mcp__playwright__browser_evaluate({
  function: `() => {
    // ----- color parser -----
    function parseRGBA(str){
      // "rgb(R,G,B)" / "rgba(R,G,B,A)" / "transparent" 対応
      if(!str || str === 'transparent' || str === 'rgba(0, 0, 0, 0)') return [0,0,0,0];
      const m = str.match(/rgba?\\(([^)]+)\\)/);
      if(!m) return [0,0,0,1];
      const parts = m[1].split(',').map(s => parseFloat(s.trim()));
      return [parts[0], parts[1], parts[2], parts[3] === undefined ? 1 : parts[3]];
    }

    // ----- alpha 合成 (前景を背景に重ねる) -----
    function composite(fg, bg){
      const a = fg[3] + bg[3] * (1 - fg[3]);
      if(a === 0) return [0,0,0,0];
      return [
        (fg[0]*fg[3] + bg[0]*bg[3]*(1-fg[3])) / a,
        (fg[1]*fg[3] + bg[1]*bg[3]*(1-fg[3])) / a,
        (fg[2]*fg[3] + bg[2]*bg[3]*(1-fg[3])) / a,
        a
      ];
    }

    // ----- 親要素遡って実効背景を合成 -----
    function effectiveBg(el){
      let cur = el;
      let acc = [255,255,255,1]; // body 上位は白基準 (canvas 色相当)
      const stack = [];
      while(cur && cur !== document.documentElement){
        const bg = parseRGBA(getComputedStyle(cur).backgroundColor);
        if(bg[3] > 0) stack.push(bg);
        cur = cur.parentElement;
      }
      // root → leaf 順に合成
      for(let i = stack.length - 1; i >= 0; i--){
        acc = composite(stack[i], acc);
      }
      return acc;
    }

    // ----- sRGB → linear 輝度 -----
    function relLuminance([r,g,b]){
      const lin = c => {
        const s = c / 255;
        return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
      };
      return 0.2126*lin(r) + 0.7152*lin(g) + 0.0722*lin(b);
    }

    // ----- WCAG コントラスト比 -----
    function contrastRatio(fg, bg){
      // 前景が半透明なら背景に合成してから輝度計算
      const fgOnBg = composite(fg, bg);
      const L1 = relLuminance(fgOnBg);
      const L2 = relLuminance(bg);
      const [hi, lo] = L1 > L2 ? [L1, L2] : [L2, L1];
      return (hi + 0.05) / (lo + 0.05);
    }

    // ----- 監査本体 -----
    function audit(selector){
      const el = document.querySelector(selector);
      if(!el) return { selector, error: 'not found' };
      const cs = getComputedStyle(el);
      const fg = parseRGBA(cs.color);
      const bg = effectiveBg(el);
      const ratio = contrastRatio(fg, bg);
      const fontSize = parseFloat(cs.fontSize);
      const isBold = parseInt(cs.fontWeight, 10) >= 700;
      const isLarge = fontSize >= 24 || (fontSize >= 18.66 && isBold); // WCAG 大文字定義
      return {
        selector,
        fg: 'rgba(' + fg.join(',') + ')',
        bg_effective: 'rgba(' + bg.map(v => +v.toFixed(2)).join(',') + ')',
        ratio: +ratio.toFixed(2),
        is_large_text: isLarge,
        aa_pass: ratio >= (isLarge ? 3 : 4.5),
        aaa_pass: ratio >= (isLarge ? 4.5 : 7),
      };
    }

    // 単一 or 配列、両対応
    const targets = ['.option-button', '.pill', '.card-title']; // ← 用途に応じ書換
    return targets.map(audit);
  }`
})
```

### Step 3: 結果判定とレポート

返却例:
```json
[
  { "selector": ".option-button", "fg": "rgba(0,0,0,0.05)", "bg_effective": "rgba(18,24,42,1)",
    "ratio": 1.27, "is_large_text": false, "aa_pass": false, "aaa_pass": false }
]
```

→ `aa_pass: false` を PR 添付ログとして残せば「主観なし」の客観証拠。

修正後の再計測:
```json
[
  { "selector": ".option-button", "fg": "rgba(242,237,224,1)", "bg_effective": "rgba(38,42,58,1)",
    "ratio": 11.07, "is_large_text": false, "aa_pass": true, "aaa_pass": true }
]
```

### Step 4: WCAG しきい値早見表

| カテゴリ | 通常テキスト | 大文字テキスト (≥24px or ≥18.66px+bold) | UI 部品/グラフィックオブジェクト |
|---------|------------|------|------|
| **AA**  | 4.5:1 以上 | 3:1 以上 | 3:1 以上 (WCAG 2.1+) |
| **AAA** | 7:1 以上   | 4.5:1 以上 | (規定なし) |

「大文字テキスト」の境界 18.66px+bold は WCAG 2.x 公式: 14pt bold = 18.66px bold。

### Step 5: 複数ページ・複数 viewport 一括監査

```js
const viewports = [{w:1280,h:900},{w:390,h:844},{w:375,h:667}];
// 各 viewport で resize → 上記 audit を回す
```

`mcp__playwright__browser_resize` で切替後、Step 2 を再実行 → ratio が viewport で変わる UI (responsive font-size 等) を捕捉。

## Examples

### Example 1: cmd_229 .option-button 1.27 → 11.07 (本スキル起源)

camp-schedule-app の TOP 参加日程ボタン未選択状態。殿テストプレイで「選んでいない日程が見えにくい」FB → 数値証明 → 修正 → 再計測。

**Before** (`rgba(0,0,0,0.05)` テキスト on tcmd_225 夜空背景):
```json
{
  "selector": ".option-button",
  "fg": "rgba(0,0,0,0.05)",
  "bg_effective": "rgba(18,24,42,1)",
  "ratio": 1.27,
  "is_large_text": false,
  "aa_pass": false, "aaa_pass": false
}
```
→ AA 4.5 大幅未達、目視通り「ほぼ不可視」を数値で確定。

**After** (tcmd_225 既存夜空トークン再利用):
```css
.option-button{
  background-color: rgba(255,250,230,0.08);
  color: var(--text-primary, #f2ede0);
  border: 1px solid var(--glass-border-strong, rgba(255,250,230,0.28));
}
```
```json
{
  "selector": ".option-button",
  "fg": "rgba(242,237,224,1)",
  "bg_effective": "rgba(38,42,58,1)",
  "ratio": 11.07,
  "is_large_text": false,
  "aa_pass": true, "aaa_pass": true
}
```
→ AAA 7:1 大幅超過。PR #26 squash merge 時に before/after JSON を添付、「数値で直った」を客観担保。

### Example 2: 複数セレクタ一括監査

```js
const targets = ['.btn--primary', '.btn--ghost', '.pill', '.pill--warn',
                 '.card-title', '.card-meta', '.tab-active', '.tab-inactive'];
return targets.map(audit);
```

返却:
```
.btn--primary    fg: rgba(255,255,255,1)  bg: rgba(217,74,31,1)   ratio: 4.83  AA✓ AAA✗
.btn--ghost      fg: rgba(38,42,58,0.7)   bg: rgba(255,250,230,1) ratio: 6.11  AA✓ AAA✗
.pill            fg: rgba(0,0,0,0.5)      bg: rgba(255,250,230,0.08) ratio: 1.81 AA✗ AAA✗  ← 要修正
.pill--warn      fg: rgba(255,255,255,1)  bg: rgba(217,74,31,1)   ratio: 4.83  AA✓ AAA✗
...
```

「全コンポーネント一斉監査して落第セレクタだけ抽出」用途。

### Example 3: ダーク/ライトテーマ切替後の差分監査

```js
// theme=light で audit
const light = audit('.card-title');
document.body.classList.add('theme-dark');
// theme=dark で audit
const dark = audit('.card-title');
return { light, dark, regression: light.aa_pass && !dark.aa_pass };
```

テーマ切替で AA を失っていないか自動検出。`css-keyframes-themed-via-vars` 方式と組み合わせると有効。

## Guidelines / Failure Modes

### 半透明テキスト (`color: rgba(...,0.5)`) の合成漏れ

- **必ず前景も背景に合成してから輝度計算**せよ。`relLuminance(fg)` を直接呼ぶと半透明色の値が嘘になる
- 上記 `contrastRatio()` は `composite(fg, bg)` を内部で呼ぶ実装になっている
- `rgba(0,0,0,0.05)` のような極端に薄い前景は、合成後ほぼ背景色 = 比率 1 付近になるのが正解

### 親要素遡上時の `transparent` 無視

- 中間要素が `background: transparent` または `rgba(0,0,0,0)` なら**スタックに積まない**
- 上記 `effectiveBg()` は `bg[3] > 0` でフィルタしている
- `body` も明示的に背景指定がないなら **白 (canvas 色相当)** を root とする (`acc = [255,255,255,1]`)
- ただしダークモードでは `<html>`/`<body>` に `background: #121828` 等の指定があるはずなので、そちらが優先される

### `display:none` / `visibility:hidden` 要素

- `getComputedStyle` 取得自体はできるが、レンダリング上は不可視 → 監査対象外にすべき
- 監査前に `el.offsetParent !== null` または `getBoundingClientRect().width > 0` でフィルタ

### 画像背景 (`background-image: url(...)`)

- 画像背景上のテキストは本スキルでは **計測不可** (画像のピクセル平均色が必要)
- 設計時から「画像上テキストには semi-transparent overlay (`rgba(0,0,0,0.5)` 等) を必須」のルールで回避
- どうしても計測したいなら canvas 経由で背景画像をピクセルサンプリングする拡張が必要 (本スキルの範疇外)

### `inherit` / `currentColor` / CSS 変数

- `getComputedStyle` は最終解決値を返すので、`color: currentColor` や `var(--text-primary)` も**展開後の rgb 値**で取れる
- 心配無用、特別扱い不要

### cache-bust 忘れによる Before 値固着 (kz_armyA_018)

- Playwright MCP で CSS 編集 → reload → 計測しても**ブラウザキャッシュで旧 CSS** が残ることがある
- Step 1 の cache-bust スニペットを必ず先に実行
- 症状: 修正したはずなのに ratio が変わらない / "Before" の数値が出続ける → 9割キャッシュ問題

### viewport 依存 (responsive font-size)

- `font-size: clamp(14px, 1vw, 18px)` のような responsive 設計だと **大文字判定 (`isLarge`) が viewport で変わる**
- 必ず計測対象 viewport を `browser_resize` で固定してから audit
- 殿環境を再現するなら 1280×900 (PC) + 390×844 (iPhone 12) + 375×667 (iPhone SE) の3パターン推奨

### 数値だけで判断しない例外ケース

- WCAG 数値合格でも「文字色が背景と紛らわしい色相」なら体感不可視 (例: ratio 5.0 で青 on 紫)
- 数値はミニマムバー、最終チェックは目視 + 殿確認
- ただし「目視のみ」で判断するのは NG (本スキルの存在意義)

## Related Workflow

### cache-bust スニペット (kz_armyA_018 の解)

CSS 編集 → 再計測の前段として**必ず**実行。本スキルとセット運用が前提。

```js
mcp__playwright__browser_evaluate({
  function: `() => {
    const ts = Date.now();
    document.querySelectorAll('link[rel=stylesheet]').forEach(l => {
      const u = new URL(l.href);
      u.searchParams.set('bust', ts);
      l.href = u.toString();
    });
    return 'cache-busted at ' + ts;
  }`
})
```

これにより `link[rel=stylesheet]` の href に `?bust=<epoch>` を注入、強制リロード相当の効果。Playwright `browser_navigate` の cache 無効化オプションが効かない場面 (CSS だけ更新した時等) で確実。

### 関連スキル

- `playwright-animation-pause`: アニメ駆動中の peak 値での `getComputedStyle` 取得に併用 (動的に色が変わる UI のコントラスト計測)
- `css-keyframes-themed-via-vars`: テーマ切替を変数差替で実装した UI で、theme A / theme B 両方の audit を回して AA 維持を保証
- 上流ツールとの棲み分け: 単純 fg/bg なら axe-core / Lighthouse、複雑な alpha レイヤや動的アニメ peak での計測は本スキル

## 入出力仕様

### 入力
- `target_url` (URL): ナビゲート先
- `selectors` (string[]): 監査対象セレクタ配列
- `viewports` (任意): `[{w,h}, ...]` 複数 viewport 計測

### 出力 (selector ごと)
```ts
{
  selector: string;
  fg: string;              // "rgba(R,G,B,A)"
  bg_effective: string;    // 親要素遡上後の合成背景
  ratio: number;           // 小数2桁
  is_large_text: boolean;
  aa_pass: boolean;        // ratio >= 4.5 (大文字なら 3.0)
  aaa_pass: boolean;       // ratio >= 7.0 (大文字なら 4.5)
}
```

## Checklist

```
- [ ] browser_navigate <target_url>
- [ ] cache-bust スニペット実行 (Related Workflow の link[bust=ts] 注入)
- [ ] 計測 viewport を browser_resize で固定 (PC/モバイル別なら複数回)
- [ ] audit() 関数を targets 配列で実行、結果を JSON 取得
- [ ] aa_pass: false を抽出 → 修正対象セレクタ確定
- [ ] CSS 修正
- [ ] cache-bust + 再 audit、ratio が AA/AAA に乗ったか確認
- [ ] before/after JSON を PR 本文 or reports/ に添付 (客観証拠)
- [ ] 半透明背景・画像背景・currentColor の例外ケースを目視併用確認
```

## Related kaizen / commands

- 起源: kz_armyA_016 (家老A、cmd_229 で 1.27→11.07 実測、cmd_242 で skill 化)
- 同梱解消: kz_armyA_018 (Playwright cache-bust ワンライナー) を Related Workflow に取り込み同時 fixed
- 採用実績:
  - cmd_229 camp-schedule-app `.option-button` 視認性改善 (PR #26 squash merge)
    - Before: rgba(0,0,0,0.05) on 夜空背景 → ratio **1.27** (AA 4.5 大幅未達)
    - After: var(--text-primary,#f2ede0) on rgba(255,250,230,0.08) → ratio **11.07** (AAA 7:1 超過)
    - 殿FB「見えにくい」を数値で原因特定 → tcmd_225 既存夜空トークン再利用で最小修正
- 関連スキル:
  - `playwright-animation-pause`: 動的色 UI の peak 値計測時に併用
  - `css-keyframes-themed-via-vars`: テーマ切替後の AA 維持回帰検証
