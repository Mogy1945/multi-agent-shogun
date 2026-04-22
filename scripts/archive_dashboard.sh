#!/usr/bin/env bash
# ============================================================
# archive_dashboard.sh — ダッシュボードの完了セクションをアーカイブ
# ============================================================
# 用途: dashboard_{armyA,armyB,armyC}.md から完了セクションを
#       dashboard_{name}_archive.md に移動し、元ファイルを軽量化する。
#       (tcmd_233 で旧 dashboard_shinobi.md → dashboard_armyC.md に改称)
#
# 使い方:
#   bash scripts/archive_dashboard.sh              # 全ダッシュボード処理
#   bash scripts/archive_dashboard.sh --dry-run    # プレビューのみ
#
# ルール:
#   - 「✅」を含む ## / ### セクション見出しを完了と判定
#   - 「🚨 要対応」セクションは絶対にアーカイブしない
#   - 「📊 統計」セクションは絶対にアーカイブしない

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
  esac
done

if [[ "$DRY_RUN" == true ]]; then
  echo "[DRY-RUN] アーカイブ対象の確認のみ。実際の移動は行いません。"
  echo ""
fi

PYTHON="python3"

# ============================================================
# archive_dashboard: 1ダッシュボードの処理
# $1 = ダッシュボードファイル
# $2 = アーカイブ先ファイル
# $3 = ラベル（表示用）
# ============================================================
archive_dashboard() {
  local SRC="$1"
  local DST="$2"
  local LABEL="$3"

  if [[ ! -f "$SRC" ]]; then
    echo "[$LABEL] ソースなし: $SRC — スキップ"
    return
  fi

  $PYTHON - "$SRC" "$DST" "$DRY_RUN" "$LABEL" << 'PYEOF'
import sys, os, re
from datetime import datetime

src_path = sys.argv[1]
dst_path = sys.argv[2]
dry_run = sys.argv[3].lower() == "true"
label = sys.argv[4]

with open(src_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# セクションを解析
# ## レベルのセクション → 次の ## まで
# ### レベルのセクション → 次の ## or ### まで
sections = []
current_section = None

for i, line in enumerate(lines):
    m = re.match(r'^(#{2,3})\s+(.+)', line)
    if m:
        if current_section is not None:
            current_section['end'] = i
            sections.append(current_section)
        current_section = {
            'level': len(m.group(1)),
            'title': m.group(2).strip(),
            'start': i,
            'end': len(lines),
        }

if current_section is not None:
    current_section['end'] = len(lines)
    sections.append(current_section)

# 保護対象（絶対にアーカイブしない）
PROTECTED_PATTERNS = ['\U0001f6a8', '要対応', '\U0001f4ca', '統計']

# 保護対象の ## セクションを特定
protected_ranges = set()
for sec in sections:
    if sec['level'] == 2 and any(p in sec['title'] for p in PROTECTED_PATTERNS):
        for i in range(sec['start'], sec['end']):
            protected_ranges.add(i)

# ✅ を含むセクションをアーカイブ対象に
archive_sections = []
for sec in sections:
    title = sec['title']
    # 保護範囲内のサブセクションはスキップ
    if sec['start'] in protected_ranges:
        continue
    # ✅ を含むセクション
    if '\u2705' in title:
        archive_sections.append(sec)

if not archive_sections:
    print(f"[{label}] アーカイブ対象なし — スキップ")
    sys.exit(0)

print(f"[{label}] アーカイブ対象: {len(archive_sections)}セクション")

if dry_run:
    for sec in archive_sections:
        line_count = sec['end'] - sec['start']
        print(f"  -> {'#' * sec['level']} {sec['title'][:60]} ({line_count}行)")
    sys.exit(0)

# アーカイブ対象の行番号セット
archive_line_set = set()
for sec in archive_sections:
    for i in range(sec['start'], sec['end']):
        archive_line_set.add(i)

# 元ダッシュボードから対象行を除去
keep_lines = []
for i, line in enumerate(lines):
    if i not in archive_line_set:
        keep_lines.append(line)

# 連続空行を2行以内に正規化
normalized = []
blank_count = 0
for line in keep_lines:
    if line.strip() == '':
        blank_count += 1
        if blank_count <= 2:
            normalized.append(line)
    else:
        blank_count = 0
        normalized.append(line)

# アーカイブ先に追記
archive_content = []
archive_content.append(f"\n---\n")
archive_content.append(f"# アーカイブ — {datetime.now().strftime('%Y-%m-%d %H:%M')}\n\n")
for sec in archive_sections:
    for i in range(sec['start'], sec['end']):
        archive_content.append(lines[i])

if os.path.exists(dst_path):
    with open(dst_path, 'a', encoding='utf-8') as f:
        f.writelines(archive_content)
else:
    with open(dst_path, 'w', encoding='utf-8') as f:
        f.write(f"# ダッシュボード アーカイブ\n\n")
        f.write(f"> 自動生成: archive_dashboard.sh\n\n")
        f.writelines(archive_content)

# 元ファイルを書き換え
with open(src_path, 'w', encoding='utf-8') as f:
    f.writelines(normalized)

# サイズ比較
src_size = os.path.getsize(src_path)
dst_size = os.path.getsize(dst_path)
archived_lines = sum(sec['end'] - sec['start'] for sec in archive_sections)
print(f"  アーカイブ: {archived_lines}行 -> {os.path.basename(dst_path)}")
print(f"  元ファイル: {src_size/1024:.1f}KB")
print(f"  アーカイブ先: {dst_size/1024:.1f}KB")
print(f"  完了: {len(archive_sections)}セクションをアーカイブ")
PYEOF
}

echo "=========================================="
echo " archive_dashboard.sh — ダッシュボードアーカイブ"
echo " $(date '+%Y-%m-%d %H:%M')"
echo "=========================================="
echo ""

# 1. 軍A
archive_dashboard \
  "$BASE_DIR/dashboard_armyA.md" \
  "$BASE_DIR/dashboard_armyA_archive.md" \
  "軍A"

# 2. 軍B
archive_dashboard \
  "$BASE_DIR/dashboard_armyB.md" \
  "$BASE_DIR/dashboard_armyB_archive.md" \
  "軍B"

# 3. 軍C (tcmd_233 で旧忍衆 dashboard_shinobi.md から改称)
archive_dashboard \
  "$BASE_DIR/dashboard_armyC.md" \
  "$BASE_DIR/dashboard_armyC_archive.md" \
  "軍C"

echo ""
echo "=========================================="
echo " 完了"
echo "=========================================="
