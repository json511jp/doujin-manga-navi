-- ============================================================
-- DMM SEO Kit — 統合初期スキーマ
-- ============================================================
-- このファイルを Supabase SQL エディタで上から順に実行してください。
-- 既存DBへの適用は setup.sh / setup.bat が自動実行します。
-- ============================================================

-- ============================================================
-- 拡張機能
-- ============================================================
CREATE EXTENSION IF NOT EXISTS moddatetime;

-- ============================================================
-- products
-- ============================================================
CREATE TABLE products (
  id               UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  dmm_content_id   TEXT    UNIQUE NOT NULL,
  product_id       TEXT,
  title            TEXT    NOT NULL,
  description      TEXT,
  volume           INT,                          -- 収録時間（分）
  number           INT,
  affiliate_url    TEXT,
  page_url         TEXT,                         -- 商品ページURL
  list_url         TEXT,                         -- 電子書籍 立ち読みURL（ebook系フロア）
  floor            TEXT,                         -- 取得元フロアコード（videoa / anime / ebook/comic 等）
  image_url_list   TEXT,
  image_url_small  TEXT,
  image_url_large  TEXT,
  sample_images_s  TEXT[],
  sample_images_l  TEXT[],
  sample_movie_url TEXT,
  price_min        INT,
  price_max        INT,
  price_text       TEXT,
  release_date     TIMESTAMP,
  review_count     INT     DEFAULT 0,
  review_average   NUMERIC(3,2),
  series_id        TEXT,
  series_name      TEXT,
  maker_id         TEXT,
  maker_name       TEXT,
  label_id         TEXT,
  label_name       TEXT,
  director_id      TEXT,
  director_name    TEXT,
  is_active        BOOLEAN DEFAULT true,
  is_featured      BOOLEAN DEFAULT false,        -- 管理画面でのピックアップ設定
  is_vr            BOOLEAN DEFAULT false,        -- VRコンテンツフラグ
  last_seen_at     TIMESTAMP,
  created_at       TIMESTAMP DEFAULT NOW(),
  updated_at       TIMESTAMP DEFAULT NOW()
);

CREATE INDEX products_release_date_idx        ON products (release_date DESC);
CREATE INDEX products_review_average_idx      ON products (review_average DESC NULLS LAST);
CREATE INDEX products_maker_id_idx            ON products (maker_id);
CREATE INDEX products_series_id_idx           ON products (series_id);
CREATE INDEX products_price_min_idx           ON products (price_min);
CREATE INDEX products_active_release_date_idx ON products (is_active, release_date DESC);
CREATE INDEX products_floor_idx               ON products (floor);
CREATE INDEX products_featured_idx            ON products (is_featured) WHERE is_featured = true;
CREATE INDEX products_vr_idx                  ON products (is_vr)       WHERE is_vr = true;

CREATE TRIGGER set_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

