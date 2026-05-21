import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main(): Promise<void> {
  // Admin
  const adminPassword = await bcrypt.hash('admin123', 12);
  const admin = await prisma.user.upsert({
    where: { email: 'admin@sistemaigreja.com.br' },
    update: {},
    create: {
      name: 'Administrador',
      email: 'admin@sistemaigreja.com.br',
      password: adminPassword,
      role: 'ADMIN',
    },
  });

  // Lider
  const leaderPassword = await bcrypt.hash('lider123', 12);
  const leader = await prisma.user.upsert({
    where: { email: 'lider@sistemaigreja.com.br' },
    update: {},
    create: {
      name: 'João Silva',
      email: 'lider@sistemaigreja.com.br',
      password: leaderPassword,
      role: 'LIDER',
    },
  });

  // Célula
  const cell = await prisma.cell.upsert({
    where: { leaderId: leader.id },
    update: {},
    create: {
      name: 'Célula Esperança',
      leaderId: leader.id,
      address: 'Rua das Flores, 123',
      neighborhood: 'Centro',
      city: 'São Paulo',
      dayOfWeek: 'quarta',
      time: '19:30',
      maxCapacity: 20,
      latitude: -23.5505,
      longitude: -46.6333,
    },
  });

  // Visitante de exemplo
  await prisma.visitor.upsert({
    where: { id: 'seed-visitor-1' },
    update: {},
    create: {
      id: 'seed-visitor-1',
      name: 'Maria Santos',
      phone: '(11) 99999-0001',
      email: 'maria@email.com',
      address: 'Av. Paulista, 500',
      neighborhood: 'Bela Vista',
      city: 'São Paulo',
      status: 'novo',
      leaderId: leader.id,
      cellId: cell.id,
    },
  });

  console.log('Seed concluído:', { admin: admin.email, leader: leader.email, cell: cell.name });
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
