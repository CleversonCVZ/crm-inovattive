# Migração para Supabase + Vercel — Guia passo a passo

Objetivo desta etapa: ter o esquema do banco criado no Supabase e a
autenticação funcionando (substituindo login/senha texto-plano do
`crm.html`), com o código já publicado no GitHub e em deploy automático
na Vercel. Os dados reais (clientes, cards, propostas) e a troca do
localStorage por chamadas ao banco ficam para a etapa seguinte —
o app continua funcionando 100% local enquanto isso.

---

## Passo 1 — Criar as contas

Crie nesta ordem (gratuitas, basta confirmar e-mail):

1. **GitHub** — https://github.com/signup
2. **Supabase** — https://supabase.com (pode entrar com a conta do GitHub)
3. **Vercel** — https://vercel.com (pode entrar com a conta do GitHub)

Use o mesmo e-mail (`cleverson.cvz@gmail.com`) nas três, e logar Supabase/Vercel
via GitHub facilita a conexão automática depois.

---

## Passo 2 — Criar o projeto Supabase e o esquema do banco

1. No painel do Supabase, **New project**. Nome sugerido: `crm-inovattive`.
   Anote a senha do banco (Database Password) em local seguro.
2. Aguarde o projeto provisionar (~2 min).
3. Vá em **SQL Editor** → **New query**.
4. Cole o conteúdo do arquivo `supabase/schema.sql` (já está na pasta do
   projeto) e clique em **Run**.
   - Isso cria todas as tabelas (clientes, cards, propostas, fases, etc.),
     ativa Row Level Security, cria o bucket de Storage `propostas` e
     insere os dados de configuração (fases, origens, funções, grupos —
     os mesmos seeds que o `crm.html` já usa).

---

## Passo 3 — Autenticação (substitui login/senha texto-plano)

1. Em **Authentication → Providers**, confirme que **Email** está habilitado
   (é o padrão).
2. Em **Authentication → Users → Add user**, crie o usuário admin:
   - Email: `cleverson.cvz@gmail.com` (ou outro de sua escolha)
   - Senha: defina uma senha forte
   - **Auto Confirm User**: marque (evita precisar confirmar e-mail agora)
3. Copie o **User UID** gerado (aparece na lista de usuários).
4. Volte ao **SQL Editor** e rode, trocando o UID:

```sql
insert into usuarios (auth_id, nome, login, funcao, grupo_id, dias_logado, ativo)
values ('COLE-O-UID-AQUI', 'Cleverson', 'cleverson', 'Sócio', 1, 30, true);
```

Isso vincula o usuário do Supabase Auth ao grupo **Administradores** (id 1,
já no seed) — equivalente ao usuário `admin/admin` do protótipo.

---

## Passo 4 — Subir o código para o GitHub

No terminal, dentro da pasta do projeto:

```bash
git init
git add .
git commit -m "Versão inicial do CRM + Obras"
```

Depois, no GitHub, crie um repositório novo (ex.: `crm-inovattive`, pode ser
privado) **sem** README/gitignore, e siga as instruções que ele mostra para
"push an existing repository":

```bash
git remote add origin https://github.com/SEU-USUARIO/crm-inovattive.git
git branch -M main
git push -u origin main
```

---

## Passo 5 — Conectar a Vercel (deploy automático)

1. Na Vercel, **Add New → Project**.
2. Importe o repositório `crm-inovattive` do GitHub.
3. Como o `crm.html` é estático (HTML único), use:
   - Framework Preset: **Other**
   - Build Command: (deixe vazio)
   - Output Directory: `.` (raiz)
4. Em **Environment Variables**, ainda não precisa de nada — as chaves do
   Supabase (URL + anon key, que são públicas por design) entrarão
   diretamente no código na próxima etapa.
5. **Deploy**. A partir daqui, todo `git push` no `main` gera um deploy novo
   automaticamente, e cada Pull Request gera um link de preview.

> Pegue a **Project URL** e a **anon public key** do Supabase
> (Settings → API) — vamos usá-las no código na próxima etapa.

---

## Próximos passos (próxima sessão) — código

Com banco + auth + deploy no ar, o trabalho de código entra em fases
incrementais (o app pode continuar usando localStorage até cada parte ser
trocada e testada):

1. **Login real**: trocar `fazerLogin()` por `supabase.auth.signInWithPassword`,
   carregando o registro de `usuarios`/`grupos` pelo `auth_id`.
2. **Camada de dados**: isolar `load()`/`save()` por entidade (`carregarClientes`,
   `salvarCliente`, etc.) para que cada uma possa ser trocada de
   localStorage → Supabase independentemente, sem reescrever as telas.
3. **Entidades de configuração primeiro** (fases, origens, funções, grupos,
   empresa) — já existem no banco, baixo risco.
4. **Clientes, obras, cards, histórico** — entidades principais do dia a dia.
5. **Propostas + itens + arquivos** — arquivos saem do IndexedDB e vão para o
   bucket `propostas` do Supabase Storage.
6. **Migração dos dados atuais**: exportar o `crmDB` do localStorage (já dá
   pra fazer com um botão "exportar JSON" no próprio app) e importar para as
   tabelas via script.

Cada fase pode ser testada isoladamente no ambiente publicado (Vercel) antes
de seguir para a próxima.
