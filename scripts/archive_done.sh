#!/usr/bin/env bash
# ============================================================
# archive_done.sh — 完了済みコマンドをアーカイブに退避する
# ============================================================
# 用途: queue/*.yaml から status: done のエントリを
#       archive/commands.yaml に移動し、元ファイルを軽量化する。
#
# 使い方:
#   bash scripts/archive_done.sh              # 全キュー+ダッシュボードを一括アーカイブ
#   bash scripts/archive_done.sh --dry-run    # 何が移動されるか確認のみ
#   bash scripts/archive_done.sh --no-dashboard  # キューのみ（ダッシュボードスキップ）
#
# 対象ファイル:
#   1. queue/taishogun_to_shogun.yaml  → queue/archive/taishogun_commands.yaml
#   2. queue/armyA/shogun_to_karo.yaml → queue/armyA/archive/commands.yaml
#   3. queue/armyB/shogun_to_karo.yaml → queue/armyB/archive/commands.yaml
#   4. queue/armyC/shogun_to_karo.yaml → queue/armyC/archive/commands.yaml
#
# NOTE: tcmd_233 (2026-04-22) で旧 queue/taishogun_to_shinobi.yaml のアーカイブ経路は廃止。
#       既存の queue/archive/shinobi_commands.yaml は歴史資産として温存される。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DRY_RUN=false
WITH_DASHBOARD=true    # デフォルトでdashboardもアーカイブ
DASHBOARD_ONLY=false
NO_DASHBOARD=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --with-dashboard) WITH_DASHBOARD=true ;;
    --no-dashboard) WITH_DASHBOARD=false; NO_DASHBOARD=true ;;
    --dashboard-only) DASHBOARD_ONLY=true; WITH_DASHBOARD=true ;;
  esac
done

if [[ "$DRY_RUN" == true ]]; then
  echo "[DRY-RUN] アーカイブ対象の確認のみ。実際の移動は行いません。"
  echo ""
fi

# Python3でYAML処理（PyYAMLがなければ素のPythonパーサで処理）
PYTHON="python3"

# アーカイブ用ディレクトリ確保
mkdir -p "$BASE_DIR/queue/archive"
mkdir -p "$BASE_DIR/queue/armyA/archive"
mkdir -p "$BASE_DIR/queue/armyB/archive"
mkdir -p "$BASE_DIR/queue/armyC/archive"

