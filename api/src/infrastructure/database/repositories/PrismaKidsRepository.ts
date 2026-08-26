import type { Prisma, PrismaClient } from '@prisma/client';
import type {
  ChildHealth,
  CreateAlertData,
  CreateKidsRoomData,
  CreateNoteData,
  GuardianInput,
  KidsAlert,
  KidsAlertLevel,
  KidsCheckin,
  KidsChild,
  KidsNote,
  KidsOverviewReport,
  KidsRoom,
  KidsSessionSummary,
  KidsTeacherRole,
  OpenSessionData,
  QuickRegisterChildData,
  UpdateKidsRoomData,
} from '@domain/entities/Kids';
import type {
  CheckinEntry,
  CheckoutRecord,
  IKidsRepository,
  PickupState,
  PlannedDelivery,
} from '@domain/repositories/IKidsRepository';
import { getEffectiveChurchId } from '@shared/context/tenant-context';

// Includes reaproveitados: o mapeamento depende deles, então ficam ao lado.
const roomInclude = {
  teachers: { include: { user: { select: { name: true } } } },
} satisfies Prisma.KidsRoomInclude;

const sessionInclude = {
  room: { select: { name: true, capacity: true } },
  _count: { select: { checkins: true } },
} satisfies Prisma.KidsSessionInclude;

const childInclude = {
  guardians: { orderBy: [{ isPrimary: 'desc' }, { name: 'asc' }] },
} satisfies Prisma.ChildInclude;

const checkinInclude = {
  child: true,
  checkinGuardian: { select: { name: true } },
  checkoutGuardian: { select: { name: true } },
  alerts: { where: { status: { not: 'RESOLVED' } }, select: { id: true } },
} satisfies Prisma.KidsCheckinInclude;

const noteInclude = {
  child: { select: { name: true } },
  author: { select: { name: true } },
} satisfies Prisma.KidsNoteInclude;

const alertInclude = {
  session: {
    select: { status: true, serviceDate: true, room: { select: { name: true } } },
  },
  child: {
    select: {
      name: true,
      guardians: {
        orderBy: [{ isPrimary: 'desc' }, { name: 'asc' }],
        select: { phone: true },
      },
    },
  },
  createdBy: { select: { name: true } },
  deliveries: {
    include: { guardian: { select: { name: true } } },
    orderBy: { queuedAt: 'asc' },
  },
} satisfies Prisma.KidsAlertInclude;

type RoomRow = Prisma.KidsRoomGetPayload<{ include: typeof roomInclude }>;
type SessionRow = Prisma.KidsSessionGetPayload<{ include: typeof sessionInclude }>;
type ChildRow = Prisma.ChildGetPayload<{ include: typeof childInclude }>;
type CheckinRow = Prisma.KidsCheckinGetPayload<{ include: typeof checkinInclude }>;
type NoteRow = Prisma.KidsNoteGetPayload<{ include: typeof noteInclude }>;
type AlertRow = Prisma.KidsAlertGetPayload<{ include: typeof alertInclude }>;

export class PrismaKidsRepository implements IKidsRepository {
  constructor(private readonly prisma: PrismaClient) {}

  // ── Salas ─────────────────────────────────────────────────────────────────

  async listRooms(): Promise<KidsRoom[]> {
    const rows = await this.prisma.kidsRoom.findMany({
      include: roomInclude,
      orderBy: [{ isActive: 'desc' }, { name: 'asc' }],
    });
    // Uma consulta só para as sessões abertas de todas as salas — evita N+1 na
    // tela inicial do professor, que é a mais acessada do módulo.
    const open = await this.prisma.kidsSession.findMany({
      where: { roomId: { in: rows.map((r) => r.id) }, status: 'OPEN' },
      include: sessionInclude,
    });
    const openByRoom = new Map<string, SessionRow>();
    for (const s of open) openByRoom.set(s.roomId, s);

    const presentCounts = await this.presentCountBySession(open.map((s) => s.id));
    const alertCounts = await this.openAlertCountBySession(open.map((s) => s.id));

    return rows.map((row) => {
      const session = openByRoom.get(row.id);
      return this.mapRoom(
        row,
        session
          ? this.mapSession(
              session,
              presentCounts.get(session.id) ?? 0,
              alertCounts.get(session.id) ?? 0,
            )
          : null,
      );
    });
  }

