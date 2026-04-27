# tcmd_263 Before / After スクリーンショット index

- **作成者**: ashigaruB2 (シニアテクニカルライター視点)
- **作成日**: 2026-04-27
- **parent_tcmd**: tcmd_263
- **目的**: 各 Phase 完遂時の証跡スクショを横串で対比できるように整理。スクショ自体は既存 `phase{2,3,4}/` から **移動せず参照リンクで統合**。

---

## 0. 凡例

- **Before (tcmd_263 開始前)**: Phase1 cmd_B044 発令時点の `src/App.jsx 742行 1ファイル単独アプリ` のスクショは **存在しない** (Initial commit 3805f81 のみ、視覚証跡未取得)
  - 代わりに `reports/tcmd_263/b1_functional.md §1-1` および `reports/tcmd_263/b3_mobile_design.md §1` の **文章記述** で再現
  - 殿曰く「適当に作った」: useState 散在、コンポーネント分割なし、recharts AreaChart 1系列、WCAG AA 違反多数、ダークモード未対応、PWA 未対応
- **After**: 各 Phase 完遂時のスクショ (Playwright 4 viewport: 375 / 390 / 412 / 1440)

---

## 1. Phase 別 Before / After 対比表

### 1-1. Phase2 完遂時 — `reports/tcmd_263/phase2/`

| ファイル | 内容 | 対応する Before との差分 |
|---------|------|----------------------|
| [`phase2/iphone_se_375.png`](../phase2/iphone_se_375.png) | iPhone SE (375x667) 主画面、データ無し状態 | App.jsx 742行 1ファイル → 8ファイル4層分割、StatCard 6+4二層、LineChart 4系列の枠 |
| [`phase2/iphone_se_375_with_data.png`](../phase2/iphone_se_375_with_data.png) | iPhone SE (375x667) 30日データ投入後、グラフ+統計+履歴 | recharts AreaChart 1系列 → LineChart 4系列 (朝実線+夜破線+7日朝移動平均+目標) |
| [`phase2/iphone_14_390.png`](../phase2/iphone_14_390.png) | iPhone 14 (390x844) 主画面 | M-01 セーフエリア対応、M-04 ラベル色 5.8:1 達成 |
| [`phase2/pixel_7_412.png`](../phase2/pixel_7_412.png) | Pixel 7 (412x892) 主画面 | M-05 記録ボタン w-full md:min-w-[160px]、M-06 タップ補助CSS |
| [`phase2/desktop_1440.png`](../phase2/desktop_1440.png) | デスクトップ (1440x900) 主画面 | コンポーネント分割によるレスポンシブ余白の改善 |
| [`phase2/dark_mode_simulated_375.png`](../phase2/dark_mode_simulated_375.png) | iPhone SE (375x667) ダークモード | OS ダークモード未対応 → CSS変数 (--c-paper/--c-card/--c-ink/...) 枠 + tailwind.config darkMode + theme-color 動的化 |
| [`phase2/edit_modal_opened.png`](../phase2/edit_modal_opened.png) | 履歴行タップで編集モーダル開いた状態 | M-08 履歴行全体タップで編集モード (role="button" + イベント伝播制御) |
| [`phase2/cmd_B046_after.png`](../phase2/cmd_B046_after.png) | WCAG AA cmd_B046 修正後 (EntryForm h-11 / StatsGrid min-h-[44px]) | WCAG AA 違反 87→0、cmd_B046 後 119/119 PASS (家老B直対応 K-F001例外1回目) |

**Phase2 検証**: vitest 24/24 PASS / vite build 555 KB / WCAG AA 119/119 PASS / 30日データ投入動作確認

### 1-2. Phase3 完遂時 — `reports/tcmd_263/phase3/`

| ファイル | 内容 | 対応する Before との差分 (Phase2比) |
|---------|------|----------------------|
| [`phase3/phase3_iphone_se_375.png`](../phase3/phase3_iphone_se_375.png) | iPhone SE (375x667) PWA 適用後 | manifest.json + apple-touch-icon-180 + apple-mobile-web-app-capable で「ホーム画面に追加」可能、ストリーク2日復活猶予 + 過去日補記入リンク |
| [`phase3/phase3_iphone14_390.png`](../phase3/phase3_iphone14_390.png) | iPhone 14 (390x844) PWA 適用後 | iOS Safari の standalone 起動 + theme_color 反映 |
| [`phase3/phase3_pixel7_412.png`](../phase3/phase3_pixel7_412.png) | Pixel 7 (412x892) PWA 適用後 | Android の PWA インストール対応 |
| [`phase3/phase3_desktop_1440.png`](../phase3/phase3_desktop_1440.png) | デスクトップ (1440x900) PWA 適用後 + soft visual reminder | 朝14時超で朝未記録なら EntryForm の朝タブが淡色注意色 |

**Phase3 検証**: Lighthouse PWA Installable=PASS / PWA Optimized=85+ / precache 15 entries 580.84 KiB / vitest 24/24 PASS / 4 viewport PWA インストール動作確認

