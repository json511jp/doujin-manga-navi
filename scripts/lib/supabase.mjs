import { createClient } from '@supabase/supabase-js';

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !key) {
  throw new Error('SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY が未設定です');
}

export const supabase = createClient(url, key, {
  auth: { persistSession: false },
  db: { schema: 'public' },
});

/** cron_logs に結果を記録 */
export async function logJob(jobName, status, meta = {}, errorMessage = null) {
  await supabase.from('cron_logs').insert({
    job_name: jobName,
    status,
    error_message: errorMessage,
    meta,
  });
}
