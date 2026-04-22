---
name: css-keyframes-themed-via-vars
description: CSS @keyframes 内に `var(--*)` を直接展開し、`:root` と `.modifier-class` で変数値だけを差替えることで、keyframes 不変・要素追加なしにモード切替を表現するスキル。装飾構造が変わらず色/サイズ/透明度のみ変える用途で、css-crossfade-via-dual-pseudo より行数・DOMノード共に圧倒的に少なく済む
---

# CSS Keyframes Themed via Vars - 変数差替方式テーマ切替スキル

## Overview

CSS `@keyframes` 駆動の装飾要素 (pulse / glow / breathe / shimmer 等) のモード切替で、**装飾の構造 (要素・疑似要素・keyframes 名)** が変わらず、**値 (色・サイズ・透明度)** だけが変わる場合は、本スキルが最も単純かつ低コストの設計パターン。

仕組み:
1. `:root` に装飾パラメータを CSS 変数として集約 (色・blur 量・spread 量・α・scale 値等)
2. `@keyframes` 内のリテラル値を `var(--*)` に置換 — keyframes 自体は **モードを問わず1つ**
3. `body.modifier-class` (または ancestor) で **変数のみを上書き** — keyframes は再定義しない
4. ブラウザは class 切替の瞬間から各 keyframes イテレーション (3-5秒周期) で新しい変数値を読み、徐々に新ピーク値が出力される → **自然な視覚遷移**

cmd_240 で `css-crossfade-via-dual-pseudo` (cmd_238) からの縮退として採用、`assets/css/style.css` で **-86 行純減 / 位置 0px 差 / ray 全削除** を達成。装飾構造が変わらない用途には本スキルを最優先。

## When to Use

- CSS `@keyframes` の peak 値・色・サイズだけをモード切替したい
- 装飾の **位置・形・要素構成は変えない** (= 変えなくてよい / 変えてはいけない)
- DOM ノード追加 / 疑似要素追加 / keyframes 追加を**避けたい** (行数・複雑性低減)
- transition (opacity 等) の crossfade ですら不要、「class 切替後の自然な keyframes 進行」で見栄え遷移が成立する用途
- 既存 keyframes アニメ (organic / breathing motion 等) を**そのまま継承**したい

逆に、装飾の**構造そのもの** (corona 追加、ray 表示、形状 radius 変化、要素追加) が変わるならば `css-crossfade-via-dual-pseudo` の方が適切。

## Instructions

### Step 1: 装飾パラメータを抽出して `:root` に集約

既存 CSS の `@keyframes` 内に書かれている色・blur・spread・α・scale 等のリテラル値を、変数名で抽出して `:root` に集約する。

```css
/* Before: keyframes 内にリテラル値が散在 */
@keyframes star-core{
  0%   { box-shadow: rgba(245,239,226,0.55) 0 0 12px 0, rgba(232,106,60,0.18) 0 0 8px 0 }
  20%  { box-shadow: rgba(245,239,226,1.0)  0 0 60px 3px, rgba(232,106,60,0.45) 0 0 32px 0 }
  100% { box-shadow: rgba(245,239,226,0.55) 0 0 12px 0, rgba(232,106,60,0.18) 0 0 8px 0 }
}
```

```css
/* After: :root に集約 */
:root{
  --star-core-rgb: 245,239,226;
  --star-glow-rgb: 232,106,60;
  --star-core-blur-max: 60px;
  --star-core-spread-max: 3px;
  --star-glow-alpha-max: 0.45;
}
```

抽出原則: **モード切替で変えたい値**だけを変数化する。固定の transform-origin や easing 等は変数化不要。

### Step 2: `@keyframes` 内のリテラルを `var()` で置換

