/** Contagem crua por dimensão/bucket, sem rótulos nem percentuais. */
export interface DemographicCount {
  readonly dimension: 'gender' | 'ageRange' | 'maritalStatus';
  readonly bucket: string;
  readonly count: number;
}

export interface IDemographicsRepository {
  /** Contagens por gênero, faixa etária e estado civil das pessoas da igreja. */
  countByDemographics(): Promise<DemographicCount[]>;
}