# ============================================================
# archive_yaml: 1ファイル分のアーカイブ処理
# $1 = ソースYAML
# $2 = アーカイブ先YAML
# $3 = ラベル（表示用）
# ============================================================
archive_yaml() {
  local SRC="$1"
  local DST="$2"
  local LABEL="$3"

  if [[ ! -f "$SRC" ]]; then
    echo "[$LABEL] ソースなし: $SRC — スキップ"
    return
  fi

  # Pythonスクリプトで done エントリを分離
  $PYTHON - "$SRC" "$DST" "$DRY_RUN" "$LABEL" << 'PYEOF'
import sys, os, re, json
from datetime import datetime

src_path = sys.argv[1]
dst_path = sys.argv[2]
dry_run = sys.argv[3].lower() == "true"
label = sys.argv[4]

with open(src_path, 'r', encoding='utf-8') as f:
    content = f.read()

# --- 簡易YAMLパーサ ---
# queue: ブロック内の各 "- id:" エントリを分割する
# ヘッダー（queue: の前）とエントリ群を分離

# queue: の行を見つける
queue_match = re.search(r'^(queue:\s*\n)', content, re.MULTILINE)
if not queue_match:
    print(f"[{label}] queue: ブロックが見つかりません — スキップ")
    sys.exit(0)

header = content[:queue_match.start()]
queue_header = queue_match.group(1)
body = content[queue_match.end():]

# 各エントリを "  - id:" で分割
entries = re.split(r'(?=^  - id: )', body, flags=re.MULTILINE)
entries = [e for e in entries if e.strip()]

done_entries = []
keep_entries = []

for entry in entries:
    # status: done を検出
    if re.search(r'^\s+status:\s*(done|code_complete)\s*$', entry, re.MULTILINE):
        done_entries.append(entry)
    else:
        keep_entries.append(entry)

if not done_entries:
    print(f"[{label}] 完了済みエントリなし — スキップ")
    sys.exit(0)

print(f"[{label}] 完了: {len(done_entries)}件 / 残存: {len(keep_entries)}件")

if dry_run:
    for e in done_entries:
        id_match = re.search(r'id:\s*(\S+)', e)
        if id_match:
            print(f"  → アーカイブ対象: {id_match.group(1)}")
    sys.exit(0)

# --- アーカイブファイルに追記 ---
archive_header = f"""# ============================================================
# アーカイブ — 完了済みコマンド
# ============================================================
# 自動生成: archive_done.sh
# 最終更新: {datetime.now().strftime('%Y-%m-%d %H:%M')}

queue:
"""

if os.path.exists(dst_path):
    with open(dst_path, 'r', encoding='utf-8') as f:
        existing = f.read()
    # 既存の queue: ブロックの末尾に追記
    # 末尾の改行を整える
    existing = existing.rstrip() + '\n'
    for entry in done_entries:
        existing += entry
    with open(dst_path, 'w', encoding='utf-8') as f:
        f.write(existing)
else:
    with open(dst_path, 'w', encoding='utf-8') as f:
        f.write(archive_header)
        for entry in done_entries:
            f.write(entry)

# --- 元ファイルを書き換え（doneを除去）---
new_content = header + queue_header
for entry in keep_entries:
    new_content += entry

with open(src_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

# サイズ比較
src_size = os.path.getsize(src_path)
dst_size = os.path.getsize(dst_path)
print(f"  元ファイル: {src_size/1024:.1f}KB")
print(f"  アーカイブ: {dst_size/1024:.1f}KB")
print(f"  ✅ {len(done_entries)}件をアーカイブ完了")
PYEOF
}

echo "=========================================="
echo " archive_done.sh — 完了コマンドアーカイブ"
echo " $(date '+%Y-%m-%d %H:%M')"
echo "=========================================="
echo ""

# YAML キューアーカイブ（--dashboard-only 時はスキップ）
if [[ "$DASHBOARD_ONLY" == false ]]; then

# 1. 大将軍→将軍
archive_yaml \
  "$BASE_DIR/queue/taishogun_to_shogun.yaml" \
  "$BASE_DIR/queue/archive/taishogun_commands.yaml" \
  "大将軍→将軍"

# 2. 将軍A→家老A
archive_yaml \
  "$BASE_DIR/queue/armyA/shogun_to_karo.yaml" \
  "$BASE_DIR/queue/armyA/archive/commands.yaml" \
  "軍A(将軍→家老)"

# 3. 将軍B→家老B
archive_yaml \
  "$BASE_DIR/queue/armyB/shogun_to_karo.yaml" \
  "$BASE_DIR/queue/armyB/archive/commands.yaml" \
  "軍B(将軍→家老)"

# 4. 将軍C→家老C (tcmd_233 で旧「大将軍→忍頭」経路から移行)
archive_yaml \
  "$BASE_DIR/queue/armyC/shogun_to_karo.yaml" \
  "$BASE_DIR/queue/armyC/archive/commands.yaml" \
  "軍C(将軍→家老)"

echo ""

fi  # end DASHBOARD_ONLY check

# 5. ダッシュボードアーカイブ（デフォルトON、--no-dashboard で無効化）
if [[ "$WITH_DASHBOARD" == true ]]; then
  if [[ -f "$SCRIPT_DIR/archive_dashboard.sh" ]]; then
    echo "=========================================="
    echo " ダッシュボードアーカイブ"
    echo "=========================================="
    if [[ "$DRY_RUN" == true ]]; then
      bash "$SCRIPT_DIR/archive_dashboard.sh" --dry-run
    else
      bash "$SCRIPT_DIR/archive_dashboard.sh"
    fi
    echo ""
  else
    echo "⚠️ archive_dashboard.sh が見つかりません: $SCRIPT_DIR/archive_dashboard.sh — スキップ"
  fi
fi

echo "=========================================="
echo " 完了"
echo "=========================================="
