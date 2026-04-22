# 全エージェント共通プロトコル（base.md）

> 本ファイルは全エージェント共通のプロトコルである。
> 各役割固有の指示は instructions/{role}.md を参照せよ。
> 本ファイルと役割固有instructionsが矛盾する場合、役割固有が優先する。

---

## 1. @agent_id が唯一の正データ

```bash
tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'      # 自分のID
tmux display-message -t "$TMUX_PANE" -p '#{@army_id}'       # 所属軍
tmux display-message -t "$TMUX_PANE" -p '#{@army_session}'  # セッション名
```

- ペイン死亡・復活でインデックスは変わるが、@agent_id は不変
- ペインインデックスから役割を推測するな。@agent_id のみで判断せよ
- CLAUDE.md のペイン参照テーブルは初期配置の目安に過ぎない

## 2. tmux send-keys プロトコル

### ❌ 禁止パターン

```bash
tmux send-keys -t armyA:agents.0 'メッセージ' Enter   # 固定index禁止、1行禁止
```

### ✅ 正しい方法（2回のBash呼び出しに分ける）

**【1回目】** ペインを動的解決してメッセージを送る：
```bash
TARGET=$(bash scripts/resolve_pane.sh <agent_id>)
tmux send-keys -t "$TARGET" 'メッセージ内容'
```

**【2回目】** Enter を送る：
```bash
tmux send-keys -t "$TARGET" Enter
```

> **なぜ2回に分けるか**: 1回のBash呼び出しで `'メッセージ' Enter` と書くと Enter が正しく解釈されない。
> これは Claude Code の Bash ツール実装に起因する技術的制約である。

### ペインアドレスの動的解決（resolve_pane.sh）

全ペイン参照は `scripts/resolve_pane.sh` で `@agent_id` から動的解決する。

```bash
TARGET=$(bash scripts/resolve_pane.sh karoA)                   # 家老A
TARGET=$(bash scripts/resolve_pane.sh ashigaruA3)               # 足軽A3
TARGET=$(bash scripts/resolve_pane.sh shogunC)                  # 将軍C
TARGET=$(bash scripts/resolve_pane.sh ashigaruC1)               # 足軽C1 (旧半蔵相当)
```

ペイン死亡時は exit code 1 を返す：
```bash
TARGET=$(bash scripts/resolve_pane.sh ashigaruA5) || echo "dead"
```

## 3. send-keys 到達確認

### 方法A: send_notify.sh（推奨・1コマンドで完結）

```bash
bash scripts/send_notify.sh <agent_id> 'メッセージ内容'
```

- resolve_pane.sh → send-keys → 到達確認 → 未到達なら1回リトライ を全自動
- exit 0 = 到達OK、exit 1 = 未到達（リトライ後も）
- **1回のBash呼び出しで完結**するため、手動の2回分割+capture-paneが不要

### 方法B: 手動（send_notify.shが使えない場合）

送信後、**別のBash呼び出し**で確認（sleepは使うな）：
```bash
TARGET=$(bash scripts/resolve_pane.sh <agent_id>) && tmux capture-pane -t "$TARGET" -p | tail -8
```

| 判定 | 証拠 |
|------|------|
| **到達OK** | スピナー記号（⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏✻⠂✳）、「thinking」等、送信メッセージ文字列 |
| **到達NG** | `❯` プロンプトが最終行、スピナーもメッセージもない |

- ⚠️ `esc to interrupt` や `bypass permissions on` は**常時表示**。到達の証拠にならない
- ⚠️ **`❯` = 未到達 ではない**。相手が高速処理して`❯`に戻っている場合がある（特に将軍→家老委任後）
- 「到達NG」と判断する前に、相手が既に処理済みでないかYAMLで確認せよ
- 未到達なら **1回だけ再送**。それ以上追わない
- 報告YAMLは書いてあるため、未処理報告スキャンで発見される

## 4. 共通禁止事項

| ID | 禁止行為 | 理由 | 代替手段 |
|----|----------|------|----------|
| G-F001 | Task agents を使用 | 統制不能 | send-keys |
| G-F002 | ポーリング（待機ループ） | API代金浪費 | イベント駆動 |
| G-F003 | コンテキストを読まずに作業開始 | 誤判断の原因 | 必ず先読み |

> **G-F001例外**: 家老（karo）が Agent tool で足軽をSubAgentとして起動する場合は G-F001 の対象外。
> これは正式に承認された運用方式であり、cmd_B001 で検証済み。軍A/B/C いずれにも適用される。

## 5. タイムスタンプの取得

タイムスタンプは**必ず `date` コマンドで取得せよ**。自分で推測するな。

```bash
date "+%Y-%m-%d %H:%M"       # dashboard用
date "+%Y-%m-%dT%H:%M:%S"    # YAML用（ISO 8601）
```

## 6. ファイル操作の鉄則

- **Write や Edit の前に必ず Read せよ。** Claude Code は未読ファイルへの Write/Edit を拒否する
- Read → Write/Edit を1セットとして実行すること

## 7. 同一ファイル書き込み禁止（RACE-001）

- 複数エージェントが同一ファイルに同時書き込みすることを禁止する
- 各エージェントは専用ファイルに書け（タスクYAML、報告YAML等）
- 同一ファイルへの編集が必要な場合は Phase 分けで順次化せよ
- やむを得ず並列で上下分担する場合の規約:
  - 担当範囲を境界マーカー（コメント）で明示する
  - **境界マーカー削除は両者完了確認後に、最後に書いた方が行う**（cmd_218 事故の教訓、kz_armyA_009）
  - より安全な代替: `scripts/parallel_split_concat.sh` で物理分割 → 最後に結合（推奨）

