#!/usr/bin/env bash
# ============================================================
# health_check.sh — 全エージェント健康状態チェックスクリプト
# ============================================================
# 使い方:
#   bash scripts/health_check.sh              # 全エージェント表示
#   bash scripts/health_check.sh --summary    # サマリのみ表示
#   bash scripts/health_check.sh --army armyA # 特定軍のみ表示
#   bash scripts/health_check.sh --army armyA --summary
#   bash scripts/health_check.sh --context      # コンテキスト残量表示
#   bash scripts/health_check.sh --suggest-restart  # 停止エージェントの再起動コマンド提案

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# ── オプション解析 ────────────────────────────────────────
SUMMARY_ONLY=false
FILTER_ARMY=""
SHOW_CONTEXT=false
SUGGEST_RESTART=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary) SUMMARY_ONLY=true; shift ;;
    --army) FILTER_ARMY="$2"; shift 2 ;;
    --context) SHOW_CONTEXT=true; shift ;;
    --suggest-restart) SUGGEST_RESTART=true; shift ;;
    *) shift ;;
  esac
done

# ── 全エージェント定義 ─────────────────────────────────────
# 形式: "agent_id army_group"
# taishogunは特別扱い（固定ペイン taishogun:main.0）
AGENTS=(
    # armyA
    "shogunA    armyA"
    "karoA      armyA"
    "ashigaruA1 armyA"
    "ashigaruA2 armyA"
    "ashigaruA3 armyA"
    "ashigaruA4 armyA"
    "ashigaruA5 armyA"
    "ashigaruA6 armyA"
    "ashigaruA7 armyA"
    "ashigaruA8 armyA"
    # armyB
    "shogunB    armyB"
    "karoB      armyB"
    "ashigaruB1 armyB"
    "ashigaruB2 armyB"
    "ashigaruB3 armyB"
    "ashigaruB4 armyB"
    "ashigaruB5 armyB"
    "ashigaruB6 armyB"
    "ashigaruB7 armyB"
    "ashigaruB8 armyB"
    # armyC (tcmd_233 で旧忍衆から統合)
    "shogunC    armyC"
    "karoC      armyC"
    "ashigaruC1 armyC"
    "ashigaruC2 armyC"
    "ashigaruC3 armyC"
    "ashigaruC4 armyC"
    "ashigaruC5 armyC"
    "ashigaruC6 armyC"
    "ashigaruC7 armyC"
    "ashigaruC8 armyC"
)

# ── スピナー文字・キーワード判定 ──────────────────────────
is_active() {
    local content="$1"
    # スピナー文字またはアクティブキーワードを含む場合 → ACTIVE
    echo "$content" | grep -qP '[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏✻⠂✳✢✽✶]|thinking|Compacting|Reading|Searching|Effecting|Writing|Running'
}

is_idle() {
    local content="$1"
    # ❯ プロンプト、bypass permissions、auto-compact のいずれかがあればIDLE
    echo "$content" | grep -qP '❯|bypass permissions|auto-compact'
}

# ── カウンター ────────────────────────────────────────────
COUNT_ACTIVE=0
COUNT_IDLE=0
COUNT_DEAD=0
COUNT_UNKNOWN=0

# ── コンテキスト残量 & 停止エージェント追跡 ────────────────
CONTEXT_WARNINGS=()    # "agent_id:残量%" の配列
IDLE_AGENTS=()         # "agent_id:army_group" の配列

# ── 出力バッファ（グループ別） ─────────────────────────────
declare -A GROUP_OUTPUT
GROUP_OUTPUT["taishogun"]=""
GROUP_OUTPUT["armyA"]=""
GROUP_OUTPUT["armyB"]=""
GROUP_OUTPUT["armyC"]=""
GROUP_ORDER=("taishogun" "armyA" "armyB" "armyC")

# ── コンテキスト残量抽出 ────────────────────────────────
# capture-pane出力から "X% until auto-compact" を探す
extract_context_pct() {
    local content="$1"
    local pct
    pct=$(echo "$content" | grep -oP '\d+% until auto-compact' | head -1 | grep -oP '^\d+')
    echo "${pct:-}"
}

