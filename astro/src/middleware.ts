import { defineMiddleware } from 'astro:middleware';
import { getAdminSetting, getAnonClient } from './lib/adminClient';
import { setCookies, clearCookies } from './lib/authCookies';
import { colorsToCssVars } from './lib/themes';
import type { ThemeColors } from './lib/themes';
import { siteConfig } from '../../site.config.js';

const PUBLIC_ADMIN_PATHS = ['/admin/login', '/admin/auth/callback', '/api/admin/set-session'];
const CACHE_TTL = 60_000;

// --- テーマ CSS 変数キャッシュ ---
let _themeCache: { vars: string; at: number } | null = null;

async function getThemeVars(): Promise<string> {
  if (_themeCache && Date.now() - _themeCache.at < CACHE_TTL) return _themeCache.vars;
  try {
    const colors = await getAdminSetting<ThemeColors>('colors');
    const vars = colors ? colorsToCssVars(colors) : '';
    _themeCache = { vars, at: Date.now() };
    return vars;
  } catch {
    return _themeCache?.vars ?? '';
  }
}

// --- サイト設定キャッシュ ---
type FlatSiteSettings = {
  siteName?: string; siteDescription?: string; siteUrl?: string;
  tagline?: string; contactEmail?: string; ctaLabel?: string;
  featActresses?: boolean; featSampleMovie?: boolean; featTrialReading?: boolean;
  featDuration?: boolean; featDirector?: boolean; featMaker?: boolean; featVrBadge?: boolean;
  affiliateProgramName?: string; affiliateAgeRestricted?: boolean;
  customCss?: string;
};

type CachedSettings = { settings: App.SiteLocals; customCss: string };
let _settingsCache: { value: CachedSettings; at: number } | null = null;

function buildSiteLocals(s: FlatSiteSettings): App.SiteLocals {
  return {
    siteName:        s.siteName        ?? siteConfig.siteName,
    siteDescription: s.siteDescription ?? siteConfig.siteDescription,
    siteUrl:         s.siteUrl         ?? siteConfig.siteUrl,
    tagline:         s.tagline         ?? siteConfig.tagline,
    contactEmail:    s.contactEmail    ?? siteConfig.contactEmail,
    ctaLabel:        s.ctaLabel        ?? siteConfig.ctaLabel,
    features: {
      actresses:    s.featActresses    ?? siteConfig.features.actresses,
      sampleMovie:  s.featSampleMovie  ?? siteConfig.features.sampleMovie,
      trialReading: s.featTrialReading ?? siteConfig.features.trialReading,
      duration:     s.featDuration     ?? siteConfig.features.duration,
      director:     s.featDirector     ?? siteConfig.features.director,
      maker:        s.featMaker        ?? siteConfig.features.maker,
      vrBadge:      s.featVrBadge      ?? siteConfig.features.vrBadge,
    },
    affiliate: {
      programName:   s.affiliateProgramName   ?? siteConfig.affiliate.programName,
      ageRestricted: s.affiliateAgeRestricted ?? siteConfig.affiliate.ageRestricted,
    },
  };
}

// </style によるブレイクアウトを防ぐ簡易サニタイズ
function sanitizeCss(css: string): string {
  return css.replace(/<\/style/gi, '<\\/style');
}

async function getSiteLocals(): Promise<CachedSettings> {
  if (_settingsCache && Date.now() - _settingsCache.at < CACHE_TTL) return _settingsCache.value;
  try {
    const saved = await getAdminSetting<FlatSiteSettings>('site_settings');
    const value: CachedSettings = {
      settings: buildSiteLocals(saved ?? {}),
      customCss: sanitizeCss(saved?.customCss ?? ''),
    };
    _settingsCache = { value, at: Date.now() };
    return value;
  } catch {
    return _settingsCache?.value ?? { settings: buildSiteLocals({}), customCss: '' };
  }
}

export const onRequest = defineMiddleware(async (context, next) => {
  const [themeVars, siteData] = await Promise.all([getThemeVars(), getSiteLocals()]);
  context.locals.themeVars = themeVars;
  context.locals.siteSettings = siteData.settings;
  context.locals.customCss = siteData.customCss;
  context.locals.adminUser = null;

  const { pathname } = context.url;
  const isAdminPage = pathname.startsWith('/admin');
  const isAdminApi  = pathname.startsWith('/api/admin');
  if (!isAdminPage && !isAdminApi) return next();
  if (PUBLIC_ADMIN_PATHS.some(p => pathname.startsWith(p))) return next();

  // 未認証時の応答: ページなら /admin/login へリダイレクト、API なら 401
  const unauthorized = () =>
    isAdminApi
      ? new Response('Unauthorized', { status: 401 })
      : context.redirect('/admin/login');

  const accessToken  = context.cookies.get('admin_access_token')?.value;
  const refreshToken = context.cookies.get('admin_refresh_token')?.value;

  if (!accessToken) return unauthorized();

  try {
    const client = getAnonClient();
    const { data: { user }, error } = await client.auth.getUser(accessToken);

    if (error || !user) {
      if (refreshToken) {
        const { data, error: refreshError } = await client.auth.refreshSession({ refresh_token: refreshToken });
        if (refreshError || !data.session) {
          clearCookies(context.cookies);
          return unauthorized();
        }
        if (!isAllowedAdmin(data.user?.email)) {
          clearCookies(context.cookies);
          return unauthorized();
        }
        setCookies(context.cookies, data.session.access_token, data.session.refresh_token ?? '');
        context.locals.adminUser = { email: data.user?.email ?? '' };
      } else {
        clearCookies(context.cookies);
        return unauthorized();
      }
    } else {
      if (!isAllowedAdmin(user.email)) {
        clearCookies(context.cookies);
        return unauthorized();
      }
      context.locals.adminUser = { email: user.email ?? '' };
    }
  } catch {
    clearCookies(context.cookies);
    return unauthorized();
  }

  return next();
});

function isAllowedAdmin(email: string | undefined | null): boolean {
  if (!email) return false;
  const allowed = import.meta.env.ADMIN_EMAIL;
  if (!allowed) return true; // 未設定時はすべての認証ユーザーを許可
  return allowed.split(',').map((e: string) => e.trim()).includes(email);
}
