-- ============================================================================
-- Schema atual do projeto Supabase "Inovattive CRM" (bazoyvccbxtjwfbldvuz)
-- Gerado por introspecção do banco AO VIVO em 2026-07-23 (via list_tables/execute_sql).
--
-- Este arquivo SUBSTITUI a versão anterior, que só tinha as 14 tabelas da
-- migração inicial (empresa, fases_crm, fases_proposta, origens, funcoes,
-- grupos, usuarios, clientes, obras, cards, card_historico, propostas,
-- proposta_itens, proposta_arquivos) — o banco real já tinha 52 tabelas,
-- criadas ao longo do projeto via SQL direto (execute_sql/apply_migration),
-- nunca salvo de volta aqui. Este dump cobre TODAS as 52.
--
-- Objetivo: referência/backup para reconstrução em caso de perda do projeto
-- Supabase — não é testado como script de setup do zero (sequences dos IDs
-- não estão incluídas explicitamente; Postgres as cria a partir do `nextval`
-- nos defaults abaixo, mas os valores atuais de cada sequence não são
-- capturados aqui). Storage buckets e Edge Functions estão listados no fim,
-- mas não recriados por este script.
--
-- Não versionar dados (rows) aqui — só estrutura.
-- ============================================================================


-- ── FUNÇÕES DE PERMISSÃO (usadas dentro das policies de RLS abaixo) ────────
-- SECURITY DEFINER é intencional nas três: rodam com o dono do schema pra
-- poder ler usuarios/grupos mesmo quando o RLS dessas tabelas restringiria o
-- usuário que está chamando — é o padrão recomendado pelo Supabase pra esse
-- tipo de helper (evita recursão/bloqueio de RLS dentro da própria checagem
-- de RLS). NÃO trocar para SECURITY INVOKER.

create or replace function public.usuario_ativo()
returns boolean
language sql
security definer
set search_path = public
as $$
  select coalesce(
    (select coalesce(ativo, true) from public.usuarios where auth_id = auth.uid()),
    false
  );
$$;

create or replace function public.sou_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select coalesce(
    (select g.admin and coalesce(u.ativo, true)
     from public.usuarios u
     join public.grupos g on g.id = u.grupo_id
     where u.auth_id = auth.uid()),
    false
  );
$$;

create or replace function public.bloquear_autopromocao_usuario()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.sou_admin() then
    if new.grupo_id is distinct from old.grupo_id then
      raise exception 'Apenas administradores podem alterar o grupo de um usuário.';
    end if;
    if new.ativo is distinct from old.ativo then
      raise exception 'Apenas administradores podem ativar/desativar um usuário.';
    end if;
  end if;
  return new;
end;
$$;


-- ── TABELAS ─────────────────────────────────────────────────────────────────

create table public.audit_logs (
  id bigint not null,
  user_id bigint,
  user_nome text not null,
  acao text not null,
  entidade text not null,
  entidade_id text,
  descricao text not null,
  created_at timestamp with time zone default now()
);

create table public.card_contatos (
  id bigint not null,
  card_id bigint not null,
  nome text not null,
  funcao text,
  tel text
);

create table public.card_historico (
  id bigint not null,
  card_id bigint,
  data timestamp with time zone,
  texto text not null
);

create table public.cards (
  id bigint not null,
  num integer not null,
  cliente_id bigint,
  obra_id bigint,
  origem_id bigint,
  fase_id bigint,
  responsavel text,
  agenda timestamp with time zone,
  valor numeric(14,2) default 0,
  perdido boolean default false,
  concluido boolean default false,
  created_at timestamp with time zone default now(),
  google_event_id text,
  responsavel_id integer
);

create table public.cards_srm (
  id integer not null default nextval('cards_srm_id_seq'::regclass),
  num integer not null,
  fornecedor_id integer,
  fase_id integer,
  responsavel text not null default ''::text,
  descricao text not null default ''::text,
  data_abertura date not null default CURRENT_DATE,
  encerrado boolean not null default false,
  cancelado boolean not null default false,
  historico jsonb not null default '[]'::jsonb,
  centro_custo_id integer,
  obra_id integer,
  pagamento_responsavel text not null default 'empresa'::text,
  fatura_direta boolean not null default false
);

create table public.categorias_outros_custos (
  id integer not null default nextval('categorias_outros_custos_id_seq'::regclass),
  nome text not null,
  emoji text not null default '📦'::text,
  ordem integer not null default 0
);

create table public.centros_custo (
  id bigint not null,
  nome text not null,
  descricao text,
  tipo text not null default 'fixo'::text,
  ativo boolean not null default true,
  created_at timestamp with time zone default now(),
  slug text,
  protegido boolean not null default false
);

create table public.clientes (
  id bigint not null,
  nome text not null,
  tel text,
  email text,
  cidade text,
  endereco jsonb default '{}'::jsonb,
  cnpj_cpf text
);

create table public.contas_correntes (
  id bigint not null,
  nome text not null,
  banco text,
  agencia text,
  conta text,
  tipo text not null default 'corrente'::text,
  saldo_inicial numeric(12,2) not null default 0,
  ativo boolean not null default true,
  created_at timestamp with time zone default now(),
  limite numeric(12,2),
  dia_fechamento integer,
  dia_vencimento_fatura integer,
  fatura_inicial numeric default 0,
  ocultar_painel boolean not null default false,
  eh_provisao_impostos boolean not null default false,
  eh_conta_sistema boolean not null default false
);

create table public.contas_pagar (
  id bigint not null,
  descricao text not null default ''::text,
  fornecedor text,
  valor numeric(12,2) not null default 0,
  data_vencimento date,
  data_pagamento date,
  status text not null default 'pendente'::text,
  centro_custo_id bigint,
  obra_id bigint,
  os_id bigint,
  conta_id bigint,
  observacao text,
  created_at timestamp with time zone default now(),
  fornecedor_id bigint,
  condicao text,
  recorrente_id bigint,
  card_srm_id integer,
  guia_tributos_id bigint,
  valor_pago numeric default 0
);

create table public.contas_pagar_pagamentos (
  id bigint not null,
  conta_pagar_id bigint not null,
  data date not null,
  valor numeric not null,
  conta_id bigint,
  movimentacao_id bigint,
  created_at timestamp with time zone not null default now()
);

