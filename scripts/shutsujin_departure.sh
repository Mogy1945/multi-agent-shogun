#!/bin/bash
# ============================================================
# shutsujin_departure.sh — 出陣（大将軍+3軍団 起動スクリプト）
# ============================================================
# 使い方:
#   ./scripts/shutsujin_departure.sh           # 全起動（セッション作成 + Claude Code起動）
#   ./scripts/shutsujin_departure.sh -c        # クリーンスタート（キューリセット）
#   ./scripts/shutsujin_departure.sh -k        # 決戦の陣（全足軽Opus Thinking）
#   ./scripts/shutsujin_departure.sh -s        # セットアップのみ（Claude起動なし）
#   ./scripts/shutsujin_departure.sh -t        # Windows Terminal 3タブ展開
#   ./scripts/shutsujin_departure.sh -h        # ヘルプ表示
#
# 構成:
#   taishogun セッション (1ペイン): 大将軍
#   armyA セッション (10ペイン):    将軍A + 家老A + 足軽A1-A8
#   armyB セッション (10ペイン):    将軍B + 家老B + 足軽B1-B8
#   armyC セッション (10ペイン):    将軍C + 家老C + 足軽C1-C8

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
cd "$BASE_DIR"

# Claude Code のパス
CLAUDE_CMD="claude"

# モデル設定
MODEL_TAISHOGUN="opus"
MODEL_SHOGUN="opus"
MODEL_KARO="opus"
MODEL_ASHIGARU_SONNET="sonnet"
MODEL_ASHIGARU_OPUS="opus"
MODEL_SHINOBICHO="opus"
MODEL_SHINOBI="opus"

# ============================================================
# 1. read_settings() — config/settings.yaml から設定読み取り
# ============================================================
read_settings() {
    LANG_SETTING="ja"
    SHELL_SETTING="bash"
    TONE_SETTING="sengoku"

    if [ -f "$BASE_DIR/config/settings.yaml" ]; then
        LANG_SETTING=$(grep "^language:" "$BASE_DIR/config/settings.yaml" 2>/dev/null | awk '{print $2}' || echo "ja")
        SHELL_SETTING=$(grep "^shell:" "$BASE_DIR/config/settings.yaml" 2>/dev/null | awk '{print $2}' || echo "bash")
        TONE_SETTING=$(grep "^tone:" "$BASE_DIR/config/settings.yaml" 2>/dev/null | awk '{print $2}' || echo "sengoku")
    fi
}

# ============================================================
# 2. parse_options() — CLI引数パース
# ============================================================
SETUP_ONLY=false
OPEN_TERMINAL=false
CLEAN_MODE=false
KESSEN_MODE=false
SHELL_OVERRIDE=""

parse_options() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--clean)
                CLEAN_MODE=true
                shift
                ;;
            -k|--kessen)
                KESSEN_MODE=true
                shift
                ;;
            -s|--setup-only)
                SETUP_ONLY=true
                shift
                ;;
            -t|--terminal)
                OPEN_TERMINAL=true
                shift
                ;;
            -shell|--shell)
                if [[ -n "${2:-}" && "$2" != -* ]]; then
                    SHELL_OVERRIDE="$2"
                    shift 2
                else
                    echo "エラー: -shell オプションには bash または zsh を指定してください"
                    exit 1
                fi
                ;;
            -h|--help)
                echo ""
                echo "🏯 multi-agent-shogun 出陣スクリプト（大将軍+3軍団制）"
                echo ""
                echo "使用方法: ./shutsujin_departure.sh [オプション]"
                echo ""
                echo "オプション:"
                echo "  -c, --clean         キューとダッシュボードをリセットして起動（クリーンスタート）"
                echo "                      未指定時は前回の状態を維持して起動"
                echo "  -k, --kessen        決戦の陣（全足軽をOpus Thinkingで起動）"
                echo "                      未指定時は平時の陣（足軽1-4=Sonnet, 足軽5-8=Opus）"
                echo "  -s, --setup-only    tmuxセッションのセットアップのみ（Claude起動なし）"
                echo "  -t, --terminal      Windows Terminal で4タブ展開"
                echo "  -shell, --shell SH  シェルを指定（bash または zsh）"
                echo "                      未指定時は config/settings.yaml の設定を使用"
                echo "  -h, --help          このヘルプを表示"
                echo ""
                echo "例:"
                echo "  ./shutsujin_departure.sh              # 前回の状態を維持して出陣"
                echo "  ./shutsujin_departure.sh -c           # クリーンスタート（キューリセット）"
                echo "  ./shutsujin_departure.sh -s           # セットアップのみ（手動でClaude起動）"
                echo "  ./shutsujin_departure.sh -t           # 全エージェント起動 + ターミナルタブ展開"
                echo "  ./shutsujin_departure.sh -k           # 決戦の陣（全足軽Opus Thinking）"
                echo "  ./shutsujin_departure.sh -c -k        # クリーンスタート＋決戦の陣"
                echo "  ./shutsujin_departure.sh -shell zsh   # zsh用プロンプトで起動"
                echo ""
                echo "セッション構成（31ペイン）:"
                echo "  taishogun: 大将軍 (1ペイン)   — Opus"
                echo "  armyA:     将軍A + 家老A + 足軽A1-A8 (10ペイン)"
                echo "  armyB:     将軍B + 家老B + 足軽B1-B8 (10ペイン)"
                echo "  armyC:     将軍C + 家老C + 足軽C1-C8 (10ペイン)"
                echo ""
                echo "陣形:"
                echo "  平時の陣（デフォルト）: 足軽1-4=Sonnet Thinking, 足軽5-8=Opus Thinking"
                echo "  決戦の陣（--kessen）:   全足軽=Opus Thinking"
                echo ""
                echo "エイリアス:"
                echo "  csst  → cd $BASE_DIR && ./scripts/shutsujin_departure.sh"
                echo "  cst   → tmux attach-session -t taishogun"
                echo "  csa   → tmux attach-session -t armyA"
                echo "  csb   → tmux attach-session -t armyB"
                echo "  csc   → tmux attach-session -t armyC"
                echo ""
                exit 0
                ;;
            *)
                echo "不明なオプション: $1"
                echo "./shutsujin_departure.sh -h でヘルプを表示"
                exit 1
                ;;
        esac
    done

    # シェル設定のオーバーライド
    if [ -n "$SHELL_OVERRIDE" ]; then
        if [[ "$SHELL_OVERRIDE" == "bash" || "$SHELL_OVERRIDE" == "zsh" ]]; then
            SHELL_SETTING="$SHELL_OVERRIDE"
        else
            echo "エラー: -shell オプションには bash または zsh を指定してください（指定値: $SHELL_OVERRIDE）"
            exit 1
        fi
    fi
}