  async findRoomById(id: string): Promise<KidsRoom | null> {
    const row = await this.prisma.kidsRoom.findFirst({
      where: { id },
      include: roomInclude,
    });
    if (!row) return null;
    const openSession = await this.findOpenSessionByRoom(id);
    return this.mapRoom(row, openSession);
  }

  async countActiveRooms(): Promise<number> {
    return this.prisma.kidsRoom.count({ where: { isActive: true } });
  }

  async createRoom(data: CreateKidsRoomData): Promise<KidsRoom> {
    const churchId = getEffectiveChurchId() ?? null;
    const room = await this.prisma.kidsRoom.create({
      data: {
        name: data.name,
        description: data.description ?? null,
        capacity: data.capacity,
        minAgeMonths: data.minAgeMonths ?? null,
        maxAgeMonths: data.maxAgeMonths ?? null,
        ...(data.color ? { color: data.color } : {}),
        ...(data.teacherIds?.length
          ? {
              teachers: {
                create: data.teacherIds.map((t) => ({
                  userId: t.userId,
                  role: t.role,
                  churchId,
                })),
              },
            }
          : {}),
      },
      include: roomInclude,
    });
    return this.mapRoom(room, null);
  }

  async updateRoom(id: string, data: UpdateKidsRoomData): Promise<KidsRoom> {
    await this.prisma.kidsRoom.updateMany({
      where: { id },
      data: {
        ...(data.name !== undefined ? { name: data.name } : {}),
        ...(data.description !== undefined ? { description: data.description } : {}),
        ...(data.capacity !== undefined ? { capacity: data.capacity } : {}),
        ...(data.minAgeMonths !== undefined ? { minAgeMonths: data.minAgeMonths } : {}),
        ...(data.maxAgeMonths !== undefined ? { maxAgeMonths: data.maxAgeMonths } : {}),
        ...(data.color !== undefined ? { color: data.color } : {}),
        ...(data.isActive !== undefined ? { isActive: data.isActive } : {}),
      },
    });
    const room = await this.findRoomById(id);
    if (!room) throw new Error('Sala não encontrada após atualização');
    return room;
  }

  async setRoomTeachers(
    roomId: string,
    teachers: { userId: string; role: KidsTeacherRole }[],
  ): Promise<KidsRoom> {
    const churchId = getEffectiveChurchId() ?? null;
    await this.prisma.$transaction([
      this.prisma.kidsRoomTeacher.deleteMany({ where: { roomId } }),
      ...(teachers.length
        ? [
            this.prisma.kidsRoomTeacher.createMany({
              data: teachers.map((t) => ({
                roomId,
                userId: t.userId,
                role: t.role,
                churchId,
              })),
              skipDuplicates: true,
            }),
          ]
        : []),
    ]);
    const room = await this.findRoomById(roomId);
    if (!room) throw new Error('Sala não encontrada');
    return room;
  }

  async isTeacherOfRoom(roomId: string, userId: string): Promise<boolean> {
    const found = await this.prisma.kidsRoomTeacher.findFirst({
      where: { roomId, userId },
      select: { id: true },
    });
    return found !== null;
  }

  async isTeacherOfSession(sessionId: string, userId: string): Promise<boolean> {
    const session = await this.prisma.kidsSession.findFirst({
      where: { id: sessionId },
      select: { roomId: true },
    });
    if (!session) return false;
    return this.isTeacherOfRoom(session.roomId, userId);
  }

  // ── Sessões ───────────────────────────────────────────────────────────────

  async openSession(data: OpenSessionData): Promise<KidsSessionSummary> {
    const row = await this.prisma.kidsSession.create({
      data: {
        roomId: data.roomId,
        serviceDate: data.serviceDate,
        serviceName: data.serviceName,
        lesson: data.lesson ?? null,
        capacityOverride: data.capacityOverride ?? null,
        openedById: data.openedById,
      },
      include: sessionInclude,
    });
    return this.mapSession(row, 0, 0);
  }

  async findSessionById(id: string): Promise<KidsSessionSummary | null> {
    const row = await this.prisma.kidsSession.findFirst({
      where: { id },
      include: sessionInclude,
    });
    if (!row) return null;
    const present = await this.countCheckedInBySession(id);
    const alerts = await this.prisma.kidsAlert.count({
      where: { sessionId: id, status: { not: 'RESOLVED' } },
    });
    return this.mapSession(row, present, alerts);
  }

