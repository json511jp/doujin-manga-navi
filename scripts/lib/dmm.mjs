/**
 * DMM Web API クライアント
 * site=FANZA / service=digital / floor=videoa 固定
 */

const DMM_API_BASE = 'https://api.dmm.com/affiliate/v3';
const API_ID = process.env.DMM_API_ID;
const AFFILIATE_ID = process.env.DMM_AFFILIATE_ID;

if (!API_ID || !AFFILIATE_ID) {
  throw new Error('DMM_API_ID / DMM_AFFILIATE_ID が未設定です');
}

const FIXED_PARAMS = {
  api_id: API_ID,
  affiliate_id: AFFILIATE_ID,
  site: process.env.DMM_SITE ?? 'FANZA',
  service: process.env.DMM_SERVICE ?? 'digital',
  floor: process.env.DMM_FLOOR ?? 'videoa',
  output: 'json',
};

/** 1秒スリープ（レート制限対策） */
export const sleep = (ms = 1000) => new Promise(r => setTimeout(r, ms));

/**
 * 作品一覧取得
 * @param {Object} params - hits, offset, sort, gte_date, lte_date など
 */
/** YYYY-MM-DD を YYYY-MM-DDT00:00:00 形式に変換 */
function formatDate(date) {
  if (!date) return undefined;
  // 既に時刻付きならそのまま
  if (/T\d{2}:\d{2}:\d{2}/.test(date)) return date;
  return `${date}T00:00:00`;
}

export async function fetchItems(params = {}) {
  const url = new URL(`${DMM_API_BASE}/ItemList`);
  const normalized = { ...params };
  if (normalized.gte_date) normalized.gte_date = formatDate(normalized.gte_date);
  if (normalized.lte_date) normalized.lte_date = formatDate(normalized.lte_date);
  const merged = { ...FIXED_PARAMS, hits: 100, ...normalized };
  for (const [k, v] of Object.entries(merged)) {
    if (v !== undefined && v !== null && v !== '') url.searchParams.set(k, String(v));
  }

  const res = await fetch(url.toString());
  if (!res.ok) throw new Error(`DMM API error: ${res.status} ${await res.text()}`);
  const json = await res.json();

  const result = json?.result;
  if (!result) throw new Error(`DMM API 不正レスポンス: ${JSON.stringify(json)}`);

  return {
    status: result.status,
    totalCount: Number(result.total_count ?? 0),
    items: result.items ?? [],
  };
}

/**
 * 女優情報取得
 * @param {Object} params - hits, offset, actress_id など
 */
export async function fetchActresses(params = {}) {
  const url = new URL(`${DMM_API_BASE}/ActressSearch`);
  const merged = { ...FIXED_PARAMS, hits: 100, ...params };
  // ActressSearch は service/floor 不要
  delete merged.service;
  delete merged.floor;
  for (const [k, v] of Object.entries(merged)) {
    if (v !== undefined && v !== null && v !== '') url.searchParams.set(k, String(v));
  }

  const res = await fetch(url.toString());
  if (!res.ok) throw new Error(`DMM API error: ${res.status} ${await res.text()}`);
  const json = await res.json();

  const result = json?.result;
  if (!result) throw new Error(`DMM API 不正レスポンス: ${JSON.stringify(json)}`);

  return {
    status: result.status,
    totalCount: Number(result.total_count ?? 0),
    actresses: result.actress ?? [],
  };
}

/**
 * DMM アイテムを products upsert 用レコードに変換
 */