# ============================================================
# ユーティリティ関数
# ============================================================
log_info() {
    echo -e "\033[1;33m【報】\033[0m $1"
}

log_success() {
    echo -e "\033[1;32m【成】\033[0m $1"
}

log_war() {
    echo -e "\033[1;31m【戦】\033[0m $1"
}

log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

# ============================================================
# 3. show_battle_cry() — バナー表示
# ============================================================
show_battle_cry() {
    clear

    # タイトルバナー
    echo ""
    echo -e "\033[1;31m╔══════════════════════════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m███████╗██╗  ██╗██╗   ██╗████████╗███████╗██╗   ██╗     ██╗██╗███╗   ██╗\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m██╔════╝██║  ██║██║   ██║╚══██╔══╝██╔════╝██║   ██║     ██║██║████╗  ██║\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m███████╗███████║██║   ██║   ██║   ███████╗██║   ██║     ██║██║██╔██╗ ██║\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m╚════██║██╔══██║██║   ██║   ██║   ╚════██║██║   ██║██   ██║██║██║╚██╗██║\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m███████║██║  ██║╚██████╔╝   ██║   ███████║╚██████╔╝╚█████╔╝██║██║ ╚████║\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m╚══════╝╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚══════╝ ╚═════╝  ╚════╝ ╚═╝╚═╝  ╚═══╝\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m╠══════════════════════════════════════════════════════════════════════════════════╣\033[0m"
    echo -e "\033[1;31m║\033[0m       \033[1;37m出陣じゃーーー！！！\033[0m    \033[1;36m⚔\033[0m    \033[1;35m天下布武！\033[0m                          \033[1;31m║\033[0m"
    echo -e "\033[1;31m╚══════════════════════════════════════════════════════════════════════════════════╝\033[0m"
    echo ""

    # 足軽隊列（3軍24名）
    echo -e "\033[1;34m  ╔═════════════════════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;34m  ║\033[0m              \033[1;37m【 足 軽 隊 列 ・ 三 軍 二 十 四 名 配 備 】\033[0m                 \033[1;34m║\033[0m"
    echo -e "\033[1;34m  ╚═════════════════════════════════════════════════════════════════════════════╝\033[0m"

    cat << 'ASHIGARU_EOF'

    ＜軍A＞                 ＜軍B＞                 ＜軍C＞
       /\      /\      /\      /\      /\      /\      /\      /\
      /||\    /||\    /||\    /||\    /||\    /||\    /||\    /||\
     /_||\   /_||\   /_||\   /_||\   /_||\   /_||\   /_||\   /_||\
       ||      ||      ||      ||      ||      ||      ||      ||
      /||\    /||\    /||\    /||\    /||\    /||\    /||\    /||\
      /  \    /  \    /  \    /  \    /  \    /  \    /  \    /  \
     [A1]    [A2]    [A3]    [B1]    [B2]    [B3]    [C1]    [C2]

       /\      /\      /\      /\      /\      /\      /\      /\
      /||\    /||\    /||\    /||\    /||\    /||\    /||\    /||\
     /_||\   /_||\   /_||\   /_||\   /_||\   /_||\   /_||\   /_||\
       ||      ||      ||      ||      ||      ||      ||      ||
      /||\    /||\    /||\    /||\    /||\    /||\    /||\    /||\
      /  \    /  \    /  \    /  \    /  \    /  \    /  \    /  \
     [A4]    [A5]    [B4]    [B5]    [B6]    [C3]    [C4]    [C5]

       /\      /\      /\      /\      /\      /\      /\      /\
      /||\    /||\    /||\    /||\    /||\    /||\    /||\    /||\
     /_||\   /_||\   /_||\   /_||\   /_||\   /_||\   /_||\   /_||\
       ||      ||      ||      ||      ||      ||      ||      ||
      /||\    /||\    /||\    /||\    /||\    /||\    /||\    /||\
      /  \    /  \    /  \    /  \    /  \    /  \    /  \    /  \
     [A6]    [A7]    [A8]    [B7]    [B8]    [C6]    [C7]    [C8]

ASHIGARU_EOF

    echo -e "                    \033[1;36m「「「 はっ！！ 出陣いたす！！ 」」」\033[0m"
    echo ""

    # システム情報ボックス（大将軍仕様）
    echo -e "\033[1;33m  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\033[0m"
    echo -e "\033[1;33m  ┃\033[0m  \033[1;37m🏯 multi-agent-shogun\033[0m  〜 \033[1;36m大将軍+3軍団 並列統率システム\033[0m 〜              \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m                                                                           \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m    \033[1;33m大将軍\033[0m: 全軍統括   \033[1;35m将軍×3\033[0m: 軍団指揮   \033[1;31m家老×3\033[0m: 管理   \033[1;34m足軽×24\033[0m: 実働  \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\033[0m"
    echo ""

    # 陣形表示
    if [ "$KESSEN_MODE" = true ]; then
        echo -e "  \033[1;31m⚔  決戦の陣 — 全足軽 Opus Thinking！\033[0m"
    else
        echo -e "  \033[1;33m🏯 平時の陣 — 足軽1-4: Sonnet, 足軽5-8: Opus\033[0m"
    fi
    echo ""
}

