# インストール手順書

## 所要時間の目安

約 **20〜30分**（DMM API審査済みの場合）

---

## 事前準備チェックリスト

### 必要なアカウント（すべて無料）

- [ ] [GitHub](https://github.com/) アカウント
- [ ] [Supabase](https://supabase.com/) アカウント
- [ ] [Cloudflare](https://www.cloudflare.com/) アカウント
- [ ] [FANZA アフィリエイト](https://affiliate.dmm.com/) アカウント（API審査通過済み）

> **DMM API の審査について**  
> アフィリエイト登録後、API利用申請が必要です。審査は通常 **数日〜1週間** かかります。  
> 審査中でもセットアップは進められます（APIキーの入力だけ後回しにしてください）。

---

## STEP 0: 必要なCLIをインストール

### Mac / Linux

```bash
# Homebrew がなければ先にインストール
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 必要ツールを一括インストール
brew install git gh supabase/tap/supabase node@22
brew link node@22 --force
npm install -g wrangler
```

### Windows

```powershell
# winget（Windows 11 標準）でインストール
winget install OpenJS.NodeJS.LTS Git.Git GitHub.cli

# Supabase CLI（Scoop 経由）
# PowerShell で Scoop をインストール
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase

# Wrangler
npm install -g wrangler
```

インストール後、ターミナルを再起動して以下で確認してください。

```bash
node --version   # v22 以上
gh --version
supabase --version
wrangler --version
```

---

## STEP 1: ファイルを展開する

### Mac

受け取った `dmm-seo-kit-beta.zip` をダブルクリックして展開し、ターミナルで展開先に移動します。

```bash
cd ~/Downloads/dmm-seo-kit-beta
```

### Windows

エクスプローラーで `dmm-seo-kit-beta.zip` を右クリック → **すべて展開** → 展開先フォルダを開き、アドレスバーにパスをコピー。PowerShell で移動します。

```powershell
cd C:\Users\あなたのユーザー名\Downloads\dmm-seo-kit-beta
```

---

## STEP 2: site.config.js を編集

**セットアップ前に必ず編集してください。** セットアップスクリプトがこのファイルから値を自動読み込みします。

```bash
# エディタで開く（VS Code の場合）
code site.config.js
```

### 必須項目

```js
siteName: 'あなたのサイト名',          // 例: 'FANZA動画まとめ'
siteDescription: 'サイトの説明文',     // meta description に使用
tagline: 'キャッチコピー',             // TOPページに表示
contactEmail: 'your@email.com',        // フッターのお問い合わせ先

dmm: {
  site: 'FANZA',       // 'FANZA' または 'DMM.co.jp'
  service: 'digital',  // サービスコード（下表参照）
  floor: 'videoa',     // フロアコード（下表参照）
  keyword: '',         // 絞り込みキーワード（空で全件取得）
},
```

### フロアコード一覧

| ジャンル | `service` | `floor` |
|---|---|---|
| 動画（メイン） | `digital` | `videoa` |
| 素人 | `digital` | `videoc` |
| アニメ動画 | `digital` | `anime` |
| 成人映画 | `digital` | `nikkatsu` |
| 見放題DX | `monthly` | `premium` |
| VR | `monthly` | `vr` |
| 同人 | `doujin` | `digital_doujin` |
| 電子書籍（コミック） | `ebook` | `comic` |
| DVD | `mono` | `dvd` |

### 機能フラグ（フロアに合わせて設定）

```js
features: {
  actresses:    true,   // 女優ページ・出演者情報（動画系はtrue、同人・ebook系はfalse）
  sampleMovie:  true,   // サンプル動画プレイヤー（動画系はtrue）
  trialReading: false,  // 電子書籍の立ち読み（ebook系のみtrue）
  duration:     true,   // 収録時間（動画・DVD系はtrue）
  director:     true,   // 監督情報
  maker:        true,   // メーカー・レーベル・シリーズ
  vrBadge:      false,  // VRバッジ（monthly/vr のみtrue）
},

ctaLabel: 'FANZAで見る',  // 購入ボタンのテキスト
```

---

## STEP 3: セットアップスクリプトを実行

### Mac / Linux

```bash
chmod +x setup.sh
./setup.sh
```

### Windows

```bat
setup.bat
```

### スクリプトが自動で行うこと

| ステップ | 内容 |
|---|---|
| STEP 1 | 必要CLIのインストール確認 |
| STEP 2 | プロジェクト名の入力・サイト情報の自動読み込み |
| STEP 3 | GitHub / Supabase / Cloudflare へのログイン |
| STEP 4 | Supabase プロジェクト作成・DBマイグレーション実行 |
| STEP 5 | DMM APIキーの入力 |
| STEP 6 | `.env` ファイルの自動生成 |
| STEP 7 | `wrangler.toml` / `site.config.js` の自動更新 |
| STEP 8 | GitHub リポジトリ作成・Secrets 登録 |
| STEP 9 | Cloudflare Pages への初回デプロイ |

### 入力が必要な項目（5項目）

| 項目 | 説明 | 取得場所 |
|---|---|---|
| **プロジェクト名** | 英小文字・ハイフン。例: `my-dmm-site` | 自由に決める |
| **DMM API ID** | DMM Web API の ID | [affiliate.dmm.com/api/](https://affiliate.dmm.com/api/) |
| **DMM アフィリエイトID** | 例: `xxxxx-999` | 同上 |
| **管理画面メールアドレス** | `/admin` ログインに使うアドレス | 自分のメアド |
| **Cloudflare API Token** | デプロイ用トークン（下記参照） | Cloudflare Dashboard |

> GitHub / Supabase のログインはブラウザが自動で開きます。  
> DBパスワード・GitHubリポジトリ名・Supabaseプロジェクト名は自動生成・自動設定されます。

### Cloudflare API Token の取得方法

1. [Cloudflare Dashboard](https://dash.cloudflare.com/) にログイン
2. 右上のアイコン → **My Profile** → **API Tokens**
3. **Create Token** → テンプレート一覧から **Edit Cloudflare Workers** を選択
4. **Account Resources**: 自分のアカウントを選択
5. **Zone Resources**: All zones（または対象ドメイン）
6. **Continue to summary** → **Create Token**
7. 表示されたトークンをコピー（この画面を閉じると二度と表示されません）

---

## STEP 4: 初期データを投入

セットアップ完了後、GitHub Actions から `backfill` を手動実行してDMMから作品データを一括取得します。

1. GitHub リポジトリ → **Actions** タブを開く
2. 左メニューから **backfill** を選択
3. **Run workflow** → **Run workflow** をクリック
4. 完了まで 5〜15分 待つ

完了後、サイトに作品データが表示されます。

---

## STEP 5: 動作確認

```
https://your-project.pages.dev
```

| チェック項目 | 確認方法 |
|---|---|
| TOPページが表示される | ブラウザでアクセス |
| 作品が表示される | backfill 完了後に確認 |
| 管理画面にログインできる | `/admin` → メールアドレス入力 → Magic Link |
| 自動同期が動く | Actions → `sync-products` が定期実行されているか確認 |

---

## セットアップ後の設定変更

### サイト名・説明文・デザインを変えたい

`site.config.js` を編集して再デプロイするだけです。

```bash
# 変更後に再デプロイ
cd astro && npm run build && npx wrangler deploy --config dist/server/wrangler.json && cd ..
```

または GitHub にプッシュすれば自動デプロイされます（setup.sh 実行後、git リポジトリは自動作成済みです）。

### DMM フロア（ジャンル）を変えたい

フロアを変更すると取得データが丸ごと変わります。

1. `site.config.js` の `dmm.service` / `dmm.floor` を変更
2. GitHub Secrets を更新

```bash
gh secret set DMM_SERVICE --repo "ユーザー名/リポジトリ名" --body "digital"
gh secret set DMM_FLOOR   --repo "ユーザー名/リポジトリ名" --body "anime"
```

3. Supabase の `products` テーブルをクリア（任意）
4. GitHub Actions → `backfill` を手動実行

---

## トラブルシューティング

### `supabase` コマンドが見つからない

```bash
# Mac
brew install supabase/tap/supabase

# Windows（Scoop）
scoop install supabase
```

### `wrangler login` でブラウザが開かない

```bash
wrangler login --browser false
# 表示されたURLをブラウザに手動で貼り付ける
```

### Supabase のAPIキー自動取得に失敗した

スクリプトが手動入力を求めます。  
[Supabase Dashboard](https://supabase.com/dashboard) → プロジェクト → **Settings** → **API** から取得してください。

- **anon public キー** → `anon` の行
- **service_role キー** → `service_role` の行

### マジックリンクをクリックすると `localhost:3000` が開く

Supabase の Auth 設定 **Site URL** がデフォルト値 `http://localhost:3000` のままになっています。  
以下の手順で本番 URL に変更してください。

**① 本番 URL を確認する**

`site.config.js` を開き、`siteUrl` の値をコピーしておきます。

```js
siteUrl: 'https://my-site.username.workers.dev',  // ← この値
```

**② Supabase Dashboard で設定する**

1. [Supabase Dashboard](https://supabase.com/dashboard) を開き、該当プロジェクトを選択
2. 左メニュー → **Authentication** → **URL Configuration** を開く
3. **Site URL** の欄を、コピーした `siteUrl` の値に書き換える  
   例: `https://my-site.username.workers.dev`
4. **Redirect URLs** の **Add URL** をクリックし、以下を追加する  
   例: `https://my-site.username.workers.dev/admin/auth/callback`  
   （`siteUrl` の末尾に `/admin/auth/callback` をつけた URL）
5. **Save** をクリックして保存

> **補足**: セットアップスクリプト（`setup.sh` / `setup.bat`）は上記を自動で設定します。  
> 手動でプロジェクトを作成した場合や設定が反映されていない場合に、この手順を実施してください。

### backfill 後も作品が表示されない

1. GitHub Actions のログを確認（エラーが出ていないか）
2. Supabase Dashboard → **Table Editor** → `products` テーブルにデータがあるか確認
3. `astro/.env` の `PUBLIC_SUPABASE_URL` / `PUBLIC_SUPABASE_ANON_KEY` が正しいか確認

---

## 独自ドメインを設定したい

1. Cloudflare Pages → プロジェクト → **Custom domains** → **Set up a custom domain**
2. ドメインを入力して DNS を設定
3. `site.config.js` の `siteUrl` を独自ドメインに変更して再デプロイ

---

*本テンプレートはFANZA（DMM）アフィリエイトプログラムの利用を前提としています。*  
*18歳未満の方の利用はお断りしております。*
