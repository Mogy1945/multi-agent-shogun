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
    # armyA — 足軽1=Sonnet, 足軽2-8=Opus（shutsujin_departure.sh準拠）
    "shogunA armyA Opus"
    "karoA armyA Opus"
    "ashigaruA1 armyA Sonnet"
    "ashigaruA2 armyA Opus"
    "ashigaruA3 armyA Opus"
    "ashigaruA4 armyA Opus"
    "ashigaruA5 armyA Opus"
    "ashigaruA6 armyA Opus"
    "ashigaruA7 armyA Opus"
    "ashigaruA8 armyA Opus"
    # armyB — 足軽1=Sonnet, 足軽2-8=Opus（shutsujin_departure.sh準拠）
    "shogunB armyB Opus"
    "karoB armyB Opus"
    "ashigaruB1 armyB Sonnet"
    "ashigaruB2 armyB Opus"
    "ashigaruB3 armyB Opus"
    "ashigaruB4 armyB Opus"
    "ashigaruB5 armyB Opus"
    "ashigaruB6 armyB Opus"
    "ashigaruB7 armyB Opus"
    "ashigaruB8 armyB Opus"
    # armyC — 足軽1=Sonnet, 足軽2-8=Opus（tcmd_233 で旧忍衆から統合、shutsujin_departure.sh 準拠）
    "shogunC armyC Opus"
    "karoC armyC Opus"
    "ashigaruC1 armyC Sonnet"
    "ashigaruC2 armyC Opus"
    "ashigaruC3 armyC Opus"
    "ashigaruC4 armyC Opus"
    "ashigaruC5 armyC Opus"
    "ashigaruC6 armyC Opus"
    "ashigaruC7 armyC Opus"
    "ashigaruC8 armyC Opus"
    # taishogun は固定ペイン（main.0）のため除外
)

# ── FROZEN検出カウンター（連続無活動回数） ───────────────────
declare -A FROZEN_COUNTS

# ── 上位監督者マッピング ──────────────────────────────────────
get_supervisor() {
    local agent_id="$1"
    case "$agent_id" in
        ashigaruA*) echo "karoA" ;;
        ashigaruB*) echo "karoB" ;;
        ashigaruC*) echo "karoC" ;;
        karoA)      echo "shogunA" ;;
        karoB)      echo "shogunB" ;;
        karoC)      echo "shogunC" ;;
        shogunA)    echo "taishogun" ;;
        shogunB)    echo "taishogun" ;;
        shogunC)    echo "taishogun" ;;
        *)          echo "" ;;
    esac
}

# ── ペイン生存チェック＆蘇生 ────────────────────────────────
check_and_revive() {
    local revived=0

    # Log rotation: 1MB limit, 1 generation
    if [[ -f "$LOG_FILE" ]] && [[ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt 1048576 ]]; then
        mv "$LOG_FILE" "${LOG_FILE}.1"
        log "Log rotated"
    fi

    for entry in "${AGENTS[@]}"; do
        local agent_id session model_name
        read -r agent_id session model_name <<< "$entry"

        # resolve_pane.sh で検索（見つかれば生存）
        local pane_addr
        pane_addr=$(bash "$SCRIPT_DIR/resolve_pane.sh" "$agent_id" 2>/dev/null) || true
        if [ -n "$pane_addr" ]; then
            # ペイン生存 → Claude Code死活チェック
            local pane_content
            pane_content=$(tmux capture-pane -t "$pane_addr" -p 2>/dev/null | tail -20)

            if echo "$pane_content" | grep -qP '[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏✻⠂✳✢✽✶❯]|thinking|Compacting|Reading|Searching|Effecting|Writing|Running'; then
                # 活動検出 → カウントリセット
                FROZEN_COUNTS["$agent_id"]=0
            else
                # 活動なし → カウントインクリメント
                FROZEN_COUNTS["$agent_id"]=$(( ${FROZEN_COUNTS["$agent_id"]:-0} + 1 ))
                local count=${FROZEN_COUNTS["$agent_id"]}
                if [[ $count -ge 2 ]]; then
                    local supervisor
                    supervisor=$(get_supervisor "$agent_id")
                    log "WARN: FROZEN: ${agent_id} on ${pane_addr} — no activity for ${count}x${POLL_INTERVAL}s (notify: ${supervisor:-none})"
                    # FROZEN検出: send-keysでコンパクション復帰手順を送信して起こす
                    if [[ $count -eq 2 ]]; then
                        log "ACTION: Waking ${agent_id} with compaction recovery prompt"
                        tmux send-keys -t "$pane_addr" 'コンパクション復帰手順を実行せよ' 2>/dev/null || true
                        sleep 0.5
                        tmux send-keys -t "$pane_addr" Enter 2>/dev/null || true
                        # 上位監督者へFROZEN通知
                        if [ -n "$supervisor" ]; then
                            local sup_pane
                            sup_pane=$(bash "$SCRIPT_DIR/resolve_pane.sh" "$supervisor" 2>/dev/null) || true
                            if [ -n "$sup_pane" ]; then
                                tmux send-keys -t "$sup_pane" "⚠ FROZEN検出: ${agent_id} が${count}x${POLL_INTERVAL}秒無活動。復帰を試みた。" 2>/dev/null || true
                                sleep 0.5
                                tmux send-keys -t "$sup_pane" Enter 2>/dev/null || true
                                log "NOTIFY: Sent FROZEN alert for ${agent_id} to ${supervisor} (${sup_pane})"
                            else
                                log "NOTIFY-SKIP: ${supervisor} pane not found, skipping notification"
                            fi
                        fi
                    fi
                    if [[ $count -eq 3 ]]; then
                        log "CRITICAL: ${agent_id} frozen for ${count}x${POLL_INTERVAL}s — sending /clear"
                        tmux send-keys -t "$pane_addr" '/clear' 2>/dev/null || true
                        sleep 0.5
                        tmux send-keys -t "$pane_addr" Enter 2>/dev/null || true
                        FROZEN_COUNTS["$agent_id"]=0
                    fi
                fi
            fi
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
