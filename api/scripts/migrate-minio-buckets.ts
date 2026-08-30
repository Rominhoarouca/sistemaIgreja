/**
 * Migra o storage do bucket único para um bucket por igreja.
 *
 * Antes: um bucket (`MINIO_BUCKET`, default "materiais") com os objetos de
 * todas as igrejas. Agora: um bucket por igreja, com as pastas meetings/,
 * members/, visitors/, users/, materiais/, notifications/ e logo/.
 *
 * A migração é dirigida pelo banco, não pela listagem do bucket: cada chave
 * guardada tem uma linha dona com `church_id`, então o destino é sempre certo
 * e nenhum objeto vai parar no bucket errado por adivinhação de nome.
 *
 * Idempotente: objeto já copiado é pulado e a chave no banco só é reescrita
 * depois da cópia dar certo. Nada é apagado da origem sem `--purge`.
 *
 * Uso:
 *   npx tsx scripts/migrate-minio-buckets.ts [--dry-run] [--files-only] [--purge]
 *
 * Sequência recomendada em produção (sem janela de indisponibilidade):
 *   1. `--files-only`  copia os objetos e NÃO toca no banco. O código antigo
 *                      segue lendo do bucket antigo, que continua intacto.
 *   2. deploy da API nova (passa a ler/gravar no bucket da igreja).
 *   3. execução normal  só reescreve as chaves de logo e material no banco,
 *                      já que os objetos foram copiados no passo 1.
 *   4. `--purge`        depois de conferir, apaga da origem o que foi migrado.
 */
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import * as Minio from 'minio';
import { bucketForChurch, StorageFolder } from '../src/infrastructure/storage/MinioService';

const dryRun = process.argv.includes('--dry-run');
const purge = process.argv.includes('--purge');
/** Copia os objetos sem reescrever as chaves no banco. */
const filesOnly = process.argv.includes('--files-only');

const legacyBucket = process.env['MINIO_BUCKET'] ?? 'materiais';

const client = new Minio.Client({
  endPoint: process.env['MINIO_ENDPOINT'] ?? 'localhost',
  port: Number(process.env['MINIO_PORT'] ?? 9000),
  useSSL: process.env['MINIO_USE_SSL'] === 'true',
  accessKey: process.env['MINIO_ACCESS_KEY'] ?? '',
  secretKey: process.env['MINIO_SECRET_KEY'] ?? '',
});

// Sem guard multi-tenant aqui de propósito: o script precisa enxergar todas as
// igrejas, e é ele mesmo quem resolve o dono de cada chave.
const prisma = new PrismaClient();

interface Item {
  readonly table: string;
  readonly id: string;
  readonly churchId: string;
  /** Chave no bucket antigo. */
  readonly oldKey: string;
  /** Chave no bucket da igreja. */
  readonly newKey: string;
  readonly persist: (newKey: string) => Promise<unknown>;
}

/**
 * Chaves de logo e material mudam de formato na migração, e o valor no banco
 * pode já estar no formato novo (execução anterior). Estas funções derivam
 * **os dois** formatos a partir do que está gravado, para o script continuar
 * idempotente depois da reescrita — sem isso o `--purge` procurava a chave
 * nova dentro do bucket antigo e não apagava nada.
 */
function logoKeys(current: string, churchId: string): { oldKey: string; newKey: string } {
  const file = current.split('/').pop() ?? current;
  const newKey = `${StorageFolder.logo}/${file}`;
  const oldKey = current.startsWith(`${StorageFolder.logo}/`)
    ? `churches/${churchId}/${StorageFolder.logo}/${file}`
    : current;
  return { oldKey, newKey };
}

function materialKeys(current: string): { oldKey: string; newKey: string } {
  const prefix = `${StorageFolder.materials}/`;
  if (current.startsWith(prefix)) {
    return { oldKey: current.slice(prefix.length), newKey: current };
  }
  return { oldKey: current, newKey: `${prefix}${current}` };
}

