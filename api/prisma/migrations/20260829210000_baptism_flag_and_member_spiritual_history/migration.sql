-- Membro também tem situação de batismo (visitante já tinha `is_baptized`).
ALTER TABLE "cell_members"
  ADD COLUMN IF NOT EXISTS "is_baptized" BOOLEAN NOT NULL DEFAULT false;

-- Histórico espiritual passa a aceitar membro, não só visitante.
--
-- `visitor_id` vira opcional e ganha um irmão `member_id`; exatamente um dos
-- dois é preenchido. As linhas existentes já têm visitor_id, então nada quebra.
ALTER TABLE "spiritual_histories" ALTER COLUMN "visitor_id" DROP NOT NULL;
ALTER TABLE "spiritual_histories" ADD COLUMN IF NOT EXISTS "member_id" TEXT;

CREATE INDEX IF NOT EXISTS "spiritual_histories_member_id_idx"
  ON "spiritual_histories" ("member_id");

DO $$ BEGIN
  ALTER TABLE "spiritual_histories"
    ADD CONSTRAINT "spiritual_histories_member_id_fkey"
    FOREIGN KEY ("member_id") REFERENCES "cell_members" ("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Garante no banco o "um ou outro": sem isso um evento poderia nascer órfão
-- (nenhum dos dois) e sumir de todas as listagens.
DO $$ BEGIN
  ALTER TABLE "spiritual_histories"
    ADD CONSTRAINT "spiritual_histories_person_check"
    CHECK (("visitor_id" IS NOT NULL) <> ("member_id" IS NOT NULL));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