# ============================================================
# 4. cleanup_sessions() — 既存tmuxセッション破棄
# ============================================================
cleanup_sessions() {
    log_info "既存の陣を撤収中..."

    # 大将軍+3軍団セッション
    tmux kill-session -t taishogun 2>/dev/null && log_info "  └─ taishogun陣、撤収完了" || true
    tmux kill-session -t armyA 2>/dev/null && log_info "  └─ armyA陣、撤収完了" || true
    tmux kill-session -t armyB 2>/dev/null && log_info "  └─ armyB陣、撤収完了" || true
    tmux kill-session -t armyC 2>/dev/null && log_info "  └─ armyC陣、撤収完了" || true
    tmux kill-session -t shinobi 2>/dev/null && log_info "  └─ shinobi陣（旧）、撤収完了" || true

    sleep 0.5
}

# ============================================================
# 5. backup_and_clean() — --clean時: バックアップ + キューリセット
# ============================================================
backup_and_clean() {
    if [ "$CLEAN_MODE" != true ]; then
        return
    fi

    BACKUP_DIR="$BASE_DIR/logs/backup_$(date '+%Y%m%d_%H%M%S')"
    NEED_BACKUP=false

    # 旧データの存在チェック
    for army in armyA armyB armyC; do
        if [ -d "$BASE_DIR/queue/$army" ]; then
            if [ "$(ls -A "$BASE_DIR/queue/$army/tasks/" 2>/dev/null)" ] || \
               [ -f "$BASE_DIR/queue/$army/shogun_to_karo.yaml" ]; then
                NEED_BACKUP=true
            fi
        fi
    done

    if [ "$NEED_BACKUP" = true ]; then
        mkdir -p "$BACKUP_DIR"
        cp -r "$BASE_DIR/queue/" "$BACKUP_DIR/" 2>/dev/null || true
        cp "$BASE_DIR/dashboard_armyA.md" "$BACKUP_DIR/" 2>/dev/null || true
        cp "$BASE_DIR/dashboard_armyB.md" "$BACKUP_DIR/" 2>/dev/null || true
        cp "$BASE_DIR/dashboard_armyC.md" "$BACKUP_DIR/" 2>/dev/null || true
        log_info "前回の記録をバックアップ: $BACKUP_DIR"
    fi

    log_info "前回の軍議記録を破棄中..."

    # 軍別キューリセット
    for army in armyA armyB armyC; do
        local queue_dir="$BASE_DIR/queue/$army"
        mkdir -p "$queue_dir/tasks" "$queue_dir/reports" "$queue_dir/archive"

        # shogun_to_karo.yaml リセット
        echo "queue: []" > "$queue_dir/shogun_to_karo.yaml"

        # archive/commands.yaml リセット
        echo "archive: []" > "$queue_dir/archive/commands.yaml"

        # kaizen.yaml リセット
        echo "entries: []" > "$queue_dir/kaizen.yaml"

        # kaizen_archive.yaml リセット
        echo "archive: []" > "$queue_dir/kaizen_archive.yaml"

        # 足軽タスク・レポートファイルリセット
        local suffix="${army: -1}"  # A, B, or C
        for i in $(seq 1 8); do
            cat > "$queue_dir/tasks/ashigaru${i}.yaml" << EOF
# 足軽${suffix}${i}専用タスクファイル
task:
  task_id: null
  parent_cmd: null
  description: null
  target_path: null
  status: idle
  timestamp: ""
EOF
            cat > "$queue_dir/reports/ashigaru${i}_report.yaml" << EOF
worker_id: ashigaru${suffix}${i}
task_id: null
timestamp: ""
status: idle
result: null
EOF
        done
    done

    # taishogun_to_shogun.yaml リセット
    echo "queue: []" > "$BASE_DIR/queue/taishogun_to_shogun.yaml"

    # 旧shinobiキューは tcmd_233 で軍C統合済み。archive は保護（touchしない）。

    log_success "陣払い完了"
}

