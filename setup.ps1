# =============================================================================
# DMM SEO Kit - 初期セットアップスクリプト (Windows / PowerShell)
# =============================================================================
[CmdletBinding()]
param(
    [switch]$Local
)

$ErrorActionPreference = 'Continue'
# PowerShell 7+ で native コマンドの stderr を例外化させない
if ($PSVersionTable.PSVersion.Major -ge 7) { $PSNativeCommandUseErrorActionPreference = $false }
$OutputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::InputEncoding  = [System.Text.UTF8Encoding]::new()

function Ok   ($m) { Write-Host "[OK] $m"   -ForegroundColor Green }
function Warn ($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Info ($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Step ($m) { Write-Host ""; Write-Host "=== $m ===" -ForegroundColor White }
function Fail ($m) { Write-Host "[ERROR] $m" -ForegroundColor Red; Read-Host "Enter で終了"; exit 1 }
function Ask  ($m) { return (Read-Host -Prompt $m) }

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$LOCAL_MODE = [bool]$Local

# 文字化け対策: バッチから渡された ASCII 引数を解釈
foreach ($a in $args) { if ($a -eq '--local') { $LOCAL_MODE = $true } }

# =============================================================================
# 0. ようこそ
# =============================================================================
Clear-Host
Write-Host ""
Write-Host "  ================================================" -ForegroundColor Cyan
Write-Host "   DMM SEO Kit" -ForegroundColor Cyan
Write-Host "   DB型アフィリエイトサイト構築キット" -ForegroundColor Cyan
Write-Host "  ================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  このスクリプトは以下を自動でセットアップします:"
Write-Host "    1. 必要CLIのインストール確認"
Write-Host "    2. .env ファイルの生成"
Write-Host "    3. Supabase プロジェクト作成 + マイグレーション実行"
Write-Host "    4. GitHub リポジトリ作成 + Secrets 登録"
Write-Host "    5. Cloudflare Pages プロジェクト作成 + 初回デプロイ"
Write-Host ""
[void](Read-Host "準備ができたら Enter を押してください")

if (-not $LOCAL_MODE) {
    Write-Host ""
    Write-Host "  実行モードを選択してください:"
    Write-Host "    1) クラウドモード  - Supabase + GitHub + Cloudflare Pages に本番デプロイ"
    Write-Host "    2) ローカルモード  - ローカルの Supabase + Astro dev server で動作確認 [テスト用]"
    Write-Host ""
    $sel = Read-Host "番号を入力 [1/2]"
    if ($sel -eq '2') { $LOCAL_MODE = $true }
}

if ($LOCAL_MODE) {
    Write-Host ""
    Info "ローカルモードで実行します (クラウドへの接続・デプロイはスキップ)"
}

# =============================================================================
# 1. 必要CLIのインストール確認
# =============================================================================
Step "STEP 1: 必要ツールの確認"

function Check-Cmd($cmd, $hint) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
        Ok "$cmd が見つかりました"
    } else {
        Warn "$cmd が見つかりません"
        Write-Host "     インストール方法: $hint"
        Fail "$cmd をインストールしてから再実行してください"
    }
}

Check-Cmd "node"     "https://nodejs.org/ からインストール (v18以上推奨)"
Check-Cmd "npm"      "Node.js に同梱"
Check-Cmd "git"      "https://git-scm.com/"
Check-Cmd "supabase" "scoop install supabase または https://supabase.com/docs/guides/cli"

if (-not $LOCAL_MODE) {
    Check-Cmd "gh"       "winget install GitHub.cli または https://cli.github.com/"
    Check-Cmd "wrangler" "npm install -g wrangler"
}

Write-Host ""
Ok "すべての必要ツールが揃っています"

# =============================================================================
# 2. サイト基本情報の入力
# =============================================================================
Step "STEP 2: サイト基本情報の入力"
Write-Host ""
Info "サイト名・説明文・キャッチコピーは site.config.js から自動読み込みします"
Write-Host ""

$CF_PROJECT_NAME = Read-Host "プロジェクト名 (例: my-affiliate-site) ※CF/GitHub/Supabase 共通"
$GH_REPO_NAME = $CF_PROJECT_NAME

