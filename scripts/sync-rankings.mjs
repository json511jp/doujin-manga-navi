/**
 * sync-rankings.mjs
 * ランキング取得 — sort=rank で人気順取得し DELETE→INSERT
 */

import { fetchItems, itemToProduct, itemToGenres, itemToActressIds, sleep } from './lib/dmm.mjs';
import { supabase, logJob } from './lib/supabase.mjs';
import { siteConfig } from '../site.config.js';

const JOB_NAME = 'sync-rankings';

const RANK_TYPES = [
  { key: 'monthly', sort: 'rank',   hits: 100 },
  { key: 'weekly',  sort: 'rankweek', hits: 100 },
];

// ニッチランキング: site.config.js の nicheRanking 設定を使用
const NICHE_GENRE_IDS = siteConfig.nicheRanking.genreIds;
const NICHE_SLUG = siteConfig.nicheRanking.slug;

try {
  console.log('[sync-rankings] 開始');

  for (const { key, sort, hits } of RANK_TYPES) {
    await syncRankType(key, sort, hits);
    await sleep(1500);
  }

  // ニッチ特化ランキング（ジャンル絞り込み）
  if (NICHE_GENRE_IDS.length > 0) {
    await syncNicheRanking();
  }

  console.log('[sync-rankings] 完了');
  await logJob(JOB_NAME, 'success', { rank_types: ['monthly', 'weekly', NICHE_SLUG] });

} catch (err) {
  console.error('[sync-rankings] 致命的エラー:', err);
  await logJob(JOB_NAME, 'error', {}, err.message);
  process.exit(1);
}

async function syncRankType(rankType, sort, hits) {
  console.log(`[sync-rankings] ${rankType} 取得中...`);

  const { items } = await fetchItems({ hits, offset: 1, sort });
  if (items.length === 0) {
    console.log(`[sync-rankings] ${rankType} 0件`);
    return;
  }

  // products を upsert して UUID を確保
  const rows = [];
  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    try {
      const product = itemToProduct(item);
      const { data } = await supabase
        .from('products')
        .upsert(product, { onConflict: 'dmm_content_id' })
        .select('id')
        .single();
      if (data) rows.push({ product_id: data.id, rank_position: i + 1 });
    } catch (e) {
      console.warn(`upsert失敗 content_id=${item.content_id}:`, e.message);
    }
  }

  // トランザクション内で DELETE → INSERT
  const { error } = await supabase.rpc('replace_rankings', {
    p_rank_type: rankType,
    p_rows: rows,
  });

  if (error) throw new Error(`replace_rankings(${rankType}): ${error.message}`);
  console.log(`[sync-rankings] ${rankType} ${rows.length}件更新`);
}

async function syncNicheRanking() {
  console.log(`[sync-rankings] ${NICHE_SLUG} 取得中...`);

  // ニッチランキング対象ジャンルの作品をレビュー平均順で取得
  const { data: nicheProducts } = await supabase
    .from('product_genres')
    .select('product_id, genres!inner(dmm_genre_id)')
    .in('genres.dmm_genre_id', NICHE_GENRE_IDS)
    .limit(200);

  if (!nicheProducts?.length) {
    console.log(`[sync-rankings] ${NICHE_SLUG} 対象なし`);
    return;
  }

  const productIds = [...new Set(nicheProducts.map(r => r.product_id))];
  const { data: products } = await supabase
    .from('products')
    .select('id, review_average, review_count')
    .in('id', productIds)
    .eq('is_active', true)
    .order('review_average', { ascending: false })
    .limit(100);

  if (!products?.length) return;

  const rows = products.map((p, i) => ({ product_id: p.id, rank_position: i + 1 }));

  const { error } = await supabase.rpc('replace_rankings', {
    p_rank_type: NICHE_SLUG,
    p_rows: rows,
  });

  if (error) throw new Error(`replace_rankings(${NICHE_SLUG}): ${error.message}`);
  console.log(`[sync-rankings] ${NICHE_SLUG} ${rows.length}件更新`);
}
