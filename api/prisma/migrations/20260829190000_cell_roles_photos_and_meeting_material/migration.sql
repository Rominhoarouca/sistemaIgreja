-- Papel dentro da célula: vice-líder e anfitrião.
--
-- Tipo novo (não é ALTER TYPE ADD VALUE), então pode ser usado em DDL na mesma
-- migration sem esbarrar na restrição do Postgres.
DO $$ BEGIN
  CREATE TYPE "CellMemberRole" AS ENUM ('MEMBRO', 'VICE_LIDER', 'ANFITRIAO');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE "cell_members"
  ADD COLUMN IF NOT EXISTS "role_in_cell" "CellMemberRole" NOT NULL DEFAULT 'MEMBRO';

-- Foto de membro e de visitante. Guardamos só a chave do objeto no MinIO; a
-- URL assinada é gerada na leitura.
ALTER TABLE "cell_members" ADD COLUMN IF NOT EXISTS "photo_key" TEXT;
ALTER TABLE "visitors"     ADD COLUMN IF NOT EXISTS "photo_key" TEXT;

-- Lição do encontro apontando para um material do acervo da célula.
-- `lesson` (texto livre) continua existindo para quando a lição não está lá.
ALTER TABLE "cell_meetings" ADD COLUMN IF NOT EXISTS "material_id" TEXT;

CREATE INDEX IF NOT EXISTS "cell_meetings_material_id_idx"
  ON "cell_meetings" ("material_id");

DO $$ BEGIN
  ALTER TABLE "cell_meetings"
    ADD CONSTRAINT "cell_meetings_material_id_fkey"
    FOREIGN KEY ("material_id") REFERENCES "materials" ("id")
    ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
