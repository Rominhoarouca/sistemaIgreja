import type { PrismaClient } from '@prisma/client';
import type { ISpiritualHistoryRepository, SpiritualHistoryWithVisitor } from '@domain/repositories/ISpiritualHistoryRepository';
import type { SpiritualHistory, AddSpiritualEventData } from '@domain/entities/SpiritualHistory';

export class PrismaSpiritualHistoryRepository implements ISpiritualHistoryRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async findByVisitor(visitorId: string): Promise<SpiritualHistory[]> {
    return this.prisma.spiritualHistory.findMany({
      where: { visitorId },
      orderBy: { date: 'asc' },
    });
  }

  async findByCellId(cellId: string): Promise<SpiritualHistoryWithVisitor[]> {
    const rows = await this.prisma.spiritualHistory.findMany({
      where: { visitor: { cellId } },
      include: { visitor: { select: { name: true } } },
      orderBy: { date: 'desc' },
    });
    return rows.map((r) => ({
      id: r.id,
      visitorId: r.visitorId,
      visitorName: r.visitor.name,
      eventType: r.eventType as SpiritualHistory['eventType'],
      description: r.description,
      date: r.date,
      recordedById: r.recordedById,
      createdAt: r.createdAt,
    }));
  }

  async add(data: AddSpiritualEventData): Promise<SpiritualHistory> {
    return this.prisma.spiritualHistory.create({
      data: {
        visitorId: data.visitorId,
        eventType: data.eventType,
        description: data.description ?? null,
        date: data.date,
        recordedById: data.recordedById,
      },
    });
  }
}
