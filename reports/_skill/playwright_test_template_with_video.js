/**
 * playwright_test_template_with_video.js
 * tcmd_356 / cmd_B123: 検証強化基盤 — Playwright 動画録画+FFmpeg フレーム抽出+md5 突合
 *
 * 目的: 各 tcmd take_screenshots.js から require('./_skill/playwright_test_template_with_video') して
 *       launchWithVideo / extractFrames / md5DistinctOrFail を流用. 再実装ゼロ.
 *
 * 使い方 (各 tcmd_NNN の take_screenshots.js から):
 *   const { launchWithVideo, extractFrames, md5DistinctOrFail } = require('../../_skill/playwright_test_template_with_video');
 *   const { browser, ctx, page, videoDir } = await launchWithVideo({ evidenceDir: EVIDENCE_DIR });
 *   // ... テスト ...
 *   await ctx.close();   // ← video finalize (重要)
 *   await browser.close();
 *   await extractFrames({ videoDir, outDir: `${EVIDENCE_DIR}/frames`, fps: 1 });
 *   const md5Result = md5DistinctOrFail([scene1, scene2, scene3]);
 *
 * 設計原則 (家老B 採択):
 *   - size 640x360 で 30MB 以下容量制限 (KZ-184 deviceScaleFactor 2 はそのまま、ビデオサイズだけ縮小)
 *   - fps 1 で 1秒ごと PNG 抽出 (シンプル)
 *   - md5 突合 require('crypto') early fail 機構継続適用 (tcmd_354 第15弾 kaizen)
 *   - 動作証明 banner DOM 強制パターンは各 tcmd 側で挿入 (本雛形は枠組のみ)
 */

const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const { execFileSync } = require('child_process');
const { chromium } = require('/home/shuirein928/.npm/_npx/e41f203b7505f1fb/node_modules/playwright');

/**
 * Playwright を recordVideo オプション付きで起動.
 *
 * @param {Object} opts
 * @param {string} opts.evidenceDir   - 各 tcmd の playwright_evidence ディレクトリ (動画はこの直下 video/ に出力)
 * @param {Object} [opts.viewport]    - ビューポート (default 1280x800、KZ-184 維持)
 * @param {Object} [opts.videoSize]   - 動画サイズ (default 640x360、家老B 採択 30MB 以下)
 * @param {boolean} [opts.hasTouch]   - touch 対応 (tcmd_346 SP D-pad 等)
 * @param {boolean} [opts.isMobile]   - mobile mode (デバイス判定)
 * @returns {{browser, ctx, page, videoDir, errors}} — errors は pageerror/console_error 配列
 */
async function launchWithVideo(opts) {
  const evidenceDir = opts.evidenceDir;
  if (!evidenceDir) throw new Error('launchWithVideo: evidenceDir is required');
  const viewport = opts.viewport || { width: 1280, height: 800 };
  const videoSize = opts.videoSize || { width: 640, height: 360 };  // 家老B 採択 30MB 以下
  const videoDir = path.join(evidenceDir, 'video');
  fs.mkdirSync(videoDir, { recursive: true });
  const browser = await chromium.launch({
    headless: true,
    args: ['--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream'],
  });
  const ctxOpts = {
    permissions: ['microphone'],
    viewport,
    recordVideo: { dir: videoDir, size: videoSize },  // ★ recordVideo 有効化 (家老B 採択 30MB 以下)
  };
  if (opts.hasTouch) ctxOpts.hasTouch = true;
  if (opts.isMobile) ctxOpts.isMobile = true;
  const ctx = await browser.newContext(ctxOpts);
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push({ type: 'pageerror', message: e.message }));
  page.on('console', msg => { if (msg.type() === 'error') errors.push({ type: 'console_error', message: msg.text() }); });
  page.on('dialog', d => d.accept());
  return { browser, ctx, page, videoDir, errors };
}

/**
 * テスト終了後に video.webm を取得+frames/ に PNG 連番抽出.
 *
 * @param {Object} opts
 * @param {string} opts.videoDir   - launchWithVideo 戻り値の videoDir (video.webm が出力されているディレクトリ)
 * @param {string} opts.outDir     - フレーム出力先 (例 reports/tcmd_NNN/playwright_evidence/frames/)
 * @param {number} [opts.fps]      - 抽出 fps (default 1、家老B 採択)
 * @returns {{videoPath, frameCount, framePaths}} — 抽出成果
 */
