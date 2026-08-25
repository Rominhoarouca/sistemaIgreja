/*
  Warnings:

  - Added the required column `updated_at` to the `children` table without a default value. This is not possible if the table is not empty.

*/
-- CreateEnum
CREATE TYPE "KidsSessionStatus" AS ENUM ('OPEN', 'CLOSED');

-- CreateEnum
CREATE TYPE "KidsCheckinStatus" AS ENUM ('CHECKED_IN', 'CHECKED_OUT', 'NO_SHOW');

-- CreateEnum
CREATE TYPE "KidsCheckMethod" AS ENUM ('QR', 'CODE', 'MANUAL');

-- CreateEnum
CREATE TYPE "KidsNoteKind" AS ENUM ('INDIVIDUAL', 'CLASS');

-- CreateEnum
CREATE TYPE "KidsAlertLevel" AS ENUM ('INFO', 'URGENT', 'EMERGENCY');

-- CreateEnum
CREATE TYPE "KidsAlertStatus" AS ENUM ('OPEN', 'ACKNOWLEDGED', 'RESOLVED');

-- CreateEnum
CREATE TYPE "KidsChannel" AS ENUM ('PUSH', 'WHATSAPP', 'SMS', 'CALL', 'CRITICAL_PUSH');

-- CreateEnum
CREATE TYPE "KidsDeliveryStatus" AS ENUM ('QUEUED', 'SENT', 'DELIVERED', 'READ', 'FAILED');

-- CreateEnum
CREATE TYPE "KidsTeacherRole" AS ENUM ('TITULAR', 'AUXILIAR');

-- CreateEnum
CREATE TYPE "GuardianRelation" AS ENUM ('PAI', 'MAE', 'AVO', 'TIO', 'RESPONSAVEL_LEGAL', 'OUTRO');

-- Os valores 'KIDS'/'RESPONSAVEL' do enum UserRole são adicionados na migração
-- anterior (20260825171800_kids_user_roles), isolada por exigência do Postgres.

-- DropForeignKey
ALTER TABLE "children" DROP CONSTRAINT "children_user_id_fkey";

-- AlterTable
ALTER TABLE "children" ADD COLUMN     "allergies" TEXT,
ADD COLUMN     "authorized_pickup" TEXT,
ADD COLUMN     "cell_member_id" TEXT,
ADD COLUMN     "disabilities" TEXT,
ADD COLUMN     "gender" "Gender",
ADD COLUMN     "is_active" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "medical_notes" TEXT,
ADD COLUMN     "medications" TEXT,
ADD COLUMN     "photo_key" TEXT,
-- DEFAULT no ADD COLUMN: `children` já tem linhas em produção (filhos
-- declarados no perfil), e NOT NULL sem default falharia na migração.
ADD COLUMN     "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "visitor_id" TEXT,
ALTER COLUMN "user_id" DROP NOT NULL;

