export type Json = string | number | boolean | null | { [key: string]: Json } | Json[];

export interface Database {
  public: {
    Tables: {
      products: {
        Row: {
          id: string;
          dmm_content_id: string;
          product_id: string | null;
          title: string;
          description: string | null;
          volume: number | null;
          number: number | null;
          affiliate_url: string | null;
          page_url: string | null;
          image_url_list: string | null;
          image_url_small: string | null;
          image_url_large: string | null;
          sample_images_s: string[] | null;
          sample_images_l: string[] | null;
          sample_movie_url: string | null;
          price_min: number | null;
          price_max: number | null;
          price_text: string | null;
          release_date: string | null;
          review_count: number;
          review_average: number | null;
          series_id: string | null;
          series_name: string | null;
          maker_id: string | null;
          maker_name: string | null;
          label_id: string | null;
          label_name: string | null;
          director_id: string | null;
          director_name: string | null;
          is_active: boolean;
          is_featured: boolean;
          last_seen_at: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: Omit<Database['public']['Tables']['products']['Row'], 'id' | 'created_at' | 'updated_at'>;
        Update: Partial<Database['public']['Tables']['products']['Insert']>;
        Relationships: [];
      };
      actresses: {
        Row: {
          id: string;
          dmm_actress_id: string;
          name: string;
          ruby: string | null;
          slug: string;
          bust: number | null;
          cup: string | null;
          waist: number | null;
          hip: number | null;
          height: number | null;
          birthday: string | null;
          blood_type: string | null;
          hobby: string | null;
          prefectures: string | null;
          image_url_small: string | null;
          image_url_large: string | null;
          list_url: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: Omit<Database['public']['Tables']['actresses']['Row'], 'id' | 'created_at' | 'updated_at'>;
        Update: Partial<Database['public']['Tables']['actresses']['Insert']>;
        Relationships: [];
      };
      genres: {
        Row: {
          id: string;
          dmm_genre_id: string;
          name: string;
          slug: string;
        };
        Insert: Omit<Database['public']['Tables']['genres']['Row'], 'id'>;
        Update: Partial<Database['public']['Tables']['genres']['Insert']>;
        Relationships: [];
      };
      moods: {
        Row: {
          id: string;
          name: string;
          slug: string;
          description: string | null;
          genre_ids: string[];
        };
        Insert: Omit<Database['public']['Tables']['moods']['Row'], 'id'>;
        Update: Partial<Database['public']['Tables']['moods']['Insert']>;
        Relationships: [];
      };
      product_actresses: {
        Row: { product_id: string; actress_id: string };
        Insert: Database['public']['Tables']['product_actresses']['Row'];
        Update: Partial<Database['public']['Tables']['product_actresses']['Row']>;
        Relationships: [];
      };
      product_genres: {
        Row: { product_id: string; genre_id: string };
        Insert: Database['public']['Tables']['product_genres']['Row'];
        Update: Partial<Database['public']['Tables']['product_genres']['Row']>;
        Relationships: [];
      };
      actress_relations: {
        Row: {
          actress_a_id: string;
          actress_b_id: string;
          co_appearances: number;
          shared_genres: number;
        };
        Insert: Database['public']['Tables']['actress_relations']['Row'];
        Update: Partial<Database['public']['Tables']['actress_relations']['Row']>;
        Relationships: [];
      };
      rankings: {
        Row: {
          id: string;
          product_id: string;
          rank_type: 'monthly' | 'weekly' | 'ntr';
          rank_position: number;
          recorded_at: string;
        };
        Insert: Omit<Database['public']['Tables']['rankings']['Row'], 'id' | 'recorded_at'>;
        Update: Partial<Database['public']['Tables']['rankings']['Insert']>;
        Relationships: [];
      };
      likes: {
        Row: {
          id: string;
          target_type: 'product' | 'actress';
          target_id: string;
          visitor_id: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          target_type: 'product' | 'actress';
          target_id: string;
          visitor_id: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          target_type?: 'product' | 'actress';
          target_id?: string;
          visitor_id?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      cron_logs: {
        Row: {
          id: string;
          job_name: string;
          status: 'success' | 'error';
          error_message: string | null;
          meta: Json | null;
          executed_at: string | null;
        };
        Insert: {
          id?: string;
          job_name: string;
          status: 'success' | 'error';
          error_message?: string | null;
          meta?: Json | null;
          executed_at?: string | null;
        };
        Update: {
          id?: string;
          job_name?: string;
          status?: 'success' | 'error';
          error_message?: string | null;
          meta?: Json | null;
          executed_at?: string | null;
        };
        Relationships: [];
      };
      admin_settings: {
        Row: {
          key: string;
          value: Json;
          updated_at: string | null;
        };
        Insert: {
          key: string;
          value: Json;
          updated_at?: string | null;
        };
        Update: {
          key?: string;
          value?: Json;
          updated_at?: string | null;
        };
        Relationships: [];
      };
    };
    Views: Record<string, never>;
    Functions: Record<string, never>;
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
}
