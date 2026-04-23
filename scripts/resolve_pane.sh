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
#   bash scripts/resolve_pane.sh shogunA     → "armyA:agents.0"
#   bash scripts/resolve_pane.sh karoB       → "armyB:agents.1"
#   bash scripts/resolve_pane.sh ashigaruC3  → "armyC:agents.4"
#   bash scripts/resolve_pane.sh taishogun   → "taishogun:main.0"
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
RESULT=$(tmux list-panes -a -F '#{session_name}:#{window_name}.#{pane_index} #{@agent_id}' \
    | grep " ${TARGET_AGENT}$" \
    | head -1 \
    | cut -d' ' -f1)

if [ -z "$RESULT" ]; then
    echo "ERROR: ${TARGET_AGENT} not found" >&2
    exit 1
fi

echo "$RESULT"
