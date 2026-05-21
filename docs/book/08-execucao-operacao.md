# 08. Execucao e Operacao

[⬅ Voltar ao indice do book](README.md)

## Pre-requisitos

- Flutter SDK (compativel com `sdk: ^3.11.1`)
- Node.js >= 20
- PostgreSQL
- MinIO (para materiais/fotos)

## Frontend (Flutter)

No diretorio raiz:

```bash
flutter pub get
flutter run
```

## Backend (API)

No diretorio `api`:

```bash
npm install
npx prisma generate
npx prisma migrate dev
npm run dev
```

Build de producao:

```bash
npm run build
npm run start
```

## Documentacao da API

Com a API rodando:

- Swagger UI: `http://localhost:<porta>/docs`
- OpenAPI JSON: `http://localhost:<porta>/docs.json`

## Banco de dados

Modelo principal em:

- `api/prisma/schema.prisma`

Migracoes em:

- `api/prisma/migrations`

## Observabilidade e erros

- Request logger habilitado em ambiente de desenvolvimento.
- Error middleware centraliza respostas de erro e validacoes.

## Dicas para troubleshooting

- Se `prisma migrate` falhar em sandbox, execute em terminal com acesso ao banco local.
- Se houver erro de relacao no Prisma (`P1012`), verifique se toda relacao tem lado inverso no schema.

[⬅ Voltar ao indice do book](README.md)
