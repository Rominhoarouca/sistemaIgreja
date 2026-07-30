import type { IDemographicsRepository } from '@domain/repositories/IDemographicsRepository';
import type { DemographicBucket, Demographics } from '@domain/entities/Demographics';

/**
 * Ordem e rótulos de cada dimensão. Buckets sem nenhuma pessoa também são
 * devolvidos (count 0) para que o gráfico mantenha as mesmas linhas sempre.
 */
const GENDER_BUCKETS: ReadonlyArray<readonly [string, string]> = [
  ['MASCULINO', 'Homens'],
  ['FEMININO', 'Mulheres'],
  ['UNKNOWN', 'Não informado'],
];

const AGE_BUCKETS: ReadonlyArray<readonly [string, string]> = [
  ['0_11', 'Até 11'],
  ['12_17', '12 a 17'],
  ['18_25', '18 a 25'],
  ['26_34', '26 a 34'],
  ['35_44', '35 a 44'],
  ['45_54', '45 a 54'],
  ['55_PLUS', '55+'],
  ['UNKNOWN', 'Não informado'],
];

const MARITAL_BUCKETS: ReadonlyArray<readonly [string, string]> = [
  ['MARRIED', 'Casados'],
  ['SINGLE', 'Solteiros'],
  ['OTHER', 'Outros'],
  ['UNKNOWN', 'Não informado'],
];

export class GetDemographicsUseCase {
  constructor(private readonly demographicsRepo: IDemographicsRepository) {}

  async execute(): Promise<Demographics> {
    const counts = await this.demographicsRepo.countByDemographics();

    // O total é o mesmo em qualquer dimensão — toda pessoa cai em exatamente um
    // bucket, inclusive no "Não informado".
    const total = counts
      .filter((c) => c.dimension === 'gender')
      .reduce((sum, c) => sum + c.count, 0);

    const build = (
      dimension: 'gender' | 'ageRange' | 'maritalStatus',
      buckets: ReadonlyArray<readonly [string, string]>,
    ): DemographicBucket[] => {
      const byBucket = new Map(
        counts.filter((c) => c.dimension === dimension).map((c) => [c.bucket, c.count]),
      );
      return buckets.map(([key, label]) => {
        const count = byBucket.get(key) ?? 0;
        return {
          key,
          label,
          count,
          percent: total === 0 ? 0 : Math.round((count / total) * 1000) / 10,
        };
      });
    };

    return {
      total,
      gender: build('gender', GENDER_BUCKETS),
      ageRange: build('ageRange', AGE_BUCKETS),
      maritalStatus: build('maritalStatus', MARITAL_BUCKETS),
    };
  }
}