function extractFrames(opts) {
  const { videoDir, outDir, fps = 1 } = opts;
  if (!videoDir || !outDir) throw new Error('extractFrames: videoDir and outDir required');
  // video.webm を videoDir 配下から検出 (Playwright は <random>.webm 命名)
  const candidates = fs.readdirSync(videoDir).filter(f => f.endsWith('.webm'));
  if (candidates.length === 0) {
    throw new Error('extractFrames: no .webm video found in ' + videoDir);
  }
  const videoPath = path.join(videoDir, candidates[0]);
  const sizeBytes = fs.statSync(videoPath).size;
  if (sizeBytes > 30 * 1024 * 1024) {
    console.warn('🚨 video size > 30MB:', (sizeBytes / 1024 / 1024).toFixed(1) + 'MB');
  }
  fs.mkdirSync(outDir, { recursive: true });
  // scripts/extract_frames.sh 呼出 (ffmpeg ラッパー、エラー時 throw)
  const scriptPath = '/home/shuirein928/multi-agent-shogun/scripts/extract_frames.sh';
  try {
    execFileSync(scriptPath, [videoPath, outDir, String(fps)], { stdio: 'inherit' });
  } catch (e) {
    throw new Error('extractFrames: ffmpeg failed (ensure ffmpeg installed: sudo apt install -y ffmpeg)\n' + e.message);
  }
  const framePaths = fs.readdirSync(outDir).filter(f => f.startsWith('frame_') && f.endsWith('.png')).sort();
  return { videoPath, videoSizeMB: +(sizeBytes / 1024 / 1024).toFixed(2), frameCount: framePaths.length, framePaths };
}

/**
 * md5 突合 — 同一 hash 検出時 throw (early fail).
 * tcmd_354 第15弾 kaizen 継続適用.
 *
 * @param {string[]} files - 比較対象ファイルパス配列 (シーン PNG または frame サンプル)
 * @returns {{md5Map, distinct, collisions}} — distinct=true なら全 unique、false なら collisions 配列に重複ペア
 */
function md5DistinctOrFail(files) {
  const md5Map = {};
  for (const f of files) {
    if (!fs.existsSync(f)) {
      md5Map[f] = null;
      continue;
    }
    md5Map[f] = crypto.createHash('md5').update(fs.readFileSync(f)).digest('hex');
  }
  const values = Object.values(md5Map);
  const distinct = new Set(values).size === values.length && values.every(h => h !== null);
  const collisions = [];
  const keys = Object.keys(md5Map);
  for (let i = 0; i < values.length; i++) {
    for (let j = i + 1; j < values.length; j++) {
      if (values[i] !== null && values[i] === values[j]) {
        collisions.push({ a: keys[i], b: keys[j], hash: values[i] });
      }
    }
  }
  if (!distinct) {
    console.error('🚨 MD5 COLLISION DETECTED — KZ-189 第14弾失敗パターン再発、early fail');
    console.error(JSON.stringify(collisions, null, 2));
    // throw でテスト失敗を強制 (各 tcmd の all_pass=false に連動、process.exit(1) は呼出側採択)
    throw new Error('md5DistinctOrFail: collisions detected (' + collisions.length + ')');
  }
  return { md5Map, distinct, collisions };
}

/**
 * 動作証明 banner DOM (tcmd_354 第15弾 kaizen 流用)
 * page.evaluate 内で挿入する場合は呼出側で:
 *   await page.evaluate((id, text, color) => { ... }, 'banner_id', 'message', '#1565c0');
 * を直接書く方が柔軟. 本関数は server-side 呼出ヘルパとしてラベル仕様だけ提供.
 */
const PROOF_BANNER_STYLE = 'position:fixed;top:60px;left:50%;transform:translateX(-50%);background:rgba(33,150,243,0.95);color:#fff;padding:12px 18px;border-radius:6px;font-family:monospace;font-size:13px;font-weight:700;z-index:9999;border:2px solid #1565c0;max-width:90%;';

module.exports = {
  launchWithVideo,
  extractFrames,
  md5DistinctOrFail,
  PROOF_BANNER_STYLE,
};
