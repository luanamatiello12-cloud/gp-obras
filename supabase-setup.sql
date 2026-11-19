-- =====================================================================
-- GP:OBRA — Criação do banco + segurança (Supabase)
-- Rodar em: Supabase → SQL Editor → New query → colar tudo → Run
-- Pode rodar de novo sem problema (não apaga dados).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Tabelas do painel
-- ---------------------------------------------------------------------
create table if not exists public.chat_mensagens (
    id          bigint generated always as identity primary key,
    created_at  timestamptz not null default now(),
    autor       text not null,
    mensagem    text,
    midia_url   text
);

create table if not exists public.diario_obra (
    id          bigint generated always as identity primary key,
    created_at  timestamptz not null default now(),
    autor       text not null,
    descricao   text not null,
    midia_url   text
);

create table if not exists public.pedidos_materiais (
    id          bigint generated always as identity primary key,
    created_at  timestamptz not null default now(),
    material    text not null,
    quantidade  text not null,
    status      text not null default 'pendente' check (status in ('pendente', 'aprovado')),
    urgencia    text not null default 'planeada' check (urgencia in ('critica', 'media', 'planeada'))
);

create table if not exists public.obra_financeiro (
    id          bigint generated always as identity primary key,
    created_at  timestamptz not null default now(),
    descricao   text not null,
    valor_pago  numeric(12, 2) not null check (valor_pago >= 0),
    cupom_url   text
);

create table if not exists public.obra_cronograma (
    id          bigint generated always as identity primary key,
    created_at  timestamptz not null default now(),
    ordem       int not null default 0,
    etapa       text not null,
    progresso   int not null default 0 check (progresso between 0 and 100)
);

create table if not exists public.pontos_tecnicos (
    id                bigint generated always as identity primary key,
    created_at        timestamptz not null default now(),
    nome_comodo       text not null,
    url_foto_interna  text not null,
    pos_x             numeric(5, 2) not null,
    pos_y             numeric(5, 2) not null
);

-- Etapas iniciais do cronograma (só se a tabela estiver vazia).
-- Para mudar depois: Supabase → Table Editor → obra_cronograma.
insert into public.obra_cronograma (ordem, etapa)
select * from (values
    (1, 'Serviços preliminares'),
    (2, 'Fundação'),
    (3, 'Estrutura'),
    (4, 'Alvenaria'),
    (5, 'Cobertura'),
    (6, 'Instalações elétricas'),
    (7, 'Instalações hidráulicas'),
    (8, 'Climatização'),
    (9, 'Revestimentos'),
    (10, 'Pintura e acabamento')
) as v(ordem, etapa)
where not exists (select 1 from public.obra_cronograma);

-- ---------------------------------------------------------------------
-- 1. Tabela de perfis (guarda o papel ADMIN/CLIENTE de cada usuário)
-- ---------------------------------------------------------------------
create table if not exists public.perfis (
    id          uuid primary key references auth.users(id) on delete cascade,
    email       text,
    papel       text not null default 'CLIENTE' check (papel in ('ADMIN', 'CLIENTE')),
    avatar_url  text,
    created_at  timestamptz not null default now()
);

-- Cria perfil para usuários que já existem
insert into public.perfis (id, email)
select id, lower(email) from auth.users
on conflict (id) do nothing;

-- Cria perfil automaticamente para cada novo usuário
create or replace function public.criar_perfil()
returns trigger language plpgsql security definer set search_path = public as $$
begin
    insert into public.perfis (id, email) values (new.id, lower(new.email))
    on conflict (id) do nothing;
    return new;
end;
$$;

drop trigger if exists ao_criar_usuario on auth.users;
create trigger ao_criar_usuario
    after insert on auth.users
    for each row execute function public.criar_perfil();

-- Função usada pelas regras: o usuário logado é admin?
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
    select exists (select 1 from public.perfis where id = auth.uid() and papel = 'ADMIN');
$$;

-- ---------------------------------------------------------------------
-- 2. Apagar regras antigas (algumas podem estar liberando tudo)
-- ---------------------------------------------------------------------
do $$
declare r record;
begin
    for r in
        select policyname, tablename from pg_policies
        where schemaname = 'public'
          and tablename in ('perfis', 'chat_mensagens', 'diario_obra', 'pedidos_materiais',
                            'obra_financeiro', 'obra_cronograma', 'pontos_tecnicos')
    loop
        execute format('drop policy %I on public.%I', r.policyname, r.tablename);
    end loop;
end $$;