# ============================================================
# 6. init_army_queues(army_id) — 軍別キューディレクトリ初期化
# ============================================================
init_army_queues() {
    local army_id=$1
    local queue_dir="$BASE_DIR/queue/$army_id"

    mkdir -p "$queue_dir/tasks" "$queue_dir/reports" "$queue_dir/archive"

    # shogun_to_karo.yaml（存在しなければ作成）
    if [ ! -f "$queue_dir/shogun_to_karo.yaml" ]; then
        echo "queue: []" > "$queue_dir/shogun_to_karo.yaml"
    fi

    # archive/commands.yaml
    if [ ! -f "$queue_dir/archive/commands.yaml" ]; then
        echo "archive: []" > "$queue_dir/archive/commands.yaml"
    fi

    # kaizen.yaml
    if [ ! -f "$queue_dir/kaizen.yaml" ]; then
        echo "entries: []" > "$queue_dir/kaizen.yaml"
    fi

    # kaizen_archive.yaml
    if [ ! -f "$queue_dir/kaizen_archive.yaml" ]; then
        echo "archive: []" > "$queue_dir/kaizen_archive.yaml"
    fi

    # 足軽タスク・レポートファイル（存在しなければ作成）
    for i in $(seq 1 8); do
        if [ ! -f "$queue_dir/tasks/ashigaru${i}.yaml" ]; then
            echo -e "task:\n  status: idle" > "$queue_dir/tasks/ashigaru${i}.yaml"
        fi
        if [ ! -f "$queue_dir/reports/ashigaru${i}_report.yaml" ]; then
            echo "# No report yet" > "$queue_dir/reports/ashigaru${i}_report.yaml"
        fi
    done

    # taishogun_to_shogun.yaml（共通、存在しなければ作成）
    if [ ! -f "$BASE_DIR/queue/taishogun_to_shogun.yaml" ]; then
        echo "queue: []" > "$BASE_DIR/queue/taishogun_to_shogun.yaml"
    fi
}

# ============================================================
# 6b. (廃止) init_shinobi_queues() — tcmd_233 で軍C へ統合済み
# ============================================================

# ============================================================
# 7. init_dashboards() — --clean時: ダッシュボード初期化
# ============================================================
init_dashboards() {
    if [ "$CLEAN_MODE" != true ]; then
        return
    fi

    log_info "戦況報告板を初期化中..."
    local TIMESTAMP
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M")

    for army_label in "軍A" "軍B" "軍C"; do
        local filename
        case "$army_label" in
            "軍A") filename="$BASE_DIR/dashboard_armyA.md" ;;
            "軍B") filename="$BASE_DIR/dashboard_armyB.md" ;;
            "軍C") filename="$BASE_DIR/dashboard_armyC.md" ;;
        esac

        if [ "$LANG_SETTING" = "ja" ]; then
            cat > "$filename" << EOF
# 📊 戦況報告 -- ${army_label}
最終更新: ${TIMESTAMP}

## 🚨 要対応 - 殿のご判断をお待ちしております
なし

## 🔄 進行中
なし

## ✅ 本日の戦果
| 時刻 | 戦場 | 任務 | 結果 |
|------|------|------|------|

## 🎯 スキル化候補 - 承認待ち
なし

## 🛠️ 生成されたスキル
なし

## ⏸️ 待機中
なし

## ❓ 伺い事項
なし
EOF
        else
            cat > "$filename" << EOF
# 📊 戦況報告 (Battle Status Report) -- ${army_label}
最終更新 (Last Updated): ${TIMESTAMP}

## 🚨 要対応 - 殿のご判断をお待ちしております (Action Required - Awaiting Lord's Decision)
なし (None)

## 🔄 進行中 (In Progress)
なし (None)

## ✅ 本日の戦果 (Today's Achievements)
| 時刻 (Time) | 戦場 (Battlefield) | 任務 (Mission) | 結果 (Result) |
|------|------|------|------|

## 🎯 スキル化候補 - 承認待ち (Skill Candidates - Pending Approval)
なし (None)

## 🛠️ 生成されたスキル (Generated Skills)
なし (None)

## ⏸️ 待機中 (On Standby)
なし (None)

