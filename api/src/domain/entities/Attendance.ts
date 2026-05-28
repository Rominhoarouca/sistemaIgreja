export interface Attendance {
  readonly id: string;
  readonly visitorId: string | null;
  readonly memberId: string | null;
  readonly cellId: string;
  readonly meetingDate: Date;
  readonly isPresent: boolean;
  readonly notes: string | null;
  readonly createdAt: Date;
}

export interface RegisterAttendanceData {
  readonly visitorId?: string | undefined;
  readonly memberId?: string | undefined;
  readonly cellId: string;
  readonly meetingDate: Date;
  readonly isPresent: boolean;
  readonly notes?: string | undefined;
}