# GitHub ユーザー名を自動取得
$GH_OWNER = ""
try { $GH_OWNER = (& gh api user --jq .login 2>$null).Trim() } catch {}
if (-not $GH_OWNER) {
    $GH_OWNER = Read-Host "GitHub ユーザー名または Org 名"
} else {
    Ok "GitHub ユーザー名: $GH_OWNER (自動検出)"
}

# site.config.js から自動読み込み
function Read-SiteConfig($key) {
    $configPath = "file:///$($SCRIPT_DIR.Replace('\','/'))/site.config.js"
    $code = "import {siteConfig} from '$configPath'; process.stdout.write(String(siteConfig.$key ?? ''))"
    try { return (& node --input-type=module --eval $code 2>$null) } catch { return "" }
}

$SITE_NAME        = Read-SiteConfig 'siteName'
$SITE_DESCRIPTION = Read-SiteConfig 'siteDescription'
$SITE_TAGLINE     = Read-SiteConfig 'tagline'
if (-not $SITE_NAME) { $SITE_NAME = "My DMM Site" }
Info "サイト名: $SITE_NAME"

# =============================================================================
# 3. 認証ログイン確認
# =============================================================================
Step "STEP 3: 各サービスへのログイン"

if ($LOCAL_MODE) {
    Info "ローカルモード: クラウドログインをスキップします"
    Write-Host "▶ Docker"
    try { & docker info *>$null; if ($LASTEXITCODE -ne 0) { throw } ; Ok "Docker: 起動中" }
    catch { Fail "Docker が起動していません。Docker Desktop を起動してから再実行してください。" }
    Write-Host "▶ Supabase CLI"
    Ok "supabase CLI: $(& supabase --version)"
} else {
    Info "未ログインの場合はブラウザが開きます"
    Write-Host ""
    Write-Host "▶ GitHub"
    & gh auth status *>$null
    if ($LASTEXITCODE -ne 0) { Info "GitHub にログインします..."; & gh auth login } else { Ok "GitHub: ログイン済み" }

    Write-Host "▶ Supabase"
    & supabase projects list *>$null
    if ($LASTEXITCODE -ne 0) { Info "Supabase にログインします..."; & supabase login } else { Ok "Supabase: ログイン済み" }

    Write-Host "▶ Cloudflare"
    & wrangler whoami *>$null
    if ($LASTEXITCODE -ne 0) { Info "Cloudflare にログインします..."; & wrangler login } else { Ok "Cloudflare: ログイン済み" }
}

# =============================================================================
# 4. Supabase セットアップ
# =============================================================================
Step "STEP 4: Supabase プロジェクトのセットアップ"

$SB_URL = ""; $SB_ANON_KEY = ""; $SB_SERVICE_KEY = ""; $SB_PROJECT_ID = ""; $SB_STUDIO_URL = ""

