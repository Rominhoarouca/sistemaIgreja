import type { Gender } from './Gender';

export type KidsSessionStatus = 'OPEN' | 'CLOSED';
export type KidsCheckinStatus = 'CHECKED_IN' | 'CHECKED_OUT' | 'NO_SHOW';
export type KidsCheckMethod = 'QR' | 'CODE' | 'MANUAL';
export type KidsNoteKind = 'INDIVIDUAL' | 'CLASS';
export type KidsAlertLevel = 'INFO' | 'URGENT' | 'EMERGENCY';
export type KidsAlertStatus = 'OPEN' | 'ACKNOWLEDGED' | 'RESOLVED';
export type KidsChannel = 'PUSH' | 'WHATSAPP' | 'SMS' | 'CALL' | 'CRITICAL_PUSH';
export type KidsDeliveryStatus = 'QUEUED' | 'SENT' | 'DELIVERED' | 'READ' | 'FAILED';
export type KidsTeacherRole = 'TITULAR' | 'AUXILIAR';
export type GuardianRelation = 'PAI' | 'MAE' | 'AVO' | 'TIO' | 'RESPONSAVEL_LEGAL' | 'OUTRO';

export interface KidsRoomTeacher {
  readonly userId: string;
  readonly name: string;
  readonly role: KidsTeacherRole;
}

export interface KidsRoom {
  readonly id: string;
  readonly name: string;
  readonly description: string | null;
  readonly capacity: number;
  readonly minAgeMonths: number | null;
  readonly maxAgeMonths: number | null;
  readonly color: string;
  readonly isActive: boolean;
  readonly teachers: KidsRoomTeacher[];
  /** Sessão aberta agora, se houver — é o que a tela do professor abre. */
  readonly openSession: KidsSessionSummary | null;
  readonly createdAt: Date;
}

export interface KidsSessionSummary {
  readonly id: string;
  readonly roomId: string;
  readonly roomName: string;
  readonly serviceDate: Date;
  readonly serviceName: string;
  readonly status: KidsSessionStatus;
  readonly lesson: string | null;
  readonly capacity: number;
  /** Crianças com `CHECKED_IN` neste instante. */
  readonly presentCount: number;
  /** Total de check-ins da sessão, incluindo quem já saiu. */
  readonly totalCheckins: number;
  readonly openAlerts: number;
  readonly openedAt: Date;
  readonly closedAt: Date | null;
}

/** Dado sensível da criança (LGPD art. 5º, II). Só sai para quem tem a sala. */
export interface ChildHealth {
  readonly allergies: string | null;
  readonly medications: string | null;
  readonly disabilities: string | null;
  readonly medicalNotes: string | null;
}

export interface KidsGuardian {
  readonly id: string;
  readonly childId: string;
  readonly userId: string | null;
  readonly name: string;
  readonly phone: string;
  readonly hasWhatsapp: boolean;
  readonly relation: GuardianRelation;
  readonly isPrimary: boolean;
  readonly canPickup: boolean;
}

export interface KidsChild {
  readonly id: string;
  readonly name: string;
  readonly birthDate: Date | null;
  readonly gender: Gender | null;
  readonly photoKey: string | null;
  readonly authorizedPickup: string | null;
  readonly isActive: boolean;
  readonly userId: string | null;
  readonly cellMemberId: string | null;
  readonly visitorId: string | null;
  readonly health: ChildHealth;
  readonly guardians: KidsGuardian[];
  readonly createdAt: Date;
}

export interface KidsCheckin {
  readonly id: string;
  readonly sessionId: string;
  readonly childId: string;
  readonly childName: string;
  readonly childBirthDate: Date | null;
  readonly status: KidsCheckinStatus;
  readonly badgeCode: string;
  readonly checkinAt: Date;
  readonly checkinMethod: KidsCheckMethod;
  readonly checkinGuardianName: string | null;
  /** Últimos 2 dígitos da senha — conferência visual, nunca a senha inteira. */
  readonly pickupCodeLast2: string | null;
  readonly hasPickupCode: boolean;
  readonly checkoutAt: Date | null;
  readonly checkoutMethod: KidsCheckMethod | null;
  readonly checkoutGuardianName: string | null;
  readonly health: ChildHealth;
  readonly openAlerts: number;
}

export interface KidsNote {
  readonly id: string;
  readonly sessionId: string;
  readonly kind: KidsNoteKind;
  readonly childId: string | null;
  readonly childName: string | null;
  readonly checkinId: string | null;
  readonly body: string;
  readonly visibleToGuardian: boolean;
  readonly authorId: string;
  readonly authorName: string;
  readonly createdAt: Date;
}

