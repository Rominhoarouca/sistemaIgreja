# 03. API REST

[⬅ Voltar ao indice do book](README.md)

Base path: `/v1`

## Auth

- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/refresh`
- `POST /auth/logout`
- `GET /auth/me`

## Users

- `GET /users/me`
- `PATCH /users/me` (multipart, foto opcional)
- `GET /users/leaders`

## Visitors

- `POST /visitors`
- `GET /visitors`
- `GET /visitors/:id`
- `PATCH /visitors/:id/status`
- `PATCH /visitors/:id/convert-member`

## Cells

- `GET /cells/nearby`
- `GET /cells`
- `POST /cells`
- `GET /cells/:id`
- `PATCH /cells/:id`
- `DELETE /cells/:id`
- `GET /cells/:id/members`
- `POST /cells/:id/members`

## Attendance

- `POST /attendance`
- `GET /attendance/cell/:cellId`

## Spiritual History

- `POST /spiritual-history`
- `GET /spiritual-history/visitor/:visitorId`

## Dashboard

- `GET /dashboard/stats` (admin)

## Materials

- `GET /materials` (filtro por `cellId`)
- `POST /materials` (multipart)
- `GET /materials/:id/download-url`
- `DELETE /materials/:id`

## Seguranca e padroes

- Autenticacao por JWT via middleware.
- Validacao de payload com Zod.
- Tratamento centralizado de erros.
- Documentacao viva em Swagger UI:
  - `/docs`
  - `/docs.json`

[⬅ Voltar ao indice do book](README.md)