## ❓ 伺い事項 (Questions for Lord)
なし (None)
EOF
        fi
    done

    # 旧忍衆ダッシュボードは tcmd_233 で dashboard_armyC.md に統合済み

    log_success "  └─ ダッシュボード初期化完了 (言語: $LANG_SETTING)"
}

# ============================================================
# 8. generate_prompt(label, color, shell) — カラープロンプト生成
# ============================================================
generate_prompt() {
    local label="$1"
    local color="$2"
    local shell_type="$3"

    if [ "$shell_type" == "zsh" ]; then
        echo "(%F{${color}}%B${label}%b%f) %F{green}%B%~%b%f%# "
    else
        local color_code
        case "$color" in
            red)     color_code="1;31" ;;
            green)   color_code="1;32" ;;
            yellow)  color_code="1;33" ;;
            blue)    color_code="1;34" ;;
            magenta) color_code="1;35" ;;
            cyan)    color_code="1;36" ;;
            *)       color_code="1;37" ;;
        esac
        echo "(\[\033[${color_code}m\]${label}\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ "
    fi
}

# ============================================================
# 9. setup_taishogun() — 大将軍セッション作成
# ============================================================
setup_taishogun() {
    log_war "大将軍の本陣を構築中..."

    tmux new-session -d -s taishogun -x 200 -y 50
    tmux rename-window -t taishogun:0 "main"

    # tmuxペイン変数設定
    tmux set-option -p -t taishogun:main.0 @agent_id "taishogun"
    tmux set-option -p -t taishogun:main.0 @army_id "taishogun"
    tmux set-option -p -t taishogun:main.0 @army_session "taishogun"
    tmux set-option -p -t taishogun:main.0 @model_name "Opus"

    # ペインタイトル・プロンプト設定
    tmux select-pane -t taishogun:main.0 -T "taishogun (Opus)"
    local PROMPT_STR
    PROMPT_STR=$(generate_prompt "大将軍" "yellow" "$SHELL_SETTING")
    tmux send-keys -t taishogun:main.0 "cd \"$BASE_DIR\" && export PS1='${PROMPT_STR}' && clear" Enter

    log_success "  └─ 大将軍の本陣、構築完了"
}

# ============================================================
# 9b. (廃止) setup_shinobi() — tcmd_233 で軍C (setup_army "armyC") に統合
# ============================================================

# ============================================================
# 10. setup_army(army_id) — 軍団セッション作成（10ペイン）
# ============================================================
setup_army() {
    local army_id=$1
    local suffix="${army_id: -1}"  # A or B

    log_war "${army_id} の陣を構築中（将軍+家老+足軽×8）..."

    tmux new-session -d -s "$army_id" -x 200 -y 50
    tmux rename-window -t "${army_id}:0" "agents"

    # 9回split で合計10ペイン
    for _ in $(seq 1 9); do
        tmux split-window -t "${army_id}:agents" || true
        tmux select-layout -t "${army_id}:agents" tiled
    done
    tmux select-layout -t "${army_id}:agents" tiled

    # --- 将軍（pane 0）---
    tmux set-option -p -t "${army_id}:agents.0" @agent_id "shogun${suffix}"
    tmux set-option -p -t "${army_id}:agents.0" @army_id "$army_id"
    tmux set-option -p -t "${army_id}:agents.0" @army_session "$army_id"
    tmux set-option -p -t "${army_id}:agents.0" @model_name "Opus"
    tmux select-pane -t "${army_id}:agents.0" -T "shogun${suffix} (Opus)"
    local PROMPT_STR
    PROMPT_STR=$(generate_prompt "将軍${suffix}" "magenta" "$SHELL_SETTING")
    tmux send-keys -t "${army_id}:agents.0" "cd \"$BASE_DIR\" && export PS1='${PROMPT_STR}' && clear" Enter

    # --- 家老（pane 1）---
    tmux set-option -p -t "${army_id}:agents.1" @agent_id "karo${suffix}"
    tmux set-option -p -t "${army_id}:agents.1" @army_id "$army_id"
    tmux set-option -p -t "${army_id}:agents.1" @army_session "$army_id"
    tmux set-option -p -t "${army_id}:agents.1" @model_name "Opus"
    tmux select-pane -t "${army_id}:agents.1" -T "karo${suffix} (Opus)"
    PROMPT_STR=$(generate_prompt "家老${suffix}" "red" "$SHELL_SETTING")
    tmux send-keys -t "${army_id}:agents.1" "cd \"$BASE_DIR\" && export PS1='${PROMPT_STR}' && clear" Enter

    # --- 足軽（pane 2-9）---
    for i in $(seq 1 8); do
        local pane_idx=$((i + 1))
        local agent_id="ashigaru${suffix}${i}"
        local model_name

        if [ "$KESSEN_MODE" = true ]; then
            model_name="Opus Thinking"
        elif [ $i -le 4 ]; then
            model_name="Sonnet Thinking"
        else
            model_name="Opus Thinking"
        fi

        tmux set-option -p -t "${army_id}:agents.${pane_idx}" @agent_id "$agent_id"
        tmux set-option -p -t "${army_id}:agents.${pane_idx}" @army_id "$army_id"
        tmux set-option -p -t "${army_id}:agents.${pane_idx}" @army_session "$army_id"
        tmux set-option -p -t "${army_id}:agents.${pane_idx}" @model_name "$model_name"
        tmux select-pane -t "${army_id}:agents.${pane_idx}" -T "${agent_id} (${model_name})"

        PROMPT_STR=$(generate_prompt "足軽${suffix}${i}" "blue" "$SHELL_SETTING")
        tmux send-keys -t "${army_id}:agents.${pane_idx}" "cd \"$BASE_DIR\" && export PS1='${PROMPT_STR}' && clear" Enter
    done

    # pane-border-format でモデル名を常時表示
    tmux set-option -t "$army_id" -w pane-border-status top
    tmux set-option -t "$army_id" -w pane-border-format '#{pane_index} #{@agent_id} (#{?#{==:#{@model_name},},unknown,#{@model_name}})'

    log_success "  └─ ${army_id} の陣、構築完了"
}

