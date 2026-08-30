-- Papéis acumulados por usuário.
--
-- `users.role` continua existindo como papel principal (é o que ordena a home
-- do app e o que as checagens de "só líder vê X" usam). A coluna nova guarda a
-- união de todos os papéis que a pessoa exerce, para que um mesmo usuário possa
-- ser líder, supervisor, admin e coordenador ao mesmo tempo.
ALTER TABLE "users"
  ADD COLUMN IF NOT EXISTS "roles" "UserRole"[] NOT NULL DEFAULT ARRAY[]::"UserRole"[];

-- Backfill: quem já existia passa a ter o papel atual dentro do array.
UPDATE "users" SET "roles" = ARRAY["role"]::"UserRole"[] WHERE cardinality("roles") = 0;

-- Célula sem líder.
--
-- Antes, cadastrar a primeira célula exigia um líder e cadastrar o primeiro
-- líder exigia uma célula — nenhum dos dois entrava numa base zerada. Agora os
-- dois lados são opcionais e o vínculo é feito depois.
ALTER TABLE "cells" ALTER COLUMN "leader_id" DROP NOT NULL;