```css
@keyframes star-core{
  0%   { box-shadow: rgba(var(--star-core-rgb),0.55) 0 0 12px 0,
                     rgba(var(--star-glow-rgb),0.18) 0 0 8px 0 }
  20%  { box-shadow: rgba(var(--star-core-rgb),1.0)
                     0 0 var(--star-core-blur-max) var(--star-core-spread-max),
                     rgba(var(--star-glow-rgb),var(--star-glow-alpha-max)) 0 0 32px 0 }
  100% { box-shadow: rgba(var(--star-core-rgb),0.55) 0 0 12px 0,
                     rgba(var(--star-glow-rgb),0.18) 0 0 8px 0 }
}
```

**重要**: `rgba(R,G,B,A)` の `R,G,B` 部分はカンマ区切りで `var()` 展開可能 (`rgba(var(--rgb), 0.5)` 形式)。これにより α だけは別変数として独立可変にできる (色とαの分離)。

### Step 3: モード切替トリガ class で**変数のみ上書き**

```css
body.tobi-raised{
  --star-core-rgb: 217,74,31;          /* 白系 → 赤系 */
  --star-glow-rgb: 232,106,60;
  --star-core-blur-max: 110px;          /* 60px → 110px (光が広がる) */
  --star-core-spread-max: 6px;          /* 3px → 6px */
  --star-glow-alpha-max: 0.85;          /* 0.45 → 0.85 (より濃い) */
}
```

**keyframes は再定義しない**。class セレクタが変数を上書き → 同じ keyframes が新しいピーク値を出力するだけ。

### Step 4: トリガ JS

```js
revealBtn.addEventListener("click", () => {
  document.body.classList.add("tobi-raised");
});
```

### Step 5: 自然な視覚遷移の保証

class 切替の瞬間に変数値は即時に置換されるが、**現在の keyframes イテレーションの進行に応じて出力値が反映される** ため、視覚上は次の keyframes 周期 (3-5秒) かけて自然に新ピークへ遷移する。

明示的な `transition` 不要。dual-element の opacity crossfade も不要。これがこのスキルの最大の利点。

### Step 6: prefers-reduced-motion 対応

motion 制限環境でも変数は機能する。`animation:none` で keyframes を止めても、`box-shadow` リテラルを `var()` で書いておけばモード切替時の peak 値が静止状態でも反映される:

```css
@media (prefers-reduced-motion: reduce){
  body::after{
    animation: none;
    box-shadow: rgba(var(--star-core-rgb),1.0)
                0 0 var(--star-core-blur-max) var(--star-core-spread-max),
                rgba(var(--star-glow-rgb),var(--star-glow-alpha-max)) 0 0 32px 0;
  }
}
```

→ 一つの宣言で星モード・太陽モード両方の静止 peak 値を表現可能。

## Examples

### Example 1: cmd_240 星 → 赤オレンジ拡大化 (本スキル起源)

camp-schedule-app で殿FB「太陽は別位置じゃなくて、元の星を赤オレンジに広げて欲しい。線いらない」を受け、前タスク cmd_238 の `sun-orb` 別レイヤ + crossfade 方式 (`css-crossfade-via-dual-pseudo`) を**全廃**し、本スキルに縮退。

```css
:root{
  --ember-deep:#D94A1F;
  --star-core-rgb:245,239,226;       /* 星モード: 白系 */
  --star-glow-rgb:232,106,60;
  --star-core-blur-max:60px;
  --star-core-spread-max:3px;
  --star-glow-alpha-max:0.45;
  --halo-scale-min:0.85;
  --halo-scale-max:1.18;
  --halo-opacity-max:1.0;
  --halo-bg:radial-gradient(circle, rgba(245,239,226,0.18) 0%, rgba(232,106,60,0.10) 40%, rgba(245,239,226,0) 72%);
}

@keyframes star-core{
  0%, 100% { box-shadow: rgba(var(--star-core-rgb),0.55) 0 0 12px 0, ... }
  20%      { box-shadow: rgba(var(--star-core-rgb),1.0)
                          0 0 var(--star-core-blur-max) var(--star-core-spread-max),
                          rgba(var(--star-glow-rgb),var(--star-glow-alpha-max)) 0 0 32px 0 }
}
@keyframes star-aura-breathe{
  0%, 100% { transform: translate(-50%,-50%) scale(var(--halo-scale-min)); opacity: 0.6 }
  50%      { transform: translate(-50%,-50%) scale(var(--halo-scale-max));
             opacity: var(--halo-opacity-max) }
}
.star-aura{ background: var(--halo-bg); animation: star-aura-breathe 5.3s infinite }

body.tobi-raised{
  --star-core-rgb:217,74,31;          /* 赤系へ差替 */
  --star-glow-rgb:232,106,60;
  --star-core-blur-max:110px;          /* 拡大 */
  --star-core-spread-max:6px;
  --star-glow-alpha-max:0.85;
  --halo-scale-min:0.95;
  --halo-scale-max:1.32;
  --halo-opacity-max:1.0;
  --halo-bg:radial-gradient(circle, rgba(232,106,60,0.55) 0%, rgba(217,74,31,0.32) 40%, rgba(217,74,31,0) 75%);
}
```

