import { Prisma } from '@prisma/client';
import type { PrismaClient } from '@prisma/client';
import { getEffectiveChurchId } from '@shared/context/tenant-context';

/**
 * Nomes dos wrappers de chave composta por modelo (ex.: `cellId_meetingDate`),
 * extraídos do DMMF. `findUnique` aceita esse wrapper, `findFirst` não — então
 * ao converter a action precisamos achatar o objeto no where.
 */
const COMPOUND_KEYS: Map<string, Set<string>> = (() => {
  const map = new Map<string, Set<string>>();
  for (const model of Prisma.dmmf.datamodel.models) {
    const names = new Set<string>();
    for (const idx of model.uniqueIndexes) {
      if (idx.fields.length > 1) names.add(idx.name || idx.fields.join('_'));
    }
    if (model.primaryKey && model.primaryKey.fields.length > 1) {
      names.add(model.primaryKey.name || model.primaryKey.fields.join('_'));
    }
    if (names.size > 0) map.set(model.name, names);
  }
  return map;
})();

function flattenCompoundKeys(model: string, where: unknown): Record<string, unknown> {
  const source = (where ?? {}) as Record<string, unknown>;
  const compound = COMPOUND_KEYS.get(model);
  if (!compound) return { ...source };

  const flat: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(source)) {
    if (compound.has(key) && value !== null && typeof value === 'object') {
      Object.assign(flat, value as Record<string, unknown>);
    } else {
      flat[key] = value;
    }
  }
  return flat;
}

/**
 * Modelos isolados por igreja (tenant-scoped). Nomes exatamente como o Prisma
 * Client os expõe em `params.model`.
 */
const TENANT_MODELS = new Set<Prisma.ModelName>([
  'User',
  'Coordenacao',
  'Child',
  'CellType',
  'Cell',
  'Visitor',
  'CellMember',
  'CellMeeting',
  'Attendance',
  'SpiritualHistory',
  'Material',
]);

/**
 * Guard-rail de multi-tenancy. Injeta `church_id` automaticamente com base no
 * contexto (AsyncLocalStorage) em modelos tenant-scoped:
 *  - Leituras (find, count, aggregate, groupBy): adiciona `where.churchId`.
 *  - findUnique → findFirst para permitir o filtro por igreja.
 *  - Escritas em lote (updateMany/deleteMany): adiciona `where.churchId`.
 *  - create/createMany: injeta `churchId` no data quando ausente.
 *  - upsert: injeta `churchId` no payload `create`.
 *
 * Quando não há churchId no contexto (SUPERADMIN cross-tenant, rotas públicas,
 * seeds) o guard não interfere. Mutações unitárias por id (update/delete/upsert)
 * mantêm o `where` unique intacto — o isolamento nesses fluxos é garantido pela
 * leitura prévia tenant-scoped feita nos controllers.
 */
export function applyTenantGuard(prisma: PrismaClient): void {
  prisma.$use(async (params, next) => {
    const model = params.model as Prisma.ModelName | undefined;
    if (!model || !TENANT_MODELS.has(model)) return next(params);

    const churchId = getEffectiveChurchId();
    if (!churchId) return next(params);

    const args = (params.args ?? {}) as Record<string, unknown>;

    switch (params.action) {
      case 'findUnique':
      case 'findUniqueOrThrow': {
        params.action = params.action === 'findUnique' ? 'findFirst' : 'findFirstOrThrow';
        args['where'] = { ...flattenCompoundKeys(model, args['where']), churchId };
        params.args = args;
        break;
      }
      case 'findFirst':
      case 'findFirstOrThrow':
      case 'findMany':
      case 'count':
      case 'aggregate':
      case 'groupBy':
      case 'updateMany':
      case 'deleteMany': {
        args['where'] = { ...(args['where'] as object), churchId };
        params.args = args;
        break;
      }
      case 'create': {
        const data = (args['data'] ?? {}) as Record<string, unknown>;
        if (data['churchId'] === undefined && data['church'] === undefined) {
          args['data'] = { ...data, churchId };
          params.args = args;
        }
        break;
      }
      case 'createMany': {
        const data = args['data'];
        if (Array.isArray(data)) {
          args['data'] = data.map((d) => ({ churchId, ...(d as object) }));
        } else if (data && typeof data === 'object') {
          args['data'] = { churchId, ...(data as object) };
        }
        params.args = args;
        break;
      }
      case 'upsert': {
        // O `where` continua unique (Prisma exige), mas o payload de criação
        // precisa do churchId: sem ele a linha nasce com church_id nulo e some
        // de todas as leituras, que filtram por igreja.
        const create = (args['create'] ?? {}) as Record<string, unknown>;
        if (create['churchId'] === undefined && create['church'] === undefined) {
          args['create'] = { ...create, churchId };
          params.args = args;
        }
        break;
      }
      default:
        // update/delete unitários: where deve permanecer unique.
        break;
    }

    return next(params);
  });
}
