import type { APIRoute } from 'astro';

const ALLOWED_WORKFLOWS = [
  'sync-products.yml',
  'sync-actresses.yml',
  'sync-rankings.yml',
  'backfill.yml',
  'generate-descriptions.yml',
] as const;

type AllowedWorkflow = typeof ALLOWED_WORKFLOWS[number];

function isAllowedWorkflow(w: string | undefined): w is AllowedWorkflow {
  return !!w && (ALLOWED_WORKFLOWS as readonly string[]).includes(w);
}

export const POST: APIRoute = async ({ request, locals }) => {
  if (!locals.adminUser) {
    return new Response('Unauthorized', { status: 401 });
  }

  const token = import.meta.env.GITHUB_TOKEN;
  const repo  = import.meta.env.GITHUB_REPO;

  if (!token || !repo) {
    return new Response(JSON.stringify({ error: 'GITHUB_TOKEN または GITHUB_REPO が未設定です' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  let body: { workflow?: string; inputs?: Record<string, string> };
  try {
    body = await request.json();
  } catch {
    return new Response('invalid json', { status: 400 });
  }

  const { workflow, inputs = {} } = body;

  if (!isAllowedWorkflow(workflow)) {
    return new Response(JSON.stringify({ error: '不正なワークフロー名です' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const ref = import.meta.env.GITHUB_DEFAULT_BRANCH ?? 'main';
  const url = `https://api.github.com/repos/${repo}/actions/workflows/${workflow}/dispatches`;

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ ref, inputs }),
  });

  if (!res.ok) {
    // 詳細はサーバーログのみに残し、クライアントには汎用メッセージ + ステータスのみ返す
    const detail = await res.text().catch(() => '');
    console.error(`[trigger-workflow] GitHub API ${res.status} for ${workflow}: ${detail}`);

    const clientMessage =
      res.status === 401 || res.status === 403 ? 'GitHub の認証に失敗しました（GITHUB_TOKEN を確認してください）' :
      res.status === 404 ? 'ワークフローまたはリポジトリが見つかりません' :
      res.status === 422 ? 'ワークフローのパラメータが不正です' :
      'GitHub API エラー';

    return new Response(JSON.stringify({ error: `${clientMessage} (HTTP ${res.status})` }), {
      status: res.status,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // 204 No Content が正常レスポンス
  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
};