if ($LOCAL_MODE) {
    Info "ローカル Supabase を起動中..."
    if (-not (Test-Path "$SCRIPT_DIR\supabase\config.toml")) {
        & supabase --workdir "$SCRIPT_DIR" init
    }
    & supabase --workdir "$SCRIPT_DIR" status *>$null
    if ($LASTEXITCODE -ne 0) {
        & supabase --workdir "$SCRIPT_DIR" start
    } else {
        Ok "Supabase ローカル: すでに起動中"
    }
    Get-ChildItem "$SCRIPT_DIR\supabase\migrations\*_init.sql" -ErrorAction SilentlyContinue | ForEach-Object {
        $new = $_.FullName -replace '_init\.sql$', '_schema.sql'
        Move-Item $_.FullName $new
        Info "rename: $($_.Name) -> $(Split-Path $new -Leaf)"
    }
    Info "マイグレーションを適用中..."
    & supabase --workdir "$SCRIPT_DIR" db reset --local

    $st = & supabase --workdir "$SCRIPT_DIR" status -o json 2>$null | ConvertFrom-Json
    $SB_URL = $st.API_URL
    $SB_ANON_KEY = $st.ANON_KEY
    $SB_SERVICE_KEY = $st.SERVICE_ROLE_KEY
    $SB_STUDIO_URL = $st.STUDIO_URL
    Ok "Supabase ローカル URL: $SB_URL"
    Ok "Supabase Studio:      $SB_STUDIO_URL"
    Ok "マイグレーション完了"

} else {
    $SB_PROJECT_NAME = $CF_PROJECT_NAME
    $SB_REGION = "ap-northeast-1"
    Info "Supabase プロジェクト名: $SB_PROJECT_NAME / リージョン: $SB_REGION (東京)"

    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789'.ToCharArray()
    $SB_DB_PASSWORD = -join (1..28 | ForEach-Object { $chars | Get-Random })
    Info "DBパスワードを自動生成しました (.env に保存されます)"

    $SB_ORG_ID = ""
    try {
        $orgsJson = & supabase orgs list --output json 2>$null
        $orgsArr = ($orgsJson -join "`n") | Select-String -Pattern '\[[\s\S]*\]' | ForEach-Object { $_.Matches[0].Value }
        if ($orgsArr) {
            $orgs = $orgsArr | ConvertFrom-Json
            if ($orgs.Count -gt 0) { $SB_ORG_ID = $orgs[0].id }
        }
    } catch {}
    if (-not $SB_ORG_ID) {
        $SB_ORG_ID = Read-Host "Supabase 組織ID (supabase orgs list で確認)"
    }
    Info "Supabase 組織ID: $SB_ORG_ID"

    Info "Supabase プロジェクトを作成中..."
    $createOutput = & supabase projects create $SB_PROJECT_NAME `
        --org-id $SB_ORG_ID `
        --region $SB_REGION `
        --db-password $SB_DB_PASSWORD `
        --output json 2>&1
    $createText = ($createOutput | Out-String)

    $m = [regex]::Match($createText, '"(?:id|ref)"\s*:\s*"([a-z0-9]{15,})"')
    if ($m.Success) { $SB_PROJECT_ID = $m.Groups[1].Value }

    $SB_PROJECT_ID_NEW = $false
    if ($SB_PROJECT_ID) {
        $SB_PROJECT_ID_NEW = $true
        Ok "Supabase プロジェクト作成完了: $SB_PROJECT_ID"
        Info "プロジェクトの起動を待機中... (30秒)"
        Start-Sleep -Seconds 30
    } else {
        Warn "プロジェクトの自動作成に失敗しました"
        Info "エラー内容: $createText"
        Warn "既存のプロジェクトを検索中..."
        try {
            $listJson = & supabase projects list --output json 2>$null
            $listArr = ($listJson -join "`n") | Select-String -Pattern '\[[\s\S]*\]' | ForEach-Object { $_.Matches[0].Value }
            if ($listArr) {
                $projects = $listArr | ConvertFrom-Json
                $hit = $projects | Where-Object { $_.name -eq $SB_PROJECT_NAME } | Select-Object -First 1
                if ($hit) { $SB_PROJECT_ID = if ($hit.id) { $hit.id } else { $hit.ref } }
            }
        } catch {}
        if ($SB_PROJECT_ID) {
            Ok "既存プロジェクトを使用します: $SB_PROJECT_ID"
        } else {
            if ($createText -match 'maximum limits|2 project limit|free projects|reached the maximum') {
                Fail "Supabase 無料プランの上限 (2件) に達しています。https://supabase.com/dashboard で不要なプロジェクトを Pause/削除してから再実行してください。"
            }
            $SB_PROJECT_ID = Read-Host "Supabase Project ID を手動で入力 (dashboard.supabase.com で確認)"
        }
    }

    Info "Supabase の API キーを取得中... (初回は1〜2分かかる場合があります)"
    for ($i = 1; $i -le 12; $i++) {
        Start-Sleep -Seconds 10
        try {
            $keysJson = & supabase projects api-keys --project-ref $SB_PROJECT_ID --output json 2>$null
            $keysArr = ($keysJson -join "`n") | Select-String -Pattern '\[[\s\S]*\]' | ForEach-Object { $_.Matches[0].Value }
            if ($keysArr) {
                $keys = $keysArr | ConvertFrom-Json
                $anon = $keys | Where-Object { $_.name -eq 'anon' } | Select-Object -First 1
                $svc  = $keys | Where-Object { $_.name -eq 'service_role' } | Select-Object -First 1
                if ($anon) { $SB_ANON_KEY = $anon.api_key }
                if ($svc)  { $SB_SERVICE_KEY = $svc.api_key }
            }
        } catch {}
        if ($SB_ANON_KEY -and $SB_SERVICE_KEY) { break }
        Info "待機中... ($($i*10)秒経過)"
    }
    $SB_URL = "https://$SB_PROJECT_ID.supabase.co"

    if (-not $SB_ANON_KEY -or -not $SB_SERVICE_KEY) {
        Warn "APIキーの自動取得に失敗しました。手動で入力してください"
        Info "取得場所: Supabase ダッシュボード -> $SB_PROJECT_NAME -> Settings -> API"
        $SB_ANON_KEY    = Read-Host "anon public キー"
        $SB_SERVICE_KEY = Read-Host "service_role キー"
    }
    Ok "Supabase URL: $SB_URL"

    Info "データベースマイグレーションを実行中..."
    & supabase link --project-ref $SB_PROJECT_ID --password $SB_DB_PASSWORD
    & supabase db push --yes
    Ok "マイグレーション完了"
}

