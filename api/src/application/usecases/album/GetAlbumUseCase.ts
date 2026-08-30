import type {
  AlbumPhotoRow,
  AlbumScope,
  IAlbumRepository,
} from '@domain/repositories/IAlbumRepository';
import type { MinioService } from '@infrastructure/storage/MinioService';

/** Quantas fotos entram na montagem de capa de um grupo. */
const kCoverSize = 4;

/**
 * Degraus do álbum. `LIDER` é o degrau do meio quando o líder responde direto
 * à coordenação, sem supervisor — ocupa o mesmo lugar que uma supervisão.
 */
export type AlbumLevel = 'COORDENACAO' | 'SUPERVISAO' | 'LIDER' | 'CELULA';

export interface AlbumPhoto {
  readonly url: string;
  readonly cellId: string;
  readonly cellName: string;
  readonly leaderName: string | null;
  readonly lesson: string | null;
}

/**
 * Nó do álbum. O app desenha `coverPhotos` como montagem e usa `children`
 * como carrossel — quando não há filhos (nível célula), o carrossel são as
 * próprias `photos`.
 */
export interface AlbumNode {
  readonly id: string;
  readonly name: string;
  readonly level: AlbumLevel;
  readonly color: string | null;
  readonly photoCount: number;
  readonly coverPhotos: string[];
  readonly photos: AlbumPhoto[];
  readonly children: AlbumNode[];
}

/** Degrau da árvore. `REDE` = supervisão ou líder direto na coordenação. */
type AlbumStage = 'COORDENACAO' | 'REDE' | 'CELULA';

export interface AlbumDayView {
  readonly date: string;
  readonly rootLevel: AlbumLevel;
  readonly photoCount: number;
  readonly groups: AlbumNode[];
}

/** Chave de agrupamento quando a cadeia está incompleta. */
const kNoCoordenacao = 'sem-coordenacao';
const kNoRede = 'sem-rede';

export class GetAlbumUseCase {
  constructor(
    private readonly albumRepo: IAlbumRepository,
    private readonly minio: MinioService,
  ) {}

  /** Dias com foto + a montagem de capa de cada dia. */
  async listDays(
    scope: AlbumScope,
    limit: number,
  ): Promise<Array<{ date: string; photoCount: number; coverPhotos: string[] }>> {
    const days = await this.albumRepo.findDays(scope, limit);
    if (days.length === 0) return [];

    const rows = await this.albumRepo.findPhotosByDates(
      scope,
      days.map((d) => d.date),
    );
    const byDate = new Map<string, AlbumPhotoRow[]>();
    for (const row of rows) {
      const key = isoDate(row.meetingDate);
      (byDate.get(key) ?? byDate.set(key, []).get(key)!).push(row);
    }

    return Promise.all(
      days.map(async (day) => {
        const key = isoDate(day.date);
        return {
          date: key,
          photoCount: day.photoCount,
          coverPhotos: await this.sign(
            (byDate.get(key) ?? []).slice(0, kCoverSize).map((r) => r.photoKey),
          ),
        };
      }),
    );
  }

  /**
   * Árvore de um dia, já recortada pelo perfil. O nível raiz é o degrau
   * imediatamente abaixo de quem está olhando: admin começa nas coordenações,
   * coordenador nas supervisões e supervisor nas células.
   */
  async getDay(scope: AlbumScope, date: Date): Promise<AlbumDayView> {
    const rows = await this.albumRepo.findPhotosByDates(scope, [date]);
    const rootStage: AlbumStage =
      scope.kind === 'ALL'
        ? 'COORDENACAO'
        : scope.kind === 'COORDENADOR'
          ? 'REDE'
          : 'CELULA';

    const groups = await this.buildLevel(rows, rootStage);
    return {
      date: isoDate(date),
      // O degrau do meio pode misturar supervisão e líder direto; o rótulo do
      // nível de cada nó vai em `groups[].level`.
      rootLevel: rootStage === 'REDE' ? 'SUPERVISAO' : rootStage,
      photoCount: rows.length,
      groups,
    };
  }

  /**
   * Agrupa as linhas no degrau pedido e desce recursivamente.
   *
   * `stage` é o degrau lógico; o `level` de cada nó sai de [stageNodeLevel],
   * porque o degrau do meio pode render tanto uma supervisão quanto um líder
   * ligado direto à coordenação.
   */
  private async buildLevel(
    rows: AlbumPhotoRow[],
    stage: AlbumStage,
  ): Promise<AlbumNode[]> {
    const buckets = new Map<string, AlbumPhotoRow[]>();
    for (const row of rows) {
      const key = this.keyFor(row, stage);
      (buckets.get(key) ?? buckets.set(key, []).get(key)!).push(row);
    }

    return Promise.all(
      [...buckets.entries()].map(async ([id, groupRows]) => {
        const first = groupRows[0]!;
        const children =
          stage === 'CELULA'
            ? []
            : await this.buildLevel(
                groupRows,
                stage === 'COORDENACAO' ? 'REDE' : 'CELULA',
              );

        return {
          id,
          name: this.nameFor(first, stage),
          level: this.stageNodeLevel(first, stage),
          color: stage === 'COORDENACAO' ? first.coordenacaoColor : null,
          photoCount: groupRows.length,
          coverPhotos: await this.sign(
            groupRows.slice(0, kCoverSize).map((r) => r.photoKey),
          ),
          photos: await this.toPhotos(groupRows),
          children,
        };
      }),
    );
  }

  /**
   * Chave do agrupamento. No degrau do meio, o líder sem supervisor vira o
   * próprio grupo — senão todos os líderes diretos de uma coordenação
   * cairiam juntos num balde só.
   */
  private keyFor(row: AlbumPhotoRow, stage: AlbumStage): string {
    switch (stage) {
      case 'COORDENACAO':
        return row.coordenacaoId ?? kNoCoordenacao;
      case 'REDE':
        if (row.supervisorId) return `sup:${row.supervisorId}`;
        return row.leaderId ? `lider:${row.leaderId}` : kNoRede;
      case 'CELULA':
        return row.cellId;
    }
  }

  private nameFor(row: AlbumPhotoRow, stage: AlbumStage): string {
    switch (stage) {
      case 'COORDENACAO':
        return row.coordenacaoName ?? 'Sem coordenação';
      case 'REDE':
        return row.supervisorName ?? row.leaderName ?? 'Sem supervisão';
      case 'CELULA':
        return row.cellName;
    }
  }

  private stageNodeLevel(row: AlbumPhotoRow, stage: AlbumStage): AlbumLevel {
    if (stage === 'COORDENACAO') return 'COORDENACAO';
    if (stage === 'CELULA') return 'CELULA';
    return row.supervisorId ? 'SUPERVISAO' : 'LIDER';
  }

  private async toPhotos(rows: AlbumPhotoRow[]): Promise<AlbumPhoto[]> {
    return Promise.all(
      rows.map(async (row) => ({
        url: (await this.sign([row.photoKey]))[0] ?? '',
        cellId: row.cellId,
        cellName: row.cellName,
        leaderName: row.leaderName,
        lesson: row.lesson,
      })),
    );
  }

  /** Falha de storage não derruba o álbum: a foto some, o resto continua. */
  private async sign(keys: string[]): Promise<string[]> {
    const urls = await Promise.all(
      keys.map((key) =>
        this.minio.presignedDownloadUrl(key).catch(() => null),
      ),
    );
    return urls.filter((u): u is string => u !== null);
  }
}

/** `meeting_date` é `date` no Postgres: lê em UTC para não voltar um dia. */
function isoDate(date: Date): string {
  return date.toISOString().substring(0, 10);
}
