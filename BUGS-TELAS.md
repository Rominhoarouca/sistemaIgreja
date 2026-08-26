# Bugs de tela — pendentes

**Última varredura:** 26/08/2026
**Ambientes:** iPhone 16 Pro (sim), Chrome 1440x900, iPad Air 11" (sim, 820x1180) e
**iPad de Romulo (aparelho físico, iOS 27)**.

> Rodada de correções de 26/08 concluída. Sobrou o que está abaixo.

> **Android sem cobertura.** A system image `android-35;google_apis_playstore;arm64-v8a` está
> incompleta e o emulador aborta com `No initial system image for this configuration!`. A proposta
> de layout de tablet vale igual para Android (é baseada em `MediaQuery`, não em plataforma), mas
> **não foi verificada em aparelho Android**.

---

## Em aberto

### 1. Área do KIDS e do RESPONSÁVEL sem layout próprio de tablet/desktop

O conteúdo dessas áreas agora tem largura máxima (não estica mais de ponta a ponta), mas continua
em **coluna única**. Num tablet em paisagem ou num monitor sobra espaço lateral ocioso.

Ganho possível: painel mestre-detalhe (lista de filhos/salas à esquerda, ficha à direita). É trabalho
de produto, não correção de bug.

### 2. Demografia com dados degenerados

**Onde:** ADMIN → Relatórios → Informações demográficas.

Homens 1 (0,3%), Mulheres 0 (0,0%), Não informado 358 (99,7%). É qualidade da massa de seed, não bug
de tela — mas a tela fica inútil numa demonstração.

---

## Corrigido nesta rodada

| # | Item | Verificação |
|---|---|---|
| 1 | Breakpoint de tablet: KPIs em 4 colunas no iPad (eram 2 gigantes) | ✅ visual, iPad sim |
| 2 | Largura máxima de conteúdo em KIDS/RESPONSÁVEL | ✅ visual |
| 3 | Salas homônimas: cor da sala + nomes dos professores no card | ✅ analyze |
| 4 | `403 /church/me` no SUPERADMIN (não chama mais) | ✅ analyze |
| 5 | `Zone mismatch` no boot (binding dentro do `runZonedGuarded`) | ✅ **0 no log do iPad físico** |

## Verificados e descartados (não são bugs)

Registrados para não voltarem à lista:

- **Sidebar "cortada" em paisagem** — ela **rola**: é `Expanded(child: ListView(...))` em
  `admin_sidebar.dart:301`. Falta só indicação visual de que há mais conteúdo abaixo.
- **AppBar branca no SUPERADMIN** — é **por design**. O laranja vem do `menuColor` da igreja
  (branding do tenant, via `applyChurchMenuColor`); o SUPERADMIN é cross-tenant e não tem igreja,
  então cai no tema padrão.
- **"Conteúdo cortado pela bottom nav"** — recorte normal de viewport; o padding já existe
  (`fromLTRB(..., 88)` nas listas, `100` no menu Mais).
- **"FAB cobrindo card"** — o card coberto não era o último; sobreposição durante a rolagem é
  comportamento padrão do Material.
- **Credenciais no login** — já dentro de `if (kDebugMode)` (`login_page.dart:37` e `:217`).
- **"Visitantes (mês) = 0"** — correto: dos 143 visitantes, o mês mais recente é `2026-07`.

---

## Proposta de layout para tablet (implementada)

`lib/design_system/layout/app_breakpoints.dart` passou a concentrar as faixas, que antes eram
números soltos (720, 900, 1024) espalhados por ~15 arquivos:

| Faixa | Largura | Comportamento |
|---|---|---|
| Telefone | < 720pt | Bottom nav, 2 colunas de KPI |
| Tablet | 720–1023pt | Bottom nav, **até 4 colunas** de KPI, conteúdo com largura máxima |
| Desktop | ≥ 1024pt | Sidebar fixa, 4 colunas |

**Por que 4 colunas já no tablet:** o card de indicador foi desenhado para ~185pt — a largura que ele
tem num telefone com 2 colunas. Num iPad de 820pt, 2 colunas dão 390pt por card, o dobro do previsto.
Subir para 4 devolve a densidade original. O que separa tablet de desktop é a moldura (sidebar), não
a densidade do grid.

`kpiColumns(context, itemCount:)` escolhe o maior número de colunas que divide a lista sem sobra —
4 cards viram uma linha de 4; 6 viram duas de 3. Sem isso, 4 cards numa grade de 3 deixavam o quarto
sozinho com dois buracos ao lado.

`AppContentWidth` centraliza e limita a coluna de conteúdo (840pt; 640pt em formulários).

**Vale para Android:** a decisão é por `MediaQuery.sizeOf().width`, sem checar plataforma. Tablets
Android de 10" ficam entre 800 e 1000pt em retrato, caindo na mesma faixa de tablet.

---

## Cobertura

| Perfil | iPhone sim | Chrome | iPad sim |
|---|---|---|---|
| SUPERADMIN | ✓ | ✓ | ✓ |
| ADMIN | ✓ | ✓ | ✓ |
| COORDENADOR | ✓ | ✓ | ✓ |
| SUPERVISOR | ✓ | ✓ | ✓ |
| LÍDER | ✓ | ✓ | ✓ |
| KIDS | ✓ | ✓ | ✓ |
| RESPONSÁVEL | ✓ | ✓ | ✓ |

**iPad de Romulo (físico):** build, instalação, execução e VM Service atachado (hot reload
funcionando por cabo). Log limpo — 0 overflow, 0 `Zone mismatch`, 0 asset faltando.
**Sem captura de tela:** `flutter screenshot` responde `Screenshot not supported` para iOS físico,
`devicectl` não tem o comando e o `idevicescreenshot` depende do DDI no formato antigo, que o iOS 27
não expõe. A confirmação visual saiu do simulador de mesma geometria.

**Não percorrido:** telas de detalhe/formulário, aba "Uso do Sistema" do SUPERADMIN, abas internas de
COORDENADOR/SUPERVISOR/LÍDER.

**Não verificado:** badge "Em casa" da ficha do filho — corrigido no backend
(`KidsController.getChild` devolve `openCheckin`), mas confirmar exige criança com check-in aberto.