  async findOpenSessionByRoom(roomId: string): Promise<KidsSessionSummary | null> {
    const row = await this.prisma.kidsSession.findFirst({
      where: { roomId, status: 'OPEN' },
      include: sessionInclude,
      orderBy: { openedAt: 'desc' },
    });
    if (!row) return null;
    const present = await this.countCheckedInBySession(row.id);
    const alerts = await this.prisma.kidsAlert.count({
      where: { sessionId: row.id, status: { not: 'RESOLVED' } },
    });
    return this.mapSession(row, present, alerts);
  }

  async listSessions(filter: {
    roomId?: string;
    from?: Date;
    to?: Date;
    limit?: number;
  }): Promise<KidsSessionSummary[]> {
    const rows = await this.prisma.kidsSession.findMany({
      where: {
        ...(filter.roomId ? { roomId: filter.roomId } : {}),
        ...(filter.from || filter.to
          ? {
              serviceDate: {
                ...(filter.from ? { gte: filter.from } : {}),
                ...(filter.to ? { lte: filter.to } : {}),
              },
            }
          : {}),
      },
      include: sessionInclude,
      orderBy: [{ serviceDate: 'desc' }, { openedAt: 'desc' }],
      take: filter.limit ?? 50,
    });
    const ids = rows.map((r) => r.id);
    const present = await this.presentCountBySession(ids);
    const alerts = await this.openAlertCountBySession(ids);
    return rows.map((r) =>
      this.mapSession(r, present.get(r.id) ?? 0, alerts.get(r.id) ?? 0),
    );
  }

  async updateSession(
    id: string,
    data: { lesson?: string | null; capacityOverride?: number | null },
  ): Promise<KidsSessionSummary> {
    await this.prisma.kidsSession.updateMany({
      where: { id },
      data: {
        ...(data.lesson !== undefined ? { lesson: data.lesson } : {}),
        ...(data.capacityOverride !== undefined
          ? { capacityOverride: data.capacityOverride }
          : {}),
      },
    });
    const session = await this.findSessionById(id);
    if (!session) throw new Error('Sessão não encontrada');
    return session;
  }

  async closeSession(id: string, closedById: string): Promise<KidsSessionSummary> {
    await this.prisma.kidsSession.updateMany({
      where: { id },
      data: { status: 'CLOSED', closedAt: new Date(), closedById },
    });
    const session = await this.findSessionById(id);
    if (!session) throw new Error('Sessão não encontrada');
    return session;
  }

  async countCheckedInBySession(sessionId: string): Promise<number> {
    return this.prisma.kidsCheckin.count({
      where: { sessionId, status: 'CHECKED_IN' },
    });
  }

  // ── Crianças ──────────────────────────────────────────────────────────────

  async searchChildren(query: string, limit = 20): Promise<KidsChild[]> {
    const term = query.trim();
    // Busca por nome da criança OU telefone do responsável: no balcão, o que a
    // professora tem em mãos costuma ser o celular do pai.
    const rows = await this.prisma.child.findMany({
      where: {
        isActive: true,
        OR: [
          { name: { contains: term, mode: 'insensitive' } },
          { guardians: { some: { phone: { contains: term } } } },
          { guardians: { some: { name: { contains: term, mode: 'insensitive' } } } },
        ],
      },
      include: childInclude,
      orderBy: { name: 'asc' },
      take: limit,
    });
    return rows.map((r) => this.mapChild(r));
  }

  async findChildById(id: string): Promise<KidsChild | null> {
    const row = await this.prisma.child.findFirst({ where: { id }, include: childInclude });
    return row ? this.mapChild(row) : null;
  }

  async findChildrenByGuardianUser(userId: string): Promise<KidsChild[]> {
    // Duas origens de vínculo: filho declarado no perfil (`userId`) e
    // responsável cadastrado na salinha que depois criou conta (`guardians`).
    const rows = await this.prisma.child.findMany({
      where: {
        isActive: true,
        OR: [{ userId }, { guardians: { some: { userId } } }],
      },
      include: childInclude,
      orderBy: { name: 'asc' },
    });
    return rows.map((r) => this.mapChild(r));
  }

