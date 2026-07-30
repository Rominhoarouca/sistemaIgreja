/**
 * Seed SaaS — idempotente. Cria/garante:
 *  - Planos FREE/STARTER/GROWTH/COMPLETE (com features)
 *  - Usuário SUPERADMIN (dono do SaaS), churchId = null
 *
 * Uso: npm run seed:saas
 * Env opcional: SUPERADMIN_EMAIL, SUPERADMIN_PASSWORD, SUPERADMIN_NAME
 */
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

const PLANS = [
  { tier: 'FREE' as const, name: 'Free', description: 'Recursos essenciais para começar', priceMonth: 0, priceYear: 0, features: [] as string[] },
  { tier: 'STARTER' as const, name: 'Starter', description: 'Para células em crescimento', priceMonth: 4900, priceYear: 49000, features: ['spiritual_history', 'coordenacao'] },
  { tier: 'GROWTH' as const, name: 'Growth', description: 'Gestão completa de discipulado', priceMonth: 9900, priceYear: 99000, features: ['spiritual_history', 'coordenacao', 'materials', 'map_geolocation', 'advanced_dashboard'] },
  { tier: 'COMPLETE' as const, name: 'Complete', description: 'Todos os recursos, sem limites', priceMonth: 19900, priceYear: 199000, features: ['spiritual_history', 'coordenacao', 'materials', 'map_geolocation', 'advanced_dashboard', 'whatsapp'] },
];

async function main(): Promise<void> {
  for (const p of PLANS) {
    await prisma.plan.upsert({
      where: { tier: p.tier },
      create: p,
      update: { name: p.name, description: p.description, priceMonth: p.priceMonth, priceYear: p.priceYear, features: p.features },
    });
  }
  console.log(`[seed:saas] ${PLANS.length} planos garantidos`);

  const email = (process.env['SUPERADMIN_EMAIL'] ?? 'superadmin@sistema.local').toLowerCase();
  const password = process.env['SUPERADMIN_PASSWORD'] ?? 'superadmin123';
  const name = process.env['SUPERADMIN_NAME'] ?? 'Super Admin';

  const existing = await prisma.user.findFirst({ where: { email, role: 'SUPERADMIN' } });
  if (existing) {
    console.log(`[seed:saas] SUPERADMIN já existe: ${email}`);
  } else {
    await prisma.user.create({
      data: { name, email, password: await bcrypt.hash(password, 12), role: 'SUPERADMIN', churchId: null },
    });
    console.log(`[seed:saas] SUPERADMIN criado: ${email} / senha: ${password}`);
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
