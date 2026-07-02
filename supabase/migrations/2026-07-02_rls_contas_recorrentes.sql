-- ============================================================
-- Corrige gap de segurança: contas_recorrentes estava sem RLS
-- (única tabela do banco sem Row Level Security habilitado)
-- 2026-07-02
-- ============================================================

ALTER TABLE public.contas_recorrentes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "auth_contas_recorrentes"
  ON public.contas_recorrentes
  FOR ALL
  TO public
  USING (auth.role() = 'authenticated'::text);