# ============================================================
# 11. wait_for_claude(target, max_wait) — Claude起動待機
# ============================================================
wait_for_claude() {
    local target=$1
    local max_wait=${2:-30}

    for i in $(seq 1 "$max_wait"); do
        if tmux capture-pane -t "$target" -p 2>/dev/null | grep -q "bypass permissions"; then
            return 0
        fi
        sleep 1
    done
    return 1
}

# ============================================================
# 12. launch_claude_taishogun() — 大将軍にClaude Code起動
# ============================================================
launch_claude_taishogun() {
    log_war "大将軍に Claude Code を召喚中..."

    tmux send-keys -t taishogun:main.0 \
        "MAX_THINKING_TOKENS=0 $CLAUDE_CMD --model $MODEL_TAISHOGUN --dangerously-skip-permissions" \
        Enter

    log_info "  └─ 大将軍、召喚完了"
}

# ============================================================
# 13. launch_claude_army(army_id) — 軍全エージェントにClaude Code起動
# ============================================================
launch_claude_army() {
    local army_id=$1

    log_war "${army_id} に Claude Code を召喚中..."

    # 将軍（Opus, thinking無効）
    tmux send-keys -t "${army_id}:agents.0" \
        "MAX_THINKING_TOKENS=0 $CLAUDE_CMD --model $MODEL_SHOGUN --dangerously-skip-permissions" \
        Enter
    sleep 1
    log_info "  └─ ${army_id} 将軍、召喚完了"

    # 家老（Opus）
    tmux send-keys -t "${army_id}:agents.1" \
        "$CLAUDE_CMD --model $MODEL_KARO --dangerously-skip-permissions" \
        Enter
    sleep 1
    log_info "  └─ ${army_id} 家老、召喚完了"

    # 足軽（1-8）
    for i in $(seq 1 8); do
        local pane_idx=$((i + 1))
        local model

        if [ "$KESSEN_MODE" = true ]; then
            model=$MODEL_ASHIGARU_OPUS
        elif [ $i -le 4 ]; then
            model=$MODEL_ASHIGARU_SONNET
        else
            model=$MODEL_ASHIGARU_OPUS
        fi

        tmux send-keys -t "${army_id}:agents.${pane_idx}" \
            "$CLAUDE_CMD --model $model --dangerously-skip-permissions" \
            Enter
        sleep 1
    done

    if [ "$KESSEN_MODE" = true ]; then
        log_info "  └─ ${army_id} 足軽1-8（Opus Thinking）、決戦の陣で召喚完了"
    else
        log_info "  └─ ${army_id} 足軽1-4（Sonnet）、足軽5-8（Opus）、召喚完了"
    fi
}

# ============================================================
# 13b. (廃止) launch_claude_shinobi() — tcmd_233 で launch_claude_army "armyC" に統合

# ============================================================
# 14. send_initial_instructions() — 全エージェントに指示書送信
# ============================================================
send_initial_instructions() {
    log_war "各エージェントに指示書を伝達中..."

    echo "  Claude Code の起動を待機中（最大30秒）..."

    # 大将軍の起動待ち
    if wait_for_claude "taishogun:main.0" 30; then
        echo "  └─ 大将軍の Claude Code 起動確認完了"
    else
        echo "  └─ 大将軍の起動確認タイムアウト（続行）"
    fi

    # 大将軍に指示
    tmux send-keys -t taishogun:main.0 'instructions/taishogun.md を読んでセッションを開始せよ。'
    sleep 0.5
    tmux send-keys -t taishogun:main.0 Enter
    log_info "  └─ 大将軍に指示書伝達完了"
    sleep 2

    # 各軍に指示
    for army_id in armyA armyB armyC; do
        # 将軍
        tmux send-keys -t "${army_id}:agents.0" 'instructions/shogun.md を読んでセッションを開始せよ。'
        sleep 0.5
        tmux send-keys -t "${army_id}:agents.0" Enter
        sleep 2

        # 家老
        tmux send-keys -t "${army_id}:agents.1" 'instructions/karo.md を読んでセッションを開始せよ。'
        sleep 0.5
        tmux send-keys -t "${army_id}:agents.1" Enter
        sleep 2

        # 足軽
        for i in $(seq 1 8); do
            local pane_idx=$((i + 1))
            tmux send-keys -t "${army_id}:agents.${pane_idx}" "instructions/ashigaru.md を読んでセッションを開始せよ。"
            sleep 0.3
            tmux send-keys -t "${army_id}:agents.${pane_idx}" Enter
            sleep 0.5
        done

        log_info "  └─ ${army_id} 全エージェントに指示書伝達完了"
    done

    # 旧忍衆は tcmd_233 で軍C に統合済み。別途指示伝達は不要。

    log_success "全軍に指示書伝達完了"
}

