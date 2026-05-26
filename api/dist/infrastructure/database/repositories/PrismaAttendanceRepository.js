"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PrismaAttendanceRepository = void 0;
class PrismaAttendanceRepository {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    async register(data) {
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
    async findByCellAndDate(cellId, meetingDate) {
        return this.prisma.attendance.findMany({
            where: { cellId, meetingDate },
            orderBy: { createdAt: 'desc' },
        });
    }
    async findByVisitor(visitorId) {
        return this.prisma.attendance.findMany({
            where: { visitorId },
            orderBy: { meetingDate: 'desc' },
        });
    }
    async getAverageAttendanceRate() {
        const result = await this.prisma.$queryRaw `
      SELECT
        COALESCE(
          AVG(CASE WHEN is_present THEN 1.0 ELSE 0.0 END) * 100,
          0
        ) AS rate
      FROM attendances
    `;
        return Number(result[0]?.rate ?? 0);
    }
    async findMeetingsByCellId(cellId) {
        // Merge standalone meetings (cell_meetings) with attendance-derived meetings
        // so that an empty meeting created by the leader also appears in the list.
        const rows = await this.prisma.$queryRaw `
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
    async createMeeting(cellId, meetingDate, createdById) {
        await this.prisma.cellMeeting.upsert({
            where: { cellId_meetingDate: { cellId, meetingDate } },
            create: { cellId, meetingDate, createdById },
            update: {},
        });
    }
}
exports.PrismaAttendanceRepository = PrismaAttendanceRepository;
