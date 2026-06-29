import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

// ── Todos os estados brasileiros ──────────────────────────────────────────────
const ESTADOS = [
  { name: 'Acre',                 uf: 'AC' },
  { name: 'Alagoas',              uf: 'AL' },
  { name: 'Amapá',                uf: 'AP' },
  { name: 'Amazonas',             uf: 'AM' },
  { name: 'Bahia',                uf: 'BA' },
  { name: 'Ceará',                uf: 'CE' },
  { name: 'Distrito Federal',     uf: 'DF' },
  { name: 'Espírito Santo',       uf: 'ES' },
  { name: 'Goiás',                uf: 'GO' },
  { name: 'Maranhão',             uf: 'MA' },
  { name: 'Mato Grosso',          uf: 'MT' },
  { name: 'Mato Grosso do Sul',   uf: 'MS' },
  { name: 'Minas Gerais',         uf: 'MG' },
  { name: 'Pará',                 uf: 'PA' },
  { name: 'Paraíba',              uf: 'PB' },
  { name: 'Paraná',               uf: 'PR' },
  { name: 'Pernambuco',           uf: 'PE' },
  { name: 'Piauí',                uf: 'PI' },
  { name: 'Rio de Janeiro',       uf: 'RJ' },
  { name: 'Rio Grande do Norte',  uf: 'RN' },
  { name: 'Rio Grande do Sul',    uf: 'RS' },
  { name: 'Rondônia',             uf: 'RO' },
  { name: 'Roraima',              uf: 'RR' },
  { name: 'Santa Catarina',       uf: 'SC' },
  { name: 'São Paulo',            uf: 'SP' },
  { name: 'Sergipe',              uf: 'SE' },
  { name: 'Tocantins',            uf: 'TO' },
];

