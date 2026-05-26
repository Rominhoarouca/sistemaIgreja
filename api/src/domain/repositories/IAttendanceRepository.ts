import type { Attendance, RegisterAttendanceData } from '../entities/Attendance';

export interface MeetingSummary {
  readonly meetingDate: Date;
  readonly total: number;
  readonly present: number;
}

export interface IAttendanceRepository {
  register(data: RegisterAttendanceData): Promise<Attendance>;
  findByCellAndDate(cellId: string, meetingDate: Date): Promise<Attendance[]>;
  findByVisitor(visitorId: string): Promise<Attendance[]>;
  getAverageAttendanceRate(): Promise<number>;
  findMeetingsByCellId(cellId: string): Promise<MeetingSummary[]>;
  createMeeting(cellId: string, meetingDate: Date, createdById: string): Promise<void>;
}