# =============================================================================
# 5. DMM API キーの入力
# =============================================================================
Step "STEP 5: DMM API キーの入力"

if ($LOCAL_MODE) {
    Info "ローカルモード: DMM API キーはデータ同期スクリプト実行時に必要です"
    $DMM_API_ID = Read-Host "DMM API ID (スキップは Enter)"
    $DMM_AFFILIATE_ID = Read-Host "DMM アフィリエイト ID (スキップは Enter)"
    if (-not $DMM_API_ID) { $DMM_API_ID = "your_api_id_here" }
    if (-not $DMM_AFFILIATE_ID) { $DMM_AFFILIATE_ID = "your_affiliate_id-990" }
    $PUBLIC_GA4_ID = ""
    $ADMIN_EMAIL = Read-Host "管理画面ログイン用メールアドレス"
} else {
    Info "取得場所: https://affiliate.dmm.com/api/"
    $DMM_API_ID = Read-Host "DMM API ID"
    $DMM_AFFILIATE_ID = Read-Host "DMM アフィリエイト ID (例: xxxxx-999)"
    $PUBLIC_GA4_ID = Read-Host "Google Analytics 4 測定ID (任意 / スキップは Enter)"
    $ADMIN_EMAIL = Read-Host "管理画面ログイン用メールアドレス"
}

# =============================================================================
# 6. .env ファイル生成
# =============================================================================
Step "STEP 6: .env ファイルの生成"

$date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

$envRoot = @"
# 自動生成 - $date
# このファイルは絶対に Git にコミットしないでください

# Supabase
SUPABASE_URL=$SB_URL
SUPABASE_SERVICE_ROLE_KEY=$SB_SERVICE_KEY

# DMM API
DMM_API_ID=$DMM_API_ID
DMM_AFFILIATE_ID=$DMM_AFFILIATE_ID
"@
[System.IO.File]::WriteAllText("$SCRIPT_DIR\.env", $envRoot, [System.Text.UTF8Encoding]::new($false))
Ok "ルート .env を生成しました"

$envAstro = @"
# 自動生成 - $date
# このファイルは絶対に Git にコミットしないでください

PUBLIC_SUPABASE_URL=$SB_URL
PUBLIC_SUPABASE_ANON_KEY=$SB_ANON_KEY
PUBLIC_GA4_ID=$PUBLIC_GA4_ID

# Admin
SUPABASE_URL=$SB_URL
SUPABASE_SERVICE_ROLE_KEY=$SB_SERVICE_KEY
ADMIN_EMAIL=$ADMIN_EMAIL
"@
[System.IO.File]::WriteAllText("$SCRIPT_DIR\astro\.env", $envAstro, [System.Text.UTF8Encoding]::new($false))
Ok "astro\.env を生成しました"

