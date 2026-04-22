#!/usr/bin/env bash
# =============================================================
# hook_report_notify.sh — PostToolUse Hook: YAML自動通知
# =============================================================
# 以下のパターンを検知し、上官にtmux send-keysで自動通知する。
#
# (1) 足軽がreport.yamlを書いた → 家老に通知
# (2) 足軽がタスクYAMLのstatusをdoneに更新 → 家老に通知 [PoC]
# (3) 家老がshogun_to_karo.yamlのstatusをdoneに更新 → 将軍に通知 [PoC]
#
# 入力: stdin（Claude Code Hooks APIのJSON）
# 発火条件: PostToolUse Write|Edit
# =============================================================

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
STATE_DIR="/tmp/hook_yaml_status"
mkdir -p "$STATE_DIR"

# stdin からJSON入力を読み取り
INPUT=$(cat)

# file_path を抽出（python3でJSON解析。jq非依存）
FILE_PATH=$(python3 -c "
import json, sys
try:
    data = json.loads(sys.argv[1])
    fp = data.get('tool_input', {}).get('file_path', '')
    print(fp)
except:
    print('')
" "$INPUT" 2>/dev/null)

# file_path が空なら終了
[ -z "$FILE_PATH" ] && exit 0

# --- status:done 検知ヘルパー ---
# ファイルのYAML statusフィールドを読み取る
# 状態ファイルと比較し、doneへの遷移時のみtrueを返す
check_status_done() {
  local file="$1"
  local state_key="$2"
  local state_file="$STATE_DIR/$state_key"

  # ファイルが存在しなければスキップ
  [ -f "$file" ] || return 1

  # 現在のstatus取得（最後にマッチしたstatus行を採用）
  local current_status
  current_status=$(grep -oP '^\s*status:\s*\K\S+' "$file" 2>/dev/null | tail -1)
  [ -z "$current_status" ] && return 1

  # 前回のstatus取得
  local prev_status=""
  [ -f "$state_file" ] && prev_status=$(cat "$state_file" 2>/dev/null)

  # 現在のstatusを保存
  echo "$current_status" > "$state_file"

  # done への遷移のみ通知（既にdoneだった場合は通知しない）
  if [ "$current_status" = "done" ] && [ "$prev_status" != "done" ]; then
    return 0
  fi
  return 1
}

# --- パターン判定 → 通知先決定 ---
case "$FILE_PATH" in

  # (1) 足軽→家老: report.yaml通知
  */queue/army*/reports/ashigaru*_report.yaml)
    ARMY_ID=$(echo "$FILE_PATH" | grep -oP 'queue/\Karmy[ABC]')
    [ -z "$ARMY_ID" ] && exit 0
    SUFFIX="${ARMY_ID: -1}"
    NOTIFY_TARGET="karo${SUFFIX}"
    WORKER=$(basename "$FILE_PATH" _report.yaml)
    MSG="[hook] ${WORKER}が報告書を更新。確認されよ。"
    ;;

  # (2) 足軽タスクYAML: status:done検知 → 家老に通知
  */queue/army*/tasks/ashigaru*.yaml)
    ARMY_ID=$(echo "$FILE_PATH" | grep -oP 'queue/\Karmy[ABC]')
    [ -z "$ARMY_ID" ] && exit 0
    SUFFIX="${ARMY_ID: -1}"
    WORKER=$(basename "$FILE_PATH" .yaml)
    STATE_KEY="${ARMY_ID}_${WORKER}"
    check_status_done "$FILE_PATH" "$STATE_KEY" || exit 0
    NOTIFY_TARGET="karo${SUFFIX}"
    MSG="[hook] ${WORKER}のタスクがdone。報告書を確認されよ。"
    ;;

  # (3) shogun_to_karo.yaml: status:done検知 → 将軍に通知
  */queue/army*/shogun_to_karo.yaml)
    ARMY_ID=$(echo "$FILE_PATH" | grep -oP 'queue/\Karmy[ABC]')
    [ -z "$ARMY_ID" ] && exit 0
    SUFFIX="${ARMY_ID: -1}"
    # キュー内の最後のエントリのstatusを見る
    STATE_KEY="${ARMY_ID}_shogun_to_karo"
    check_status_done "$FILE_PATH" "$STATE_KEY" || exit 0
    NOTIFY_TARGET="shogun${SUFFIX}"
    MSG="[hook] ${ARMY_ID}家老がコマンド完了報告。queue確認されよ。"
    ;;

  *)
    # 対象外
    exit 0
    ;;
esac

# 既存のsend_notify.shを利用（到達確認+リトライ付き）
bash "$PROJECT_DIR/scripts/send_notify.sh" "$NOTIFY_TARGET" "$MSG" 2>/dev/null || true

exit 0
