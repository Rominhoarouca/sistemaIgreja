#!/usr/bin/env node
// Registra UDIDs na conta Apple Developer via App Store Connect API.
//
//   node scripts/apple-devices.mjs udids.txt
//
// O arquivo é o exportado pelo Firebase (App Distribution → Testadores →
// Exportar UDIDs): TSV com cabeçalho `Device ID  Device Name  Device Platform`.
// Também aceita um UDID por linha.
//
// Credenciais (App Store Connect → Usuários e Acesso → Integrações → Chaves):
//   ASC_KEY_ID     ex.: 2X9R4HXF34
//   ASC_ISSUER_ID  ex.: 57246542-96fe-1a63-e053-0824d011072a
//   ASC_KEY_PATH   caminho do AuthKey_XXXXXXXX.p8
import { createSign } from 'node:crypto';
import { readFileSync } from 'node:fs';

const KEY_ID = process.env.ASC_KEY_ID;
const ISSUER_ID = process.env.ASC_ISSUER_ID;
const KEY_PATH = process.env.ASC_KEY_PATH;

const b64url = (buf) =>
  Buffer.from(buf).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

/** JWT ES256 exigido pela App Store Connect API. Vale no máximo 20 minutos. */
function makeToken() {
  const header = { alg: 'ES256', kid: KEY_ID, typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: ISSUER_ID,
    iat: now,
    exp: now + 15 * 60,
    aud: 'appstoreconnect-v1',
  };
  const unsigned = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;

  const signer = createSign('SHA256');
  signer.update(unsigned);
  // `ieee-p1363` devolve r||s, que é o formato do JOSE. O padrão do Node é
  // DER, que a Apple rejeita com 401 sem explicar o motivo.
  const sig = signer.sign(
    { key: readFileSync(KEY_PATH, 'utf8'), dsaEncoding: 'ieee-p1363' },
  );
  return `${unsigned}.${b64url(sig)}`;
}

/** Lê o TSV do Firebase ou uma lista simples de UDIDs. */
function parseUdids(path) {
  const linhas = readFileSync(path, 'utf8').split(/\r?\n/).filter((l) => l.trim());
  const saida = [];
  for (const linha of linhas) {
    if (/device\s*id/i.test(linha)) continue; // cabeçalho
    const campos = linha.split('\t').map((c) => c.trim());
    const udid = campos[0];
    // UDID de iOS: 40 hex (aparelhos antigos) ou 25 chars com hífen (modernos).
    if (!udid || !/^[0-9A-Fa-f-]{20,}$/.test(udid)) continue;
    saida.push({ udid, nome: campos[1] || `Tester ${udid.slice(0, 8)}` });
  }
  return saida;
}

async function registrar(token, { udid, nome }) {
  const res = await fetch('https://api.appstoreconnect.apple.com/v1/devices', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      data: { type: 'devices', attributes: { name: nome, platform: 'IOS', udid } },
    }),
  });

  if (res.ok) return 'registrado';

  const corpo = await res.json().catch(() => ({}));
  const erro = corpo?.errors?.[0];
  const detalhe = `${erro?.title ?? res.status} — ${erro?.detail ?? ''}`.trim();
  // Aparelho já cadastrado não é falha: o objetivo é que ele esteja lá.
  if (/already exists|already been taken/i.test(detalhe)) return 'já existia';
  throw new Error(detalhe);
}

async function main() {
  const arquivo = process.argv[2];
  if (!arquivo) {
    console.error('uso: node scripts/apple-devices.mjs <arquivo-de-udids>');
    process.exit(1);
  }
  if (!KEY_ID || !ISSUER_ID || !KEY_PATH) {
    console.error(
      'Faltam credenciais da App Store Connect API.\n' +
        '  ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH\n' +
        'Gere em App Store Connect → Usuários e Acesso → Integrações → Chaves,\n' +
        'com papel "App Manager" ou superior.',
    );
    process.exit(2);
  }

  const aparelhos = parseUdids(arquivo);
  if (aparelhos.length === 0) {
    console.error(`Nenhum UDID válido em ${arquivo}`);
    process.exit(1);
  }

  const token = makeToken();
  let novos = 0;
  let existentes = 0;

  for (const ap of aparelhos) {
    try {
      const r = await registrar(token, ap);
      if (r === 'registrado') novos += 1;
      else existentes += 1;
      console.log(`  ${ap.udid.slice(0, 12)}… ${ap.nome}: ${r}`);
    } catch (e) {
      console.error(`  ${ap.udid.slice(0, 12)}… ${ap.nome}: FALHOU — ${e.message}`);
    }
  }

  console.log(`\n${novos} novo(s), ${existentes} já cadastrado(s).`);
  // Só vale rebuildar se algo mudou — o perfil só muda com aparelho novo.
  process.exit(novos > 0 ? 0 : 3);
}

main().catch((e) => {
  console.error('FALHOU:', e.message);
  process.exit(1);
});