# 管理者ユーザーを Supabase Auth に登録
if ($ADMIN_EMAIL -and $SB_SERVICE_KEY) {
    Info "管理者ユーザーを Supabase に登録中..."
    try {
        $body = @{ email = $ADMIN_EMAIL; email_confirm = $true } | ConvertTo-Json -Compress
        Invoke-RestMethod -Method Post -Uri "$SB_URL/auth/v1/admin/users" `
            -Headers @{ apikey = $SB_SERVICE_KEY; Authorization = "Bearer $SB_SERVICE_KEY"; 'Content-Type' = 'application/json' } `
            -Body $body | Out-Null
        Ok "管理者ユーザーを登録しました: $ADMIN_EMAIL"
    } catch {
        $code = 0
        try { $code = [int]$_.Exception.Response.StatusCode } catch {}
        $msg = "$($_.Exception.Message) $($_.ErrorDetails.Message)"
        if ($code -eq 422 -or $msg -match 'already') {
            Ok "管理者ユーザーは既に登録済みです: $ADMIN_EMAIL"
        } else {
            Warn "管理者ユーザーの登録に失敗: $msg"
            Warn "Supabase Dashboard -> Authentication -> Users から手動で追加してください"
        }
    }
}

# =============================================================================
# 7. wrangler の name を更新
# =============================================================================
Step "STEP 7: Cloudflare プロジェクト名の更新"

function Update-FileText($path, $pattern, $replacement) {
    if (-not (Test-Path $path)) { return }
    try { attrib -R $path 2>$null } catch {}
    $s = [System.IO.File]::ReadAllText($path, [System.Text.UTF8Encoding]::new($false))
    $s = [regex]::Replace($s, $pattern, $replacement)
    [System.IO.File]::WriteAllText($path, $s, [System.Text.UTF8Encoding]::new($false))
}

Update-FileText "$SCRIPT_DIR\wrangler.jsonc"      '"name"\s*:\s*"[^"]*"'  ('"name": "' + $CF_PROJECT_NAME + '"')
Update-FileText "$SCRIPT_DIR\astro\wrangler.toml" '(?m)^name\s*=\s*"[^"]*"' ('name = "' + $CF_PROJECT_NAME + '"')
Ok "wrangler.jsonc と astro\wrangler.toml を更新しました"

# Cloudflare workers.dev サブドメイン取得
$CF_SUBDOMAIN = ""
$_CF_ACCOUNT_ID = ""
$_WRANGLER_TOKEN = ""
try {
    $whoami = (& wrangler whoami 2>&1 | Out-String)
    $hex = [regex]::Match($whoami, '[0-9a-f]{32}')
    if ($hex.Success) { $_CF_ACCOUNT_ID = $hex.Value }
} catch {}

foreach ($wp in @(
    "$env:APPDATA\.wrangler\config\default.toml",
    "$env:USERPROFILE\.wrangler\config\default.toml",
    "$env:LOCALAPPDATA\.wrangler\config\default.toml"
)) {
    if (Test-Path $wp) {
        $t = Get-Content $wp -Raw
        $tm = [regex]::Match($t, 'oauth_token\s*=\s*"([^"]+)"')
        if ($tm.Success) { $_WRANGLER_TOKEN = $tm.Groups[1].Value; break }
    }
}

if ($_CF_ACCOUNT_ID -and $_WRANGLER_TOKEN) {
    try {
        $r = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/accounts/$_CF_ACCOUNT_ID/workers/subdomain" `
            -Headers @{ Authorization = "Bearer $_WRANGLER_TOKEN" }
        if ($r.success) { $CF_SUBDOMAIN = $r.result.subdomain }
    } catch {}
}

if (-not $CF_SUBDOMAIN) {
    Warn "Cloudflare サブドメインを自動取得できませんでした。GitHub ユーザー名を代替使用します。"
    $CF_SUBDOMAIN = $GH_OWNER
} else {
    Ok "Cloudflare workers.dev サブドメイン: $CF_SUBDOMAIN"
}

$SITE_URL = "https://$CF_PROJECT_NAME.$CF_SUBDOMAIN.workers.dev"

