> **Status (2026-09-15):** Passo 1 da Fase A (`config.js`) já foi implementado e está em produção (v1.47.221/mobile v1.0.40) — `omni-desktop.html` e `omni-mobile.html` agora leem `SUPABASE_URL`/`SUPABASE_KEY` de `window.OMNI_CONFIG` (arquivo `config.js` na raiz do repo), em vez de ter os valores fixos no código. Valor hoje é o mesmo de sempre (banco da Inovattive) — zero mudança funcional, só destrava os passos 2-10 pra quando houver um beta tester decidido. Resto da Fase A e toda a Fase B continuam não iniciados.

# Plano de Comercialização do OMNI — Fase A (Beta Testers) → Fase B (Mono-instância)

> Documento de planejamento, não de implementação. Nada aqui foi executado — é o roteiro pra quando o Cleverson decidir avançar. Ver também `MIGRACAO-SUPABASE.md` (como o OMNI migrou de localStorage pra Supabase) e `MODULO-FINANCEIRO.md` pra contexto de como os módulos foram documentados até aqui.

## Contexto e decisão estratégica

Hoje o OMNI é **100% mono-empresa**: uma `SUPABASE_URL` fixa hardcoded no HTML (`omni-desktop.html` linha ~3325), uma tabela `empresa` singular, zero coluna `empresa_id` em qualquer uma das 51 tabelas do schema. Rodar o OMNI pra outra empresa hoje, do jeito que está, significaria literalmente copiar os arquivos e apontar pra outro banco.

A estratégia escolhida (2026-08-27): **não pular direto pro multi-tenant**. Primeiro validar o produto com 2 clientes reais ("Beta Testers") rodando cada um sua própria instância duplicada (banco + app próprios) — rápido de colocar no ar, zero risco de um cliente ver dado do outro (são bancos fisicamente separados). Só depois de validado com uso real é que vale investir o trabalho pesado de consolidar tudo num único banco multi-tenant.

Isso evita gastar meses reescrevendo RLS/schema pra suportar múltiplas empresas antes de saber se alguém de fato vai pagar pelo produto.

---

## Fase A — Beta Testers (instância duplicada), detalhado

**Objetivo:** ter 2 empresas externas usando o OMNI em produção, cada uma com seu próprio Supabase project e seu próprio deploy Vercel — nenhuma mudança de arquitetura no código, só repetir o setup que já existe pra Inovattive.

### Custo real (checado hoje, 2026-08-27)

A org Supabase da Inovattive (`CleversonCVZ's Org`) está no **plano Free**, com só o projeto da Inovattive rodando hoje. Isso muda a conta:

- **Supabase Free**: até **2 projetos ativos por organização**, de graça. Ou seja, dá pra criar **1 beta tester de graça** (Inovattive + Beta 1 = 2 projetos), mas o **2º beta tester exige upgrade pro plano Pro (US$ 25/mês por projeto)** — ou criar o 2º beta tester numa organização/conta Supabase separada (própria do cliente ou uma segunda conta sua), o que mantém tudo grátis mas espalha o controle em mais de um lugar. Importante também: **projeto Free pausa automaticamente depois de 7 dias sem uso** — se o beta tester ficar uma semana sem abrir o sistema, ele simplesmente para de funcionar até alguém reativar manualmente no painel Supabase. Isso pode ser confuso bem no meio de um teste com cliente externo.
- **Vercel**: o plano Hobby (grátis) **proíbe uso comercial e trabalho pra cliente** nos termos de serviço — rodar o OMNI pra uma empresa terceira (ainda que "só teste") já se enquadra como uso comercial. Pra fazer isso dentro das regras, precisa do **plano Pro (US$ 20/mês por membro)**.

