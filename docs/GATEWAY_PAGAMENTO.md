# Gateway de Pagamento — Recomendação para o SaaS Sistema Igreja

Este documento compara opções de gateway para cobrança recorrente (assinaturas de
planos) e recomenda uma escolha. O sistema suportará **duas formas**:

1. **Cobrança via gateway** (forma principal) — checkout + assinatura recorrente + webhooks.
2. **Atribuição manual** — o super-admin define/altera o plano de uma igreja sem
   passar pelo gateway (cortesia, contrato offline, testes).

A arquitetura abstrai o gateway atrás de uma interface (`IPaymentGateway`), então a
escolha abaixo pode ser trocada depois sem reescrever a lógica de negócio.

---

## Contexto que pesa na decisão

- **Público-alvo: igrejas no Brasil.** Meios de pagamento locais (PIX, boleto) são
  decisivos para conversão. Muitas igrejas não usam cartão internacional.
- **Cobrança recorrente mensal/anual** por plano.
- **Stack:** Node/TypeScript (Express) + Flutter (web/mobile). Precisa de SDK Node e
  webhooks.
- **Volume inicial baixo**, crescendo. Evitar custo fixo alto.

---

## Comparativo

| Critério | **Stripe** | **Mercado Pago** | **Asaas** | **Pagar.me** |
|---|---|---|---|---|
| PIX | ✅ (BR) | ✅ | ✅ | ✅ |
| Boleto | ✅ | ✅ | ✅ | ✅ |
| Cartão recorrente | ✅ (Billing/Subscriptions maduro) | ✅ (Preapproval) | ✅ | ✅ |
| Assinaturas nativas | ✅ Excelente (planos, trials, proration) | ⚠️ Ok (preapproval) | ✅ Boa | ✅ Boa |
| Webhooks | ✅ Robusto, assinado | ✅ | ✅ | ✅ |
| SDK Node oficial | ✅ Ótimo | ✅ | ⚠️ REST (SDK limitado) | ✅ |
| Docs | ✅ Referência do mercado | ⚠️ Média | ⚠️ Média | ✅ Boa |
| Taxas (aprox.)¹ | ~3.99% + R$0,39 cartão | PIX ~0,99%; cartão ~4,98% | PIX baixo; cartão competitivo | competitivo |
| Recebe em conta BR | ✅ (Stripe BR) | ✅ Nativo | ✅ Nativo | ✅ Nativo |
| Foco em SaaS/recorrência | ✅✅ | ⚠️ | ✅ (nichado BR) | ✅ |
| Antifraude incluso | ✅ Radar | ✅ | ✅ | ✅ |

¹ Taxas são aproximadas e mudam por negociação/volume. Confirmar no momento da integração.

---

## Recomendação

### Escolha principal: **Mercado Pago** (ou **Asaas**), com abstração para trocar

**Por quê Mercado Pago / Asaas em vez de Stripe:**

- **PIX é o fator decisivo no Brasil.** Igrejas convertem muito melhor com PIX/boleto
  do que com cartão. Mercado Pago e Asaas têm PIX recorrente e boleto nativos e baratos.
- **Recebimento local sem fricção** (conta brasileira, saque em BRL, suporte em pt-BR).
- **Asaas** é especialmente forte para cobrança recorrente B2B nacional (assinaturas,
  split, régua de inadimplência, notificação automática de boleto/PIX) — ótimo encaixe
  para "igreja paga mensalidade do sistema".

**Quando Stripe faz mais sentido:**

- Se houver intenção de vender para **fora do Brasil**, ou se a prioridade for a
  **melhor DX/documentação** e recursos de billing avançados (trials, proration,
  dunning, portal do cliente prontos). Stripe Billing é o mais maduro do mundo para SaaS.

### Estratégia sugerida

1. **Fase 1 (MVP de cobrança):** implementar `IPaymentGateway` + **atribuição manual**
   já funcionando. Isso destrava o produto sem depender do gateway.
2. **Fase 2:** integrar **um** gateway concreto. Recomendo **Asaas** ou **Mercado Pago**
   pelo PIX/boleto recorrente. Implementar `AsaasPaymentGateway`/`MercadoPagoPaymentGateway`
   como classe que satisfaz a interface.
3. **Fase 3 (opcional):** adicionar Stripe como segundo provider para clientes
   internacionais/cartão, selecionável por variável de ambiente.

---

## Interface de abstração (contrato)

```ts
// api/src/domain/billing/IPaymentGateway.ts
export interface CheckoutSessionInput {
  churchId: string;
  planId: string;
  billingCycle: 'MONTHLY' | 'YEARLY';
  successUrl: string;
  cancelUrl: string;
  customer: { name: string; email: string; taxId?: string /* CPF/CNPJ */ };
}

export interface CheckoutSessionResult {
  provider: string;              // 'asaas' | 'mercadopago' | 'stripe'
  externalSubscriptionId?: string;
  checkoutUrl: string;           // redireciona o cliente para pagar
}

export interface WebhookEvent {
  type: 'subscription.active' | 'subscription.past_due'
      | 'subscription.canceled' | 'payment.confirmed' | 'payment.failed';
  externalSubscriptionId?: string;
  externalCustomerId?: string;
  raw: unknown;
}

export interface IPaymentGateway {
  createCheckoutSession(input: CheckoutSessionInput): Promise<CheckoutSessionResult>;
  cancelSubscription(externalSubscriptionId: string): Promise<void>;
  verifyAndParseWebhook(headers: Record<string, string>, rawBody: Buffer): Promise<WebhookEvent>;
}
```

O banco guarda `provider`, `externalCustomerId`, `externalSubscriptionId` e `status`
na `Subscription` da igreja (ver `SAAS_PLANO.md`). Webhooks atualizam o `status`; a
atribuição manual escreve direto na tabela com `provider = 'manual'`.

---

## Variáveis de ambiente (a adicionar)

```
PAYMENT_PROVIDER=manual        # manual | asaas | mercadopago | stripe
PAYMENT_API_KEY=               # chave do provider escolhido
PAYMENT_WEBHOOK_SECRET=        # validação de assinatura do webhook
APP_PUBLIC_URL=                # base para success/cancel URLs
```

---

## Segurança (obrigatório na integração)

- **Validar assinatura do webhook** (HMAC/secret) antes de confiar no evento.
- **Idempotência**: guardar `event.id` já processado para não aplicar duas vezes.
- **Nunca** confiar em status vindo do cliente Flutter — só o webhook do gateway muda
  `Subscription.status`.
- Guardar apenas IDs externos e status; **não** armazenar dados de cartão (PCI fica no gateway).
