# Envio de Mensagens em Lote via WhatsApp — Ferramentas e Estratégia

Documento de decisão para o recurso **WhatsApp** do Sistema Igreja (SaaS
multi-tenant; hoje liberado no plano **COMPLETE**). Cobre as opções técnicas,
riscos, conformidade (LGPD + políticas do WhatsApp) e uma recomendação de
arquitetura que se encaixa no modelo por igreja (`churchId`).

> **Aviso importante:** o WhatsApp **proíbe** disparo não solicitado (spam). O uso
> correto exige **opt-in** (consentimento do contato) e, para mensagens iniciadas
> pela igreja fora da janela de 24h, **templates aprovados**. Ignorar isso leva a
> **banimento do número** e risco jurídico (LGPD). A estratégia abaixo assume envio
> a membros/visitantes que consentiram.

---

## 1. As três famílias de solução

| Abordagem | Exemplos | Legal/estável? | Custo | Esforço |
|---|---|---|---|---|
| **API Oficial (Cloud API)** | Meta Cloud API, via BSP: Twilio, 360dialog, Gupshup, Zenvia, Infobip | ✅ Oficial, sem risco de ban | Por conversa/template | Médio |
| **Gateways "não oficiais" gerenciados** | Z-API, Evolution API (self-host), UltraMsg, Chat-API | ⚠️ Usam WhatsApp Web por baixo; risco de ban menor que DIY, mas existe | Mensalidade fixa | Baixo |
| **Bibliotecas DIY (WhatsApp Web)** | Baileys, whatsapp-web.js, Venom, WPPConnect | ❌ Não oficial; **alto risco de ban**; TOS-violation | "Grátis" (infra) | Alto (manutenção) |

### 1.1 API Oficial — Meta Cloud API (via BSP)
- **O que é:** API oficial do WhatsApp Business Platform. Você fala com a Meta
  direto (Cloud API) ou por um **BSP** (Business Solution Provider) que simplifica
  onboarding, cobrança e número.
- **Prós:** sem risco de banimento por uso legítimo; suporta **templates**,
  **mídia**, **botões**, webhooks de status (entregue/lido), múltiplos números.
- **Contras:** exige número dedicado verificado, aprovação de templates (24–48h),
  cobrança **por conversa** (categorias: marketing/utility/authentication/service).
- **Melhor para:** SaaS sério, multi-igreja, que quer escalar sem risco.

### 1.2 Gateways gerenciados (Z-API, Evolution API, UltraMsg)
- **O que é:** serviços que expõem uma API REST simples e mantêm a sessão do
  WhatsApp Web por baixo. **Evolution API** é open-source e self-hostável (encaixa
  no `docker-compose` atual).
- **Prós:** integração rápida (REST + QR code), sem burocracia de template, barato,
  usa o **número comum** da igreja (WhatsApp normal).
- **Contras:** tecnicamente fora do TOS oficial → **risco de bloqueio do número**,
  especialmente em disparo em massa. Instabilidade quando o WhatsApp muda o Web.
- **Melhor para:** MVP, igrejas pequenas, volume baixo/moderado com opt-in.

### 1.3 DIY (Baileys / whatsapp-web.js)
- Só faz sentido se você quiser controle total e aceitar manter a infra + risco.
  **Não recomendado** para produto pago — instabilidade e ban derrubam o recurso
  para o cliente.

---

## 2. Recomendação para o Sistema Igreja

### Estratégia em 2 camadas (abstração por provider)

Assim como o billing (`IPaymentGateway`), abstrair o WhatsApp atrás de uma
interface `IWhatsappProvider` e escolher a implementação por variável de ambiente /
por igreja. Isso permite começar simples e migrar sem reescrever a lógica.

1. **Fase 1 (MVP):** **Evolution API** (self-host no `docker-compose`) — rápido,
   barato, cada igreja conecta o próprio número por QR code. Bom para validar o
   recurso com volume controlado + opt-in.
2. **Fase 2 (escala/segurança):** **Meta Cloud API via BSP** (360dialog ou Gupshup
   têm bom custo no Brasil) para igrejas do plano COMPLETE que querem volume alto
   sem risco de ban. Selecionável por plano/igreja.

> **Por quê as duas:** o disparo em massa "de verdade" (campanhas, avisos a
> centenas de membros) é seguro só na API oficial. Mas o oficial tem fricção de
> onboarding — Evolution destrava o recurso já, para quem topa o risco.

---

## 3. Interface de abstração (contrato sugerido)