create table public.contas_recorrentes (
  id bigint not null default nextval('contas_recorrentes_id_seq'::regclass),
  nome text not null,
  fornecedor_id bigint,
  centro_custo_id bigint,
  obra_id bigint,
  valor numeric(12,2) not null default 0,
  dia_vencimento integer not null default 10,
  ativa boolean not null default true,
  criado_em timestamp with time zone default now(),
  conta_id bigint,
  periodicidade text not null default 'mensal'::text,
  mes_vencimento smallint,
  ativada_em timestamp with time zone
);

create table public.download_arquivos (
  id text not null,
  categoria_id bigint,
  nome text not null,
  descricao text default ''::text,
  storage_path text not null,
  tamanho bigint default 0,
  criado_em timestamp with time zone default now(),
  criado_por text default ''::text
);

create table public.download_categorias (
  id bigint not null,
  nome text not null,
  ordem integer default 0
);

create table public.empresa (
  id bigint not null,
  razao text default ''::text,
  fantasia text default ''::text,
  cnpj text default ''::text,
  ie text default ''::text,
  tel text default ''::text,
  email text default ''::text,
  site text default ''::text,
  logo text default ''::text,
  endereco jsonb default '{}'::jsonb,
  log_retencao_dias integer default 90,
  aliquota_tributos numeric default 6,
  aliquota_tributos_produto numeric not null default 6,
  aliquota_tributos_servico numeric not null default 6,
  garantia_servico_obra_meses integer not null default 12,
  garantia_servico_os_avulsa_meses integer not null default 12
);

create table public.estoque_categorias (
  id integer not null default nextval('estoque_categorias_id_seq'::regclass),
  nome text not null,
  cor text not null default '#9e9e9e'::text,
  ordem integer not null default 0
);

create table public.estoque_movimentacoes (
  id integer not null default nextval('estoque_movimentacoes_id_seq'::regclass),
  produto_id integer not null,
  tipo text not null,
  quantidade numeric not null,
  valor_unitario numeric,
  data date not null,
  srm_cotacao_id integer,
  nf_item_idx integer,
  obra_id integer,
  observacao text,
  criado_em timestamp with time zone not null default now(),
  criado_por text,
  os_id integer
);

create table public.estoque_produtos (
  id integer not null default nextval('estoque_produtos_id_seq'::regclass),
  nome text not null,
  nome_fiscal text,
  ncm text,
  unidade text not null default 'un'::text,
  descricao text,
  ativo boolean not null default true,
  criado_em timestamp with time zone not null default now(),
  categoria_id integer,
  garantia_ativa boolean not null default false,
  garantia_classe_id bigint
);

create table public.fases_crm (
  id bigint not null,
  nome text not null,
  cor text not null,
  ordem integer not null,
  tipo text
);

create table public.fases_faturamento (
  id integer not null,
  nome text not null,
  cor text not null default '#9e9e9e'::text,
  ordem integer not null default 0,
  tipo text
);

create table public.fases_obra (
  id integer not null default nextval('fases_obra_id_seq'::regclass),
  nome text not null,
  cor text not null default '#607d8b'::text,
  ordem integer not null default 0,
  tipo text
);

create table public.fases_os (
  id integer not null default nextval('fases_os_id_seq'::regclass),
  nome text not null,
  cor text not null default '#607d8b'::text,
  ordem integer not null default 0,
  tipo text
);

create table public.fases_proposta (
  id bigint not null,
  nome text not null,
  cor text not null,
  ordem integer not null,
  tipo text
);

create table public.fases_srm (
  id integer not null default nextval('fases_srm_id_seq'::regclass),
  nome text not null,
  cor text not null default '#9e9e9e'::text,
  ordem integer not null default 0,
  tipo text
);

create table public.faturamento_itens (
  id bigint not null,
  nota_fiscal_id bigint not null,
  tipo text not null,
  os_id bigint,
  proposta_id bigint,
  proposta_idx integer,
  descricao text,
  quantidade numeric,
  valor_unitario numeric,
  valor_total numeric,
  criado_em timestamp with time zone default now(),
  produto_estoque_id bigint
);

create table public.financeiro_recebimentos (
  id bigint not null,
  card_id bigint,
  proposta_id bigint,
  os_id bigint,
  descricao text not null,
  valor numeric(12,2) not null default 0,
  tipo text not null default 'fixo'::text,
  data_vencimento date,
  condicao text,
  status text not null default 'pendente'::text,
  data_recebimento date,
  created_at timestamp with time zone default now(),
  valor_pago numeric not null default 0
);

create table public.financeiro_recebimentos_pagamentos (
  id bigint not null,
  recebimento_id bigint not null,
  data date not null,
  valor numeric not null,
  conta_id bigint,
  movimentacao_id bigint,
  created_at timestamp with time zone not null default now()
);

create table public.fornecedor_contatos (
  id bigint not null,
  fornecedor_id bigint not null,
  nome text not null default ''::text,
  cargo text,
  telefone text,
  email text,
  created_at timestamp with time zone default now()
);

create table public.fornecedores (
  id bigint not null,
  nome text not null default ''::text,
  cnpj_cpf text,
  telefone text,
  email text,
  logradouro text,
  numero text,
  complemento text,
  bairro text,
  cidade text,
  estado character(2),
  cep text,
  observacao text,
  ativo boolean not null default true,
  created_at timestamp with time zone default now(),
  nome_fantasia text
);

create table public.funcoes (
  id bigint not null,
  nome text not null
);

create table public.garantia_classes (
  id bigint not null,
  nome text not null,
  meses integer not null,
  ordem integer not null default 0
);

create table public.grupos (
  id bigint not null,
  nome text not null,
  admin boolean not null default false,
  telas text[] not null default '{}'::text[],
  recursos text[] not null default '{}'::text[],
  fases_permitidas jsonb,
  filtrar_os boolean not null default false,
  acesso_comercial boolean not null default false,
  acesso_tecnico boolean not null default false,
  recursos_editar jsonb,
  telas_nivel jsonb default '{}'::jsonb,
  filtrar_propostas boolean default false,
  notificacoes_categorias jsonb,
  filtrar_obras boolean not null default false,
  filtrar_cards boolean not null default false
);

