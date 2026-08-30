/**
 * Uma foto de encontro com a cadeia de gestão resolvida
 * (célula → líder → supervisor → coordenação).
 *
 * A coordenação vem do supervisor **ou** do próprio líder: um coordenador pode
 * ter líderes direto na rede dele, sem supervisor no meio. Por isso
 * `supervisorId` pode ser nulo com `coordenacaoId` preenchido.
 *
 * Os campos da cadeia são anuláveis de propósito: célula sem líder, líder sem
 * supervisor e líder sem coordenação são estados válidos, e a foto não pode
 * sumir do álbum por causa disso — cai num grupo "Sem coordenação".
 */
export interface AlbumPhotoRow {
  readonly meetingDate: Date;
  readonly photoKey: string;
  readonly lesson: string | null;
  readonly cellId: string;
  readonly cellName: string;
  readonly leaderId: string | null;
  readonly leaderName: string | null;
  readonly supervisorId: string | null;
  readonly supervisorName: string | null;
  readonly coordenacaoId: string | null;
  readonly coordenacaoName: string | null;
  readonly coordenacaoColor: string | null;
}

export interface AlbumDay {
  readonly date: Date;
  readonly photoCount: number;
}

/**
 * Recorte de quem está olhando. O álbum mostra apenas as células sob a gestão
 * do perfil: admin vê a igreja inteira, coordenador vê a própria coordenação e
 * supervisor vê os próprios líderes.
 */
export type AlbumScope =
  | { readonly kind: 'ALL' }
  | { readonly kind: 'COORDENADOR'; readonly userId: string }
  | { readonly kind: 'SUPERVISOR'; readonly userId: string };

export interface IAlbumRepository {
  /** Dias com foto, do mais recente para o mais antigo. */
  findDays(scope: AlbumScope, limit: number): Promise<AlbumDay[]>;
  findPhotosByDates(scope: AlbumScope, dates: Date[]): Promise<AlbumPhotoRow[]>;
}
