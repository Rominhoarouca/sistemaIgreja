-- Informações demográficas: gênero (visitantes e membros de célula) e
-- nascimento/estado civil para membros de célula, que antes só tinham contato.

-- CreateEnum
CREATE TYPE "Gender" AS ENUM ('MASCULINO', 'FEMININO');

-- AlterTable
ALTER TABLE "visitors" ADD COLUMN "gender" "Gender";

-- AlterTable
ALTER TABLE "cell_members"
  ADD COLUMN "birth_date" TIMESTAMP(3),
  ADD COLUMN "gender" "Gender",
  ADD COLUMN "marital_status" TEXT;

-- Índices para as agregações do painel demográfico, que filtram por igreja
CREATE INDEX "visitors_church_id_gender_idx" ON "visitors"("church_id", "gender");
CREATE INDEX "cell_members_church_id_gender_idx" ON "cell_members"("church_id", "gender");
