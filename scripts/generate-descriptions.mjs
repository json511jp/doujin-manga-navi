/**
 * generate-descriptions.mjs
 * description が NULL の作品に SEO を意識した作品詳細ページ用の紹介文を生成して upsert
 *
 * OVERWRITE_DESCRIPTIONS=true を指定すると既存 description も再生成する。
 */

import { supabase, logJob } from './lib/supabase.mjs';
import { siteConfig } from '../site.config.js';

const SITE_KEYWORD = siteConfig.dmm.keyword || 'FANZA';
const SITE_NAME = siteConfig.siteName;

const JOB_NAME = 'generate-descriptions';
const BATCH_SIZE = 100;  // 1回の処理件数
const MIN_DESCRIPTION_LENGTH = 500;
const MAX_DESCRIPTION_LENGTH = 900;
const OVERWRITE_DESCRIPTIONS = process.env.OVERWRITE_DESCRIPTIONS === 'true';

let totalUpdated = 0;
let totalSkipped = 0;

try {
  console.log('[generate-descriptions] 開始');

  let offset = 0;
  let hasMore = true;

  while (hasMore) {
    let query = supabase
      .from('products')
      .select(`
        id, dmm_content_id, title, description, review_average, review_count,
        volume, maker_name, label_name, series_name, release_date, price_text, sample_movie_url,
        product_actresses ( actresses ( name ) ),
        product_genres    ( genres    ( name ) )
      `)
      .eq('is_active', true)
      .range(offset, offset + BATCH_SIZE - 1);

    if (!OVERWRITE_DESCRIPTIONS) {
      query = query.is('description', null);
    }

    const { data: products, error } = await query;

    if (error) throw new Error(error.message);
    if (!products || products.length === 0) {
      hasMore = false;
      break;
    }

    console.log(`[generate-descriptions] offset=${offset} ${products.length}件処理中...`);

    for (const product of products) {
      try {
        const description = buildDescription(product);
        if (!description) { totalSkipped++; continue; }

        const { error: updateError } = await supabase
          .from('products')
          .update({ description })
          .eq('id', product.id);

        if (updateError) throw new Error(updateError.message);
        totalUpdated++;
      } catch (e) {
        console.error(`失敗 id=${product.id}:`, e.message);
        totalSkipped++;
      }
    }

    if (products.length < BATCH_SIZE) {
      hasMore = false;
    } else {
      offset += BATCH_SIZE;
      await new Promise(r => setTimeout(r, 500));
    }
  }

  console.log(`[generate-descriptions] 完了 updated=${totalUpdated} skipped=${totalSkipped}`);
  await logJob(JOB_NAME, 'success', { totalUpdated, totalSkipped });

} catch (err) {
  console.error('[generate-descriptions] 致命的エラー:', err);
  await logJob(JOB_NAME, 'error', { totalUpdated }, err.message);
  process.exit(1);
}

function buildDescription(product) {
  const actresses = (product.product_actresses ?? [])
    .map(r => r.actresses?.name).filter(Boolean);
  const genres = (product.product_genres ?? [])
    .map(r => r.genres?.name).filter(Boolean);

  if (!product.title) return null;

  const year = product.release_date
    ? new Date(product.release_date).getFullYear()
    : new Date().getFullYear();

  const sortedGenres = prioritizeGenres(unique(genres));
  const genreLabel = sortedGenres.slice(0, 3).join('・') || SITE_KEYWORD;
  const leadGenre = sortedGenres[0] || SITE_KEYWORD;
  const actressLabel = actresses.length > 0 ? unique(actresses).slice(0, 2).join('・') : null;
  const title = cleanTitle(product.title);
  const maker = product.maker_name || product.label_name || null;
  const stars = product.review_average ? Number(product.review_average).toFixed(1) : null;
  const seed = hashString(product.id || product.dmm_content_id || product.title);

  const opener = pick(seed, [
    actressLabel
      ? `${year}年配信、${actressLabel}が出演する${genreLabel}系の動画作品です。タイトルは「${title}」。`
      : `${year}年配信の${genreLabel}系動画作品です。タイトルは「${title}」。`,
    actressLabel
      ? `${actressLabel}出演の${leadGenre}作品としてチェックしたい一本です。「${title}」は、${genreLabel}の要素を軸に作品を探している人に向いています。`
      : `${leadGenre}を探している人に向けた、${genreLabel}系の一本です。「${title}」という作品名どおり、タグやレビューを見ながら比較しやすい作品です。`,
    maker
      ? `${maker}による${genreLabel}作品です。${actressLabel ? `${actressLabel}の出演作としてもチェックしたい「${title}」を、作品情報とあわせて整理しました。` : `「${title}」の基本情報を、ジャンルや評価の観点から確認できます。`}`
      : `${genreLabel}の作品を探している人に向けて、「${title}」の見どころと確認ポイントを整理しました。`,
  ]);

  const angle = pick(seed + 7, [
    `${genreLabel}系の作品では、設定や雰囲気が好みに合うかどうかが大事です。この作品は${genreLabel}のタグから探せるため、自分の好みを重視して選びたいときの候補になります。`,
    `${leadGenre}の空気感を楽しみたい人にとって、出演者、メーカー、レビュー評価をまとめて確認できるのは選びやすいポイントです。似たジャンルの作品と比べながら、好みに近い一本かどうかを判断できます。`,
    `${genreLabel}のタグに反応する人なら、まずサンプルとレビューを確認しておきたい作品です。作品名だけで決めず、出演者や関連ジャンルまで見ておくと失敗しにくくなります。`,
  ]);

  const details = [
    product.volume ? `収録時間は${product.volume}分` : null,
    stars ? `レビュー評価は${stars}` : null,
    product.review_count ? `レビュー${product.review_count}件` : null,
    product.price_text ? `価格目安は${product.price_text}` : null,
  ].filter(Boolean);

  const closer = details.length > 0
    ? `${details.slice(0, 4).join('、')}。${sampleText(product)}やレビューを見ながら、自分の好みに合うか確認できます。`
    : `${sampleText(product)}や出演者、関連タグを見ながら、自分の好みに合うか確認できます。`;

  const recommendation = pick(seed + 13, [
    `このページでは、作品の基本情報に加えて、出演女優、関連タグ、同じジャンルの関連作品も確認できます。${SITE_NAME}で${genreLabel}作品を探している人、女優名から出演作を追いたい人、レビュー評価を参考に選びたい人に向けた紹介文です。`,
    `一覧ページだけでは分かりにくい作品の雰囲気を、ジャンル・出演者・評価・収録時間から整理しています。${genreLabel}が好きな人は、関連作品もあわせて見ることで、自分の好みに近い作品を見つけやすくなります。`,
    `作品選びで迷ったときは、タイトルの印象だけでなく、タグ、レビュー、メーカー、出演者を合わせて見るのがおすすめです。${actressLabel ? `${actressLabel}の出演作を探している人にも、` : ''}${leadGenre}系の候補として比較しやすいページです。`,
  ]);

  const caveat = `紹介文は作品データをもとに作成しているため、購入や視聴前には配信ページの最新情報も確認してください。`;

  return fitLongDescription([opener, angle, closer, recommendation, caveat].join('\n\n'));
}

