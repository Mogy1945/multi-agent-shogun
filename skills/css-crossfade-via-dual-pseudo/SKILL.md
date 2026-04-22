---
name: css-crossfade-via-dual-pseudo
description: モード切替時の「唐突感」を消すため、別要素 / 疑似要素を上下レイヤで重ね opacity transition で 1-2 秒クロスフェードさせる設計テンプレ。CSS keyframes 動作中の単一要素は class 切替で値の途中遷移ができないため、別レイヤ重ね方式で滑らかに切替える
---

# CSS Crossfade via Dual Pseudo - 状態切替アニメ滑らか化スキル

## Overview

CSS `@keyframes` で常時駆動している装飾要素 (pulse, glow, breathe 等) を、モード切替 (例: 通常 → ハイライト、星 → 太陽) で「色」「形」「サイズ」を切り替えたいとき、**単一要素 + class 切替方式**では keyframes が常時 box-shadow / transform 等を上書きしているため `transition` が効かず、切替が**カクッと唐突**になる。

本スキルは **2つのレイヤ (別要素または疑似要素) を z-index で重ねて配置**し、それぞれを `opacity: 0/1 + transition: opacity Xs ease-out` でクロスフェードさせることで、keyframes 動作中の装飾モード切替を 1-2 秒で滑らかに移行させる設計パターン。

cmd_238 で星モード body::after / .star-aura → 太陽モード .sun-orb / .sun-orb::before / .sun-orb::after の遷移に採用、後継 cmd_240 で「変数差替方式」に縮退するまで実装の基準パターンとして機能。

## When to Use

- CSS `@keyframes` で常時アニメ稼働中の装飾要素のモード切替を**フェードで**実装したい
- 「単一要素の class 切替で transition 効かない」問題を回避したい
- 切替対象が「色」だけでなく「形 (radius/clip-path)」「サイズ」「装飾追加 (corona/halo)」を含む
- 1-2秒の crossfade で「唐突感ゼロ」「editorial 品位維持」を要求される
- 切替方向の表現が逆向き / 同時並行 (旧消失 + 新出現) で必要

逆に、切替対象が **CSS 変数で表現可能な「色 / サイズ / 透明度」のみ** で済むなら本スキルは不要。`css-keyframes-themed-via-vars` 方式 (kaizen kz_armyA_025 候補) の方が単純で行数も少ない。

## Instructions

### Step 1: 切替対象を 2レイヤに分離

旧モード (例: 星) 用の要素群 / 新モード (例: 太陽) 用の要素群を**完全に独立した DOM ノード**として用意する。

```html
<!-- 旧モード用 (常駐) -->
<div class="star-aura" aria-hidden="true"></div>
<!-- body::after も旧モード用 (CSS で生成) -->

<!-- 新モード用 (常駐、初期 opacity:0) -->
<div class="sun-orb" aria-hidden="true"></div>
<!-- .sun-orb::before / ::after は新モード装飾 (corona, ray 等) -->
```

旧/新モード用要素は**両方とも常時 DOM に存在**させる。display:none 切替は transition が効かず NG。

### Step 2: 旧モード要素に opacity transition

```css
body::after{
  /* 既存の星モード装飾 */
  opacity: 1;
  transition: opacity 1.5s ease-out;
  animation: star-core 3.1s infinite, star-shimmer 1.7s infinite;
}
.star-aura{
  opacity: 1;
  transition: opacity 1.5s ease-out;
  animation: star-aura-breathe 5.3s infinite;
}
```

`will-change: opacity` を加えると GPU 合成レイヤで安定する (任意)。

### Step 3: 新モード要素に opacity transition (初期 0)

```css
.sun-orb{
  /* 新モード装飾 */
  opacity: 0;                        /* 初期は不可視 */
  transition: opacity 1.5s ease-out;
  animation: sun-core 4.3s infinite, sun-flicker 1.3s infinite;
}
.sun-orb::before{ /* corona / ray 等 */ }
.sun-orb::after{ /* halo */ }
```

### Step 4: モード切替トリガ class

JS は **body または ancestor に class を1つ付ける**だけ:

```js
revealBtn.addEventListener("click", () => {
  document.body.classList.add("tobi-raised");
});
```

### Step 5: class 経由で旧/新の opacity を反転

```css
/* tobi-raised: 星モード fade-out + 太陽モード fade-in (1.5s クロスフェード) */
body.tobi-raised::after{ opacity: 0 }
body.tobi-raised .star-aura{ opacity: 0 }
body.tobi-raised .sun-orb{ opacity: 1 }
```

→ Step 2/3 で仕込んだ `transition: opacity 1.5s ease-out` が発火し、両方が同時に 1.5s で入れ替わる。

### Step 6: prefers-reduced-motion 対応

motion 制限環境では transition 自体が無視されることがあるが、final 状態 (opacity:0/1) には到達するので機能上は問題なし。peak 値の見栄えだけ静止状態で保証しておく:

```css
@media (prefers-reduced-motion: reduce){
  body.tobi-raised .sun-orb{ animation: none; box-shadow: <peak値固定>; }
  body.tobi-raised .sun-orb::before{ opacity: 0.65 }
  body.tobi-raised .sun-orb::after{ opacity: 1.0; transform: <peak値固定> }
}
```

## Examples

### Example 1: cmd_238 星 → 太陽 1.5s クロスフェード

camp-schedule-app の「火種を掲げる」ボタンで星モード → 太陽モードへ切替。

```html
<div class="star-aura" aria-hidden="true"></div>
<div class="sun-orb" aria-hidden="true"></div>
```