```ts
// api/src/domain/whatsapp/IWhatsappProvider.ts
export interface WhatsappRecipient {
  phone: string;          // E.164, ex: +5511999999999
  variables?: Record<string, string>; // p/ personalização ({{nome}})
}

export interface SendBatchInput {
  churchId: string;
  templateName?: string;  // obrigatório na API oficial fora da janela 24h
  body?: string;          // texto livre (gateways não-oficiais / dentro da janela)
  mediaUrl?: string;
  recipients: WhatsappRecipient[];
}

export interface SendResult {
  phone: string;
  status: 'queued' | 'sent' | 'failed';
  providerMessageId?: string;
  error?: string;
}

export interface IWhatsappProvider {
  readonly name: string;                 // 'evolution' | 'cloud_api'
  sendBatch(input: SendBatchInput): Promise<SendResult[]>;
  // webhook de status (entregue/lido/falha) atualiza o histórico de envio
  parseStatusWebhook(headers: Record<string, string>, body: Buffer): Promise<unknown>;
}
```

Cada igreja guarda sua config (número/instância/token) numa tabela
`WhatsappConfig (churchId, provider, instanceId, apiKey, phoneNumberId, ...)`,
respeitando o isolamento multi-tenant já existente.

---

## 4. Envio em lote — como fazer certo (fila + rate limit)

Disparo em massa **não** deve ser um loop síncrono no request. Padrão recomendado:

1. **Enfileirar**, não enviar na hora. Criar um **job/fila** (ex.: BullMQ + Redis,
   ou tabela `MessageQueue` + worker cron) por lote.
2. **Rate limiting / throttling:** enviar com intervalo (ex.: 1–3 msg/s por número)
   e jitter aleatório. Massa "instantânea" é o que mais queima número em gateway
   não-oficial. Na Cloud API respeitar os **tiers** de mensagens da Meta.
3. **Idempotência + retry:** guardar status por destinatário; reprocessar falhas com
   backoff.
4. **Warm-up do número:** número novo começa com volume baixo e sobe gradualmente.
5. **Personalização:** usar variáveis (`{{nome}}`) — mensagem idêntica em massa é
   sinal de spam.
6. **Registro de envio:** persistir campanha + destinatários + status (entregue/
   lido/falha) para relatório e reenvio. Encaixa como um módulo `WhatsappCampaign`
   tenant-scoped.

### Esboço de arquitetura

```
[Admin da igreja]
   │  seleciona público (membros/visitantes filtrados por célula, status…)
   ▼
[POST /v1/whatsapp/campaigns]  → cria Campaign + enfileira destinatários
   ▼
[Worker/Fila]  → throttle 1–3/s → IWhatsappProvider.sendBatch()
   ▼
[Webhook de status]  → atualiza CampaignRecipient (sent/delivered/read/failed)
   ▼
[Relatório de campanha no painel]
```

---

## 5. Conformidade — obrigatório

- **Opt-in explícito:** só enviar a quem consentiu receber mensagens da igreja.
  Guardar data/origem do consentimento (prova para LGPD).
- **Opt-out:** toda mensagem de campanha deve permitir "sair"/"não quero mais".
  Respeitar imediatamente (flag no contato).
- **Templates (API oficial):** mensagens iniciadas pela igreja fora da janela de 24h
  exigem template aprovado pela Meta, na categoria correta (utility vs marketing).
- **LGPD:** dados pessoais (telefone) — base legal = consentimento; permitir exclusão;
  não compartilhar entre igrejas (o isolamento por `churchId` já garante isso).
- **Política do WhatsApp:** nada de listas compradas, nada de spam. Violação =
  banimento do número, sem recurso rápido.

---

## 6. Comparativo rápido de custo (aprox., BR)

| Solução | Modelo de custo | Ordem de grandeza |
|---|---|---|
| Meta Cloud API (via BSP) | por conversa iniciada (24h) | utility ~R$0,03–0,08; marketing ~R$0,10–0,30 |
| 360dialog / Gupshup (BSP) | fee mensal + custo Meta | fee baixo + repasse Meta |
| Evolution API (self-host) | infra (seu servidor) | ~custo do container; "grátis" de licença |
| Z-API / UltraMsg | mensalidade por número | ~R$50–100/número/mês |

Valores mudam; confirmar no momento da integração.

---

## 7. Decisão sugerida (resumo)

- **Agora:** integrar **Evolution API** (self-host, encaixa no docker-compose) atrás
  de `IWhatsappProvider`, com **fila + throttle + opt-in/opt-out** e registro de
  campanhas por igreja. Recurso do plano COMPLETE (já gated).
- **Depois:** adicionar **Meta Cloud API (via 360dialog/Gupshup)** como provider
  alternativo para volume alto sem risco de ban, selecionável por igreja.
- **Nunca:** disparo síncrono sem fila, sem opt-in, ou com número recém-criado em
  volume alto — é o caminho direto para o banimento.
```
