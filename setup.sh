#!/usr/bin/env bash
# =============================================================================
# DMM SEO Kit — 初期セットアップスクリプト (Mac / Linux)
# =============================================================================
set -euo pipefail

# --- カラー定義 ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

ok()   { echo -e "${GREEN}✅ $*${RESET}"; }
warn() { echo -e "${YELLOW}⚠️  $*${RESET}"; }
err()  { echo -e "${RED}❌ $*${RESET}"; exit 1; }
info() { echo -e "${CYAN}ℹ️  $*${RESET}"; }
step() { echo -e "\n${BOLD}═══ $* ═══${RESET}"; }
ask()  { echo -en "${BOLD}$* ${RESET}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- モード判定 ---
# --local フラグまたは引数なしで対話選択
LOCAL_MODE=false
for arg in "$@"; do
  [[ "$arg" == "--local" ]] && LOCAL_MODE=true
done

# =============================================================================
# 0. ようこそ
# =============================================================================
clear
echo -e "${BOLD}"
echo "  ██████╗ ███╗   ███╗███╗   ███╗    ███████╗███████╗ ██████╗"
echo "  ██╔══██╗████╗ ████║████╗ ████║    ██╔════╝██╔════╝██╔═══██╗"
echo "  ██║  ██║██╔████╔██║██╔████╔██║    ███████╗█████╗  ██║   ██║"
echo "  ██║  ██║██║╚██╔╝██║██║╚██╔╝██║    ╚════██║██╔══╝  ██║   ██║"
echo "  ██████╔╝██║ ╚═╝ ██║██║ ╚═╝ ██║    ███████║███████╗╚██████╔╝"
echo "  ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚═╝    ╚══════╝╚══════╝ ╚═════╝"
echo -e "${RESET}"
echo -e "${CYAN}  DB型アフィリエイトサイト構築キット — 初期セットアップ${RESET}"
echo ""
echo "  このスクリプトは以下を自動でセットアップします:"
echo "    1. 必要CLIのインストール確認"
echo "    2. .env ファイルの生成"
echo "    3. Supabase プロジェクト作成 + マイグレーション実行"
echo "    4. GitHub リポジトリ作成 + Secrets 登録"
echo "    5. Cloudflare Pages プロジェクト作成 + 初回デプロイ"
echo ""
ask "準備ができたら Enter を押してください..."; read -r

# モード未指定なら対話選択
if [[ "$LOCAL_MODE" == false ]]; then
  echo ""
  echo -e "${BOLD}  実行モードを選択してください:${RESET}"
  echo "    1) クラウドモード  — Supabase + GitHub + Cloudflare Pages に本番デプロイ"
  echo "    2) ローカルモード  — ローカルの Supabase + Astro dev server で動作確認 [テスト用]"
  echo ""
  ask "番号を入力 [1/2]:"; read -r _MODE_SEL
  [[ "$_MODE_SEL" == "2" ]] && LOCAL_MODE=true
fi

if [[ "$LOCAL_MODE" == true ]]; then
  echo ""
  info "ローカルモードで実行します（クラウドへの接続・デプロイはスキップ）"
fi

# =============================================================================
# 1. 必要CLIのインストール確認
# =============================================================================
step "STEP 1: 必要ツールの確認"

check_cmd() {
  local cmd=$1 install_hint=$2
  if command -v "$cmd" &>/dev/null; then
    ok "$cmd が見つかりました ($(command -v "$cmd"))"
  else
    warn "$cmd が見つかりません"
    echo "     インストール方法: $install_hint"
    err "$cmd をインストールしてから再実行してください"
  fi
}

check_cmd "node"     "https://nodejs.org/ からインストール (v18以上推奨)"
check_cmd "npm"      "Node.js に同梱されています"
check_cmd "git"      "https://git-scm.com/ または: brew install git"
check_cmd "supabase" "brew install supabase/tap/supabase  または  https://supabase.com/docs/guides/cli"

if [[ "$LOCAL_MODE" == false ]]; then
  check_cmd "gh"       "brew install gh  または  https://cli.github.com/"
  check_cmd "wrangler" "npm install -g wrangler"
fi

echo ""
ok "すべての必要ツールが揃っています"

# =============================================================================
# 2. サイト基本情報の入力
# =============================================================================
step "STEP 2: サイト基本情報の入力"

echo ""
info "サイト名・説明文・キャッチコピーは site.config.js から自動読み込みします"
echo ""
ask "プロジェクト名 (例: my-affiliate-site) ※CF/GitHub/Supabase 共通:"; read -r CF_PROJECT_NAME
GH_REPO_NAME="$CF_PROJECT_NAME"

# GitHub ユーザー名を自動取得
GH_OWNER=$(gh api user --jq .login 2>/dev/null || true)
if [[ -z "$GH_OWNER" ]]; then
  ask "GitHub ユーザー名またはOrg名:"; read -r GH_OWNER
else
  ok "GitHub ユーザー名: $GH_OWNER (自動検出)"
fi

# site.config.js からサイト情報を自動読み込み
SITE_NAME=$(node --input-type=module <<< "import {siteConfig} from 'file://$SCRIPT_DIR/site.config.js'; process.stdout.write(siteConfig.siteName)" 2>/dev/null || echo "My DMM Site")
SITE_DESCRIPTION=$(node --input-type=module <<< "import {siteConfig} from 'file://$SCRIPT_DIR/site.config.js'; process.stdout.write(siteConfig.siteDescription)" 2>/dev/null || echo "")
SITE_TAGLINE=$(node --input-type=module <<< "import {siteConfig} from 'file://$SCRIPT_DIR/site.config.js'; process.stdout.write(siteConfig.tagline)" 2>/dev/null || echo "")
info "サイト名: $SITE_NAME"

# =============================================================================
# 3. 認証ログイン確認
# =============================================================================
step "STEP 3: 各サービスへのログイン"

if [[ "$LOCAL_MODE" == true ]]; then
  info "ローカルモード: クラウドログインをスキップします"

  # Docker 確認
  echo -e "${BOLD}▶ Docker${RESET}"
  if docker info &>/dev/null 2>&1; then
    ok "Docker: 起動中"
  else
    err "Docker が起動していません。Docker Desktop を起動してから再実行してください。"
  fi

  # supabase CLI 確認
  echo -e "${BOLD}▶ Supabase CLI${RESET}"
  ok "supabase CLI: $(supabase --version)"
else
  info "未ログインの場合はブラウザが開きます"
  echo ""

  # GitHub
  echo -e "${BOLD}▶ GitHub${RESET}"
  if gh auth status &>/dev/null; then
    ok "GitHub: ログイン済み"
  else
    info "GitHub にログインします..."
    gh auth login
  fi

  # Supabase
  echo -e "${BOLD}▶ Supabase${RESET}"
  if supabase projects list &>/dev/null; then
    ok "Supabase: ログイン済み"
  else
    info "Supabase にログインします..."
    supabase login
  fi

  # Cloudflare
  echo -e "${BOLD}▶ Cloudflare${RESET}"
  if wrangler whoami &>/dev/null 2>&1; then
    ok "Cloudflare: ログイン済み"
  else
    info "Cloudflare にログインします..."
    wrangler login
  fi
fi

# =============================================================================
# 4. Supabase セットアップ
# =============================================================================
step "STEP 4: Supabase プロジェクトのセットアップ"

if [[ "$LOCAL_MODE" == true ]]; then
  # ---- ローカル Supabase ----
  info "ローカル Supabase を起動中..."

  # supabase init（config.toml がない場合のみ）
  if [[ ! -f "$SCRIPT_DIR/supabase/config.toml" ]]; then
    supabase --workdir "$SCRIPT_DIR" init
  fi

  # supabase start（既に起動中ならスキップ）
  if ! supabase --workdir "$SCRIPT_DIR" status &>/dev/null 2>&1; then
    supabase --workdir "$SCRIPT_DIR" start
  else
    ok "Supabase ローカル: すでに起動中"
  fi

  # マイグレーションファイル名に "init" が含まれると CLI がスキップするため rename
  for f in "$SCRIPT_DIR"/supabase/migrations/*_init.sql; do
    [[ -f "$f" ]] && mv "$f" "${f/_init.sql/_schema.sql}" && info "マイグレーションファイルを rename しました: $(basename "$f") → $(basename "${f/_init.sql/_schema.sql}")"
  done

  info "マイグレーションを適用中..."
  supabase --workdir "$SCRIPT_DIR" db reset --local

  # ローカルの接続情報を取得
  _SB_STATUS=$(supabase --workdir "$SCRIPT_DIR" status -o json 2>/dev/null)
  SB_URL=$(echo "$_SB_STATUS" | node -e "process.stdout.write(JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')).API_URL)")
  SB_ANON_KEY=$(echo "$_SB_STATUS" | node -e "process.stdout.write(JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')).ANON_KEY)")
  SB_SERVICE_KEY=$(echo "$_SB_STATUS" | node -e "process.stdout.write(JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')).SERVICE_ROLE_KEY)")
  SB_STUDIO_URL=$(echo "$_SB_STATUS" | node -e "process.stdout.write(JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')).STUDIO_URL)")

  ok "Supabase ローカル URL: $SB_URL"
  ok "Supabase Studio:      $SB_STUDIO_URL"
  ok "anon key:             ${SB_ANON_KEY:0:30}..."
  ok "マイグレーション完了"

else
  # ---- クラウド Supabase ----
  SB_PROJECT_NAME="$CF_PROJECT_NAME"
  SB_REGION="ap-northeast-1"
  info "Supabase プロジェクト名: $SB_PROJECT_NAME / リージョン: $SB_REGION (東京)"
  SB_DB_PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom 2>/dev/null | head -c 28 || \
    node -e "const c='ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';let p='';for(let i=0;i<28;i++)p+=c[Math.floor(Math.random()*c.length)];process.stdout.write(p)")
  info "DBパスワードを自動生成しました（.env に保存されます）"

  SB_ORG_ID=$(supabase orgs list --output json 2>/dev/null | node -e "const d=require('fs').readFileSync('/dev/stdin','utf8');const a=JSON.parse(d);console.log(a[0]?.id??'')" 2>/dev/null || true)
  if [[ -z "$SB_ORG_ID" ]]; then
    ask "Supabase 組織ID (supabase orgs list で確認):"; read -r SB_ORG_ID
  fi
  info "Supabase 組織ID: $SB_ORG_ID"

  info "Supabase プロジェクトを作成中..."
  SB_CREATE_OUTPUT=$(supabase projects create "$SB_PROJECT_NAME" \
    --org-id "$SB_ORG_ID" \
    --region "$SB_REGION" \
    --db-password "$SB_DB_PASSWORD" \
    --output json 2>&1 || true)

  SB_PROJECT_ID=$(echo "$SB_CREATE_OUTPUT" | node -e "const d=require('fs').readFileSync('/dev/stdin','utf8');try{const m=d.match(/\{[\s\S]*\}/);const o=JSON.parse(m?.[0]??'{}');process.stdout.write(o.id??o.ref??'')}catch{}" 2>/dev/null || true)

  if [[ -n "$SB_PROJECT_ID" ]]; then
    ok "Supabase プロジェクト作成完了: $SB_PROJECT_ID"
    info "プロジェクトの起動を待機中... (30秒)"
    sleep 30
  else
    warn "プロジェクトの自動作成に失敗しました"
    info "エラー内容: $SB_CREATE_OUTPUT"
    warn "既存のプロジェクトを検索中..."
    SB_PROJECT_ID=$(supabase projects list --output json 2>/dev/null | \
      node -e "const d=require('fs').readFileSync('/dev/stdin','utf8');try{const a=JSON.parse(d);const p=a.find(p=>p.name==='$SB_PROJECT_NAME');process.stdout.write(p?.id??'')}catch{}" 2>/dev/null || true)
    if [[ -n "$SB_PROJECT_ID" ]]; then
      ok "既存プロジェクトを使用します: $SB_PROJECT_ID"
    else
      warn "プロジェクトが見つかりません。エラー内容:"
      echo "$SB_CREATE_OUTPUT"
      echo ""
      if echo "$SB_CREATE_OUTPUT" | grep -q "maximum limits\|2 project limit\|free projects"; then
        err "【無料プランの上限に達しています】
  Supabase の無料プランはアクティブプロジェクトが2件までです。
  以下のいずれかを行ってから再実行してください:
    1. https://supabase.com/dashboard で不要なプロジェクトを一時停止（Pause）または削除
    2. Supabase の有料プランにアップグレード"
      fi
      ask "Supabase Project ID を手動で入力してください (dashboard.supabase.com で確認):"; read -r SB_PROJECT_ID
    fi
  fi

  info "Supabase のキーを取得中... (初回は1〜2分かかる場合があります)"
  SB_ANON_KEY=""
  SB_SERVICE_KEY=""
  for i in $(seq 1 12); do
    sleep 10
    SB_KEYS=$(supabase projects api-keys --project-ref "$SB_PROJECT_ID" --output json 2>/dev/null || echo "[]")
    SB_ANON_KEY=$(echo "$SB_KEYS" | node -e "const d=require('fs').readFileSync('/dev/stdin','utf8');try{const a=JSON.parse(d);console.log(a.find(k=>k.name==='anon')?.api_key??'')}catch{}" 2>/dev/null || true)
    SB_SERVICE_KEY=$(echo "$SB_KEYS" | node -e "const d=require('fs').readFileSync('/dev/stdin','utf8');try{const a=JSON.parse(d);console.log(a.find(k=>k.name==='service_role')?.api_key??'')}catch{}" 2>/dev/null || true)
    if [[ -n "$SB_ANON_KEY" && -n "$SB_SERVICE_KEY" ]]; then break; fi
    info "待機中... ($((i*10))秒経過)"
  done
  SB_URL="https://${SB_PROJECT_ID}.supabase.co"

  if [[ -z "$SB_ANON_KEY" || -z "$SB_SERVICE_KEY" ]]; then
    warn "APIキーの自動取得に失敗しました。手動で入力してください"
    info "取得場所: Supabase ダッシュボード → $SB_PROJECT_NAME → Settings → API"
    ask "anon public キー:"; read -rs SB_ANON_KEY; echo ""
    ask "service_role キー:"; read -rs SB_SERVICE_KEY; echo ""
  fi

  ok "Supabase URL: $SB_URL"
  ok "anon key: ${SB_ANON_KEY:0:20}..."
  ok "service_role key: ${SB_SERVICE_KEY:0:20}..."

  info "データベースマイグレーションを実行中..."
  supabase link --project-ref "$SB_PROJECT_ID" --password "$SB_DB_PASSWORD"
  supabase db push --yes

  ok "マイグレーション完了"
fi

# =============================================================================
# 5. 追加キーの入力
# =============================================================================
step "STEP 5: DMM API キーの入力"

if [[ "$LOCAL_MODE" == true ]]; then
  info "ローカルモード: DMM API キーはデータ同期スクリプト実行時に必要です"
  info "今すぐ入力しなくてもローカル動作確認は可能です（.env に空値で保存します）"
  ask "DMM API ID (スキップは Enter):"; read -r DMM_API_ID
  ask "DMM アフィリエイト ID (スキップは Enter):"; read -r DMM_AFFILIATE_ID
  DMM_API_ID="${DMM_API_ID:-your_api_id_here}"
  DMM_AFFILIATE_ID="${DMM_AFFILIATE_ID:-your_affiliate_id-990}"
  PUBLIC_GA4_ID=""
  ask "管理画面ログイン用メールアドレス (ローカル Supabase Auth に登録):"; read -r ADMIN_EMAIL
else
  info "取得場所: https://affiliate.dmm.com/api/"
  ask "DMM API ID:"; read -r DMM_API_ID
  ask "DMM アフィリエイト ID (例: xxxxx-999):"; read -r DMM_AFFILIATE_ID

  ask "Google Analytics 4 測定ID (任意 / スキップは Enter):"; read -r PUBLIC_GA4_ID
  PUBLIC_GA4_ID="${PUBLIC_GA4_ID:-}"

  ask "管理画面ログイン用メールアドレス (Supabase Auth に登録されるアドレス):"; read -r ADMIN_EMAIL
fi

# =============================================================================
# 6. .env ファイルの生成
# =============================================================================
step "STEP 6: .env ファイルの生成"

# ルート .env
cat > "$SCRIPT_DIR/.env" <<EOF
# 自動生成 — $(date '+%Y-%m-%d %H:%M:%S')
# このファイルは絶対に Git にコミットしないでください

# Supabase
SUPABASE_URL=${SB_URL}
SUPABASE_SERVICE_ROLE_KEY=${SB_SERVICE_KEY}

# DMM API
DMM_API_ID=${DMM_API_ID}
DMM_AFFILIATE_ID=${DMM_AFFILIATE_ID}
EOF
ok "ルート .env を生成しました"

# astro/.env
cat > "$SCRIPT_DIR/astro/.env" <<EOF
# 自動生成 — $(date '+%Y-%m-%d %H:%M:%S')
# このファイルは絶対に Git にコミットしないでください

PUBLIC_SUPABASE_URL=${SB_URL}
PUBLIC_SUPABASE_ANON_KEY=${SB_ANON_KEY}
PUBLIC_GA4_ID=${PUBLIC_GA4_ID}

# Admin
SUPABASE_URL=${SB_URL}
SUPABASE_SERVICE_ROLE_KEY=${SB_SERVICE_KEY}
ADMIN_EMAIL=${ADMIN_EMAIL}
EOF
ok "astro/.env を生成しました"

# 管理者ユーザーを Supabase Auth に登録（マジックリンクログイン用）
if [ -n "$ADMIN_EMAIL" ] && [ -n "$SB_SERVICE_KEY" ]; then
  echo "  管理者ユーザーを Supabase に登録中..."
  ADMIN_CREATE_RESP=$(curl -s -o /tmp/sb_admin_user.json -w "%{http_code}" \
    -X POST "${SB_URL}/auth/v1/admin/users" \
    -H "apikey: ${SB_SERVICE_KEY}" \
    -H "Authorization: Bearer ${SB_SERVICE_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${ADMIN_EMAIL}\",\"email_confirm\":true}")
  if [ "$ADMIN_CREATE_RESP" = "200" ] || [ "$ADMIN_CREATE_RESP" = "201" ]; then
    ok "管理者ユーザーを登録しました: ${ADMIN_EMAIL}"
  elif [ "$ADMIN_CREATE_RESP" = "422" ] || grep -q "already" /tmp/sb_admin_user.json 2>/dev/null; then
    ok "管理者ユーザーは既に登録済みです: ${ADMIN_EMAIL}"
  else
    warn "管理者ユーザーの登録に失敗 (HTTP ${ADMIN_CREATE_RESP})"
    warn "Supabase Dashboard → Authentication → Users から手動で追加してください: ${ADMIN_EMAIL}"
  fi
fi

# =============================================================================
# 7. wrangler の name を更新
# =============================================================================
step "STEP 7: Cloudflare プロジェクト名の更新"

sed -i.bak "s/\"name\": \"[^\"]*\"/\"name\": \"${CF_PROJECT_NAME}\"/" "$SCRIPT_DIR/wrangler.jsonc"
sed -i.bak "s/^name = \".*\"/name = \"${CF_PROJECT_NAME}\"/" "$SCRIPT_DIR/astro/wrangler.toml"
rm -f "$SCRIPT_DIR/wrangler.jsonc.bak" "$SCRIPT_DIR/astro/wrangler.toml.bak"
ok "wrangler.jsonc と astro/wrangler.toml を更新しました → name = \"${CF_PROJECT_NAME}\""

# Cloudflare workers.dev サブドメインを取得（wrangler の OAuth トークン経由で CF API を叩く）
CF_SUBDOMAIN=""
_CF_ACCOUNT_ID=$(wrangler whoami 2>&1 | grep -oE '[0-9a-f]{32}' | head -1 || true)
_WRANGLER_TOKEN=""
for _wpath in \
    "$HOME/Library/Preferences/.wrangler/config/default.toml" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/.wrangler/config/default.toml" \
    "$HOME/.wrangler/config/default.toml"; do
  if [[ -f "$_wpath" ]]; then
    _WRANGLER_TOKEN=$(grep -E '^oauth_token' "$_wpath" 2>/dev/null | sed -E 's/oauth_token[[:space:]]*=[[:space:]]*"([^"]+)"/\1/' || true)
    [[ -n "$_WRANGLER_TOKEN" ]] && break
  fi
done
if [[ -n "$_CF_ACCOUNT_ID" && -n "$_WRANGLER_TOKEN" ]]; then
  CF_SUBDOMAIN=$(curl -s -H "Authorization: Bearer $_WRANGLER_TOKEN" \
    "https://api.cloudflare.com/client/v4/accounts/${_CF_ACCOUNT_ID}/workers/subdomain" 2>/dev/null \
    | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{const j=JSON.parse(d);if(j.success)process.stdout.write(j.result?.subdomain??'')}catch{}})" 2>/dev/null || true)
fi
if [[ -z "$CF_SUBDOMAIN" ]]; then
  warn "Cloudflare サブドメインを自動取得できませんでした。GitHub ユーザー名を代替使用します。"
  CF_SUBDOMAIN="$GH_OWNER"
else
  ok "Cloudflare workers.dev サブドメイン: ${CF_SUBDOMAIN}"
fi

# site.config.js の更新
SITE_URL="https://${CF_PROJECT_NAME}.${CF_SUBDOMAIN}.workers.dev"
sed -i.bak "s|siteName:.*|siteName: '${SITE_NAME}',|" "$SCRIPT_DIR/site.config.js"
sed -i.bak "s|siteUrl:.*|siteUrl: '${SITE_URL}',|" "$SCRIPT_DIR/site.config.js"
sed -i.bak "s|siteDescription:.*|siteDescription: '${SITE_DESCRIPTION}',|" "$SCRIPT_DIR/site.config.js"
sed -i.bak "s|tagline:.*|tagline: '${SITE_TAGLINE}',|" "$SCRIPT_DIR/site.config.js"
rm -f "$SCRIPT_DIR/site.config.js.bak"
ok "site.config.js を更新しました → siteUrl = \"${SITE_URL}\""

# Supabase Auth の Site URL を本番 URL に更新（マジックリンクのリダイレクト先修正）
if [[ "$LOCAL_MODE" != true && -n "${SB_PROJECT_ID:-}" ]]; then
  # supabase login で保存されるトークンを探す（環境変数 → Keychain → ファイル → 手動入力 の順）
  SUPABASE_ACCESS_TOKEN="${SUPABASE_ACCESS_TOKEN:-}"

  # 1. macOS Keychain（supabase CLI が go-keyring で保存。account="supabase"、base64エンコード）
  if [[ -z "$SUPABASE_ACCESS_TOKEN" && "$(uname)" == "Darwin" ]]; then
    _RAW=$(security find-generic-password -s "Supabase CLI" -a "supabase" -w 2>/dev/null || true)
    if [[ -n "$_RAW" ]]; then
      if [[ "$_RAW" == go-keyring-base64:* ]]; then
        SUPABASE_ACCESS_TOKEN=$(echo "${_RAW#go-keyring-base64:}" | base64 -d 2>/dev/null || true)
      else
        SUPABASE_ACCESS_TOKEN="$_RAW"
      fi
    fi
  fi

  # 2. Linux Secret Service (libsecret)
  if [[ -z "$SUPABASE_ACCESS_TOKEN" ]] && command -v secret-tool &>/dev/null; then
    _RAW=$(secret-tool lookup service "Supabase CLI" username "supabase" 2>/dev/null || true)
    if [[ -n "$_RAW" ]]; then
      if [[ "$_RAW" == go-keyring-base64:* ]]; then
        SUPABASE_ACCESS_TOKEN=$(echo "${_RAW#go-keyring-base64:}" | base64 -d 2>/dev/null || true)
      else
        SUPABASE_ACCESS_TOKEN="$_RAW"
      fi
    fi
  fi

  # 3. ファイル保存（古いバージョン or fallback）
  if [[ -z "$SUPABASE_ACCESS_TOKEN" ]]; then
    SUPABASE_ACCESS_TOKEN=$(
      cat "${XDG_CONFIG_HOME:-$HOME/.config}/supabase/access-token" 2>/dev/null ||
      cat "$HOME/.supabase/access-token" 2>/dev/null ||
      node -e "try{const f=require('fs');const p=require('os').homedir()+'/.config/supabase/credentials.json';const d=JSON.parse(f.readFileSync(p,'utf8'));console.log(d.access_token??d.token??'')}catch{}" 2>/dev/null ||
      true
    )
  fi

  # 4. 手動入力（最終手段）
  if [[ -z "$SUPABASE_ACCESS_TOKEN" ]]; then
    echo ""
    warn "supabase login のアクセストークンを自動取得できませんでした"
    info "Personal Access Token を以下から発行して貼り付けてください:"
    info "  https://supabase.com/dashboard/account/tokens"
    ask "Supabase Personal Access Token (空Enterでスキップ):"; read -rs SUPABASE_ACCESS_TOKEN; echo ""
  fi
  if [[ -n "$SUPABASE_ACCESS_TOKEN" ]]; then
    info "Supabase Auth の Site URL を設定中..."
    _AUTH_PATCH=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH \
      "https://api.supabase.com/v1/projects/${SB_PROJECT_ID}/config/auth" \
      -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"site_url\": \"${SITE_URL}\", \"additional_redirect_urls\": \"${SITE_URL}/admin/auth/callback\"}" 2>/dev/null || true)
    if [[ "$_AUTH_PATCH" == "200" ]]; then
      ok "Supabase Auth Site URL を設定しました → ${SITE_URL}"
      ok "Redirect URLs に追加しました → ${SITE_URL}/admin/auth/callback"
    else
      warn "Supabase Auth Site URL の自動設定に失敗しました (HTTP $_AUTH_PATCH)"
      warn "手動で設定してください:"
      warn "  Supabase Dashboard → Authentication → URL Configuration"
      warn "  Site URL: ${SITE_URL}"
      warn "  Redirect URLs: ${SITE_URL}/admin/auth/callback"
    fi
  else
    warn "Supabase アクセストークンが見つかりません。手動で設定してください:"
    warn "  Supabase Dashboard → Authentication → URL Configuration"
    warn "  Site URL: ${SITE_URL}"
    warn "  Redirect URLs: ${SITE_URL}/admin/auth/callback"
  fi
fi

# =============================================================================
# 8. GitHub リポジトリ作成 + Secrets 登録
# =============================================================================
if [[ "$LOCAL_MODE" == true ]]; then
  step "STEP 8-9: スキップ（ローカルモード）"
  info "GitHub リポジトリ作成・Cloudflare デプロイはスキップします"

  info "依存パッケージをインストール中（ルート）..."
  cd "$SCRIPT_DIR" && npm install
  ok "ルート npm install 完了"

  info "依存パッケージをインストール中（Astro）..."
  cd "$SCRIPT_DIR/astro" && npm install && cd "$SCRIPT_DIR"
  ok "Astro npm install 完了"

  echo ""
  echo -e "${GREEN}${BOLD}"
  echo "  ╔══════════════════════════════════════════════════╗"
  echo "  ║    ローカルセットアップ完了！ 🎉               ║"
  echo "  ╚══════════════════════════════════════════════════╝"
  echo -e "${RESET}"
  echo ""
  echo -e "  ${BOLD}Supabase Studio:${RESET}  ${SB_STUDIO_URL}"
  echo -e "  ${BOLD}DB URL:${RESET}           postgresql://postgres:postgres@127.0.0.1:54322/postgres"
  echo ""
  echo -e "  ${BOLD}次のステップ:${RESET}"
  echo "    1. 開発サーバー起動:"
  echo "       cd astro && npm run dev"
  echo ""
  echo "    2. DMM API キーを .env に設定後、データ同期:"
  echo "       npm run sync:products"
  echo ""
  echo "    3. Docker 再起動後は以下で Supabase を再起動:"
  echo "       supabase start"
  echo ""
  exit 0
fi

step "STEP 8: GitHub リポジトリのセットアップ"

# git 初期化（未初期化の場合のみ）
if [[ ! -d "$SCRIPT_DIR/.git" ]]; then
  # .gitignore がなければキットのデフォルトを生成
  if [[ ! -f "$SCRIPT_DIR/.gitignore" ]]; then
    cat > "$SCRIPT_DIR/.gitignore" <<'GITIGNORE'
node_modules/
dist/
.env
.astro/
.DS_Store
*.log
.claude/
CLAUDE.md
GITIGNORE
  fi
  git -C "$SCRIPT_DIR" init
  git -C "$SCRIPT_DIR" add .
  git -C "$SCRIPT_DIR" commit -m "Initial commit"
  ok "git リポジトリを初期化しました"
fi

# リポジトリ作成
if gh repo view "${GH_OWNER}/${GH_REPO_NAME}" &>/dev/null; then
  warn "リポジトリ ${GH_OWNER}/${GH_REPO_NAME} はすでに存在します。スキップします"
  # 既存リポジトリの場合、リモート URL を正しいリポジトリに合わせてからプッシュ
  _REPO_URL="https://github.com/${GH_OWNER}/${GH_REPO_NAME}.git"
  if git -C "$SCRIPT_DIR" remote get-url origin &>/dev/null; then
    git -C "$SCRIPT_DIR" remote set-url origin "$_REPO_URL"
  else
    git -C "$SCRIPT_DIR" remote add origin "$_REPO_URL"
  fi
  git -C "$SCRIPT_DIR" push origin main --force-with-lease 2>/dev/null || true
else
  # 前回失敗の残骸として origin が残っている場合は削除（gh repo create が失敗するため）
  git -C "$SCRIPT_DIR" remote remove origin 2>/dev/null || true
  gh repo create "${GH_OWNER}/${GH_REPO_NAME}" --private --source="$SCRIPT_DIR" --remote=origin --push
  ok "GitHubリポジトリ作成完了: https://github.com/${GH_OWNER}/${GH_REPO_NAME}"
fi

# GitHub Actions を有効化（プライベートリポジトリでは無効になっている場合がある）
info "GitHub Actions を有効化中..."
_GH_ACTIONS_OK=false
for _i in 1 2 3; do
  if gh api "repos/${GH_OWNER}/${GH_REPO_NAME}/actions/permissions" \
      --method PUT \
      -F enabled=true \
      -f allowed_actions=all \
      --silent 2>/tmp/gh_actions_err.log; then
    _GH_ACTIONS_OK=true
    break
  fi
  sleep 2
done
if [[ "$_GH_ACTIONS_OK" == true ]]; then
  ok "GitHub Actions を有効化しました"
else
  warn "GitHub Actions の有効化をスキップ（手動で Settings > Actions から有効化してください）"
  [[ -s /tmp/gh_actions_err.log ]] && warn "エラー詳細: $(cat /tmp/gh_actions_err.log)"
fi

# Cloudflare API Token の取得
echo ""
echo -e "${BOLD}  Cloudflare API Token の作成手順${RESET}"
echo "  ─────────────────────────────────────────────"
echo "  1. ブラウザで以下のURLを開く"
echo "     https://dash.cloudflare.com/profile/api-tokens"
echo ""
echo "  2. [Create Token] ボタンをクリック"
echo ""
echo "  3. テンプレート一覧から"
echo "     [Edit Cloudflare Workers] の [Use template] をクリック"
echo ""
echo "  4. [Account Resources] を確認"
echo "     → Include / All accounts になっていることを確認"
echo ""
echo "  5. [Zone Resources] を確認"
echo "     → Include / All zones になっていることを確認"
echo ""
echo "  6. [Continue to summary] → [Create Token] をクリック"
echo ""
echo "  7. 表示されたトークンをコピー"
echo "     ※ この画面を閉じると二度と表示されません"
echo "  ─────────────────────────────────────────────"
echo ""
ask "Cloudflare API Token を貼り付けてください:"; read -rs CF_API_TOKEN; echo ""

# Secrets 登録
info "GitHub Secrets を登録中..."
gh secret set SUPABASE_URL          --repo "${GH_OWNER}/${GH_REPO_NAME}" --body "$SB_URL"
gh secret set SUPABASE_SERVICE_ROLE_KEY --repo "${GH_OWNER}/${GH_REPO_NAME}" --body "$SB_SERVICE_KEY"
gh secret set PUBLIC_SUPABASE_URL   --repo "${GH_OWNER}/${GH_REPO_NAME}" --body "$SB_URL"
gh secret set PUBLIC_SUPABASE_ANON_KEY  --repo "${GH_OWNER}/${GH_REPO_NAME}" --body "$SB_ANON_KEY"
gh secret set DMM_API_ID            --repo "${GH_OWNER}/${GH_REPO_NAME}" --body "$DMM_API_ID"
gh secret set DMM_AFFILIATE_ID      --repo "${GH_OWNER}/${GH_REPO_NAME}" --body "$DMM_AFFILIATE_ID"
DMM_SITE_VAL=$(node -e "import('file://$SCRIPT_DIR/site.config.js').then(m=>process.stdout.write(m.siteConfig.dmm.site))" 2>/dev/null || echo "FANZA")
DMM_SERVICE_VAL=$(node -e "import('file://$SCRIPT_DIR/site.config.js').then(m=>process.stdout.write(m.siteConfig.dmm.service))" 2>/dev/null || echo "digital")
DMM_FLOOR_VAL=$(node -e "import('file://$SCRIPT_DIR/site.config.js').then(m=>process.stdout.write(m.siteConfig.dmm.floor))" 2>/dev/null || echo "videoa")
gh secret set DMM_SITE              --repo "${GH_OWNER}/${GH_REPO_NAME}" --body "$DMM_SITE_VAL"
gh secret set DMM_SERVICE           --repo "${GH_OWNER}/${GH_REPO_NAME}" --body "$DMM_SERVICE_VAL"
gh secret set DMM_FLOOR             --repo "${GH_OWNER}/${GH_REPO_NAME}" --body "$DMM_FLOOR_VAL"
gh secret set CLOUDFLARE_API_TOKEN  --repo "${GH_OWNER}/${GH_REPO_NAME}" --body "$CF_API_TOKEN"
[[ -n "$PUBLIC_GA4_ID" ]] && gh secret set PUBLIC_GA --repo "${GH_OWNER}/${GH_REPO_NAME}" --body "$PUBLIC_GA4_ID"

ok "GitHub Secrets の登録完了 (${GH_OWNER}/${GH_REPO_NAME})"

# =============================================================================
# 9. Cloudflare Pages デプロイ
# =============================================================================
step "STEP 9: Cloudflare Pages への初回デプロイ"

info "Astro をビルド中..."
cd "$SCRIPT_DIR/astro"
npm install
npm run build
cd "$SCRIPT_DIR"

info "Cloudflare Workers にデプロイ中..."
cd "$SCRIPT_DIR/astro"
CLOUDFLARE_API_TOKEN="$CF_API_TOKEN" npx wrangler deploy --config dist/server/wrangler.json
cd "$SCRIPT_DIR"

ok "Cloudflare Pages デプロイ完了"

# =============================================================================
# 完了
# =============================================================================
echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║         セットアップ完了！ 🎉            ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${RESET}"
echo ""
echo -e "  ${BOLD}Supabase ダッシュボード:${RESET} https://supabase.com/dashboard/project/${SB_PROJECT_ID}"
echo -e "  ${BOLD}GitHub リポジトリ:${RESET}       https://github.com/${GH_OWNER}/${GH_REPO_NAME}"
echo -e "  ${BOLD}Cloudflare Pages:${RESET}        ${SITE_URL}"
echo ""
echo -e "  ${BOLD}次のステップ:${RESET}"
echo "    1. GitHub Actions → backfill を手動実行してデータを初期投入"
echo "    2. 独自ドメインは Cloudflare Pages の設定から追加"
echo ""
