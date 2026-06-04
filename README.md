# DMM DB型SEOアフィリエイトサイト 構築キット

FANZAのAPIで作品データを自動取得・蓄積し、毎日自動更新されるDB型アフィリエイトサイトを  
**ほぼ無料**で構築・運用できるテンプレートです。

---

## 特徴

- **月額費用ほぼ0円** — Cloudflare Pages・Supabase・GitHub Actionsはすべて無料枠で動作
- **毎日自動更新** — GitHub Actionsが深夜にDMM APIを叩いてDBを自動更新
- **高速表示** — Cloudflare CDNで世界中から高速配信
- **SEO対応済み** — sitemap・JSON-LD・canonical・meta tags を自動生成
- **1ファイル設定** — `site.config.js` を編集するだけでサイト名・ジャンル・テーマを変更可能
- **管理画面付き** — `/admin` からテーマ変更・商品管理・ログ確認が可能

---

## 必要なアカウント（すべて無料）

| サービス | 用途 |
|---|---|
| Cloudflare | ホスティング・CDN |
| Supabase | データベース |
| GitHub | コード管理・自動化 |
| DMM アフィリエイト | API・収益化 |

---

## 事前準備

### 1. 必要なCLIをインストール

**Mac / Linux**

```bash
# Homebrew がなければ先にインストール
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew install git gh supabase/tap/supabase
npm install -g wrangler
```

Node.js は https://nodejs.org/ からインストール（v18以上推奨）。

**Windows**

```powershell
# winget（Windows 11 標準）でまとめてインストール
winget install OpenJS.NodeJS Git.Git GitHub.cli

# Supabase CLI（Scoop 経由）
winget install Scoop.Scoop
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase

# Wrangler
npm install -g wrangler
```

> **Scoop が使えない場合** — Supabase CLI の最新バイナリを  
> https://github.com/supabase/cli/releases から手動でダウンロードして PATH に追加してください。

### 2. site.config.js を編集

`siteName` / `siteUrl` / `siteDescription` はセットアップスクリプトが自動で書き換えます。  
事前に決めておくのは **対象フロア** と **機能フラグ** です。

```js
dmm: {
  site: 'FANZA',        // サイトコード（下記フロア一覧を参照）
  service: 'digital',   // サービスコード
  floor: 'videoa',      // フロアコード
  keyword: '',          // 絞り込みキーワード（空で全件）
},

// フロアに合わせて有効にする機能を切り替える
features: {
  actresses:    true,   // 女優ページ・出演者情報
  sampleMovie:  true,   // サンプル動画プレイヤー
  trialReading: false,  // 電子書籍の立ち読みリンク
  duration:     true,   // 収録時間
  director:     true,   // 監督情報
  maker:        true,   // メーカー・レーベル・シリーズ
  vrBadge:      false,  // VRコンテンツバッジ
},

// 作品詳細ページの購入ボタンテキスト
ctaLabel: 'FANZAで見る',  // 例: 'ブックスで読む' | 'DVDを購入'
```

**フロア別 features プリセット**

