import type { APIRoute } from 'astro';
import { supabase } from '../../lib/supabase';

export const POST: APIRoute = async ({ request }) => {
  try {
    const { target_type, target_id, visitor_id } = await request.json();

    if (!target_type || !target_id || !visitor_id) {
      return new Response(JSON.stringify({ error: 'missing params' }), { status: 400 });
    }
    if (!['product', 'actress'].includes(target_type)) {
      return new Response(JSON.stringify({ error: 'invalid target_type' }), { status: 400 });
    }
    if (visitor_id.length > 64) {
      return new Response(JSON.stringify({ error: 'invalid visitor_id' }), { status: 400 });
    }

    // Check if already liked
    const { data: existing } = await supabase
      .from('likes')
      .select('id')
      .eq('target_type', target_type)
      .eq('target_id', target_id)
      .eq('visitor_id', visitor_id)
      .maybeSingle();

    if (existing) {
      // Unlike
      await supabase.from('likes').delete()
        .eq('target_type', target_type)
        .eq('target_id', target_id)
        .eq('visitor_id', visitor_id);
    } else {
      // Like
      await supabase.from('likes').insert({ target_type, target_id, visitor_id });
    }

    // Get updated count
    const { count } = await supabase
      .from('likes')
      .select('*', { count: 'exact', head: true })
      .eq('target_type', target_type)
      .eq('target_id', target_id);

    return new Response(JSON.stringify({ liked: !existing, count: count ?? 0 }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch {
    return new Response(JSON.stringify({ error: 'server error' }), { status: 500 });
  }
};
