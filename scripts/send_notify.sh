#!/bin/bash
# ============================================================
# send_notify.sh — send-keys + 到達確認 + 1回リトライ
# ============================================================
# send-keys による通知を確実に届けるためのラッパースクリプト。
# resolve_pane.sh でペイン解決 → 送信 → 到達確認 → 未到達なら1回リトライ。
#
# 使い方:
#   bash scripts/send_notify.sh <agent_id> 'メッセージ'
#
# 例:
#   bash scripts/send_notify.sh karoA '【足軽A3→家老A】cmd_100完了。報告書参照。'
#   bash scripts/send_notify.sh shogunA 'dashboard更新完了'
#
# 終了コード:
#   0: 到達確認OK（スピナー or thinking検出）
#   1: 到達NG（リトライ後も未到達）or ペイン解決失敗

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── 引数チェック ─────────────────────────────────────────────
if [ $# -lt 2 ]; then
    echo "Usage: bash $0 <agent_id> 'message'" >&2
    exit 1
fi

AGENT_ID="$1"
MESSAGE="$2"

# ── スピナー記号パターン（到達OKの証拠） ─────────────────────
# CLAUDE.md準拠: スピナー記号、thinking等のステータス、または送信メッセージ
SPINNER_PATTERN='[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏✻⠂✳✽✶✢·]|thinking|Compacting|Reading|Searching|Effecting|Writing|Running'

# ── ペインアドレス解決 ────────────────────────────────────────
PANE_ADDR=$(bash "$SCRIPT_DIR/resolve_pane.sh" "$AGENT_ID" 2>/dev/null)
if [ -z "$PANE_ADDR" ]; then
    echo "ERROR: ${AGENT_ID} not found (pane dead?)" >&2
    exit 1
fi

# ── 送信+到達確認関数 ─────────────────────────────────────────
send_and_check() {
    # 1. メッセージ送信
    tmux send-keys -t "$PANE_ADDR" "$MESSAGE" 2>/dev/null || return 1

    # 2. Enter送信
    sleep 0.3
    tmux send-keys -t "$PANE_ADDR" Enter 2>/dev/null || return 1

    # 3. 5秒待機（CLAUDE.md 統一基準: 送信後5秒待機）
    sleep 5

    # 4. capture-paneで到達確認
    local captured
    captured=$(tmux capture-pane -t "$PANE_ADDR" -p 2>/dev/null | tail -8)

    # 5. スピナー or thinking があればOK
    if echo "$captured" | grep -qP "$SPINNER_PATTERN"; then
        return 0
    fi

    # 6. ❯ がプロンプト最終行にあり活動なし → 未到達
    if echo "$captured" | tail -3 | grep -q '❯'; then
        return 1
    fi

    # 判定不能 → OKとみなす（安全側）
    return 0
}

# ── 送信実行 ──────────────────────────────────────────────────
if send_and_check; then
    exit 0
fi

# ── 1回リトライ ──────────────────────────────────────────────
echo "RETRY: First attempt to ${AGENT_ID} may not have arrived. Retrying..." >&2
if send_and_check; then
    exit 0
fi

echo "WARN: Message to ${AGENT_ID} may not have been delivered after retry." >&2
exit 1