create table public.guias_tributos (
  id bigint not null,
  data_recebimento date,
  observacoes text,
  valor_total numeric not null default 0,
  status text not null default 'aberta'::text,
  contas_pagar_id bigint,
  criado_em timestamp with time zone default now(),
  numero text
);

create table public.movimentacoes_financeiras (
  id bigint not null,
  conta_id bigint not null,
  tipo text not null default 'entrada'::text,
  valor numeric(12,2) not null default 0,
  descricao text not null default ''::text,
  data_movimento date not null,
  centro_custo_id bigint,
  origem_tipo text default 'manual'::text,
  origem_id bigint,
  conta_destino_id bigint,
  created_at timestamp with time zone default now(),
  obra_id bigint
);

create table public.notas_fiscais (
  id integer not null,
  numero text not null default ''::text,
  obra_id integer,
  fase_id integer,
  valor numeric not null default 0,
  impostos_retidos numeric not null default 0,
  data_emissao date,
  observacoes text not null default ''::text,
  card_id bigint,
  produto_numero text,
  produto_data date,
  produto_valor numeric,
  produto_pdf_path text,
  produto_pdf_nome text,
  produto_xls_path text,
  produto_xls_nome text,
  servico_numero text,
  servico_data date,
  servico_valor numeric,
  servico_pdf_path text,
  servico_pdf_nome text,
  servico_xls_path text,
  servico_xls_nome text,
  incluir_previsao_impostos boolean not null default true,
  imposto_real numeric,
  guia_tributos_id bigint,
  criado_em timestamp with time zone not null default now()
);

create table public.notificacoes (
  id bigint not null,
  categoria text not null,
  titulo text not null,
  descricao text,
  entidade text,
  entidade_id text,
  created_at timestamp with time zone not null default now()
);

-- LEGADO — ver nota no cabeçalho do arquivo e no comentário em omni-desktop.html
-- (db.obraRetiradas / carregarDadosSupabase): o app parou de ler/escrever nessas
-- duas tabelas desde a v1.47.15/16 ("Obra→Compras" virou visualização do SRM).
-- Continuam no banco só como histórico congelado de antes da migração.
create table public.obra_compras (
  id bigint not null,
  obra_id bigint,
  card_id bigint,
  fornecedor text not null default ''::text,
  numero_pedido text default ''::text,
  data_pedido date,
  valor_pedido numeric(12,2),
  descricao text default ''::text,
  status text not null default 'pendente'::text,
  pdf_path text default ''::text,
  pdf_nome text default ''::text,
  created_at timestamp with time zone default now()
);

create table public.obra_contatos (
  id integer not null default nextval('obra_contatos_id_seq'::regclass),
  obra_id integer not null,
  nome text not null,
  funcao text not null default ''::text,
  tel text not null default ''::text
);

create table public.obra_equipamentos (
  id bigint not null,
  obra_id bigint not null,
  equipamento text not null,
  login text,
  senha text,
  observacao text,
  created_at timestamp with time zone default now(),
  arquivos jsonb default '[]'::jsonb
);

-- LEGADO — ver nota acima em obra_compras.
create table public.obra_nfs (
  id bigint not null,
  compra_id bigint,
  obra_id bigint,
  numero_nf text default ''::text,
  fornecedor text default ''::text,
  valor_nf numeric(12,2),
  data_nf date,
  pdf_path text default ''::text,
  pdf_nome text default ''::text,
  created_at timestamp with time zone default now()
);

create table public.obra_retiradas (
  id bigint not null default nextval('obra_retiradas_id_seq'::regclass),
  obra_id bigint not null,
  data_retirada date not null,
  valor numeric(12,2) not null,
  descricao text,
  status text not null default 'registrada'::text,
  created_at timestamp with time zone not null default now(),
  cp_id bigint
);

create table public.obras (
  id bigint not null,
  cliente_id bigint,
  nome text not null,
  endereco jsonb default '{}'::jsonb,
  fase_id integer,
  status text not null default 'ativa'::text,
  outros_custos jsonb default '[]'::jsonb,
  concluida_em date
);

create table public.ordens_servico (
  id integer not null,
  numero text not null,
  card_id integer,
  cliente_id integer,
  obra_id integer,
  tipo text not null default 'avaliacao'::text,
  fase_id integer,
  titulo text not null default ''::text,
  responsavel_id integer,
  data_agend date,
  data_inicio timestamp with time zone,
  data_termino timestamp with time zone,
  fechada boolean not null default false,
  imagens jsonb not null default '[]'::jsonb,
  produtos jsonb not null default '[]'::jsonb,
  pendencias jsonb not null default '[]'::jsonb,
  historico jsonb not null default '[]'::jsonb,
  arquivos_arquiteto jsonb not null default '[]'::jsonb,
  arquivos_projeto jsonb not null default '[]'::jsonb,
  fase_obra_id integer,
  itens_trabalho jsonb not null default '[]'::jsonb,
  custo_mo jsonb,
  instrucoes text,
  descricao_chamado text,
  tipo_atendimento text,
  google_event_id text,
  resultado_cp_id bigint
);

create table public.origens (
  id bigint not null,
  nome text not null
);

create table public.os_custos (
  id bigint not null,
  os_id bigint not null,
  descricao text not null,
  valor numeric(12,2) not null default 0,
  data date,
  centro_custo_id bigint,
  created_at timestamp with time zone not null default now(),
  cp_id bigint
);

create table public.os_diario (
  id integer not null default nextval('os_diario_id_seq'::regclass),
  os_id integer not null,
  data date not null default CURRENT_DATE,
  autor_id integer,
  descricao text not null default ''::text,
  imagens jsonb not null default '[]'::jsonb
);

create table public.os_itens_trabalho (
  id integer not null default nextval('os_itens_trabalho_id_seq'::regclass),
  os_id integer not null,
  proposta_item_id bigint not null
);

create table public.os_tecnicos (
  id integer not null default nextval('os_tecnicos_id_seq'::regclass),
  os_id integer not null,
  usuario_id integer not null
);

create table public.proposta_arquivos (
  id text not null,
  proposta_id bigint,
  nome text not null,
  storage_path text not null
);