-- ---------------------------------------------------------------------
-- 3. Ligar RLS e bloquear visitantes não logados (anon)
-- ---------------------------------------------------------------------
alter table public.perfis            enable row level security;
alter table public.chat_mensagens    enable row level security;
alter table public.diario_obra       enable row level security;
alter table public.pedidos_materiais enable row level security;
alter table public.obra_financeiro   enable row level security;
alter table public.obra_cronograma   enable row level security;
alter table public.pontos_tecnicos   enable row level security;

revoke all on public.perfis, public.chat_mensagens, public.diario_obra, public.pedidos_materiais,
              public.obra_financeiro, public.obra_cronograma, public.pontos_tecnicos
    from anon;

-- Usuários logados acessam a API; as regras abaixo (RLS) decidem o que cada um pode fazer.
-- (Explícito para funcionar mesmo com "Conceder acesso à API automaticamente" desligado.)
grant usage on schema public to authenticated;
grant select, insert, update, delete
    on public.chat_mensagens, public.diario_obra, public.pedidos_materiais,
       public.obra_financeiro, public.obra_cronograma, public.pontos_tecnicos
    to authenticated;
grant usage on all sequences in schema public to authenticated;

-- ---------------------------------------------------------------------
-- 4. Regras por tabela
--    Todos os usuários LOGADOS podem ver. Só ADMIN altera.
--    No chat, cada um só envia mensagem em seu próprio nome.
-- ---------------------------------------------------------------------

-- perfis: cada um vê o seu (admin vê todos); só pode trocar a própria foto, nunca o papel
create policy "perfis: ver"        on public.perfis for select to authenticated using (id = auth.uid() or public.is_admin());
create policy "perfis: editar foto" on public.perfis for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
revoke insert, update, delete on public.perfis from authenticated;
grant select on public.perfis to authenticated;
grant update (avatar_url) on public.perfis to authenticated;

-- chat
create policy "chat: ver"     on public.chat_mensagens for select to authenticated using (true);
create policy "chat: enviar"  on public.chat_mensagens for insert to authenticated
    with check (lower(autor) = lower(auth.jwt() ->> 'email'));

-- tabelas que só o admin altera
create policy "diario: ver"          on public.diario_obra       for select to authenticated using (true);
create policy "diario: admin"        on public.diario_obra       for all    to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "pedidos: ver"         on public.pedidos_materiais for select to authenticated using (true);
create policy "pedidos: admin"       on public.pedidos_materiais for all    to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "financeiro: ver"      on public.obra_financeiro   for select to authenticated using (true);
create policy "financeiro: admin"    on public.obra_financeiro   for all    to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "cronograma: ver"      on public.obra_cronograma   for select to authenticated using (true);
create policy "cronograma: admin"    on public.obra_cronograma   for all    to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "pontos: ver"          on public.pontos_tecnicos   for select to authenticated using (true);
create policy "pontos: admin"        on public.pontos_tecnicos   for all    to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- 5. Storage: pasta para fotos e cupons (até 10 MB, só imagens e PDF)
--    Os arquivos recebem nomes aleatórios e impossíveis de adivinhar.
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('obra-uploads', 'obra-uploads', true, 10485760, array['image/*', 'application/pdf'])
on conflict (id) do update
    set file_size_limit = excluded.file_size_limit,
        allowed_mime_types = excluded.allowed_mime_types;

-- Pasta das plantas (planta base + camadas). Envie as imagens pelo painel
-- do Supabase (Storage → projeto-arquivos) com estes nomes exatos:
--   planta base.png | hidraulica (2).jpg | eletrica.jpg | climatizaca.jpg
insert into storage.buckets (id, name, public)
values ('projeto-arquivos', 'projeto-arquivos', true)
on conflict (id) do nothing;

drop policy if exists "obra-uploads: enviar" on storage.objects;
create policy "obra-uploads: enviar" on storage.objects for insert to authenticated
    with check (bucket_id = 'obra-uploads');

-- ---------------------------------------------------------------------
-- 6. Atualização em tempo real para todas as tabelas do painel
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
    foreach t in array array['chat_mensagens', 'diario_obra', 'pedidos_materiais',
                             'obra_financeiro', 'obra_cronograma', 'pontos_tecnicos']
    loop
        if not exists (select 1 from pg_publication_tables
                       where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
            execute format('alter publication supabase_realtime add table public.%I', t);
        end if;
    end loop;
end $$;

-- ---------------------------------------------------------------------
-- 7. QUEM É ADMIN — troque pelos e-mails reais e rode:
-- ---------------------------------------------------------------------
-- update public.perfis set papel = 'ADMIN' where email in ('engenheiro@exemplo.com', 'mestre@exemplo.com');

-- Conferir:
-- select email, papel from public.perfis order by papel, email;
