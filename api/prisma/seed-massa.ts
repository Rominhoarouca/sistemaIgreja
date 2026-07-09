/* eslint-disable no-console */
// ─────────────────────────────────────────────────────────────────────────────
// Seed de MASSA DE DADOS para testes — Sistema Igreja
//
// Regras atendidas:
//  • Endereços exclusivamente de Juiz de Fora/MG (bairros reais com lat/lng);
//  • Presenças de membros e visitantes de 08/07/2024 a 08/07/2026
//    (reuniões semanais no dia da célula, com CellMeeting + Attendance);
//  • Histórico espiritual (batismo, treinamento etc.);
//  • 5 visitantes vinculados em TODAS as células
//    + 5 visitantes SEM célula, porém em bairros onde existem células.
//
// Executar (após o seed base, que cria estados/JF/bairros):
//   npm --prefix api run seed          # base
//   npm --prefix api run seed:massa    # esta massa
//
// O script é idempotente: usuários por e-mail, células por nome+líder,
// reuniões por (cellId, meetingDate); seções já populadas são puladas.
// ─────────────────────────────────────────────────────────────────────────────

import { PrismaClient, DayOfWeek, VisitorStatus, SpiritualEventType } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

// ── Janela de presenças ───────────────────────────────────────────────────────
const PERIOD_START = new Date(Date.UTC(2024, 6, 8)); // 08/07/2024
const PERIOD_END = new Date(Date.UTC(2026, 6, 8)); // 08/07/2026

// ── Dimensões da massa ────────────────────────────────────────────────────────
const N_COORDENACOES = 2;
const SUPERVISORES_POR_COORD = 2;
const LIDERES_POR_SUPERVISOR = 3;
const CELULAS_POR_LIDER = 2; // 2×2×3×2 = 24 células
const MEMBROS_POR_CELULA = 8;
const VISITANTES_POR_CELULA = 5; // requisito
const VISITANTES_SEM_ = 5; // requisito

const SENHA_PADRAO = 'senha123';

