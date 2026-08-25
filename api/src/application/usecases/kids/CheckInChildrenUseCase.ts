import type {
  CheckinResult,
  ChildHealth,
  KidsCheckMethod,
  KidsChild,
} from '@domain/entities/Kids';
import type { CheckinEntry, IKidsRepository } from '@domain/repositories/IKidsRepository';
import { AppError } from '@shared/errors/AppError';
import type { PickupCodeService } from '../../services/PickupCodeService';

interface Input {
  readonly sessionId: string;
  readonly childIds: string[];
  readonly guardianId?: string | null;
  readonly method: KidsCheckMethod;
  readonly checkinById: string;
  /** Ignora a faixa etária da sala. Só ADMIN chega aqui com `true`. */
  readonly force?: boolean;
}

export interface CheckInOutput {
  readonly checkins: CheckinResult[];
  readonly roomOccupancy: { current: number; capacity: number };
}

/**
 * Entrada de uma ou mais crianças na sala.
 *
 * A senha de retirada só é gerada para quem **não** tem responsável com conta
 * no app: quando há app, a retirada é pelo mesmo QR da entrada, que é o caminho
 * seguro. Gerar senha para todo mundo criaria uma chave fraca desnecessária.
 */
export class CheckInChildrenUseCase {
  constructor(
    private readonly kidsRepo: IKidsRepository,
    private readonly pickupCodes: PickupCodeService,
  ) {}

  async execute(input: Input): Promise<CheckInOutput> {
    if (input.childIds.length === 0) {
      throw new AppError('Selecione ao menos uma criança');
    }

    const session = await this.kidsRepo.findSessionById(input.sessionId);
    if (!session) throw AppError.notFound('Sessão não encontrada');
    if (session.status !== 'OPEN') {
      throw new AppError('A sala já foi fechada', 409, 'KIDS_SESSION_CLOSED');
    }

    const room = await this.kidsRepo.findRoomById(session.roomId);
    if (!room) throw AppError.notFound('Sala não encontrada');

    const present = await this.kidsRepo.countCheckedInBySession(session.id);
    if (present + input.childIds.length > session.capacity) {
      throw new AppError(
        `Sala lotada: ${present}/${session.capacity} lugares ocupados`,
        409,
        'KIDS_ROOM_FULL',
      );
    }

    const entries: CheckinEntry[] = [];
    const plainCodes = new Map<string, string>();
    const children = new Map<string, KidsChild>();
    let badgeNumber = await this.kidsRepo.nextBadgeNumber(session.id);

    for (const childId of input.childIds) {
      const child = await this.kidsRepo.findChildById(childId);
      if (!child) throw AppError.notFound(`Criança ${childId} não encontrada`);
      children.set(childId, child);

      const open = await this.kidsRepo.findOpenCheckinByChild(childId);
      if (open) {
        throw new AppError(
          `${child.name} já está em uma sala`,
          409,
          'KIDS_ALREADY_CHECKED_IN',
        );
      }

      if (!input.force) this.assertAgeFits(child, room.minAgeMonths, room.maxAgeMonths);

      // Quem tem responsável com conta usa o QR na saída; os demais recebem senha.
      const guardianWithApp = child.guardians.some((g) => g.userId !== null);
      let pickupCodeHash: string | null = null;
      let pickupCodeLast2: string | null = null;
      if (!guardianWithApp) {
        const code = this.pickupCodes.generate();
        pickupCodeHash = await this.pickupCodes.hash(code);
        pickupCodeLast2 = this.pickupCodes.last2(code);
        plainCodes.set(childId, code);
      }

      entries.push({
        sessionId: session.id,
        childId,
        badgeCode: `K-${String(badgeNumber).padStart(3, '0')}`,
        checkinById: input.checkinById,
        checkinMethod: input.method,
        checkinGuardianId: input.guardianId ?? null,
        pickupCodeHash,
        pickupCodeLast2,
      });
      badgeNumber += 1;
    }

    const created = await this.kidsRepo.createCheckins(entries);

    return {
      checkins: created.map((c) => ({
        id: c.id,
        childId: c.childId,
        childName: c.childName,
        badgeCode: c.badgeCode,
        // Única vez que a senha existe em texto puro. Depois, só o hash.
        pickupCode: plainCodes.get(c.childId) ?? null,
        healthFlags: this.healthFlags(children.get(c.childId)?.health),
      })),
      roomOccupancy: {
        current: present + created.length,
        capacity: session.capacity,
      },
    };
  }

  /** A faixa etária é um aviso forte, não uma parede: o ADMIN pode sobrepor. */
  private assertAgeFits(
    child: KidsChild,
    minAgeMonths: number | null,
    maxAgeMonths: number | null,
  ): void {
    if (!child.birthDate || (minAgeMonths === null && maxAgeMonths === null)) return;

    const months = this.ageInMonths(child.birthDate);
    const below = minAgeMonths !== null && months < minAgeMonths;
    const above = maxAgeMonths !== null && months > maxAgeMonths;
    if (below || above) {
      throw new AppError(
        `${child.name} está fora da faixa etária da sala`,
        422,
        'KIDS_AGE_OUT_OF_RANGE',
      );
    }
  }

  private ageInMonths(birthDate: Date): number {
    const now = new Date();
    const years = now.getUTCFullYear() - birthDate.getUTCFullYear();
    const months = now.getUTCMonth() - birthDate.getUTCMonth();
    const dayAdjust = now.getUTCDate() < birthDate.getUTCDate() ? -1 : 0;
    return years * 12 + months + dayAdjust;
  }

  /** Resumo clínico para a tela do professor — some da lista ao dar check-out. */
  private healthFlags(health: ChildHealth | undefined): string[] {
    if (!health) return [];
    const flags: string[] = [];
    if (health.allergies) flags.push(`Alergia: ${health.allergies}`);
    if (health.medications) flags.push(`Medicação: ${health.medications}`);
    if (health.disabilities) flags.push(`Deficiência: ${health.disabilities}`);
    if (health.medicalNotes) flags.push(health.medicalNotes);
    return flags;
  }
}
