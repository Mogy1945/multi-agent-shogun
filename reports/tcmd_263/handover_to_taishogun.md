# tcmd_263 weight-diary — 大将軍引き渡しドキュメント

- **作成者**: ashigaruB2 (シニアテクニカルライター視点)
- **作成日**: 2026-04-27
- **parent_tcmd**: tcmd_263
- **目的**: tcmd_263 全Phase完遂後、将軍B → 大将軍 への引き渡し用クロージング情報。大将軍が殿に伝えるサマリと、殿が引き渡し後に実行する7項目を集約。
- **併読**: `reports/tcmd_263/implementation_summary.md` (全工程サマリ、本ドキュメントは引き渡し用要約)

---

## 1. 概要

tcmd_263 は **「殿の体重日記アプリを全面ブラッシュアップ」** を目的に発令された、軍B単独 5 Phase / 9 cmd / 8足軽 + 家老B直対応3回 の開発プロジェクト。

- **開始**: 2026-04-26 22:36 (cmd_B044 発令)
- **完遂見込み**: 2026-04-27 (Phase5 cmd_B049 完了時)
- **状態**: Phase1-4 マージ済 (33cf521 HEAD)、Phase5 進行中 (本ドキュメント+B1 vercel連携準備が並列、家老B統括push+PR編纂で close)
- **本番稼働**: **殿アクション7項目** (下記§2) を順次実行で本番稼働完了見込み

---

## 2. 本番稼働までの殿アクション7項目

引き渡し後、殿が実行する項目。詳細は `reports/tcmd_263/tono_actions_required.md` (B1 作成、本Phase5 並列実行中) 参照。

| 優先 | 項目 | 参照ドキュメント | 想定時間 |
|------|------|-----------------|---------|
| **必須** | (1) firestore.rules デプロイ (`firebase deploy --only firestore:rules`) | `reports/tcmd_263/firestore_rules_deploy_guide.md` | 5分 |
| **必須** | (2) Vercel Import Repository (Mogy1945/weight-diary を Private で接続) | `reports/tcmd_263/vercel_setup_guide.md` | 10分 |
| **必須** | (3) Vercel 環境変数 6項目+VITE_USE_FIRESTORE=true 投入 (Production/Preview/Development 3スコープで同値) | `reports/tcmd_263/vercel_setup_guide.md` | 10分 |
| **必須** | (4) Vercel 配布URL を Firebase Console の「承認済みドメイン」に追加 | `reports/tcmd_263/vercel_setup_guide.md` | 5分 |
| **必須** | (5) 本番URL で E2E 確認 (Google ログイン → 記録 → 別端末同期 → オフライン) | `reports/tcmd_263/tono_e2e_checklist.md` | 15分 |
| 任意 | (6) カスタムドメイン設定 (gakkounofumoto.jp 等の体重日記用ドメイン取得時) | `reports/tcmd_263/vercel_setup_guide.md` | 後回し可 |
| 任意 | (7) firestore.rules 強化版適用 (書込サイズ制限+weight値域チェック+entryId形式検証) | Phase5 以降切り出し | 後回し可 |

> **必須(1)〜(5) のみで本番稼働開始**。任意(6)(7) は時間がある時で良い。

---

## 3. 大将軍が殿に伝えるサマリ

### 3-1. ビフォア (Phase1 cmd_B044 発令時点)

- src/App.jsx **742行 1ファイル単独アプリ** (殿曰く「適当に作った」)
- useState 散在 (約20箇所)、コンポーネント分割なし
- localStorage に state 全体丸ごと永続化 (`load/save` 2メソッドのみ)
- recharts AreaChart 1系列 (体重のみ)、統計カード 8種類が単一フラットレイアウト
- WCAG AA タップ44px 違反多数 (履歴ボタン4箇所/カレンダー6列/設定トグル/CSV ボタン)
- ダークモード未対応、PWA 未対応、Firebase 未接続、認証なし、プライバシーポリシーなし
- Initial commit 3805f81 のみ、ローカル/リモート同一 (.github/workflows/deploy.yml は GitHub Pages 用)

### 3-2. アフター (Phase5 cmd_B049 close 時点)