# site.config.js 更新
$cfgPath = "$SCRIPT_DIR\site.config.js"
try { attrib -R $cfgPath 2>$null } catch {}
$cfg = [System.IO.File]::ReadAllText($cfgPath, [System.Text.UTF8Encoding]::new($false))
function Esc($s) { return ($s -replace "'", "\'") }
$cfg = [regex]::Replace($cfg, 'siteName:[^\r\n]*',        ("siteName: '"        + (Esc $SITE_NAME)        + "',"))
$cfg = [regex]::Replace($cfg, 'siteUrl:[^\r\n]*',         ("siteUrl: '"         + (Esc $SITE_URL)         + "',"))
$cfg = [regex]::Replace($cfg, 'siteDescription:[^\r\n]*', ("siteDescription: '" + (Esc $SITE_DESCRIPTION) + "',"))
$cfg = [regex]::Replace($cfg, 'tagline:[^\r\n]*',         ("tagline: '"         + (Esc $SITE_TAGLINE)     + "',"))
[System.IO.File]::WriteAllText($cfgPath, $cfg, [System.Text.UTF8Encoding]::new($false))
Ok "site.config.js を更新しました (siteUrl = $SITE_URL)"

# Supabase Auth Site URL 更新
if (-not $LOCAL_MODE -and $SB_PROJECT_ID) {
    Info "Supabase Auth の Site URL を設定中..."
    $SUPABASE_ACCESS_TOKEN = $env:SUPABASE_ACCESS_TOKEN

    # Windows Credential Manager (go-keyring) から取得
    if (-not $SUPABASE_ACCESS_TOKEN) {
        try {
            $cm = & cmdkey /list:"Supabase CLI" 2>$null | Out-String
            if ($cm -match 'Supabase CLI') {
                Add-Type -Namespace W -Name C -MemberDefinition @'
[DllImport("Advapi32.dll", SetLastError=true, CharSet=CharSet.Unicode, EntryPoint="CredReadW")]
public static extern bool R(string t, uint y, uint f, out System.IntPtr p);
[DllImport("Advapi32.dll", EntryPoint="CredFree")]
public static extern void F(System.IntPtr p);
'@ -ErrorAction SilentlyContinue
                $p = [IntPtr]::Zero
                if ([W.C]::R('Supabase CLI', 1, 0, [ref]$p)) {
                    $size = [System.Runtime.InteropServices.Marshal]::ReadInt32($p, [IntPtr]::Size*2 + 24)
                    $blob = [System.Runtime.InteropServices.Marshal]::ReadIntPtr($p, [IntPtr]::Size*2 + 32)
                    $bytes = New-Object byte[] $size
                    [System.Runtime.InteropServices.Marshal]::Copy($blob, $bytes, 0, $size)
                    [W.C]::F($p)
                    $v = [System.Text.Encoding]::Unicode.GetString($bytes)
                    if ($v.StartsWith('go-keyring-base64:')) {
                        $SUPABASE_ACCESS_TOKEN = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($v.Substring(18)))
                    } else {
                        $SUPABASE_ACCESS_TOKEN = $v
                    }
                }
            }
        } catch {}
    }

    # ファイルから取得 (旧版互換)
    if (-not $SUPABASE_ACCESS_TOKEN) {
        foreach ($p in @(
            "$env:APPDATA\supabase\access-token",
            "$env:USERPROFILE\.supabase\access-token",
            "$env:LOCALAPPDATA\supabase\access-token"
        )) {
            if (Test-Path $p) { $SUPABASE_ACCESS_TOKEN = (Get-Content $p -Raw).Trim(); break }
        }
    }

    if (-not $SUPABASE_ACCESS_TOKEN) {
        Warn "supabase login のアクセストークンを自動取得できませんでした"
        Info "Personal Access Token: https://supabase.com/dashboard/account/tokens"
        $SUPABASE_ACCESS_TOKEN = Read-Host "Supabase Personal Access Token (空Enterでスキップ)"
    }

    if ($SUPABASE_ACCESS_TOKEN) {
        try {
            $body = @{
                site_url = $SITE_URL
                additional_redirect_urls = "$SITE_URL/admin/auth/callback"
            } | ConvertTo-Json -Compress
            Invoke-RestMethod -Method Patch -Uri "https://api.supabase.com/v1/projects/$SB_PROJECT_ID/config/auth" `
                -Headers @{ Authorization = "Bearer $SUPABASE_ACCESS_TOKEN"; 'Content-Type' = 'application/json' } `
                -Body $body | Out-Null
            Ok "Supabase Auth Site URL を設定しました -> $SITE_URL"
        } catch {
            Warn "Supabase Auth Site URL の自動設定に失敗: $($_.Exception.Message)"
            Warn "手動で設定してください: Supabase Dashboard -> Authentication -> URL Configuration"
            Warn "  Site URL: $SITE_URL"
            Warn "  Redirect URLs: $SITE_URL/admin/auth/callback"
        }
    } else {
        Warn "スキップしました。手動で設定してください: Site URL = $SITE_URL"
    }
}

