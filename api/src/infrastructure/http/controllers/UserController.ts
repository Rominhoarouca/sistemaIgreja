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

  updateProfile = async (req: Request, res: Response): Promise<void> => {
    const body = updateProfileSchema.parse(
      typeof req.body === 'string' ? JSON.parse(req.body) : req.body,
    );

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