create table public.proposta_itens (
  id bigint not null,
  proposta_id bigint,
  item text,
  descricao text,
  qtd numeric,
  unit numeric(14,2),
  total numeric(14,2),
  tipo text,
  categoria text,
  cliente_fornece boolean default false,
  produto_estoque_id integer
);

create table public.propostas (
  id bigint not null,
  numero text not null,
  card_id bigint,
  cliente_id bigint,
  obra_id bigint,
  data_emissao date,
  valor numeric(14,2) default 0,
  validade_dias integer default 10,
  fase_id bigint,
  status text not null default 'emitida'::text,
  aditivo boolean default false,
  data_aprovacao date,
  fase_anterior bigint
);

create table public.srm_cotacoes (
  id integer not null default nextval('srm_cotacoes_id_seq'::regclass),
  card_srm_id integer not null,
  fornecedor_id integer,
  descricao text not null default ''::text,
  valor numeric(14,2),
  data_recebimento date,
  status text not null default 'recebida'::text,
  observacao text,
  arquivos jsonb not null default '[]'::jsonb,
  xml_nf_path text,
  xml_nf_nome text,
  nf_itens jsonb,
  nf_numero text,
  nf_data date,
  nf_valor_total numeric(12,2),
  nf_emit_cnpj text,
  nf_emit_nome text,
  pdf_nf_path text,
  pdf_nf_nome text,
  estoque_lancado boolean not null default false,
  estoque_lancado_em timestamp with time zone,
  nf_itens_origem text
);

create table public.usuarios (
  id bigint not null,
  auth_id uuid,
  nome text not null,
  login text not null,
  funcao text,
  grupo_id bigint,
  dias_logado integer default 30,
  ativo boolean default true,
  email text,
  google_refresh_token text
);


-- ── PRIMARY KEYS ─────────────────────────────────────────────────────────────

alter table public.audit_logs add constraint audit_logs_pkey primary key (id);
alter table public.card_contatos add constraint card_contatos_pkey primary key (id);
alter table public.card_historico add constraint card_historico_pkey primary key (id);
alter table public.cards add constraint cards_pkey primary key (id);
alter table public.cards_srm add constraint cards_srm_pkey primary key (id);
alter table public.categorias_outros_custos add constraint categorias_outros_custos_pkey primary key (id);
alter table public.centros_custo add constraint centros_custo_pkey primary key (id);
alter table public.clientes add constraint clientes_pkey primary key (id);
alter table public.contas_correntes add constraint contas_correntes_pkey primary key (id);
alter table public.contas_pagar add constraint contas_pagar_pkey primary key (id);
alter table public.contas_pagar_pagamentos add constraint contas_pagar_pagamentos_pkey primary key (id);
alter table public.contas_recorrentes add constraint contas_recorrentes_pkey primary key (id);
alter table public.download_arquivos add constraint download_arquivos_pkey primary key (id);
alter table public.download_categorias add constraint download_categorias_pkey primary key (id);
alter table public.empresa add constraint empresa_pkey primary key (id);
alter table public.estoque_categorias add constraint estoque_categorias_pkey primary key (id);
alter table public.estoque_movimentacoes add constraint estoque_movimentacoes_pkey primary key (id);
alter table public.estoque_produtos add constraint estoque_produtos_pkey primary key (id);
alter table public.fases_crm add constraint fases_crm_pkey primary key (id);
alter table public.fases_faturamento add constraint fases_faturamento_pkey primary key (id);
alter table public.fases_obra add constraint fases_obra_pkey primary key (id);
alter table public.fases_os add constraint fases_os_pkey primary key (id);
alter table public.fases_proposta add constraint fases_proposta_pkey primary key (id);
alter table public.fases_srm add constraint fases_srm_pkey primary key (id);
alter table public.faturamento_itens add constraint faturamento_itens_pkey primary key (id);
alter table public.financeiro_recebimentos add constraint financeiro_recebimentos_pkey primary key (id);
alter table public.financeiro_recebimentos_pagamentos add constraint financeiro_recebimentos_pagamentos_pkey primary key (id);
alter table public.fornecedor_contatos add constraint fornecedor_contatos_pkey primary key (id);
alter table public.fornecedores add constraint fornecedores_pkey primary key (id);
alter table public.funcoes add constraint funcoes_pkey primary key (id);
alter table public.garantia_classes add constraint garantia_classes_pkey primary key (id);
alter table public.grupos add constraint grupos_pkey primary key (id);
alter table public.guias_tributos add constraint guias_tributos_pkey primary key (id);
alter table public.movimentacoes_financeiras add constraint movimentacoes_financeiras_pkey primary key (id);
alter table public.notas_fiscais add constraint notas_fiscais_pkey primary key (id);
alter table public.notificacoes add constraint notificacoes_pkey primary key (id);
alter table public.obra_compras add constraint obra_compras_pkey primary key (id);
alter table public.obra_contatos add constraint obra_contatos_pkey primary key (id);
alter table public.obra_equipamentos add constraint obra_equipamentos_pkey primary key (id);
alter table public.obra_nfs add constraint obra_nfs_pkey primary key (id);
alter table public.obra_retiradas add constraint obra_retiradas_pkey primary key (id);
alter table public.obras add constraint obras_pkey primary key (id);
alter table public.ordens_servico add constraint ordens_servico_pkey primary key (id);
alter table public.origens add constraint origens_pkey primary key (id);
alter table public.os_custos add constraint os_custos_pkey primary key (id);
alter table public.os_diario add constraint os_diario_pkey primary key (id);
alter table public.os_itens_trabalho add constraint os_itens_trabalho_pkey primary key (id);
alter table public.os_tecnicos add constraint os_tecnicos_pkey primary key (id);
alter table public.proposta_arquivos add constraint proposta_arquivos_pkey primary key (id);
alter table public.proposta_itens add constraint proposta_itens_pkey primary key (id);
alter table public.propostas add constraint propostas_pkey primary key (id);
alter table public.srm_cotacoes add constraint srm_cotacoes_pkey primary key (id);
alter table public.usuarios add constraint usuarios_pkey primary key (id);


-- ── FOREIGN KEYS ─────────────────────────────────────────────────────────────