成果:
- `style.css` **-86 行純減** (cmd_238 の sun-orb 関連 5 keyframes / 4 selectors / mobile media を全廃)
- 位置差 **0px** (`getBoundingClientRect` で body::after の x/y/width/height 完全一致)
- ray 削除完全 (`querySelectorAll('svg, [class*=ray]')` = 0)
- 既存 4 アニメ (star-core / star-shimmer / star-flare / star-aura-breathe) すべて稼働継続
- HTML から `<div class="sun-orb">` 削除のみ (1行)
- JS 無変更 (cmd_238 の `body.classList.add('tobi-raised')` をそのまま継承)

### Example 2: ダーク/ライトテーマの背景アクセント

```css
:root{
  --aurora-rgb-1: 80,140,200;
  --aurora-rgb-2: 150,80,200;
  --aurora-alpha-max: 0.6;
}
@keyframes aurora-flow{
  0%, 100% { background: radial-gradient(rgba(var(--aurora-rgb-1),0.2), transparent) }
  50%      { background: radial-gradient(rgba(var(--aurora-rgb-2),var(--aurora-alpha-max)), transparent) }
}
body.theme-light{
  --aurora-rgb-1: 240,200,150;
  --aurora-rgb-2: 220,180,120;
  --aurora-alpha-max: 0.4;
}
```

`aurora-flow` keyframes は1つ、テーマ切替は変数差替のみ。

### Example 3: ボタンの hover ピーク強度をテーマ別に変更

```css
:root{ --pulse-scale-max: 1.05; --pulse-shadow-max: 8px }
@keyframes btn-pulse{
  50% { transform: scale(var(--pulse-scale-max));
        box-shadow: 0 0 var(--pulse-shadow-max) currentColor }
}
.btn--bold{ --pulse-scale-max: 1.12; --pulse-shadow-max: 16px }
```

同じ pulse keyframes を `.btn--bold` で強化版に変身。

## Guidelines / Failure Modes

### `var()` 展開できない CSS プロパティに注意

- `animation-name` や `animation-timing-function` 等の **アニメ駆動側プロパティ** は `var()` 展開可能だが、現実的には `:root` で切替えるとアニメ自体が再起動して見栄えが乱れる
- 本スキルは **値 (色 / サイズ / α / scale 等)** だけを変数化する想定。`animation` プロパティは変数化しない

### `rgba()` 内の RGB 部分を変数化する書式

- `rgba(245,239,226,0.5)` → `rgba(var(--rgb),0.5)` (var の中身は `245,239,226` のカンマ込み3値)
- これは `rgba(R,G,B,A)` の関数構文がカンマ展開を許容するため成立。`rgb(var(--rgb))` も可
- α まで変数化したいなら `rgba(var(--rgb), var(--alpha))` で完全分離

### `radial-gradient` 等の文字列全体を変数化する場合

- 細かいパラメータ (色stop位置等) を全部変数化すると行数爆発 → グラデーション**全体を1変数**にまとめる方がシンプル
- 例: `--halo-bg: radial-gradient(circle, rgba(232,106,60,0.55) 0%, rgba(217,74,31,0.32) 40%, transparent 75%)`
- 切替先も同形式の文字列を `body.tobi-raised{ --halo-bg: ... }` で差替