| フロア | actresses | sampleMovie | trialReading | duration | director | maker | vrBadge |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| digital/videoa（ビデオ） | ✓ | ✓ | | ✓ | ✓ | ✓ | |
| digital/anime（アニメ） | | ✓ | | ✓ | | ✓ | |
| monthly/vr（VRch） | ✓ | ✓ | | ✓ | ✓ | ✓ | ✓ |
| ebook/*（ブックス） | | | ✓ | | | ✓ | |
| mono/dvd（DVD） | ✓ | | | ✓ | ✓ | ✓ | |
| doujin/*（同人） | | | | | | | |

**フロア一覧（site / service / floor の組み合わせ）**

`site` `service` `floor` の3つをセットで設定してください。

**FANZA（アダルト）— `site: 'FANZA'`**

| サービス名 | `service` | `floor` | 内容 |
|---|---|---|---|
| 動画 | `digital` | `videoa` | ビデオ（メイン） |
| 動画 | `digital` | `videoc` | 素人 |
| 動画 | `digital` | `nikkatsu` | 成人映画 |
| 動画 | `digital` | `anime` | アニメ動画 |
| 月額動画 | `monthly` | `premium` | 見放題chデラックス |
| 月額動画 | `monthly` | `vr` | VRch |
| 月額動画 | `monthly` | `standard` | 見放題ch |
| 通販 | `mono` | `dvd` | DVD |
| 通販 | `mono` | `goods` | 大人のおもちゃ |
| 通販 | `mono` | `pcgame` | PCゲーム |
| アダルトPCゲーム | `pcgame` | `digital_pcgame` | アダルトPCゲーム |
| 同人 | `doujin` | `digital_doujin` | 同人 |
| 同人 | `doujin` | `digital_doujin_bl` | らぶカル（BL） |
| 同人 | `doujin` | `digital_doujin_tl` | らぶカル（TL） |
| FANZAブックス | `ebook` | `comic` | コミック |
| FANZAブックス | `ebook` | `novel` | 美少女ノベル・官能小説 |
| FANZAブックス | `ebook` | `photo` | アダルト写真集・雑誌 |
| FANZAブックス | `ebook` | `bl` | BL |
| FANZAブックス | `ebook` | `tl` | TL |
| ブックス読み放題 | `unlimited_book` | `unlimited_comic` | 読み放題 |

**DMM.com（一般）— `site: 'DMM.com'`**

| サービス名 | `service` | `floor` | 内容 |
|---|---|---|---|
| DMMブックス | `ebook` | `comic` | コミック |
| DMMブックス | `ebook` | `novel` | 文芸・ラノベ |
| DMMブックス | `ebook` | `photo` | 写真集 |
| 通販 | `mono` | `dvd` | DVD・Blu-ray |
| 通販 | `mono` | `cd` | CD |
| 通販 | `mono` | `book` | 本・コミック |
| DMMTV | `dmmtv` | `dmmtv_video` | DMMTV |

---

## セットアップ（自動）

セットアップスクリプトが以下をすべて自動で実行します。

- Supabase プロジェクト作成 + DB マイグレーション
- GitHub リポジトリ作成 + Secrets 登録
- Cloudflare Pages への初回デプロイ

### Mac / Linux

```bash
# ZIPを展開したフォルダで実行
chmod +x setup.sh
./setup.sh
```

### Windows

```bat
# ZIPを展開したフォルダで実行
setup.bat
```

スクリプトの途中でブラウザが開き、各サービスへのログインを求められます。  
指示に従って進めると、完了後に以下のURLが表示されます。

```
Supabase ダッシュボード: https://supabase.com/dashboard/project/xxxxxxxx
GitHub リポジトリ:       https://github.com/your-name/your-repo
Cloudflare Pages:        https://your-project.pages.dev
```

---

## 初期データ投入

セットアップ完了後、GitHub Actions から `backfill` を手動実行して過去作品を取得します。

1. GitHub → Actions タブを開く
2. `backfill` ワークフローを選択
3. `Run workflow` をクリック

その後は毎日深夜に自動同期が走り、新着作品・ランキングが自動更新されます。

---

## 管理画面

`https://your-site.pages.dev/admin` から管理画面にアクセスできます。

ログインはメールアドレス入力のみ（Magic Link認証）。パスワード不要です。

| メニュー | URL | 機能 |
|---|---|---|
| ダッシュボード | `/admin` | 商品数・女優数・同期ログの確認 |
| テーマ | `/admin/themes` | 6種類のプリセットテーマ + カスタムカラー設定 |
| 商品管理 | `/admin/products` | 公開・非公開・ピックアップの切り替え |
| ムード設定 | `/admin/moods` | TOPページのムードボタン編集 |
| 同期ログ | `/admin/logs` | GitHub Actionsの実行履歴確認 |
| サイト設定 | `/admin/settings` | サイト名・説明文・その他設定の確認 |

管理者メールアドレスは `astro/.env` の `ADMIN_EMAIL` で指定します（カンマ区切りで複数可）。

---

## ディレクトリ構成

```
/
├── site.config.js          ← ★ サイト設定（ここを編集）
├── setup.sh                ← セットアップスクリプト（Mac/Linux）
├── setup.bat               ← セットアップスクリプト（Windows）
├── .env.example            ← 環境変数テンプレート
├── astro/                  ← フロントエンド（Astro SSR）
│   ├── src/pages/          ← ページ・APIルート
│   ├── src/components/     ← UIコンポーネント
│   └── src/lib/            ← Supabaseクライアント・ユーティリティ
├── scripts/                ← データ同期スクリプト（GitHub Actions で実行）
├── supabase/migrations/    ← DBスキーマ定義SQL
├── plugin/                 ← WordPress連携プラグイン（オプション）
│   └── dmm-genre-search/   ← ジャンル検索ウィジェット
└── .github/workflows/      ← 自動同期ワークフロー
```

---

## ページ一覧

| URL | 内容 |
|---|---|
| `/` | TOP（ムードUI・ランキング・新着） |
| `/explore/[mood]` | ムード別没入スクロール（TikTok風） |
| `/explore` | ムード一覧 |
| `/item/[id]` | 作品詳細 |
| `/products` | 作品一覧 |
| `/tag/[slug]` | タグ別一覧 |
| `/actress/[slug]` | 女優詳細（相関図付き） |
| `/actress` | 女優一覧 |
| `/ranking/[type]` | ランキング（新着・人気・ニッチ） |
| `/graph` | 女優相関図 |
| `/about` | サイト概要 |
| `/privacy` | プライバシーポリシー |
| `/admin` | 管理画面 |

---

## よくある質問

**Q. DMM APIの審査は通りますか？**  
A. DMM アフィリエイトに登録後、API利用申請が必要です。審査は通常数日かかります。

**Q. どのジャンルでも使えますか？**  
A. `site.config.js` の `dmm.floor` を変更することで、アニメ・同人・電子書籍など各ジャンルに対応できます。フロアによって表示される機能（サンプル動画・立ち読み・VRバッジなど）も自動で切り替わります。

**Q. Supabaseの無料枠で足りますか？**  
A. 無料枠（500MB）で作品データ約3〜5万件程度まで対応できます。

**Q. WordPressは必要ですか？**  
A. 不要です。Cloudflare Pages + Supabase + GitHub Actions のみで動作します。

**Q. セットアップスクリプトが途中でエラーになりました。**  
A. 各CLIが正しくインストールされているか確認してください。`supabase projects create` はSupabaseへのログインが必要です。

---

*本テンプレートはFANZA（DMM）アフィリエイトプログラムの利用を前提としています。*  
*18歳未満の方の利用はお断りしております。*