Ou seja, colocar os 2 beta testers no ar "de verdade" (sem risco de pausa automática, dentro dos termos de uso) tem um custo real de referência de **~US$ 25 (Supabase Pro, só se passar de 2 projetos) + US$ 20 (Vercel Pro) por mês**, considerando que os projetos ficam na mesma organização/conta que a Inovattive já usa. Dá pra começar só com 1 beta tester sem gastar nada, e decidir o upgrade quando o 2º entrar.

> **Recomendação — começar com só 1 beta tester (2026-08-27):** com 1 único beta tester, Inovattive + Beta = 2 projetos, o Supabase **fica inteiramente no plano Free, sem custo nenhum**. O trabalho técnico é o mesmo passo a passo abaixo, só que executado uma vez em vez de duas — na prática metade do esforço de setup e metade do esforço contínuo de propagar cada versão nova. O único ponto que não muda com 1 ou 2 testers é o Vercel: a restrição de "uso comercial/trabalho pra cliente" do plano Hobby é sobre a *natureza* do uso, não sobre quantos projetos — então, se for uma empresa terceira de verdade usando o sistema (mesmo em teste, mesmo sem cobrar nada dela), tecnicamente já se enquadra como comercial pelos termos da Vercel. Vale considerar se esse único deploy extra entra no Pro (US$20/mês) ou fica um tempo informal — não sou advogado, é uma decisão de risco sua. Contra: com só 1 tester, o sinal de validação é mais fraco (só um tipo de negócio/fluxo de trabalho testado) — se esse cliente for muito parecido com a Inovattive, você aprende menos sobre o quão genérico o produto realmente é antes de decidir investir na Fase B.

### Passo a passo, na ordem, por Beta Tester

1. **Extrair a config do Supabase pro `config.js`** (única mudança de código, feita uma vez só — vale pra Inovattive e pros 2 beta testers). Hoje `SUPABASE_URL`/`SUPABASE_KEY` são `const` fixas no topo do `<script>` (linha ~3325). Passa a ficar assim:

   ```html
   <!-- antes do <script> principal, no <head> -->
   <script src="config.js"></script>
   ```
   ```js
   // config.js — um arquivo diferente por deploy Vercel
   window.OMNI_CONFIG = {
     supabaseUrl: 'https://xxxxxxxx.supabase.co',
     supabaseKey: 'eyJ...'
   };
   ```
   E dentro do `<script>` principal, trocar:
   ```js
   const SUPABASE_URL = 'https://bazoyvccbxtjwfbldvuz.supabase.co';
   ```
   por:
   ```js
   const SUPABASE_URL = window.OMNI_CONFIG.supabaseUrl;
   ```
   Isso faz o **mesmo `omni-desktop.html`/`omni-mobile.html`, o mesmo repositório git, o mesmo código-fonte** servir os 3 clientes — só o `config.js` (não versionado no git, ou versionado num arquivo por ambiente) muda entre os deploys. Sem isso, cada cliente novo viraria uma cópia física divergente do HTML, e toda correção de bug teria que ser copiada e colada 3 vezes à mão dentro do próprio arquivo — muito mais frágil do que manter 1 fonte de verdade + 3 configs.

2. **Criar o projeto Supabase novo** (painel Supabase ou MCP `create_project`), mesma região (`us-east-2`) pra manter latência parecida.

3. **Aplicar o schema** — **não confiar no `supabase/schema.sql`** (ele já está sabidamente desatualizado em relação ao banco real, prática conhecida neste projeto). O caminho mais seguro é gerar um dump limpo *do banco real da Inovattive agora* (via `pg_dump --schema-only` ou reconstruindo a partir de `list_tables`/introspecção) e aplicar isso no projeto novo — inclui as 51 tabelas, todas as funções `SECURITY DEFINER`, e todas as policies de RLS já calibradas (o beta tester já nasce com a mesma segurança que levamos meses pra fechar na Inovattive, de graça).