  async createChildWithGuardians(data: QuickRegisterChildData): Promise<KidsChild> {
    const churchId = getEffectiveChurchId() ?? null;
    const row = await this.prisma.child.create({
      data: {
        name: data.name,
        birthDate: data.birthDate ?? null,
        gender: data.gender ?? null,
        allergies: data.allergies ?? null,
        medications: data.medications ?? null,
        disabilities: data.disabilities ?? null,
        medicalNotes: data.medicalNotes ?? null,
        authorizedPickup: data.authorizedPickup ?? null,
        guardians: {
          create: data.guardians.map((g, index) => ({
            churchId,
            name: g.name,
            phone: g.phone,
            hasWhatsapp: g.hasWhatsapp ?? true,
            relation: g.relation ?? 'RESPONSAVEL_LEGAL',
            // Sem indicação explícita, o primeiro da lista é o primário — é
            // quem o alerta procura antes de todo mundo.
            isPrimary: g.isPrimary ?? index === 0,
            canPickup: g.canPickup ?? true,
            userId: g.userId ?? null,
          })),
        },
      },
      include: childInclude,
    });
    return this.mapChild(row);
  }

  async updateChild(
    id: string,
    data: Partial<{
      name: string;
      birthDate: Date | null;
      gender: string | null;
      allergies: string | null;
      medications: string | null;
      disabilities: string | null;
      medicalNotes: string | null;
      authorizedPickup: string | null;
      isActive: boolean;
      userId: string | null;
      cellMemberId: string | null;
      visitorId: string | null;
    }>,
  ): Promise<KidsChild> {
    await this.prisma.child.updateMany({
      where: { id },
      data: data as Prisma.ChildUpdateManyMutationInput,
    });
    const child = await this.findChildById(id);
    if (!child) throw new Error('Criança não encontrada');
    return child;
  }

  async addGuardian(childId: string, guardian: GuardianInput): Promise<KidsChild> {
    const churchId = getEffectiveChurchId() ?? null;
    await this.prisma.kidsGuardian.create({
      data: {
        childId,
        churchId,
        name: guardian.name,
        phone: guardian.phone,
        hasWhatsapp: guardian.hasWhatsapp ?? true,
        relation: guardian.relation ?? 'RESPONSAVEL_LEGAL',
        isPrimary: guardian.isPrimary ?? false,
        canPickup: guardian.canPickup ?? true,
        userId: guardian.userId ?? null,
      },
    });
    const child = await this.findChildById(childId);
    if (!child) throw new Error('Criança não encontrada');
    return child;
  }

  async linkGuardiansByPhone(phone: string, userId: string): Promise<number> {
    // Compara pelos últimos 11 dígitos: sobrevive a diferenças de DDI/máscara
    // entre o telefone digitado no balcão e o digitado no cadastro da conta.
    const target = phone.replace(/\D/g, '').slice(-11);
    if (target.length < 8) return 0;

    const candidates = await this.prisma.kidsGuardian.findMany({
      where: { userId: null },
      select: { id: true, phone: true },
    });
    const matchIds = candidates
      .filter((g) => g.phone.replace(/\D/g, '').slice(-11) === target)
      .map((g) => g.id);
    if (matchIds.length === 0) return 0;

    const result = await this.prisma.kidsGuardian.updateMany({
      where: { id: { in: matchIds } },
      data: { userId },
    });
    return result.count;
  }

  // ── Check-in / check-out ──────────────────────────────────────────────────

  async listCheckinsBySession(sessionId: string): Promise<KidsCheckin[]> {
    const rows = await this.prisma.kidsCheckin.findMany({
      where: { sessionId },
      include: checkinInclude,
      orderBy: [{ status: 'asc' }, { checkinAt: 'asc' }],
    });
    return rows.map((r) => this.mapCheckin(r));
  }

  async findCheckinById(id: string): Promise<KidsCheckin | null> {
    const row = await this.prisma.kidsCheckin.findFirst({
      where: { id },
      include: checkinInclude,
    });
    return row ? this.mapCheckin(row) : null;
  }

  async findOpenCheckinByChild(childId: string): Promise<KidsCheckin | null> {
    const row = await this.prisma.kidsCheckin.findFirst({
      where: { childId, status: 'CHECKED_IN', session: { status: 'OPEN' } },
      include: checkinInclude,
    });
    return row ? this.mapCheckin(row) : null;
  }

