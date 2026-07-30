import type { PrismaClient } from '@prisma/client';
import type {
  DemographicCount,
  IDemographicsRepository,
} from '@domain/repositories/IDemographicsRepository';
import { getEffectiveChurchId } from '@shared/context/tenant-context';

export class PrismaDemographicsRepository implements IDemographicsRepository {
  constructor(private readonly prisma: PrismaClient) {}

  /**
   * Uma única query agrega as três dimensões. A CTE `people` une visitantes e
   * membros de célula; visitantes já convertidos em membro são excluídos do
   * lado dos visitantes para não contar a mesma pessoa duas vezes.
   */
  async countByDemographics(): Promise<DemographicCount[]> {
    const churchId = getEffectiveChurchId() ?? null;
    const rows = await this.prisma.$queryRaw<
      Array<{ dimension: string; bucket: string; count: bigint }>
    >`
      WITH people AS (
        SELECT v.gender::text AS gender, v.birth_date, v.marital_status
        FROM visitors v
        WHERE (${churchId}::text IS NULL OR v.church_id = ${churchId})
          AND NOT EXISTS (
            SELECT 1 FROM cell_members cm WHERE cm.source_visitor_id = v.id
          )
        UNION ALL
        SELECT m.gender::text AS gender, m.birth_date, m.marital_status
        FROM cell_members m
        WHERE (${churchId}::text IS NULL OR m.church_id = ${churchId})
      )
      SELECT 'gender' AS dimension,
             COALESCE(gender, 'UNKNOWN') AS bucket,
             COUNT(*)::bigint AS count
      FROM people
      GROUP BY 2

      UNION ALL

      SELECT 'ageRange' AS dimension,
             CASE
               WHEN birth_date IS NULL THEN 'UNKNOWN'
               WHEN EXTRACT(YEAR FROM AGE(birth_date)) <= 11 THEN '0_11'
               WHEN EXTRACT(YEAR FROM AGE(birth_date)) <= 17 THEN '12_17'
               WHEN EXTRACT(YEAR FROM AGE(birth_date)) <= 25 THEN '18_25'
               WHEN EXTRACT(YEAR FROM AGE(birth_date)) <= 34 THEN '26_34'
               WHEN EXTRACT(YEAR FROM AGE(birth_date)) <= 44 THEN '35_44'
               WHEN EXTRACT(YEAR FROM AGE(birth_date)) <= 54 THEN '45_54'
               ELSE '55_PLUS'
             END AS bucket,
             COUNT(*)::bigint AS count
      FROM people
      GROUP BY 2

      UNION ALL

      SELECT 'maritalStatus' AS dimension,
             CASE
               WHEN marital_status IS NULL OR btrim(marital_status) = '' THEN 'UNKNOWN'
               WHEN lower(marital_status) LIKE 'casad%' THEN 'MARRIED'
               WHEN lower(marital_status) LIKE 'solteir%' THEN 'SINGLE'
               ELSE 'OTHER'
             END AS bucket,
             COUNT(*)::bigint AS count
      FROM people
      GROUP BY 2
    `;

    return rows.map((r) => ({
      dimension: r.dimension as DemographicCount['dimension'],
      bucket: r.bucket,
      count: Number(r.count),
    }));
  }
}
