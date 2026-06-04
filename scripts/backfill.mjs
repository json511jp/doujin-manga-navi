/**
 * backfill.mjs
 * 初期データ投入 — 設定フロアの人気順上位100件を取得
 */

import { fetchItems, itemToProduct, itemToGenres, itemToActressIds, itemToActresses, sleep } from './lib/dmm.mjs';
import { supabase, logJob } from './lib/supabase.mjs';

const TOTAL = parseInt(process.env.BACKFILL_LIMIT ?? '100');
const JOB_NAME = 'backfill';

let totalInserted = 0;
let totalSkipped  = 0;

try {
  console.log(`[backfill] フロア全体から人気順 ${TOTAL} 件取得`);

  let offset = 1;
  let fetched = 0;

  while (fetched < TOTAL) {
    const hits = Math.min(100, TOTAL - fetched);
    console.log(`[backfill] offset=${offset} hits=${hits} 取得中...`);

    const { totalCount, items } = await fetchItems({ hits, offset, sort: 'rank' });

    if (items.length === 0) break;

    console.log(`[backfill] ${items.length}件取得 (フロア合計: ${totalCount}件) — upsert開始`);

    let idx = 0;
    for (const item of items) {
      idx++;
      try {
        await upsertItem(item);
        totalInserted++;
        if (idx % 10 === 0 || idx === items.length) {
          console.log(`[backfill]   ${idx}/${items.length} 処理済み (inserted=${totalInserted} skipped=${totalSkipped})`);
        }
      } catch (e) {
        console.error(`[backfill] upsert失敗 content_id=${item.content_id}:`, e.message);
        totalSkipped++;
      }
    }

    fetched += items.length;

    if (fetched >= TOTAL || offset + hits > totalCount) break;

    offset += hits;
    await sleep(1000);
  }

  console.log(`\n[backfill] 完了 inserted=${totalInserted} skipped=${totalSkipped}`);
  await logJob(JOB_NAME, 'success', { total: TOTAL, totalInserted, totalSkipped });

} catch (err) {
  console.error('[backfill] 致命的エラー:', err);
  await logJob(JOB_NAME, 'error', { totalInserted }, err.message);
  process.exit(1);
}

async function upsertItem(item) {
  const product   = itemToProduct(item);
  const genres    = itemToGenres(item);
  const actressIds = itemToActressIds(item);

  const { data: productData, error: productError } = await supabase
    .from('products')
    .upsert(product, { onConflict: 'dmm_content_id' })
    .select('id')
    .single();

  if (productError) throw new Error(`products upsert: ${productError.message}`);
  const productId = productData.id;

  if (genres.length > 0) {
    await supabase.from('genres').upsert(genres, { onConflict: 'dmm_genre_id', ignoreDuplicates: true });

    const { data: genreRows } = await supabase
      .from('genres').select('id, dmm_genre_id')
      .in('dmm_genre_id', genres.map(g => g.dmm_genre_id));

    if (genreRows?.length > 0) {
      await supabase.from('product_genres').upsert(
        genreRows.map(g => ({ product_id: productId, genre_id: g.id })),
        { onConflict: 'product_id,genre_id', ignoreDuplicates: true }
      );
    }
  }

  if (actressIds.length > 0) {
    const actresses = itemToActresses(item);
    if (actresses.length > 0) {
      await supabase.from('actresses').upsert(actresses, {
        onConflict: 'dmm_actress_id',
        ignoreDuplicates: true,
      });
    }

    const { data: actressRows } = await supabase
      .from('actresses').select('id, dmm_actress_id')
      .in('dmm_actress_id', actressIds);

    if (actressRows?.length > 0) {
      await supabase.from('product_actresses').upsert(
        actressRows.map(a => ({ product_id: productId, actress_id: a.id })),
        { onConflict: 'product_id,actress_id', ignoreDuplicates: true }
      );
    }
  }
}