alter table public.audit_logs add constraint audit_logs_user_id_fkey foreign key (user_id) references public.usuarios(id) on delete set null;
alter table public.card_contatos add constraint card_contatos_card_id_fkey foreign key (card_id) references public.cards(id) on delete cascade;
alter table public.card_historico add constraint card_historico_card_id_fkey foreign key (card_id) references public.cards(id) on delete cascade;
alter table public.cards add constraint cards_responsavel_id_fkey foreign key (responsavel_id) references public.usuarios(id);
alter table public.cards add constraint cards_obra_id_fkey foreign key (obra_id) references public.obras(id) on delete set null;
alter table public.cards add constraint cards_fase_id_fkey foreign key (fase_id) references public.fases_crm(id);
alter table public.cards add constraint cards_cliente_id_fkey foreign key (cliente_id) references public.clientes(id);
alter table public.cards add constraint cards_origem_id_fkey foreign key (origem_id) references public.origens(id);
alter table public.cards_srm add constraint cards_srm_obra_id_fkey foreign key (obra_id) references public.obras(id) on delete set null;
alter table public.cards_srm add constraint cards_srm_centro_custo_id_fkey foreign key (centro_custo_id) references public.centros_custo(id) on delete set null;
alter table public.cards_srm add constraint cards_srm_fornecedor_id_fkey foreign key (fornecedor_id) references public.fornecedores(id) on delete set null;
alter table public.cards_srm add constraint cards_srm_fase_id_fkey foreign key (fase_id) references public.fases_srm(id) on delete set null;
alter table public.contas_pagar add constraint contas_pagar_fornecedor_id_fkey foreign key (fornecedor_id) references public.fornecedores(id) on delete set null;
alter table public.contas_pagar add constraint contas_pagar_conta_id_fkey foreign key (conta_id) references public.contas_correntes(id) on delete set null;
alter table public.contas_pagar add constraint contas_pagar_os_id_fkey foreign key (os_id) references public.ordens_servico(id) on delete set null;
alter table public.contas_pagar add constraint contas_pagar_obra_id_fkey foreign key (obra_id) references public.obras(id) on delete set null;
alter table public.contas_pagar add constraint contas_pagar_centro_custo_id_fkey foreign key (centro_custo_id) references public.centros_custo(id) on delete set null;
alter table public.contas_pagar add constraint contas_pagar_card_srm_id_fkey foreign key (card_srm_id) references public.cards_srm(id) on delete set null;
alter table public.contas_pagar add constraint contas_pagar_recorrente_id_fkey foreign key (recorrente_id) references public.contas_recorrentes(id) on delete set null;
alter table public.contas_pagar_pagamentos add constraint contas_pagar_pagamentos_conta_pagar_id_fkey foreign key (conta_pagar_id) references public.contas_pagar(id) on delete cascade;
alter table public.contas_pagar_pagamentos add constraint contas_pagar_pagamentos_conta_id_fkey foreign key (conta_id) references public.contas_correntes(id);
alter table public.contas_recorrentes add constraint contas_recorrentes_conta_id_fkey foreign key (conta_id) references public.contas_correntes(id) on delete set null;
alter table public.contas_recorrentes add constraint contas_recorrentes_fornecedor_id_fkey foreign key (fornecedor_id) references public.fornecedores(id) on delete set null;
alter table public.contas_recorrentes add constraint contas_recorrentes_obra_id_fkey foreign key (obra_id) references public.obras(id) on delete set null;
alter table public.contas_recorrentes add constraint contas_recorrentes_centro_custo_id_fkey foreign key (centro_custo_id) references public.centros_custo(id) on delete set null;
alter table public.download_arquivos add constraint download_arquivos_categoria_id_fkey foreign key (categoria_id) references public.download_categorias(id) on delete cascade;
alter table public.estoque_movimentacoes add constraint estoque_movimentacoes_produto_id_fkey foreign key (produto_id) references public.estoque_produtos(id);
alter table public.estoque_movimentacoes add constraint estoque_movimentacoes_os_id_fkey foreign key (os_id) references public.ordens_servico(id) on delete set null;
alter table public.estoque_movimentacoes add constraint estoque_movimentacoes_srm_cotacao_id_fkey foreign key (srm_cotacao_id) references public.srm_cotacoes(id);
alter table public.estoque_movimentacoes add constraint estoque_movimentacoes_obra_id_fkey foreign key (obra_id) references public.obras(id);
alter table public.estoque_produtos add constraint estoque_produtos_garantia_classe_id_fkey foreign key (garantia_classe_id) references public.garantia_classes(id) on delete set null;
alter table public.estoque_produtos add constraint estoque_produtos_categoria_id_fkey foreign key (categoria_id) references public.estoque_categorias(id) on delete set null;
alter table public.faturamento_itens add constraint faturamento_itens_nota_fiscal_id_fkey foreign key (nota_fiscal_id) references public.notas_fiscais(id) on delete cascade;
alter table public.faturamento_itens add constraint faturamento_itens_produto_estoque_id_fkey foreign key (produto_estoque_id) references public.estoque_produtos(id);
alter table public.faturamento_itens add constraint faturamento_itens_proposta_id_fkey foreign key (proposta_id) references public.propostas(id);
alter table public.faturamento_itens add constraint faturamento_itens_os_id_fkey foreign key (os_id) references public.ordens_servico(id);
alter table public.financeiro_recebimentos add constraint financeiro_recebimentos_proposta_id_fkey foreign key (proposta_id) references public.propostas(id) on delete set null;
alter table public.financeiro_recebimentos add constraint financeiro_recebimentos_os_id_fkey foreign key (os_id) references public.ordens_servico(id) on delete set null;
alter table public.financeiro_recebimentos add constraint financeiro_recebimentos_card_id_fkey foreign key (card_id) references public.cards(id) on delete cascade;
alter table public.financeiro_recebimentos_pagamentos add constraint financeiro_recebimentos_pagamentos_recebimento_id_fkey foreign key (recebimento_id) references public.financeiro_recebimentos(id) on delete cascade;
alter table public.financeiro_recebimentos_pagamentos add constraint financeiro_recebimentos_pagamentos_conta_id_fkey foreign key (conta_id) references public.contas_correntes(id) on delete set null;
alter table public.fornecedor_contatos add constraint fornecedor_contatos_fornecedor_id_fkey foreign key (fornecedor_id) references public.fornecedores(id) on delete cascade;
alter table public.movimentacoes_financeiras add constraint movimentacoes_financeiras_centro_custo_id_fkey foreign key (centro_custo_id) references public.centros_custo(id) on delete set null;
alter table public.movimentacoes_financeiras add constraint movimentacoes_financeiras_conta_destino_id_fkey foreign key (conta_destino_id) references public.contas_correntes(id);
alter table public.movimentacoes_financeiras add constraint movimentacoes_financeiras_obra_id_fkey foreign key (obra_id) references public.obras(id) on delete set null;
alter table public.movimentacoes_financeiras add constraint movimentacoes_financeiras_conta_id_fkey foreign key (conta_id) references public.contas_correntes(id);
alter table public.notas_fiscais add constraint notas_fiscais_fase_id_fkey foreign key (fase_id) references public.fases_faturamento(id);
alter table public.notas_fiscais add constraint notas_fiscais_card_id_fkey foreign key (card_id) references public.cards(id);
alter table public.notas_fiscais add constraint notas_fiscais_obra_id_fkey foreign key (obra_id) references public.obras(id);
alter table public.obra_compras add constraint obra_compras_card_id_fkey foreign key (card_id) references public.cards(id) on delete cascade;
alter table public.obra_compras add constraint obra_compras_obra_id_fkey foreign key (obra_id) references public.obras(id) on delete cascade;
alter table public.obra_contatos add constraint obra_contatos_obra_id_fkey foreign key (obra_id) references public.obras(id) on delete cascade;
alter table public.obra_equipamentos add constraint obra_equipamentos_obra_id_fkey foreign key (obra_id) references public.obras(id) on delete cascade;
alter table public.obra_nfs add constraint obra_nfs_obra_id_fkey foreign key (obra_id) references public.obras(id) on delete cascade;
alter table public.obra_nfs add constraint obra_nfs_compra_id_fkey foreign key (compra_id) references public.obra_compras(id) on delete cascade;
alter table public.obra_retiradas add constraint obra_retiradas_obra_id_fkey foreign key (obra_id) references public.obras(id) on delete cascade;
alter table public.obra_retiradas add constraint obra_retiradas_cp_id_fkey foreign key (cp_id) references public.contas_pagar(id);
alter table public.obras add constraint obras_fase_id_fkey foreign key (fase_id) references public.fases_obra(id) on delete set null;
alter table public.obras add constraint obras_cliente_id_fkey foreign key (cliente_id) references public.clientes(id) on delete cascade;
alter table public.ordens_servico add constraint ordens_servico_fase_obra_id_fkey foreign key (fase_obra_id) references public.fases_obra(id) on delete set null;
alter table public.ordens_servico add constraint ordens_servico_resultado_cp_id_fkey foreign key (resultado_cp_id) references public.contas_pagar(id);
alter table public.ordens_servico add constraint ordens_servico_card_id_fkey foreign key (card_id) references public.cards(id) on delete cascade;
alter table public.os_custos add constraint os_custos_os_id_fkey foreign key (os_id) references public.ordens_servico(id) on delete cascade;
alter table public.os_custos add constraint os_custos_centro_custo_id_fkey foreign key (centro_custo_id) references public.centros_custo(id) on delete set null;
alter table public.os_custos add constraint os_custos_cp_id_fkey foreign key (cp_id) references public.contas_pagar(id) on delete set null;
alter table public.os_diario add constraint os_diario_autor_id_fkey foreign key (autor_id) references public.usuarios(id) on delete set null;
alter table public.os_diario add constraint os_diario_os_id_fkey foreign key (os_id) references public.ordens_servico(id) on delete cascade;
alter table public.os_itens_trabalho add constraint os_itens_trabalho_os_id_fkey foreign key (os_id) references public.ordens_servico(id) on delete cascade;
alter table public.os_itens_trabalho add constraint os_itens_trabalho_proposta_item_id_fkey foreign key (proposta_item_id) references public.proposta_itens(id) on delete cascade;
alter table public.os_tecnicos add constraint os_tecnicos_usuario_id_fkey foreign key (usuario_id) references public.usuarios(id) on delete cascade;
alter table public.os_tecnicos add constraint os_tecnicos_os_id_fkey foreign key (os_id) references public.ordens_servico(id) on delete cascade;
alter table public.proposta_arquivos add constraint proposta_arquivos_proposta_id_fkey foreign key (proposta_id) references public.propostas(id) on delete cascade;
alter table public.proposta_itens add constraint proposta_itens_proposta_id_fkey foreign key (proposta_id) references public.propostas(id) on delete cascade;
alter table public.proposta_itens add constraint proposta_itens_produto_estoque_id_fkey foreign key (produto_estoque_id) references public.estoque_produtos(id) on delete set null;
alter table public.propostas add constraint propostas_card_id_fkey foreign key (card_id) references public.cards(id) on delete cascade;
alter table public.propostas add constraint propostas_obra_id_fkey foreign key (obra_id) references public.obras(id) on delete set null;
alter table public.propostas add constraint propostas_fase_id_fkey foreign key (fase_id) references public.fases_proposta(id);
alter table public.propostas add constraint propostas_cliente_id_fkey foreign key (cliente_id) references public.clientes(id);
alter table public.srm_cotacoes add constraint srm_cotacoes_fornecedor_id_fkey foreign key (fornecedor_id) references public.fornecedores(id) on delete set null;
alter table public.srm_cotacoes add constraint srm_cotacoes_card_srm_id_fkey foreign key (card_srm_id) references public.cards_srm(id) on delete cascade;
alter table public.usuarios add constraint usuarios_grupo_id_fkey foreign key (grupo_id) references public.grupos(id);


