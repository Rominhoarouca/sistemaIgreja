# Plano de Implementação — Transformar Sistema Igreja em SaaS Multi-Tenant

**Decisões do cliente (fixadas):**

- **Multi-tenant, 1 deploy** — uma instalação atende N igrejas; todo dado é isolado por `churchId`.
- **Cobrança:** gateway (principal) **+** atribuição manual. Recomendação de gateway em [`GATEWAY_PAGAMENTO.md`](./GATEWAY_PAGAMENTO.md).
- **Super-admin** (dono do SaaS) gerencia igrejas e planos; **admin da igreja** edita só a própria igreja.
- **Signup:** self-service público **e** onboarding manual, ambos disponíveis.

**Princípio inegociável:** *todas as funcionalidades atuais preservadas.* A camada
multi-tenant é aditiva — nada de fluxo existente pode quebrar.

---

## 1. Modelo de dados (Prisma)

### 1.1 Novos modelos

```prisma
enum PlanTier { STARTER GROWTH COMPLETE }        // exemplo de tiers
enum SubscriptionStatus { TRIALING ACTIVE PAST_DUE CANCELED MANUAL }
enum BillingCycle { MONTHLY YEARLY }

model Church {
  id            String   @id @default(uuid())
  name          String
  slug          String   @unique                 // subdomínio / identificador
  address       String?
  site          String?
  instagram     String?
  youtube       String?
  tiktok         String?
  logoKey       String?  @map("logo_key")         // objeto no MinIO
  menuColor     String   @default("#3F51B5") @map("menu_color")  // hex
  isActive      Boolean  @default(true) @map("is_active")
  createdAt     DateTime @default(now()) @map("created_at")
  updatedAt     DateTime @updatedAt @map("updated_at")

  subscription  Subscription?
  users         User[]
  // ... back-relations de todos os modelos tenant-scoped
  @@map("churches")
}

model Plan {
  id          String   @id @default(uuid())
  tier        PlanTier @unique
  name        String
  description String?
  priceMonth  Int      @map("price_month")   // centavos
  priceYear   Int      @map("price_year")     // centavos
  features    String[] @default([])           // chaves de feature liberadas
  isActive    Boolean  @default(true) @map("is_active")
  createdAt   DateTime @default(now()) @map("created_at")

  subscriptions Subscription[]
  @@map("plans")
}

model Subscription {
  id                     String             @id @default(uuid())
  churchId               String             @unique @map("church_id")
  planId                 String             @map("plan_id")
  status                 SubscriptionStatus @default(TRIALING)
  billingCycle           BillingCycle       @default(MONTHLY) @map("billing_cycle")
  provider               String             @default("manual") // manual|asaas|mercadopago|stripe
  externalCustomerId     String?            @map("external_customer_id")
  externalSubscriptionId String?            @map("external_subscription_id")
  currentPeriodEnd       DateTime?          @map("current_period_end")
  createdAt              DateTime           @default(now()) @map("created_at")
  updatedAt              DateTime           @updatedAt @map("updated_at")

  church Church @relation(fields: [churchId], references: [id], onDelete: Cascade)
  plan   Plan   @relation(fields: [planId], references: [id])
  @@map("subscriptions")
}
```

### 1.2 Papéis (roles)

Adicionar `SUPERADMIN` ao enum `UserRole`. `SUPERADMIN` **não** pertence a nenhuma
igreja (`churchId` nulo) — é o dono do SaaS. Demais papéis (`ADMIN`, `SUPERVISOR`,
`COORDENADOR`, `LIDER`) passam a ter `churchId` obrigatório.

### 1.3 `churchId` em todos os modelos tenant-scoped

Adicionar `churchId String @map("church_id")` + relação `church` + `@@index([churchId])` em:

`User`, `Coordenacao`, `CellType`, `Cell`, `Visitor`, `CellMember`, `CellMeeting`,
`Attendance`, `SpiritualHistory`, `Material`, `Child`.

**Não** recebem `churchId` (globais/compartilhados): `Estado`, `Cidade`, `Bairro`
(geografia é comum a todas as igrejas), `RefreshToken` (ligado ao User), `Plan`.

> Nota sobre `unique`: `CellType.name @unique` e `Coordenacao.coordinadorId @unique`
> hoje são globais. Precisam virar compostos com `churchId`
> (`@@unique([churchId, name])`) para não colidir entre igrejas. `User.email` fica
> `@@unique([churchId, email])` — mesmo e-mail pode existir em igrejas diferentes.

### 1.4 Migração de dados existentes

Criar 1 igreja "seed" e atribuir todos os registros atuais a ela (migração de dados
não-destrutiva), garantindo que o ambiente atual continue funcionando.

---

## 2. Backend (API Node/Express)

### 2.1 JWT com tenant

`LoginUseCase` passa a assinar `{ sub, role, churchId }`. `auth.middleware` popula
`req.churchId`. Novo `requireSuperAdmin`.

### 2.2 Isolamento por tenant (o ponto crítico)

Toda query de modelo tenant-scoped precisa filtrar por `churchId`. Duas camadas:

1. **Repositórios recebem `churchId`** nos métodos de consulta/gravação (assinatura
   explícita) — seguro e legível. Ex.: `cellRepo.findMany(churchId, …)`.
2. **Guard-rail com Prisma Client Extension** (`$extends`) que injeta `where.churchId`
   automaticamente em modelos marcados, como rede de segurança contra esquecimento.

`SUPERADMIN` opera sem filtro (acesso cross-tenant) apenas nas rotas de administração
do SaaS.

### 2.3 Feature gating por plano

- Mapa `PLAN_FEATURES` (chave → tiers que liberam). Ex.:
  `materials`, `whatsapp`, `spiritual_history`, `advanced_dashboard`, `map_geolocation`.