async function collect(): Promise<Item[]> {
  const items: Item[] = [];
  const noop = () => Promise.resolve();

  const churches = await prisma.church.findMany({
    where: { logoKey: { not: null } },
    select: { id: true, logoKey: true },
  });
  for (const c of churches) {
    const { oldKey, newKey } = logoKeys(c.logoKey!, c.id);
    items.push({
      table: 'churches.logo_key',
      id: c.id,
      churchId: c.id,
      oldKey,
      newKey,
      persist: (key) =>
        prisma.church.update({ where: { id: c.id }, data: { logoKey: key } }),
    });
  }

  const meetings = await prisma.cellMeeting.findMany({
    where: { photoKey: { not: null }, churchId: { not: null } },
    select: { id: true, churchId: true, photoKey: true },
  });
  for (const m of meetings) {
    items.push({
      table: 'cell_meetings.photo_key',
      id: m.id,
      churchId: m.churchId!,
      oldKey: m.photoKey!,
      newKey: m.photoKey!,
      persist: noop,
    });
  }

  const members = await prisma.cellMember.findMany({
    where: { photoKey: { not: null }, churchId: { not: null } },
    select: { id: true, churchId: true, photoKey: true },
  });
  for (const m of members) {
    items.push({
      table: 'cell_members.photo_key',
      id: m.id,
      churchId: m.churchId!,
      oldKey: m.photoKey!,
      newKey: m.photoKey!,
      persist: noop,
    });
  }

  const visitors = await prisma.visitor.findMany({
    where: { photoKey: { not: null }, churchId: { not: null } },
    select: { id: true, churchId: true, photoKey: true },
  });
  for (const v of visitors) {
    items.push({
      table: 'visitors.photo_key',
      id: v.id,
      churchId: v.churchId!,
      oldKey: v.photoKey!,
      newKey: v.photoKey!,
      persist: noop,
    });
  }

  const users = await prisma.user.findMany({
    where: { photoKey: { not: null }, churchId: { not: null } },
    select: { id: true, churchId: true, photoKey: true },
  });
  for (const u of users) {
    items.push({
      table: 'users.photo_key',
      id: u.id,
      churchId: u.churchId!,
      oldKey: u.photoKey!,
      newKey: u.photoKey!,
      persist: noop,
    });
  }

  const materials = await prisma.material.findMany({
    where: { churchId: { not: null } },
    select: { id: true, churchId: true, url: true },
  });
  for (const mat of materials) {
    const { oldKey, newKey } = materialKeys(mat.url);
    items.push({
      table: 'materials.url',
      id: mat.id,
      churchId: mat.churchId!,
      oldKey,
      newKey,
      persist: (key) =>
        prisma.material.update({ where: { id: mat.id }, data: { url: key } }),
    });
  }

  const notifications = await prisma.notification.findMany({
    where: { imageKey: { not: null }, churchId: { not: null } },
    select: { id: true, churchId: true, imageKey: true },
  });
  for (const n of notifications) {
    items.push({
      table: 'notifications.image_key',
      id: n.id,
      churchId: n.churchId!,
      oldKey: n.imageKey!,
      newKey: n.imageKey!,
      persist: noop,
    });
  }

  return items;
}

async function objectExists(bucket: string, key: string): Promise<boolean> {
  try {
    await client.statObject(bucket, key);
    return true;
  } catch {
    return false;
  }
}

async function main(): Promise<void> {
  const items = await collect();
  const modes = [
    dryRun ? 'dry-run' : null,
    filesOnly ? 'files-only (nao altera o banco)' : null,
    purge ? 'purge' : null,
  ].filter(Boolean);
  console.log(
    `[migrate] ${items.length} referencia(s) no banco; origem: bucket "${legacyBucket}"` +
      (modes.length ? ` [${modes.join(', ')}]` : ''),
  );

  for (const bucket of new Set(items.map((i) => bucketForChurch(i.churchId)))) {
    const exists = await client.bucketExists(bucket).catch(() => false);
    if (!exists) {
      console.log(`[migrate] criando bucket ${bucket}`);
      if (!dryRun) await client.makeBucket(bucket, 'us-east-1');
    }
  }

  let copied = 0;
  let skipped = 0;
  let missing = 0;

  for (const item of items) {
    const bucket = bucketForChurch(item.churchId);

    // A checagem do destino vale também em dry-run: senão a prévia mostra
    // cópias que na prática não aconteceriam.
    if (await objectExists(bucket, item.newKey)) {
      skipped++;
    } else if (await objectExists(legacyBucket, item.oldKey)) {
      console.log(
        `[migrate] ${item.table}: ${legacyBucket}/${item.oldKey} -> ${bucket}/${item.newKey}`,
      );
      if (!dryRun) {
        await client.copyObject(
          bucket,
          item.newKey,
          `/${legacyBucket}/${item.oldKey}`,
          new Minio.CopyConditions(),
        );
      }
      copied++;
    } else {
      console.warn(
        `[migrate] AUSENTE na origem: ${legacyBucket}/${item.oldKey} (${item.table} ${item.id})`,
      );
      missing++;
      continue;
    }

    if (!dryRun && !filesOnly && item.newKey !== item.oldKey) {
      await item.persist(item.newKey);
    }
  }

  if (purge && !dryRun) {
    console.log('[migrate] removendo do bucket de origem o que ja foi copiado');
    for (const item of items) {
      if (await objectExists(bucketForChurch(item.churchId), item.newKey)) {
        await client.removeObject(legacyBucket, item.oldKey).catch(() => undefined);
      }
    }
  }

  console.log(
    `[migrate] fim - copiados: ${copied}, ja existiam: ${skipped}, ausentes na origem: ${missing}`,
  );
  await prisma.$disconnect();
}

main().catch(async (err) => {
  console.error('[migrate] falhou:', err);
  await prisma.$disconnect();
  process.exit(1);
});
