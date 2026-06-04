import type { APIRoute } from 'astro';
import { getAnonClient } from '../../../lib/adminClient';
import { setCookies } from '../../../lib/authCookies';

export const POST: APIRoute = async ({ request, cookies }) => {
  let body: { access_token?: string; refresh_token?: string };
  try {
    body = await request.json();
  } catch {
    return new Response('invalid json', { status: 400 });
  }

  const { access_token, refresh_token } = body;
  if (!access_token) return new Response('missing access_token', { status: 400 });

  // トークンが正当なユーザーのものか確認
  const { data: { user }, error } = await getAnonClient().auth.getUser(access_token);
  if (error || !user) return new Response('invalid token', { status: 401 });

  setCookies(cookies, access_token, refresh_token ?? '');
  return new Response('ok');
};