-- ── TRIGGER ──────────────────────────────────────────────────────────────────

create trigger trg_bloquear_autopromocao before update on public.usuarios
  for each row execute function bloquear_autopromocao_usuario();


-- ── VIEW PÚBLICA (login antes de autenticar — ver comentário em omni-desktop.html
--    função atualizarMarcaDoServidor) ─────────────────────────────────────────

create view public.empresa_marca
with (security_definer = true) as
  select id, razao, fantasia, logo from public.empresa;

-- Nota: como é SECURITY DEFINER, esta view ignora o RLS de `empresa` de propósito
-- — expõe só 3 campos (nome/logo), nunca CNPJ/IE/alíquotas/config interna, pro
-- role `anon` mostrar o logotipo certo na tela de login antes de ter sessão.


-- ── ROW LEVEL SECURITY ───────────────────────────────────────────────────────
-- Todas as tabelas usam basicamente o mesmo padrão: RLS habilitado, policy(s)
-- pro role authenticated exigindo usuario_ativo() (usuário logado E ativo).
-- Exceções: grupos (escrita restrita a sou_admin()) e usuarios (grupo_id/ativo
-- só por admin via trigger, ver bloquear_autopromocao_usuario acima).

alter table public.audit_logs enable row level security;
create policy "authenticated_full_access" on public.audit_logs for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.card_contatos enable row level security;
create policy "Usuários autenticados acessam card_contatos" on public.card_contatos for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.card_historico enable row level security;
create policy "authenticated_full_access" on public.card_historico for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.cards enable row level security;
create policy "authenticated_full_access" on public.cards for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.cards_srm enable row level security;
create policy "Authenticated users can delete cards_srm" on public.cards_srm for DELETE to authenticated using (usuario_ativo());
create policy "Authenticated users can insert cards_srm" on public.cards_srm for INSERT to authenticated with check (usuario_ativo());
create policy "Authenticated users can select cards_srm" on public.cards_srm for SELECT to authenticated using (usuario_ativo());
create policy "Authenticated users can update cards_srm" on public.cards_srm for UPDATE to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.categorias_outros_custos enable row level security;
create policy "autenticados podem gerenciar categorias" on public.categorias_outros_custos for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());
create policy "autenticados podem ler categorias" on public.categorias_outros_custos for SELECT to authenticated using (usuario_ativo());

