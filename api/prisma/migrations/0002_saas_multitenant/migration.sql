-- ═══════════════════════════════════════════════════════════════════════════
-- SaaS multi-tenant migration
-- Aditiva e NÃO destrutiva: cria Church/Plan/Subscription, adiciona church_id
-- em todos os modelos tenant-scoped e faz backfill dos dados existentes para
-- uma igreja "seed", preservando 100% das funcionalidades atuais.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── Enums ────────────────────────────────────────────────────────────────────
ALTER TYPE "UserRole" ADD VALUE IF NOT EXISTS 'SUPERADMIN';

CREATE TYPE "PlanTier" AS ENUM ('FREE', 'STARTER', 'GROWTH', 'COMPLETE');
CREATE TYPE "SubscriptionStatus" AS ENUM ('TRIALING', 'ACTIVE', 'PAST_DUE', 'CANCELED', 'MANUAL');
CREATE TYPE "BillingCycle" AS ENUM ('MONTHLY', 'YEARLY');

-- ── Church ───────────────────────────────────────────────────────────────────
CREATE TABLE "churches" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "address" TEXT,
    "site" TEXT,
    "instagram" TEXT,
    "youtube" TEXT,
    "tiktok" TEXT,
    "logo_key" TEXT,
    "menu_color" TEXT NOT NULL DEFAULT '#3F51B5',
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "churches_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "churches_slug_key" ON "churches"("slug");

