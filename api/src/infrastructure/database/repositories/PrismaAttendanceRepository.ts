import type { PrismaClient } from '@prisma/client';
import type { IAttendanceRepository } from '@domain/repositories/IAttendanceRepository';
import type { Attendance, RegisterAttendanceData } from '@domain/entities/Attendance';

export class PrismaAttendanceRepository implements IAttendanceRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async register(data: RegisterAttendanceData): Promise<Attendance> {
    const row = await this.prisma.attendance.upsert({
      where: {
        visitorId_cellId_meetingDate: {
          visitorId: data.visitorId,
          cellId: data.cellId,
          meetingDate: data.meetingDate,
        },
      },
      create: {
        visitorId: data.visitorId,
        cellId: data.cellId,
        meetingDate: data.meetingDate,
        isPresent: data.isPresent,
        notes: data.notes ?? null,
      },
      update: {
        isPresent: data.isPresent,
        notes: data.notes ?? null,
      },
    });
    return row;
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
}
