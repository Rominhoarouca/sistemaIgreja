import { Prisma, type PrismaClient } from '@prisma/client';
import type {
  AlbumDay,
  AlbumPhotoRow,
  AlbumScope,
  IAlbumRepository,
} from '@domain/repositories/IAlbumRepository';
import { getEffectiveChurchId } from '@shared/context/tenant-context';

export class PrismaAlbumRepository implements IAlbumRepository {
  constructor(private readonly prisma: PrismaClient) {}

  /**
   * Filtro do recorte. Query crua não passa pelo guard do Prisma, então o
   * `church_id` entra aqui explicitamente — sem ele o álbum de uma igreja
   * mostraria fotos de outra.
   */
  private scopeSql(scope: AlbumScope): Prisma.Sql {
    const churchId = getEffectiveChurchId() ?? null;
    const tenant = Prisma.sql`(${churchId}::text IS NULL OR m.church_id = ${churchId})`;

    switch (scope.kind) {
      case 'COORDENADOR':
        return Prisma.sql`${tenant} AND coord.coordinador_id = ${scope.userId}`;
      case 'SUPERVISOR':
        return Prisma.sql`${tenant} AND sup.id = ${scope.userId}`;
      default:
        return tenant;
    }
  }

  /**
   * Cadeia célula → líder → supervisor → coordenação.
   *
   * O `COALESCE` é o ponto central: a coordenação sai do supervisor quando ele
   * existe e, quando não existe, do próprio líder. Um coordenador pode ter
   * zero supervisores e ainda assim ter líderes na rede — sem isso as fotos
   * desses líderes caíam em "Sem coordenação" e sumiam do álbum dele.
   */
  private readonly joins = Prisma.sql`
    FROM cell_meetings m
    JOIN cells c            ON c.id = m.cell_id
    LEFT JOIN users lead    ON lead.id = c.leader_id
    LEFT JOIN users sup     ON sup.id = lead.supervisor_id
    LEFT JOIN coordenacoes coord
      ON coord.id = COALESCE(sup.coordenacao_id, lead.coordenacao_id)
  `;

  async findDays(scope: AlbumScope, limit: number): Promise<AlbumDay[]> {
    const rows = await this.prisma.$queryRaw<
      Array<{ meeting_date: Date; photo_count: bigint }>
    >`
      SELECT m.meeting_date, COUNT(*)::bigint AS photo_count
      ${this.joins}
      WHERE m.photo_key IS NOT NULL
        AND ${this.scopeSql(scope)}
      GROUP BY m.meeting_date
      ORDER BY m.meeting_date DESC
      LIMIT ${limit}
    `;
    return rows.map((r) => ({
      date: r.meeting_date,
      photoCount: Number(r.photo_count),
    }));
  }

  async findPhotosByDates(scope: AlbumScope, dates: Date[]): Promise<AlbumPhotoRow[]> {
    if (dates.length === 0) return [];
    const rows = await this.prisma.$queryRaw<
      Array<{
        meeting_date: Date;
        photo_key: string;
        lesson: string | null;
        cell_id: string;
        cell_name: string;
        leader_id: string | null;
        leader_name: string | null;
        supervisor_id: string | null;
        supervisor_name: string | null;
        coordenacao_id: string | null;
        coordenacao_name: string | null;
        coordenacao_color: string | null;
      }>
    >`
      SELECT
        m.meeting_date,
        m.photo_key,
        m.lesson,
        c.id            AS cell_id,
        c.name          AS cell_name,
        lead.id         AS leader_id,
        lead.name       AS leader_name,
        sup.id          AS supervisor_id,
        sup.name        AS supervisor_name,
        coord.id        AS coordenacao_id,
        coord.name      AS coordenacao_name,
        coord.color     AS coordenacao_color
      ${this.joins}
      WHERE m.photo_key IS NOT NULL
        AND m.meeting_date IN (${Prisma.join(dates)})
        AND ${this.scopeSql(scope)}
      ORDER BY m.meeting_date DESC, coord.name NULLS LAST, sup.name NULLS LAST, c.name
    `;

    return rows.map((r) => ({
      meetingDate: r.meeting_date,
      photoKey: r.photo_key,
      lesson: r.lesson,
      cellId: r.cell_id,
      cellName: r.cell_name,
      leaderId: r.leader_id,
      leaderName: r.leader_name,
      supervisorId: r.supervisor_id,
      supervisorName: r.supervisor_name,
      coordenacaoId: r.coordenacao_id,
      coordenacaoName: r.coordenacao_name,
      coordenacaoColor: r.coordenacao_color,
    }));
  }
}