# ── エージェント1件チェック ──────────────────────────────
check_agent() {
    local agent_id="$1"
    local army_group="$2"
    local pane_addr status_icon status_label last_line pane_display

    # ペイン解決
    pane_addr=$(bash "$SCRIPT_DIR/resolve_pane.sh" "$agent_id" 2>/dev/null)
    local resolve_rc=$?

    if [[ $resolve_rc -ne 0 ]] || [[ -z "$pane_addr" ]]; then
        status_icon="💀"
        status_label="DEAD"
        pane_display="❌ NOT FOUND"
        last_line=""
        COUNT_DEAD=$((COUNT_DEAD + 1))
    else
        pane_display="$pane_addr"
        local capture
        capture=$(tmux capture-pane -t "$pane_addr" -p 2>/dev/null | tail -10)

        if is_active "$capture"; then
            status_icon="🟢"
            status_label="ACTIVE"
            COUNT_ACTIVE=$((COUNT_ACTIVE + 1))
        elif is_idle "$capture"; then
            status_icon="🟡"
            status_label="IDLE"
            COUNT_IDLE=$((COUNT_IDLE + 1))
            IDLE_AGENTS+=("${agent_id}:${army_group}")
        else
            status_icon="❓"
            status_label="UNKNOWN"
            COUNT_UNKNOWN=$((COUNT_UNKNOWN + 1))
        fi

        # コンテキスト残量抽出（--context時のみ処理）
        local context_pct=""
        if [[ "$SHOW_CONTEXT" == true ]]; then
            # より広い範囲をキャプチャしてコンテキスト表示を探す
            local wide_capture
            wide_capture=$(tmux capture-pane -t "$pane_addr" -p 2>/dev/null | tail -25)
            context_pct=$(extract_context_pct "$wide_capture")
            if [[ -n "$context_pct" ]] && [[ "$context_pct" -le 10 ]]; then
                CONTEXT_WARNINGS+=("${agent_id}:${context_pct}%")
            fi
        fi

        # 最終行（60文字にトリム）
        last_line=$(echo "$capture" | tail -1 | tr -d '\n' | cut -c1-60)
    fi

    # 出力行を組み立て
    local block
    if [[ "$pane_display" == "❌ NOT FOUND" ]]; then
        block="[${army_group}] ${agent_id}
  ペイン: ${pane_display}
  状態: ${status_icon} ${status_label}
"
    else
        local context_line=""
        if [[ "$SHOW_CONTEXT" == true ]] && [[ -n "${context_pct:-}" ]]; then
            if [[ "$context_pct" -le 10 ]]; then
                context_line="  コンテキスト: ⚠️  ${context_pct}% until auto-compact"
            else
                context_line="  コンテキスト: ${context_pct}% until auto-compact"
            fi
        fi
        block="[${army_group}] ${agent_id}
  ペイン: ${pane_display}
  状態: ${status_icon} ${status_label}
  最終: ${last_line}
"
        if [[ -n "$context_line" ]]; then
            block+="${context_line}
"
        fi
    fi

    GROUP_OUTPUT["$army_group"]+="$block"$'\n'
}

# ── taishogunを先にチェック ───────────────────────────────
check_taishogun() {
    local agent_id="taishogun"
    local army_group="taishogun"
    local pane_addr="taishogun:main.0"
    local status_icon status_label last_line

    # taishogunは固定ペイン
    if ! tmux has-session -t "taishogun" 2>/dev/null; then
        status_icon="💀"
        status_label="DEAD"
        last_line=""
        COUNT_DEAD=$((COUNT_DEAD + 1))
        GROUP_OUTPUT["taishogun"]+="[taishogun] taishogun
  ペイン: ❌ NOT FOUND (session: taishogun)
  状態: ${status_icon} ${status_label}
"$'\n'
        return
    fi

    local capture
    capture=$(tmux capture-pane -t "$pane_addr" -p 2>/dev/null | tail -10)
    local rc=$?

    if [[ $rc -ne 0 ]]; then
        status_icon="💀"
        status_label="DEAD"
        last_line=""
        COUNT_DEAD=$((COUNT_DEAD + 1))
        GROUP_OUTPUT["taishogun"]+="[taishogun] taishogun
  ペイン: ❌ NOT FOUND
  状態: ${status_icon} ${status_label}
"$'\n'
        return
    fi

    if is_active "$capture"; then
        status_icon="🟢"
        status_label="ACTIVE"
        COUNT_ACTIVE=$((COUNT_ACTIVE + 1))
    elif is_idle "$capture"; then
        status_icon="🟡"
        status_label="IDLE"
        COUNT_IDLE=$((COUNT_IDLE + 1))
        IDLE_AGENTS+=("taishogun:taishogun")
    else
        status_icon="❓"
        status_label="UNKNOWN"
        COUNT_UNKNOWN=$((COUNT_UNKNOWN + 1))
    fi

    # コンテキスト残量抽出
    local context_pct=""
    local context_line=""
    if [[ "$SHOW_CONTEXT" == true ]]; then
        local wide_capture
        wide_capture=$(tmux capture-pane -t "$pane_addr" -p 2>/dev/null | tail -25)
        context_pct=$(extract_context_pct "$wide_capture")
        if [[ -n "$context_pct" ]] && [[ "$context_pct" -le 10 ]]; then
            CONTEXT_WARNINGS+=("taishogun:${context_pct}%")
            context_line="  コンテキスト: ⚠️  ${context_pct}% until auto-compact"
        elif [[ -n "$context_pct" ]]; then
            context_line="  コンテキスト: ${context_pct}% until auto-compact"
        fi
    fi

    last_line=$(echo "$capture" | tail -1 | tr -d '\n' | cut -c1-60)

    local block="[taishogun] taishogun
  ペイン: ${pane_addr}
  状態: ${status_icon} ${status_label}
  最終: ${last_line}
"
    if [[ -n "$context_line" ]]; then
        block+="${context_line}
"
    fi
    GROUP_OUTPUT["taishogun"]+="$block"$'\n'
}

