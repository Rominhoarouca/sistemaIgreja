import type { IVisitorRepository } from '@domain/repositories/IVisitorRepository';
import type { Visitor, CreateVisitorData } from '@domain/entities/Visitor';

export class RegisterVisitorUseCase {
  constructor(private readonly visitorRepo: IVisitorRepository) {}

  async execute(data: CreateVisitorData): Promise<Visitor> {
    return this.visitorRepo.create(data);
  }
}
