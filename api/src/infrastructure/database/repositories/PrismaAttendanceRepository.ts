import type { PrismaClient } from '@prisma/client';
import type { IAttendanceRepository } from '@domain/repositories/IAttendanceRepository';
import type { Attendance, RegisterAttendanceData } from '@domain/entities/Attendance';

export class PrismaAttendanceRepository implements IAttendanceRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async register(data: RegisterAttendanceData): Promise<Attendance> {
    if (data.visitorId) {
      const existing = await this.prisma.attendance.findFirst({
        where: { visitorId: data.visitorId, cellId: data.cellId, meetingDate: data.meetingDate },
      });
      if (existing) {
        return this.prisma.attendance.update({
          where: { id: existing.id },
          data: { isPresent: data.isPresent, notes: data.notes ?? null },
        });
      }
      return this.prisma.attendance.create({
        data: {
          visitorId: data.visitorId,
          cellId: data.cellId,
          meetingDate: data.meetingDate,
          isPresent: data.isPresent,
          notes: data.notes ?? null,
        },
      });
    } else {
      // memberId path — data.memberId is guaranteed non-undefined here
      const memberId = data.memberId as string;
      const existing = await this.prisma.attendance.findFirst({
        where: { memberId, cellId: data.cellId, meetingDate: data.meetingDate },
      });
      if (existing) {
        return this.prisma.attendance.update({
          where: { id: existing.id },
          data: { isPresent: data.isPresent, notes: data.notes ?? null },
        });
      }
      return this.prisma.attendance.create({
        data: {
          memberId,
          cellId: data.cellId,
          meetingDate: data.meetingDate,
          isPresent: data.isPresent,
          notes: data.notes ?? null,
        },
      });
    }
  }

  async findByCellAndDate(cellId: string, meetingDate: Date): Promise<Attendance[]> {
    return this.prisma.attendance.findMany({
      where: { cellId, meetingDate },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findByVisitor(visitorId: string): Promise<Attendance[]> {
    return this.prisma.attendance.findMany({
      where: { visitorId },
      orderBy: { meetingDate: 'desc' },
    });
  }

  async getAverageAttendanceRate(): Promise<number> {
    const result = await this.prisma.$queryRaw<[{ rate: number }]>`
      SELECT
        COALESCE(
          AVG(CASE WHEN is_present THEN 1.0 ELSE 0.0 END) * 100,
          0
        ) AS rate
      FROM attendances
    `;
    return Number(result[0]?.rate ?? 0);
  }

  async findMeetingsByCellId(
    cellId: string,
  ): Promise<Array<{ meetingDate: Date; total: number; present: number }>> {
    // Merge standalone meetings (cell_meetings) with attendance-derived meetings
    // so that an empty meeting created by the leader also appears in the list.
    const rows = await this.prisma.$queryRaw<
      Array<{ meeting_date: Date; total: bigint; present: bigint }>
    >`
      SELECT
        m.meeting_date,
        COUNT(a.id)::bigint                                      AS total,
        COALESCE(SUM(CASE WHEN a.is_present THEN 1 ELSE 0 END), 0)::bigint AS present
      FROM cell_meetings m
      LEFT JOIN attendances a
        ON a.cell_id = m.cell_id
       AND a.meeting_date = m.meeting_date
      WHERE m.cell_id = ${cellId}
      GROUP BY m.meeting_date
      UNION
      SELECT
        a2.meeting_date,
        COUNT(a2.id)::bigint                                         AS total,
        SUM(CASE WHEN a2.is_present THEN 1 ELSE 0 END)::bigint       AS present
      FROM attendances a2
      WHERE a2.cell_id = ${cellId}
        AND a2.meeting_date NOT IN (
          SELECT meeting_date FROM cell_meetings WHERE cell_id = ${cellId}
        )
      GROUP BY a2.meeting_date
      ORDER BY meeting_date DESC
      LIMIT 20
    `;
    return rows.map((r) => ({
      meetingDate: r.meeting_date,
      total: Number(r.total),
      present: Number(r.present),
    }));
  }

  async createMeeting(
    cellId: string,
    meetingDate: Date,
    createdById: string,
  ): Promise<void> {
    await this.prisma.cellMeeting.upsert({
      where: { cellId_meetingDate: { cellId, meetingDate } },
      create: { cellId, meetingDate, createdById },
      update: {},
    });
  }

  async updateMeetingPhoto(cellId: string, meetingDate: Date, photoKey: string): Promise<void> {
    await this.prisma.cellMeeting.updateMany({
      where: { cellId, meetingDate },
      data: { photoKey },
    });
  }

  async getMeetingPhotoKey(cellId: string, meetingDate: Date): Promise<string | null> {
    const meeting = await this.prisma.cellMeeting.findUnique({
      where: { cellId_meetingDate: { cellId, meetingDate } },
      select: { photoKey: true },
    });
    return meeting?.photoKey ?? null;
  }
}