export function itemToProduct(item) {
  const imageInfo = item.imageURL ?? {};
  const sampleImages = item.sampleImageURL?.sample_s ?? [];
  const sampleImagesL = item.sampleImageURL?.sample_l ?? [];
  const review = item.review ?? {};
  const prices = item.prices ?? {};

  // sample_images は単一オブジェクトの場合がある
  const normSampleS = Array.isArray(sampleImages)
    ? sampleImages.map(s => s?.image ?? s)
    : (sampleImages?.image ? [sampleImages.image] : []);
  const normSampleL = Array.isArray(sampleImagesL)
    ? sampleImagesL.map(s => s?.image ?? s)
    : (sampleImagesL?.image ? [sampleImagesL.image] : []);

  // sample_movie_url: 最大サイズを優先
  const sampleMovieUrl = item.sampleMovieURL?.size_720_480
    ?? item.sampleMovieURL?.size_644_414
    ?? item.sampleMovieURL?.size_560_360
    ?? item.sampleMovieURL?.size_476_306
    ?? null;

  // VR判定: content_id プレフィックスが 'vr' または floor が vr
  const currentFloor = FIXED_PARAMS.floor;
  const isVr = currentFloor === 'vr'
    || String(item.content_id ?? '').startsWith('vr')
    || (item.iteminfo?.genre ?? []).some(g => String(g.id) === '6081'); // VRジャンルID

  // 価格
  const priceMin = prices.list ? parseInt(String(prices.list).replace(/[^0-9]/g, ''), 10) || null : null;
  const priceMax = prices.price ? parseInt(String(prices.price).replace(/[^0-9]/g, ''), 10) || null : null;

  return {
    dmm_content_id: item.content_id,
    product_id: item.product_id ?? null,
    title: item.title,
    description: item.comment ?? null,
    volume: item.volume ? parseInt(item.volume, 10) || null : null,
    number: item.number ? parseInt(item.number, 10) || null : null,
    affiliate_url: item.affiliateURL ?? null,
    page_url: item.URL ?? null,
    list_url: item.listURL?.digital ?? item.listURL?.pc ?? null,
    floor: currentFloor,
    is_vr: isVr,
    image_url_list: imageInfo.list ?? null,
    image_url_small: imageInfo.small ?? null,
    image_url_large: imageInfo.large ?? null,
    sample_images_s: normSampleS.filter(Boolean),
    sample_images_l: normSampleL.filter(Boolean),
    sample_movie_url: sampleMovieUrl,
    price_min: priceMin,
    price_max: priceMax,
    price_text: prices.list ? String(prices.list) : null,
    release_date: item.date ? new Date(item.date).toISOString() : null,
    review_count: parseInt(review.count ?? '0', 10) || 0,
    review_average: review.average ? parseFloat(review.average) : null,
    series_id: item.iteminfo?.series?.[0]?.id ? String(item.iteminfo.series[0].id) : null,
    series_name: item.iteminfo?.series?.[0]?.name ?? null,
    maker_id: item.iteminfo?.maker?.[0]?.id ? String(item.iteminfo.maker[0].id) : null,
    maker_name: item.iteminfo?.maker?.[0]?.name ?? null,
    label_id: item.iteminfo?.label?.[0]?.id ? String(item.iteminfo.label[0].id) : null,
    label_name: item.iteminfo?.label?.[0]?.name ?? null,
    director_id: item.iteminfo?.director?.[0]?.id ? String(item.iteminfo.director[0].id) : null,
    director_name: item.iteminfo?.director?.[0]?.name ?? null,
    is_active: true,
    last_seen_at: new Date().toISOString(),
  };
}

/**
 * DMM アイテムからジャンル配列を取得
 */
export function itemToGenres(item) {
  const genres = item.iteminfo?.genre ?? [];
  return genres.map(g => ({
    dmm_genre_id: String(g.id),
    name: g.name,
    slug: String(g.id),  // sync後にローマ字変換スクリプトで更新
  }));
}

/**
 * DMM アイテムから出演女優配列を取得
 */
export function itemToActressIds(item) {
  const actresses = item.iteminfo?.actress ?? [];
  return actresses.map(a => String(a.id));
}

/**
 * 商品APIの iteminfo.actress から最小女優レコード配列を生成
 * （詳細プロフィールは sync-actresses.mjs で後から補完）
 */
export function itemToActresses(item) {
  const actresses = item.iteminfo?.actress ?? [];
  return actresses.map(a => ({
    dmm_actress_id: String(a.id),
    name: a.name,
    ruby: a.ruby ?? null,
    slug: (a.ruby ?? String(a.id)).toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '') || String(a.id),
  }));
}

/**
 * DMM 女優レスポンスを actresses upsert 用レコードに変換
 */
export function actressToRecord(a) {
  return {
    dmm_actress_id: String(a.id),
    name: a.name,
    ruby: a.ruby ?? null,
    slug: (a.ruby ?? String(a.id)).toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '') || String(a.id),
    bust: a.bust ? parseInt(a.bust, 10) || null : null,
    cup: a.cup ?? null,
    waist: a.waist ? parseInt(a.waist, 10) || null : null,
    hip: a.hip ? parseInt(a.hip, 10) || null : null,
    height: a.height ? parseInt(a.height, 10) || null : null,
    birthday: a.birthday ?? null,
    blood_type: a.blood_type ?? null,
    hobby: a.hobby ?? null,
    prefectures: a.prefectures ?? null,
    image_url_small: a.imageURL?.small ?? null,
    image_url_large: a.imageURL?.large ?? null,
    list_url: a.listURL?.digital ?? null,
  };
}