```css
body::after{
  /* 星モード装飾 */
  transition: opacity 1.5s ease-out;
  animation: star-core 3.1s infinite, star-shimmer 1.7s infinite, star-flare 18s infinite;
}
.star-aura{
  transition: opacity 1.5s ease-out;
  animation: star-aura-breathe 5.3s infinite;
}
.sun-orb{
  opacity: 0;
  transition: opacity 1.5s ease-out;
  animation: sun-core 4.3s infinite, sun-flicker 1.3s infinite;
}

body.tobi-raised::after{ opacity: 0 }
body.tobi-raised .star-aura{ opacity: 0 }
body.tobi-raised .sun-orb{ opacity: 1 }
```

```js
revealBtn.addEventListener("click", () => {
  document.body.classList.add("tobi-raised");
});
```

→ クリック後、星3要素が 1.5s かけて消えながら、太陽3要素が同時に 1.5s かけて現れる。「唐突感ゼロ」体感達成。

### Example 2: ダーク / ライトテーマの背景アクセント切替

```html
<div class="theme-aurora-dark"></div>
<div class="theme-aurora-light"></div>
```

```css
.theme-aurora-dark{
  opacity: 1;
  transition: opacity 2s ease;
  animation: aurora-dark-flow 12s infinite;
}
.theme-aurora-light{
  opacity: 0;
  transition: opacity 2s ease;
  animation: aurora-light-flow 12s infinite;
}
body.theme-light .theme-aurora-dark{ opacity: 0 }
body.theme-light .theme-aurora-light{ opacity: 1 }
```

テーマトグル時に背景の aurora アニメごと滑らかに入れ替わる。

## Guidelines / Failure Modes

### keyframes 駆動中は transition 効かない

- 単一要素の `box-shadow` を `@keyframes` で常時上書きしている状態で `transition: box-shadow` を仕掛けても、keyframes 出力値が transition より優先 → カクッと切替
- 本スキルは「**transition は opacity だけにかけ、装飾内容は別レイヤに分離**」することでこの制約を回避する
- 「色だけ変えたい」なら CSS 変数差替方式 (`css-keyframes-themed-via-vars`) の方が単純

### z-index 設計

- 旧/新が同時に opacity:0.5 程度になる中間フレーム (約 0.75s 時点) で**重なる**
- z-index で意図した上下関係を確定させる (例: 旧 z:2 / 新 z:3 で新が上)
- 重なり時に「2つのグロー混合」で意外と良い見栄えになるケースもあるので、デザイン意図と整合確認

### opacity だけでは「サイズ移行」にならない

- 旧大 → 新小 で見た目を縮める移行をしたい場合、それぞれの要素が**最終形のサイズ**で存在しているので「サイズが滑らかに縮む」ことはない (旧が消えて新が現れるだけ)
- サイズも徐々に変えたいなら、新要素にも `transform: scale(...)` の transition を別途仕掛ける

### display:none との不整合

- 旧モード要素を「使わないとき display:none」にすると transition が効かず一瞬でカクッと消える
- 必ず `opacity:0 + pointer-events:none` で「見えないけど存在する」状態に保つ

### 1.5s より長いと editorial 品位低下

- 殿FB事例: クロスフェード 3-4秒は「もっさり」と感じる
- 1-2秒が editorial デザインの体感ベスト、1.5s ease-out 推奨デフォルト
- 「速さ」を出したいなら 0.6-0.8s ease-in-out

### 縮退の選択肢

- cmd_240 で本スキルは「より単純な CSS 変数差替方式 (`css-keyframes-themed-via-vars`)」に置換された
- 切替対象が「色 / サイズ / 透明度のみ」の場合、別レイヤ追加せずに済むため変数方式が優先
- 本スキルは「装飾の追加 (corona / ray 等の構造変化)」を伴う切替にこそ価値がある

## 入出力仕様

### 入力
- `old_mode_selectors` (CSS): 旧モード装飾 (1-N 要素 / 疑似要素)
- `new_mode_selectors` (CSS): 新モード装飾 (1-N 要素 / 疑似要素、初期 opacity:0)
- `trigger_class` (string): 切替を発火する class 名 (body または ancestor に付与)
- `crossfade_duration` (秒): 1-2秒推奨

### 出力
- 旧/新モード装飾の opacity が trigger_class 切替で同時に反転
- transition 1-2秒 ease-out で滑らかにクロスフェード
- アニメは旧/新それぞれが独立 keyframes で稼働継続

## Checklist

```
- [ ] 旧モード要素 / 新モード要素を独立した DOM ノードに分離
- [ ] 両方を常時 DOM に存在させる (display:none 不可)
- [ ] 旧モード要素に transition: opacity Xs ease-out
- [ ] 新モード要素に opacity:0 + transition: opacity Xs ease-out
- [ ] z-index で重なり時の上下関係を確定
- [ ] body or ancestor の class 切替で opacity 反転 ({old}=0, {new}=1)
- [ ] prefers-reduced-motion 対応 (animation:none + peak値固定)
- [ ] 1-2秒範囲の duration 採用 (editorial 品位)
```

## Related kaizen / commands

- 起源: kz_armyA_024 (家老A、cmd_238 sun-orb 実装、cmd_241 で skill 化)
- 採用: cmd_238 星 → 太陽 1.5s ease-out クロスフェード
- 縮退ケース: cmd_240 で「色のみ変更」の用途には CSS 変数差替方式 (将来 skill `css-keyframes-themed-via-vars`) に置換可能と判明、本スキルは「装飾構造が変わる切替」にこそ価値ありと改めて位置付け
