#!/bin/bash
# ============================================================
# trpg_precompact.sh — PreCompactフックスクリプト
# ============================================================
# コンパクション発生時にTRPGセッション状態をログに記録し、
# 家老（KP）のコンパクション時は将軍に通知する。
#
# Claude Code の PreCompact フックから呼び出される。
# stdin から JSON を受け取る:
#   { "session_id": "...", "trigger": "manual|auto", ... }

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
ARMY_ID=$(tmux display-message -t "$TMUX_PANE" -p '#{@army_id}' 2>/dev/null || echo "")
ARMY_SESSION=$(tmux display-message -t "$TMUX_PANE" -p '#{@army_session}' 2>/dev/null || echo "")

# 軍IDが取得できた場合は軍別パス、できなければフォールバック
if [ -n "$ARMY_ID" ]; then
    QUEUE_DIR="$BASE_DIR/queue/$ARMY_ID"
else
    QUEUE_DIR="$BASE_DIR/queue"
fi

SESSION_FILE="$QUEUE_DIR/trpg_session.yaml"
COMPACT_LOG="$QUEUE_DIR/trpg_compact_log.yaml"

# TRPGセッションが非アクティブなら何もしない
if [ ! -f "$SESSION_FILE" ]; then
    exit 0
fi

# stdin から JSON を読み取り
INPUT=$(cat)
TRIGGER=$(echo "$INPUT" | jq -r '.trigger // "unknown"' 2>/dev/null || echo "unknown")
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")

# タイムスタンプ取得
TIMESTAMP=$(date "+%Y-%m-%dT%H:%M:%S")

# エージェントIDを取得（tmux ペイン変数から）
AGENT_ID=$(tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}' 2>/dev/null || echo "unknown")

# compact_log ファイルが存在しなければ初期化
if [ ! -f "$COMPACT_LOG" ]; then
    echo "compact_log:" > "$COMPACT_LOG"
fi

# ログエントリを追記
echo "  - timestamp: \"$TIMESTAMP\"" >> "$COMPACT_LOG"
echo "    agent_id: \"$AGENT_ID\"" >> "$COMPACT_LOG"
echo "    trigger: \"$TRIGGER\"" >> "$COMPACT_LOG"
echo "    session_id: \"$SESSION_ID\"" >> "$COMPACT_LOG"

# 家老のコンパクションの場合、同軍の将軍に通知
if [ "$AGENT_ID" = "karo" ] || [[ "$AGENT_ID" == karo* ]]; then
    # 将軍ペインを @agent_id から動的に解決
    SUFFIX=${ARMY_ID: -1}
    SHOGUN_PANE=$(bash "$SCRIPT_DIR/resolve_pane.sh" "shogun${SUFFIX}" 2>/dev/null || echo "")
    if [ -z "$SHOGUN_PANE" ]; then
        # resolve_pane.sh が失敗（将軍ペイン死亡等）→ 通知スキップ
        exit 0
    fi
    # 将軍ペインに通知（send-keys は2回に分ける）
    tmux send-keys -t "$SHOGUN_PANE" "【警告】家老（KP）がコンパクションされた。TRPGセッション中断リスクあり。queue/${ARMY_ID:-}/trpg_compact_log.yaml を確認し、復旧cmdの発行を検討されよ。" 2>/dev/null || true
    sleep 1
    tmux send-keys -t "$SHOGUN_PANE" Enter 2>/dev/null || true
fi

exit 0
