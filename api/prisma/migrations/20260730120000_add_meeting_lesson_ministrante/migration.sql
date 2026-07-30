-- Lição ministrada e quem ministrou, exibidos no card "Últimas reuniões".
-- Ministrante é texto livre porque pode ser alguém de fora da célula.

-- AlterTable
ALTER TABLE "cell_meetings"
  ADD COLUMN "lesson" TEXT,
  ADD COLUMN "ministrante" TEXT;
