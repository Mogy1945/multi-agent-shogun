#!/bin/bash
# ============================================================
# migrate_instructions_v2.sh — v2構造への移行スクリプト
# ============================================================
# 使い方: ./scripts/migrate_instructions_v2.sh [--dry-run]
#
# 動作:
#   1. instructions/ の旧ファイルを instructions/legacy/ にバックアップ
#   2. instructions/v2/ の内容を instructions/ にコピー
#   3. instructions/base.md はそのまま（既に存在）
#   4. instructions/v2/overlays/ → instructions/overlays/ にコピー

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
INSTRUCTIONS_DIR="$BASE_DIR/instructions"
V2_DIR="$INSTRUCTIONS_DIR/v2"
LEGACY_DIR="$INSTRUCTIONS_DIR/legacy"

DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=true
    echo "[DRY-RUN] 実際のファイル操作は行いません"
    echo ""
fi

# v2ディレクトリの存在チェック
if [ ! -d "$V2_DIR" ]; then
    echo "エラー: $V2_DIR が見つかりません"
    exit 1
fi

echo "instructions v2 移行"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Step 1: 旧ファイルをlegacy/にバックアップ
ROLE_FILES=(taishogun.md shogun.md karo.md ashigaru.md)
echo ""
echo "Step 1: 旧ファイルを legacy/ にバックアップ"

if [ "$DRY_RUN" = false ]; then
    mkdir -p "$LEGACY_DIR"
fi

for file in "${ROLE_FILES[@]}"; do
    src="$INSTRUCTIONS_DIR/$file"
    if [ -f "$src" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "  [DRY] $file → legacy/$file"
        else
            mv "$src" "$LEGACY_DIR/$file"
            echo "  ✓ $file → legacy/$file"
        fi
    else
        echo "  - $file （存在しない、スキップ）"
    fi
done

# sets/ ディレクトリもバックアップ
if [ -d "$INSTRUCTIONS_DIR/sets" ]; then
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY] sets/ → legacy/sets/"
    else
        mv "$INSTRUCTIONS_DIR/sets" "$LEGACY_DIR/sets"
        echo "  ✓ sets/ → legacy/sets/"
    fi
fi

# Step 2: v2/の内容をinstructions/にコピー
echo ""
echo "Step 2: v2/ のファイルを instructions/ にコピー"

for file in "${ROLE_FILES[@]}"; do
    src="$V2_DIR/$file"
    if [ -f "$src" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "  [DRY] v2/$file → $file"
        else
            cp "$src" "$INSTRUCTIONS_DIR/$file"
            echo "  ✓ v2/$file → $file"
        fi
    else
        echo "  - v2/$file （未作成、スキップ）"
    fi
done

# CLAUDE.md のコピー
if [ -f "$V2_DIR/CLAUDE.md" ]; then
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY] v2/CLAUDE.md → CLAUDE.md（プロジェクトルート）"
    else
        # 旧CLAUDE.mdをバックアップ
        if [ -f "$BASE_DIR/CLAUDE.md" ]; then
            cp "$BASE_DIR/CLAUDE.md" "$LEGACY_DIR/CLAUDE.md"
            echo "  ✓ CLAUDE.md → legacy/CLAUDE.md（バックアップ）"
        fi
        cp "$V2_DIR/CLAUDE.md" "$BASE_DIR/CLAUDE.md"
        echo "  ✓ v2/CLAUDE.md → CLAUDE.md"
    fi
fi

# Step 3: base.md 確認
echo ""
echo "Step 3: base.md 確認"
if [ -f "$INSTRUCTIONS_DIR/base.md" ]; then
    echo "  ✓ base.md は既に存在（そのまま）"
else
    echo "  ⚠ base.md が存在しません"
fi

# Step 4: overlays/ コピー
echo ""
echo "Step 4: overlays/ コピー"
if [ -d "$V2_DIR/overlays" ]; then
    overlay_count=$(find "$V2_DIR/overlays" -name "*.md" -type f | wc -l)
    if [ "$overlay_count" -gt 0 ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "  [DRY] v2/overlays/ → overlays/ （${overlay_count}ファイル）"
        else
            mkdir -p "$INSTRUCTIONS_DIR/overlays"
            cp "$V2_DIR/overlays"/*.md "$INSTRUCTIONS_DIR/overlays/"
            echo "  ✓ v2/overlays/ → overlays/ （${overlay_count}ファイル）"
        fi
    else
        echo "  - overlays/ にファイルなし（佐助が作成中）"
    fi
else
    echo "  - v2/overlays/ が存在しない"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] 移行プレビュー完了"
else
    echo "移行完了"
    echo ""
    echo "確認事項:"
    echo "  1. instructions/ のファイルが v2 版に置き換わったことを確認"
    echo "  2. 旧ファイルは instructions/legacy/ にバックアップ済み"
    echo "  3. 各エージェントに /clear を送って新しい設定を読み込ませてください"
fi
