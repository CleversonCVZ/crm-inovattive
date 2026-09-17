# Módulo Financeiro — Documentação Técnica

Cobre as implementações realizadas a partir de 2026-06-24: Contas a Receber, Centros de Custo e correções de infraestrutura associadas.

---

## 1. Contas a Receber (`financeiro_recebimentos`)

### Tabela Supabase

```sql
CREATE TABLE financeiro_recebimentos (
  id                BIGINT PRIMARY KEY,
  card_id           BIGINT REFERENCES cards(id) ON DELETE CASCADE,
  proposta_id       BIGINT REFERENCES propostas(id) ON DELETE SET NULL,
  os_id             BIGINT REFERENCES ordens_servico(id) ON DELETE SET NULL,
  descricao         TEXT NOT NULL DEFAULT '',
  valor             NUMERIC(12,2) NOT NULL DEFAULT 0,
  tipo              TEXT NOT NULL DEFAULT 'fixo',        -- 'fixo' | 'percentual'
  data_vencimento   DATE,
  condicao          TEXT,
  status            TEXT NOT NULL DEFAULT 'pendente',    -- 'pendente' | 'recebido' | 'vencido'
  data_recebimento  DATE,
  created_at        TIMESTAMPTZ DEFAULT now()
);
```

### Mapeamento JS (`db.recebimentos`)

```js
{
  id, cardId, propostaId, osId,
  descricao, valor,        // valor em número float
  tipo,                    // 'fixo' | 'percentual'
  dataVencimento,          // 'YYYY-MM-DD' ou null
  condicao,                // texto livre (ex: '30/60/90')
  status,                  // 'pendente' | 'recebido' | 'vencido'
  dataRecebimento,         // 'YYYY-MM-DD' ou null
  criadoEm                 // ISO string
}
```

### Aba Financeiro no Cartão CRM

Ativada pela permissão `aba-financeiro`. Renderizada por `abaFinanceiroCartaoHTML(c)`.

**Bloco de Referência** — exibe no topo o valor aprovado de cada proposta (via `valorReceberProposta(p)`, excluindo itens `clienteFornece`) e calcula o saldo ainda não parcelado.

**Stat pills:**
- "A receber" — soma de parcelas com `status = 'pendente'`
- "Recebido" — soma de parcelas com `status = 'recebido'`
- Badge de vencidas quando há parcelas com `dataVencimento` no passado e `status = 'pendente'`

**CRUD de parcelas:**
- `abrirNovaParcelaReceber(cardId)` — abre modal com campos: descrição, valor (`mascaraMoeda`), origem (proposta/OS/avulso), data de vencimento, condição de pagamento
- `salvarNovaParcelaReceber()` — `proximoIdSeguro('financeiro_recebimentos')` + push em `db.recebimentos` + `save()`
- `marcarRecebido(id)` — define `status = 'recebido'` e `dataRecebimento = hoje`
- `excluirParcelaReceber(id)` — confirma + `excluirDoSupabase('financeiro_recebimentos', id)`

### Painel Global (view `fin-contas-receber`)

Renderizado por `renderFinanceiroPainel()` ao ativar a view `fin-contas-receber`.

Exibe:
- Stats gerais: total a receber, total recebido, vencidas, recebimentos deste mês
- Tabela de todas as parcelas com filtro de status
- Cada linha tem link para abrir o cartão CRM correspondente

> **Atenção:** existia um `<div id="view-fin-contas-receber">` placeholder anterior que causava conflito de ID com a implementação real. Foi removido.

---

## 2. Helper `valorReceberProposta(p)`

```js
function valorReceberProposta(p) {
  if (!p.itens || !p.itens.length) return p.valor || 0;
  return p.itens
    .filter(it => !it.clienteFornece)
    .reduce((s, it) => s + (it.total || 0), 0);
}
```

**Propósito:** itens marcados com `clienteFornece: true` são fornecidos diretamente pelo cliente — não geram receita para a empresa, portanto não entram no total a receber nem no Resultado Aparente.

**Onde é usada:**
- Bloco de referência da aba Financeiro do cartão
- Labels de origem no modal de nova parcela
- Painel global Contas a Receber
- `abaObraResultadoAparente` (valorVenda)

Quando alguma proposta aprovada tem itens `clienteFornece`, o Resultado Aparente exibe um aviso azul informando que esses valores foram excluídos do cálculo.

---

## 3. Helper `escHtml(s)`