# ローカルモードはここで終了
if ($LOCAL_MODE) {
    Info "依存パッケージをインストール中 (ルート)..."
    Push-Location $SCRIPT_DIR; & npm install; Pop-Location
    Info "依存パッケージをインストール中 (Astro)..."
    Push-Location "$SCRIPT_DIR\astro"; & npm install; Pop-Location

    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Green
    Write-Host "   ローカルセットアップ完了!" -ForegroundColor Green
    Write-Host "  ============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Supabase Studio: $SB_STUDIO_URL"
    Write-Host "  次のステップ:"
    Write-Host "    1. cd astro && npm run dev"
    Write-Host "    2. .env に DMM API キーを設定後: npm run sync:products"
    Write-Host ""
    Read-Host "Enter で終了"
    exit 0
}

# =============================================================================
# 8. GitHub リポジトリ作成 + Secrets 登録
# =============================================================================
Step "STEP 8: GitHub リポジトリのセットアップ"

if (-not (Test-Path "$SCRIPT_DIR\.git")) {
    if (-not (Test-Path "$SCRIPT_DIR\.gitignore")) {
        @"
node_modules/
dist/
.env
.astro/
.DS_Store
*.log
.claude/
CLAUDE.md
"@ | Set-Content -Path "$SCRIPT_DIR\.gitignore" -Encoding UTF8
    }
    & git -C $SCRIPT_DIR init
    & git -C $SCRIPT_DIR add .
    & git -C $SCRIPT_DIR commit -m "Initial commit"
    Ok "git リポジトリを初期化しました"
}

& gh repo view "$GH_OWNER/$GH_REPO_NAME" *>$null
if ($LASTEXITCODE -ne 0) {
    & git -C $SCRIPT_DIR remote remove origin 2>$null
    & gh repo create "$GH_OWNER/$GH_REPO_NAME" --private --source=$SCRIPT_DIR --remote=origin --push
    Ok "GitHub リポジトリ作成完了: https://github.com/$GH_OWNER/$GH_REPO_NAME"
} else {
    Warn "リポジトリ $GH_OWNER/$GH_REPO_NAME はすでに存在します。スキップします"
    $repoUrl = "https://github.com/$GH_OWNER/$GH_REPO_NAME.git"
    & git -C $SCRIPT_DIR remote get-url origin *>$null
    if ($LASTEXITCODE -eq 0) {
        & git -C $SCRIPT_DIR remote set-url origin $repoUrl
    } else {
        & git -C $SCRIPT_DIR remote add origin $repoUrl
    }
    & git -C $SCRIPT_DIR push origin main --force-with-lease 2>$null
}

Info "GitHub Actions を有効化中..."
$ghActionsOk = $false
for ($i = 0; $i -lt 3; $i++) {
    & gh api "repos/$GH_OWNER/$GH_REPO_NAME/actions/permissions" --method PUT -F enabled=true -f allowed_actions=all --silent 2>$null
    if ($LASTEXITCODE -eq 0) { $ghActionsOk = $true; break }
    Start-Sleep -Seconds 2
}
if ($ghActionsOk) { Ok "GitHub Actions を有効化しました" }
else { Warn "GitHub Actions の有効化をスキップ (Settings > Actions から有効化してください)" }

