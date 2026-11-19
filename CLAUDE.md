# GP:OBRA — contexto para o Claude

Painel de acompanhamento de obra. A dona do projeto não é programadora: responda em português, sem jargão, e dê passo a passo com links diretos quando ela precisar fazer algo no Supabase ou na Vercel.

## Como o sistema é montado

- **Site:** um único `index.html` (HTML + JS puro, sem build). Publicado na Vercel em https://gp-obras.vercel.app. Todo push na branch `main` publica sozinho em ~30 segundos.
- **Banco, login e arquivos:** Supabase, projeto `kasrpxzqniumebjnrdmg`. A URL e a chave pública ficam em `SUPA_URL` / `SUPA_KEY` no `index.html`.
- **CSS:** `tailwind.css` é gerado. Ao usar classes novas do Tailwind, rode:
  `npx tailwindcss@3.4.19 --content index.html -o tailwind.css --minify`
- **Estrutura do banco:** `supabase-setup.sql` (tabelas, regras RLS, buckets, realtime). O Claude não tem acesso de administrador ao banco: qualquer mudança de estrutura vai nesse arquivo e a dona cola no SQL Editor do Supabase.

## Regras do projeto

- Papéis: `ADMIN` altera tudo; `CLIENTE` só visualiza e usa o chat. O papel fica na tabela `perfis`. A tela só esconde botões — quem bloqueia de verdade é o RLS do banco. Toda função nova precisa da regra correspondente no banco.
- Todo texto vindo do banco passa por `esc()` antes de entrar em `innerHTML`; URLs passam por `urlSegura()`.
- Arquivos (fotos, cupons) vão para o bucket `obra-uploads` via `uploadArquivo()`. As plantas ficam no bucket `projeto-arquivos`.
- Cadastro público está desligado: usuários são criados no painel do Supabase.
- As bibliotecas externas têm `integrity` (SRI). Ao trocar a versão de uma, recalcule o hash.
- A dona autorizou editar o código e publicar direto na `main`. Confirme antes de qualquer mudança que apague dados ou altere quem tem acesso a quê.
- O Claude não digita senhas: para testar o painel por dentro, use um Supabase simulado em memória ou peça para ela testar.

## Ideias ainda não feitas

- Cliente poder solicitar materiais
- Gerenciar usuários pelo painel (convidar, definir admin)
- Financeiro com categorias e orçamento previsto × gasto
- Várias obras no mesmo sistema