### 「いきなりピークが変わる」体感問題

- class 切替の瞬間、**ちょうど peak 値を出力中の keyframes** がある場合、その瞬間に値が飛ぶ (透明度 0.45 → 0.85 等)
- これを避けたい場合は body 自体に `transition: --star-core-blur-max 1.5s ease` 等の CSS 変数 transition を仕掛ける (ブラウザ対応要件確認、`@property` 宣言推奨)
- ただし殿FBによれば cmd_240 では「自然な keyframes 周期での進行で十分滑らか」と確認済 — 多くの場合は不要

### CSS 変数のスコープ汚染

- `:root` に過剰に変数を盛ると意図しないセレクタで継承される可能性
- 名前空間プレフィックス (`--star-`, `--halo-`, `--aurora-` 等) を付けて衝突を防ぐ
- 特定要素スコープに閉じたいなら `:root` ではなく `body::after` や `.star-aura` 直下に書く方法もあるが、`body.modifier-class` での上書きが効かなくなるので注意

### 縮退判定 (本スキル vs crossfade-dual-pseudo)

| 切替対象 | 本スキル | crossfade-dual-pseudo |
|---------|---------|----------------------|
| 色のみ | ◎ | △ (過剰) |
| 色 + サイズ | ◎ | △ |
| 色 + 透明度 | ◎ | △ |
| 装飾追加 (corona / ray 等) | ✕ | ◎ |
| 形状変化 (radius / clip-path) | △ | ◎ |
| 別 keyframes 必要 | ✕ | ◎ |

「装飾構造が変わらない」なら本スキル一択。

## 入出力仕様

### 入力
- `keyframes_definitions` (CSS): リテラル値を含む既存 @keyframes 群
- `var_extraction_targets` (list): 変数化したいリテラル値のリスト (色 / blur / spread / α / scale 等)
- `mode_classes` (dict): `{class名: {変数名: 新値}}` 形式の上書き辞書

### 出力
- `:root` に集約された変数定義
- `var()` 展開された keyframes (モードを問わず単一定義)
- `.modifier-class` 単位の変数上書きセレクタ群
- 行数純減 (例: cmd_240 で -86 行)、DOM ノード追加なし

## Checklist

```
- [ ] keyframes 内のリテラル値を抽出して :root に集約
- [ ] keyframes 内のリテラルを var() で置換 (rgba は RGB,A 分離)
- [ ] modifier class で変数のみ上書き (keyframes 再定義しない)
- [ ] DOM ノード追加なし、疑似要素追加なし、keyframes 追加なしを確認
- [ ] prefers-reduced-motion 対応 (animation:none + var() peak 値)
- [ ] 「自然な keyframes 周期での値遷移」で十分滑らかか視認確認
- [ ] (要なら) CSS 変数 transition / @property で滑らか化
- [ ] 行数純減 / 位置差 0px / 余計な要素削除を計測
```

## Related kaizen / commands

- 起源: kz_armyA_025 (家老A、cmd_240 派生、cmd_241 で skill 化)
- 採用実績:
  - cmd_240: 星モード → 赤オレンジ拡大化 (cmd_238 の sun-orb crossfade 方式から縮退)
    - `style.css` -86 行純減 (sun-orb 全廃)
    - `index.html` `<div class="sun-orb">` 削除1行
    - 位置差 0px (body::after `getBoundingClientRect` 完全一致)
    - ray 全削除 (`querySelectorAll('svg, [class*=ray]')` = 0)
    - 既存 4 アニメ稼働継続 (star-core / star-shimmer / star-flare / star-aura-breathe)
    - JS 無変更
- 関連スキル:
  - `css-crossfade-via-dual-pseudo`: 装飾構造が変わる切替に使用 (cmd_238)
  - `playwright-animation-pause`: 本スキル切替後の peak 値検証に使用 (cmd_240 で本番完全一致確認)