// ── Bairros de Juiz de Fora (IBGE) com lat/lng ────────────────────────────────
// Fonte: IBGE – Setores Censitários 2022 / Localidades de Juiz de Fora/MG
const BAIRROS_JF = [
  { name: 'Alto Grajaú',                lat: -21.7153, lng: -43.3558 },
  { name: 'Alto Mariano Procópio',       lat: -21.7552, lng: -43.3618 },
  { name: 'Pio X',                       lat: -21.7642, lng: -43.3560 },
  { name: 'Alphaville',                  lat: -21.7258, lng: -43.3955 },
  { name: 'Alto dos Passos',             lat: -21.7492, lng: -43.3508 },
  { name: 'Altolândia',                  lat: -21.7384, lng: -43.3892 },
  { name: 'Barbosa Lage',                lat: -21.7721, lng: -43.3453 },
  { name: 'Barreira do Triunfo',         lat: -21.7858, lng: -43.3561 },
  { name: 'Bairu',                       lat: -21.7701, lng: -43.3637 },
  { name: 'Bandeirantes',                lat: -21.7564, lng: -43.3733 },
  { name: 'Bela Aurora',                 lat: -21.7437, lng: -43.3453 },
  { name: 'Benfica',                     lat: -21.7524, lng: -43.3569 },
  { name: 'Bom Clima',                   lat: -21.7313, lng: -43.3822 },
  { name: 'Borboleta',                   lat: -21.8021, lng: -43.3431 },
  { name: 'Botanágua',                   lat: -21.7289, lng: -43.3740 },
  { name: 'Brasil',                      lat: -21.7618, lng: -43.3551 },
  { name: 'Brejal',                      lat: -21.7903, lng: -43.4034 },
  { name: 'Bom Pastor',                  lat: -21.7698, lng: -43.3485 },
  { name: 'Caetés',                      lat: -21.7612, lng: -43.3860 },
  { name: 'Cascatinha',                  lat: -21.7176, lng: -43.3789 },
  { name: 'Cerâmica',                    lat: -21.7798, lng: -43.3560 },
  { name: 'Centro',                      lat: -21.7622, lng: -43.3503 },
  { name: 'Cidade do Sol',               lat: -21.7892, lng: -43.3720 },
  { name: 'Cinco',                       lat: -21.7588, lng: -43.3568 },
  { name: 'Copacabana',                  lat: -21.7543, lng: -43.3663 },
  { name: 'Costa Carvalho',              lat: -21.7450, lng: -43.3560 },
  { name: 'Cruzeiro de Santo Antônio',   lat: -21.7711, lng: -43.3744 },
  { name: 'Democrata',                   lat: -21.7652, lng: -43.3441 },
  { name: 'Dom Bosco',                   lat: -21.7728, lng: -43.3501 },
  { name: 'Eldorado',                    lat: -21.7856, lng: -43.3662 },
  { name: 'Esplanada',                   lat: -21.7680, lng: -43.3503 },
  { name: 'Fábrica',                     lat: -21.7742, lng: -43.3474 },
  { name: 'Filgueiras',                  lat: -21.7482, lng: -43.3861 },
  { name: 'Floresta',                    lat: -21.7648, lng: -43.3593 },
  { name: 'Francisco Bernardino',        lat: -21.7569, lng: -43.3616 },
  { name: 'Grama',                       lat: -21.7891, lng: -43.3509 },
  { name: 'Grajaú',                      lat: -21.7221, lng: -43.3599 },
  { name: 'Granjas Betânia',             lat: -21.7403, lng: -43.4009 },
  { name: 'Granjas Triunfo',             lat: -21.7822, lng: -43.3518 },
  { name: 'Granbery',                    lat: -21.7630, lng: -43.3543 },
  { name: 'Graminha',                    lat: -21.7959, lng: -43.3508 },
  { name: 'Humaitá',                     lat: -21.7576, lng: -43.3646 },
  { name: 'Igrejinha',                   lat: -21.7726, lng: -43.3621 },
  { name: 'Inocentes',                   lat: -21.7803, lng: -43.3589 },
  { name: 'Ipiranga',                    lat: -21.7723, lng: -43.3441 },
  { name: 'Jardim Esperança',            lat: -21.7842, lng: -43.3635 },
  { name: 'Jardim da Lua',               lat: -21.7910, lng: -43.3614 },
  { name: 'Jardim Natal',                lat: -21.7866, lng: -43.3596 },
  { name: 'Jardim Cachoeira',            lat: -21.7813, lng: -43.3643 },
  { name: 'Jardim Glória',               lat: -21.7771, lng: -43.3718 },
  { name: 'Jardim Norte',                lat: -21.7462, lng: -43.3512 },
  { name: 'Jóquei Clube',                lat: -21.7506, lng: -43.3605 },
  { name: 'Ladeira',                     lat: -21.7728, lng: -43.3668 },
  { name: 'Linhares',                    lat: -21.7682, lng: -43.3672 },
  { name: 'Liberdade',                   lat: -21.7561, lng: -43.3500 },
  { name: 'Mariano Procópio',            lat: -21.7601, lng: -43.3643 },
  { name: 'Marilândia',                  lat: -21.7762, lng: -43.3691 },
  { name: 'Manoel Honório',              lat: -21.7668, lng: -43.3452 },
  { name: 'Monte Castelo',               lat: -21.7574, lng: -43.3455 },
  { name: 'Milho Branco',                lat: -21.7948, lng: -43.3574 },
  { name: 'Morro da Glória',             lat: -21.7682, lng: -43.3546 },
  { name: 'Morro do Imperador',          lat: -21.7549, lng: -43.3482 },
  { name: 'Mussurunga',                  lat: -21.7781, lng: -43.3537 },
  { name: 'Nova Era',                    lat: -21.7832, lng: -43.3681 },
  { name: 'Nogueira',                    lat: -21.7489, lng: -43.3730 },
  { name: 'Nossa Senhora Aparecida',     lat: -21.7744, lng: -43.3561 },
  { name: 'Nova Califórnia',             lat: -21.7871, lng: -43.3708 },
  { name: 'Novo Horizonte',              lat: -21.7854, lng: -43.3629 },
  { name: 'Olavo Costa',                 lat: -21.7748, lng: -43.3609 },
  { name: 'Paineiras',                   lat: -21.7501, lng: -43.3658 },
  { name: 'Parque Guarani',              lat: -21.7912, lng: -43.3663 },
  { name: 'Parque das Nações',           lat: -21.7768, lng: -43.3753 },
  { name: 'Parque Independência',        lat: -21.7901, lng: -43.3645 },
  { name: 'Parque São Clemente',         lat: -21.7880, lng: -43.3559 },
  { name: 'Poço Rico',                   lat: -21.7818, lng: -43.3499 },
  { name: 'Progresso',                   lat: -21.7681, lng: -43.3703 },
  { name: 'Represa',                     lat: -21.7834, lng: -43.3551 },
  { name: 'Residencial La Salle',        lat: -21.7248, lng: -43.3868 },
  { name: 'Retiro',                      lat: -21.7553, lng: -43.3729 },
  { name: 'Santa Catarina',              lat: -21.7658, lng: -43.3618 },
  { name: 'Santa Cruz',                  lat: -21.7732, lng: -43.3730 },
  { name: 'Santa Helena',                lat: -21.7618, lng: -43.3453 },
  { name: 'Santa Luzia',                 lat: -21.7588, lng: -43.3582 },
  { name: 'Santa Rita',                  lat: -21.7639, lng: -43.3500 },
  { name: 'Santa Terezinha',             lat: -21.7802, lng: -43.3695 },
  { name: 'Santo Antônio',               lat: -21.7662, lng: -43.3726 },
  { name: 'São Bernardo',                lat: -21.7742, lng: -43.3647 },
  { name: 'São Dimas',                   lat: -21.7792, lng: -43.3666 },
  { name: 'São Judas Tadeu',             lat: -21.7878, lng: -43.3626 },
  { name: 'São Mateus',                  lat: -21.7752, lng: -43.3499 },
  { name: 'São Benedito',                lat: -21.7713, lng: -43.3598 },
  { name: 'São Pedro',                   lat: -21.7561, lng: -43.3692 },
  { name: 'São Sebastião',               lat: -21.7651, lng: -43.3465 },
  { name: 'Saudade',                     lat: -21.7701, lng: -43.3592 },
  { name: 'Serrano',                     lat: -21.7552, lng: -43.3822 },
  { name: 'Teixeiras',                   lat: -21.7838, lng: -43.3598 },
  { name: 'Três Moinhos',                lat: -21.7428, lng: -43.3603 },
  { name: 'Trianon',                     lat: -21.7638, lng: -43.3481 },
  { name: 'Varginha',                    lat: -21.7778, lng: -43.3512 },
  { name: 'Vitorino Braga',              lat: -21.7748, lng: -43.3559 },
  { name: 'Vila Alpina',                 lat: -21.7858, lng: -43.3581 },
  { name: 'Vila Ideal',                  lat: -21.7812, lng: -43.3527 },
  { name: 'Vila Isabel',                 lat: -21.7768, lng: -43.3538 },
  { name: 'Vila Lélia',                  lat: -21.7793, lng: -43.3547 },
  { name: 'Vila Nova',                   lat: -21.7868, lng: -43.3570 },
  { name: 'Vilarinho',                   lat: -21.7673, lng: -43.3782 },
  { name: 'Vista Alegre',                lat: -21.7823, lng: -43.3560 },
];

