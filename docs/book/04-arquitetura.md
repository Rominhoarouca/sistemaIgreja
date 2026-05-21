# 04. Arquitetura

[⬅ Voltar ao indice do book](README.md)

## Visao de camadas

O backend segue uma organizacao em camadas com separacao de responsabilidades:

- **Domain**: entidades e contratos de repositorio.
- **Application**: casos de uso.
- **Infrastructure**: Prisma, rotas HTTP, controllers, middlewares e storage.
- **Shared**: container de injecao, erros, configuracao OpenAPI.

## Backend (Node + TS + Prisma)

### Fluxo interno

1. Rota Express recebe request.
2. Middleware aplica autenticacao/autorizacao.
3. Controller valida entrada com Zod.
4. Controller executa use case.
5. Use case acessa repositorios (Prisma).
6. Response padronizado ao cliente.

### Container de dependencias

Arquivo central de composicao:

- `api/src/shared/container/index.ts`

Responsavel por instanciar:

- Repositorios Prisma.
- Use cases.
- Controllers.

## Frontend (Flutter)

### Organizacao geral

- `lib/features/*`: modulos por dominio funcional.
- `lib/routing/app_router.dart`: regras de navegacao e redirecionamento por autenticacao/papel.
- `lib/core/network`: configuracao de Dio e armazenamento de token.
- `lib/design_system`: componentes e tokens visuais.

### Fluxo de tela

1. Tela dispara acao (ex.: carregar visitantes).
2. Cliente Dio chama endpoint REST.
3. UI atualiza estado local/BLoC.
4. Resultado renderizado no Design System.

## Persistencia e arquivos

- **PostgreSQL**: dados transacionais (usuarios, visitantes, membros, celulas etc.).
- **MinIO**: arquivos de materiais e fotos, com URLs assinadas para download seguro.

## Observacoes arquiteturais recentes

- Membros de celula foram separados da tabela de visitantes (`cell_members`).
- Conversao visitante -> membro preserva rastreabilidade por `sourceVisitorId`.
- Contagem de membros em celula considera a tabela dedicada de membros.

[⬅ Voltar ao indice do book](README.md)
