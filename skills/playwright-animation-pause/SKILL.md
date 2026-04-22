---
name: playwright-animation-pause
description: Playwright MCP で CSS @keyframes の中間フレームを正確にキャプチャするスキル。`element.getAnimations()` の `currentTime` を任意時点に固定し pause、スクショ取得、play() で復帰までの定型フロー。複数アニメ並走時は keyframe 別に各 currentTime を個別指定して複合ピーク再現可能
---

# Playwright Animation Pause - CSSアニメ中間フレーム検証スキル

## Overview

Playwright MCP で CSS `@keyframes` を使った装飾アニメ (pulse / glow / breathe / shimmer 等) を視覚検証する際、リアルタイム駆動のままスクショを撮ると「いつのフレームか」が不定で再現性ゼロとなる。

本スキルは `document.getAnimations()` で稼働中の Animation オブジェクトを取得し、`currentTime` を任意の ms (= 周期 × 進行率%) に固定して `pause()` することで、**任意の keyframe ピーク状態を pixel-perfect に再現**してスクショ取得する手順を提供する。

複数アニメが並走する場合 (例: candle decay + shimmer + flare + halo-breathe の4並列) は、Animation 名ごとに **異なる currentTime** を設定することで、複合ピーク (各アニメが意図したフレームに揃う組み合わせ) を再現可能。

cmd_234 / 235 / 237 / 238 / 240 で計5タスク連続採用、本番 computed style との完全一致検証のデファクト手法。

## When to Use

- CSS `@keyframes` 装飾の peak / mid / rest 各フレームを「再現可能」な形で記録したいとき
- 本番デプロイ後の `getComputedStyle` 値が設計通りか検証したいとき
- 1ページに2つ以上のアニメが並走しており、それぞれ別フレームで複合スクショを撮りたいとき
- アニメ駆動中の box-shadow / transform / opacity / filter 値を**サンプル取得**したいとき
- PR 添付用に「animation peak」の可視ログを残したいとき

逆に、アニメ静止時 (loading 完了後の rest 状態など) を撮るだけなら本スキルは不要。

## Instructions

### Step 1: ナビゲート & 状態整流

```js
// Playwright MCP
mcp__playwright__browser_navigate({ url: "<target_url>" })
```

必要なら ID 自動ログイン等で目的の DOM 状態にしておく:
```js
mcp__playwright__browser_evaluate({
  function: `() => { localStorage.setItem('userId', 'xxx'); return 'set'; }`
})
mcp__playwright__browser_navigate({ url: "<target_url>" })  // reload
```

### Step 2: アニメ稼働確認

```js
mcp__playwright__browser_evaluate({
  function: `() => {
    return {
      total: document.getAnimations().length,
      names: document.getAnimations().map(a => a.animationName),
    };
  }`
})
```

期待する keyframes 名がすべて active であることを確認する。

### Step 3: 周期と進行率の設計

ピーク時刻 = `周期(ms) × 進行率(0-1)` で算出。

CSS 例:
```css
@keyframes star-core{
  0%   { box-shadow: ... 12px ... }     /* 鎮火 */
  20%  { box-shadow: ... 60px ... }     /* peak */
  100% { box-shadow: ... 12px ... }
}
.star { animation: star-core 3.1s ... infinite; }
```
→ peak (20%) を撮るには `currentTime = 3100 * 0.20 = 620ms`

### Step 4: currentTime 固定 + pause

```js
mcp__playwright__browser_evaluate({
  function: `() => {
    const peakTimes = {
      'star-core':         3100 * 0.20,
      'star-shimmer':      1700 * 0.25,
      'star-flare':        18000 * 0.96,
      'star-aura-breathe': 5300 * 0.50,
    };
    let paused = [];
    document.getAnimations().forEach(a => {
      if (peakTimes[a.animationName] !== undefined) {
        a.currentTime = peakTimes[a.animationName];
        a.pause();
        paused.push(a.animationName);
      }
    });
    return { paused, total: document.getAnimations().length };
  }`
})
```

**重要**: アニメ名ごとに `peakTimes` を辞書で個別指定することで、4-5 並列アニメでも各 keyframe 別の進行率を同時に固定できる (= 複合ピークの再現)。

### Step 5: スクショ取得

```js
mcp__playwright__browser_take_screenshot({
  filename: "<absolute_path>",
  fullPage: false,
})
```

`fullPage:false` で viewport のみ撮るのが通常。fullPage は装飾アニメの位置がスクロール内になければ無意味。

### Step 6: computed style サンプリング (任意)

ピーク値が設計通りか検証:
```js
mcp__playwright__browser_evaluate({
  function: `() => {
    const ps = getComputedStyle(document.body, '::after');
    return {
      background: ps.backgroundColor,
      animation: ps.animationName,
      boxShadow: ps.boxShadow,
      transform: ps.transform,
      filter: ps.filter,
    };
  }`
})
```

期待値と完全一致していれば本番デプロイ後の検証もこの方式で再現可能。

### Step 7: play() で復帰 (任意)

別フレームを連続撮影する場合:
```js
mcp__playwright__browser_evaluate({
  function: `() => { document.getAnimations().forEach(a => a.play()); return 'resumed'; }`
})
```

ブラウザを閉じる (`browser_close`) なら復帰不要。

## Examples

### Example 1: cmd_237 organic star — 4アニメ複合ピーク

camp-schedule-app の星エフェクトは body::after に3アニメ (star-core / star-shimmer / star-flare) + .star-aura に1アニメ (star-aura-breathe) の計4並列。

