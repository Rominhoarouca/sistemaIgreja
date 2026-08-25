import type { CreateAlertData, KidsAlert } from '@domain/entities/Kids';
import type { IKidsRepository } from '@domain/repositories/IKidsRepository';
import { AppError } from '@shared/errors/AppError';
import type { KidsAlertDispatcher } from '../../services/KidsAlertDispatcher';

/**
 * Cria o alerta e dispara as entregas.
 *
 * O alerta é gravado **antes** de qualquer envio: se o WhatsApp cair, o
 * registro (e o rastro das tentativas) continua existindo. O disparo roda em
 * seguida e nunca derruba a resposta — o professor precisa ver "alerta criado"
 * na hora, não esperar provedor externo.
 */
export class CreateAlertUseCase {
  constructor(
    private readonly kidsRepo: IKidsRepository,
    private readonly dispatcher: KidsAlertDispatcher,
  ) {}

  async execute(input: CreateAlertData): Promise<KidsAlert> {
    const checkin = await this.kidsRepo.findCheckinById(input.checkinId);
    if (!checkin) throw AppError.notFound('Check-in não encontrado');

    const child = await this.kidsRepo.findChildById(checkin.childId);
    if (!child) throw AppError.notFound('Criança não encontrada');

    const guardians = child.guardians;
    if (guardians.length === 0) {
      throw new AppError(
        'Criança sem responsável cadastrado — não há para quem avisar',
        409,
        'KIDS_NO_GUARDIAN',
      );
    }

    const planned = this.dispatcher.plan(input.level, guardians);
    const alert = await this.kidsRepo.createAlertWithDeliveries(
      {
        ...input,
        sessionId: checkin.sessionId,
        childId: checkin.childId,
      },
      planned,
    );

    await this.dispatcher.dispatch(alert, guardians);

    // Relê para devolver o status real de cada entrega (SENT/FAILED/QUEUED).
    return (await this.kidsRepo.findAlertById(alert.id)) ?? alert;
  }
}
