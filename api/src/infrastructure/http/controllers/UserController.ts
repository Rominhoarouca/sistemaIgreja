import type { Request, Response } from 'express';
import { z } from 'zod';
import type { GetProfileUseCase } from '@application/usecases/user/GetProfileUseCase';
import type { UpdateProfileUseCase } from '@application/usecases/user/UpdateProfileUseCase';
import type { IUserRepository } from '@domain/repositories/IUserRepository';

const childSchema = z.object({
  id: z.string().uuid().optional(),
  name: z.string().min(1),
  birthDate: z.string().datetime({ offset: true }).nullable().optional(),
});

const updateProfileSchema = z.object({
  name: z.string().min(1).optional(),
  phone: z.string().nullable().optional(),
  address: z.string().nullable().optional(),
  birthDate: z.string().datetime({ offset: true }).nullable().optional(),
  children: z.array(childSchema).optional(),
});

export class UserController {
  constructor(
    private readonly getProfileUseCase: GetProfileUseCase,
    private readonly updateProfileUseCase: UpdateProfileUseCase,
    private readonly userRepo: IUserRepository,
  ) {}

  getProfile = async (req: Request, res: Response): Promise<void> => {
    const result = await this.getProfileUseCase.execute(req.userId);
    res.json({ user: result });
  };

  findLeaders = async (_req: Request, res: Response): Promise<void> => {
    const leaders = await this.userRepo.listLeaders();
    res.json({ leaders });
  };

  findSupervisors = async (_req: Request, res: Response): Promise<void> => {
    const supervisors = await this.userRepo.listSupervisors();
    res.json({ supervisors });
  };

  getMyLeaders = async (req: Request, res: Response): Promise<void> => {
    const leaders = await this.userRepo.findLeadersBySupervisorId(req.userId);
    res.json({ leaders });
  };

  assignLeaderSupervisor = async (req: Request, res: Response): Promise<void> => {
    const { leaderId } = req.params as { leaderId: string };
    const { supervisorId } = z.object({ supervisorId: z.string().uuid().nullable() }).parse(req.body);
    await this.userRepo.assignSupervisor(leaderId, supervisorId);
    res.status(204).send();
  };

  updateLeaderDescription = async (req: Request, res: Response): Promise<void> => {
    const { leaderId } = req.params as { leaderId: string };
    const { description } = z.object({ description: z.string().max(1000).nullable() }).parse(req.body);
    await this.userRepo.updateLeaderDescription(leaderId, description);
    res.status(204).send();
  };

  updateProfile = async (req: Request, res: Response): Promise<void> => {
    const rawBody = typeof req.body === 'string'
      ? JSON.parse(req.body)
      : (req.body ?? {});

    const toNullable = (value: unknown): unknown => {
      if (value === '' || value === 'null' || value === 'undefined') return null;
      return value;
    };

    const normalizedBody = {
      ...rawBody,
      ...(rawBody.phone !== undefined ? { phone: toNullable(rawBody.phone) } : {}),
      ...(rawBody.address !== undefined ? { address: toNullable(rawBody.address) } : {}),
      ...(rawBody.birthDate !== undefined ? { birthDate: toNullable(rawBody.birthDate) } : {}),
      ...(typeof rawBody.children === 'string'
        ? { children: JSON.parse(rawBody.children) }
        : {}),
    };

    const body = updateProfileSchema.parse(normalizedBody);

    const file = req.file;

    const { user, children } = await this.updateProfileUseCase.execute({
      userId: req.userId,
      ...(body.name !== undefined && { name: body.name }),
      ...(body.phone !== undefined && { phone: body.phone }),
      ...(body.address !== undefined && { address: body.address }),
      ...(body.birthDate !== undefined && { birthDate: body.birthDate }),
      ...(body.children !== undefined && {
        children: body.children.map((c) => ({
          ...(c.id !== undefined && { id: c.id }),
          name: c.name,
          ...(c.birthDate !== undefined && { birthDate: c.birthDate }),
        })),
      }),
      ...(file && {
        fileBuffer: file.buffer,
        mimeType: file.mimetype,
        originalName: file.originalname,
      }),
    });

    res.json({ user, children });
  };
}