# ============================================================
# 15. show_formation() — 布陣図表示
# ============================================================
show_formation() {
    echo ""
    echo "  ┌──────────────────────────────────────────────────────────┐"
    echo "  │  📺 Tmux陣容 (Sessions)                                  │"
    echo "  └──────────────────────────────────────────────────────────┘"
    tmux list-sessions 2>/dev/null | sed 's/^/     /'
    echo ""
    echo "  ┌──────────────────────────────────────────────────────────┐"
    echo "  │  📋 布陣図 (Formation) — 大将軍+3軍団制                  │"
    echo "  └──────────────────────────────────────────────────────────┘"
    echo ""
    echo "     【taishogunセッション】大将軍の本陣"
    echo "     ┌─────────────────────────────┐"
    echo "     │  Pane 0: 大将軍 (TAISHOGUN) │  ← 全軍統括"
    echo "     └─────────────────────────────┘"
    echo ""
    echo "     【armyAセッション】軍A（10ペイン）"
    echo "     ┌──────────┬──────────┬──────────┬──────────┬──────────┐"
    echo "     │ 将軍A(0) │ 家老A(1) │ 足軽A1(2)│ 足軽A2(3)│ 足軽A3(4)│"
    echo "     ├──────────┼──────────┼──────────┼──────────┼──────────┤"
    echo "     │ 足軽A4(5)│ 足軽A5(6)│ 足軽A6(7)│ 足軽A7(8)│ 足軽A8(9)│"
    echo "     └──────────┴──────────┴──────────┴──────────┴──────────┘"
    echo ""
    echo "     【armyBセッション】軍B（10ペイン）"
    echo "     ┌──────────┬──────────┬──────────┬──────────┬──────────┐"
    echo "     │ 将軍B(0) │ 家老B(1) │ 足軽B1(2)│ 足軽B2(3)│ 足軽B3(4)│"
    echo "     ├──────────┼──────────┼──────────┼──────────┼──────────┤"
    echo "     │ 足軽B4(5)│ 足軽B5(6)│ 足軽B6(7)│ 足軽B7(8)│ 足軽B8(9)│"
    echo "     └──────────┴──────────┴──────────┴──────────┴──────────┘"
    echo ""
    echo "     【armyCセッション】軍C（10ペイン）"
    echo "     ┌──────────┬──────────┬──────────┬──────────┬──────────┐"
    echo "     │ 将軍C(0) │ 家老C(1) │ 足軽C1(2)│ 足軽C2(3)│ 足軽C3(4)│"
    echo "     ├──────────┼──────────┼──────────┼──────────┼──────────┤"
    echo "     │ 足軽C4(5)│ 足軽C5(6)│ 足軽C6(7)│ 足軽C7(8)│ 足軽C8(9)│"
    echo "     └──────────┴──────────┴──────────┴──────────┴──────────┘"
    echo ""
}

# ============================================================
# 16. show_completion() — 完了メッセージ
# ============================================================
show_completion() {
    echo ""
    echo "  ╔══════════════════════════════════════════════════════════╗"
    echo "  ║  🏯 出陣準備完了！天下布武！                              ║"
    echo "  ╚══════════════════════════════════════════════════════════╝"
    echo ""

    if [ "$SETUP_ONLY" = true ]; then
        echo "  ⚠️  セットアップのみモード: Claude Codeは未起動です"
        echo ""
        echo "  tmux変数の確認:"
        echo "    tmux display-message -t taishogun:main.0 -p '#{@agent_id}'     # → taishogun"
        echo "    tmux display-message -t armyA:agents.0 -p '#{@agent_id}'       # → shogunA"
        echo "    tmux display-message -t armyA:agents.1 -p '#{@agent_id}'       # → karoA"
        echo "    tmux display-message -t armyB:agents.0 -p '#{@agent_id}'       # → shogunB"
        echo ""
    fi

    echo "  次のステップ:"
    echo "  ┌──────────────────────────────────────────────────────────┐"
    echo "  │  大将軍の本陣にアタッチ:                                  │"
    echo "  │     tmux attach-session -t taishogun   (または: cst)     │"
    echo "  │                                                          │"
    echo "  │  軍Aの陣を確認:                                          │"
    echo "  │     tmux attach-session -t armyA        (または: csa)    │"
    echo "  │                                                          │"
    echo "  │  軍Bの陣を確認:                                          │"
    echo "  │     tmux attach-session -t armyB        (または: csb)    │"
    echo "  │                                                          │"
    echo "  │  軍Cの陣を確認:                                          │"
    echo "  │     tmux attach-session -t armyC        (または: csc)    │"
    echo "  └──────────────────────────────────────────────────────────┘"
    echo ""
    echo "  ════════════════════════════════════════════════════════════"
    echo "   天下布武！勝利を掴め！ (Tenka Fubu! Seize victory!)"
    echo "  ════════════════════════════════════════════════════════════"
    echo ""
}