Write-Host ""
Write-Host "  Cloudflare API Token の作成手順"
Write-Host "  ─────────────────────────────────────────────"
Write-Host "  1. https://dash.cloudflare.com/profile/api-tokens を開く"
Write-Host "  2. [Create Token] をクリック"
Write-Host "  3. [Edit Cloudflare Workers] テンプレートの [Use template]"
Write-Host "  4. Account Resources: Include / All accounts"
Write-Host "  5. Zone Resources: Include / All zones"
Write-Host "  6. [Continue to summary] -> [Create Token]"
Write-Host "  7. トークンをコピー (この画面を閉じると二度と表示されません)"
Write-Host "  ─────────────────────────────────────────────"
Write-Host ""
$CF_API_TOKEN = Read-Host "Cloudflare API Token を貼り付けてください"

Info "GitHub Secrets を登録中..."
$DMM_SITE_VAL    = Read-SiteConfig 'dmm.site'    ; if (-not $DMM_SITE_VAL) { $DMM_SITE_VAL = 'FANZA' }
$DMM_SERVICE_VAL = Read-SiteConfig 'dmm.service' ; if (-not $DMM_SERVICE_VAL) { $DMM_SERVICE_VAL = 'digital' }
$DMM_FLOOR_VAL   = Read-SiteConfig 'dmm.floor'   ; if (-not $DMM_FLOOR_VAL) { $DMM_FLOOR_VAL = 'videoa' }

$secrets = @{
    SUPABASE_URL              = $SB_URL
    SUPABASE_SERVICE_ROLE_KEY = $SB_SERVICE_KEY
    PUBLIC_SUPABASE_URL       = $SB_URL
    PUBLIC_SUPABASE_ANON_KEY  = $SB_ANON_KEY
    DMM_API_ID                = $DMM_API_ID
    DMM_AFFILIATE_ID          = $DMM_AFFILIATE_ID
    DMM_SITE                  = $DMM_SITE_VAL
    DMM_SERVICE               = $DMM_SERVICE_VAL
    DMM_FLOOR                 = $DMM_FLOOR_VAL
    CLOUDFLARE_API_TOKEN      = $CF_API_TOKEN
}
foreach ($k in $secrets.Keys) {
    & gh secret set $k --repo "$GH_OWNER/$GH_REPO_NAME" --body $secrets[$k]
}
if ($PUBLIC_GA4_ID) {
    & gh secret set PUBLIC_GA --repo "$GH_OWNER/$GH_REPO_NAME" --body $PUBLIC_GA4_ID
}
Ok "GitHub Secrets の登録完了 ($GH_OWNER/$GH_REPO_NAME)"

# =============================================================================
# 9. Cloudflare デプロイ
# =============================================================================
Step "STEP 9: Cloudflare Workers への初回デプロイ"

Info "Astro をビルド中..."
Push-Location "$SCRIPT_DIR\astro"
& npm install
& npm run build
if ($LASTEXITCODE -ne 0) { Pop-Location; Fail "Astro build failed" }
Pop-Location

Info "Cloudflare Workers にデプロイ中..."
$env:CLOUDFLARE_API_TOKEN = $CF_API_TOKEN
Push-Location "$SCRIPT_DIR\astro"
& npx wrangler deploy --config dist/server/wrangler.json
Pop-Location

Ok "Cloudflare デプロイ完了"

Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host "   セットアップ完了!" -ForegroundColor Green
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Supabase ダッシュボード: https://supabase.com/dashboard/project/$SB_PROJECT_ID"
Write-Host "  GitHub リポジトリ:       https://github.com/$GH_OWNER/$GH_REPO_NAME"
Write-Host "  Cloudflare Workers:      $SITE_URL"
Write-Host ""
Write-Host "  次のステップ:"
Write-Host "    1. GitHub Actions -> backfill を手動実行してデータを初期投入"
Write-Host "    2. 独自ドメインは Cloudflare の設定から追加"
Write-Host ""
Read-Host "Enter で終了"
