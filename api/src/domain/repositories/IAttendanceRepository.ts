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
  readonly createdAt: Date;
}

export interface IAttendanceRepository {
  register(data: RegisterAttendanceData): Promise<Attendance>;
  findByCellAndDate(cellId: string, meetingDate: Date): Promise<Attendance[]>;
  findByVisitor(visitorId: string): Promise<Attendance[]>;
  getAverageAttendanceRate(): Promise<number>;
  getAttendanceRateByCell(): Promise<CellAttendanceSummary[]>;
  findMeetingsByCellId(cellId: string): Promise<MeetingSummary[]>;
  findAttendeesByCellId(cellId: string): Promise<CellAttendee[]>;
  createMeeting(
    cellId: string,
    meetingDate: Date,
    createdById: string,
    details?: MeetingDetails,
  ): Promise<void>;
  updateMeetingPhoto(cellId: string, meetingDate: Date, photoKey: string): Promise<void>;
  getMeetingPhotoKey(cellId: string, meetingDate: Date): Promise<string | null>;
}