-- ── Plan ─────────────────────────────────────────────────────────────────────
CREATE TABLE "plans" (
    "id" TEXT NOT NULL,
    "tier" "PlanTier" NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "price_month" INTEGER NOT NULL DEFAULT 0,
    "price_year" INTEGER NOT NULL DEFAULT 0,
    "features" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "plans_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "plans_tier_key" ON "plans"("tier");

-- ── Subscription ─────────────────────────────────────────────────────────────
CREATE TABLE "subscriptions" (
    "id" TEXT NOT NULL,
    "church_id" TEXT NOT NULL,
    "plan_id" TEXT NOT NULL,
    "status" "SubscriptionStatus" NOT NULL DEFAULT 'TRIALING',
    "billing_cycle" "BillingCycle" NOT NULL DEFAULT 'MONTHLY',
    "provider" TEXT NOT NULL DEFAULT 'manual',
    "external_customer_id" TEXT,
    "external_subscription_id" TEXT,
    "current_period_end" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "subscriptions_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "subscriptions_church_id_key" ON "subscriptions"("church_id");
CREATE INDEX "subscriptions_plan_id_idx" ON "subscriptions"("plan_id");

-- ── church_id em modelos tenant-scoped ───────────────────────────────────────
ALTER TABLE "users" ADD COLUMN "church_id" TEXT;
ALTER TABLE "coordenacoes" ADD COLUMN "church_id" TEXT;
ALTER TABLE "children" ADD COLUMN "church_id" TEXT;
ALTER TABLE "cell_types" ADD COLUMN "church_id" TEXT;
ALTER TABLE "cells" ADD COLUMN "church_id" TEXT;
ALTER TABLE "visitors" ADD COLUMN "church_id" TEXT;
ALTER TABLE "cell_members" ADD COLUMN "church_id" TEXT;
ALTER TABLE "cell_meetings" ADD COLUMN "church_id" TEXT;
ALTER TABLE "attendances" ADD COLUMN "church_id" TEXT;
ALTER TABLE "spiritual_histories" ADD COLUMN "church_id" TEXT;
ALTER TABLE "materials" ADD COLUMN "church_id" TEXT;

-- ── Unicidade global → composta por igreja ───────────────────────────────────
DROP INDEX IF EXISTS "users_email_key";
CREATE UNIQUE INDEX "users_church_id_email_key" ON "users"("church_id", "email");
CREATE INDEX "users_church_id_idx" ON "users"("church_id");

DROP INDEX IF EXISTS "cell_types_name_key";
CREATE UNIQUE INDEX "cell_types_church_id_name_key" ON "cell_types"("church_id", "name");

-- ── Índices church_id ────────────────────────────────────────────────────────
CREATE INDEX "coordenacoes_church_id_idx" ON "coordenacoes"("church_id");
CREATE INDEX "children_church_id_idx" ON "children"("church_id");
CREATE INDEX "cell_types_church_id_idx" ON "cell_types"("church_id");
CREATE INDEX "cells_church_id_idx" ON "cells"("church_id");
CREATE INDEX "visitors_church_id_idx" ON "visitors"("church_id");
CREATE INDEX "cell_members_church_id_idx" ON "cell_members"("church_id");
CREATE INDEX "cell_meetings_church_id_idx" ON "cell_meetings"("church_id");
CREATE INDEX "attendances_church_id_idx" ON "attendances"("church_id");
CREATE INDEX "spiritual_histories_church_id_idx" ON "spiritual_histories"("church_id");
CREATE INDEX "materials_church_id_idx" ON "materials"("church_id");

-- ── Foreign keys ─────────────────────────────────────────────────────────────
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_church_id_fkey" FOREIGN KEY ("church_id") REFERENCES "churches"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "plans"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "users" ADD CONSTRAINT "users_church_id_fkey" FOREIGN KEY ("church_id") REFERENCES "churches"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "coordenacoes" ADD CONSTRAINT "coordenacoes_church_id_fkey" FOREIGN KEY ("church_id") REFERENCES "churches"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "children" ADD CONSTRAINT "children_church_id_fkey" FOREIGN KEY ("church_id") REFERENCES "churches"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "cell_types" ADD CONSTRAINT "cell_types_church_id_fkey" FOREIGN KEY ("church_id") REFERENCES "churches"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "cells" ADD CONSTRAINT "cells_church_id_fkey" FOREIGN KEY ("church_id") REFERENCES "churches"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "visitors" ADD CONSTRAINT "visitors_church_id_fkey" FOREIGN KEY ("church_id") REFERENCES "churches"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "cell_members" ADD CONSTRAINT "cell_members_church_id_fkey" FOREIGN KEY ("church_id") REFERENCES "churches"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "cell_meetings" ADD CONSTRAINT "cell_meetings_church_id_fkey" FOREIGN KEY ("church_id") REFERENCES "churches"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "attendances" ADD CONSTRAINT "attendances_church_id_fkey" FOREIGN KEY ("church_id") REFERENCES "churches"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "spiritual_histories" ADD CONSTRAINT "spiritual_histories_church_id_fkey" FOREIGN KEY ("church_id") REFERENCES "churches"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "materials" ADD CONSTRAINT "materials_church_id_fkey" FOREIGN KEY ("church_id") REFERENCES "churches"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- ═══════════════════════════════════════════════════════════════════════════
-- BACKFILL — igreja seed + planos + associação dos dados existentes
-- ═══════════════════════════════════════════════════════════════════════════

-- Igreja seed (recebe todos os dados atuais). Idempotente.
INSERT INTO "churches" ("id", "name", "slug", "menu_color", "is_active", "created_at", "updated_at")
VALUES ('00000000-0000-0000-0000-000000000001', 'Igreja Principal', 'principal', '#3F51B5', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT ("id") DO NOTHING;

-- Planos padrão. features = chaves liberadas (ver PLAN_FEATURES no backend).
INSERT INTO "plans" ("id", "tier", "name", "description", "price_month", "price_year", "features", "is_active", "created_at", "updated_at") VALUES
  ('00000000-0000-0000-0000-0000000000f0', 'FREE',     'Free',     'Recursos essenciais para começar',        0,     0,     ARRAY[]::TEXT[], true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  ('00000000-0000-0000-0000-0000000000f1', 'STARTER',  'Starter',  'Para células em crescimento',              4900,  49000, ARRAY['spiritual_history','coordenacao']::TEXT[], true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  ('00000000-0000-0000-0000-0000000000f2', 'GROWTH',   'Growth',   'Gestão completa de discipulado',           9900,  99000, ARRAY['spiritual_history','coordenacao','materials','map_geolocation','advanced_dashboard']::TEXT[], true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  ('00000000-0000-0000-0000-0000000000f3', 'COMPLETE', 'Complete', 'Todos os recursos, sem limites',           19900, 199000, ARRAY['spiritual_history','coordenacao','materials','map_geolocation','advanced_dashboard','whatsapp']::TEXT[], true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT ("tier") DO NOTHING;

-- Backfill church_id nos dados existentes (só linhas órfãs).
UPDATE "users"               SET "church_id" = '00000000-0000-0000-0000-000000000001' WHERE "church_id" IS NULL;
UPDATE "coordenacoes"        SET "church_id" = '00000000-0000-0000-0000-000000000001' WHERE "church_id" IS NULL;
UPDATE "children"            SET "church_id" = '00000000-0000-0000-0000-000000000001' WHERE "church_id" IS NULL;
UPDATE "cell_types"          SET "church_id" = '00000000-0000-0000-0000-000000000001' WHERE "church_id" IS NULL;
UPDATE "cells"               SET "church_id" = '00000000-0000-0000-0000-000000000001' WHERE "church_id" IS NULL;
UPDATE "visitors"            SET "church_id" = '00000000-0000-0000-0000-000000000001' WHERE "church_id" IS NULL;
UPDATE "cell_members"        SET "church_id" = '00000000-0000-0000-0000-000000000001' WHERE "church_id" IS NULL;
UPDATE "cell_meetings"       SET "church_id" = '00000000-0000-0000-0000-000000000001' WHERE "church_id" IS NULL;
UPDATE "attendances"         SET "church_id" = '00000000-0000-0000-0000-000000000001' WHERE "church_id" IS NULL;
UPDATE "spiritual_histories" SET "church_id" = '00000000-0000-0000-0000-000000000001' WHERE "church_id" IS NULL;
UPDATE "materials"           SET "church_id" = '00000000-0000-0000-0000-000000000001' WHERE "church_id" IS NULL;

-- Assinatura da igreja seed no plano COMPLETE (preserva acesso a tudo).
INSERT INTO "subscriptions" ("id", "church_id", "plan_id", "status", "billing_cycle", "provider", "created_at", "updated_at")
VALUES ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000f3', 'MANUAL', 'MONTHLY', 'manual', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT ("church_id") DO NOTHING;
