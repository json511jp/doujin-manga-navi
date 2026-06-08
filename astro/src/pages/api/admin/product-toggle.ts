import type { APIRoute } from 'astro';
import { getAdminClient } from '../../../lib/adminClient';

export const POST: APIRoute = async ({ request, locals }) => {
  if (!locals.adminUser) {
    return new Response('Unauthorized', { status: 401 });
  }

  const { id, field, value }: { id: string; field: 'is_active' | 'is_featured'; value: boolean } = await request.json();

  if (!id || !['is_active', 'is_featured'].includes(field)) {
    return new Response('Bad Request', { status: 400 });
  }

  const client = getAdminClient();
  const { error } = await client.from('products').update({ [field]: value } as { is_active: boolean } | { is_featured: boolean }).eq('id', id);

  if (error) return new Response(error.message, { status: 500 });
  return new Response('OK');
};
