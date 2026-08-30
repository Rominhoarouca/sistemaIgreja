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

export class GetSaasUsageUseCase {
  constructor(
    private readonly prisma: PrismaClient,
    private readonly minio: MinioService,
  ) {}

  async execute(): Promise<SaasUsageResult> {
    const [churches, cells, users, cellMemberGroups, visitorGroups, coordenacaoGroups] =
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
      ]);

    // Com bucket por igreja o espaço em disco é o tamanho do próprio bucket —
    // não é mais preciso adivinhar o dono pelo nome do objeto.
    const storageByChurch = new Map<string, number>(
      await Promise.all(
        churches.map(
          async (church) =>
            [church.id, await this.minio.bucketSizeBytes(church.id).catch(() => 0)] as [
              string,
              number,
            ],
        ),
      ),
    );

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
