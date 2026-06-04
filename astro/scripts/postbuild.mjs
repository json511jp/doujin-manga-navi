import { readFileSync, writeFileSync } from 'fs';

const path = 'dist/server/wrangler.json';
const config = JSON.parse(readFileSync(path, 'utf8'));

// SESSION KV binding is auto-added by @astrojs/cloudflare but not used
config.kv_namespaces = [];

// Inject Supabase vars so the Worker runtime can access them
const supabaseUrl = process.env.PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.PUBLIC_SUPABASE_ANON_KEY;
if (supabaseUrl && supabaseAnonKey) {
  config.vars = {
    ...(config.vars ?? {}),
    PUBLIC_SUPABASE_URL: supabaseUrl,
    PUBLIC_SUPABASE_ANON_KEY: supabaseAnonKey,
  };
  console.log('[postbuild] Injected PUBLIC_SUPABASE_URL and PUBLIC_SUPABASE_ANON_KEY into wrangler.json vars');
} else {
  console.warn('[postbuild] WARNING: PUBLIC_SUPABASE_URL or PUBLIC_SUPABASE_ANON_KEY not set');
}

writeFileSync(path, JSON.stringify(config));
console.log('[postbuild] Removed unused KV bindings from dist/server/wrangler.json');