# ── メイン処理 ────────────────────────────────────────────
NOW=$(date '+%Y-%m-%d %H:%M')

# taishogunチェック
if [[ -z "$FILTER_ARMY" ]] || [[ "$FILTER_ARMY" == "taishogun" ]]; then
    check_taishogun
fi

# 各エージェントチェック
for entry in "${AGENTS[@]}"; do
    local_agent_id=$(echo "$entry" | awk '{print $1}')
    local_army_group=$(echo "$entry" | awk '{print $2}')

    # フィルタ適用
    if [[ -n "$FILTER_ARMY" ]] && [[ "$local_army_group" != "$FILTER_ARMY" ]]; then
        continue
    fi

    check_agent "$local_agent_id" "$local_army_group"
done

# ── 合計エージェント数 ─────────────────────────────────────
TOTAL=$((COUNT_ACTIVE + COUNT_IDLE + COUNT_DEAD + COUNT_UNKNOWN))
SUMMARY_LINE="🟢 ${COUNT_ACTIVE} | 🟡 ${COUNT_IDLE} | 💀 ${COUNT_DEAD} | ❓ ${COUNT_UNKNOWN} | 合計 ${TOTAL}"

# ── 出力 ─────────────────────────────────────────────────
if $SUMMARY_ONLY; then
    echo "$SUMMARY_LINE"
    exit 0
fi

echo "=========================================="
echo " shogun Health Check — ${NOW}"
echo "=========================================="
echo ""

FIRST_GROUP=true
for group in "${GROUP_ORDER[@]}"; do
    # フィルタ適用
    if [[ -n "$FILTER_ARMY" ]] && [[ "$group" != "$FILTER_ARMY" ]]; then
        continue
    fi

    content="${GROUP_OUTPUT[$group]}"
    if [[ -z "$content" ]]; then
        continue
    fi

    if ! $FIRST_GROUP; then
        echo ""
    fi
    FIRST_GROUP=false

    printf "%s" "$content"
done

echo "------------------------------------------"
echo "$SUMMARY_LINE"

# ── コンテキスト残量警告（--context時） ────────────────────
if [[ "$SHOW_CONTEXT" == true ]] && [[ ${#CONTEXT_WARNINGS[@]} -gt 0 ]]; then
    echo ""
    echo "⚠️  コンテキスト残量警告（10%以下）:"
    for w in "${CONTEXT_WARNINGS[@]}"; do
        local_aid="${w%%:*}"
        local_pct="${w#*:}"
        echo "  - ${local_aid}: ${local_pct}"
    done
fi

# ── 停止エージェント再起動提案（--suggest-restart時） ──────
if [[ "$SUGGEST_RESTART" == true ]] && [[ ${#IDLE_AGENTS[@]} -gt 0 ]]; then
    echo ""
    echo "💤 停止中エージェント（IDLE）の再起動コマンド:"
    for entry in "${IDLE_AGENTS[@]}"; do
        local_aid="${entry%%:*}"
        echo "  # ${local_aid} を起こす:"
        echo "  TARGET=\$(bash scripts/resolve_pane.sh ${local_aid}) && tmux send-keys -t \"\$TARGET\" 'コンパクション復帰手順を実行せよ'"
        echo "  tmux send-keys -t \"\$TARGET\" Enter"
        echo ""
    done
fi
