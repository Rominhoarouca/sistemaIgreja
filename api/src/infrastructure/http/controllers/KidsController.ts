import type { Request, Response } from 'express';
import { z } from 'zod';
import type { IKidsRepository } from '@domain/repositories/IKidsRepository';
import type { CheckInChildrenUseCase } from '@application/usecases/kids/CheckInChildrenUseCase';
import type { CheckOutChildUseCase } from '@application/usecases/kids/CheckOutChildUseCase';
import type { CreateAlertUseCase } from '@application/usecases/kids/CreateAlertUseCase';
import type { KidsQrService } from '@application/services/KidsQrService';
import type { PickupCodeService } from '@application/services/PickupCodeService';
import { AppError } from '@shared/errors/AppError';

const optionalText = (max: number) =>
  z
    .string()
    .max(max)
    .nullish()
    .transform((v) => {
      if (v === undefined) return undefined;
      const trimmed = v?.trim() ?? '';
      return trimmed === '' ? null : trimmed;
    });

const roomSchema = z.object({
  name: z.string().min(1).max(120),
  description: optionalText(300),
  capacity: z.number().int().positive().max(500),
  minAgeMonths: z.number().int().min(0).max(300).nullish(),
  maxAgeMonths: z.number().int().min(0).max(300).nullish(),
  color: z.string().regex(/^#[0-9a-fA-F]{6}$/).optional(),
  teachers: z
    .array(z.object({ userId: z.string().uuid(), role: z.enum(['TITULAR', 'AUXILIAR']) }))
    .optional(),
});

const teachersSchema = z.object({
  teachers: z.array(
    z.object({ userId: z.string().uuid(), role: z.enum(['TITULAR', 'AUXILIAR']) }),
  ),
});

const openSessionSchema = z.object({
  serviceDate: z.coerce.date().optional(),
  serviceName: z.string().min(1).max(80).default('Culto'),
  lesson: optionalText(300),
  capacityOverride: z.number().int().positive().max(500).nullish(),
});

const guardianSchema = z.object({
  name: z.string().min(1).max(120),
  phone: z.string().min(8).max(20),
  hasWhatsapp: z.boolean().optional(),
  relation: z
    .enum(['PAI', 'MAE', 'AVO', 'TIO', 'RESPONSAVEL_LEGAL', 'OUTRO'])
    .optional(),
  isPrimary: z.boolean().optional(),
  canPickup: z.boolean().optional(),
  // Conta do responsável no app, quando existe. Sem isso o QR dele não
  // encontraria a criança — é o que liga o cadastro do balcão ao app.
  userId: z.string().uuid().nullish(),
});

const quickChildSchema = z.object({
  name: z.string().min(1).max(120),
  birthDate: z.coerce.date().nullish(),
  gender: z.enum(['MASCULINO', 'FEMININO']).nullish(),
  allergies: optionalText(500),
  medications: optionalText(500),
  disabilities: optionalText(500),
  medicalNotes: optionalText(1000),
  authorizedPickup: optionalText(500),
  guardians: z.array(guardianSchema).min(1),
});

const checkinSchema = z.object({
  sessionId: z.string().uuid(),
  childIds: z.array(z.string().uuid()).min(1),
  guardianId: z.string().uuid().nullish(),
  method: z.enum(['QR', 'CODE', 'MANUAL']).default('MANUAL'),
  force: z.boolean().optional(),
});

const checkoutSchema = z.object({
  qrToken: z.string().nullish(),
  pickupCode: z.string().regex(/^\d{5}$/).nullish(),
  guardianName: optionalText(120),
  reason: optionalText(300),
});

const noteSchema = z.object({
  kind: z.enum(['INDIVIDUAL', 'CLASS']),
  childId: z.string().uuid().nullish(),
  checkinId: z.string().uuid().nullish(),
  body: z.string().min(1).max(4000),
  visibleToGuardian: z.boolean().optional(),
});

const alertSchema = z.object({
  level: z.enum(['INFO', 'URGENT', 'EMERGENCY']),
  message: z.string().min(1).max(1000),
});

export class KidsController {
  constructor(
    private readonly kidsRepo: IKidsRepository,
    private readonly checkInUseCase: CheckInChildrenUseCase,
    private readonly checkOutUseCase: CheckOutChildUseCase,
    private readonly createAlertUseCase: CreateAlertUseCase,
    private readonly qrService: KidsQrService,
    private readonly pickupCodes: PickupCodeService,
  ) {}

  // ── Salas ─────────────────────────────────────────────────────────────────

  listRooms = async (req: Request, res: Response): Promise<void> => {
    const rooms = await this.kidsRepo.listRooms();
    // Professor vê só as salas dele; ADMIN vê todas.
    if (req.userRole === 'KIDS') {
      res.json({
        rooms: rooms.filter((r) => r.teachers.some((t) => t.userId === req.userId)),
      });
      return;
    }
    res.json({ rooms });
  };

  createRoom = async (req: Request, res: Response): Promise<void> => {
    const body = roomSchema.parse(req.body);
    const room = await this.kidsRepo.createRoom({
      name: body.name,
      description: body.description ?? null,
      capacity: body.capacity,
      minAgeMonths: body.minAgeMonths ?? null,
      maxAgeMonths: body.maxAgeMonths ?? null,
      ...(body.color ? { color: body.color } : {}),
      ...(body.teachers ? { teacherIds: body.teachers } : {}),
    });
    res.status(201).json({ room });
  };

  updateRoom = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const body = roomSchema.partial().extend({ isActive: z.boolean().optional() }).parse(req.body);
    const room = await this.kidsRepo.updateRoom(id, {
      ...(body.name !== undefined ? { name: body.name } : {}),
      ...(body.description !== undefined ? { description: body.description } : {}),
      ...(body.capacity !== undefined ? { capacity: body.capacity } : {}),
      ...(body.minAgeMonths !== undefined ? { minAgeMonths: body.minAgeMonths } : {}),
      ...(body.maxAgeMonths !== undefined ? { maxAgeMonths: body.maxAgeMonths } : {}),
      ...(body.color !== undefined ? { color: body.color } : {}),
      ...(body.isActive !== undefined ? { isActive: body.isActive } : {}),
    });
    res.json({ room });
  };

  deactivateRoom = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const open = await this.kidsRepo.findOpenSessionByRoom(id);
    if (open) {
      throw new AppError(
        'Feche a sessão em andamento antes de desativar a sala',
        409,
        'KIDS_SESSION_OPEN',
      );
    }
    const room = await this.kidsRepo.updateRoom(id, { isActive: false });
    res.json({ room });
  };

  setTeachers = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const { teachers } = teachersSchema.parse(req.body);
    const room = await this.kidsRepo.setRoomTeachers(id, teachers);
    res.json({ room });
  };

  // ── Sessões ───────────────────────────────────────────────────────────────

  openSession = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const body = openSessionSchema.parse(req.body);

    const room = await this.kidsRepo.findRoomById(id);
    if (!room) throw AppError.notFound('Sala não encontrada');
    if (!room.isActive) throw new AppError('Sala desativada', 409, 'KIDS_ROOM_INACTIVE');

    // Reabrir a mesma sala devolve a sessão existente em vez de estourar erro:
    // dois professores tocando "abrir" ao mesmo tempo é rotina no domingo.
    const existing = await this.kidsRepo.findOpenSessionByRoom(id);
    if (existing) {
      res.status(200).json({ session: existing, reused: true });
      return;
    }

    const session = await this.kidsRepo.openSession({
      roomId: id,
      serviceDate: body.serviceDate ?? this.today(),
      serviceName: body.serviceName,
      lesson: body.lesson ?? null,
      capacityOverride: body.capacityOverride ?? null,
      openedById: req.userId,
    });
    res.status(201).json({ session, reused: false });
  };

  getSession = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const session = await this.kidsRepo.findSessionById(id);
    if (!session) throw AppError.notFound('Sessão não encontrada');
    const [checkins, notes] = await Promise.all([
      this.kidsRepo.listCheckinsBySession(id),
      this.kidsRepo.listNotesBySession(id),
    ]);
    res.json({ session, checkins, notes });
  };

  listSessions = async (req: Request, res: Response): Promise<void> => {
    const { roomId, from, to, limit } = req.query as Record<string, string | undefined>;
    const sessions = await this.kidsRepo.listSessions({
      ...(roomId ? { roomId } : {}),
      ...(from ? { from: new Date(from) } : {}),
      ...(to ? { to: new Date(to) } : {}),
      ...(limit ? { limit: Number(limit) } : {}),
    });
    res.json({ sessions });
  };

  updateSession = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const body = z
      .object({ lesson: optionalText(300), capacityOverride: z.number().int().positive().nullish() })
      .parse(req.body);
    const session = await this.kidsRepo.updateSession(id, {
      ...(body.lesson !== undefined ? { lesson: body.lesson } : {}),
      ...(body.capacityOverride !== undefined
        ? { capacityOverride: body.capacityOverride }
        : {}),
    });
    res.json({ session });
  };

  closeSession = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const session = await this.kidsRepo.findSessionById(id);
    if (!session) throw AppError.notFound('Sessão não encontrada');
    if (session.status === 'CLOSED') {
      res.json({ session });
      return;
    }

    // Fechar a sala com criança dentro é o erro que este módulo existe para
    // impedir: a lista de quem ficou volta no corpo do 409.
    const present = await this.kidsRepo.countCheckedInBySession(id);
    if (present > 0) {
      const checkins = await this.kidsRepo.listCheckinsBySession(id);
      throw new AppError(
        `Ainda há ${present} criança(s) na sala. Faça o check-out antes de fechar.`,
        409,
        'KIDS_CHILDREN_STILL_IN_ROOM',
      ).withDetails({
        pending: checkins
          .filter((c) => c.status === 'CHECKED_IN')
          .map((c) => ({ checkinId: c.id, childName: c.childName, badgeCode: c.badgeCode })),
      });
    }

    const closed = await this.kidsRepo.closeSession(id, req.userId);
    res.json({ session: closed });
  };

  // ── Crianças ──────────────────────────────────────────────────────────────

  searchChildren = async (req: Request, res: Response): Promise<void> => {
    const { q } = req.query as { q?: string };
    if (!q || q.trim().length < 2) {
      res.json({ children: [] });
      return;
    }
    const children = await this.kidsRepo.searchChildren(q.trim());
    res.json({ children });
  };

  quickRegisterChild = async (req: Request, res: Response): Promise<void> => {
    const body = quickChildSchema.parse(req.body);
    const child = await this.kidsRepo.createChildWithGuardians({
      name: body.name,
      birthDate: body.birthDate ?? null,
      gender: body.gender ?? null,
      allergies: body.allergies ?? null,
      medications: body.medications ?? null,
      disabilities: body.disabilities ?? null,
      medicalNotes: body.medicalNotes ?? null,
      authorizedPickup: body.authorizedPickup ?? null,
      guardians: body.guardians,
    });
    res.status(201).json({ child });
  };

  getChild = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const child = await this.kidsRepo.findChildById(id);
    if (!child) throw AppError.notFound('Criança não encontrada');
    await this.assertChildVisible(req, id);
    res.json({ child });
  };

  updateChild = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    await this.assertChildVisible(req, id);
    const body = quickChildSchema.partial().omit({ guardians: true }).parse(req.body);
    const child = await this.kidsRepo.updateChild(id, {
      ...(body.name !== undefined ? { name: body.name } : {}),
      ...(body.birthDate !== undefined ? { birthDate: body.birthDate ?? null } : {}),
      ...(body.gender !== undefined ? { gender: body.gender ?? null } : {}),
      ...(body.allergies !== undefined ? { allergies: body.allergies } : {}),
      ...(body.medications !== undefined ? { medications: body.medications } : {}),
      ...(body.disabilities !== undefined ? { disabilities: body.disabilities } : {}),
      ...(body.medicalNotes !== undefined ? { medicalNotes: body.medicalNotes } : {}),
      ...(body.authorizedPickup !== undefined
        ? { authorizedPickup: body.authorizedPickup }
        : {}),
    });
    res.json({ child });
  };

  addGuardian = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    await this.assertChildVisible(req, id);
    const body = guardianSchema.parse(req.body);
    const child = await this.kidsRepo.addGuardian(id, body);
    res.status(201).json({ child });
  };

  childHistory = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    await this.assertChildVisible(req, id);
    const history = await this.kidsRepo.childHistory(id);
    res.json({ history });
  };

  childNotes = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    await this.assertChildVisible(req, id);
    // O pai só vê o que o professor marcou como visível.
    const onlyVisible = req.userRole === 'RESPONSAVEL';
    const notes = await this.kidsRepo.listNotesByChild(id, onlyVisible);
    res.json({ notes });
  };

  // ── Check-in / check-out ──────────────────────────────────────────────────

  resolveQr = async (req: Request, res: Response): Promise<void> => {
    const { qrToken } = z.object({ qrToken: z.string().min(10) }).parse(req.body);
    const resolved = await this.qrService.consume(qrToken, req.churchId);
    const children = await this.kidsRepo.findChildrenByGuardianUser(resolved.guardianUserId);
    if (children.length === 0) {
      throw new AppError(
        'Nenhuma criança vinculada a este responsável',
        404,
        'KIDS_NO_CHILDREN',
      );
    }

    // Quem já está em alguma sala aparece marcado, para o professor não tentar
    // dar entrada duas vezes.
    const enriched = await Promise.all(
      children.map(async (child) => ({
        ...child,
        openCheckin: await this.kidsRepo.findOpenCheckinByChild(child.id),
      })),
    );
    res.json({ guardianUserId: resolved.guardianUserId, children: enriched });
  };

  checkIn = async (req: Request, res: Response): Promise<void> => {
    const body = checkinSchema.parse(req.body);
    if (body.force && req.userRole !== 'ADMIN' && req.userRole !== 'SUPERADMIN') {
      throw AppError.forbidden('Só administradores podem ignorar a faixa etária');
    }
    const result = await this.checkInUseCase.execute({
      sessionId: body.sessionId,
      childIds: body.childIds,
      guardianId: body.guardianId ?? null,
      method: body.method,
      checkinById: req.userId,
      ...(body.force !== undefined ? { force: body.force } : {}),
    });
    res.status(201).json(result);
  };

  getCheckin = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const checkin = await this.kidsRepo.findCheckinById(id);
    if (!checkin) throw AppError.notFound('Check-in não encontrado');
    res.json({ checkin });
  };

  checkOut = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const body = checkoutSchema.parse(req.body);
    const checkin = await this.checkOutUseCase.execute({
      checkinId: id,
      checkoutById: req.userId,
      checkoutByRole: req.userRole,
      qrToken: body.qrToken ?? null,
      pickupCode: body.pickupCode ?? null,
      manual:
        body.guardianName && body.reason
          ? { guardianName: body.guardianName, reason: body.reason }
          : null,
      readerChurchId: req.churchId,
    });
    res.json({ checkin });
  };

  regenerateCode = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const checkin = await this.kidsRepo.findCheckinById(id);
    if (!checkin) throw AppError.notFound('Check-in não encontrado');
    if (checkin.status !== 'CHECKED_IN') {
      throw new AppError('Check-in já encerrado', 409, 'KIDS_ALREADY_CHECKED_OUT');
    }
    const code = this.pickupCodes.generate();
    await this.kidsRepo.replacePickupCode(
      id,
      await this.pickupCodes.hash(code),
      this.pickupCodes.last2(code),
    );
    // A senha anterior deixa de valer no mesmo instante.
    res.json({ pickupCode: code });
  };

  // ── Anotações ─────────────────────────────────────────────────────────────

  createNote = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const body = noteSchema.parse(req.body);
    if (body.kind === 'INDIVIDUAL' && !body.childId) {
      throw new AppError('Anotação individual precisa da criança');
    }
    const note = await this.kidsRepo.createNote({
      sessionId: id,
      kind: body.kind,
      childId: body.kind === 'CLASS' ? null : body.childId ?? null,
      checkinId: body.checkinId ?? null,
      body: body.body,
      ...(body.visibleToGuardian !== undefined
        ? { visibleToGuardian: body.visibleToGuardian }
        : {}),
      authorId: req.userId,
    });
    res.status(201).json({ note });
  };

  updateNote = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const note = await this.kidsRepo.findNoteById(id);
    if (!note) throw AppError.notFound('Anotação não encontrada');
    if (note.authorId !== req.userId && req.userRole === 'KIDS') {
      throw AppError.forbidden('Só o autor pode editar a anotação');
    }
    const body = z
      .object({ body: z.string().min(1).max(4000).optional(), visibleToGuardian: z.boolean().optional() })
      .parse(req.body);
    const updated = await this.kidsRepo.updateNote(id, body);
    res.json({ note: updated });
  };

  deleteNote = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    await this.kidsRepo.deleteNote(id);
    res.status(204).send();
  };

  // ── Alertas ───────────────────────────────────────────────────────────────

  createAlert = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const body = alertSchema.parse(req.body);
    const alert = await this.createAlertUseCase.execute({
      checkinId: id,
      level: body.level,
      message: body.message,
      createdById: req.userId,
    });
    res.status(201).json({ alert });
  };

  listAlerts = async (req: Request, res: Response): Promise<void> => {
    const { status, sessionId, level, limit } = req.query as Record<string, string | undefined>;
    const alerts = await this.kidsRepo.listAlerts({
      ...(status ? { status: status as 'OPEN' | 'ACKNOWLEDGED' | 'RESOLVED' } : {}),
      ...(sessionId ? { sessionId } : {}),
      ...(level ? { level: level as 'INFO' | 'URGENT' | 'EMERGENCY' } : {}),
      ...(limit ? { limit: Number(limit) } : {}),
    });
    res.json({ alerts });
  };

  acknowledgeAlert = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const alert = await this.kidsRepo.findAlertById(id);
    if (!alert) throw AppError.notFound('Alerta não encontrado');

    const child = await this.kidsRepo.findChildById(alert.childId);
    const guardian = child?.guardians.find((g) => g.userId === req.userId) ?? null;
    if (!guardian && child?.userId !== req.userId && req.userRole === 'RESPONSAVEL') {
      throw AppError.forbidden('Este alerta não é sobre um filho seu');
    }

    const updated = await this.kidsRepo.acknowledgeAlert(id, guardian?.id ?? null);
    res.json({ alert: updated });
  };

  resolveAlert = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const alert = await this.kidsRepo.resolveAlert(id, req.userId);
    res.json({ alert });
  };

  registerCall = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const alert = await this.kidsRepo.findAlertById(id);
    if (!alert) throw AppError.notFound('Alerta não encontrado');

    // A entrega por telefone só existe quando alguém realmente discou — é o
    // registro do ato humano, não de um envio automático.
    const pending = alert.deliveries.find((d) => d.channel === 'CALL' && d.status === 'QUEUED');
    if (!pending) {
      throw new AppError('Nenhuma ligação pendente neste alerta', 409, 'KIDS_NO_PENDING_CALL');
    }
    await this.kidsRepo.markDeliverySent(pending.id, null);
    const updated = await this.kidsRepo.findAlertById(id);
    res.json({ alert: updated });
  };

  // ── Responsável (app do pai) ──────────────────────────────────────────────

  myQr = async (req: Request, res: Response): Promise<void> => {
    const { token, expiresIn } = this.qrService.issue(req.userId, req.churchId);
    res.json({ token, expiresIn });
  };

  myChildren = async (req: Request, res: Response): Promise<void> => {
    const children = await this.kidsRepo.findChildrenByGuardianUser(req.userId);
    const withStatus = await Promise.all(
      children.map(async (child) => ({
        ...child,
        openCheckin: await this.kidsRepo.findOpenCheckinByChild(child.id),
      })),
    );
    res.json({ children: withStatus });
  };

  myAlerts = async (req: Request, res: Response): Promise<void> => {
    const alerts = await this.kidsRepo.listAlertsForGuardianUser(req.userId);
    res.json({ alerts });
  };

  // ── Relatórios ────────────────────────────────────────────────────────────

  overview = async (req: Request, res: Response): Promise<void> => {
    const { from, to } = req.query as { from?: string; to?: string };
    const end = to ? new Date(to) : new Date();
    const start = from ? new Date(from) : new Date(end.getTime() - 90 * 24 * 60 * 60 * 1000);
    const report = await this.kidsRepo.overview(start, end);
    res.json({ report });
  };

  // ── Helpers ───────────────────────────────────────────────────────────────

  /** Hoje sem hora — `service_date` é `date` no banco. */
  private today(): Date {
    const now = new Date();
    return new Date(Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()));
  }

  /**
   * Ficha de criança carrega dado de saúde, então o acesso é restrito: ADMIN,
   * responsável da própria criança, ou professor da sala onde ela está agora.
   */
  private async assertChildVisible(req: Request, childId: string): Promise<void> {
    if (req.userRole === 'ADMIN' || req.userRole === 'SUPERADMIN') return;

    const child = await this.kidsRepo.findChildById(childId);
    if (!child) throw AppError.notFound('Criança não encontrada');

    if (req.userRole === 'RESPONSAVEL') {
      const isGuardian =
        child.userId === req.userId || child.guardians.some((g) => g.userId === req.userId);
      if (!isGuardian) throw AppError.forbidden('Esta criança não é sua');
      return;
    }

    if (req.userRole === 'KIDS') {
      const open = await this.kidsRepo.findOpenCheckinByChild(childId);
      const allowed =
        open !== null && (await this.kidsRepo.isTeacherOfSession(open.sessionId, req.userId));
      if (!allowed) {
        throw AppError.forbidden('A criança não está em uma sala sua');
      }
      return;
    }

    throw AppError.forbidden('Acesso negado');
  }
}
