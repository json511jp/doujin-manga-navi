/**
 * sync-products.mjs
 * 日次新作取得 — 昨日以降の新作を upsert
 */

import { fetchItems, itemToProduct, itemToGenres, itemToActressIds, sleep } from './lib/dmm.mjs';
import { supabase, logJob } from './lib/supabase.mjs';

const JOB_NAME = 'sync-products';

// GTE_DATE が指定されていなければ昨日の日付を使用
const gteDate = process.env.GTE_DATE || (() => {
  const d = new Date();
  d.setDate(d.getDate());
  return d.toISOString().split('T')[0];
})();

let totalInserted = 0;
let totalSkipped = 0;

try {
  console.log(`[sync-products] gte_date=${gteDate}`);

  let offset = 1;
  const hits = 100;

  while (true) {
    const { totalCount, items } = await fetchItems({
      hits,
      offset,
      sort: 'date',
      gte_date: gteDate,
    });

    if (items.length === 0) break;
    console.log(`[sync-products] ${items.length}件取得 offset=${offset}`);

    for (const item of items) {
      try {
        await upsertItem(item);
        totalInserted++;
      } catch (e) {
        console.error(`upsert失敗 content_id=${item.content_id}:`, e.message);
        totalSkipped++;
      }
    }

    if (offset + hits > totalCount || offset + hits > 50000) break;
    offset += hits;
    await sleep(1000);
  }

  console.log(`[sync-products] 完了 inserted=${totalInserted} skipped=${totalSkipped}`);
  await logJob(JOB_NAME, 'success', { gte_date: gteDate, totalInserted, totalSkipped });

} catch (err) {
  console.error('[sync-products] 致命的エラー:', err);
  await logJob(JOB_NAME, 'error', { gte_date: gteDate, totalInserted }, err.message);
  process.exit(1);
}

async function upsertItem(item) {
  const product = itemToProduct(item);
  const genres = itemToGenres(item);
  const actressIds = itemToActressIds(item);

  const { data: productData, error } = await supabase
    .from('products')
    .upsert(product, { onConflict: 'dmm_content_id' })
    .select('id')
    .single();

  if (error) throw new Error(error.message);
  const productId = productData.id;

  if (genres.length > 0) {
    await supabase.from('genres').upsert(genres, { onConflict: 'dmm_genre_id', ignoreDuplicates: true });
    const { data: genreRows } = await supabase
      .from('genres').select('id, dmm_genre_id').in('dmm_genre_id', genres.map(g => g.dmm_genre_id));
    if (genreRows?.length) {
      await supabase.from('product_genres').upsert(
        genreRows.map(g => ({ product_id: productId, genre_id: g.id })),
        { onConflict: 'product_id,genre_id', ignoreDuplicates: true }
      );
    }
  }

  if (actressIds.length > 0) {
    const { data: actressRows } = await supabase
      .from('actresses').select('id, dmm_actress_id').in('dmm_actress_id', actressIds);
    if (actressRows?.length) {
      await supabase.from('product_actresses').upsert(
        actressRows.map(a => ({ product_id: productId, actress_id: a.id })),
        { onConflict: 'product_id,actress_id', ignoreDuplicates: true }
      );
    }
  }
}