- **アーキテクチャ**: 8ファイル4層分割 (App.jsx 80行以下、`lib/` `state/` `hooks/` `components/`)
- **状態管理**: useReducer + Context (Zustand/Jotai/Redux Toolkit は不採用、ROI 不足)
- **データ**: entries 新スキーマ `{morning, night, dayNote}` 1日1行2フィールド方式 (review.md §1-1 b案)
- **永続化**: repository pattern 9メソッド (LocalStorage / Firestore 切替、`VITE_USE_FIRESTORE` フラグ)
- **グラフ**: recharts LineChart 4系列 (朝実線 + 夜破線 + 7日朝移動平均 + 目標 ReferenceLine)
- **統計**: StatCard 6+4 二層 (デフォルト6枚 + 詳細トグル4枚)
- **モバイルUX**: WCAG AA 119/119 PASS、iOS フォーカスズーム抑制、セーフエリア対応、タップ補助CSS
- **ダークモード**: CSS変数化 + tailwind.config darkMode + theme-color 動的化 (Claude Design 待ちの値プレースホルダ済)
- **PWA**: vite-plugin-pwa (Lighthouse Installable=PASS, PWA Optimized 85+、precache 15 entries)
- **継続性UX**: ストリーク2日復活猶予 + 過去日補記入リンク + soft visual reminder (朝14時超で朝タブ淡色注意色)
- **Firebase**: Google認証 + FirestoreEntryRepository 9メソッド + IndexedDB persistence + 移行UI + Security Rules + アカウント削除 + プライバシーポリシーpage
- **テスト**: vitest 24/24 PASS (date 7 + reducer 17)
- **CI/CD**: Vercel連携準備 (vercel.json + README デプロイ手順 + GitHub Pages workflow 削除予定)

### 3-3. 工数累計 (実績は `implementation_summary.md` §2 参照)

- review.md 上限想定 60-65h (8人日)
- 実績 約86h相当 (Phase1多軸レビュー + Phase2-fix + K-F001例外3連 + Phase4 interface整合救済 + Phase5 統括の家老B直対応工数を含む実時間)
- 純実装工数換算では上限内、家老B統括/救済工数で +20h 程度上振れ
- 殿の所要工数 (引き渡し後): **必須5項目で約45分、任意2項目は時間がある時に**

### 3-4. PR 一覧 (殿が GitHub で確認できる成果物)

- PR #1 Phase2 (https://github.com/Mogy1945/weight-diary/pull/1, f898ef9, 25 files +6840/-736)
- PR #2 Phase3 (https://github.com/Mogy1945/weight-diary/pull/2, eac5976, 11 files +5411/-1384)
- PR #3 Phase4 (https://github.com/Mogy1945/weight-diary/pull/3, 33cf521, 13 files +2724/-99)
- PR #4 Phase5 (本Phase、家老B統括時に push予定)

---

## 4. 未着手項目 (Phase5 以降切り出し)

tcmd_263 では実装せず、後続 tcmd で切り出す候補:

### 4-1. firestore.rules 強化版

- **現状**: 基本Rules (request.auth.uid 制御のみ) は Phase4 B8 でデプロイ済
- **強化版で追加すべき項目**:
  - 書込サイズ制限 (1ドキュメントあたりの最大サイズ、過大 entries 防止)
  - weight 値域チェック (10kg-300kg 等の妥当範囲、誤入力防止)
  - entryId 形式検証 (yyyy-mm-dd 正規表現、不正キー防止)
- **優先度**: 任意・後回し可。Phase4 B8 の基本Rules で本番稼働は可能

### 4-2. Firebase SDK code-splitting (kaizen 候補 #9)

- **問題**: Phase3 580 KiB → Phase4 1126→1147 KiB (firebase SDK +540 KiB)
- **対策**: dynamic import で auth/firestore を分離、初回ロード軽量化
- **優先度**: 体重日記の規模で実害は小さいが Vercel CDN 配信コスト最適化候補

### 4-3. Claude Design による本格ビジュアル刷新 (Phase1 b3 §3 D-01〜D-09)

- **現状**: ダークモード CSS変数枠と必須改修 8件 (M-01〜M-08) は Phase2 で実装済、ビジュアル本格刷新は未着手
- **D-01〜D-09 (b3_mobile_design.md §3 参照)**:
  - D-01 下部固定FAB
  - D-02 ダーク本格パレット (現在は枠のみ、値が暫定)
  - D-03 タイポ階層
  - D-04 カレンダービジュアル
  - D-05 ステータスカード再編
  - D-06 グラフ視覚刷新
  - D-07 アイコンセット
  - D-08 モーション
  - D-09 ブランドカラー意味論
- **優先度**: 殿の好み次第。引き渡し後に殿が「本格ビジュアル刷新したい」と思ったら別 tcmd で発令

### 4-4. SettingsPanel 分割 (kaizen 候補 #10)

- **問題**: Phase4 で SettingsPanel.jsx が 420行に肥大化 (Phase2 で抜き出した直後は 200行程度)
- **対策**: AccountSection / DataMigrationSection / PrivacySection に再分割
- **優先度**: 体感影響なし、リファクタリング tcmd で扱う

---

## 5. kaizen棚卸し方針 (Phase5 close 時に大将軍裁定で kaizen.yaml 転記)

