export interface Estado {
  readonly id: string;
  readonly name: string;
  readonly uf: string;
  readonly createdAt: Date;
}

export interface Cidade {
  readonly id: string;
  readonly name: string;
  readonly estadoId: string;
  readonly estado?: Estado;
  readonly latitude?: number | null;
  readonly longitude?: number | null;
  readonly createdAt: Date;
}

export interface Bairro {
  readonly id: string;
  readonly name: string;
  readonly cidadeId: string;
  readonly cidade?: Cidade;
  readonly latitude?: number | null;
  readonly longitude?: number | null;
  readonly createdAt: Date;
}

// Nested view used in responses
export interface BairroWithLocation extends Bairro {
  readonly cidade: Cidade & { readonly estado: Estado };
}

export interface CreateEstadoData {
  readonly name: string;
  readonly uf: string;
}

export interface CreateCidadeData {
  readonly name: string;
  readonly estadoId: string;
}

export interface CreateBairroData {
  readonly name: string;
  readonly cidadeId: string;
}
