export type SpiritualEventType =
  | 'enviado_batismo'
  | 'batizado'
  | 'enviado_treinamento_lider'
  | 'concluiu_treinamento'
  | 'tornou_se_lider';

export interface SpiritualHistory {
  readonly id: string;
  readonly visitorId: string;
  readonly eventType: SpiritualEventType;
  readonly description: string | null;
  readonly date: Date;
  readonly recordedById: string;
  readonly createdAt: Date;
}

export interface AddSpiritualEventData {
  readonly visitorId: string;
  readonly eventType: SpiritualEventType;
  readonly description?: string | undefined;
  readonly date: Date;
  readonly recordedById: string;
}