alter table public.centros_custo enable row level security;
create policy "Authenticated users can manage centros_custo" on public.centros_custo for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.clientes enable row level security;
create policy "authenticated_full_access" on public.clientes for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.contas_correntes enable row level security;
create policy "auth_contas_correntes" on public.contas_correntes for ALL to public using (usuario_ativo()) with check (usuario_ativo());

alter table public.contas_pagar enable row level security;
create policy "auth_contas_pagar" on public.contas_pagar for ALL to public using (usuario_ativo()) with check (usuario_ativo());

alter table public.contas_pagar_pagamentos enable row level security;
create policy "authenticated_full_access" on public.contas_pagar_pagamentos for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.contas_recorrentes enable row level security;
create policy "auth_contas_recorrentes" on public.contas_recorrentes for ALL to public using (usuario_ativo()) with check (usuario_ativo());

alter table public.download_arquivos enable row level security;
create policy "auth" on public.download_arquivos for ALL to public using (usuario_ativo()) with check (usuario_ativo());

alter table public.download_categorias enable row level security;
create policy "auth" on public.download_categorias for ALL to public using (usuario_ativo()) with check (usuario_ativo());

alter table public.empresa enable row level security;
create policy "authenticated_full_access" on public.empresa for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.estoque_categorias enable row level security;
create policy "del" on public.estoque_categorias for DELETE to authenticated using (usuario_ativo());
create policy "upd" on public.estoque_categorias for UPDATE to authenticated using (usuario_ativo()) with check (usuario_ativo());
create policy "sel" on public.estoque_categorias for SELECT to authenticated using (usuario_ativo());
create policy "ins" on public.estoque_categorias for INSERT to authenticated with check (usuario_ativo());

alter table public.estoque_movimentacoes enable row level security;
create policy "Acesso autenticado — estoque_movimentacoes" on public.estoque_movimentacoes for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.estoque_produtos enable row level security;
create policy "Acesso autenticado — estoque_produtos" on public.estoque_produtos for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.fases_crm enable row level security;
create policy "authenticated_full_access" on public.fases_crm for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.fases_faturamento enable row level security;
create policy "Authenticated users can read fases_faturamento" on public.fases_faturamento for SELECT to authenticated using (usuario_ativo());
create policy "Authenticated users can insert fases_faturamento" on public.fases_faturamento for INSERT to authenticated with check (usuario_ativo());
create policy "Authenticated users can update fases_faturamento" on public.fases_faturamento for UPDATE to authenticated using (usuario_ativo()) with check (usuario_ativo());
create policy "Authenticated users can delete fases_faturamento" on public.fases_faturamento for DELETE to authenticated using (usuario_ativo());

alter table public.fases_obra enable row level security;
create policy "autenticados escrevem fases_obra" on public.fases_obra for ALL to public using (usuario_ativo()) with check (usuario_ativo());
create policy "auth fases_obra" on public.fases_obra for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());
create policy "autenticados leem fases_obra" on public.fases_obra for SELECT to public using (usuario_ativo());

alter table public.fases_os enable row level security;
create policy "autenticados escrevem fases_os" on public.fases_os for ALL to public using (usuario_ativo()) with check (usuario_ativo());
create policy "autenticados leem fases_os" on public.fases_os for SELECT to public using (usuario_ativo());
create policy "auth fases_os" on public.fases_os for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.fases_proposta enable row level security;
create policy "authenticated_full_access" on public.fases_proposta for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.fases_srm enable row level security;
create policy "Authenticated users can delete fases_srm" on public.fases_srm for DELETE to authenticated using (usuario_ativo());
create policy "Authenticated users can read fases_srm" on public.fases_srm for SELECT to authenticated using (usuario_ativo());
create policy "Authenticated users can update fases_srm" on public.fases_srm for UPDATE to authenticated using (usuario_ativo()) with check (usuario_ativo());
create policy "Authenticated users can insert fases_srm" on public.fases_srm for INSERT to authenticated with check (usuario_ativo());