function prioritizeGenres(genres) {
  // site.config.js の nicheRanking ジャンル名を優先表示（ジャンル名の部分一致）
  const nicheLabel = siteConfig.nicheRanking.label.replace(/ランキング$/, '');
  const keyword = siteConfig.dmm.keyword;
  const priority = [nicheLabel, keyword, '熟女', '巨乳', '美少女', 'ドラマ'].filter(Boolean);
  return [
    ...genres.filter(g => priority.some(k => g.includes(k))),
    ...genres.filter(g => !priority.some(k => g.includes(k))),
  ];
}

function sampleText(product) {
  return product.sample_movie_url ? 'サンプル動画・画像' : 'サンプル画像';
}

function cleanTitle(title) {
  return String(title)
    .replace(/\s+/g, ' ')
    .replace(/[【】]/g, '')
    .trim()
    .slice(0, 70);
}

function unique(values) {
  return [...new Set(values.map(v => String(v).trim()).filter(Boolean))];
}

function pick(seed, values) {
  return values[Math.abs(seed) % values.length];
}

function hashString(value) {
  let hash = 0;
  for (const char of String(value)) {
    hash = ((hash << 5) - hash + char.charCodeAt(0)) | 0;
  }
  return hash;
}

function fitLongDescription(text) {
  let description = normalizeParagraphs(text);
  let fallbackIndex = 0;
  while (description.length < MIN_DESCRIPTION_LENGTH && fallbackIndex < 3) {
    description = normalizeParagraphs(`${description}\n\n${fallbackParagraph(fallbackIndex)}`);
    fallbackIndex++;
  }
  if (description.length <= MAX_DESCRIPTION_LENGTH) return description;

  const sliced = description.slice(0, MAX_DESCRIPTION_LENGTH - 1);
  const lastPunctuation = Math.max(sliced.lastIndexOf('。'), sliced.lastIndexOf('、'));
  return `${sliced.slice(0, lastPunctuation > MIN_DESCRIPTION_LENGTH ? lastPunctuation + 1 : MAX_DESCRIPTION_LENGTH - 1)}…`;
}

function normalizeParagraphs(text) {
  return text
    .split(/\n{2,}/)
    .map(paragraph => paragraph.replace(/\s+/g, ' ').trim())
    .filter(Boolean)
    .join('\n\n');
}

function fallbackParagraph(index) {
  const keyword = SITE_KEYWORD;
  return [
    `${keyword}系の作品は、テーマごとに雰囲気や見せ方が大きく変わります。気になる作品を選ぶときは、サンプルの印象、出演者、レビュー件数、関連タグを合わせて見ると、自分の好みに合うか判断しやすくなります。`,
    `初めて見る作品でも、収録時間やメーカー、評価の傾向を確認しておくと選びやすくなります。タグの組み合わせも参考にすると、自分の好みに合った作品を見つけやすくなります。`,
    `関連作品や同じ出演者の作品もあわせて確認すると、似た雰囲気の動画を探しやすくなります。作品詳細ページでは、タイトルだけでは分からない比較材料をまとめ、視聴前の判断に役立つ情報を整理しています。`,
  ][index] ?? '';
}
