#!/usr/bin/env bash
# tcmd_356 / cmd_B123: FFmpeg フレーム抽出ラッパー
# Usage: extract_frames.sh <video.webm> <output_dir> [fps]
#   - 1秒ごと PNG 連番抽出 (default fps=1、家老B 採択)
#   - frame_001.png, frame_002.png, ... 形式
#   - 失敗時は exit code 非ゼロで Playwright スクリプトの early fail に連動
#
# 例:
#   extract_frames.sh reports/tcmd_356/playwright_evidence/video.webm \
#                     reports/tcmd_356/playwright_evidence/frames/

set -euo pipefail

VIDEO="${1:-}"
OUT_DIR="${2:-}"
FPS="${3:-1}"

if [ -z "$VIDEO" ] || [ -z "$OUT_DIR" ]; then
  echo "Usage: $0 <video.webm> <output_dir> [fps=1]" >&2
  exit 2
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "🚨 ffmpeg not found. Install: sudo apt install -y ffmpeg" >&2
  exit 3
fi

if [ ! -f "$VIDEO" ]; then
  echo "🚨 video file not found: $VIDEO" >&2
  exit 4
fi

mkdir -p "$OUT_DIR"

# tcmd_356 / cmd_B123: 家老B 採択 fps=1 (1秒ごと、家老B 採択シンプル)
# -y で出力上書き、-loglevel error で stderr 抑制 (Playwright 連携時の stdout 汚染防止)
ffmpeg -y -loglevel error -i "$VIDEO" -vf "fps=${FPS}" "${OUT_DIR%/}/frame_%03d.png"

# 抽出成果サマリ
COUNT=$(ls "${OUT_DIR%/}"/frame_*.png 2>/dev/null | wc -l)
echo "[extract_frames] video=$VIDEO out=$OUT_DIR fps=$FPS frames=$COUNT"

if [ "$COUNT" -lt 1 ]; then
  echo "🚨 frame extraction yielded zero frames" >&2
  exit 5
fi
