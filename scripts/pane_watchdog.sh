#!/bin/bash
# ============================================================
# pane_watchdog.sh — ペイン死亡検知＆自動蘇生スクリプト
# ============================================================
# 定期的に全エージェントのペイン生存を確認し、
# 死んだペインを再作成→変数再設定→シェル起動まで自動実行する。
#
# 使い方:
#   nohup bash scripts/pane_watchdog.sh &
#   または: bash scripts/pane_watchdog.sh --once  （1回だけ実行）
#
# Claude Codeの再起動は行わない（API費用がかかるため）。
# ペインとシェルの復活のみ。Claude起動は手動 or 家老からのsend-keysで行う。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$BASE_DIR/logs/pane_watchdog.log"
POLL_INTERVAL=30  # 秒

mkdir -p "$BASE_DIR/logs"

log() {
    echo "[$(date '+%Y-%m-%dT%H:%M:%S')] $*" >> "$LOG_FILE"
}

# ── 全エージェント定義 ──────────────────────────────────────
# 形式: "agent_id session model_name"
AGENTS=(
    # armyA
    "shogunA armyA Opus"
    "karoA armyA Opus"
    "ashigaruA1 armyA Sonnet"
    "ashigaruA2 armyA Sonnet"
    "ashigaruA3 armyA Sonnet"
    "ashigaruA4 armyA Sonnet"
    "ashigaruA5 armyA Sonnet"
    "ashigaruA6 armyA Sonnet"
    "ashigaruA7 armyA Sonnet"
    "ashigaruA8 armyA Sonnet"
    # armyB
    "shogunB armyB Opus"
    "karoB armyB Opus"
    "ashigaruB1 armyB Sonnet"
    "ashigaruB2 armyB Sonnet"
    "ashigaruB3 armyB Sonnet"
    "ashigaruB4 armyB Sonnet"
    "ashigaruB5 armyB Sonnet"
    "ashigaruB6 armyB Sonnet"
    "ashigaruB7 armyB Sonnet"
    "ashigaruB8 armyB Sonnet"
    # armyC (tcmd_233 で旧忍衆から統合)
    "shogunC armyC Opus"
    "karoC armyC Opus"
    "ashigaruC1 armyC Sonnet"
    "ashigaruC2 armyC Sonnet"
    "ashigaruC3 armyC Sonnet"
    "ashigaruC4 armyC Sonnet"
    "ashigaruC5 armyC Sonnet"
    "ashigaruC6 armyC Sonnet"
    "ashigaruC7 armyC Sonnet"
    "ashigaruC8 armyC Sonnet"
    # taishogun は固定ペイン（main.0）のため除外
)

# ── ペイン生存チェック＆蘇生 ────────────────────────────────
check_and_revive() {
    local revived=0

    for entry in "${AGENTS[@]}"; do
        local agent_id session model_name
        read -r agent_id session model_name <<< "$entry"

        # resolve_pane.sh で検索（見つかれば生存）
        if bash "$SCRIPT_DIR/resolve_pane.sh" "$agent_id" >/dev/null 2>&1; then
            continue
        fi

        # セッション自体が存在するか確認
        if ! tmux has-session -t "$session" 2>/dev/null; then
            log "WARN: session '$session' does not exist. Skipping $agent_id."
            continue
        fi

        # ── ペイン蘇生 ──
        log "REVIVE: $agent_id (session=$session) — pane dead, recreating..."

        # 新しいペインを作成
        tmux split-window -t "${session}:agents" 2>/dev/null \
            || tmux split-window -t "${session}:agents" -h 2>/dev/null

        # 作成された最新のペインインデックスを取得
        local new_pane
        new_pane=$(tmux list-panes -t "${session}:agents" -F '#{pane_index}' | tail -1)

        if [ -z "$new_pane" ]; then
            log "ERROR: Failed to create pane for $agent_id"
            continue
        fi

        local target="${session}:agents.${new_pane}"

        # tmux変数を設定
        tmux set-option -p -t "$target" @agent_id "$agent_id"
        tmux set-option -p -t "$target" @army_id "$session"
        tmux set-option -p -t "$target" @army_session "$session"
        tmux set-option -p -t "$target" @model_name "$model_name"
        tmux select-pane -t "$target" -T "${agent_id} (${model_name})"

        # シェルをbase dirに移動
        tmux send-keys -t "$target" "cd \"$BASE_DIR\" && clear" Enter

        # レイアウトを整理
        tmux select-layout -t "${session}:agents" tiled 2>/dev/null || true

        log "REVIVED: $agent_id → ${target} (model=$model_name)"
        revived=$((revived + 1))
    done

    if [ $revived -gt 0 ]; then
        log "SUMMARY: Revived $revived pane(s)"
    fi
}

# ── メインループ ────────────────────────────────────────────
if [ "${1:-}" = "--once" ]; then
    log "START: Single run mode"
    check_and_revive
    log "DONE: Single run complete"
    exit 0
fi

log "START: Watchdog daemon (interval=${POLL_INTERVAL}s)"

while true; do
    check_and_revive
    sleep "$POLL_INTERVAL"
done
