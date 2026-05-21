-- CreateTable
CREATE TABLE "cell_members" (
    "id" TEXT NOT NULL,
    "cell_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "email" TEXT,
    "address" TEXT,
    "neighborhood" TEXT,
    "city" TEXT,
    "leader_id" TEXT,
    "source_visitor_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "cell_members_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "cell_members_source_visitor_id_key" ON "cell_members"("source_visitor_id");

-- CreateIndex
CREATE INDEX "cell_members_cell_id_idx" ON "cell_members"("cell_id");

-- CreateIndex
CREATE INDEX "cell_members_leader_id_idx" ON "cell_members"("leader_id");

-- AddForeignKey
ALTER TABLE "cell_members" ADD CONSTRAINT "cell_members_cell_id_fkey" FOREIGN KEY ("cell_id") REFERENCES "cells"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cell_members" ADD CONSTRAINT "cell_members_leader_id_fkey" FOREIGN KEY ("leader_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cell_members" ADD CONSTRAINT "cell_members_source_visitor_id_fkey" FOREIGN KEY ("source_visitor_id") REFERENCES "visitors"("id") ON DELETE SET NULL ON UPDATE CASCADE;
