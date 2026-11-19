# GP:OBRA — Command Center

Painel de obra em um único `index.html` (Supabase + Vercel).

## Arquivos

- `index.html`: o site inteiro. A URL e a chave do Supabase ficam em `SUPA_URL` e `SUPA_KEY`.
- `tailwind.css`: CSS gerado a partir das classes do `index.html`.
- `supabase-setup.sql`: cria as tabelas, as regras de segurança e as pastas de arquivos. Rode no SQL Editor do Supabase.

## Montar um projeto Supabase do zero

1. Em supabase.com, crie um projeto (região São Paulo, se disponível).
2. **SQL Editor → New query**: cole todo o `supabase-setup.sql` e clique em **Run**.
3. **Authentication → Sign In / Providers**: desligue **"Allow new users to sign up"**.
4. **Authentication → URL Configuration**: em Site URL, coloque `https://gp-obras.vercel.app`.
5. **Authentication → Users → Add user → Create new user**: crie cada pessoa, com e-mail, senha e "Auto Confirm User" marcado.
6. Defina os administradores no SQL Editor:
   `update public.perfis set papel = 'ADMIN' where email in ('pessoa1@exemplo.com', 'pessoa2@exemplo.com');`
7. **Storage → projeto-arquivos**: envie as plantas com estes nomes exatos:
   `planta base.png`, `hidraulica (2).jpg`, `eletrica.jpg`, `climatizaca.jpg`.
8. **Project Settings → API**: copie a *Project URL* e a chave *anon public* para `SUPA_URL` e `SUPA_KEY` no `index.html`.

As etapas do cronograma são criadas automaticamente. Para mudar os nomes ou a ordem, use **Table Editor → obra_cronograma**.

## Se mudar classes do Tailwind no `index.html`

```
npx tailwindcss@3.4.19 --content index.html -o tailwind.css --minify
```
