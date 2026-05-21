export interface Attendance {
  readonly id: string;
  readonly visitorId: string;
  readonly cellId: string;
  readonly meetingDate: Date;
  readonly isPresent: boolean;
  readonly notes: string | null;
  readonly createdAt: Date;
}

export interface RegisterAttendanceData {
  readonly visitorId: string;
  readonly cellId: string;
  readonly meetingDate: Date;
  readonly isPresent: boolean;
  readonly notes?: string | undefined;
}
