/**
 * sync-actresses.mjs
 * 女優情報 upsert + actress_relations 再計算
 */

import { fetchActresses, actressToRecord, sleep } from './lib/dmm.mjs';
import { supabase, logJob } from './lib/supabase.mjs';

const JOB_NAME = 'sync-actresses';
let totalUpserted = 0;

try {
  console.log('[sync-actresses] 開始');

  // products に登場する dmm_actress_id を収集
  const { data: existingActresses } = await supabase
    .from('actresses')
    .select('dmm_actress_id');

  // product_actresses 経由で未登録の actress_id を取得
  const { data: productActressIds } = await supabase.rpc('get_unsynced_actress_ids');

  // actress_ids のユニークリスト（既存 + 未登録）
  const existingIds = new Set((existingActresses ?? []).map(a => a.dmm_actress_id));

  // まず既存女優を更新、次に未登録を追加
  let offset = 1;
  const hits = 100;

  while (true) {
    const { totalCount, actresses } = await fetchActresses({ hits, offset });
    if (actresses.length === 0) break;

    console.log(`[sync-actresses] ${actresses.length}件取得 offset=${offset}`);

    const records = actresses.map(a => actressToRecord(a));

    // slug 重複チェック・suffix 付与
    for (const r of records) {
      const { data: existing } = await supabase
        .from('actresses')
        .select('id')
        .eq('slug', r.slug)
        .neq('dmm_actress_id', r.dmm_actress_id)
        .maybeSingle();

      if (existing) {
        r.slug = `${r.slug}-${r.dmm_actress_id}`;
      }
    }

    const { error } = await supabase
      .from('actresses')
      .upsert(records, { onConflict: 'dmm_actress_id' });

    if (error) console.error('actresses upsert警告:', error.message);
    else totalUpserted += records.length;

    if (offset + hits > totalCount || offset + hits > 50000) break;
    offset += hits;
    await sleep(1000);
  }

  // actress_relations 再計算
  console.log('[sync-actresses] actress_relations 再計算中...');
  const { error: rpcError } = await supabase.rpc('recalculate_actress_relations');
  if (rpcError) console.error('recalculate_actress_relations エラー:', rpcError.message);
  else console.log('[sync-actresses] actress_relations 再計算完了');

  console.log(`[sync-actresses] 完了 upserted=${totalUpserted}`);
  await logJob(JOB_NAME, 'success', { totalUpserted });

} catch (err) {
  console.error('[sync-actresses] 致命的エラー:', err);
  await logJob(JOB_NAME, 'error', { totalUpserted }, err.message);
  process.exit(1);
}