async function main(): Promise<void> {
  console.log('Iniciando seed...');

  // ── 1. Criar todos os estados ─────────────────────────────────────────────
  console.log('Criando estados...');
  const estadoMap: Record<string, string> = {};

  for (const est of ESTADOS) {
    const estado = await prisma.estado.upsert({
      where: { uf: est.uf },
      update: { name: est.name },
      create: { name: est.name, uf: est.uf },
    });
    estadoMap[est.uf] = estado.id;
  }
  console.log(`${ESTADOS.length} estados criados/atualizados.`);

  // ── 2. Criar cidade de Juiz de Fora (MG) ─────────────────────────────────
  console.log('Criando cidade de Juiz de Fora...');
  const mgId = estadoMap['MG'];
  const juizDeFora = await prisma.cidade.upsert({
    where: { name_estadoId: { name: 'Juiz de Fora', estadoId: mgId } },
    update: { latitude: -21.7642, longitude: -43.3503 },
    create: {
      name: 'Juiz de Fora',
      estadoId: mgId,
      latitude: -21.7642,
      longitude: -43.3503,
    },
  });

  // Criar São Paulo/SP também (usado no seed de visitante de exemplo)
  const spId = estadoMap['SP'];
  const saoPaulo = await prisma.cidade.upsert({
    where: { name_estadoId: { name: 'São Paulo', estadoId: spId } },
    update: { latitude: -23.5505, longitude: -46.6333 },
    create: {
      name: 'São Paulo',
      estadoId: spId,
      latitude: -23.5505,
      longitude: -46.6333,
    },
  });

  // ── 3. Criar bairros de Juiz de Fora ─────────────────────────────────────
  console.log(`Criando ${BAIRROS_JF.length} bairros de Juiz de Fora...`);
  let bairroCount = 0;
  const bairroMap: Record<string, string> = {};

  for (const b of BAIRROS_JF) {
    const bairro = await prisma.bairro.upsert({
      where: { name_cidadeId: { name: b.name, cidadeId: juizDeFora.id } },
      update: { latitude: b.lat, longitude: b.lng },
      create: {
        name: b.name,
        cidadeId: juizDeFora.id,
        latitude: b.lat,
        longitude: b.lng,
      },
    });
    bairroMap[b.name] = bairro.id;
    bairroCount++;
  }
  console.log(`${bairroCount} bairros criados/atualizados.`);

  // Bairros de SP para o visitante de exemplo
  const centro = await prisma.bairro.upsert({
    where: { name_cidadeId: { name: 'Centro', cidadeId: saoPaulo.id } },
    update: {},
    create: { name: 'Centro', cidadeId: saoPaulo.id, latitude: -23.5489, longitude: -46.6388 },
  });

  const belaVista = await prisma.bairro.upsert({
    where: { name_cidadeId: { name: 'Bela Vista', cidadeId: saoPaulo.id } },
    update: {},
    create: { name: 'Bela Vista', cidadeId: saoPaulo.id, latitude: -23.5601, longitude: -46.6485 },
  });

  // ── 4. Usuários ───────────────────────────────────────────────────────────
  console.log('Criando usuários...');
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

  // ── 5. Célula de exemplo ──────────────────────────────────────────────────
  let cell = await prisma.cell.findFirst({ where: { leaderId: leader.id } });
  if (!cell) {
    cell = await prisma.cell.create({
      data: {
        name: 'Célula Esperança',
        leaderId: leader.id,
        address: 'Rua das Flores, 123',
        bairroId: centro.id,
        dayOfWeek: 'quarta',
        time: '19:30',
        maxCapacity: 20,
        latitude: -23.5505,
        longitude: -46.6333,
      },
    });
  }

  // ── 6. Visitante de exemplo ───────────────────────────────────────────────
  await prisma.visitor.upsert({
    where: { id: 'seed-visitor-1' },
    update: {},
    create: {
      id: 'seed-visitor-1',
      name: 'Maria Santos',
      phone: '(11) 99999-0001',
      email: 'maria@email.com',
      address: 'Av. Paulista, 500',
      bairroId: belaVista.id,
      status: 'novo',
      leaderId: leader.id,
      cellId: cell.id,
    },
  });

  console.log('✅ Seed concluído com sucesso!');
  console.log(`   - ${ESTADOS.length} estados`);
  console.log(`   - Juiz de Fora/MG com ${bairroCount} bairros`);
  console.log(`   - Usuários: ${admin.email}, ${leader.email}`);
  console.log(`   - Célula: ${cell.name}`);
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
