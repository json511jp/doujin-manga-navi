# Supabase セットアップ手順

## 1. Supabaseプロジェクト作成

https://supabase.com/dashboard でプロジェクトを新規作成し、以下を控える:
- Project URL（例: `https://xxxx.supabase.co`）
- anon key（公開用・Astro側で使用）
- service_role key（GitHub Actions用・絶対に公開しない）

## 2. マイグレーション実行

Supabase Dashboard の **SQL Editor** で以下のファイルを順番に実行:

```
supabase/migrations/20260515000000_init.sql       — テーブル・インデックス・RLS
supabase/migrations/20260515000001_seed_moods.sql — moods初期データ
supabase/migrations/20260515000002_functions.sql  — RPC関数
```

または Supabase CLI を使う場合:

```bash
npx supabase link --project-ref <PROJECT_REF>
npx supabase db push
```

## 3. 環境変数設定

```bash
cp .env.example .env
# .env を編集して実際の値を設定
```

```env
PUBLIC_SUPABASE_URL=https://xxxx.supabase.co
PUBLIC_SUPABASE_ANON_KEY=eyJxxxxx
```

## 4. GitHub Secrets 設定

GitHub リポジトリの Settings → Secrets and variables → Actions に登録:

| Secret名 | 値 |
|---|---|
| `DMM_API_ID` | DMM Web API の API ID |
| `DMM_AFFILIATE_ID` | DMM アフィリエイト ID |
| `SUPABASE_URL` | Supabase Project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | service_role key |

## 5. moods の genre_ids 調整

`20260515000001_seed_moods.sql` の genre_ids は仮の値です。
実際の DMM Web API レスポンスから `iteminfo.genre[].id` を確認して更新してください。
