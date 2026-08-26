import type {
  CreateAlertData,
  CreateKidsRoomData,
  CreateNoteData,
  GuardianInput,
  KidsAlert,
  KidsAlertLevel,
  KidsChannel,
  KidsCheckMethod,
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
} from '../entities/Kids';

/** Uma criança entrando na sala. A senha chega já em hash. */
export interface CheckinEntry {
  readonly sessionId: string;
  readonly childId: string;
  readonly badgeCode: string;
  readonly checkinById: string;
  readonly checkinMethod: KidsCheckMethod;
  readonly checkinGuardianId: string | null;
  readonly pickupCodeHash: string | null;
  readonly pickupCodeLast2: string | null;
}

export interface CheckoutRecord {
  readonly checkinId: string;
  readonly checkoutById: string;
  readonly checkoutMethod: KidsCheckMethod;
  readonly checkoutGuardianId: string | null;
  readonly checkoutGuardianName: string | null;
  readonly checkoutReason: string | null;
}

export interface PickupState {
  readonly checkinId: string;
  readonly status: string;
  readonly pickupCodeHash: string | null;
  readonly attempts: number;
  readonly lockedUntil: Date | null;
}

/** Entrega planejada de um alerta, antes de ir para a fila. */
export interface PlannedDelivery {
  readonly channel: KidsChannel;
  readonly guardianId: string | null;
  readonly userId: string | null;
}

export interface IKidsRepository {
  // ── Salas ─────────────────────────────────────────────────────────────────
  listRooms(): Promise<KidsRoom[]>;
  findRoomById(id: string): Promise<KidsRoom | null>;
  countActiveRooms(): Promise<number>;
  createRoom(data: CreateKidsRoomData): Promise<KidsRoom>;
  updateRoom(id: string, data: UpdateKidsRoomData): Promise<KidsRoom>;
  setRoomTeachers(
    roomId: string,
    teachers: { userId: string; role: KidsTeacherRole }[],
  ): Promise<KidsRoom>;
  /** `true` quando o usuário é professor da sala. ADMIN não passa por aqui. */
  isTeacherOfRoom(roomId: string, userId: string): Promise<boolean>;
  isTeacherOfSession(sessionId: string, userId: string): Promise<boolean>;

  // ── Sessões ───────────────────────────────────────────────────────────────
  openSession(data: OpenSessionData): Promise<KidsSessionSummary>;
  findSessionById(id: string): Promise<KidsSessionSummary | null>;
  findOpenSessionByRoom(roomId: string): Promise<KidsSessionSummary | null>;
  listSessions(filter: {
    roomId?: string;
    from?: Date;
    to?: Date;
    limit?: number;
  }): Promise<KidsSessionSummary[]>;
  updateSession(
    id: string,
    data: { lesson?: string | null; capacityOverride?: number | null },
  ): Promise<KidsSessionSummary>;
  closeSession(id: string, closedById: string): Promise<KidsSessionSummary>;
  countCheckedInBySession(sessionId: string): Promise<number>;

  // ── Crianças ──────────────────────────────────────────────────────────────
  searchChildren(query: string, limit?: number): Promise<KidsChild[]>;
  findChildById(id: string): Promise<KidsChild | null>;
  findChildrenByGuardianUser(userId: string): Promise<KidsChild[]>;
  createChildWithGuardians(data: QuickRegisterChildData): Promise<KidsChild>;
  updateChild(
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
  ): Promise<KidsChild>;
  addGuardian(childId: string, guardian: GuardianInput): Promise<KidsChild>;
  /**
   * Religa contas de responsável criadas depois do cadastro da criança no
   * balcão: casa por telefone (normalizado, ignora DDI/formatação) contra
   * guardians ainda sem `userId`. Devolve quantos vínculos foram feitos.
   */
  linkGuardiansByPhone(phone: string, userId: string): Promise<number>;

  // ── Check-in / check-out ──────────────────────────────────────────────────
  listCheckinsBySession(sessionId: string): Promise<KidsCheckin[]>;
  findCheckinById(id: string): Promise<KidsCheckin | null>;
  /** Sessão aberta em que a criança já está — impede entrada duplicada. */
  findOpenCheckinByChild(childId: string): Promise<KidsCheckin | null>;
  nextBadgeNumber(sessionId: string): Promise<number>;
  createCheckins(entries: CheckinEntry[]): Promise<KidsCheckin[]>;
  registerCheckout(data: CheckoutRecord): Promise<KidsCheckin>;
  /** Hash e trava da senha de retirada — só o use case de check-out consome. */
  getPickupState(checkinId: string): Promise<PickupState | null>;
  registerPickupFailure(checkinId: string, lockUntil: Date | null): Promise<number>;
  replacePickupCode(checkinId: string, hash: string, last2: string): Promise<void>;

  // ── Anotações ─────────────────────────────────────────────────────────────
  createNote(data: CreateNoteData): Promise<KidsNote>;
  updateNote(
    id: string,
    data: { body?: string | undefined; visibleToGuardian?: boolean | undefined },
  ): Promise<KidsNote>;
  listNotesBySession(sessionId: string): Promise<KidsNote[]>;
  listNotesByChild(childId: string, onlyVisibleToGuardian: boolean): Promise<KidsNote[]>;
  findNoteById(id: string): Promise<KidsNote | null>;
  deleteNote(id: string): Promise<void>;

  // ── Alertas ───────────────────────────────────────────────────────────────
  createAlertWithDeliveries(
    data: CreateAlertData & { sessionId: string; childId: string },
    deliveries: PlannedDelivery[],
  ): Promise<KidsAlert>;
  findAlertById(id: string): Promise<KidsAlert | null>;
  listAlerts(filter: {
    status?: 'OPEN' | 'ACKNOWLEDGED' | 'RESOLVED';
    sessionId?: string;
    level?: KidsAlertLevel;
    limit?: number;
  }): Promise<KidsAlert[]>;
  listAlertsForGuardianUser(userId: string, limit?: number): Promise<KidsAlert[]>;
  acknowledgeAlert(id: string, guardianId: string | null): Promise<KidsAlert>;
  resolveAlert(id: string, resolvedById: string): Promise<KidsAlert>;
  markDeliverySent(deliveryId: string, providerMessageId?: string | null): Promise<void>;
  markDeliveryFailed(deliveryId: string, error: string): Promise<void>;

  // ── Relatórios ────────────────────────────────────────────────────────────
  overview(from: Date, to: Date): Promise<KidsOverviewReport>;
  childHistory(childId: string, limit?: number): Promise<KidsCheckin[]>;
}
