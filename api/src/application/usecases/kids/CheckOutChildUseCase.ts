import type { KidsCheckin } from '@domain/entities/Kids';
import type { IKidsRepository } from '@domain/repositories/IKidsRepository';
import { AppError } from '@shared/errors/AppError';
import type { KidsQrService } from '../../services/KidsQrService';
import type { PickupCodeService } from '../../services/PickupCodeService';

interface Input {
  readonly checkinId: string;
  readonly checkoutById: string;
  readonly checkoutByRole: string;
  /** Um dos três: QR do responsável, senha de 5 dígitos, ou liberação manual. */
  readonly qrToken?: string | null;
  readonly pickupCode?: string | null;
  readonly manual?: { guardianName: string; reason: string } | null;
  readonly readerChurchId: string | null;
}

/**
 * Saída da criança. Três caminhos, em ordem de confiança:
 *
 * 1. **QR** do app do responsável — vínculo verificado no servidor.
 * 2. **Senha** de 5 dígitos entregue no check-in, com bloqueio por tentativa.
 * 3. **Manual**, só para ADMIN ou professor titular, com nome de quem levou e
 *    justificativa — é a válvula de escape para o dia em que nada funciona, e
 *    fica registrada exatamente por isso.
 */
export class CheckOutChildUseCase {
  constructor(
    private readonly kidsRepo: IKidsRepository,
    private readonly pickupCodes: PickupCodeService,
    private readonly qrService: KidsQrService,
  ) {}

  async execute(input: Input): Promise<KidsCheckin> {
    const checkin = await this.kidsRepo.findCheckinById(input.checkinId);
    if (!checkin) throw AppError.notFound('Check-in não encontrado');
    if (checkin.status === 'CHECKED_OUT') {
      throw new AppError('Esta criança já foi retirada', 409, 'KIDS_ALREADY_CHECKED_OUT');
    }

    if (input.qrToken) return this.byQr(input, checkin);
    if (input.pickupCode) return this.byCode(input, checkin);
    if (input.manual) return this.byManual(input);

    throw new AppError('Informe o QR Code, a senha de retirada ou a liberação manual');
  }

  private async byQr(input: Input, checkin: KidsCheckin): Promise<KidsCheckin> {
    const resolved = await this.qrService.consume(input.qrToken!, input.readerChurchId);

    const child = await this.kidsRepo.findChildById(checkin.childId);
    if (!child) throw AppError.notFound('Criança não encontrada');

    // O QR identifica o usuário; ele só retira quem é dele — e só se estiver
    // autorizado a retirar (um responsável pode existir só para receber avisos).
    const guardian = child.guardians.find(
      (g) => g.userId === resolved.guardianUserId && g.canPickup,
    );
    const isDeclaredParent = child.userId === resolved.guardianUserId;
    if (!guardian && !isDeclaredParent) {
      throw AppError.forbidden('Este responsável não está autorizado a retirar a criança');
    }

    return this.kidsRepo.registerCheckout({
      checkinId: checkin.id,
      checkoutById: input.checkoutById,
      checkoutMethod: 'QR',
      checkoutGuardianId: guardian?.id ?? null,
      checkoutGuardianName: guardian?.name ?? null,
      checkoutReason: null,
    });
  }

  private async byCode(input: Input, checkin: KidsCheckin): Promise<KidsCheckin> {
    const state = await this.kidsRepo.getPickupState(checkin.id);
    if (!state?.pickupCodeHash) {
      throw new AppError(
        'Este check-in não tem senha de retirada — use o QR Code do responsável',
        409,
        'KIDS_NO_PICKUP_CODE',
      );
    }

    if (state.lockedUntil && state.lockedUntil > new Date()) {
      throw new AppError(
        'Retirada por senha bloqueada por tentativas erradas. Chame o responsável pela sala.',
        429,
        'KIDS_PICKUP_LOCKED',
      );
    }

    const ok = await this.pickupCodes.verify(input.pickupCode!, state.pickupCodeHash);
    if (!ok) {
      const lockUntil = this.pickupCodes.lockUntil(state.attempts);
      const attempts = await this.kidsRepo.registerPickupFailure(checkin.id, lockUntil);
      throw new AppError(
        lockUntil
          ? 'Senha incorreta. Retirada bloqueada por 15 minutos.'
          : `Senha incorreta (${attempts}/${this.pickupCodes.maxAttempts})`,
        401,
        'KIDS_PICKUP_CODE_INVALID',
      );
    }

    return this.kidsRepo.registerCheckout({
      checkinId: checkin.id,
      checkoutById: input.checkoutById,
      checkoutMethod: 'CODE',
      checkoutGuardianId: null,
      checkoutGuardianName: null,
      checkoutReason: null,
    });
  }

  private async byManual(input: Input): Promise<KidsCheckin> {
    if (input.checkoutByRole !== 'ADMIN' && input.checkoutByRole !== 'SUPERADMIN') {
      throw AppError.forbidden('Liberação manual é restrita a administradores');
    }
    const { guardianName, reason } = input.manual!;
    if (!guardianName.trim() || !reason.trim()) {
      throw new AppError('Informe quem retirou e o motivo da liberação manual');
    }

    return this.kidsRepo.registerCheckout({
      checkinId: input.checkinId,
      checkoutById: input.checkoutById,
      checkoutMethod: 'MANUAL',
      checkoutGuardianId: null,
      checkoutGuardianName: guardianName.trim(),
      checkoutReason: reason.trim(),
    });
  }
}
