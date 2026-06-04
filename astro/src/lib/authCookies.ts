import type { AstroCookies } from 'astro';

// secure は本番ビルド時のみ true（ローカル dev の http://localhost でも cookie がセットされるように）
const COOKIE_OPTS = { httpOnly: true, secure: import.meta.env.PROD, sameSite: 'lax' as const, path: '/' };

export function setCookies(cookies: AstroCookies, access: string, refresh: string) {
  cookies.set('admin_access_token',  access,  { ...COOKIE_OPTS, maxAge: 3600 });
  cookies.set('admin_refresh_token', refresh, { ...COOKIE_OPTS, maxAge: 604800 });
}

export function clearCookies(cookies: AstroCookies) {
  cookies.delete('admin_access_token',  { path: '/' });
  cookies.delete('admin_refresh_token', { path: '/' });
}
