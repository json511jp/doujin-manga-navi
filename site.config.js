/**
 * サイト設定ファイル
 * =============================
 * このファイルを編集するだけで、サイト名・テーマ・検索ジャンルを
 * 自分のサイト向けにカスタマイズできます。
 *
 * DMM Web API の site / service / floor パラメータは
 * 下記の公式ドキュメントを参照してください。
 * https://affiliate.dmm.com/api/
 */

export const siteConfig = {
  // -------------------------------------------------------
  // 基本情報
  // -------------------------------------------------------

  /** サイト名（ヘッダー・タイトルタグに使用） */
  siteName: 'DOUJIN MANGA NAVI',

  /** サイトの説明文（meta description のデフォルト） */
  siteDescription: '成人向け同人・漫画の紹介サイト',

  /** 本番ドメイン（sitemap・canonical URL に使用） */
  siteUrl: 'https://doujin-manga-navi.json511jp.workers.dev',

  /** サイトのキャッチコピー（TOPページに表示） */
  tagline: '話題の成人向け同人・漫画をまとめて紹介',

  /** お問い合わせメールアドレス（フッターに表示） */
  contactEmail: 'json511jp@gmail.com',

  // -------------------------------------------------------
  // DMM Web API 設定
  // -------------------------------------------------------

  dmm: {
    /**
     * DMM API の site パラメータ
     * 'FANZA' | 'DMM.co.jp'
     */
    site: 'FANZA',

    /**
     * DMM API の service パラメータ
     * 例: 'digital'（動画）| 'mono'（パッケージ）
     */
    service: 'doujin',

    /**
     * DMM API の floor パラメータ
     * 例: 'videoa'（一般動画）| 'anime'（アニメ）| 'doujin'（同人）
     */
    floor: 'digital_doujin',

    /**
     * 同期時に絞り込むキーワード（空文字で全件取得）
     * 例: '人妻' | 'NTR' | '巨乳' | ''
     */
    keyword: '',
  },

  // -------------------------------------------------------
  // ニッチ特化ランキング設定
  // -------------------------------------------------------

  /**
   * 独自ランキング（3番目のランキングタブ）の設定
   * DMM ジャンルID を指定。複数指定でOR検索になります。
   *
   * ジャンルIDの確認方法:
   * Supabase の genres テーブルから dmm_genre_id を参照
   */
  nicheRanking: {
    /** ランキング名（URLスラッグ・表示名に使用） */
    slug: 'niche',

    /** 表示名 */
    label: 'ニッチランキング',

    /** 対象ジャンルID（OR条件）— Supabase の genres テーブルの dmm_genre_id を参照 */
    genreIds: [],
  },

  // -------------------------------------------------------
  // デザイン設定
  // -------------------------------------------------------

  colors: {
    /** ページ背景色 */
    background: '#0a0a0a',

    /** カード背景色 */
    surface: '#111111',

    /** アクセントカラー（CTAボタン・評価星など） */
    accent: '#d4a843',

    /** アクセントカラー（ホバー時） */
    accentHover: '#f0c060',
  },

  // -------------------------------------------------------
  // ムードUI設定
  // -------------------------------------------------------

  /**
   * TOPページのムードボタン設定
   * DMM ジャンルID との対応を定義します。
   * ジャンルIDは genres テーブルの dmm_genre_id を参照。
   */
  moods: [
    // genreIds は Supabase の genres テーブルの dmm_genre_id を参照して設定してください
    { name: 'ムード1', slug: 'mood1', genreIds: [] },
    { name: 'ムード2', slug: 'mood2', genreIds: [] },
    { name: '新作を見たい', slug: 'newrelease', genreIds: [] },
  ],

  // -------------------------------------------------------
  // UI機能フラグ（フロアに応じて切り替える）
  // -------------------------------------------------------

  /**
   * フロア別プリセット（このコメントを参考に features を設定してください）
   *
   * digital/videoa  (ビデオ)     → actresses:true,  sampleMovie:true,  trialReading:false, duration:true,  director:true,  maker:true,  vrBadge:false
   * digital/videoc  (素人)       → actresses:true,  sampleMovie:true,  trialReading:false, duration:true,  director:false, maker:true,  vrBadge:false
   * digital/nikkatsu(成人映画)   → actresses:true,  sampleMovie:true,  trialReading:false, duration:true,  director:true,  maker:true,  vrBadge:false
   * digital/anime   (アニメ動画) → actresses:false, sampleMovie:true,  trialReading:false, duration:true,  director:false, maker:true,  vrBadge:false
   * monthly/premium (見放題DX)  → actresses:true,  sampleMovie:true,  trialReading:false, duration:true,  director:true,  maker:true,  vrBadge:false
   * monthly/vr      (VRch)      → actresses:true,  sampleMovie:true,  trialReading:false, duration:true,  director:true,  maker:true,  vrBadge:true
   * doujin/*        (同人)       → actresses:false, sampleMovie:false, trialReading:false, duration:false, director:false, maker:false, vrBadge:false
   * ebook/*         (ブックス)   → actresses:false, sampleMovie:false, trialReading:true,  duration:false, director:false, maker:true,  vrBadge:false
   * mono/dvd        (DVD)        → actresses:true,  sampleMovie:false, trialReading:false, duration:true,  director:true,  maker:true,  vrBadge:false
   * mono/goods      (グッズ)     → actresses:false, sampleMovie:false, trialReading:false, duration:false, director:false, maker:true,  vrBadge:false
   * pcgame/*        (PCゲーム)   → actresses:false, sampleMovie:false, trialReading:false, duration:false, director:false, maker:true,  vrBadge:false
   */
  features: {
    /** 女優ページ・作品詳細の出演者情報・ナビの女優リンクを表示 */
    actresses: false,

    /** 作品詳細のサンプル動画プレイヤーを表示 */
    sampleMovie: false,

    /** 電子書籍の立ち読みリンクを表示（ebook系フロア向け） */
    trialReading: false,

    /** 収録時間を表示（動画・DVD向け） */
    duration: false,

    /** 監督情報を表示 */
    director: false,

    /** メーカー・レーベル・シリーズ情報を表示 */
    maker: true,

    /** VRコンテンツバッジを表示（monthly/vr 向け） */
    vrBadge: false,
  },

  // -------------------------------------------------------
  // CTA設定
  // -------------------------------------------------------

  /**
   * 作品詳細ページの購入ボタンテキスト
   * フロアに合わせて変更してください
   * 例: 'FANZAで見る' | 'ブックスで読む' | 'ゲームを購入' | 'DVDを購入'
   */
  ctaLabel: 'FANZAで見る',

  // -------------------------------------------------------
  // アフィリエイト設定
  // -------------------------------------------------------

  affiliate: {
    /** アフィリエイトプログラム名（フッター表記に使用） */
    programName: 'FANZA（DMM）のアフィリエイトプログラム',

    /** 年齢制限（true = 18歳以上対象の表記を表示） */
    ageRestricted: true,
  },
};
