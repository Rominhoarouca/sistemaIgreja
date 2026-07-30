-- Encontros criados via upsert nasceram com church_id nulo, porque o
-- tenant-guard não injetava o tenant nessa action. Linha sem church_id não
-- casa com o filtro por igreja das leituras, então o encontro ficava invisível
-- na lista do líder. O guard já foi corrigido; aqui recuperamos as órfãs
-- herdando a igreja da própria célula.
UPDATE cell_meetings m
SET church_id = c.church_id
FROM cells c
WHERE m.cell_id = c.id
  AND m.church_id IS NULL
  AND c.church_id IS NOT NULL;
