import type { PrismaClient } from '@prisma/client';
import type { MinioService } from '@infrastructure/storage/MinioService';

interface LeaderCounts {
  readonly lider: number;
  readonly supervisor: number;
  readonly coordenador: number;
  readonly coordenacoes: number;
}

export interface ChurchUsage {
  readonly churchId: string;
  readonly churchName: string;
  readonly isActive: boolean;
  readonly planTier: string | null;
  readonly membersCount: number;
  readonly cellsCount: number;
  readonly visitorsCount: number;
  readonly leaders: LeaderCounts;
  readonly storageBytes: number;
}

export interface SaasUsageResult {
  readonly totals: {
    readonly churches: number;
    readonly activeChurches: number;
    readonly membersCount: number;
    readonly cellsCount: number;
    readonly visitorsCount: number;
    readonly leaders: LeaderCounts;
    readonly storageBytes: number;
  };
  readonly churches: ChurchUsage[];
}

/**
 * Deriva o churchId "dono" de um objeto do MinIO a partir da convenção de
 * nomes usada pelos use cases de upload (ver UploadChurchLogoUseCase,
 * UpdateProfileUseCase, UploadMaterialUseCase, AttendanceController):
 *  - `churches/{churchId}/...`      → logo da igreja
 *  - `users/{userId}/...`           → foto de perfil
 *  - `meetings/{cellId}/...`        → foto de reunião de célula
 *  - `{cellId}/{uuid}.ext`          → material da célula
 */
function resolveObjectChurchId(
  objectName: string,
  userChurchMap: Map<string, string>,
  cellChurchMap: Map<string, string>,
): string | undefined {
  const parts = objectName.split('/');
  if (parts[0] === 'churches' && parts[1]) return parts[1];
  if (parts[0] === 'users' && parts[1]) return userChurchMap.get(parts[1]);
  if (parts[0] === 'meetings' && parts[1]) return cellChurchMap.get(parts[1]);
  return cellChurchMap.get(parts[0] ?? '');
}

export class GetSaasUsageUseCase {
  constructor(
    private readonly prisma: PrismaClient,
    private readonly minio: MinioService,
  ) {}

  async execute(): Promise<SaasUsageResult> {
    const [churches, cells, users, cellMemberGroups, visitorGroups, coordenacaoGroups, objects] =
      await Promise.all([
        this.prisma.church.findMany({
          include: { subscription: { include: { plan: true } } },
          orderBy: { createdAt: 'desc' },
        }),
        this.prisma.cell.findMany({ select: { id: true, churchId: true } }),
        this.prisma.user.findMany({ select: { id: true, churchId: true, role: true } }),
        this.prisma.cellMember.groupBy({ by: ['churchId'], _count: { _all: true } }),
        this.prisma.visitor.groupBy({ by: ['churchId'], _count: { _all: true } }),
        this.prisma.coordenacao.groupBy({ by: ['churchId'], _count: { _all: true } }),
        this.minio.listAllObjects(),
      ]);

    const cellChurchMap = new Map(cells.map((c) => [c.id, c.churchId] as const).filter((e): e is [string, string] => e[1] != null));
    const userChurchMap = new Map(users.map((u) => [u.id, u.churchId] as const).filter((e): e is [string, string] => e[1] != null));

    const cellsByChurch = new Map<string, number>();
    for (const c of cells) {
      if (!c.churchId) continue;
      cellsByChurch.set(c.churchId, (cellsByChurch.get(c.churchId) ?? 0) + 1);
    }

    const leadersByChurch = new Map<string, { lider: number; supervisor: number; coordenador: number }>();
    for (const u of users) {
      if (!u.churchId) continue;
      const entry = leadersByChurch.get(u.churchId) ?? { lider: 0, supervisor: 0, coordenador: 0 };
      if (u.role === 'LIDER') entry.lider += 1;
      else if (u.role === 'SUPERVISOR') entry.supervisor += 1;
      else if (u.role === 'COORDENADOR') entry.coordenador += 1;
      leadersByChurch.set(u.churchId, entry);
    }

    const membersByChurch = new Map(cellMemberGroups.map((g) => [g.churchId, g._count._all]));
    const visitorsByChurch = new Map(visitorGroups.map((g) => [g.churchId, g._count._all]));
    const coordenacoesByChurch = new Map(coordenacaoGroups.map((g) => [g.churchId, g._count._all]));

    const storageByChurch = new Map<string, number>();
    for (const obj of objects) {
      const churchId = resolveObjectChurchId(obj.name, userChurchMap, cellChurchMap);
      if (!churchId) continue;
      storageByChurch.set(churchId, (storageByChurch.get(churchId) ?? 0) + obj.size);
    }

    const churchUsages: ChurchUsage[] = churches.map((church) => {
      const leaders = leadersByChurch.get(church.id) ?? { lider: 0, supervisor: 0, coordenador: 0 };
      return {
        churchId: church.id,
        churchName: church.name,
        isActive: church.isActive,
        planTier: church.subscription?.plan.tier ?? null,
        membersCount: membersByChurch.get(church.id) ?? 0,
        cellsCount: cellsByChurch.get(church.id) ?? 0,
        visitorsCount: visitorsByChurch.get(church.id) ?? 0,
        leaders: {
          lider: leaders.lider,
          supervisor: leaders.supervisor,
          coordenador: leaders.coordenador,
          coordenacoes: coordenacoesByChurch.get(church.id) ?? 0,
        },
        storageBytes: storageByChurch.get(church.id) ?? 0,
      };
    });

    const totals = churchUsages.reduce(
      (acc, c) => ({
        churches: acc.churches + 1,
        activeChurches: acc.activeChurches + (c.isActive ? 1 : 0),
        membersCount: acc.membersCount + c.membersCount,
        cellsCount: acc.cellsCount + c.cellsCount,
        visitorsCount: acc.visitorsCount + c.visitorsCount,
        leaders: {
          lider: acc.leaders.lider + c.leaders.lider,
          supervisor: acc.leaders.supervisor + c.leaders.supervisor,
          coordenador: acc.leaders.coordenador + c.leaders.coordenador,
          coordenacoes: acc.leaders.coordenacoes + c.leaders.coordenacoes,
        },
        storageBytes: acc.storageBytes + c.storageBytes,
      }),
      {
        churches: 0,
        activeChurches: 0,
        membersCount: 0,
        cellsCount: 0,
        visitorsCount: 0,
        leaders: { lider: 0, supervisor: 0, coordenador: 0, coordenacoes: 0 },
        storageBytes: 0,
      },
    );

    return { totals, churches: churchUsages };
  }
}
