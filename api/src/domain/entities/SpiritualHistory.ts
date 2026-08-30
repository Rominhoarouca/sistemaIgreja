export type SpiritualEventType =
  | 'enviado_batismo'
  | 'batizado'
  | 'enviado_treinamento_lider'
  | 'concluiu_treinamento'
  | 'tornou_se_lider';

export interface SpiritualHistory {
  readonly id: string;
  /** Exatamente um entre `visitorId` e `memberId` é preenchido. */
  readonly visitorId: string | null;
  readonly memberId: string | null;
  readonly eventType: SpiritualEventType;
  readonly description: string | null;
  readonly date: Date;
  readonly recordedById: string;
  readonly createdAt: Date;
}

export interface AddSpiritualEventData {
  readonly visitorId?: string | undefined;
  readonly memberId?: string | undefined;
  readonly eventType: SpiritualEventType;
  readonly description?: string | undefined;
  readonly date: Date;
  readonly recordedById: string;
}
