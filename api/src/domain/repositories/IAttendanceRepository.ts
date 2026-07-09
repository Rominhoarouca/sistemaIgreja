import type { Attendance, RegisterAttendanceData } from '../entities/Attendance';

export interface MeetingSummary {
  readonly meetingDate: Date;
  readonly total: number;
  readonly present: number;
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

export interface IAttendanceRepository {
  register(data: RegisterAttendanceData): Promise<Attendance>;
  findByCellAndDate(cellId: string, meetingDate: Date): Promise<Attendance[]>;
  findByVisitor(visitorId: string): Promise<Attendance[]>;
  getAverageAttendanceRate(): Promise<number>;
  getAttendanceRateByCell(): Promise<CellAttendanceSummary[]>;
  findMeetingsByCellId(cellId: string): Promise<MeetingSummary[]>;
  createMeeting(cellId: string, meetingDate: Date, createdById: string): Promise<void>;
  updateMeetingPhoto(cellId: string, meetingDate: Date, photoKey: string): Promise<void>;
  getMeetingPhotoKey(cellId: string, meetingDate: Date): Promise<string | null>;
}