4. **Seed de dados de configuração, zerado** — diferente do schema (que é estrutura, copia igual), aqui é dado "vivo" que precisa nascer neutro pro cliente novo: `grupos` (os níveis de permissão calibrados valem a pena copiar como ponto de partida — Administradores, Técnicos, Vendedores etc. — mas sem nenhum usuário real vinculado), `fases`, `origens`, `funções`, categorias de estoque, centros de custo padrão. **Nenhum dado de negócio da Inovattive** (clientes, obras, cards, propostas) vai junto — o beta tester começa com o sistema vazio, só a estrutura pronta.

5. **Recriar os 10 buckets de Storage** com as mesmas políticas: `downloads`, `propostas`, `srm-cotacoes`, `srm-nfs`, `faturamento-produtos`, `faturamento-servicos`, `equip-arquivos`, `os-diario-imagens`, `os-arquivos`, `os-imagens`.

6. **Publicar a Edge Function** `admin-usuarios` (única hoje) no projeto novo.

7. **Configurar Auth** (e-mail/senha) e criar o primeiro usuário administrador do cliente beta.

8. **Criar o projeto Vercel novo** (ex.: `crm-clientebeta1`), apontando pro mesmo repositório git, com o `config.js` desse cliente. Configurar domínio/subdomínio próprio.

9. **Cadastrar a empresa** (nome, logo, CNPJ) — já é uma tela existente no sistema, "Configurações do Sistema", não precisa de nada novo.

10. **Onboarding** — criar os usuários reais do cliente, ensinar o básico (fora do escopo técnico, mas é o que decide se o teste vai dar certo ou não).

Passos 2 a 9 são, na prática, repetir exatamente o que já foi feito pra Inovattive em junho/2026 (documentado em `MIGRACAO-SUPABASE.md`) — não é trabalho novo, é replicar um processo já validado. Dá pra estimar em questão de **1 dia de trabalho técnico por beta tester**, feito uma vez.

### Riscos e custo operacional contínuo da Fase A

