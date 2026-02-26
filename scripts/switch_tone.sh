#!/bin/bash
# ============================================================
# switch_tone.sh — 口調切り替えスクリプト
# ============================================================
# 使い方: ./scripts/switch_tone.sh <tone_name>
# 例:     ./scripts/switch_tone.sh sengoku
#         ./scripts/switch_tone.sh maid
#
# 利用可能なtone:
#   sengoku  — 戦国風（デフォルト）
#   maid     — 秋葉メイド風

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
SETTINGS_FILE="$BASE_DIR/config/settings.yaml"

# 引数チェック
if [ $# -ne 1 ]; then
    echo "使い方: $0 <tone_name>"
    echo ""
    echo "利用可能なtone:"
    echo "  sengoku — 戦国風（デフォルト）"
    echo "  maid — 秋葉メイド風"
    exit 1
fi

TONE_NAME="$1"

# tone名の妥当性チェック
case "$TONE_NAME" in
    sengoku|maid)
        # OK
        ;;
    *)
        echo "エラー: tone '$TONE_NAME' は利用できません"
        echo "利用可能なtone:"
        echo "  sengoku — 戦国風（デフォルト）"
        echo "  maid — 秋葉メイド風"
        exit 1
        ;;
esac

# settings.yaml の存在チェック
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "エラー: $SETTINGS_FILE が見つかりません"
    exit 1
fi

# tone 行の書き換え
echo "口調切り替え: $TONE_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

sed -i "s/^tone: .*/tone: $TONE_NAME/" "$SETTINGS_FILE"

echo "  ✓ config/settings.yaml の tone 行を更新"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "切り替え完了: $TONE_NAME"
echo ""
echo "注意: 各エージェントに /clear を送って新しい設定を読み込ませてください"