# ============================================================
# 17. register_aliases() — エイリアスを ~/.bashrc に登録
# ============================================================
register_aliases() {
    local rc_file="$HOME/.bashrc"
    local marker="# multi-agent-shogun aliases"

    # 既に登録済みならスキップ
    if grep -qF "$marker" "$rc_file" 2>/dev/null; then
        return
    fi

    log_info "エイリアスを ${rc_file} に登録中..."

    cat >> "$rc_file" << EOF

$marker
alias csst="cd $BASE_DIR && ./scripts/shutsujin_departure.sh"
alias cst="tmux attach-session -t taishogun"
alias csa="tmux attach-session -t armyA"
alias csb="tmux attach-session -t armyB"
alias csc="tmux attach-session -t armyC"
EOF

    log_success "  └─ エイリアス登録完了（csst, cst, csa, csb, csc）"
}

# ============================================================
# 18. open_terminal_tabs() — -t時: Windows Terminal 4タブ展開
# ============================================================
open_terminal_tabs() {
    if [ "$OPEN_TERMINAL" != true ]; then
        return
    fi

    log_info "Windows Terminal で4タブを展開中..."

    if command -v wt.exe &> /dev/null; then
        wt.exe -w 0 \
            new-tab wsl.exe -e bash -c "tmux attach-session -t taishogun" \; \
            new-tab wsl.exe -e bash -c "tmux attach-session -t armyA" \; \
            new-tab wsl.exe -e bash -c "tmux attach-session -t armyB" \; \
            new-tab wsl.exe -e bash -c "tmux attach-session -t armyC"
        log_success "  └─ ターミナルタブ展開完了（taishogun, armyA, armyB, armyC）"
    else
        log_info "  └─ wt.exe が見つかりません。手動でアタッチしてください。"
    fi
    echo ""
}

# ============================================================
# 18. main() — メイン実行
# ============================================================
main() {
    # 1. 設定読み取り
    read_settings

    # 2. 引数パース
    parse_options "$@"

    # 3. tmux存在チェック
    if ! command -v tmux &> /dev/null; then
        echo ""
        echo "  ╔════════════════════════════════════════════════════════╗"
        echo "  ║  [ERROR] tmux not found!                              ║"
        echo "  ║  tmux が見つかりません                                 ║"
        echo "  ╠════════════════════════════════════════════════════════╣"
        echo "  ║  Run first_setup.sh first:                            ║"
        echo "  ║     ./first_setup.sh                                  ║"
        echo "  ╚════════════════════════════════════════════════════════╝"
        echo ""
        exit 1
    fi

    # 4. バナー表示
    show_battle_cry

    echo -e "  \033[1;33m天下布武！陣立てを開始いたす\033[0m"
    echo ""

    # 5. 既存セッション破棄
    cleanup_sessions

    # 6. バックアップ + キューリセット（--clean時のみ）
    backup_and_clean

    # 7. キューディレクトリ初期化（通常時: 未存在時のみ作成）
    init_army_queues "armyA"
    init_army_queues "armyB"
    init_army_queues "armyC"

    # 8. ダッシュボード初期化（--clean時のみ）
    init_dashboards

    echo ""

    # 9. セッション作成
    setup_taishogun
    setup_army "armyA"
    setup_army "armyB"
    setup_army "armyC"

    echo ""
    log_success "セッション作成完了: taishogun(1) + armyA(10) + armyB(10) + armyC(10) = 31ペイン"
    echo ""

    # 10. エイリアス登録
    register_aliases

    # 11. Claude Code 起動（-s時はスキップ）
    if [ "$SETUP_ONLY" = false ]; then
        # Claude CLI 存在チェック
        if ! command -v claude &> /dev/null; then
            log_info "⚠️  claude コマンドが見つかりません"
            echo "  first_setup.sh を再実行してください"
            exit 1
        fi

        launch_claude_taishogun
        launch_claude_army "armyA"
        launch_claude_army "armyB"
        launch_claude_army "armyC"

        echo ""
        if [ "$KESSEN_MODE" = true ]; then
            log_success "決戦の陣で出陣！全軍Opus！"
        else
            log_success "平時の陣で出陣！"
        fi
        echo ""

        # 12. 初期指示送信
        send_initial_instructions
    fi

    # 13. 布陣図表示
    show_formation

    # 14. 完了メッセージ
    show_completion

    # 15. ターミナルタブ展開
    open_terminal_tabs
}

main "$@"
