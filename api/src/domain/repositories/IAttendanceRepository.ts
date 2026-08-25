import type { Attendance, RegisterAttendanceData } from '../entities/Attendance';
import type { Gender } from '../entities/Gender';

export interface MeetingSummary {
  readonly meetingDate: Date;
  readonly total: number;
  readonly present: number;
  /** Presentes que são membros de célula. */
  readonly membersPresent: number;
  /** Presentes que são visitantes. */
  readonly visitorsPresent: number;
  readonly lesson: string | null;
  readonly ministrante: string | null;
  /**
   * `true` quando há presença registrada. Um encontro criado e nunca preenchido
   * fica pendente mesmo depois da data passar.
   */
  readonly isRecorded: boolean;
}

export interface MeetingDetails {
  /** `null` limpa o campo; `undefined` deixa como está. */
  readonly lesson?: string | null | undefined;
  readonly ministrante?: string | null | undefined;
}

export interface CellAttendanceSummary {
  readonly cellId: string;
  readonly cellName: string;
  readonly leaderName: string;
  readonly meetings: number;
  readonly total: number;
  readonly present: number;
  readonly rate: number; // % 0–100
}

/**
 * Pessoa que frequenta a célula — membro ou visitante — com a frequência
 * individual dela. Alimenta a tela "Frequentadores" do líder.
 */
export interface CellAttendee {
  readonly id: string;
  readonly kind: 'MEMBER' | 'VISITOR';
  readonly name: string;
  readonly phone: string | null;
  readonly email: string | null;
  readonly birthDate: Date | null;
  readonly gender: Gender | null;
  readonly maritalStatus: string | null;
  readonly address: string | null;
  readonly neighborhood: string | null;
  readonly city: string | null;
  /** Só para visitantes: onde está no funil de acompanhamento. */
  readonly status: string | null;
  /** Só para visitantes. */
  readonly isBaptized: boolean | null;
  /** Encontros em que a presença dessa pessoa foi registrada (presente ou não). */
  readonly meetingsCount: number;
  readonly presentCount: number;
  /** presentCount / meetingsCount em %, 1 casa decimal. 0 quando sem registros. */
  readonly attendanceRate: number;
  /** Último encontro em que esteve presente. `null` se nunca veio. */
  readonly lastPresentDate: Date | null;
  /**
   * Faltas seguidas mais recentes — encontros com presença registrada depois da
   * última vez que veio. É o que identifica quem parou de frequentar; a taxa
   * sozinha demora a cair para quem tinha histórico bom.
   */
  readonly absentStreak: number;
  readonly createdAt: Date;
}

/**
 * Um encontro da célula visto pela ótica de uma pessoa: ela esteve presente,
 * faltou, ou nem chegou a ter presença registrada naquele dia.
 *
 * Alimenta o calendário de frequência individual.
 */
export interface AttendeeMeetingHistory {
  readonly meetingDate: Date;
  /** `null` quando não há registro de presença dessa pessoa no encontro. */
  readonly isPresent: boolean | null;
  readonly lesson: string | null;
  readonly ministrante: string | null;
}

export interface IAttendanceRepository {
  register(data: RegisterAttendanceData): Promise<Attendance>;
  findByCellAndDate(cellId: string, meetingDate: Date): Promise<Attendance[]>;
  findByVisitor(visitorId: string): Promise<Attendance[]>;
  getAverageAttendanceRate(): Promise<number>;
  getAttendanceRateByCell(): Promise<CellAttendanceSummary[]>;
  findMeetingsByCellId(cellId: string): Promise<MeetingSummary[]>;
  findAttendeesByCellId(cellId: string): Promise<CellAttendee[]>;
  findAttendeeHistory(
    cellId: string,
    personId: string,
    kind: 'MEMBER' | 'VISITOR',
  ): Promise<AttendeeMeetingHistory[]>;
  createMeeting(
    cellId: string,
    meetingDate: Date,
    createdById: string,
    details?: MeetingDetails,
  ): Promise<void>;
  updateMeetingPhoto(cellId: string, meetingDate: Date, photoKey: string): Promise<void>;
  getMeetingPhotoKey(cellId: string, meetingDate: Date): Promise<string | null>;
}
