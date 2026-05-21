import type { PrismaClient } from '@prisma/client';
import type { ISpiritualHistoryRepository } from '@domain/repositories/ISpiritualHistoryRepository';
import type { SpiritualHistory, AddSpiritualEventData } from '@domain/entities/SpiritualHistory';

export class PrismaSpiritualHistoryRepository implements ISpiritualHistoryRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async findByVisitor(visitorId: string): Promise<SpiritualHistory[]> {
    return this.prisma.spiritualHistory.findMany({
      where: { visitorId },
      orderBy: { date: 'asc' },
    });
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
