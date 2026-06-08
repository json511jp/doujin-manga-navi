import { createClient } from '@supabase/supabase-js';
import type { Database, Json } from './database.types';

// サーバーサイド専用（service_role key）— クライアントに漏れないこと
let _adminClient: ReturnType<typeof createClient<Database>> | null = null;

export function getAdminClient() {
  if (!_adminClient) {
    const url = import.meta.env.SUPABASE_URL ?? import.meta.env.PUBLIC_SUPABASE_URL ?? '';
    const key = import.meta.env.SUPABASE_SERVICE_ROLE_KEY ?? '';
    _adminClient = createClient<Database>(url, key, { auth: { persistSession: false } });
  }
  return _adminClient;
}

// Cloudflare Workers ではモジュールスコープがリクエスト間で共有されるため、
// auth 用途では毎回新規インスタンスを生成し、SDK 内部状態の漏出を防ぐ。
export function getAnonClient() {
  const url = import.meta.env.PUBLIC_SUPABASE_URL ?? '';
  const key = import.meta.env.PUBLIC_SUPABASE_ANON_KEY ?? '';
  return createClient(url, key, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
}

export async function getAdminSetting<T>(key: string): Promise<T | null> {
  const { data, error } = await getAdminClient().from('admin_settings').select('value').eq('key', key).single();
  if (error && error.code !== 'PGRST116') throw error;
  return data ? (data.value as T) : null;
}

export async function setAdminSetting(key: string, value: unknown): Promise<void> {
  const { error } = await getAdminClient().from('admin_settings').upsert({ key, value: value as Json });
  if (error) throw error;
}