-- CreateTable
CREATE TABLE "kids_rooms" (
    "id" TEXT NOT NULL,
    "church_id" TEXT,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "capacity" INTEGER NOT NULL,
    "min_age_months" INTEGER,
    "max_age_months" INTEGER,
    "color" TEXT NOT NULL DEFAULT '#3F51B5',
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "kids_rooms_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "kids_room_teachers" (
    "id" TEXT NOT NULL,
    "church_id" TEXT,
    "room_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "role" "KidsTeacherRole" NOT NULL DEFAULT 'AUXILIAR',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "kids_room_teachers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "kids_sessions" (
    "id" TEXT NOT NULL,
    "church_id" TEXT,
    "room_id" TEXT NOT NULL,
    "service_date" DATE NOT NULL,
    "service_name" TEXT NOT NULL DEFAULT 'Culto',
    "status" "KidsSessionStatus" NOT NULL DEFAULT 'OPEN',
    "opened_by_id" TEXT NOT NULL,
    "opened_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "closed_by_id" TEXT,
    "closed_at" TIMESTAMP(3),
    "lesson" TEXT,
    "capacity_override" INTEGER,

    CONSTRAINT "kids_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "kids_guardians" (
    "id" TEXT NOT NULL,
    "church_id" TEXT,
    "child_id" TEXT NOT NULL,
    "user_id" TEXT,
    "name" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "has_whatsapp" BOOLEAN NOT NULL DEFAULT true,
    "relation" "GuardianRelation" NOT NULL DEFAULT 'RESPONSAVEL_LEGAL',
    "is_primary" BOOLEAN NOT NULL DEFAULT false,
    "can_pickup" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "kids_guardians_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "kids_checkins" (
    "id" TEXT NOT NULL,
    "church_id" TEXT,
    "session_id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "status" "KidsCheckinStatus" NOT NULL DEFAULT 'CHECKED_IN',
    "badge_code" TEXT NOT NULL,
    "checkin_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "checkin_by_id" TEXT NOT NULL,
    "checkin_method" "KidsCheckMethod" NOT NULL,
    "checkin_guardian_id" TEXT,
    "pickup_code_hash" TEXT,
    "pickup_code_last2" TEXT,
    "pickup_attempts" INTEGER NOT NULL DEFAULT 0,
    "pickup_locked_until" TIMESTAMP(3),
    "checkout_at" TIMESTAMP(3),
    "checkout_by_id" TEXT,
    "checkout_method" "KidsCheckMethod",
    "checkout_guardian_id" TEXT,
    "checkout_guardian_name" TEXT,
    "checkout_reason" TEXT,

    CONSTRAINT "kids_checkins_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "kids_notes" (
    "id" TEXT NOT NULL,
    "church_id" TEXT,
    "session_id" TEXT NOT NULL,
    "kind" "KidsNoteKind" NOT NULL,
    "child_id" TEXT,
    "checkin_id" TEXT,
    "body" TEXT NOT NULL,
    "visible_to_guardian" BOOLEAN NOT NULL DEFAULT true,
    "author_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "kids_notes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "kids_alerts" (
    "id" TEXT NOT NULL,
    "church_id" TEXT,
    "session_id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "checkin_id" TEXT,
    "level" "KidsAlertLevel" NOT NULL,
    "status" "KidsAlertStatus" NOT NULL DEFAULT 'OPEN',
    "message" TEXT NOT NULL,
    "created_by_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "acknowledged_at" TIMESTAMP(3),
    "acknowledged_by_guardian_id" TEXT,
    "resolved_at" TIMESTAMP(3),
    "resolved_by_id" TEXT,

    CONSTRAINT "kids_alerts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "kids_alert_deliveries" (
    "id" TEXT NOT NULL,
    "church_id" TEXT,
    "alert_id" TEXT NOT NULL,
    "guardian_id" TEXT,
    "user_id" TEXT,
    "channel" "KidsChannel" NOT NULL,
    "status" "KidsDeliveryStatus" NOT NULL DEFAULT 'QUEUED',
    "provider_message_id" TEXT,
    "error" TEXT,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "queued_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "sent_at" TIMESTAMP(3),
    "delivered_at" TIMESTAMP(3),
    "read_at" TIMESTAMP(3),

    CONSTRAINT "kids_alert_deliveries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "device_tokens" (
    "id" TEXT NOT NULL,
    "church_id" TEXT,
    "user_id" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "platform" TEXT NOT NULL,
    "app_version" TEXT,
    "critical_opt_in" BOOLEAN NOT NULL DEFAULT false,
    "last_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "device_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "kids_qr_nonces" (
    "jti" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "used_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "kids_qr_nonces_pkey" PRIMARY KEY ("jti")
);

-- CreateIndex
CREATE INDEX "kids_rooms_church_id_idx" ON "kids_rooms"("church_id");

-- CreateIndex
CREATE INDEX "kids_room_teachers_church_id_idx" ON "kids_room_teachers"("church_id");

-- CreateIndex
CREATE INDEX "kids_room_teachers_user_id_idx" ON "kids_room_teachers"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "kids_room_teachers_room_id_user_id_key" ON "kids_room_teachers"("room_id", "user_id");

-- CreateIndex
CREATE INDEX "kids_sessions_church_id_idx" ON "kids_sessions"("church_id");

-- CreateIndex
CREATE INDEX "kids_sessions_room_id_service_date_idx" ON "kids_sessions"("room_id", "service_date");

-- CreateIndex
CREATE UNIQUE INDEX "kids_sessions_room_id_service_date_service_name_key" ON "kids_sessions"("room_id", "service_date", "service_name");

-- CreateIndex
CREATE INDEX "kids_guardians_church_id_idx" ON "kids_guardians"("church_id");

-- CreateIndex
CREATE INDEX "kids_guardians_child_id_idx" ON "kids_guardians"("child_id");

-- CreateIndex
CREATE INDEX "kids_guardians_user_id_idx" ON "kids_guardians"("user_id");

-- CreateIndex
CREATE INDEX "kids_guardians_church_id_phone_idx" ON "kids_guardians"("church_id", "phone");

-- CreateIndex
CREATE INDEX "kids_checkins_church_id_idx" ON "kids_checkins"("church_id");

-- CreateIndex
CREATE INDEX "kids_checkins_status_idx" ON "kids_checkins"("status");

-- CreateIndex
CREATE INDEX "kids_checkins_church_id_checkin_at_idx" ON "kids_checkins"("church_id", "checkin_at");

-- CreateIndex
CREATE UNIQUE INDEX "kids_checkins_session_id_child_id_key" ON "kids_checkins"("session_id", "child_id");

-- CreateIndex
CREATE UNIQUE INDEX "kids_checkins_session_id_badge_code_key" ON "kids_checkins"("session_id", "badge_code");

-- CreateIndex
CREATE INDEX "kids_notes_church_id_idx" ON "kids_notes"("church_id");

-- CreateIndex
CREATE INDEX "kids_notes_session_id_kind_idx" ON "kids_notes"("session_id", "kind");

-- CreateIndex
CREATE INDEX "kids_notes_child_id_idx" ON "kids_notes"("child_id");

-- CreateIndex
CREATE INDEX "kids_alerts_church_id_idx" ON "kids_alerts"("church_id");

-- CreateIndex
CREATE INDEX "kids_alerts_session_id_status_idx" ON "kids_alerts"("session_id", "status");

-- CreateIndex
CREATE INDEX "kids_alerts_child_id_idx" ON "kids_alerts"("child_id");

-- CreateIndex
CREATE INDEX "kids_alert_deliveries_church_id_idx" ON "kids_alert_deliveries"("church_id");

-- CreateIndex
CREATE INDEX "kids_alert_deliveries_alert_id_idx" ON "kids_alert_deliveries"("alert_id");

-- CreateIndex
CREATE INDEX "kids_alert_deliveries_status_idx" ON "kids_alert_deliveries"("status");

-- CreateIndex
CREATE INDEX "kids_alert_deliveries_church_id_channel_queued_at_idx" ON "kids_alert_deliveries"("church_id", "channel", "queued_at");

-- CreateIndex
CREATE UNIQUE INDEX "device_tokens_token_key" ON "device_tokens"("token");

-- CreateIndex
CREATE INDEX "device_tokens_church_id_idx" ON "device_tokens"("church_id");

-- CreateIndex
CREATE INDEX "device_tokens_user_id_idx" ON "device_tokens"("user_id");

-- CreateIndex
CREATE INDEX "kids_qr_nonces_expires_at_idx" ON "kids_qr_nonces"("expires_at");

-- CreateIndex
CREATE INDEX "children_user_id_idx" ON "children"("user_id");

-- CreateIndex
CREATE INDEX "children_church_id_name_idx" ON "children"("church_id", "name");

-- AddForeignKey
ALTER TABLE "children" ADD CONSTRAINT "children_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "children" ADD CONSTRAINT "children_cell_member_id_fkey" FOREIGN KEY ("cell_member_id") REFERENCES "cell_members"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "children" ADD CONSTRAINT "children_visitor_id_fkey" FOREIGN KEY ("visitor_id") REFERENCES "visitors"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_rooms" ADD CONSTRAINT "kids_rooms_church_id_fkey" FOREIGN KEY ("church_id") REFERENCES "churches"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_room_teachers" ADD CONSTRAINT "kids_room_teachers_church_id_fkey" FOREIGN KEY ("church_id") REFERENCES "churches"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_room_teachers" ADD CONSTRAINT "kids_room_teachers_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "kids_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_room_teachers" ADD CONSTRAINT "kids_room_teachers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_sessions" ADD CONSTRAINT "kids_sessions_church_id_fkey" FOREIGN KEY ("church_id") REFERENCES "churches"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_sessions" ADD CONSTRAINT "kids_sessions_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "kids_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_sessions" ADD CONSTRAINT "kids_sessions_opened_by_id_fkey" FOREIGN KEY ("opened_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_guardians" ADD CONSTRAINT "kids_guardians_church_id_fkey" FOREIGN KEY ("church_id") REFERENCES "churches"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_guardians" ADD CONSTRAINT "kids_guardians_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_guardians" ADD CONSTRAINT "kids_guardians_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_checkins" ADD CONSTRAINT "kids_checkins_church_id_fkey" FOREIGN KEY ("church_id") REFERENCES "churches"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_checkins" ADD CONSTRAINT "kids_checkins_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "kids_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_checkins" ADD CONSTRAINT "kids_checkins_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_checkins" ADD CONSTRAINT "kids_checkins_checkin_by_id_fkey" FOREIGN KEY ("checkin_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_checkins" ADD CONSTRAINT "kids_checkins_checkin_guardian_id_fkey" FOREIGN KEY ("checkin_guardian_id") REFERENCES "kids_guardians"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_checkins" ADD CONSTRAINT "kids_checkins_checkout_guardian_id_fkey" FOREIGN KEY ("checkout_guardian_id") REFERENCES "kids_guardians"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_notes" ADD CONSTRAINT "kids_notes_church_id_fkey" FOREIGN KEY ("church_id") REFERENCES "churches"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_notes" ADD CONSTRAINT "kids_notes_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "kids_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_notes" ADD CONSTRAINT "kids_notes_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_notes" ADD CONSTRAINT "kids_notes_checkin_id_fkey" FOREIGN KEY ("checkin_id") REFERENCES "kids_checkins"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_notes" ADD CONSTRAINT "kids_notes_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_alerts" ADD CONSTRAINT "kids_alerts_church_id_fkey" FOREIGN KEY ("church_id") REFERENCES "churches"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_alerts" ADD CONSTRAINT "kids_alerts_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "kids_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_alerts" ADD CONSTRAINT "kids_alerts_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_alerts" ADD CONSTRAINT "kids_alerts_checkin_id_fkey" FOREIGN KEY ("checkin_id") REFERENCES "kids_checkins"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_alerts" ADD CONSTRAINT "kids_alerts_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_alert_deliveries" ADD CONSTRAINT "kids_alert_deliveries_church_id_fkey" FOREIGN KEY ("church_id") REFERENCES "churches"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_alert_deliveries" ADD CONSTRAINT "kids_alert_deliveries_alert_id_fkey" FOREIGN KEY ("alert_id") REFERENCES "kids_alerts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kids_alert_deliveries" ADD CONSTRAINT "kids_alert_deliveries_guardian_id_fkey" FOREIGN KEY ("guardian_id") REFERENCES "kids_guardians"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "device_tokens" ADD CONSTRAINT "device_tokens_church_id_fkey" FOREIGN KEY ("church_id") REFERENCES "churches"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "device_tokens" ADD CONSTRAINT "device_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
