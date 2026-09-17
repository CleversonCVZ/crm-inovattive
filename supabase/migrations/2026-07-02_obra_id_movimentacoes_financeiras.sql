-- ============================================================
-- Adiciona obra_id em movimentacoes_financeiras
-- Permite vincular um lançamento manual (conta corrente/cartão)
-- a uma obra quando o centro de custo selecionado exige isso
-- (ex.: "Material de Obra", slug 'material_obra').
-- 2026-07-02
-- ============================================================

ALTER TABLE public.movimentacoes_financeiras
  ADD COLUMN IF NOT EXISTS obra_id BIGINT REFERENCES public.obras(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_movfin_obra ON public.movimentacoes_financeiras(obra_id);