  async nextBadgeNumber(sessionId: string): Promise<number> {
    const count = await this.prisma.kidsCheckin.count({ where: { sessionId } });
    return count + 1;
  }

  async createCheckins(entries: CheckinEntry[]): Promise<KidsCheckin[]> {
    const churchId = getEffectiveChurchId() ?? null;
    const created = await this.prisma.$transaction(
      entries.map((e) =>
        this.prisma.kidsCheckin.create({
          data: {
            churchId,
            sessionId: e.sessionId,
            childId: e.childId,
            badgeCode: e.badgeCode,
            checkinById: e.checkinById,
            checkinMethod: e.checkinMethod,
            checkinGuardianId: e.checkinGuardianId,
            pickupCodeHash: e.pickupCodeHash,
            pickupCodeLast2: e.pickupCodeLast2,
          },
          include: checkinInclude,
        }),
      ),
    );
    return created.map((r) => this.mapCheckin(r));
  }

  async registerCheckout(data: CheckoutRecord): Promise<KidsCheckin> {
    await this.prisma.kidsCheckin.updateMany({
      where: { id: data.checkinId },
      data: {
        status: 'CHECKED_OUT',
        checkoutAt: new Date(),
        checkoutById: data.checkoutById,
        checkoutMethod: data.checkoutMethod,
        checkoutGuardianId: data.checkoutGuardianId,
        checkoutGuardianName: data.checkoutGuardianName,
        checkoutReason: data.checkoutReason,
        // Senha morre com a retirada: nada de reaproveitar código antigo.
        pickupCodeHash: null,
        pickupAttempts: 0,
        pickupLockedUntil: null,
      },
    });
    const checkin = await this.findCheckinById(data.checkinId);
    if (!checkin) throw new Error('Check-in não encontrado');
    return checkin;
  }

  async getPickupState(checkinId: string): Promise<PickupState | null> {
    const row = await this.prisma.kidsCheckin.findFirst({
      where: { id: checkinId },
      select: {
        id: true,
        status: true,
        pickupCodeHash: true,
        pickupAttempts: true,
        pickupLockedUntil: true,
      },
    });
    if (!row) return null;
    return {
      checkinId: row.id,
      status: row.status,
      pickupCodeHash: row.pickupCodeHash,
      attempts: row.pickupAttempts,
      lockedUntil: row.pickupLockedUntil,
    };
  }

  async registerPickupFailure(checkinId: string, lockUntil: Date | null): Promise<number> {
    const updated = await this.prisma.kidsCheckin.update({
      where: { id: checkinId },
      data: {
        pickupAttempts: { increment: 1 },
        ...(lockUntil ? { pickupLockedUntil: lockUntil } : {}),
      },
      select: { pickupAttempts: true },
    });
    return updated.pickupAttempts;
  }

  async replacePickupCode(checkinId: string, hash: string, last2: string): Promise<void> {
    await this.prisma.kidsCheckin.updateMany({
      where: { id: checkinId },
      data: {
        pickupCodeHash: hash,
        pickupCodeLast2: last2,
        pickupAttempts: 0,
        pickupLockedUntil: null,
      },
    });
  }

  // ── Anotações ─────────────────────────────────────────────────────────────

  async createNote(data: CreateNoteData): Promise<KidsNote> {
    const row = await this.prisma.kidsNote.create({
      data: {
        sessionId: data.sessionId,
        kind: data.kind,
        childId: data.childId ?? null,
        checkinId: data.checkinId ?? null,
        body: data.body,
        visibleToGuardian: data.visibleToGuardian ?? true,
        authorId: data.authorId,
      },
      include: noteInclude,
    });
    return this.mapNote(row);
  }

  async updateNote(
    id: string,
    data: { body?: string | undefined; visibleToGuardian?: boolean | undefined },
  ): Promise<KidsNote> {
    await this.prisma.kidsNote.updateMany({
      where: { id },
      data: {
        ...(data.body !== undefined ? { body: data.body } : {}),
        ...(data.visibleToGuardian !== undefined
          ? { visibleToGuardian: data.visibleToGuardian }
          : {}),
      },
    });
    const note = await this.findNoteById(id);
    if (!note) throw new Error('Anotação não encontrada');
    return note;
  }

  async listNotesBySession(sessionId: string): Promise<KidsNote[]> {
    const rows = await this.prisma.kidsNote.findMany({
      where: { sessionId },
      include: noteInclude,
      orderBy: { createdAt: 'desc' },
    });
    return rows.map((r) => this.mapNote(r));
  }

