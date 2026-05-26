# 10. Indicadores e Gráficos

Este capítulo documenta todos os indicadores e gráficos exibidos no aplicativo — tanto no painel do Administrador quanto na tela do Líder de Célula — incluindo a origem dos dados, os endpoints utilizados e a lógica de cálculo.

---

## 10.1 Painel Administrativo — Aba Dashboard

**Endpoint principal:** `GET /dashboard/stats`

Retorna um objeto com os seguintes campos:

| Campo | Tipo | Descrição |
|---|---|---|
| `totalVisitors` | `number` | Total de visitantes cadastrados no sistema |
| `integratedVisitors` | `number` | Visitantes com `status = integrado` |
| `forwardedVisitors` | `number` | Visitantes com `status = em_acompanhamento` **ou** `integrado` |
| `averageAttendanceRate` | `number` | Média (%) de presença nos encontros das células |
| `totalLeaders` | `number` | Total de usuários com `role = LIDER` |
| `newVisitorsThisMonth` | `number` | Visitantes cujo `created_at` está no mês corrente |

### Cards exibidos na aba Dashboard

| Card | Campo da API | Descrição |
|---|---|---|
| **Visitantes Cadastrados** | `totalVisitors` | Contagem total de visitantes no banco |
| **Encaminhamentos** | `forwardedVisitors` | Soma dos status `em_acompanhamento` + `integrado` |
| **Visitantes Integrados** | `integratedVisitors` | Apenas visitantes com `status = integrado` |
| **Frequência nas Células** | `averageAttendanceRate` | Média percentual de presença calculada sobre todos os encontros registrados |

---

## 10.2 Gráfico de Integração (Aba Dashboard)

**Endpoint:** `GET /dashboard/monthly-stats`

Retorna:
```json
{
  "months": [
    { "month": "YYYY-MM", "total": 12, "integrated": 4 },
    ...
  ]
}
```

Os dados cobrem os **últimos 6 meses** e são agrupados por mês com SQL (`DATE_TRUNC + TO_CHAR`).

**Visualização:** `LineChart` (`fl_chart`)

| Linha | Cor | Campo |
|---|---|---|
| Total de Visitantes | Azul primário (sólida) | `total` |
| Visitantes Integrados | Verde sucesso (tracejada) | `integrated` |

O eixo X exibe o número do mês (`MM` extraído de `YYYY-MM`). O eixo Y é ajustado automaticamente ao valor máximo do período.

---

## 10.3 Painel Administrativo — Aba Relatórios

**Endpoints utilizados:**
- `GET /dashboard/stats` (mesmo da aba Dashboard)
- `GET /dashboard/monthly-stats` (mesmo da aba Dashboard)

### Cards exibidos na aba Relatórios

| Card | Cálculo | Descrição |
|---|---|---|
| **Taxa de Integração** | `integratedVisitors / totalVisitors × 100` | Percentual de visitantes que chegaram à integração |
| **Líderes Ativos** | `totalLeaders` | Contagem de usuários com `role = LIDER` |
| **Visitantes (mês)** | `newVisitorsThisMonth` | Visitantes cadastrados no mês corrente |
| **Média Frequência** | `averageAttendanceRate` | Média de presença nos encontros de todas as células |

### Gráfico de Barras Mensal (Aba Relatórios)

**Visualização:** `BarChart` (`fl_chart`) com barras agrupadas por mês

| Barra | Cor | Campo |
|---|---|---|
| Total de Visitantes | Azul primário | `total` |
| Visitantes Integrados | Verde sucesso | `integrated` |

Exibe os **últimos 6 meses**. Cada grupo tem duas barras lado a lado permitindo comparação visual de captação × integração.

---

## 10.4 Tela do Líder — Aba Presença

**Endpoints utilizados:**
1. `GET /cells/my-cell` → retorna `{ cell: { id, name, ... } }` (célula associada ao líder autenticado)
2. `GET /attendance/cell/:cellId/meetings` → retorna `{ meetings: [...] }`

Estrutura de cada item em `meetings`:

| Campo | Tipo | Descrição |
|---|---|---|
| `meetingDate` | `string (ISO 8601)` | Data do encontro |
| `total` | `number` | Total de membros convocados |
| `present` | `number` | Total de membros presentes |

**Cálculo exibido no card:**
- `% presença = (present / total) × 100`
- Exibe: `"X de Y presentes (Z%)"` por encontro

Os últimos **20 encontros** são retornados, ordenados do mais recente ao mais antigo.

O líder pode criar um novo encontro via `POST /attendance/cell/:cellId/meetings` com o campo `meetingDate`.

---

## 10.5 Tela do Líder — Aba Histórico Espiritual

**Endpoints utilizados:**
1. `GET /cells/my-cell` → obtém o `cellId` do líder
2. `GET /spiritual-history/cell/:cellId` → retorna `{ history: [...] }`

Estrutura de cada item em `history`:

| Campo | Tipo | Descrição |
|---|---|---|
| `id` | `string` | ID do registro |
| `visitorId` | `string` | ID do visitante |
| `visitorName` | `string` | Nome do visitante (join com tabela `visitors`) |
| `eventType` | `string (enum)` | Tipo do evento espiritual |
| `description` | `string` | Observações opcionais |
| `date` | `string (ISO 8601)` | Data do evento |

### Tipos de Evento (`eventType`)

| Valor na API | Rótulo exibido | Ícone |
|---|---|---|
| `enviado_batismo` | Enviado p/ Batismo | 💧 |
| `batizado` | Batizado | 💦 |
| `enviado_treinamento_lider` | Em Treinamento Líder | 🎓 |
| `concluiu_treinamento` | Concluiu Treinamento | 🏆 |
| `tornou_se_lider` | Tornou-se Líder | ⭐ |

O líder pode registrar novos eventos via `POST /spiritual-history` com os campos `visitorId`, `eventType`, `description` e `date`. Os visitantes disponíveis para seleção são carregados via `GET /visitors?cellId=:cellId`.

---

## 10.6 Arquitetura do Fluxo de Indicadores

```
Flutter App
  └─ _DashboardTab / _ReportsTab / _AttendanceTab / _SpiritualHistoryTab
       └─ DioClient (Dio + AuthStorage)
            └─ Express API (Node.js)
                 ├─ DashboardController.getStats()
                 │    └─ GetDashboardStatsUseCase
                 │         └─ IVisitorRepo, IAttendanceRepo, IUserRepo
                 ├─ DashboardController.getMonthlyStats()
                 │    └─ IVisitorRepo.countByMonth(6)  [raw SQL]
                 ├─ AttendanceController.findMeetingsByCell()
                 │    └─ IAttendanceRepo.findMeetingsByCellId(cellId)  [raw SQL]
                 ├─ SpiritualHistoryController.findByCell()
                 │    └─ ISpiritualHistoryRepo.findByCellId(cellId)
                 └─ CellController.findByLeader()
                      └─ ICellRepo.findByLeaderId(req.userId)
```

Todos os endpoints que retornam dados de célula exigem autenticação JWT. O `cellId` do líder é sempre resolvido dinamicamente via `GET /cells/my-cell` usando o `userId` do token, evitando hardcode de IDs no cliente.
