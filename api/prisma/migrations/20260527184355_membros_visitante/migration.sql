-- DropIndex
DROP INDEX "attendances_visitor_id_cell_id_meeting_date_key";

-- CreateIndex
CREATE INDEX "attendances_visitor_id_cell_id_meeting_date_idx" ON "attendances"("visitor_id", "cell_id", "meeting_date");

-- CreateIndex
CREATE INDEX "attendances_member_id_cell_id_meeting_date_idx" ON "attendances"("member_id", "cell_id", "meeting_date");
