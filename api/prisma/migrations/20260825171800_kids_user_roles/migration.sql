-- Papéis do módulo Kids.
--
-- Em migração separada de propósito: o Postgres não permite usar um valor de
-- enum recém-adicionado no mesmo bloco/transação em que ele foi criado. Manter
-- o ALTER TYPE isolado deixa qualquer DDL futuro livre para referenciar
-- 'KIDS'/'RESPONSAVEL' sem esbarrar nisso.
ALTER TYPE "UserRole" ADD VALUE IF NOT EXISTS 'KIDS';
ALTER TYPE "UserRole" ADD VALUE IF NOT EXISTS 'RESPONSAVEL';
