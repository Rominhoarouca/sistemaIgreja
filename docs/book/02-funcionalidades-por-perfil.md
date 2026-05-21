# 02. Funcionalidades por Perfil

[⬅ Voltar ao indice do book](README.md)

## ADMIN

### Dashboard

- Visualizacao de indicadores gerais.
- Bloco de celulas ativas alimentado por API.
- Atalhos para criar nova celula e novo lider.

### Visitantes

- Listagem de visitantes com busca.
- Visualizacao de dados e status.
- Atualizacao de status de visitante.
- Conversao de visitante em membro de celula (persistida em tabela dedicada de membros).

### Celulas

- CRUD de celulas.
- Detalhe de celula com endereco, lider, capacidade e status.
- Gestao de membros em endpoint dedicado:
  - Listar membros de uma celula.
  - Adicionar membro sem gravar em tabela de visitantes.

### Materiais

- Upload de materiais (arquivo + metadados).
- Listagem por celula.
- Download por URL assinada.

## LIDER

### Visitantes

- Lista com busca e filtro.
- Visualizacao detalhada por visitante.
- Alteracao de status via tags coloridas persistidas no banco.
- Conversao de visitante em membro da celula.
- Navegacao para mapa a partir do endereco.

### Presenca

- Registro de presenca por encontro.
- Consulta por celula e data.
- Visao de comparecimento.

### Materiais

- Listagem de materiais vinculados.
- Abertura/download via URL assinada.

### Historico Espiritual

- Registro de eventos espirituais por visitante.
- Consulta de historico por visitante.

## Fluxo de Visitante (Publico)

- Cadastro inicial de visitante.
- Tela de descoberta de celulas proximas (agora com consumo de API, sem mock fixo).

## Perfil e Conta (Admin e Lider)

- Consulta de perfil autenticado.
- Atualizacao de dados pessoais.
- Upload/atualizacao de foto de perfil.

[⬅ Voltar ao indice do book](README.md)