// ── PRNG determinístico (massa reprodutível) ─────────────────────────────────
function mulberry32(seed: number): () => number {
  let a = seed;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rand = mulberry32(20240708);
const pick = <T>(arr: T[]): T => arr[Math.floor(rand() * arr.length)];
const chance = (p: number): boolean => rand() < p;
const between = (min: number, max: number): number =>
  min + Math.floor(rand() * (max - min + 1));

// ── Dados PT-BR ───────────────────────────────────────────────────────────────
const FIRST_NAMES = [
  'Ana', 'Beatriz', 'Bruno', 'Camila', 'Carlos', 'Cláudia', 'Daniel', 'Débora',
  'Eduardo', 'Elaine', 'Felipe', 'Fernanda', 'Gabriel', 'Gustavo', 'Helena',
  'Igor', 'Isabela', 'João', 'Juliana', 'Larissa', 'Leonardo', 'Letícia',
  'Lucas', 'Luana', 'Marcos', 'Mariana', 'Mateus', 'Natália', 'Otávio',
  'Patrícia', 'Paulo', 'Rafaela', 'Renato', 'Roberta', 'Rodrigo', 'Sara',
  'Sérgio', 'Simone', 'Thiago', 'Vanessa', 'Vinícius', 'Vitória', 'Wesley',
  'Yasmin',
];
const LAST_NAMES = [
  'Almeida', 'Barbosa', 'Cardoso', 'Carvalho', 'Costa', 'Dias', 'Ferreira',
  'Gomes', 'Lima', 'Lopes', 'Martins', 'Mendes', 'Moreira', 'Nascimento',
  'Oliveira', 'Pereira', 'Ribeiro', 'Rocha', 'Santos', 'Silva', 'Souza',
  'Teixeira', 'Vieira',
];
// Ruas reais de Juiz de Fora
const RUAS_JF = [
  'Av. Barão do Rio Branco', 'Av. Presidente Itamar Franco', 'Rua Halfeld',
  'Rua Santo Antônio', 'Av. Independência', 'Rua Espírito Santo',
  'Rua São Sebastião', 'Av. Getúlio Vargas', 'Rua Batista de Oliveira',
  'Rua Marechal Deodoro', 'Rua Santa Rita', 'Av. dos Andradas',
  'Rua Padre Café', 'Rua Morais e Castro', 'Av. Juiz de Fora',
  'Rua Olegário Maciel', 'Rua Floriano Peixoto', 'Rua Mister Moore',
  'Av. Sete de Setembro', 'Rua Manoel Bernardino',
];
const NOMES_CELULA = [
  'Esperança', 'Vida Nova', 'Restauração', 'Aliança', 'Ebenézer', 'Shalom',
  'Betel', 'Emanuel', 'Rocha Viva', 'Águas Vivas', 'Luz do Mundo', 'Boas Novas',
  'Videira', 'Semear', 'Renovo', 'Maranata', 'Peniel', 'Hermon', 'Gileade',
  'Cades', 'Horebe', 'Sinai', 'Jireh', 'Rafah',
];
const INTERESSES = [
  'Membro da igreja', 'Procurando batismo', 'Quero ter uma célula em casa',
  'Preciso de oração',
];
const DIAS: DayOfWeek[] = [
  DayOfWeek.segunda, DayOfWeek.terca, DayOfWeek.quarta, DayOfWeek.quinta,
  DayOfWeek.sexta, DayOfWeek.sabado,
];
const HORARIOS = ['19:00', '19:30', '20:00'];
const CORES_COORD = ['#6D46C7', '#0E9F6E', '#B54708', '#3E63DD'];

const DAY_INDEX: Record<DayOfWeek, number> = {
  domingo: 0, segunda: 1, terca: 2, quarta: 3, quinta: 4, sexta: 5, sabado: 6,
};

let personSeq = 0;
function personName(): string {
  personSeq++;
  return `${pick(FIRST_NAMES)} ${pick(LAST_NAMES)} ${pick(LAST_NAMES)}`;
}
function phone(): string {
  return `(32) 9${between(8000, 9999)}-${between(1000, 9999)}`;
}
function enderecoJF(): string {
  return `${pick(RUAS_JF)}, ${between(10, 2500)}`;
}
function dateBetween(start: Date, end: Date): Date {
  return new Date(start.getTime() + rand() * (end.getTime() - start.getTime()));
}

/** Todas as datas do dia-da-semana dentro da janela de presenças. */
function meetingDates(day: DayOfWeek): Date[] {
  const dates: Date[] = [];
  const d = new Date(PERIOD_START);
  while (d.getUTCDay() !== DAY_INDEX[day]) d.setUTCDate(d.getUTCDate() + 1);
  while (d <= PERIOD_END) {
    dates.push(new Date(d));
    d.setUTCDate(d.getUTCDate() + 7);
  }
  return dates;
}

async function upsertUser(opts: {
  name: string;
  email: string;
  role: 'LIDER' | 'SUPERVISOR' | 'COORDENADOR';
  hash: string;
  supervisorId?: string;
  coordenacaoId?: string;
  bairroNome: string;
}): Promise<string> {
  const user = await prisma.user.upsert({
    where: { email: opts.email },
    update: {
      role: opts.role,
      ...(opts.supervisorId ? { supervisorId: opts.supervisorId } : {}),
      ...(opts.coordenacaoId ? { coordenacaoId: opts.coordenacaoId } : {}),
    },
    create: {
      name: opts.name,
      email: opts.email,
      password: opts.hash,
      role: opts.role,
      phone: phone(),
      address: `${enderecoJF()} — ${opts.bairroNome}, Juiz de Fora/MG`,
      ...(opts.supervisorId ? { supervisorId: opts.supervisorId } : {}),
      ...(opts.coordenacaoId ? { coordenacaoId: opts.coordenacaoId } : {}),
    },
  });
  return user.id;
}

async function main(): Promise<void> {
  console.log('── Seed de massa — Sistema Igreja ──');
  console.log(`Janela de presenças: ${PERIOD_START.toISOString().slice(0, 10)} → ${PERIOD_END.toISOString().slice(0, 10)}`);

  // ── 0. Pré-requisito: Juiz de Fora + bairros (do seed base) ───────────────
  const mg = await prisma.estado.findUnique({ where: { uf: 'MG' } });
  if (!mg) throw new Error('Estado MG não encontrado — rode primeiro: npm run seed');
  const jf = await prisma.cidade.findUnique({
    where: { name_estadoId: { name: 'Juiz de Fora', estadoId: mg.id } },
  });
  if (!jf) throw new Error('Cidade Juiz de Fora não encontrada — rode primeiro: npm run seed');
  const bairros = await prisma.bairro.findMany({ where: { cidadeId: jf.id } });
  if (bairros.length < 10) {
    throw new Error('Bairros de Juiz de Fora insuficientes — rode primeiro: npm run seed');
  }
  console.log(`Bairros de JF disponíveis: ${bairros.length}`);

  const hash = await bcrypt.hash(SENHA_PADRAO, 10);

  // ── 0.5 Normalização: tudo que existir fora de JF passa a ser de JF ───────
  const bairroIdsJF = bairros.map((b) => b.id);
  const foraDeJF = { OR: [{ bairroId: null }, { bairroId: { notIn: bairroIdsJF } }] };

  const cellsFora = await prisma.cell.findMany({ where: foraDeJF, select: { id: true } });
  for (const c of cellsFora) {
    const b = pick(bairros);
    await prisma.cell.update({
      where: { id: c.id },
      data: {
        bairroId: b.id,
        address: `${enderecoJF()} — ${b.name}, Juiz de Fora/MG`,
        latitude: (b.latitude ?? -21.7642) + (rand() - 0.5) * 0.006,
        longitude: (b.longitude ?? -43.3503) + (rand() - 0.5) * 0.006,
      },
    });
  }

  const visitorsFora = await prisma.visitor.findMany({ where: foraDeJF, select: { id: true } });
  for (const v of visitorsFora) {
    const b = pick(bairros);
    await prisma.visitor.update({
      where: { id: v.id },
      data: { bairroId: b.id, address: enderecoJF() },
    });
  }

  const membersFora = await prisma.cellMember.findMany({ where: foraDeJF, select: { id: true } });
  for (const m of membersFora) {
    const b = pick(bairros);
    await prisma.cellMember.update({
      where: { id: m.id },
      data: { bairroId: b.id, address: enderecoJF() },
    });
  }
  if (cellsFora.length || visitorsFora.length || membersFora.length) {
    console.log(`Normalizados para JF: ${cellsFora.length} células, ${visitorsFora.length} visitantes, ${membersFora.length} membros.`);
  }

  // ── 1. Hierarquia: coordenações → supervisores → líderes ──────────────────
  const leaderIds: string[] = [];
  for (let c = 0; c < N_COORDENACOES; c++) {
    const coordUserId = await upsertUser({
      name: personName(),
      email: `coordenador${c + 1}@teste.igreja.com`,
      role: 'COORDENADOR',
      hash,
      bairroNome: pick(bairros).name,
    });

    const coordName = `Coordenação ${c === 0 ? 'Leste' : 'Oeste'} JF`;
    const existing = await prisma.coordenacao.findFirst({
      where: { coordinadorId: coordUserId },
    });
    const coordenacao =
      existing ??
      (await prisma.coordenacao.create({
        data: {
          name: coordName,
          color: CORES_COORD[c % CORES_COORD.length],
          coordinadorId: coordUserId,
        },
      }));

    for (let s = 0; s < SUPERVISORES_POR_COORD; s++) {
      const supId = await upsertUser({
        name: personName(),
        email: `supervisor${c * SUPERVISORES_POR_COORD + s + 1}@teste.igreja.com`,
        role: 'SUPERVISOR',
        hash,
        coordenacaoId: coordenacao.id,
        bairroNome: pick(bairros).name,
      });

      for (let l = 0; l < LIDERES_POR_SUPERVISOR; l++) {
        const idx =
          (c * SUPERVISORES_POR_COORD + s) * LIDERES_POR_SUPERVISOR + l + 1;
        const leaderId = await upsertUser({
          name: personName(),
          email: `lider${idx}@teste.igreja.com`,
          role: 'LIDER',
          hash,
          supervisorId: supId,
          bairroNome: pick(bairros).name,
        });
        leaderIds.push(leaderId);
      }
    }
  }
  console.log(`Hierarquia OK: ${N_COORDENACOES} coordenações, ${leaderIds.length} líderes.`);

  // ── 2. Tipos de célula ─────────────────────────────────────────────────────
  const tipoNomes = ['Família', 'Jovens', 'Casais', 'Mulheres', 'Homens'];
  const tipos: string[] = [];
  for (const nome of tipoNomes) {
    const t = await prisma.cellType.upsert({
      where: { name: nome },
      update: {},
      create: { name: nome, description: `Células de ${nome.toLowerCase()}` },
    });
    tipos.push(t.id);
  }

  // ── 3. Células (endereços 100% Juiz de Fora) ───────────────────────────────
  type CellInfo = { id: string; leaderId: string; day: DayOfWeek; bairroId: string };
  const cells: CellInfo[] = [];
  let cellSeq = 0;
  for (const leaderId of leaderIds) {
    for (let k = 0; k < CELULAS_POR_LIDER; k++) {
      const nome = `Célula ${NOMES_CELULA[cellSeq % NOMES_CELULA.length]}`;
      cellSeq++;
      const bairro = pick(bairros);
      const day = pick(DIAS);
      let cell = await prisma.cell.findFirst({
        where: { name: nome, leaderId },
      });
      if (!cell) {
        cell = await prisma.cell.create({
          data: {
            name: nome,
            leaderId,
            cellTypeId: pick(tipos),
            address: `${enderecoJF()} — ${bairro.name}, Juiz de Fora/MG`,
            bairroId: bairro.id,
            dayOfWeek: day,
            time: pick(HORARIOS),
            maxCapacity: between(15, 25),
            // ~±300 m em torno do centro do bairro
            latitude: (bairro.latitude ?? -21.7642) + (rand() - 0.5) * 0.006,
            longitude: (bairro.longitude ?? -43.3503) + (rand() - 0.5) * 0.006,
          },
        });
      }
      cells.push({ id: cell.id, leaderId, day: cell.dayOfWeek, bairroId: bairro.id });
    }
  }

  // Inclui também células pré-existentes (fora desta massa), para que TODAS
  // as células do banco recebam visitantes, membros e presenças.
  const known = new Set(cells.map((c) => c.id));
  const allCells = await prisma.cell.findMany({
    select: { id: true, leaderId: true, dayOfWeek: true, bairroId: true },
  });
  for (const c of allCells) {
    if (known.has(c.id)) continue;
    cells.push({
      id: c.id,
      leaderId: c.leaderId,
      day: c.dayOfWeek,
      bairroId: c.bairroId ?? pick(bairros).id,
    });
  }
  console.log(`Células OK: ${cells.length} (incluindo pré-existentes).`);

  // ── 4. Membros (8 por célula) ──────────────────────────────────────────────
  for (const cell of cells) {
    const count = await prisma.cellMember.count({ where: { cellId: cell.id } });
    if (count >= MEMBROS_POR_CELULA) continue;
    await prisma.cellMember.createMany({
      data: Array.from({ length: MEMBROS_POR_CELULA - count }, () => ({
        cellId: cell.id,
        leaderId: cell.leaderId,
        name: personName(),
        phone: phone(),
        email: `membro${++personSeq}@teste.igreja.com`,
        address: enderecoJF(),
        bairroId: pick(bairros).id,
      })),
    });
  }
  const totalMembers = await prisma.cellMember.count();
  console.log(`Membros OK (total no banco: ${totalMembers}).`);

  // ── 5. Visitantes: 5 por célula ────────────────────────────────────────────
  const statuses: VisitorStatus[] = [
    VisitorStatus.novo,
    VisitorStatus.em_acompanhamento,
    VisitorStatus.em_acompanhamento,
    VisitorStatus.integrado,
    VisitorStatus.inativo,
  ];
  for (const cell of cells) {
    const count = await prisma.visitor.count({ where: { cellId: cell.id } });
    if (count >= VISITANTES_POR_CELULA) continue;
    for (let i = count; i < VISITANTES_POR_CELULA; i++) {
      const createdAt = dateBetween(PERIOD_START, PERIOD_END);
      await prisma.visitor.create({
        data: {
          name: personName(),
          phone: phone(),
          email: `visitante${++personSeq}@teste.igreja.com`,
          address: enderecoJF(),
          numero: String(between(10, 999)),
          bairroId: cell.bairroId, // mesmo bairro da célula (JF)
          birthDate: dateBetween(new Date('1960-01-01'), new Date('2008-01-01')),
          maritalStatus: pick(['Solteiro(a)', 'Casado(a)', 'União estável']),
          isBaptized: chance(0.3),
          interests: [pick(INTERESSES)],
          status: statuses[i % statuses.length],
          leaderId: cell.leaderId,
          cellId: cell.id,
          createdAt,
        },
      });
    }
  }
  console.log('Visitantes por célula OK (5 em cada).');

  // ── 6. Visitantes SEM célula, próximos às células ─────────────────────────
  // "Próximo" = mesmo bairro de uma célula existente (bairros de JF com célula).
  const bairrosComCelula = Array.from(new Set(cells.map((c) => c.bairroId)));
  const semCelulaCount = await prisma.visitor.count({
    where: { cellId: null, email: { endsWith: '@semcelula.igreja.com' } },
  });
  for (let i = semCelulaCount; i < VISITANTES_SEM_CELULA; i++) {
    await prisma.visitor.create({
      data: {
        name: personName(),
        phone: phone(),
        email: `visitante.livre${i + 1}@semcelula.igreja.com`,
        address: enderecoJF(),
        numero: String(between(10, 999)),
        bairroId: pick(bairrosComCelula),
        birthDate: dateBetween(new Date('1960-01-01'), new Date('2008-01-01')),
        maritalStatus: pick(['Solteiro(a)', 'Casado(a)']),
        interests: [pick(INTERESSES), 'Preciso de oração'],
        status: VisitorStatus.novo,
        createdAt: dateBetween(PERIOD_START, PERIOD_END),
      },
    });
  }
  console.log(`Visitantes sem célula OK (${VISITANTES_SEM_CELULA}, em bairros com células).`);

  // ── 7. Reuniões semanais + presenças (08/07/2024 → 08/07/2026) ────────────
  console.log('Gerando reuniões e presenças (pode levar alguns segundos)...');
  let meetingsCreated = 0;
  let attendancesCreated = 0;

  for (const cell of cells) {
    const dates = meetingDates(cell.day);

    // Reuniões (unique cellId+meetingDate → skipDuplicates torna idempotente)
    const res = await prisma.cellMeeting.createMany({
      data: dates.map((d) => ({
        cellId: cell.id,
        meetingDate: d,
        createdById: cell.leaderId,
      })),
      skipDuplicates: true,
    });
    meetingsCreated += res.count;

    // Presenças: pula célula que já tem presenças na janela (idempotência)
    const existing = await prisma.attendance.count({
      where: {
        cellId: cell.id,
        meetingDate: { gte: PERIOD_START, lte: PERIOD_END },
      },
    });
    if (existing > 0) continue;

    const members = await prisma.cellMember.findMany({
      where: { cellId: cell.id },
      select: { id: true },
    });
    const visitors = await prisma.visitor.findMany({
      where: { cellId: cell.id },
      select: { id: true, createdAt: true, status: true },
    });

    const rows: {
      cellId: string;
      meetingDate: Date;
      memberId?: string;
      visitorId?: string;
      isPresent: boolean;
    }[] = [];

    for (const date of dates) {
      // Membros: ~85% de presença
      for (const m of members) {
        rows.push({
          cellId: cell.id,
          meetingDate: date,
          memberId: m.id,
          isPresent: chance(0.85),
        });
      }
      // Visitantes: presença a partir do cadastro; frequência varia por status
      for (const v of visitors) {
        if (date < v.createdAt) continue;
        const p = v.status === 'integrado' ? 0.8
          : v.status === 'em_acompanhamento' ? 0.55
          : v.status === 'inativo' ? 0.1
          : 0.4;
        rows.push({
          cellId: cell.id,
          meetingDate: date,
          visitorId: v.id,
          isPresent: chance(p),
        });
      }
    }

    // Insere em lotes de 2000
    for (let i = 0; i < rows.length; i += 2000) {
      const res2 = await prisma.attendance.createMany({
        data: rows.slice(i, i + 2000),
      });
      attendancesCreated += res2.count;
    }
  }
  console.log(`Reuniões criadas: ${meetingsCreated}. Presenças criadas: ${attendancesCreated}.`);

  // ── 8. Histórico espiritual ────────────────────────────────────────────────
  const allVisitors = await prisma.visitor.findMany({
    where: { cellId: { not: null } },
    select: { id: true, createdAt: true, leaderId: true, status: true, isBaptized: true },
  });
  let histCreated = 0;
  for (const v of allVisitors) {
    if (!v.leaderId) continue;
    const has = await prisma.spiritualHistory.count({ where: { visitorId: v.id } });
    if (has > 0) continue;

    const events: { type: SpiritualEventType; date: Date; desc: string }[] = [];
    const base = v.createdAt > PERIOD_END ? PERIOD_START : v.createdAt;

    // ~50% enviados ao batismo; batizados 30 dias depois quando isBaptized
    if (chance(0.5) || v.isBaptized) {
      const d1 = dateBetween(base, PERIOD_END);
      events.push({
        type: SpiritualEventType.enviado_batismo,
        date: d1,
        desc: 'Encaminhado para a turma de batismo',
      });
      if (v.isBaptized) {
        const d2 = new Date(d1);
        d2.setUTCDate(d2.getUTCDate() + 30);
        events.push({
          type: SpiritualEventType.batizado,
          date: d2 > PERIOD_END ? PERIOD_END : d2,
          desc: 'Batizado nas águas',
        });
      }
    }
    // Integrados: trilha de liderança
    if (v.status === 'integrado' && chance(0.6)) {
      const d3 = dateBetween(base, PERIOD_END);
      events.push({
        type: SpiritualEventType.enviado_treinamento_lider,
        date: d3,
        desc: 'Iniciou o treinamento de líderes',
      });
      if (chance(0.5)) {
        const d4 = new Date(d3);
        d4.setUTCDate(d4.getUTCDate() + 60);
        events.push({
          type: SpiritualEventType.concluiu_treinamento,
          date: d4 > PERIOD_END ? PERIOD_END : d4,
          desc: 'Concluiu o treinamento de líderes',
        });
      }
    }

    if (events.length === 0) continue;
    await prisma.spiritualHistory.createMany({
      data: events.map((e) => ({
        visitorId: v.id,
        eventType: e.type,
        description: e.desc,
        date: e.date,
        recordedById: v.leaderId!,
      })),
    });
    histCreated += events.length;
  }
  console.log(`Histórico espiritual OK (${histCreated} eventos novos).`);

  // ── Resumo ─────────────────────────────────────────────────────────────────
  const resumo = {
    coordenacoes: await prisma.coordenacao.count(),
    supervisores: await prisma.user.count({ where: { role: 'SUPERVISOR' } }),
    lideres: await prisma.user.count({ where: { role: 'LIDER' } }),
    celulas: await prisma.cell.count(),
    membros: await prisma.cellMember.count(),
    visitantes: await prisma.visitor.count(),
    reunioes: await prisma.cellMeeting.count(),
    presencas: await prisma.attendance.count(),
    historicos: await prisma.spiritualHistory.count(),
  };
  console.log('── Resumo do banco ──');
  console.table(resumo);
  console.log(`Login de teste: lider1@teste.igreja.com / ${SENHA_PADRAO}`);
  console.log(`               supervisor1@teste.igreja.com / ${SENHA_PADRAO}`);
  console.log(`               coordenador1@teste.igreja.com / ${SENHA_PADRAO}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
