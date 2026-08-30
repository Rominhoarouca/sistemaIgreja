import * as Minio from 'minio';
import { AppError } from '@shared/errors/AppError';
import { getEffectiveChurchId } from '@shared/context/tenant-context';

/**
 * Pastas dentro do bucket da igreja. Um lugar só para os prefixos, para não
 * voltarem a divergir entre os use cases (o material, por exemplo, gravava na
 * raiz enquanto todo o resto usava pasta).
 */
export const StorageFolder = {
  meetings: 'meetings',
  members: 'members',
  visitors: 'visitors',
  users: 'users',
  materials: 'materiais',
  notifications: 'notifications',
  logo: 'logo',
} as const;

export type StorageFolderName = (typeof StorageFolder)[keyof typeof StorageFolder];

/**
 * Prefixo opcional do bucket (`MINIO_BUCKET_PREFIX`). Vazio por padrão: o
 * bucket é o próprio id da igreja.
 */
const bucketPrefix = process.env['MINIO_BUCKET_PREFIX'] ?? '';

/**
 * Nome do bucket de uma igreja.
 *
 * O id é um UUID — minúsculas, dígitos e hífen —, que já satisfaz as regras de
 * nome de bucket do S3. A validação existe para falhar alto caso algum dia
 * chegue um id fora desse formato, em vez de estourar dentro do SDK.
 */
export function bucketForChurch(churchId: string): string {
  const name = `${bucketPrefix}${churchId}`.toLowerCase();
  if (!/^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$/.test(name)) {
    throw AppError.internal(`Nome de bucket inválido para a igreja "${churchId}"`);
  }
  return name;
}

export class MinioService {
  private readonly client: Minio.Client;

  /** Buckets já garantidos neste processo — evita um HEAD por upload. */
  private readonly ensured = new Set<string>();

  constructor() {
    // Sem fallback para credencial. O default silencioso (`minio_user` /
    // `minio_password`) transformava um .env desalinhado num 500 genérico
    // "signature does not match" só na hora do upload — o erro tem de
    // aparecer no boot, não quando o usuário tenta trocar a logo.
    const accessKey = process.env['MINIO_ACCESS_KEY'];
    const secretKey = process.env['MINIO_SECRET_KEY'];
    if (!accessKey || !secretKey) {
      throw new Error(
        'MINIO_ACCESS_KEY/MINIO_SECRET_KEY ausentes: uploads (logo, foto de ' +
          'encontro, materiais) não funcionam. Configure no .env da API.',
      );
    }
    this.client = new Minio.Client({
      endPoint: process.env['MINIO_ENDPOINT'] ?? 'localhost',
      port: Number(process.env['MINIO_PORT'] ?? 9000),
      useSSL: process.env['MINIO_USE_SSL'] === 'true',
      accessKey,
      secretKey,
    });
  }

  /**
   * Erro de credencial do S3 vira 502 com texto acionável em vez de um 500
   * com a mensagem crua do SDK, que não diz o que arrumar.
   */
  private wrap(err: unknown, context: string): AppError {
    const code = (err as { code?: string })?.code ?? '';
    if (
      code === 'SignatureDoesNotMatch' ||
      code === 'InvalidAccessKeyId' ||
      code === 'AccessDenied'
    ) {
      return new AppError(
        'Credenciais do armazenamento de arquivos (MinIO) inválidas. ' +
          'Confira MINIO_ACCESS_KEY/MINIO_SECRET_KEY da API contra o servidor.',
        502,
        'STORAGE_AUTH',
      );
    }
    return AppError.internal(`MinIO ${context} error: ${String(err)}`);
  }

  /**
   * Bucket da requisição: o informado ou o da igreja no contexto.
   *
   * Falha explícita quando não há nenhum dos dois. Um default aqui gravaria o
   * arquivo de uma igreja no bucket de outra — pior que o erro.
   */
  private resolveBucket(churchId?: string): string {
    const id = churchId ?? getEffectiveChurchId();
    if (!id) {
      throw AppError.internal(
        'Igreja não identificada para o armazenamento de arquivos',
      );
    }
    return bucketForChurch(id);
  }

  /** Valida a credencial no boot. Não depende de nenhum bucket existir. */
  async healthCheck(): Promise<void> {
    try {
      await this.client.listBuckets();
    } catch (err) {
      throw this.wrap(err, 'health');
    }
  }

  /** Cria o bucket da igreja se ainda não existir. */
  async ensureBucket(churchId?: string): Promise<string> {
    const bucket = this.resolveBucket(churchId);
    if (this.ensured.has(bucket)) return bucket;
    try {
      const exists = await this.client.bucketExists(bucket);
      if (!exists) await this.client.makeBucket(bucket, 'us-east-1');
      this.ensured.add(bucket);
      return bucket;
    } catch (err) {
      throw this.wrap(err, 'bucket');
    }
  }

  /**
   * Monta a chave do objeto dentro do bucket da igreja.
   * Ex.: `meetings/{cellId}/2026-07-04_uuid.jpg`.
   */
  static objectKey(folder: StorageFolderName, ...segments: string[]): string {
    return [folder, ...segments.filter((s) => s.length > 0)].join('/');
  }

  async uploadFile(params: {
    objectName: string;
    buffer: Buffer;
    mimeType: string;
    size: number;
    churchId?: string;
  }): Promise<string> {
    const bucket = await this.ensureBucket(params.churchId);
    try {
      await this.client.putObject(
        bucket,
        params.objectName,
        params.buffer,
        params.size,
        { 'Content-Type': params.mimeType },
      );
      return params.objectName;
    } catch (err) {
      throw this.wrap(err, 'upload');
    }
  }

  /**
   * URL assinada válida por 1 hora. Reescreve o host interno do MinIO para a
   * URL pública roteada pelo nginx em `/storage/`.
   */
  async presignedDownloadUrl(
    objectName: string,
    expireSeconds = 3600,
    churchId?: string,
  ): Promise<string> {
    const bucket = this.resolveBucket(churchId);
    try {
      const url = await this.client.presignedGetObject(bucket, objectName, expireSeconds);
      const publicUrl = process.env['MINIO_PUBLIC_URL'];
      if (publicUrl) {
        return url.replace(/^https?:\/\/[^/]+\//, `${publicUrl}/storage/`);
      }
      return url;
    } catch (err) {
      throw this.wrap(err, 'presign');
    }
  }

  async deleteObject(objectName: string, churchId?: string): Promise<void> {
    try {
      await this.client.removeObject(this.resolveBucket(churchId), objectName);
    } catch {
      // Ignora: o objeto pode já não existir.
    }
  }

  /**
   * Bytes ocupados pela igreja. Com bucket por igreja o total é a soma do
   * próprio bucket — não é mais preciso adivinhar o dono pelo nome do objeto.
   */
  async bucketSizeBytes(churchId: string): Promise<number> {
    const bucket = bucketForChurch(churchId);
    const exists = await this.client.bucketExists(bucket).catch(() => false);
    if (!exists) return 0;

    return new Promise((resolve, reject) => {
      let total = 0;
      const stream = this.client.listObjectsV2(bucket, '', true);
      stream.on('data', (obj) => {
        total += obj.size ?? 0;
      });
      stream.on('end', () => resolve(total));
      stream.on('error', (err) =>
        reject(AppError.internal(`MinIO list error: ${String(err)}`)),
      );
    });
  }
}
