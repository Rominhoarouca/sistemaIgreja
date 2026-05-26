-- AlterEnum
ALTER TYPE "UserRole" ADD VALUE 'SUPERVISOR';

-- DropIndex
DROP INDEX "cells_leader_id_key";

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "supervisor_id" TEXT;

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_supervisor_id_fkey" FOREIGN KEY ("supervisor_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
