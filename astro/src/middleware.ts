import { defineMiddleware } from 'astro:middleware';
import { getAdminSetting, getAnonClient } from './lib/adminClient';
import { setCookies, clearCookies } from './lib/authCookies';
import { colorsToCssVars } from './lib/themes';
import type { ThemeColors } from './lib/themes';

const PUBLIC_ADMIN_PATHS = ['/admin/login', '/admin/auth/callback', '/api/admin/set-session'];

// Cache theme CSS vars in-process to avoid a DB round-trip on every public request
let _themeCache: { vars: string; at: number } | null = null;
const THEME_CACHE_TTL = 60_000;

async function getThemeVars(): Promise<string> {
  if (_themeCache && Date.now() - _themeCache.at < THEME_CACHE_TTL) return _themeCache.vars;
  try {
    const colors = await getAdminSetting<ThemeColors>('colors');
    const vars = colors ? colorsToCssVars(colors) : '';
    _themeCache = { vars, at: Date.now() };
    return vars;
  } catch {
    return _themeCache?.vars ?? '';
  }
}

export const onRequest = defineMiddleware(async (context, next) => {
  context.locals.themeVars = await getThemeVars();
  context.locals.adminUser = null;

  const { pathname } = context.url;
  if (!pathname.startsWith('/admin')) return next();
  if (PUBLIC_ADMIN_PATHS.some(p => pathname.startsWith(p))) return next();

  const accessToken  = context.cookies.get('admin_access_token')?.value;
  const refreshToken = context.cookies.get('admin_refresh_token')?.value;

  if (!accessToken) return context.redirect('/admin/login');

  try {
    const client = getAnonClient();
    const { data: { user }, error } = await client.auth.getUser(accessToken);

    if (error || !user) {
      if (refreshToken) {
        const { data, error: refreshError } = await client.auth.refreshSession({ refresh_token: refreshToken });
        if (refreshError || !data.session) {
          clearCookies(context.cookies);
          return context.redirect('/admin/login');
        }
        if (!isAllowedAdmin(data.user?.email)) {
          clearCookies(context.cookies);
          return context.redirect('/admin/login');
        }
        setCookies(context.cookies, data.session.access_token, data.session.refresh_token ?? '');
        context.locals.adminUser = { email: data.user?.email ?? '' };
      } else {
        clearCookies(context.cookies);
        return context.redirect('/admin/login');
      }
    } else {
      if (!isAllowedAdmin(user.email)) {
        clearCookies(context.cookies);
        return context.redirect('/admin/login');
      }
      context.locals.adminUser = { email: user.email ?? '' };
    }
  } catch {
    clearCookies(context.cookies);
    return context.redirect('/admin/login');
  }

  return next();
});

function isAllowedAdmin(email: string | undefined | null): boolean {
  if (!email) return false;
  const allowed = import.meta.env.ADMIN_EMAIL;
  if (!allowed) return true; // 未設定時はすべての認証ユーザーを許可
  return allowed.split(',').map((e: string) => e.trim()).includes(email);
}
