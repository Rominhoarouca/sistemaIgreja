import type { Request, Response } from 'express';
import { z } from 'zod';
import bcrypt from 'bcryptjs';
import type { GetProfileUseCase } from '@application/usecases/user/GetProfileUseCase';
import type { UpdateProfileUseCase } from '@application/usecases/user/UpdateProfileUseCase';
import type { IUserRepository } from '@domain/repositories/IUserRepository';
import type { IKidsRepository } from '@domain/repositories/IKidsRepository';
import { AppError } from '@shared/errors/AppError';
import { hasRole } from '../middlewares/auth.middleware';
import { effectiveRoles } from '@domain/entities/User';

// ADMIN/SUPERADMIN ficam de fora de propósito: quem cria admin de igreja é o
// signup do tenant e o super-admin, não esta tela.
const roleEnum = z.enum(['LIDER', 'SUPERVISOR', 'COORDENADOR', 'KIDS', 'RESPONSAVEL']);

// A tela de perfis também administra o papel de ADMIN da igreja — quem já é
// admin pode promover outro. SUPERADMIN continua fora: é o dono do SaaS.
const manageableRoleEnum = z.enum([
  'ADMIN',
  'LIDER',
  'SUPERVISOR',
  'COORDENADOR',
  'KIDS',
  'RESPONSAVEL',
]);

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
  isMarried: z.boolean().optional(),
  spouseName: z.string().nullable().optional(),
  weddingDate: z.string().datetime({ offset: true }).nullable().optional(),
  children: z.array(childSchema).optional(),
});