- Middleware `requireFeature('materials')` lê o plano da igreja (cache) e barra 403 se
  não incluso. Aplicado nas rotas dos recursos gated.
- Endpoint `GET /me/features` devolve features ativas para o Flutter esconder/mostrar UI.

### 2.4 Novos módulos (clean architecture, seguindo o padrão atual)

- **Church**: entity, `IChurchRepository`, `PrismaChurchRepository`, use cases
  (`GetChurch`, `UpdateChurch`, `UploadChurchLogo`), `ChurchController`, `church.routes`.
- **Plan**: entity, repo, use cases (CRUD — só SUPERADMIN), controller, rotas.
- **Subscription/Billing**: entity, repo, `IPaymentGateway` (ver GATEWAY doc),
  `ManualBillingUseCase` (super-admin atribui plano), `CreateCheckoutUseCase`,
  `HandleWebhookUseCase`, `billing.routes` (inclui `POST /billing/webhook` público e
  assinado).
- **Signup**: `RegisterChurchUseCase` (self-service: cria Church + Subscription trial +
  primeiro ADMIN, transação). Rota pública `POST /public/signup`.
- **Super-admin**: rotas `/admin/churches`, `/admin/plans`, `/admin/subscriptions`
  protegidas por `requireSuperAdmin`.

### 2.5 Logo no MinIO

Reusar `MinioService`. Chave `churches/{churchId}/logo/{uuid}`. `UploadChurchLogo`
grava e salva `logoKey`; endpoint devolve URL assinada (padrão dos materiais).

### 2.6 Container / rotas

Registrar novos repositórios, use cases e controllers no `container/index.ts` e montar
as rotas em `app.ts`. Injetar `PaymentGateway` conforme `PAYMENT_PROVIDER`.

---

## 3. Frontend (Flutter)

### 3.1 Sessão com tenant + features

- Guardar `churchId`, plano e lista de `features` na sessão (`auth_storage`).
- Carregar dados da igreja (nome, logo, `menuColor`) no login / bootstrap.

### 3.2 Tematização dinâmica (cor do menu + logo)

- `ThemeController` passa a aceitar a **cor do menu** vinda da igreja (`menuColor`),
  sobrepondo a cor do AppBar/menu lateral. Logo da igreja exibida no header/drawer
  (via URL assinada do MinIO), com fallback para o logo padrão.

### 3.3 Gating de UI por feature

- Helper `context.hasFeature('materials')` esconde itens de menu/telas de recursos não
  inclusos no plano, com CTA de upgrade. Nada some do código — só da UI conforme plano.

### 3.4 Novas telas

- **Admin da Igreja** (papel ADMIN): editar Nome, endereço, site, redes sociais
  (instagram/youtube/tiktok), **cor do menu** (color picker), **logo** (upload MinIO),
  ver plano atual e botão "assinar/alterar plano" (checkout do gateway).
- **Super-admin** (papel SUPERADMIN): listar/criar igrejas, gerenciar planos, atribuir
  plano manualmente, ver assinaturas/status.
- **Signup público**: tela na landing/app para uma igreja se cadastrar e escolher plano.

---

## 4. Fases de entrega (ordem de execução)

| Fase | Escopo | Resultado |
|---|---|---|
| **1. Schema + migração** | Modelos Church/Plan/Subscription, `churchId` em todos os modelos, `SUPERADMIN`, migração de dados p/ igreja seed, seeds de planos | Banco multi-tenant, ambiente atual preservado |
| **2. Isolamento backend** | JWT com churchId, middleware, repos filtrando por tenant, guard-rail `$extends` | Dados isolados por igreja |
| **3. Church API + logo + tema** | CRUD igreja, upload logo MinIO, endpoint features | Admin edita dados da igreja |
| **4. Feature gating** | Mapa de features, `requireFeature`, `/me/features` | Recursos liberados por plano |
| **5. Billing** | `IPaymentGateway`, atribuição manual, checkout + webhook (1 provider) | Cobrança funcionando |
| **6. Signup** | Self-service + onboarding manual | Novas igrejas entram |
| **7. Flutter** | Sessão tenant, tema dinâmico, gating UI, telas admin/super-admin/signup | Produto SaaS ponta a ponta |

Cada fase compila/roda antes da próxima. Migrations revisadas antes de aplicar.

---

## 5. Riscos & cuidados

- **Vazamento entre tenants**: mitigado pela dupla camada (repos explícitos +
  `$extends`). Testes de integração checando isolamento.
- **Unicidade global → composta**: revisar todos `@unique` (email, cellType.name,
  coordinadorId). Migração precisa tratar duplicidade potencial.
- **Migração de dados**: rodar em transação; backup antes. Ambiente atual = 1 igreja.
- **Webhook billing**: assinatura + idempotência obrigatórias (ver GATEWAY doc).
- **Preservar funcionalidades**: gating esconde na UI e barra na API, mas o código dos
  recursos permanece intacto.

---

## 6. Definição de planos (proposta inicial — ajustável)

| Feature \\ Plano | STARTER | GROWTH | COMPLETE |
|---|:---:|:---:|:---:|
| Células, membros, visitantes, presença | ✅ | ✅ | ✅ |
| Dashboard básico | ✅ | ✅ | ✅ |
| Histórico espiritual | — | ✅ | ✅ |
| Materiais (upload MinIO) | — | ✅ | ✅ |
| Coordenações / hierarquia | — | ✅ | ✅ |
| Dashboard avançado + mapa/geo | — | — | ✅ |
| WhatsApp / notificações | — | — | ✅ |
| Nº de líderes/células | limitado | maior | ilimitado |

Preços e limites a definir com o cliente.