> **方針変更**: 当初 Phase4 close 時の予定だったが、**Phase5 close 時に大将軍裁定で kaizen.yaml に一括転記** に変更。本Phaseで一括棚卸しを完遂させる。

10件の正準リスト (詳細は `implementation_summary.md` §5 参照):

| # | タイトル (1行サマリ) | 起票元 |
|---|---------------------|--------|
| 1 | Playwright モバイル監査 WCAG AA は getBoundingClientRect (border込み) が正解 | cmd_B046 |
| 2 | SubAgent Bash run_in_background + Monitor待機 → tool timeout return → 全面禁止運用へ | cmd_B047 (B4起票) |
| 3 | WSL2 sharp install 15分stuck → Playwright SVG→PNG レンダ代替 | cmd_B047a |
| 4 | 3 tcmd 分割発令 (Phase毎) で家老の認知負荷分散 | review.md §0-3 |
| 5 | SubAgent commit→reset→再commit 他足軽差分巻き込み消失 → reflog cherry-pick救済 | cmd_B047b |
| 6 | shogunB裁定中の家老B独断ガード文言 (高優先案件で複数選択肢ある場合の運用) | tcmd_263 横断 |
| 7 | 秘匿情報の伝達経路 (apiKey/トークン等) — YAML/Memory/Task に値書かず、tmux send-keys + .env.local 直投入 | cmd_B048 ゲート解除運用 |
| 8 | Phase間 interface 設計乖離の早期発見 (DoD に interface整合確認を含める運用) | cmd_B048a (B6起票) |
| 9 | Firebase SDK追加でビルドサイズ倍増 → code-splitting 検討 | cmd_B048a (shogunB起票) |
| 10 | SettingsPanel 420行肥大化 → 分割候補 | cmd_B048 B8 |

K-F001例外発動の運用基準明文化 (#6 関連) も含めて大将軍裁定で正式起票検討。

---

## 6. 大将軍 → 殿への引き渡し時 推奨メッセージ (将軍B提案)

> 殿
>
> 体重日記アプリの全面ブラッシュアップ tcmd_263 を完遂しました。
>
> 開始時点の src/App.jsx 742行 1ファイル単独アプリから、8ファイル4層分割 + useReducer+Context + repository pattern + PWA + Firebase + Google認証 + プライバシーポリシー + アカウント削除 + 移行UI + Vercel連携準備 まで到達しました。
>
> 本番稼働まで、殿のお手元で実行いただく作業は **5項目で約45分** です:
> 1. firestore.rules デプロイ (5分) — `reports/tcmd_263/firestore_rules_deploy_guide.md`
> 2. Vercel Import Repository (10分) — `reports/tcmd_263/vercel_setup_guide.md`
> 3. Vercel 環境変数 6項目+VITE_USE_FIRESTORE 投入 (10分) — 同上
> 4. Vercel 配布URL を Firebase Console 承認済みドメインに追加 (5分) — 同上
> 5. 本番URL で E2E 確認 (15分) — `reports/tcmd_263/tono_e2e_checklist.md`
>
> 任意で、カスタムドメイン (6) と firestore.rules 強化版 (7) を後でご検討ください。
>
> Claude Design による本格ビジュアル刷新 (D-01〜D-09) と Firebase SDK code-splitting は別 tcmd で発令可能です。ご希望時にお申し付けください。
>
> PR #1/#2/#3 はマージ済 (commit 33cf521 HEAD)、PR #4 (Phase5) は本Phase完了時に push 予定。
> 詳細サマリは `reports/tcmd_263/implementation_summary.md` ご参照。

---

## 7. 関連ドキュメント

- 全工程サマリ (本ドキュメントと併読): `reports/tcmd_263/implementation_summary.md`
- 殿実行用ガイド (Firebase setup): `reports/tcmd_263/firebase_setup_guide.md`
- 殿実行用ガイド (firestore.rules deploy): `reports/tcmd_263/firestore_rules_deploy_guide.md`
- 殿実行用ガイド (Vercel Import + 環境変数投入): `reports/tcmd_263/vercel_setup_guide.md` (B1 並列実行中)
- 殿アクション集約: `reports/tcmd_263/tono_actions_required.md` (B1 並列実行中)
- E2Eチェックリスト: `reports/tcmd_263/tono_e2e_checklist.md`
- プライバシーポリシー雛形 (実装済): `reports/tcmd_263/privacy_policy_draft.md`
- Phase1 多軸レビュー: `reports/tcmd_263/review.md`
- Before/After スクショindex: `reports/tcmd_263/before_after_screenshots/INDEX.md`
- 軍B 大本山 cmd 履歴: `queue/armyB/shogun_to_karo.yaml` cmd_B044〜cmd_B049