-- ============================================================
-- actresses
-- ============================================================
CREATE TABLE actresses (
  id              UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  dmm_actress_id  TEXT    UNIQUE NOT NULL,
  name            TEXT    NOT NULL,
  ruby            TEXT,
  slug            TEXT    UNIQUE NOT NULL,
  bust            INT,
  cup             TEXT,
  waist           INT,
  hip             INT,
  height          INT,
  birthday        DATE,
  blood_type      TEXT,
  hobby           TEXT,
  prefectures     TEXT,
  image_url_small TEXT,
  image_url_large TEXT,
  list_url        TEXT,
  created_at      TIMESTAMP DEFAULT NOW(),
  updated_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX actresses_name_idx ON actresses (name);
CREATE INDEX actresses_ruby_idx ON actresses (ruby);

CREATE TRIGGER set_actresses_updated_at
  BEFORE UPDATE ON actresses
  FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

-- ============================================================
-- genres
-- ============================================================
CREATE TABLE genres (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dmm_genre_id TEXT UNIQUE NOT NULL,
  name         TEXT NOT NULL,
  slug         TEXT UNIQUE NOT NULL
);

CREATE INDEX genres_name_idx ON genres (name);

-- ============================================================
-- moods
-- ============================================================
CREATE TABLE moods (
  id          UUID   PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT   NOT NULL,
  slug        TEXT   UNIQUE NOT NULL,
  description TEXT,
  genre_ids   TEXT[] NOT NULL DEFAULT '{}'
);

-- ============================================================
-- product_actresses（多対多）
-- ============================================================
CREATE TABLE product_actresses (
  product_id UUID REFERENCES products(id)  ON DELETE CASCADE,
  actress_id UUID REFERENCES actresses(id) ON DELETE CASCADE,
  PRIMARY KEY (product_id, actress_id)
);

CREATE INDEX product_actresses_actress_id_idx ON product_actresses (actress_id);

-- ============================================================
-- product_genres（多対多）
-- ============================================================
CREATE TABLE product_genres (
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
  genre_id   UUID REFERENCES genres(id)   ON DELETE CASCADE,
  PRIMARY KEY (product_id, genre_id)
);

CREATE INDEX product_genres_genre_id_idx ON product_genres (genre_id);

-- ============================================================
-- actress_relations（相関図用・事前計算）
-- ============================================================
CREATE TABLE actress_relations (
  actress_a_id   UUID REFERENCES actresses(id) ON DELETE CASCADE,
  actress_b_id   UUID REFERENCES actresses(id) ON DELETE CASCADE,
  co_appearances INT NOT NULL DEFAULT 0,
  shared_genres  INT NOT NULL DEFAULT 0,
  PRIMARY KEY (actress_a_id, actress_b_id)
);

CREATE INDEX actress_relations_a_idx ON actress_relations (actress_a_id, co_appearances DESC);

-- ============================================================
-- rankings
-- ============================================================
CREATE TABLE rankings (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id    UUID REFERENCES products(id) ON DELETE CASCADE,
  rank_type     TEXT NOT NULL CHECK (rank_type IN ('monthly', 'weekly', 'ntr')),
  rank_position INT  NOT NULL,
  recorded_at   TIMESTAMP DEFAULT NOW()
);

CREATE INDEX rankings_rank_type_position_idx ON rankings (rank_type, rank_position ASC);
CREATE INDEX rankings_product_id_idx         ON rankings (product_id);

-- ============================================================
-- likes
-- ============================================================
CREATE TABLE likes (
  id          UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  target_type TEXT        NOT NULL CHECK (target_type IN ('product', 'actress')),
  target_id   UUID        NOT NULL,
  visitor_id  TEXT        NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX likes_unique  ON likes (target_type, target_id, visitor_id);
CREATE INDEX        likes_target_idx ON likes (target_type, target_id);

-- ============================================================
-- cron_logs
-- ============================================================
CREATE TABLE cron_logs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_name      TEXT NOT NULL,
  status        TEXT NOT NULL CHECK (status IN ('success', 'error')),
  error_message TEXT,
  meta          JSONB,
  executed_at   TIMESTAMP DEFAULT NOW()
);
CREATE INDEX cron_logs_executed_at_idx ON cron_logs (executed_at DESC);
CREATE INDEX cron_logs_job_name_idx    ON cron_logs (job_name);

-- ============================================================
-- admin_settings（管理画面 KVストア）
-- ============================================================
CREATE TABLE admin_settings (
  key        TEXT PRIMARY KEY,
  value      JSONB NOT NULL,
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TRIGGER set_admin_settings_updated_at
  BEFORE UPDATE ON admin_settings
  FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

-- ============================================================
-- Row Level Security
-- ============================================================
ALTER TABLE products          ENABLE ROW LEVEL SECURITY;
ALTER TABLE actresses         ENABLE ROW LEVEL SECURITY;
ALTER TABLE genres            ENABLE ROW LEVEL SECURITY;
ALTER TABLE moods             ENABLE ROW LEVEL SECURITY;
ALTER TABLE rankings          ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_actresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_genres    ENABLE ROW LEVEL SECURITY;
ALTER TABLE actress_relations ENABLE ROW LEVEL SECURITY;
ALTER TABLE likes             ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_settings    ENABLE ROW LEVEL SECURITY;

-- 公開テーブル: anon 読み取り許可
CREATE POLICY "public read" ON products          FOR SELECT TO anon USING (true);
CREATE POLICY "public read" ON actresses         FOR SELECT TO anon USING (true);
CREATE POLICY "public read" ON genres            FOR SELECT TO anon USING (true);
CREATE POLICY "public read" ON moods             FOR SELECT TO anon USING (true);
CREATE POLICY "public read" ON rankings          FOR SELECT TO anon USING (true);
CREATE POLICY "public read" ON product_actresses FOR SELECT TO anon USING (true);
CREATE POLICY "public read" ON product_genres    FOR SELECT TO anon USING (true);
CREATE POLICY "public read" ON actress_relations FOR SELECT TO anon USING (true);

-- likes: anon 読み書き許可
CREATE POLICY "anon can read likes"   ON likes FOR SELECT TO anon USING (true);
CREATE POLICY "anon can insert likes" ON likes FOR INSERT TO anon WITH CHECK (length(visitor_id) > 0 AND length(visitor_id) <= 64);
CREATE POLICY "anon can delete likes" ON likes FOR DELETE TO anon USING (length(visitor_id) > 0);

-- admin_settings: authenticated のみ読み書き可（anon 不可）
CREATE POLICY "admin only" ON admin_settings FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================
-- Grants
-- ============================================================
GRANT SELECT ON products, actresses, genres, moods, rankings,
               product_actresses, product_genres, actress_relations
TO anon;

GRANT SELECT, INSERT, DELETE ON likes TO anon;

-- ============================================================
-- DB関数
-- ============================================================

-- actress_relations 再計算（sync-actresses から呼び出す）
CREATE OR REPLACE FUNCTION recalculate_actress_relations()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM actress_relations;
  INSERT INTO actress_relations (actress_a_id, actress_b_id, co_appearances)
  SELECT
    pa1.actress_id,
    pa2.actress_id,
    COUNT(*) AS co_appearances
  FROM product_actresses pa1
  JOIN product_actresses pa2
    ON pa1.product_id = pa2.product_id
   AND pa1.actress_id < pa2.actress_id
  GROUP BY pa1.actress_id, pa2.actress_id;
END;
$$;

-- rankings 一括置換（sync-rankings から呼び出す）
CREATE OR REPLACE FUNCTION replace_rankings(
  p_rank_type TEXT,
  p_rows      JSONB   -- [{product_id, rank_position}, ...]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM rankings WHERE rank_type = p_rank_type;
  INSERT INTO rankings (product_id, rank_type, rank_position)
  SELECT
    (row->>'product_id')::UUID,
    p_rank_type,
    (row->>'rank_position')::INT
  FROM jsonb_array_elements(p_rows) AS row;
END;
$$;

-- 長期間未更新の商品を非活性化（デフォルト30日）
CREATE OR REPLACE FUNCTION deactivate_stale_products(days INT DEFAULT 30)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  affected INT;
BEGIN
  UPDATE products
  SET is_active = false
  WHERE is_active = true
    AND last_seen_at < NOW() - (days || ' days')::INTERVAL;
  GET DIAGNOSTICS affected = ROW_COUNT;
  RETURN affected;
END;
$$;

-- 未同期女優IDを返す（将来拡張用）
CREATE OR REPLACE FUNCTION get_unsynced_actress_ids()
RETURNS TABLE(dmm_actress_id TEXT)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT NULL::TEXT WHERE false;
$$;

-- ============================================================
-- 初期データ: moods
-- ============================================================
INSERT INTO moods (name, slug, description, genre_ids) VALUES
  ('背徳感が欲しい',       'haitoku',  '禁断の関係・背徳感が楽しめる作品',           ARRAY['1039', '4111', '1069']),
  ('じっくり堕ちていく',   'ochiru',   '快楽堕ち・洗脳・調教など展開を楽しむ作品',   ARRAY['5021', '4001']),
  ('熟女が好き',           'jukujo',   '熟女・人妻・年上女性が登場する作品',         ARRAY['1014', '1039', '524']),
  ('新作を見たい',         'shinsaku', '最近発売された注目の新作',                   ARRAY[]::TEXT[]);

-- ============================================================
-- 初期データ: admin_settings
-- ============================================================
INSERT INTO admin_settings (key, value) VALUES
  ('theme',         '"dark-gold"'),
  ('colors',        '{"background":"#0a0a0a","surface":"#111111","accent":"#d4a843","accentHover":"#f0c060"}'),
  ('custom_css',    '""'),
  ('site_settings', 'null');
