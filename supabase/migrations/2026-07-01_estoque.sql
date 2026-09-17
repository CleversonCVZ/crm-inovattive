-- ============================================================
-- Módulo de Estoque — catálogo de produtos + movimentações
-- 2026-07-01
-- ============================================================

-- Catálogo de produtos (base de dados enriquecida pelas NFs)
CREATE TABLE IF NOT EXISTS estoque_produtos (
  id              serial PRIMARY KEY,
  nome            text NOT NULL,           -- nome comercial (nossa descrição)
  nome_fiscal     text,                    -- xProd da NF (descrição fiscal)
  ncm             text,                    -- NCM vindo da NF-e
  unidade         text NOT NULL DEFAULT 'un',
  descricao       text,
  ativo           boolean NOT NULL DEFAULT true,
  criado_em       timestamptz NOT NULL DEFAULT now()
);

-- Movimentações de estoque (entradas e saídas do almoxarifado)
CREATE TABLE IF NOT EXISTS estoque_movimentacoes (
  id              serial PRIMARY KEY,
  produto_id      integer NOT NULL REFERENCES estoque_produtos(id),
  tipo            text NOT NULL CHECK (tipo IN ('entrada','saida')),
  quantidade      numeric NOT NULL CHECK (quantidade > 0),
  valor_unitario  numeric,                 -- valor unitário da NF ou estimado
  data            date NOT NULL,
  -- origem da entrada
  srm_cotacao_id  integer REFERENCES srm_cotacoes(id),
  nf_item_idx     integer,                 -- índice do item no array nf_itens
  -- destino da saída
  obra_id         integer REFERENCES obras(id),
  observacao      text,
  criado_em       timestamptz NOT NULL DEFAULT now(),
  criado_por      text
);

-- Índices para queries comuns
CREATE INDEX IF NOT EXISTS idx_estmov_produto  ON estoque_movimentacoes(produto_id);
CREATE INDEX IF NOT EXISTS idx_estmov_obra     ON estoque_movimentacoes(obra_id);
CREATE INDEX IF NOT EXISTS idx_estmov_cotacao  ON estoque_movimentacoes(srm_cotacao_id);
CREATE INDEX IF NOT EXISTS idx_estprod_ncm     ON estoque_produtos(ncm);

-- RLS
ALTER TABLE estoque_produtos     ENABLE ROW LEVEL SECURITY;
ALTER TABLE estoque_movimentacoes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Acesso autenticado — estoque_produtos"
  ON estoque_produtos FOR ALL
  TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Acesso autenticado — estoque_movimentacoes"
  ON estoque_movimentacoes FOR ALL
  TO authenticated USING (true) WITH CHECK (true);

-- Marca cotação como "lançada no estoque" quando todos os itens são lançados
ALTER TABLE srm_cotacoes
  ADD COLUMN IF NOT EXISTS estoque_lancado boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS estoque_lancado_em timestamptz;