```js
function escHtml(s) {
  return String(s || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}
```

Adicionado porque estava sendo chamado em `renderFinanceiroPainel` sem ter sido definido no codebase, causando `ReferenceError` silencioso que impedia a renderização das linhas da tabela (stats funcionavam, tbody ficava vazio).

---

## 4. Centros de Custo (`centros_custo`)

### Conceito

Centros de custo classificam os gastos da **empresa inteira** (não por obra). Toda conta a pagar terá um centro de custo obrigatório. A dimensão de projeto é resolvida por FK `obra_id` nas despesas — não criando um CC por obra.

Exemplos:
- **Fixo (overhead):** Ocupação, Administrativo, RH, TI, Veículos/Combustível, Impostos
- **Variável (projetos):** Material de Obra, Mão de Obra, Estoque, Equipamentos/Ferramentas

### Tabela Supabase

```sql
CREATE TABLE centros_custo (
  id         BIGINT PRIMARY KEY,
  nome       TEXT NOT NULL,
  descricao  TEXT,
  tipo       TEXT NOT NULL DEFAULT 'fixo',   -- 'fixo' | 'variavel'
  ativo      BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

### Seed padrão (11 itens)

Disponível em `CENTROS_CUSTO_SEED` no código. Ao abrir a tela sem nenhum registro, aparece banner azul com botão "⚡ Importar sugestões" que chama `importarCentrosSeed()`.

| ID | Nome | Tipo |
|----|------|------|
| 1 | Ocupação | fixo |
| 2 | Administrativo | fixo |
| 3 | Comercial / Vendas | fixo |
| 4 | RH / Pessoal | fixo |
| 5 | TI / Tecnologia | fixo |
| 6 | Material de Obra | variavel |
| 7 | Mão de Obra | variavel |
| 8 | Estoque / Almoxarifado | variavel |
| 9 | Equipamentos / Ferramentas | variavel |
| 10 | Impostos / Taxas | fixo |
| 11 | Veículos / Combustível | fixo |

### Tela (`view-fin-centros-custo`)

Renderizada por `renderCentrosCusto()`. Usa o padrão visual das telas de Fases (`fases-table`, `fase-row`):

- **Linhas azuis** (`#dbeafe`) para centros fixos
- **Linhas verdes** (`#dcfce7`) para centros variáveis
- Agrupamento com cabeçalhos "🏢 Custos Fixos" / "🏗️ Custos Variáveis"

**Edição inline** (sem modal): nome, descrição e tipo editáveis direto na linha; salva automaticamente no `onchange`. Checkbox "Ativo" também inline. Hover/focus nos campos revela borda para indicar editabilidade.

**CRUD:**
- `abrirNovoCentroCusto()` / `salvarNovoCentroCusto()` — modal simples
- `excluirCentroCusto(id)` — confirma + `excluirDoSupabase`
- Edição: diretamente inline (sem modal de edição)

### Menu Financeiro

`fin-fases` foi removido do array `TELAS` e do array `MODULOS[financeiro].telas`. Financeiro agora tem: Painel, Centros de Custo, Categoria Custos Obra, Contas Correntes, Contas a Pagar, Contas a Receber.

---

## 5. Correções de infraestrutura

### Scroll nas telas longas

```css
/* ANTES */
main { flex:1; overflow:auto; padding:16px 20px }

/* DEPOIS */
main { flex:1; overflow:auto; padding:16px 20px; min-height:0 }
```

Sem `min-height:0`, em layout flex-column o `main` expande além do container pai (que tem `overflow:hidden`) e o `overflow:auto` nunca dispara — o scroll simplesmente não funcionava em telas com conteúdo longo. A correção aplica para todas as telas, não só centros de custo.

### Input de valor monetário

Campos de valor agora usam `type="text"` + `inputmode="decimal"` + `oninput="mascaraMoeda(this)"` em vez de `type="number"`, que rejeita vírgula como separador decimal. Parse no save:

```js
const valor = parseFloat(
  (document.getElementById('nr-valor').value || '0')
    .replace(/\./g, '')
    .replace(',', '.')
);
```

---

## 6. Próximas implementações previstas

- **Contas a Pagar** — campo `centro_custo_id` obrigatório (FK em `centros_custo`)
- **Contas Correntes** — ao marcar parcela como recebida, creditar conta corrente escolhida
- **fin-painel** — ainda placeholder "Em desenvolvimento"
