#!/usr/bin/env bash
# ============================================================
# task_stats.sh — タスク統計・Observability（軽量版）
# ============================================================
# 各軍のタスクYAML/レポートYAMLを走査し、統計情報を表示する。
#
# 使い方:
#   bash scripts/task_stats.sh                # 全軍統計
#   bash scripts/task_stats.sh --army armyA   # 軍A限定
#   bash scripts/task_stats.sh --json         # JSON出力（機械可読）
# ============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# ── オプション解析 ────────────────────────────────────
FILTER_ARMY=""
JSON_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --army) FILTER_ARMY="$2"; shift 2 ;;
    --json) JSON_MODE=true; shift ;;
    *) shift ;;
  esac
done

# ── YAML statusフィールド抽出 ──────────────────────────
get_status() {
  local file="$1"
  grep -m1 'status:' "$file" 2>/dev/null | sed 's/.*status:\s*//' | tr -d '"' | tr -d "'" | xargs
}

# ── タイムスタンプ抽出 ────────────────────────────────
get_timestamp() {
  local file="$1"
  grep -m1 'timestamp:' "$file" 2>/dev/null | sed 's/.*timestamp:\s*//' | tr -d '"' | tr -d "'" | xargs
}

# ── task_id抽出 ────────────────────────────────────────
get_task_id() {
  local file="$1"
  grep -m1 'task_id:' "$file" 2>/dev/null | sed 's/.*task_id:\s*//' | tr -d '"' | tr -d "'" | xargs
}

# ── 軍統計 ────────────────────────────────────────────
count_army_stats() {
  local army="$1"
  local task_dir="$BASE_DIR/queue/${army}/tasks"
  local report_dir="$BASE_DIR/queue/${army}/reports"

  local total=0 idle=0 assigned=0 in_progress=0 done=0 failed=0
  local reports_total=0 reports_done=0

  if [[ -d "$task_dir" ]]; then
    for f in "$task_dir"/ashigaru*.yaml; do
      [[ -f "$f" ]] || continue
      total=$((total + 1))
      local st
      st=$(get_status "$f")
      case "$st" in
        idle) idle=$((idle + 1)) ;;
        assigned) assigned=$((assigned + 1)) ;;
        in_progress) in_progress=$((in_progress + 1)) ;;
        done) done=$((done + 1)) ;;
        failed) failed=$((failed + 1)) ;;
      esac
    done
  fi

  if [[ -d "$report_dir" ]]; then
    for f in "$report_dir"/ashigaru*_report.yaml; do
      [[ -f "$f" ]] || continue
      reports_total=$((reports_total + 1))
      local rst
      rst=$(get_status "$f")
      [[ "$rst" == "done" ]] && reports_done=$((reports_done + 1))
    done
  fi

  echo "${army}|${total}|${idle}|${assigned}|${in_progress}|${done}|${failed}|${reports_total}|${reports_done}"
}

# ── 個別タスク一覧 ───────────────────────────────────
list_tasks() {
  local army="$1"
  local task_dir="$BASE_DIR/queue/${army}/tasks"

  if [[ ! -d "$task_dir" ]]; then
    return
  fi

  for f in "$task_dir"/ashigaru*.yaml "$task_dir"/*.yaml; do
    [[ -f "$f" ]] || continue
    # 重複排除（globが重なる場合）
    local basename_f
    basename_f=$(basename "$f")
    local worker="${basename_f%.yaml}"
    local task_id
    task_id=$(get_task_id "$f")
    local st
    st=$(get_status "$f")
    local ts
    ts=$(get_timestamp "$f")

    printf "  %-15s %-35s %-12s %s\n" "$worker" "${task_id:--}" "$st" "${ts:--}"
  done | sort -u
}

# ── メイン出力 ────────────────────────────────────────
NOW=$(date '+%Y-%m-%d %H:%M')
ARMIES=()

if [[ -n "$FILTER_ARMY" ]]; then
  ARMIES=("$FILTER_ARMY")
else
  [[ -d "$BASE_DIR/queue/armyA" ]] && ARMIES+=("armyA")
  [[ -d "$BASE_DIR/queue/armyB" ]] && ARMIES+=("armyB")
  [[ -d "$BASE_DIR/queue/armyC" ]] && ARMIES+=("armyC")
fi

if [[ "$JSON_MODE" == true ]]; then
  # JSON出力
  echo "{"
  echo "  \"timestamp\": \"$NOW\","
  echo "  \"armies\": {"
  first=true
  for army in "${ARMIES[@]}"; do
    IFS='|' read -r name total idle assigned in_prog done failed rtotal rdone <<< "$(count_army_stats "$army")"
    $first || echo ","
    first=false
    printf '    "%s": {"total":%d,"idle":%d,"assigned":%d,"in_progress":%d,"done":%d,"failed":%d,"reports":%d,"reports_done":%d}' \
      "$name" "$total" "$idle" "$assigned" "$in_prog" "$done" "$failed" "$rtotal" "$rdone"
  done
  echo ""
  echo "  }"
  echo "}"
  exit 0
fi

# テキスト出力
echo "=========================================="
echo " Task Statistics — ${NOW}"
echo "=========================================="
echo ""

GRAND_TOTAL=0
GRAND_DONE=0

for army in "${ARMIES[@]}"; do
  IFS='|' read -r name total idle assigned in_prog done failed rtotal rdone <<< "$(count_army_stats "$army")"
  GRAND_TOTAL=$((GRAND_TOTAL + total))
  GRAND_DONE=$((GRAND_DONE + done))

  echo "[$army] Tasks: ${total} | idle:${idle} assigned:${assigned} in_progress:${in_prog} done:${done} failed:${failed}"
  echo "        Reports: ${rtotal} (done: ${rdone})"
  list_tasks "$army"
  echo ""
done

echo "------------------------------------------"
echo "Grand Total: ${GRAND_TOTAL} tasks | ${GRAND_DONE} done"