### 1-3. Phase4 完遂時 — `reports/tcmd_263/phase4/`

LocalStorage モード (Phase3 までの動作維持) と Firestore signin モード (新規) の両方を撮影。

| ファイル | 内容 | 対応する Before との差分 (Phase3比) |
|---------|------|----------------------|
| [`phase4/local_mode.png`](../phase4/local_mode.png) | LocalStorage モード 主画面 (VITE_USE_FIRESTORE=false) | repository pattern 9メソッド化 (getEntry/listEntries/saveEntry/deleteEntry/getSettings/saveSettings/exportAll/importAll/onAuthChange)、Phase2 動作維持 |
| [`phase4/local_mode_375.png`](../phase4/local_mode_375.png) | LocalStorage モード iPhone SE (375x667) | 同上、認証UI不在で記録UI即表示 |
| [`phase4/local_mode_390.png`](../phase4/local_mode_390.png) | LocalStorage モード iPhone 14 (390x844) | 同上 |
| [`phase4/local_mode_412.png`](../phase4/local_mode_412.png) | LocalStorage モード Pixel 7 (412x892) | 同上 |
| [`phase4/local_mode_1440.png`](../phase4/local_mode_1440.png) | LocalStorage モード デスクトップ (1440x900) | 同上 |
| [`phase4/firestore_signin.png`](../phase4/firestore_signin.png) | Firestore モード サインイン画面 (VITE_USE_FIRESTORE=true、未ログイン) | Firebase 未接続/認証なし → AuthGate.jsx で Google サインインボタン表示、未ログイン時は記録UI保護 |
| [`phase4/firestore_signin_375.png`](../phase4/firestore_signin_375.png) | Firestore モード サインイン画面 iPhone SE (375x667) | 同上、apiKey値非露出スクショで個人情報非露出 |
| [`phase4/firestore_signin_1440.png`](../phase4/firestore_signin_1440.png) | Firestore モード サインイン画面 デスクトップ (1440x900) | 同上 |
| [`phase4/privacy_page_375.png`](../phase4/privacy_page_375.png) | プライバシーポリシーpage (`/privacy`) iPhone SE (375x667) | プライバシーポリシー未対応 → src/pages/Privacy.jsx 実装、フッターからリンク |
| [`phase4/privacy_page_1440.png`](../phase4/privacy_page_1440.png) | プライバシーポリシーpage (`/privacy`) デスクトップ (1440x900) | 同上 |

**Phase4 検証**: vitest 24/24 PASS / vite build precache 15 entries 1147 KiB (firebase SDK +540 KiB) / apiKey grep 0ヒット (PR diff/全ソース/.env.local 完全分離) / 両モード手動検証 PASS / KZ-158 shogunB独立検証 PASS

### 1-4. Phase5 完遂時 (本Phase進行中)

- 画面側変更なし (Vercel連携準備のみ、vercel.json + README + workflow削除)
- 本番稼働確認スクショは **殿アクション5(本番URL E2E確認)** で取得予定 (`reports/tcmd_263/tono_e2e_checklist.md` 参照)

---

## 2. 4 viewport カバレッジ

Playwright で全 Phase で巡回した 4 viewport:

| viewport | 機種 | Phase2 | Phase3 | Phase4 LocalStorage | Phase4 Firestore signin |
|---------|------|--------|--------|---------------------|------------------------|
| 375x667 | iPhone SE | [`phase2/iphone_se_375.png`](../phase2/iphone_se_375.png) + [`phase2/iphone_se_375_with_data.png`](../phase2/iphone_se_375_with_data.png) | [`phase3/phase3_iphone_se_375.png`](../phase3/phase3_iphone_se_375.png) | [`phase4/local_mode_375.png`](../phase4/local_mode_375.png) | [`phase4/firestore_signin_375.png`](../phase4/firestore_signin_375.png) |
| 390x844 | iPhone 14 | [`phase2/iphone_14_390.png`](../phase2/iphone_14_390.png) | [`phase3/phase3_iphone14_390.png`](../phase3/phase3_iphone14_390.png) | [`phase4/local_mode_390.png`](../phase4/local_mode_390.png) | (firestore_signin は 375/1440 のみ撮影) |
| 412x892 | Pixel 7 | [`phase2/pixel_7_412.png`](../phase2/pixel_7_412.png) | [`phase3/phase3_pixel7_412.png`](../phase3/phase3_pixel7_412.png) | [`phase4/local_mode_412.png`](../phase4/local_mode_412.png) | (同上) |
| 1440x900 | デスクトップ | [`phase2/desktop_1440.png`](../phase2/desktop_1440.png) | [`phase3/phase3_desktop_1440.png`](../phase3/phase3_desktop_1440.png) | [`phase4/local_mode_1440.png`](../phase4/local_mode_1440.png) | [`phase4/firestore_signin_1440.png`](../phase4/firestore_signin_1440.png) |

