import { AsyncLocalStorage } from 'node:async_hooks';
import type { UserRole } from '@domain/entities/User';

export interface TenantContext {
  readonly churchId?: string | undefined;
  readonly userId?: string | undefined;
  readonly role?: UserRole | undefined;
  /** SUPERADMIN opera cross-tenant: quando true, o guard do Prisma não filtra. */
  readonly crossTenant?: boolean | undefined;
}

const storage = new AsyncLocalStorage<TenantContext>();

/** Executa `fn` com o contexto de tenant ativo (propaga por todo o async). */
export function runWithTenant<T>(ctx: TenantContext, fn: () => T): T {
  return storage.run(ctx, fn);
}

export function getTenantContext(): TenantContext | undefined {
  return storage.getStore();
}

/** churchId efetivo para filtragem. undefined = sem filtro (superadmin/público/seed). */
export function getEffectiveChurchId(): string | undefined {
  const ctx = storage.getStore();
  if (!ctx || ctx.crossTenant) return undefined;
  return ctx.churchId;
}