  async listNotesByChild(
    childId: string,
    onlyVisibleToGuardian: boolean,
  ): Promise<KidsNote[]> {
    const rows = await this.prisma.kidsNote.findMany({
      where: {
        ...(onlyVisibleToGuardian ? { visibleToGuardian: true } : {}),
        // Anotação geral da aula também interessa ao pai: ele quer saber o que
        // foi dado na sala em que o filho estava.
        OR: [
          { childId },
          { kind: 'CLASS', session: { checkins: { some: { childId } } } },
        ],
      },
      include: noteInclude,
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    return rows.map((r) => this.mapNote(r));
  }

  async findNoteById(id: string): Promise<KidsNote | null> {
    const row = await this.prisma.kidsNote.findFirst({ where: { id }, include: noteInclude });
    return row ? this.mapNote(row) : null;
  }

  async deleteNote(id: string): Promise<void> {
    await this.prisma.kidsNote.deleteMany({ where: { id } });
  }

  // ── Alertas ───────────────────────────────────────────────────────────────

  async createAlertWithDeliveries(
    data: CreateAlertData & { sessionId: string; childId: string },
    deliveries: PlannedDelivery[],
  ): Promise<KidsAlert> {
    const churchId = getEffectiveChurchId() ?? null;
    const row = await this.prisma.kidsAlert.create({
      data: {
        sessionId: data.sessionId,
        childId: data.childId,
        checkinId: data.checkinId,
        level: data.level,
        message: data.message,
        createdById: data.createdById,
        deliveries: {
          create: deliveries.map((d) => ({
            churchId,
            channel: d.channel,
            guardianId: d.guardianId,
            userId: d.userId,
          })),
        },
      },
      include: alertInclude,
    });
    return this.mapAlert(row);
  }

  async findAlertById(id: string): Promise<KidsAlert | null> {
    const row = await this.prisma.kidsAlert.findFirst({ where: { id }, include: alertInclude });
    return row ? this.mapAlert(row) : null;
  }

  async listAlerts(filter: {
    status?: 'OPEN' | 'ACKNOWLEDGED' | 'RESOLVED';
    sessionId?: string;
    level?: KidsAlertLevel;
    limit?: number;
  }): Promise<KidsAlert[]> {
    const rows = await this.prisma.kidsAlert.findMany({
      where: {
        ...(filter.status ? { status: filter.status } : {}),
        ...(filter.sessionId ? { sessionId: filter.sessionId } : {}),
        ...(filter.level ? { level: filter.level } : {}),
      },
      include: alertInclude,
      orderBy: { createdAt: 'desc' },
      take: filter.limit ?? 50,
    });
    return rows.map((r) => this.mapAlert(r));
  }

  async listAlertsForGuardianUser(userId: string, limit = 30): Promise<KidsAlert[]> {
    const rows = await this.prisma.kidsAlert.findMany({
      where: {
        child: { OR: [{ userId }, { guardians: { some: { userId } } }] },
      },
      include: alertInclude,
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
    return rows.map((r) => this.mapAlert(r));
  }

  async acknowledgeAlert(id: string, guardianId: string | null): Promise<KidsAlert> {
    await this.prisma.kidsAlert.updateMany({
      // Só o primeiro "estou indo" conta — reconfirmar não reescreve o horário.
      where: { id, acknowledgedAt: null },
      data: {
        status: 'ACKNOWLEDGED',
        acknowledgedAt: new Date(),
        acknowledgedByGuardianId: guardianId,
      },
    });
    const alert = await this.findAlertById(id);
    if (!alert) throw new Error('Alerta não encontrado');
    return alert;
  }

  async resolveAlert(id: string, resolvedById: string): Promise<KidsAlert> {
    await this.prisma.kidsAlert.updateMany({
      where: { id },
      data: { status: 'RESOLVED', resolvedAt: new Date(), resolvedById },
    });
    const alert = await this.findAlertById(id);
    if (!alert) throw new Error('Alerta não encontrado');
    return alert;
  }

  async markDeliverySent(
    deliveryId: string,
    providerMessageId?: string | null,
  ): Promise<void> {
    await this.prisma.kidsAlertDelivery.updateMany({
      where: { id: deliveryId },
      data: {
        status: 'SENT',
        sentAt: new Date(),
        attempts: { increment: 1 },
        providerMessageId: providerMessageId ?? null,
      },
    });
  }

  async markDeliveryFailed(deliveryId: string, error: string): Promise<void> {
    await this.prisma.kidsAlertDelivery.updateMany({
      where: { id: deliveryId },
      data: { status: 'FAILED', error, attempts: { increment: 1 } },
    });
  }

  // ── Relatórios ────────────────────────────────────────────────────────────

  async overview(from: Date, to: Date): Promise<KidsOverviewReport> {
    const churchId = getEffectiveChurchId() ?? null;

    const [sessions, checkins, uniqueChildren, alertRows, roomRows] = await Promise.all([
      this.prisma.kidsSession.count({ where: { serviceDate: { gte: from, lte: to } } }),
      this.prisma.kidsCheckin.count({ where: { checkinAt: { gte: from, lte: to } } }),
      this.prisma.kidsCheckin
        .findMany({
          where: { checkinAt: { gte: from, lte: to } },
          select: { childId: true },
          distinct: ['childId'],
        })
        .then((r) => r.length),
      this.prisma.kidsAlert.groupBy({
        by: ['level'],
        where: { createdAt: { gte: from, lte: to } },
        _count: { _all: true },
      }),
      this.prisma.$queryRaw<
        Array<{
          room_id: string;
          room_name: string;
          capacity: number;
          sessions: bigint;
          checkins: bigint;
        }>
      >`
        SELECT
          r.id                        AS room_id,
          r.name                      AS room_name,
          r.capacity,
          COUNT(DISTINCT s.id)::bigint AS sessions,
          COUNT(c.id)::bigint          AS checkins
        FROM kids_rooms r
        LEFT JOIN kids_sessions s
          ON s.room_id = r.id
         AND s.service_date BETWEEN ${from} AND ${to}
        LEFT JOIN kids_checkins c ON c.session_id = s.id
        WHERE (${churchId}::text IS NULL OR r.church_id = ${churchId})
        GROUP BY r.id, r.name, r.capacity
        ORDER BY r.name
      `,
    ]);

    return {
      from,
      to,
      sessions,
      checkins,
      uniqueChildren,
      averagePerSession: sessions === 0 ? 0 : Math.round((checkins / sessions) * 10) / 10,
      alerts: alertRows.map((a) => ({
        level: a.level as KidsAlertLevel,
        count: a._count._all,
      })),
      rooms: roomRows.map((r) => {
        const roomSessions = Number(r.sessions);
        const roomCheckins = Number(r.checkins);
        return {
          roomId: r.room_id,
          roomName: r.room_name,
          capacity: r.capacity,
          sessions: roomSessions,
          checkins: roomCheckins,
          averageOccupancy:
            roomSessions === 0 || r.capacity === 0
              ? 0
              : Math.round((roomCheckins / roomSessions / r.capacity) * 1000) / 10,
        };
      }),
    };
  }

  async childHistory(childId: string, limit = 50): Promise<KidsCheckin[]> {
    const rows = await this.prisma.kidsCheckin.findMany({
      where: { childId },
      include: checkinInclude,
      orderBy: { checkinAt: 'desc' },
      take: limit,
    });
    return rows.map((r) => this.mapCheckin(r));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  private async presentCountBySession(ids: string[]): Promise<Map<string, number>> {
    if (ids.length === 0) return new Map();
    const rows = await this.prisma.kidsCheckin.groupBy({
      by: ['sessionId'],
      where: { sessionId: { in: ids }, status: 'CHECKED_IN' },
      _count: { _all: true },
    });
    return new Map(rows.map((r) => [r.sessionId, r._count._all]));
  }

  private async openAlertCountBySession(ids: string[]): Promise<Map<string, number>> {
    if (ids.length === 0) return new Map();
    const rows = await this.prisma.kidsAlert.groupBy({
      by: ['sessionId'],
      where: { sessionId: { in: ids }, status: { not: 'RESOLVED' } },
      _count: { _all: true },
    });
    return new Map(rows.map((r) => [r.sessionId, r._count._all]));
  }

  private mapRoom(row: RoomRow, openSession: KidsSessionSummary | null): KidsRoom {
    return {
      id: row.id,
      name: row.name,
      description: row.description,
      capacity: row.capacity,
      minAgeMonths: row.minAgeMonths,
      maxAgeMonths: row.maxAgeMonths,
      color: row.color,
      isActive: row.isActive,
      teachers: row.teachers.map((t) => ({
        userId: t.userId,
        name: t.user.name,
        role: t.role,
      })),
      openSession,
      createdAt: row.createdAt,
    };
  }

  private mapSession(
    row: SessionRow,
    presentCount: number,
    openAlerts: number,
  ): KidsSessionSummary {
    return {
      id: row.id,
      roomId: row.roomId,
      roomName: row.room.name,
      serviceDate: row.serviceDate,
      serviceName: row.serviceName,
      status: row.status,
      lesson: row.lesson,
      capacity: row.capacityOverride ?? row.room.capacity,
      presentCount,
      totalCheckins: row._count.checkins,
      openAlerts,
      openedAt: row.openedAt,
      closedAt: row.closedAt,
    };
  }

  private mapHealth(row: {
    allergies: string | null;
    medications: string | null;
    disabilities: string | null;
    medicalNotes: string | null;
  }): ChildHealth {
    return {
      allergies: row.allergies,
      medications: row.medications,
      disabilities: row.disabilities,
      medicalNotes: row.medicalNotes,
    };
  }

  private mapChild(row: ChildRow): KidsChild {
    return {
      id: row.id,
      name: row.name,
      birthDate: row.birthDate,
      gender: row.gender,
      photoKey: row.photoKey,
      authorizedPickup: row.authorizedPickup,
      isActive: row.isActive,
      userId: row.userId,
      cellMemberId: row.cellMemberId,
      visitorId: row.visitorId,
      health: this.mapHealth(row),
      guardians: row.guardians.map((g) => ({
        id: g.id,
        childId: g.childId,
        userId: g.userId,
        name: g.name,
        phone: g.phone,
        hasWhatsapp: g.hasWhatsapp,
        relation: g.relation,
        isPrimary: g.isPrimary,
        canPickup: g.canPickup,
      })),
      createdAt: row.createdAt,
    };
  }

  private mapCheckin(row: CheckinRow): KidsCheckin {
    return {
      id: row.id,
      sessionId: row.sessionId,
      childId: row.childId,
      childName: row.child.name,
      childBirthDate: row.child.birthDate,
      status: row.status,
      badgeCode: row.badgeCode,
      checkinAt: row.checkinAt,
      checkinMethod: row.checkinMethod,
      checkinGuardianName: row.checkinGuardian?.name ?? null,
      pickupCodeLast2: row.pickupCodeLast2,
      hasPickupCode: row.pickupCodeHash !== null,
      checkoutAt: row.checkoutAt,
      checkoutMethod: row.checkoutMethod,
      checkoutGuardianName: row.checkoutGuardianName ?? row.checkoutGuardian?.name ?? null,
      health: this.mapHealth(row.child),
      openAlerts: row.alerts.length,
    };
  }

  private mapNote(row: NoteRow): KidsNote {
    return {
      id: row.id,
      sessionId: row.sessionId,
      kind: row.kind,
      childId: row.childId,
      childName: row.child?.name ?? null,
      checkinId: row.checkinId,
      body: row.body,
      visibleToGuardian: row.visibleToGuardian,
      authorId: row.authorId,
      authorName: row.author.name,
      createdAt: row.createdAt,
    };
  }

  private mapAlert(row: AlertRow): KidsAlert {
    return {
      id: row.id,
      sessionId: row.sessionId,
      roomName: row.session.room.name,
      sessionStatus: row.session.status,
      serviceDate: row.session.serviceDate,
      childId: row.childId,
      childName: row.child.name,
      checkinId: row.checkinId,
      level: row.level,
      status: row.status,
      message: row.message,
      createdById: row.createdById,
      createdByName: row.createdBy.name,
      createdAt: row.createdAt,
      acknowledgedAt: row.acknowledgedAt,
      resolvedAt: row.resolvedAt,
      deliveries: row.deliveries.map((d) => ({
        id: d.id,
        channel: d.channel,
        status: d.status,
        guardianId: d.guardianId,
        guardianName: d.guardian?.name ?? null,
        error: d.error,
        queuedAt: d.queuedAt,
        sentAt: d.sentAt,
      })),
      guardianPhones: row.child.guardians.map((g) => g.phone),
    };
  }
}