```js
const peakTimes = {
  'star-core':         3100 * 0.20,    // candle decay peak
  'star-shimmer':      1700 * 0.25,    // shimmer peak
  'star-flare':        18000 * 0.96,   // 96% twinkle flare (4%区間のみ)
  'star-aura-breathe': 5300 * 0.50,    // halo max scale
};
document.getAnimations().forEach(a => {
  if (peakTimes[a.animationName] !== undefined) {
    a.currentTime = peakTimes[a.animationName];
    a.pause();
  }
});
```

採取結果:
- `body::after` box-shadow `rgb(245,239,226) 0px 0px 60px 3px, rgba(232,106,60,0.45) 0px 0px 32px 0px`
- `body::after` transform `matrix(1,0,0,1,0.5,-0.5)` (shimmer 25%)
- `body::after` filter `brightness(1.6)` (flare 96%)
- `.star-aura` transform `matrix(1.18,0,0,1.18,0,0)` (aura 50%)

→ ローカル実装 / 本番デプロイで完全一致確認、PR レビューに添付。

### Example 2: cmd_238 sun mode — 5アニメ複合ピーク

```js
const peakTimes = {
  'sun-core':           4300 * 0.35,
  'sun-flicker':        1300 * 0.17,
  'sun-corona-breathe': 6700 * 0.50,
  'sun-ray-rotate':     80000 * 0.0,
  'sun-ray-flicker':    2700 * 0.30,
};
```
80秒周期の超低速 ray-rotate も `0.0` 指定で初期角度に固定可能。

### Example 3: cmd_235 連続フレーム取得 (0/25/50/75/100%)

```js
[0.0, 0.25, 0.5, 0.75, 1.0].forEach((pct, i) => {
  document.getAnimations().forEach(a => {
    if (a.animationName === 'star-pulse') {
      a.currentTime = 2400 * pct;
      a.pause();
    }
  });
  // → browser_take_screenshot frame_${pct*100}.png
  document.getAnimations().forEach(a => a.play());
});
```

PR 添付用に「アニメ1周期の遷移を5枚で見せる」用途。

## Guidelines / Failure Modes

### Animation 取得タイミング

- ページロード直後に `getAnimations()` を呼ぶと CSS パース未完了で空配列になることがある
- `browser_navigate` 後に最低1回 `browser_snapshot` か `browser_evaluate('document.readyState')` で DOM 確定を待つ
- それでも空なら DevTools の Animations タブで実際に keyframes が走っているか手動確認

### currentTime 0 の罠

- `0` を指定しても 0% フレームが撮れない場合がある (animation-fill-mode 依存)
- 確実に 0% を撮るには `0.001` など微小値、もしくは 100% (周期 - 1ms) を試す
- `animation-fill-mode: both` を設計時に付けておくと 0%/100% 両方安定

### 並走アニメの取捨選択

- 1ページ全 animation を `pause()` すると ember-burst や ranking fadein 等の**意図しない装飾**まで止まる
- 本スキルは**目的 keyframe 名だけ**を `peakTimes` 辞書で限定するのが鉄則
- 辞書外の Animation はそのまま稼働継続 → 意図しない静止を防ぐ

### スクショ前の安定化

- pause 直後すぐスクショすると稀に1フレーム前の値が描画されている
- `browser_evaluate(() => requestAnimationFrame(() => requestAnimationFrame(...)))` を挟むか、Playwright の挙動上は通常不要なので**まず素直に撮影**し、ズレが見えたら調整

### Composite Animations / Web Animations API

- transitions (CSS `transition`) も `getAnimations()` に出る。意図せず捕まえないよう `animationName` フィルタ必須
- `Animation.effect.target` で対象 element も取れるが、装飾系では `animationName` 一意で十分

### prefers-reduced-motion 環境

- ユーザ環境が `prefers-reduced-motion: reduce` だと animation:none で getAnimations() 空 → 撮影不可
- 検証用 Playwright は通常 `no-preference` だが、明示的にエミュレートする場合は context オプションで上書き

## 入出力仕様

### 入力
- `target_url` (URL): ナビゲート先
- `peak_times` (dict): `{ "<animationName>": <ms> }` 形式の辞書
- `screenshot_path` (絶対パス): スクショ保存先

### 出力
- スクショ画像 (任意フレームでフリーズした状態)
- 任意で getComputedStyle のサンプル値 (peak値検証用)

## Checklist

```
- [ ] browser_navigate <target_url>
- [ ] (必要なら ID 自動ログイン等で目的 DOM へ遷移)
- [ ] browser_evaluate で getAnimations() 稼働確認
- [ ] peakTimes 辞書を周期 × 進行率で設計
- [ ] browser_evaluate で各 Animation に currentTime + pause()
- [ ] browser_take_screenshot <absolute_path>
- [ ] (任意) browser_evaluate で getComputedStyle 採取
- [ ] (連続フレーム取る場合) play() で復帰 → 次フレーム
- [ ] browser_close
```

## Related kaizen / commands

- 起源: kz_armyA_023 (家老A、cmd_234/235/237/238 4連続採用、cmd_241 で skill 化)
- 採用実績:
  - cmd_234: ember-burst peak (35%) 撮影
  - cmd_235: star-pulse 0/25/50/75/100% 5フレーム連続撮影
  - cmd_237: organic star 4アニメ複合 peak (本番完全一致検証)
  - cmd_238: 太陽モード5アニメ複合 peak
  - cmd_240: 既存4アニメ + tobi-raised 変数差替後の peak (本番完全一致検証)
