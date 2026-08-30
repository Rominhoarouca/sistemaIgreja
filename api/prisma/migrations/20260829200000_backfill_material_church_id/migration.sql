-- Materiais nasceram com church_id nulo e ficaram invisíveis.
--
-- O upload é multipart e o multer perde o AsyncLocalStorage do tenant-guard,
-- então o `church_id` nunca era injetado no create. Corrigido no código com o
-- `restoreTenantContext`; aqui reparamos as linhas já gravadas.
--
-- A célula é a fonte confiável do tenant: `materials.cell_id` sempre aponta
-- para uma célula, e a célula já tem o church_id certo.
UPDATE materials m
SET church_id = c.church_id
FROM cells c
WHERE m.cell_id = c.id
  AND m.church_id IS NULL
  AND c.church_id IS NOT NULL;