- **Toda correção de bug ou nova feature vira N deploys** (Inovattive + cada beta tester ativo) em bancos e projetos Vercel separados — nenhuma automação disso hoje, é manual. Toda vez que uma versão nova sai (como temos feito quase diariamente), a mesma migration SQL precisa ser aplicada em cada projeto Supabase, e o mesmo código re-deployado em cada projeto Vercel. Vale considerar, ainda na Fase A, uma checklist simples de "propagar versão pros N ambientes" pra não esquecer nenhum e não deixar um cliente desatualizado.
- **Migrations divergentes**: se um beta tester pedir uma customização exclusiva dele, os schemas começam a divergir de verdade — isso complica (ou inviabiliza) a consolidação da Fase B depois. Recomendação: durante a Fase A, tratar o schema como um artefato único e versionado, aplicado igual nos 3 ambientes — customização por cliente só na camada de configuração (branding, grupos, campos habilitados), nunca alterando tabela/coluna.
- **IDs vão colidir entre bancos** — cada banco usa `SERIAL`/sequence próprio (cliente #1, obra #1... existem em todas as 3 instâncias). Isso não é problema nenhum na Fase A (bancos são isolados), mas é exatamente o que torna a Fase B trabalhosa (ver abaixo). Não precisa resolver agora, só ter consciência.
- **Auto-pause do plano Free** (se optar por não pagar Pro ainda): projeto para sozinho depois de 7 dias sem requisição — risco real de o beta tester achar que "o sistema caiu" no meio do teste.
- **Saída fácil se não der certo**: se um beta tester desistir, é só pausar/excluir o projeto Supabase e o deploy Vercel dele — não afeta a Inovattive nem o outro beta tester, porque são ambientes 100% isolados. Se der certo e ele quiser continuar pagando, os dados dele já estão prontos e isolados, esperando o momento de migrar pra Fase B.

---

## Fase B — Consolidação Mono-instância (multi-tenant real)

**Objetivo:** um único banco Supabase, uma única aplicação, atendendo N empresas, cada uma enxergando só o que é seu.

Só faz sentido puxar o gatilho dessa fase depois que a Fase A provar que existe demanda real — é o trabalho mais caro do plano inteiro.

### Passo 1 — `empresa_id` em todas as tabelas

Adicionar `empresa_id bigint references empresas(id)` em praticamente todas as 51 tabelas do schema (as que não são já filhas-de-filhas de uma que já tem — ex.: `os_custos` herda o `empresa_id` da O.S. via `os_id`, mas mesmo assim costuma valer a pena desnormalizar pra simplificar RLS e evitar joins em toda policy).

### Passo 2 — Reescrever TODA a RLS

Esse é o ponto mais pesado. Cada uma das policies fechadas nos últimos meses (Fases 1-3 do plano de RLS + Lotes 1-3 de UI, documentados em `project_crm_inovattive_permissoes.md`) precisa ganhar uma cláusula adicional `AND empresa_id = current_empresa_id()`. Isso inclui:
- Toda policy de SELECT/INSERT/UPDATE/DELETE nas 51 tabelas.
- Toda função `SECURITY DEFINER` (`pode_ver_tela`, `pode_editar_tela`, `pode_usar_recurso`, `pode_editar_recurso`, e as demais) — hoje elas resolvem permissão só por usuário/grupo, precisam passar a resolver por usuário/grupo **dentro da empresa dele**.
- Uma função `current_empresa_id()` nova, que resolve a partir do usuário autenticado (`usuarios.empresa_id`), no mesmo espírito de `usuario_ativo()` que já existe hoje.

Dado o tamanho do trabalho já feito em RLS neste projeto, essa etapa é comparável (ou maior) que o plano de 3 fases + 3 lotes que acabamos de fechar — vale tratar como um projeto à parte, com a mesma disciplina de auditoria com subagentes em paralelo que já usamos.

### Passo 3 — Resolver "qual empresa é essa" no login/URL

Duas abordagens comuns, a decidir:
- **Subdomínio por empresa** (`inovattive.omni.app`, `clientebeta.omni.app`) — resolve o tenant antes até do login, mais robusto, mas exige configurar DNS/certificado por cliente.
- **Usuário pertence a uma única empresa, resolvida no login** — mais simples de implementar (não mexe em DNS), mas o app só sabe qual é o tenant depois que o usuário loga, então toda tela de login precisa ser "neutra" (sem logo/branding do cliente até autenticar).

Reaproveitando o mecanismo de `config.js` já criado na Fase A ajuda aqui — o mesmo lugar que hoje define qual Supabase apontar pode evoluir pra resolver subdomínio → empresa.

### Passo 4 — Migração de dados (o passo mais arriscado)

Os bancos da Inovattive + 2 beta testers têm IDs colidindo entre si (todos usam sequence própria começando do 1). Migrar pra um banco único exige:
- Remapear todo ID de cada empresa de origem pra uma faixa nova (ex.: Inovattive mantém 1-99999, Beta 1 vira 100000+, Beta 2 vira 200000+) — e propagar esse remapeamento em **toda** foreign key das 51 tabelas, o que é um script não-trivial de escrever e validar.
- Migrar os arquivos dos 10 buckets de Storage também, com os paths reorganizados (hoje os paths não têm prefixo de empresa).
- Rodar em ambiente de teste primeiro, validar contagens/somas financeiras batendo exatamente antes de considerar migrado (dado real de produção, mesmo cuidado que já é praticado hoje segundo `project_crm_inovattive.md`: "avoid destructive schema/data operations without confirming first").

#### O sistema fica fora do ar? Por quanto tempo?

Separando em duas partes, porque a resposta é diferente pra cada uma:

- **Adicionar `empresa_id` em todas as tabelas + reescrever a RLS (Passos 1 e 2), no banco da Inovattive**: isso **não exige tirar o sistema do ar**. São operações de estrutura (`ALTER TABLE ADD COLUMN`, `CREATE POLICY`) que o Postgres moderno (o Supabase já roda Postgres 17) executa quase instantaneamente mesmo com a tabela em uso — sem travar leituras/escritas por mais que frações de segundo. Dá pra testar tudo antes num ambiente separado (ver "Como testar sem tocar na produção" logo abaixo) e só aplicar na produção depois de validado, sem ninguém perceber.

#### Como testar sem tocar na produção

Correção de uma coisa que eu disse errado numa resposta anterior: falei em usar "branch de banco" do Supabase, mas isso é **recurso exclusivo do plano Pro** (cobra por hora de uso) — não existe no Free, que é onde a org está hoje. O caminho realista e sem custo, em camadas (do mais barato pro mais parecido com produção):

1. **Local, no computador, via Supabase CLI (`supabase start`)** — sobe um Postgres completo num container Docker na sua máquina, com o schema/migrations aplicados. Zero custo, zero risco, iteração rápida pra escrever e testar a RLS nova (`empresa_id`, as policies reescritas, a função `current_empresa_id()`) antes de subir em qualquer lugar na nuvem.
2. **Projeto Supabase "sandbox" temporário na nuvem** — depois que a versão local estiver validada, sobe num projeto novo (reaproveitando a folga de projeto grátis que sobra se ficarmos só com 1 beta tester, como decidimos) carregado com uma cópia (ou amostra anonimizada) dos dados reais, pra testar em condições mais parecidas com produção antes de decidir aplicar de verdade.
3. **Só então aplicar na Inovattive de produção** — depois de validado nos dois ambientes acima, a aplicação em si é rápida e sem downtime, como expliquei.

Ou seja: dá sim pra fazer e testar tudo isso sem encostar no banco real até o momento em que já está confiante que funciona — só não vai ser via "branch" do Supabase, a não ser que decida entrar no Pro nessa altura do campeonato.
- **A migração de dados dos beta testers pra dentro do banco único (o remapeamento de IDs)**: aqui sim, existe uma janela de indisponibilidade real, mas só **pro(s) beta tester(s) sendo incorporado(s)** naquele momento — não pra Inovattive, que continua rodando normal no banco que já é o "banco final". A prática seria: ensaiar a migração inteira num ambiente de teste primeiro pra medir o tempo real (depende do volume de dados de cada beta tester, que tende a ser bem menor que o da Inovattive hoje), depois agendar a migração de verdade num horário de baixo uso (fim de semana/noite), avisando o cliente com antecedência. Com ensaio prévio e um script testado, uma janela de **algumas horas** (não dias) é uma estimativa razoável — mas só dá pra cravar um número depois de rodar o ensaio contra os dados reais.

### Passo 5 — Camada comercial (fora do escopo técnico, mas necessário pra vender de verdade)

Não é código do OMNI em si, mas vira bloqueador de vender pra terceiros: cobrança recorrente (Stripe ou similar), painel de administração de tenants (criar/suspender empresa, ver uso), e algum SLA/suporte formalizado. Não detalhado aqui — fica pra quando a Fase B estiver mais perto.

---

## Resumo — quando fazer o quê

| Fase | Gatilho | Esforço estimado (ordem de grandeza) |
|---|---|---|
| A — Beta Testers | Assim que os 2 clientes topem testar | ~1 dia de trabalho técnico por cliente (é replicar um setup que já existe) — 1º beta cabe no plano grátis, 2º exige ~US$25-45/mês (Supabase Pro + Vercel Pro) |
| B — Mono-instância | Só depois da Fase A validar demanda real | Meses — RLS inteira reescrita + migração de dados de produção |

**Próximo passo concreto, se quiser seguir**: decidir os 2 beta testers e começar pelo item 6 da Fase A (`config.js`) — é a única mudança de código, pequena e reversível, que já destrava tudo o resto.
