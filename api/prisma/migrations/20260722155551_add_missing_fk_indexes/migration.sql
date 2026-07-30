-- CreateIndex
CREATE INDEX "attendances_cell_id_meeting_date_idx" ON "attendances"("cell_id", "meeting_date");

-- CreateIndex
CREATE INDEX "cell_meetings_created_by_id_idx" ON "cell_meetings"("created_by_id");

-- CreateIndex
CREATE INDEX "cell_members_bairro_id_idx" ON "cell_members"("bairro_id");

-- CreateIndex
CREATE INDEX "cells_leader_id_idx" ON "cells"("leader_id");

-- CreateIndex
CREATE INDEX "cells_cell_type_id_idx" ON "cells"("cell_type_id");

-- CreateIndex
CREATE INDEX "cells_bairro_id_idx" ON "cells"("bairro_id");

-- CreateIndex
CREATE INDEX "materials_cell_id_idx" ON "materials"("cell_id");

-- CreateIndex
CREATE INDEX "materials_uploaded_by_id_idx" ON "materials"("uploaded_by_id");

-- CreateIndex
CREATE INDEX "spiritual_histories_visitor_id_idx" ON "spiritual_histories"("visitor_id");

-- CreateIndex
CREATE INDEX "spiritual_histories_recorded_by_id_idx" ON "spiritual_histories"("recorded_by_id");

-- CreateIndex
CREATE INDEX "users_supervisor_id_idx" ON "users"("supervisor_id");

-- CreateIndex
CREATE INDEX "users_coordenacao_id_idx" ON "users"("coordenacao_id");

-- CreateIndex
CREATE INDEX "visitors_leader_id_idx" ON "visitors"("leader_id");

-- CreateIndex
CREATE INDEX "visitors_cell_id_idx" ON "visitors"("cell_id");

-- CreateIndex
CREATE INDEX "visitors_bairro_id_idx" ON "visitors"("bairro_id");

-- CreateIndex
CREATE INDEX "visitors_referred_by_id_idx" ON "visitors"("referred_by_id");