## 8. Auto Memory

セッション開始時・/clear復帰時に MEMORY.md を確認せよ（Auto Memory）。殿の好み・ルール・教訓が自動記録されている。

MEMORY.md は `~/.claude/` 配下に自動生成・更新される。明示的なMCPツール呼び出しは不要。

## 9. 言葉遣い

`config/settings.yaml` の `tone`（口調）と `language`（言語）に従え。
詳細は CLAUDE.md の「言語設定」「口調設定」セクションを参照。

## 10. 自軍情報の導出

起動時に取得した変数から以下を導出する（軍所属エージェント用）：

```bash
ARMY_ID=$(tmux display-message -t "$TMUX_PANE" -p '#{@army_id}')
ARMY=$(tmux display-message -t "$TMUX_PANE" -p '#{@army_session}')
SUFFIX=${ARMY_ID: -1}    # → A / B / C（agent_id構築用）
```

軍A/B/C いずれも `${ARMY_ID}` = `armyA` / `armyB` / `armyC`、SUFFIX = `A` / `B` / `C`。
agent_id は `shogun${SUFFIX}` / `karo${SUFFIX}` / `ashigaru${SUFFIX}${N}` で構築する。

## 11. Hooks API（自動通知）

`.claude/settings.json` に以下のフックが設定済み：

### PostToolUse（Write/Edit時）
- `hook_report_notify.sh`: 足軽が `report.yaml` を書いた時、上官（家老）に自動でsend-keys通知する
- 内部で `send_notify.sh`（到達確認+1回リトライ付き）を使用
- **足軽の手動send-keysと併用中**（二重通知になるが、到達率向上のため許容）

### PreCompact（auto/manual）
- `trpg_precompact.sh`: TRPGセッション状態の保全
- `precompact_save_state.sh`: エージェントの作業状態を `/tmp/shogun_precompact_{agent_id}.yaml` に保存

> フックは全エージェントに自動適用される。エージェントが意識して実行する必要はない。

## 12. 完全自律運用方針（v5.0）

本セクションは将軍システム v5.0 における完全自律運用の共通方針を定める。
全エージェントに適用される。

### 12-1. 殿のタスク最優先の原則

- 殿（上様）から降りてきたタスクは**常に最優先**で処理せよ
- 自律改善は殿のタスクが全て完了した後にのみ実行可
- タスク遂行中に自律改善のアイデアを発見した場合、まずメモし、タスク完了後に対応せよ

### 12-2. 自律改善権限

全エージェントは以下の自律改善権限を持つ:

| 権限 | 内容 | 条件 |
|------|------|------|
| 改善提案 | 自分の instructions の改善案を `kaizen_candidate` として報告 | 常時可 |
| 自律修正 | タスク遂行中に発見した問題を自律的に修正 | **自分の担当ファイルのみ** |
| 改善実行 | 提案済み改善の実行 | 殿のタスク完了後・コンパクション前 |

**自律改善の対象範囲**:
- 対象: instructions、scripts、config、templates、context
- 制約: 殿のプロジェクト実ファイル（外部パス）は自律改善の対象外

### 12-3. 安全弁

自律改善には以下の安全弁が適用される:

1. **ログ記録義務**: 全ての自律改善は `templates/autonomous_improvement_log.md` 形式でログに記録せよ
2. **他エージェントのファイル変更禁止**: RACE-001（§7）と連動。他エージェントの担当ファイルは変更するな
3. **失敗時のrevert義務**: 改善が失敗した場合は即座に revert し、`kaizen_candidate` として報告せよ
4. **破壊的操作禁止**: `git reset --hard`、`rm -rf` 等の破壊的操作は自律改善では使用禁止

### 12-4. 共有ファイル改修の権限ルール

v5.0では殿の承認なしに改善を実行する権限を持つ。共有ファイルの改修は以下のルールに従う:

| 対象ファイル | 改修権限者 | 備考 |
|-------------|-----------|------|
| CLAUDE.md, base.md, config/*.yaml | 大将軍のみ | 全軍影響のため |
| instructions/*.md（共通部分） | 大将軍が改修 | kaizen_candidate経由で自律実行 |
| instructions/*.md（自分の役割） | 当該エージェント（kaizen_candidate経由） | kaizen_candidate経由で自律実行 |
| 各軍の YAML / dashboard | 当該軍の将軍・家老のみ | 他軍は変更禁止 |
| memory/*.md | 任意のエージェントが追記可 | **他者のエントリは削除禁止** |

### 12-5. 殿への情報提供と判断報告

v5.0では殿に判断を仰ぐのではなく、判断結果を情報として提供する。

#### 事後報告が**必要**なケース
- セキュリティに関わる変更（認証・認可・暗号化等）
- 課金・決済に関わる操作
- 外部API連携の新規追加・変更
- 破壊的操作（データ削除・スキーマ変更等）
- 新規プロジェクトの作成

→ dashboardの「ℹ️殿への報告」に記載。殿が確認し、必要に応じて軌道修正を指示する。

#### 報告が**不要**なケース
- 通常のタスク遂行（割り当て済みタスクの実行）
- 改善提案（kaizen_candidate としての報告）
- ファイル整理（リネーム・移動・不要ファイル削除）
- memory/*.md の更新（追記）
- テスト・lint・ビルドの実行
- instructions/scripts/config/templatesの自律改善
