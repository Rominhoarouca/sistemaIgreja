import type { PrismaClient } from '@prisma/client';
import type {
  CellAttendee,
  IAttendanceRepository,
  MeetingDetails,
  MeetingSummary,
} from '@domain/repositories/IAttendanceRepository';
import type { Attendance, RegisterAttendanceData } from '@domain/entities/Attendance';
import { getEffectiveChurchId } from '@shared/context/tenant-context';

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
    const churchId = getEffectiveChurchId() ?? null;
    const result = await this.prisma.$queryRaw<[{ rate: number }]>`
      SELECT
        COALESCE(
          AVG(CASE WHEN is_present THEN 1.0 ELSE 0.0 END) * 100,
          0
        ) AS rate
      FROM attendances
      WHERE (${churchId}::text IS NULL OR church_id = ${churchId})
    `;
    return Number(result[0]?.rate ?? 0);
  }

  async getAttendanceRateByCell(): Promise<
    Array<{
      cellId: string;
      cellName: string;
      leaderName: string;
      meetings: number;
      total: number;
      present: number;
      rate: number;
    }>
  > {
    const churchId = getEffectiveChurchId() ?? null;
    const rows = await this.prisma.$queryRaw<
      Array<{
        cell_id: string;
        cell_name: string;
        leader_name: string | null;
        meetings: bigint;
        total: bigint;
        present: bigint;
      }>
    >`
      SELECT
        c.id                                    AS cell_id,
        c.name                                  AS cell_name,
        u.name                                  AS leader_name,
        COUNT(DISTINCT a.meeting_date)          AS meetings,
        COUNT(a.id)                             AS total,
        COUNT(a.id) FILTER (WHERE a.is_present) AS present
      FROM cells c
      LEFT JOIN users u ON u.id = c.leader_id
      LEFT JOIN attendances a ON a.cell_id = c.id
      WHERE (${churchId}::text IS NULL OR c.church_id = ${churchId})
      GROUP BY c.id, c.name, u.name
      ORDER BY c.name
    `;
    return rows.map((r) => {
      const total = Number(r.total);
      const present = Number(r.present);
      return {
        cellId: r.cell_id,
        cellName: r.cell_name,
        leaderName: r.leader_name ?? '',
        meetings: Number(r.meetings),
        total,
        present,
        rate: total === 0 ? 0 : Math.round((present / total) * 1000) / 10,
      };
    });
  }

  async findMeetingsByCellId(cellId: string): Promise<MeetingSummary[]> {
    // Merge standalone meetings (cell_meetings) with attendance-derived meetings
    // so that an empty meeting created by the leader also appears in the list.
    // Lição/ministrante só existem no primeiro caso — presenças importadas sem
    // um cell_meetings correspondente vêm com esses campos nulos.
    const churchId = getEffectiveChurchId() ?? null;
    const rows = await this.prisma.$queryRaw<
      Array<{
        meeting_date: Date;
        lesson: string | null;
        ministrante: string | null;
        total: bigint;
        present: bigint;
        members_present: bigint;
        visitors_present: bigint;
      }>
    >`
      SELECT
        m.meeting_date,
        m.lesson,
        m.ministrante,
        COUNT(a.id)::bigint                                      AS total,
        COALESCE(SUM(CASE WHEN a.is_present THEN 1 ELSE 0 END), 0)::bigint AS present,
        COALESCE(SUM(CASE WHEN a.is_present AND a.member_id IS NOT NULL THEN 1 ELSE 0 END), 0)::bigint  AS members_present,
        COALESCE(SUM(CASE WHEN a.is_present AND a.visitor_id IS NOT NULL THEN 1 ELSE 0 END), 0)::bigint AS visitors_present
      FROM cell_meetings m
      LEFT JOIN attendances a
        ON a.cell_id = m.cell_id
       AND a.meeting_date = m.meeting_date
      WHERE m.cell_id = ${cellId}
        AND (${churchId}::text IS NULL OR m.church_id = ${churchId})
      GROUP BY m.meeting_date, m.lesson, m.ministrante

      UNION ALL

      SELECT
        a2.meeting_date,
        NULL::text                                                   AS lesson,
        NULL::text                                                   AS ministrante,
        COUNT(a2.id)::bigint                                         AS total,
        SUM(CASE WHEN a2.is_present THEN 1 ELSE 0 END)::bigint       AS present,
        SUM(CASE WHEN a2.is_present AND a2.member_id IS NOT NULL THEN 1 ELSE 0 END)::bigint  AS members_present,
        SUM(CASE WHEN a2.is_present AND a2.visitor_id IS NOT NULL THEN 1 ELSE 0 END)::bigint AS visitors_present
      FROM attendances a2
      WHERE a2.cell_id = ${cellId}
        AND (${churchId}::text IS NULL OR a2.church_id = ${churchId})
        AND NOT EXISTS (
          SELECT 1 FROM cell_meetings cm
          WHERE cm.cell_id = a2.cell_id AND cm.meeting_date = a2.meeting_date
        )
      GROUP BY a2.meeting_date
      ORDER BY meeting_date DESC
      LIMIT 20
    `;
    return rows.map((r) => {
      const total = Number(r.total);
      return {
        meetingDate: r.meeting_date,
        total,
        present: Number(r.present),
        membersPresent: Number(r.members_present),
        visitorsPresent: Number(r.visitors_present),
        lesson: r.lesson,
        ministrante: r.ministrante,
        isRecorded: total > 0,
      };
    });
  }

  /**
   * Membros e visitantes da célula em uma lista só, cada um com a própria taxa
   * de frequência. O denominador é o número de encontros em que a presença
   * daquela pessoa foi registrada — quem entrou depois não é penalizado pelos
   * encontros anteriores.
   */
  async findAttendeesByCellId(cellId: string): Promise<CellAttendee[]> {
    const churchId = getEffectiveChurchId() ?? null;
    const rows = await this.prisma.$queryRaw<
      Array<{
        kind: string;
        id: string;
        name: string;
        phone: string | null;
        email: string | null;
        birth_date: Date | null;
        gender: string | null;
        marital_status: string | null;
        address: string | null;
        neighborhood: string | null;
        city: string | null;
        status: string | null;
        is_baptized: boolean | null;
        meetings: bigint;
        present: bigint;
        created_at: Date;
      }>
    >`
      WITH person_stats AS (
        SELECT
          member_id,
          visitor_id,
          COUNT(*)::bigint                                      AS meetings,
          SUM(CASE WHEN is_present THEN 1 ELSE 0 END)::bigint   AS present
        FROM attendances
        WHERE cell_id = ${cellId}
          AND (${churchId}::text IS NULL OR church_id = ${churchId})
        GROUP BY member_id, visitor_id
      )
      SELECT
        'MEMBER'                    AS kind,
        cm.id,
        cm.name,
        cm.phone,
        cm.email,
        cm.birth_date,
        cm.gender::text             AS gender,
        cm.marital_status,
        cm.address,
        b.name                      AS neighborhood,
        ci.name                     AS city,
        NULL::text                  AS status,
        NULL::boolean               AS is_baptized,
        COALESCE(s.meetings, 0)     AS meetings,
        COALESCE(s.present, 0)      AS present,
        cm.created_at
      FROM cell_members cm
      LEFT JOIN person_stats s ON s.member_id = cm.id
      LEFT JOIN bairros b       ON b.id = cm.bairro_id
      LEFT JOIN cidades ci      ON ci.id = b.cidade_id
      WHERE cm.cell_id = ${cellId}
        AND (${churchId}::text IS NULL OR cm.church_id = ${churchId})

      UNION ALL

      SELECT
        'VISITOR'                   AS kind,
        v.id,
        v.name,
        v.phone,
        v.email,
        v.birth_date,
        v.gender::text              AS gender,
        v.marital_status,
        v.address,
        b2.name                     AS neighborhood,
        ci2.name                    AS city,
        v.status::text              AS status,
        v.is_baptized,
        COALESCE(s2.meetings, 0)    AS meetings,
        COALESCE(s2.present, 0)     AS present,
        v.created_at
      FROM visitors v
      LEFT JOIN person_stats s2 ON s2.visitor_id = v.id
      LEFT JOIN bairros b2       ON b2.id = v.bairro_id
      LEFT JOIN cidades ci2      ON ci2.id = b2.cidade_id
      WHERE v.cell_id = ${cellId}
        AND (${churchId}::text IS NULL OR v.church_id = ${churchId})
        -- Visitante já convertido em membro apareceria duas vezes.
        AND NOT EXISTS (
          SELECT 1 FROM cell_members cmx WHERE cmx.source_visitor_id = v.id
        )
      ORDER BY name
    `;

    return rows.map((r) => {
      const meetingsCount = Number(r.meetings);
      const presentCount = Number(r.present);
      return {
        id: r.id,
        kind: r.kind as CellAttendee['kind'],
        name: r.name,
        phone: r.phone,
        email: r.email,
        birthDate: r.birth_date,
        gender: r.gender as CellAttendee['gender'],
        maritalStatus: r.marital_status,
        address: r.address,
        neighborhood: r.neighborhood,
        city: r.city,
        status: r.status,
        isBaptized: r.is_baptized,
        meetingsCount,
        presentCount,
        attendanceRate:
          meetingsCount === 0
            ? 0
            : Math.round((presentCount / meetingsCount) * 1000) / 10,
        createdAt: r.created_at,
      };
    });
  }

  async createMeeting(
    cellId: string,
    meetingDate: Date,
    createdById: string,
    details?: MeetingDetails,
  ): Promise<void> {
    const writable = {
      ...(details?.lesson !== undefined ? { lesson: details.lesson } : {}),
      ...(details?.ministrante !== undefined ? { ministrante: details.ministrante } : {}),
    };
    await this.prisma.cellMeeting.upsert({
      where: { cellId_meetingDate: { cellId, meetingDate } },
      create: { cellId, meetingDate, createdById, ...writable },
      update: writable,
    });
  }

  async updateMeetingPhoto(cellId: string, meetingDate: Date, photoKey: string): Promise<void> {
    await this.prisma.cellMeeting.updateMany({
      where: { cellId, meetingDate },
      data: { photoKey },
    });
  }

  async getMeetingPhotoKey(cellId: string, meetingDate: Date): Promise<string | null> {
    // findFirst (não findUnique) porque o tenant-guard injeta `churchId` no
    // where — filtro que o where unique do findUnique não aceita.
    const meeting = await this.prisma.cellMeeting.findFirst({
      where: { cellId, meetingDate },
      select: { photoKey: true },
    });
    return meeting?.photoKey ?? null;
  }
}
