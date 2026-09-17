-- Adiciona o e-mail de acesso (Supabase Auth) na tabela usuarios,
-- para a tela "Cadastro de usuários" poder exibir/gerenciar tudo
-- sem precisar abrir o painel do Supabase.

alter table usuarios add column if not exists email text;

-- Preenche o e-mail do admin atual (Cleverson)
update usuarios set email = 'cleverson.cvz@gmail.com' where login = 'cleverson';
