-- CreateTable
CREATE TABLE "cell_meetings" (
    "id" TEXT NOT NULL,
    "cell_id" TEXT NOT NULL,
    "meeting_date" DATE NOT NULL,
    "created_by_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "cell_meetings_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "cell_meetings_cell_id_meeting_date_key" ON "cell_meetings"("cell_id", "meeting_date");

-- AddForeignKey
ALTER TABLE "cell_meetings" ADD CONSTRAINT "cell_meetings_cell_id_fkey" FOREIGN KEY ("cell_id") REFERENCES "cells"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cell_meetings" ADD CONSTRAINT "cell_meetings_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