export interface KidsAlertDelivery {
  readonly id: string;
  readonly channel: KidsChannel;
  readonly status: KidsDeliveryStatus;
  readonly guardianId: string | null;
  readonly guardianName: string | null;
  readonly error: string | null;
  readonly queuedAt: Date;
  readonly sentAt: Date | null;
}

export interface KidsAlert {
  readonly id: string;
  readonly sessionId: string;
  readonly roomName: string;
  readonly childId: string;
  readonly childName: string;
  readonly checkinId: string | null;
  readonly level: KidsAlertLevel;
  readonly status: KidsAlertStatus;
  readonly message: string;
  readonly createdById: string;
  readonly createdByName: string;
  readonly createdAt: Date;
  readonly acknowledgedAt: Date | null;
  readonly resolvedAt: Date | null;
  readonly deliveries: KidsAlertDelivery[];
  /** Telefones para a ligação do nível 3, na ordem: primário primeiro. */
  readonly guardianPhones: string[];
}

// ── Dados de entrada ────────────────────────────────────────────────────────

export interface CreateKidsRoomData {
  readonly name: string;
  readonly description?: string | null;
  readonly capacity: number;
  readonly minAgeMonths?: number | null;
  readonly maxAgeMonths?: number | null;
  readonly color?: string;
  readonly teacherIds?: { userId: string; role: KidsTeacherRole }[];
}

export interface UpdateKidsRoomData {
  readonly name?: string;
  readonly description?: string | null;
  readonly capacity?: number;
  readonly minAgeMonths?: number | null;
  readonly maxAgeMonths?: number | null;
  readonly color?: string;
  readonly isActive?: boolean;
}

export interface OpenSessionData {
  readonly roomId: string;
  readonly serviceDate: Date;
  readonly serviceName: string;
  readonly lesson?: string | null;
  readonly capacityOverride?: number | null;
  readonly openedById: string;
}

export interface GuardianInput {
  readonly name: string;
  readonly phone: string;
  readonly hasWhatsapp?: boolean | undefined;
  readonly relation?: GuardianRelation | undefined;
  readonly isPrimary?: boolean | undefined;
  readonly canPickup?: boolean | undefined;
  readonly userId?: string | null | undefined;
}

export interface QuickRegisterChildData {
  readonly name: string;
  readonly birthDate?: Date | null;
  readonly gender?: Gender | null;
  readonly allergies?: string | null;
  readonly medications?: string | null;
  readonly disabilities?: string | null;
  readonly medicalNotes?: string | null;
  readonly authorizedPickup?: string | null;
  readonly guardians: GuardianInput[];
}

export interface CheckinRequestData {
  readonly sessionId: string;
  readonly childIds: string[];
  readonly guardianId?: string | null;
  readonly method: KidsCheckMethod;
  readonly checkinById: string;
  /** Ignora a validação de faixa etária. Só ADMIN. */
  readonly force?: boolean;
}

export interface CheckoutRequestData {
  readonly checkinId: string;
  readonly method: KidsCheckMethod;
  readonly checkoutById: string;
  readonly guardianId?: string | null;
  readonly guardianName?: string | null;
  readonly reason?: string | null;
}

export interface CreateNoteData {
  readonly sessionId: string;
  readonly kind: KidsNoteKind;
  readonly childId?: string | null;
  readonly checkinId?: string | null;
  readonly body: string;
  readonly visibleToGuardian?: boolean;
  readonly authorId: string;
}

export interface CreateAlertData {
  readonly checkinId: string;
  readonly level: KidsAlertLevel;
  readonly message: string;
  readonly createdById: string;
}

/** Resultado de um check-in: a senha só existe aqui, uma única vez. */
export interface CheckinResult {
  readonly id: string;
  readonly childId: string;
  readonly childName: string;
  readonly badgeCode: string;
  /** `null` quando o responsável usa o app (a retirada é pelo QR). */
  readonly pickupCode: string | null;
  readonly healthFlags: string[];
}

export interface KidsOverviewReport {
  readonly from: Date;
  readonly to: Date;
  readonly sessions: number;
  readonly checkins: number;
  readonly uniqueChildren: number;
  readonly averagePerSession: number;
  readonly alerts: { level: KidsAlertLevel; count: number }[];
  readonly rooms: {
    roomId: string;
    roomName: string;
    capacity: number;
    sessions: number;
    checkins: number;
    averageOccupancy: number;
  }[];
}