alter table public.faturamento_itens enable row level security;
create policy "authenticated_ativo" on public.faturamento_itens for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.financeiro_recebimentos enable row level security;
create policy "Authenticated users can manage financeiro_recebimentos" on public.financeiro_recebimentos for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.financeiro_recebimentos_pagamentos enable row level security;
create policy "authenticated_full_access" on public.financeiro_recebimentos_pagamentos for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.fornecedor_contatos enable row level security;
create policy "auth_fornecedor_contatos" on public.fornecedor_contatos for ALL to public using (usuario_ativo()) with check (usuario_ativo());

alter table public.fornecedores enable row level security;
create policy "auth_fornecedores" on public.fornecedores for ALL to public using (usuario_ativo()) with check (usuario_ativo());

alter table public.funcoes enable row level security;
create policy "authenticated_full_access" on public.funcoes for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.garantia_classes enable row level security;
create policy "authenticated_ativo" on public.garantia_classes for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.grupos enable row level security;
create policy "grupos_select" on public.grupos for SELECT to authenticated using (usuario_ativo());
create policy "grupos_write_admin" on public.grupos for ALL to authenticated using (sou_admin()) with check (sou_admin());

alter table public.guias_tributos enable row level security;
create policy "Authenticated users can update guias_tributos" on public.guias_tributos for UPDATE to authenticated using (usuario_ativo()) with check (usuario_ativo());
create policy "Authenticated users can delete guias_tributos" on public.guias_tributos for DELETE to authenticated using (usuario_ativo());
create policy "Authenticated users can insert guias_tributos" on public.guias_tributos for INSERT to authenticated with check (usuario_ativo());
create policy "Authenticated users can select guias_tributos" on public.guias_tributos for SELECT to authenticated using (usuario_ativo());

alter table public.movimentacoes_financeiras enable row level security;
create policy "auth_movimentacoes" on public.movimentacoes_financeiras for ALL to public using (usuario_ativo()) with check (usuario_ativo());

alter table public.notas_fiscais enable row level security;
create policy "Authenticated users can insert notas_fiscais" on public.notas_fiscais for INSERT to authenticated with check (usuario_ativo());
create policy "Authenticated users can delete notas_fiscais" on public.notas_fiscais for DELETE to authenticated using (usuario_ativo());
create policy "Authenticated users can select notas_fiscais" on public.notas_fiscais for SELECT to authenticated using (usuario_ativo());
create policy "Authenticated users can update notas_fiscais" on public.notas_fiscais for UPDATE to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.notificacoes enable row level security;
create policy "authenticated_full_access" on public.notificacoes for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.obra_compras enable row level security;
create policy "auth_obra_compras" on public.obra_compras for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.obra_contatos enable row level security;
create policy "auth obra_contatos" on public.obra_contatos for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.obra_equipamentos enable row level security;
create policy "Autenticados podem tudo em obra_equipamentos" on public.obra_equipamentos for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.obra_nfs enable row level security;
create policy "auth_obra_nfs" on public.obra_nfs for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.obra_retiradas enable row level security;
create policy "Autenticados podem excluir retiradas" on public.obra_retiradas for DELETE to authenticated using (usuario_ativo());
create policy "Autenticados podem atualizar retiradas" on public.obra_retiradas for UPDATE to authenticated using (usuario_ativo()) with check (usuario_ativo());
create policy "Autenticados podem ver retiradas" on public.obra_retiradas for SELECT to authenticated using (usuario_ativo());
create policy "Autenticados podem inserir retiradas" on public.obra_retiradas for INSERT to authenticated with check (usuario_ativo());

alter table public.obras enable row level security;
create policy "authenticated_full_access" on public.obras for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.ordens_servico enable row level security;
create policy "authenticated_all" on public.ordens_servico for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.origens enable row level security;
create policy "authenticated_full_access" on public.origens for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.os_custos enable row level security;
create policy "os_custos_all" on public.os_custos for ALL to public using (usuario_ativo()) with check (usuario_ativo());

alter table public.os_diario enable row level security;
create policy "os_diario_all" on public.os_diario for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.os_itens_trabalho enable row level security;
create policy "os_itens_trabalho_all" on public.os_itens_trabalho for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.os_tecnicos enable row level security;
create policy "os_tecnicos_all" on public.os_tecnicos for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.proposta_arquivos enable row level security;
create policy "authenticated_full_access" on public.proposta_arquivos for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.proposta_itens enable row level security;
create policy "authenticated_full_access" on public.proposta_itens for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.propostas enable row level security;
create policy "authenticated_full_access" on public.propostas for ALL to authenticated using (usuario_ativo()) with check (usuario_ativo());

alter table public.srm_cotacoes enable row level security;
create policy "sel" on public.srm_cotacoes for SELECT to public using (usuario_ativo());
create policy "del" on public.srm_cotacoes for DELETE to public using (usuario_ativo());
create policy "ins" on public.srm_cotacoes for INSERT to public with check (usuario_ativo());
create policy "upd" on public.srm_cotacoes for UPDATE to public using (usuario_ativo()) with check (usuario_ativo());

alter table public.usuarios enable row level security;
create policy "usuarios_insert_admin" on public.usuarios for INSERT to authenticated with check (sou_admin());
create policy "usuarios_delete_admin" on public.usuarios for DELETE to authenticated using (sou_admin());
create policy "usuarios_update_own_or_admin" on public.usuarios for UPDATE to authenticated using (((auth_id = auth.uid()) OR sou_admin())) with check (((auth_id = auth.uid()) OR sou_admin()));
create policy "usuarios_select" on public.usuarios for SELECT to authenticated using (usuario_ativo());


-- ============================================================================
-- STORAGE BUCKETS (não recriados por este script — criar manualmente no
-- Dashboard, Storage → New bucket, com o nome e a flag "Public" abaixo)
-- ============================================================================
-- compras-pdfs          privado
-- downloads             privado
-- equip-arquivos        privado
-- faturamento-produtos  privado
-- faturamento-servicos  privado
-- nfs-pdfs              privado
-- os-arquivos           privado
-- os-diario-imagens     PÚBLICO (fotos do Diário de Obra — getPublicUrl no app)
-- os-imagens            privado
-- propostas             privado
-- srm-cotacoes          privado
-- srm-nfs               privado
--
-- Edge Function: admin-usuarios (supabase/functions/admin-usuarios) — gestão de
-- usuários (criar/editar/excluir) sem expor a service_role key no cliente.
-- ============================================================================
