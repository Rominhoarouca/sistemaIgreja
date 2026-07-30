import type { IChurchRepository } from '@domain/repositories/IChurchRepository';
import type { MinioService } from '@infrastructure/storage/MinioService';
import { AppError } from '@shared/errors/AppError';

/**
 * Identificação mínima da igreja, exposta sem autenticação para a tela pública
 * de auto-cadastro do visitante mostrar de qual igreja é o formulário.
 *
 * Devolve só o que é seguro num endpoint aberto: nome, slug, logo e cor do
 * tema. Nada de plano, assinatura, endereço ou contadores.
 */
export interface PublicChurch {
  readonly name: string;
  readonly slug: string;
  readonly logoUrl: string | null;
  readonly menuColor: string;
}

export class GetPublicChurchUseCase {
  constructor(
    private readonly churchRepo: IChurchRepository,
    private readonly minio: MinioService,
  ) {}

  async execute(slug: string): Promise<PublicChurch> {
    const church = await this.churchRepo.findBySlug(slug.trim().toLowerCase());
    // Igreja inativa se comporta como inexistente: não confirma a existência
    // do slug para quem está de fora.
    if (!church || !church.isActive) throw AppError.notFound('Igreja não encontrada');

    let logoUrl: string | null = null;
    if (church.logoKey) {
      try {
        logoUrl = await this.minio.presignedDownloadUrl(church.logoKey);
      } catch {
        logoUrl = null;
      }
    }

    return {
      name: church.name,
      slug: church.slug,
      logoUrl,
      menuColor: church.menuColor,
    };
  }
}
