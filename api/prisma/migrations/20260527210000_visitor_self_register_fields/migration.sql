-- Migration: Add self-registration fields to visitors table
ALTER TABLE "visitors"
  ADD COLUMN "birth_date"        TIMESTAMP(3),
  ADD COLUMN "marital_status"    TEXT,
  ADD COLUMN "is_baptized"       BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN "known_person_name" TEXT,
  ADD COLUMN "interests"         TEXT[] DEFAULT ARRAY[]::TEXT[] NOT NULL;
