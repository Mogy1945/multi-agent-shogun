#!/bin/bash
# ============================================================
# switch_set.sh — instructionsセット切り替えスクリプト
# ============================================================
# 使い方: ./scripts/switch_set.sh <set_name>
# 例:     ./scripts/switch_set.sh original
#         ./scripts/switch_set.sh coc_trpg
#
# 利用可能なセット:
#   original  — エンジニアリング汎用（デフォルト）
#   coc_trpg  — クトゥルフ神話TRPG シナリオ制作専門

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
INSTRUCTIONS_DIR="$BASE_DIR/instructions"
SETS_DIR="$INSTRUCTIONS_DIR/sets"

# 引数チェック
if [ $# -ne 1 ]; then
    echo "使い方: $0 <set_name>"
    echo ""
    echo "利用可能なセット:"
    for dir in "$SETS_DIR"/*/; do
        if [ -d "$dir" ]; then
            set_name=$(basename "$dir")
            echo "  $set_name"
        fi
    done
    exit 1
fi

SET_NAME="$1"
SET_DIR="$SETS_DIR/$SET_NAME"

# セットの存在チェック
if [ ! -d "$SET_DIR" ]; then
    echo "エラー: セット '$SET_NAME' が見つかりません"
    echo "利用可能なセット:"
    for dir in "$SETS_DIR"/*/; do
        if [ -d "$dir" ]; then
            echo "  $(basename "$dir")"
        fi
    done
    exit 1
fi

# 必要なファイルの存在チェック（taishogun.md は任意）
for file in shogun.md karo.md ashigaru.md; do
    if [ ! -f "$SET_DIR/$file" ]; then
        echo "エラー: $SET_DIR/$file が見つかりません"
        exit 1
    fi
done

# コピー実行
echo "セット切り替え: $SET_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for file in taishogun.md shogun.md karo.md ashigaru.md; do
    if [ -f "$SET_DIR/$file" ]; then
        cp "$SET_DIR/$file" "$INSTRUCTIONS_DIR/$file"
        echo "  ✓ $file"
    fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "切り替え完了: $SET_NAME"
echo ""
echo "注意: 各エージェントに /clear を送って新しい設定を読み込ませてください"