export class UserController {
  constructor(
    private readonly getProfileUseCase: GetProfileUseCase,
    private readonly updateProfileUseCase: UpdateProfileUseCase,
    private readonly userRepo: IUserRepository,
    private readonly kidsRepo: IKidsRepository,
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

  findCoordinadores = async (_req: Request, res: Response): Promise<void> => {
    const coordinadores = await this.userRepo.listCoordinadores();
    res.json({ supervisors: coordinadores });
  };

  /** Lista todos os usuários da igreja (tela de perfis). */
  listUsers = async (_req: Request, res: Response): Promise<void> => {
    const users = await this.userRepo.listAll();
    res.json({ users });
  };

  searchUsers = async (req: Request, res: Response): Promise<void> => {
    const { q } = z.object({ q: z.string().min(1) }).parse(req.query);
    const users = await this.userRepo.searchUsers(q);
    res.json({ users });
  };

  getMyLeaders = async (req: Request, res: Response): Promise<void> => {
    const leaders = hasRole(req, 'COORDENADOR')
      ? await this.userRepo.findLeadersByCoordinatorId(req.userId)
      : await this.userRepo.findLeadersBySupervisorId(req.userId);
    res.json({ leaders });
  };

  getMySupervisors = async (req: Request, res: Response): Promise<void> => {
    const supervisors = await this.userRepo.findSupervisorsByCoordinatorId(req.userId);
    res.json({ supervisors });
  };

  assignLeaderSupervisor = async (req: Request, res: Response): Promise<void> => {
    const { leaderId } = req.params as { leaderId: string };
    const { supervisorId } = z.object({ supervisorId: z.string().uuid().nullable() }).parse(req.body);
    await this.userRepo.assignSupervisor(leaderId, supervisorId);
    res.status(204).send();
  };

  promoteLeader = async (req: Request, res: Response): Promise<void> => {
    const { leaderId } = req.params as { leaderId: string };
    const { targetRole } = z
      .object({ targetRole: z.enum(['SUPERVISOR', 'COORDENADOR']) })
      .parse(req.body);
    const user = await this.userRepo.findById(leaderId);
    if (!user) throw AppError.notFound('Usuário não encontrado');
    if (!effectiveRoles(user).includes('LIDER')) {
      throw new AppError('Apenas líderes podem ser promovidos', 422, 'INVALID_ROLE');
    }
    await this.userRepo.promoteUser(leaderId, targetRole);
    res.status(204).send();
  };

  assignSupervisorCoordenacao = async (req: Request, res: Response): Promise<void> => {
    const { supervisorId } = req.params as { supervisorId: string };
    const { coordenacaoId } = z
      .object({ coordenacaoId: z.string().uuid().nullable() })
      .parse(req.body);
    await this.userRepo.assignSupervisorToCoordenacao(supervisorId, coordenacaoId);
    res.status(204).send();
  };

  /**
   * Redefine a senha de outro usuário, conforme o escopo do solicitante:
   * ADMIN → qualquer perfil; SUPERVISOR → apenas seus líderes;
   * COORDENADOR → líderes e supervisores da sua coordenação.
   */
  resetUserPassword = async (req: Request, res: Response): Promise<void> => {
    const { userId } = req.params as { userId: string };
    const { newPassword } = z
      .object({ newPassword: z.string().min(6).max(72) })
      .parse(req.body);

    const target = await this.userRepo.findById(userId);
    if (!target) throw AppError.notFound('Usuário não encontrado');

    // Cada papel do solicitante é um escopo somado — quem é supervisor E
    // coordenador alcança os dois conjuntos.
    const targetRoles = effectiveRoles(target);
    let allowed = hasRole(req, 'ADMIN', 'SUPERADMIN');
    if (!allowed && hasRole(req, 'SUPERVISOR')) {
      allowed = targetRoles.includes('LIDER') && target.supervisorId === req.userId;
    }
    if (!allowed && hasRole(req, 'COORDENADOR')) {
      if (targetRoles.includes('SUPERVISOR')) {
        const sups = await this.userRepo.findSupervisorsByCoordinatorId(req.userId);
        allowed = sups.some((s) => s.id === userId);
      }
      if (!allowed && targetRoles.includes('LIDER')) {
        const leaders = await this.userRepo.findLeadersByCoordinatorId(req.userId);
        allowed = leaders.some((l) => l.id === userId);
      }
    }
    if (!allowed) {
      throw AppError.forbidden('Sem permissão para redefinir a senha deste usuário');
    }

    const hash = await bcrypt.hash(newPassword, 10);
    await this.userRepo.resetPassword(userId, hash);
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
      ...(rawBody.spouseName !== undefined ? { spouseName: toNullable(rawBody.spouseName) } : {}),
      ...(rawBody.weddingDate !== undefined ? { weddingDate: toNullable(rawBody.weddingDate) } : {}),
      ...(rawBody.isMarried !== undefined && typeof rawBody.isMarried === 'string'
        ? { isMarried: rawBody.isMarried === 'true' }
        : {}),
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
      ...(body.isMarried !== undefined && { isMarried: body.isMarried }),
      ...(body.spouseName !== undefined && { spouseName: body.spouseName }),
      ...(body.weddingDate !== undefined && { weddingDate: body.weddingDate }),
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

  /** Redefine o conjunto de papéis de um usuário (ADMIN). */
  setUserRoles = async (req: Request, res: Response): Promise<void> => {
    const { userId } = req.params as { userId: string };
    const { roles } = z.object({ roles: z.array(manageableRoleEnum).min(1) }).parse(req.body);

    const target = await this.userRepo.findById(userId);
    if (!target) throw AppError.notFound('Usuário não encontrado');

    // SUPERADMIN não é gerenciável por aqui: é o dono do SaaS, não um papel da
    // igreja. Sem isso um admin rebaixaria o superadmin e perderia o acesso
    // cross-tenant do sistema.
    if (effectiveRoles(target).includes('SUPERADMIN')) {
      throw AppError.forbidden('Os papéis do super-administrador não são editáveis aqui');
    }

    // Tirar o próprio ADMIN deixaria a pessoa sem acesso à tela que acabou de
    // usar — e possivelmente a igreja sem nenhum admin.
    if (userId === req.userId && !roles.includes('ADMIN')) {
      throw new AppError(
        'Você não pode remover o seu próprio perfil de administrador',
        422,
        'CANNOT_DEMOTE_SELF',
      );
    }

    const user = await this.userRepo.setRoles(userId, roles);
    res.json({ user });
  };

  createUser = async (req: Request, res: Response): Promise<void> => {
    const body = z.object({
      name: z.string().min(1),
      email: z.string().email(),
      password: z.string().min(6, 'Senha deve ter no mínimo 6 caracteres'),
      phone: z.string().optional(),
      cep: z.string().optional(),
      address: z.string().optional(),
      numero: z.string().optional(),
      complemento: z.string().optional(),
      bairroId: z.string().uuid().optional(),
      // KIDS e RESPONSAVEL entram aqui porque o ministério infantil cadastra
      // professor e pai pelo mesmo fluxo de admin. Nenhum dos dois participa
      // da hierarquia de células (cellIds/leaderIds ficam vazios para eles).
      role: roleEnum,
      // Papéis extras: a mesma pessoa pode ser líder, supervisor, coordenador
      // e admin ao mesmo tempo. `role` continua sendo o papel principal.
      roles: z.array(roleEnum).optional(),
      cellIds: z.array(z.string().uuid()).optional(),
      leaderIds: z.array(z.string().uuid()).optional(),
      supervisorIds: z.array(z.string().uuid()).optional(),
      coordenacaoId: z.string().uuid().optional(),
    }).parse(req.body);

    const existing = await this.userRepo.findByEmail(body.email);
    if (existing) throw new AppError('E-mail já cadastrado', 409, 'EMAIL_IN_USE');

    const hashedPassword = await bcrypt.hash(body.password, 12);

    // Build create data, only including defined fields
    const createData: any = {
      name: body.name,
      email: body.email,
      password: hashedPassword,
      role: body.role,
      roles: body.roles ?? [],
    };

    if (body.phone) createData.phone = body.phone;
    if (body.address) createData.address = body.address;
    if (body.cellIds) createData.cellIds = body.cellIds;
    if (body.leaderIds) createData.leaderIds = body.leaderIds;
    if (body.supervisorIds) createData.supervisorIds = body.supervisorIds;
    if (body.coordenacaoId) createData.coordenacaoId = body.coordenacaoId;

    const user = await this.userRepo.createUser(createData);

    // Religa automaticamente com crianças já cadastradas no balcão com esse
    // telefone — sem isso o pai loga e não vê o filho até alguém religar na mão.
    if (body.role === 'RESPONSAVEL' && body.phone) {
      await this.kidsRepo.linkGuardiansByPhone(body.phone, user.id);
    }

    res.status(201).json({ user });
  };
}
