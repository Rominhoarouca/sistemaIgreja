# 01. Visao Geral

[⬅ Voltar ao indice do book](README.md)

## Objetivo

O Sistema Igreja digitaliza o processo de recepcao, acompanhamento e integracao de visitantes em celulas, conectando os perfis de **Administrador** e **Lider**.

## Escopo funcional

- Cadastro e acompanhamento de visitantes.
- Cadastro e gestao de celulas.
- Conversao de visitante para membro de celula.
- Registro de presenca.
- Registro de historico espiritual.
- Gestao de materiais de celula com upload e download via MinIO.
- Dashboard administrativo com indicadores consolidados.

## Perfis de acesso

- **ADMIN**: visao global, gestao de celulas, visitantes, lideres e materiais.
- **LIDER**: foco operacional em visitantes, presenca, materiais e historico.
- **Fluxo de visitante** (publico do app): registro inicial e descoberta de celulas proximas.

## Stack principal

### Frontend

- Flutter 3 / Dart
- GoRouter
- Dio
- BLoC + Equatable
- Flutter Map + Geocoding

### Backend

- Node.js + TypeScript + Express
- Prisma ORM
- PostgreSQL
- MinIO (arquivos)
- Zod (validacao)
- JWT (autenticacao)

## Navegacao principal (app)

- Publico: Login, Registro, Recuperar senha, Cadastro visitante, Celulas proximas.
- Autenticado ADMIN: Dashboard admin, Materiais admin, Perfil, Notificacoes.
- Autenticado LIDER: Home do lider (visitantes/presenca/materiais/historico), Perfil, Notificacoes.

[⬅ Voltar ao indice do book](README.md)
