// Edge Function: admin-usuarios
// Permite que um usuário Administrador crie, edite (incluindo e-mail e senha)
// e exclua outros usuários do CRM, sem precisar abrir o painel do Supabase.
//
// Recebe o token de acesso do usuário logado (Authorization: Bearer <token>)
// e usa a chave de service role (somente no servidor) para:
//  - confirmar que quem está chamando é Administrador
//  - criar/editar/excluir o usuário no Supabase Auth
//  - criar/editar/excluir a linha correspondente na tabela "usuarios"
//
// Variáveis de ambiente SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY já existem
// automaticamente em toda Edge Function do Supabase.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' }
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });

  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
    const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    const authHeader = req.headers.get('Authorization') || '';
    const token = authHeader.replace(/^Bearer\s+/i, '');
    if (!token) return json({ error: 'Não autenticado.' }, 401);

    // Cliente "service role": acesso total, ignora RLS — só usado no servidor.
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // Identifica quem está chamando, a partir do token enviado pelo navegador.
    const { data: caller, error: callerErr } = await admin.auth.getUser(token);
    if (callerErr || !caller?.user) return json({ error: 'Sessão inválida.' }, 401);

    // Confirma que quem chamou é Administrador.
    const { data: linhaChamador } = await admin
      .from('usuarios')
      .select('id, grupo_id, grupos(admin)')
      .eq('auth_id', caller.user.id)
      .maybeSingle();

    const ehAdmin = !!(linhaChamador && (linhaChamador as any).grupos?.admin);
    if (!ehAdmin) return json({ error: 'Apenas administradores podem gerenciar usuários.' }, 403);

    const body = await req.json();
    const acao = body.acao;

    if (acao === 'criar') {
      const { email, nome, login, funcao, grupoId, diasLogado, ativo } = body;
      if (!email || !nome || !login) return json({ error: 'Preencha nome, login e e-mail.' }, 400);

      // Cria o usuário no Supabase Auth e envia e-mail de convite (link para definir a senha).
      const { data: novo, error: erroAuth } = await admin.auth.admin.inviteUserByEmail(email, {
        redirectTo: req.headers.get('origin') || undefined
      });
      if (erroAuth) return json({ error: 'Erro ao criar usuário no Auth: ' + erroAuth.message }, 400);

      const { data: linha, error: erroInsert } = await admin
        .from('usuarios')
        .insert({
          auth_id: novo.user.id, email, nome, login, funcao,
          grupo_id: grupoId, dias_logado: diasLogado, ativo
        })
        .select()
        .single();

      if (erroInsert) {
        // se falhar ao salvar no CRM, desfaz a criação no Auth para não ficar órfão
        await admin.auth.admin.deleteUser(novo.user.id);
        return json({ error: 'Erro ao salvar usuário: ' + erroInsert.message }, 400);
      }

      return json({ ok: true, usuario: linha });
    }

    if (acao === 'atualizar') {
      const { id, email, nome, login, funcao, grupoId, diasLogado, ativo, senha } = body;
      if (!id) return json({ error: 'Usuário inválido.' }, 400);

      const { data: existente, error: erroBusca } = await admin
        .from('usuarios').select('*').eq('id', id).maybeSingle();
      if (erroBusca || !existente) return json({ error: 'Usuário não encontrado.' }, 404);

      if (existente.auth_id) {
        const updateAuth: Record<string, unknown> = {};
        if (email && email !== existente.email) { updateAuth.email = email; updateAuth.email_confirm = true; }
        if (senha) updateAuth.password = senha;
        if (Object.keys(updateAuth).length) {
          const { error: erroAuth } = await admin.auth.admin.updateUserById(existente.auth_id, updateAuth);
          if (erroAuth) return json({ error: 'Erro ao atualizar login: ' + erroAuth.message }, 400);
        }
      }

      const { data: linha, error: erroUpdate } = await admin
        .from('usuarios')
        .update({ email, nome, login, funcao, grupo_id: grupoId, dias_logado: diasLogado, ativo })
        .eq('id', id)
        .select()
        .single();
      if (erroUpdate) return json({ error: 'Erro ao salvar usuário: ' + erroUpdate.message }, 400);

      return json({ ok: true, usuario: linha });
    }

    if (acao === 'excluir') {
      const { id } = body;
      if (!id) return json({ error: 'Usuário inválido.' }, 400);

      const { data: existente, error: erroBusca } = await admin
        .from('usuarios').select('*').eq('id', id).maybeSingle();
      if (erroBusca || !existente) return json({ error: 'Usuário não encontrado.' }, 404);

      if (existente.auth_id) {
        const { error: erroAuth } = await admin.auth.admin.deleteUser(existente.auth_id);
        if (erroAuth) return json({ error: 'Erro ao excluir login: ' + erroAuth.message }, 400);
      }

      const { error: erroDelete } = await admin.from('usuarios').delete().eq('id', id);
      if (erroDelete) return json({ error: 'Erro ao excluir usuário: ' + erroDelete.message }, 400);

      return json({ ok: true });
    }

    return json({ error: 'Ação desconhecida.' }, 400);
  } catch (e) {
    return json({ error: 'Erro inesperado: ' + (e instanceof Error ? e.message : String(e)) }, 500);
  }
});