---

## 3. 機能別 Before / After 対比

| 機能 | Before (tcmd_263 開始前、文章記述) | After (Phase4 完遂時) | 主スクショ |
|------|-------------------------------|----------------------|-----------|
| アーキテクチャ | App.jsx 742行 1ファイル + useState 散在 | 8ファイル4層分割 + useReducer+Context + repository pattern 9メソッド | (各 Phase の主画面で確認可) |
| グラフ | recharts AreaChart 1系列 (体重のみ) | recharts LineChart 4系列 (朝実線+夜破線+7日朝移動平均+目標 ReferenceLine) | [`phase2/iphone_se_375_with_data.png`](../phase2/iphone_se_375_with_data.png) |
| 統計カード | 8種類フラット | 6+4 二層 (デフォルト6枚 + 詳細トグル4枚) | [`phase2/iphone_se_375_with_data.png`](../phase2/iphone_se_375_with_data.png) |
| WCAG AA | 違反多数 (履歴ボタン4箇所/カレンダー/設定/CSV) | 119/119 PASS (cmd_B046 後) | [`phase2/cmd_B046_after.png`](../phase2/cmd_B046_after.png) |
| ダークモード | 未対応 | CSS変数枠 + tailwind.config darkMode + theme-color 動的化 (Claude Design 待ちの値プレースホルダ済) | [`phase2/dark_mode_simulated_375.png`](../phase2/dark_mode_simulated_375.png) |
| 編集UX | 履歴ボタンクリック | 履歴行全体タップ (role="button" + イベント伝播制御) | [`phase2/edit_modal_opened.png`](../phase2/edit_modal_opened.png) |
| PWA | 未対応 | Lighthouse Installable=PASS / PWA Optimized 85+、manifest+icons 4枚+iOS meta 4行 | [`phase3/phase3_iphone_se_375.png`](../phase3/phase3_iphone_se_375.png) |
| 継続性UX | なし | ストリーク2日復活猶予 + 過去日補記入リンク + soft visual reminder (朝14時超 朝未記録で朝タブ淡色注意色) | [`phase3/phase3_desktop_1440.png`](../phase3/phase3_desktop_1440.png) |
| Firebase 接続 | 未接続 | Google認証 + FirestoreEntryRepository 9メソッド + IndexedDB persistence | [`phase4/firestore_signin.png`](../phase4/firestore_signin.png) |
| 認証UI | なし | AuthGate.jsx (サインインボタン+ユーザー状態表示+サインアウト+認証中スピナー) | [`phase4/firestore_signin.png`](../phase4/firestore_signin.png) |
| 移行UI | なし | SettingsPanel 拡張「☁ クラウドに取り込む」(確認ダイアログ+進捗表示+ローカル削除オプション) | (SettingsPanel 操作スクショは Phase4 動作確認時の手動検証ログに記録、本indexでは省略) |
| アカウント削除 | なし | SettingsPanel「アカウント削除」(users/{uid} 全削除、確認ダイアログ2段階) | (同上) |
| プライバシーポリシー | なし | src/pages/Privacy.jsx 実装、フッターからリンク | [`phase4/privacy_page_375.png`](../phase4/privacy_page_375.png) + [`phase4/privacy_page_1440.png`](../phase4/privacy_page_1440.png) |
| repository モード切替 | なし (localStorage 単一) | VITE_USE_FIRESTORE フラグで LocalStorage / Firestore 切替 (両モード手動検証 PASS) | [`phase4/local_mode.png`](../phase4/local_mode.png) (LocalStorage) + [`phase4/firestore_signin.png`](../phase4/firestore_signin.png) (Firestore) |

---

## 4. 注意事項

- **apiKey値非露出**: Phase4 Firestore signin モードのスクショは **未ログイン状態**で撮影、apiKey値・projectId値・認証済みアカウント情報は非露出 (`reports/tcmd_263/firebase_setup_guide.md` の秘匿運用方針に準拠)
- **スクショの再撮影は不要**: 既存 `phase2/` `phase3/` `phase4/` のスクショで Phase 別 Before/After は十分カバー、本indexはリンク統合のみ
- **本番URL での E2E 確認スクショ**: 殿アクション5 (E2E チェックリスト実行) で殿が撮影予定。本indexには含めない (`reports/tcmd_263/tono_e2e_checklist.md` 参照)

---

## 5. 関連ドキュメント

- 全工程サマリ: [`../implementation_summary.md`](../implementation_summary.md)
- 大将軍引き渡し: [`../handover_to_taishogun.md`](../handover_to_taishogun.md)
- Phase1 多軸レビュー: [`../review.md`](../review.md)
- Phase1 b3 モバイルUX (D-01〜D-09 のビジュアル刷新候補): [`../b3_mobile_design.md`](../b3_mobile_design.md)
- E2Eチェックリスト (本番URL での殿確認用): [`../tono_e2e_checklist.md`](../tono_e2e_checklist.md)
