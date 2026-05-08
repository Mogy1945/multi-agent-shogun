# 大将軍/家老B/将軍B 判定プロトコル拡張 (動画+フレーム)

> tcmd_356 / cmd_B123 で導入. 殿FB「playwright のユーザー目線操作で最適か?」「本当にユーザーのように操作できる手段は?」(案A 動画録画+大将軍視聴) への直撃修正.

## 背景

`take_screenshots.js` の単発スクショは「決定的な瞬間」だけを切り取る方式で、

- 連続動作 (例: ハイタッチ送信 → 受信 → 成立) の中間状態が見えない
- 動作証明 banner DOM を挿入してもタイミングずれが起きやすい
- KZ-189 第14弾 (tcmd_352) で「page.evaluate のフラグ変更が DOM 同期せず screenshot が前画像と同一 (md5 衝突)」が露呈

→ **動画録画+1秒ごと PNG 抽出**で連続動作を残し、家老B/将軍B/大将軍が前後フレームを Read tool 目視できるようにする.

## 構成

| 要素 | 場所 | 役割 |
| --- | --- | --- |
| 雛形 | `reports/_skill/playwright_test_template_with_video.js` | `launchWithVideo` / `extractFrames` / `md5DistinctOrFail` を提供 |
| ffmpeg ラッパー | `scripts/extract_frames.sh` | `ffmpeg -i video.webm -vf 'fps=1' frames/frame_%03d.png` |
| 出力 | `reports/tcmd_***/playwright_evidence/video/<random>.webm` | Playwright recordVideo (640x360, 30MB 以下) |
| 出力 | `reports/tcmd_***/playwright_evidence/frames/frame_NNN.png` | 1秒ごと PNG 連番 |

## 各 tcmd test スクリプトでの使い方

```js
const { launchWithVideo, extractFrames, md5DistinctOrFail } =
  require('/home/shuirein928/multi-agent-shogun/reports/_skill/playwright_test_template_with_video');

const EVIDENCE_DIR = '/home/shuirein928/multi-agent-shogun/reports/tcmd_357/playwright_evidence';

(async () => {
  const { browser, ctx, page, videoDir, errors } = await launchWithVideo({ evidenceDir: EVIDENCE_DIR });
  await page.goto('http://localhost:8000/?mock=1&name=inmogy&v=' + Date.now());
  // ... 通常のテスト (動作証明 banner DOM 挿入は引き続き各シーン側で行う) ...
  await ctx.close();   // ← この瞬間に video.webm が finalize される (重要)
  await browser.close();

  // フレーム抽出 (fps=1)
  const ext = extractFrames({
    videoDir,
    outDir: EVIDENCE_DIR + '/frames',
    fps: 1,
  });
  console.log('[video]', ext.videoPath, ext.videoSizeMB + 'MB', ext.frameCount + ' frames');

  // md5 突合 (シーン PNG or 抽出フレーム、distinct でなければ throw)
  md5DistinctOrFail([
    EVIDENCE_DIR + '/scene_a.png',
    EVIDENCE_DIR + '/scene_b.png',
    EVIDENCE_DIR + '/scene_c.png',
  ]);
})();
```

## 大将軍/家老B/将軍B 判定プロトコル

### 1. 単発シーン (従来通り、KZ-188 改良)
- `scene_*.png` を Read tool で目視
- 動作証明 banner DOM が画面に映っていることを確認
- md5 突合で all distinct (kaizen 継続適用)

### 2. 連続動作 (本tcmd で追加)
- `frames/frame_NNN.png` から該当時間帯の連続フレームを 3-5 枚 Read tool で目視
- 例: 「H キー押下 → 相手 hightouch_received → H 応答 → 成立 🤝」を 5秒間 5枚で確認
- 単発スクショで確信が持てないときのバックアップ証拠として運用

### 3. 殿実機判定との二重チェック
- 動画は家老B/将軍B/大将軍の事前確認用
- 最終判定は殿実機操作 (Vercel 本番デプロイ後)
- 動画で「ここで状態が変わるはず」が見えてれば、実機との差分は「描画のキャッシュ問題」ではなく「ロジック問題」と切り分けられる

## ffmpeg 環境セットアップ (初回のみ)

```bash
# WSL Ubuntu
sudo apt install -y ffmpeg
ffmpeg -version
```

家老B が `which ffmpeg` で未インストールを検出したら、報告 YAML に「sudo apt install -y ffmpeg を殿に !bash 依頼」を明示すること.

## 容量制御

- recordVideo の `size: { width: 640, height: 360 }` で 30MB 以下が目安 (家老B 採択)
- 4K 録画禁止 (容量爆発防止)
- 長時間テスト (5分超) でも 640x360 なら ~15-20MB 程度
- frames/ は fps=1 なので大幅削減 (動画 20MB → 全 frame 合計 ~5MB)

## 失敗時の honest_assessment

tcmd_354 / tcmd_355 で確立された KZ-189 流儀を継承:

- ffmpeg がインストールされてない → 殿に依頼明示 (「環境依存 caveat」)
- video が 30MB 超え → サイズ警告ログ+report YAML に記録
- frame 抽出 0 枚 → ffmpeg 失敗、test 失敗扱い (extract_frames.sh exit 5)
- md5 衝突検出 → throw で early fail (各 tcmd の all_pass=false に連動)

failure-driven trust 精神 (honest is the only metric) を継続.
