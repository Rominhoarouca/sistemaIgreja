/**
 * Informações demográficas agregadas da igreja. A população considerada são as
 * pessoas ministradas: visitantes + membros de célula. Visitantes já convertidos
 * em membro contam uma única vez (pelo registro de membro).
 */
export interface DemographicBucket {
  /** Chave estável para o cliente (não traduzir). */
  readonly key: string;
  /** Rótulo já em pt-BR, pronto para exibição. */
  readonly label: string;
  readonly count: number;
  /** Percentual sobre o total de pessoas, com 1 casa decimal. */
  readonly percent: number;
}

export interface Demographics {
  readonly total: number;
  readonly gender: DemographicBucket[];
  readonly ageRange: DemographicBucket[];
  readonly maritalStatus: DemographicBucket[];
}
