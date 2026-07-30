import type { IChurchRepository } from '@domain/repositories/IChurchRepository';
import type { Church, UpdateChurchData } from '@domain/entities/Church';
import { AppError } from '@shared/errors/AppError';

const HEX = /^#([0-9a-fA-F]{6})$/;

export class UpdateChurchUseCase {
  constructor(private readonly churchRepo: IChurchRepository) {}

  async execute(churchId: string, data: UpdateChurchData): Promise<Church> {
    if (data.menuColor !== undefined && !HEX.test(data.menuColor)) {
      throw new AppError('Cor do menu deve estar no formato hexadecimal (#RRGGBB)', 400);
    }
    const church = await this.churchRepo.findById(churchId);
    if (!church) throw AppError.notFound('Igreja não encontrada');
    return this.churchRepo.update(churchId, data);
  }
}
