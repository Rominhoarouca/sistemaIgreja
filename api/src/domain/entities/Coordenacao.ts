export interface Coordenacao {
  readonly id: string;
  readonly name: string;
  readonly color: string;
  readonly coordinadorId: string;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export interface CoordenacaoWithDetails extends Coordenacao {
  readonly coordinadorName: string;
  readonly supervisoresCount: number;
  readonly supervisores: Array<{ id: string; name: string; email: string }>;
}
