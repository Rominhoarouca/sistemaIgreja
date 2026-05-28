-- Migration: Add member attendance support
-- Makes visitor_id nullable and adds optional member_id to attendances

-- Step 1: Make visitor_id nullable
ALTER TABLE "attendances" ALTER COLUMN "visitor_id" DROP NOT NULL;

-- Step 2: Add member_id column (nullable FK to cell_members)
ALTER TABLE "attendances" ADD COLUMN "member_id" TEXT;
ALTER TABLE "attendances" ADD CONSTRAINT "attendances_member_id_fkey"
  FOREIGN KEY ("member_id") REFERENCES "cell_members"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Step 3: Add check constraint — at least one participant ID must be set
ALTER TABLE "attendances" ADD CONSTRAINT "attendance_participant_required"
  CHECK (("visitor_id" IS NOT NULL) OR ("member_id" IS NOT NULL));

-- Step 4: Drop old unique constraint
ALTER TABLE "attendances" DROP CONSTRAINT IF EXISTS "attendances_visitor_id_cell_id_meeting_date_key";

-- Step 5: Partial unique index for visitor attendance
CREATE UNIQUE INDEX "attendances_visitor_cell_date_unique"
  ON "attendances" ("visitor_id", "cell_id", "meeting_date")
  WHERE "visitor_id" IS NOT NULL;

-- Step 6: Partial unique index for member attendance
CREATE UNIQUE INDEX "attendances_member_cell_date_unique"
  ON "attendances" ("member_id", "cell_id", "meeting_date")
  WHERE "member_id" IS NOT NULL;
