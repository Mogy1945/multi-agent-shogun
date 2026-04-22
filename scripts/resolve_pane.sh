#!/bin/bash
# ============================================================
# resolve_pane.sh — agent_id から tmux ペインアドレスを解決
# ============================================================
# ペインが死んでインデックスが詰まっても、@agent_id 変数で
# 正しいペインアドレスを動的に解決する。
#
# 使い方:
#   bash scripts/resolve_pane.sh <agent_id>
#
# 例:
#   bash scripts/resolve_pane.sh shogunA   → "armyA:agents.3"
#   bash scripts/resolve_pane.sh karoB     → "armyB:agents.1"
#   bash scripts/resolve_pane.sh shogunC   → "armyC:agents.0"
#   bash scripts/resolve_pane.sh ashigaruC1 → (SubAgent方式ではペインなし、エラー)
#   bash scripts/resolve_pane.sh taishogun → "taishogun:main.0"
#
# NOTE: tcmd_233 (2026-04-22) で旧忍衆 (shinobicho/hanzo/sasuke/kotaro) は
#       軍C (shogunC/karoC/ashigaruC{1..8}) に統合済み。
#       旧 ID で呼び出すと「not found」を返す。
#
# 終了コード:
#   0: 成功（ペインアドレスを stdout に出力）
#   1: 対象エージェントが見つからない（stderr にエラー出力）

TARGET_AGENT="$1"

if [ -z "$TARGET_AGENT" ]; then
    echo "ERROR: agent_id を指定せよ" >&2
    exit 1
fi

# 大将軍は固定アドレス
if [ "$TARGET_AGENT" = "taishogun" ]; then
    echo "taishogun:main.0"
    exit 0
fi

# 全ペインから @agent_id が一致するものを検索
RESULT=$(tmux list-panes -a -F '#{session_name}:#{window_name}.#{pane_index} #{@agent_id}' 2>/dev/null \
    | grep " ${TARGET_AGENT}$" \
    | head -1 \
    | cut -d' ' -f1)

if [ -z "$RESULT" ]; then
    if [[ "$TARGET_AGENT" == *ashigaru* ]]; then
        echo "ERROR: ${TARGET_AGENT} not found (note: ashigaru panes do not exist in SubAgent mode)" >&2
    elif [[ "$TARGET_AGENT" == "shinobicho" ]] || [[ "$TARGET_AGENT" == "hanzo" ]] || [[ "$TARGET_AGENT" == "sasuke" ]] || [[ "$TARGET_AGENT" == "kotaro" ]]; then
        echo "ERROR: ${TARGET_AGENT} は tcmd_233 (2026-04-22) で廃止済み。軍C (shogunC/karoC/ashigaruC{1..8}) を使用せよ" >&2
    else
        echo "ERROR: ${TARGET_AGENT} not found" >&2
    fi
    exit 1
fi

echo "$RESULT"
