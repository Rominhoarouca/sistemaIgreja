# Handoff: Redesign UI/UX — Sistema Igreja

## Overview
Redesign completo da interface do **Sistema Igreja** (repositório `Rominhoarouca/sistemaIgreja`, Flutter híbrido: web, tablet, iOS e Android). O redesign cobre **web desktop** e **mobile**, com direção visual "premium e sóbria" (azul profundo), modo **light e dark**, mantendo **todas as funcionalidades existentes** do app — apenas a camada de apresentação muda.

## About the Design Files
Os arquivos deste pacote são **referências de design criadas em HTML** (protótipos interativos que mostram aparência e comportamento pretendidos). **Não são código de produção para copiar.** A tarefa é **recriar estes designs no codebase Flutter existente**, usando os padrões já estabelecidos (BLoC/lógica, features em `lib/features/*`, tema em `design_system.dart`) — trocando apenas widgets/tema/layout.

- `Sistema Igreja.dc.html` — protótipo web desktop (Login, Dashboard e todas as telas internas + modais)
- `Sistema Igreja Mobile.dc.html` — protótipo mobile (Login, Dashboard com bottom-nav, Visitantes, menu "Mais", Cadastro público wizard)
- `assets/logo.png` — logo usado nos protótipos
- `support.js` — runtime dos protótipos (apenas para abrir os HTML; irrelevante para o Flutter)

Para visualizar: abra os `.dc.html` no navegador. A barra no topo alterna telas e o botão ☾/☀ alterna dark/light.

## Fidelity
**High-fidelity (hifi).** Cores, tipografia, espaçamentos, raios e estados são finais. Recriar pixel-perfect com os widgets/temas do Flutter.

## Design Tokens

### Cores — Light
| Token | Hex | Uso |
|---|---|---|
| primary | `#1E3A8A` | Botões primários, links, seleção, barras de gráfico |
| navy-900 | `#0B1530` | Sidebar (topo do gradiente), painéis de marca |
| navy-800 | `#122452` / `#101E42` | Gradientes do brand panel/sidebar |
| accent gold | `#E8A33D` | Destaques na sidebar/steppers (fundo escuro) |
| page bg | `#EEF0F4` | Fundo da página |
| surface | `#FFFFFF` | Cards, modais, topbar |
| surface-2 | `#F9FAFB` | Inputs de busca, fundos sutis |
| chip | `#EFF4FF` | Fundos de chips/ícones azuis, seleção |
| chip-2 | `#F5F8FF` | Linha selecionada, hover selecionado |
| border | `#E9ECF2` / `#E4E7EC` / `#D0D5DD` | Bordas de card / container / input |
| border-soft | `#F0F2F5` / `#F5F6F8` | Divisores internos |
| text | `#101828` | Títulos e texto principal |
| text-2 | `#344054` / `#475467` | Labels, texto secundário |
| text-3 | `#667085` | Texto terciário |
| muted | `#98A2B3` | Placeholders, metadados |
| success bg/fg | `#E7F6EF` / `#0E9F6E` | Badge "Integrado", barras |
| warning bg/fg | `#FDF3E1` / `#B54708` | Badge "Em acompanhamento" |
| inactive bg/fg | `#F2F4F7` / `#667085` | Badge "Não retornou" |
| danger | `#D92D20` | Asteriscos obrigatórios, excluir, sair |
| whatsapp | `#25D366` (hover `#1FB558`) | Botões de envio WhatsApp |
| roxo (coordenação Oeste) | `#6D46C7` | Cor de coordenação |

### Cores — Dark
| Token | Hex |
|---|---|
| page bg | `#0A101F` |
| surface | `#131C31` |
| surface-2 | `#0F1829` |
| chip / chip-2 | `#1D2F55` / `#1A2B4E` |
| link (primary em dark) | `#93B4FD` |
| accent border/botões | `#3E63DD` |
| text / text-2 / text-3 | `#F2F5FA` / `#C9D3E0` / `#97A5B8` |
| muted | `#697A92` |
| border / border-soft | `#283755` / `#1E2B45` |
| success bg/fg | `#0E3A2C` / `#57D9A3` |
| warning bg/fg | `#3F2D10` / `#F2C063` |
| inactive bg/fg | `#26303F` / `#AEB9C9` |
| barras de gráfico | `#5B8DEF` (total) / `#2FBE8F` (integrados) |

Painéis de marca (login/cadastro público) permanecem com o gradiente navy nos dois temas.

### Tipografia (Google Fonts)
- **Sora** — títulos, números de KPI, botões primários. Pesos 400–700. Letter-spacing levemente negativo em títulos grandes (−0.3 a −0.5px).
- **Instrument Sans** — corpo, labels, inputs. Pesos 400–600.
- Escala usada: 40px (hero login), 26–30px (títulos de tela / KPI), 17–19px (títulos de card/modal), 14–15px (corpo), 12.5–13.5px (labels/metadata), 11–12px (badges/uppercase section labels com letter-spacing 1–1.2px).

### Forma e espaçamento
- Raio: cards/modais 14–18px; inputs/botões 10–12px; chips/badges/avatars 999px (pill); frame externo 20px.
- Altura de inputs: 48–52px. Botões: 40–52px. Alvo mínimo mobile: 44px.
- Sombra de card: `0 1px 2px rgba(16,24,40,.04)`; modal: `0 24px 64px -12px rgba(0,0,0,.4)`.
- Espaçamentos: 7px label→input, 14–16px entre campos, 16–24px gaps de seção, padding de card 20–28px.
- Foco de input: borda `#1E3A8A` + halo `0 0 0 3px rgba(30,58,138,.12)`.

## Screens / Views — Web Desktop (`Sistema Igreja.dc.html`)

### Login
Split-screen: painel esquerdo 46% com gradiente navy (160°, `#0B1530→#122452→#1E3A8A`), logo, headline Sora 40px e tagline; painel direito com formulário 380px (E-mail, Senha, lembrar-me, esqueci a senha, botão Entrar `#1E3A8A` 52px, link para cadastro público de visitante).

### Dashboard (shell)
- **Sidebar 252px** com gradiente navy vertical, grupos com labels uppercase (Início / Pessoas / Células / Sistema), itens com ícone + label, item ativo com fundo `rgba(232,163,61,.14)`, contador dourado em "Visitantes", card do usuário no rodapé.
- **Topbar 68px**: título da página, busca 300px, botão "+ Novo visitante".
- Navegação da sidebar troca o conteúdo (estado `navActive`).

### Páginas internas (todas implementadas nos protótipos)
1. **Visão geral** — 4 KPIs (valor Sora 30px + delta pill verde/vermelho), lista "Visitantes recentes" (avatar com cor por status, célula, badge), "Funil de integração" (4 barras), "Células ativas" + botões "+ Nova Célula" / "+ Novo Líder".
2. **Visitantes** — busca ao vivo + filtros pill por status; tabela (Visitante/Telefone/Célula/Status) com linha selecionada (fundo `#F5F8FF` + barra 3px `#1E3A8A`); painel de detalhe à direita 340px: dados, "Ver no mapa →" (abre modal de mapa), atualizar status (chips), Enviar WhatsApp (verde), Converter em membro.
3. **Células** — grid 3 colunas de cards (nome, tipo, badge Ativa, líder, dia/hora, endereço, membros × capacidade, botões Membros/Editar), busca e "+ Nova Célula".
4. **Líderes** — busca nome/e-mail; cards com avatar colorido pela coordenação, badge de coordenação, contagem células/visitantes; painel de detalhe sticky com abas **Dados / Células / Visitantes**, descrição editável, "✎ Editar dados" e "↑ Promover a Supervisor". Aba Visitantes tem "Ver lista completa →" (modal com a lista).
5. **Supervisores** — grid de cards (coordenação, células, líderes supervisionados) com botão ✎ e "+ Novo Supervisor" (abre Novo Cadastro pré-selecionado).
6. **Coordenações** — cards com faixa vertical de cor identificadora, contagens, Editar, "+ Nova Coordenação".
7. **Novo Cadastro** — seletor de tipo em 3 cards (Líder/Supervisor/Coordenador); dois cards lado a lado: **Informações Pessoais** (nome, e-mail, telefone, senha temporária*) e **Dados de Endereço** (CEP, logradouro, número, complemento, estado*, cidade*, bairro*); associações por tipo com busca + checkboxes (Líder→células; Supervisor→líderes; Coordenador→líderes + supervisores + card Coordenação com "+ Criar Nova Coordenação"); botões full-width **✓ Salvar Cadastro** e **↺ Limpar Formulário**.
8. **Tipos de Célula** — lista com nome, descrição, contagem, Editar, "+ Novo Tipo".
9. **Cidades e Bairros** — abas segmentadas Cidades/Bairros; filtros por estado/cidade; listas com Editar; "+ Nova Cidade"/"+ Novo Bairro".
10. **WhatsApp** — abas **Em lote / Individual / Templates**. Em lote: grid 2×2 de segmentos selecionáveis. Individual: busca de destinatário. Ambas: linha "Usar template" (chips que preenchem a mensagem), textarea de mensagem, rodapé com botão verde "✈ Enviar mensagem". **Templates (CRUD)**: lista (nome, badge de categoria, prévia truncada, Usar/✎/✕) + modal Novo/Editar Template: nome, categoria (Geral/Boas-vindas/Convite), chips "Inserir variável" `{nome} {celula} {data} {horario} {bairro} {lider}` que inserem no texto, mensagem, **Preview ao vivo** (variáveis substituídas por dados de exemplo, caixa verde-claro), Salvar Template.
11. **Notificações** — feed com ícone colorido por tipo, não-lidas com fundo `#F5F8FF`, "Marcar todas como lidas".
12. **Relatórios/Indicadores** — 4 cards (Taxa de Integração, Líderes Ativos, Visitantes do mês, Média Frequência) + gráfico de barras duplas 6 meses (Total × Integrados) com legenda e "↓ Exportar relatório".
13. **Materiais** — dropzone dashed "Enviar novo material" + lista de PDFs com tamanho e "↓ Baixar".

### Modais (todos no protótipo desktop)
Padrão: overlay `rgba(11,21,48,.45)`, painel 440–580px raio 18px, header com título Sora 19px + ✕, rodapé com Cancelar/ação primária, toast verde de confirmação.
- **Novo Visitante** (topbar): nome*, telefone*, e-mail, endereço, bairro, cidade.
- **Nova Célula**: nome*, líder* (select), CEP auto-busca, logradouro*, mapa (placeholder), dia da semana, horário* (default 19:00), tipo opcional.
- **Nova Coordenação / Editar Coordenação**: nome* + 6 swatches de cor.
- **Editar Cidade / Bairro / Tipo de Célula / Célula / Supervisor / Líder** — campos pré-preenchidos e editáveis. Editar Líder inclui endereço, supervisor (select) e descrição (textarea); Editar Supervisor inclui endereço e coordenação.
- **Membros da célula**: lista com avatar + remover ✕, "+ Adicionar membro" (dashed), Concluir.
- **Ver lista completa**: visitantes do líder com badges de status.
- **Ver no mapa**: endereço + área de mapa (integrar Google Maps) + "Abrir no Google Maps ↗".
- **Novo/Editar Template WhatsApp** (descrito acima).

### Cadastro Público de Visitante (tela pública, sem login)
Fundo gradiente navy, logo + "Que alegria receber você!", **stepper de 3 passos** (dot dourado ativo): 
1. **Dados pessoais** — nome*, telefone/WhatsApp*, data de nascimento*, estado civil (opcional), e-mail (opcional).
2. **Endereço** — CEP com busca automática (ViaCEP), logradouro*, número*, complemento, estado/cidade/bairro (selects encadeados); nota de que o endereço localiza células próximas.
3. **Sobre você** — toggle "Deseja participar de alguma célula?" (quando ativo, lista células próximas com distância, selecionável) + **"Como posso ajudar você?"** com chips multi-seleção: *Membro da igreja, Procurando batismo, Quero ter uma célula em casa, Preciso de oração, Outros* (Outros abre campo livre). Manter exatamente estas opções — vêm do app atual.
Card branco central 620px, botões Voltar/Continuar/Concluir, confirmação verde ao enviar.

## Screens / Views — Mobile (`Sistema Igreja Mobile.dc.html`)
Frame 390×844. Regras: alvos ≥44px, conteúdo com padding 20px, bottom-nav 82px.
- **Login** — tela cheia com gradiente navy, inputs translúcidos (`rgba(255,255,255,.08)`, borda `.2`), botão Entrar branco sobre navy.
- **Dashboard** — header com saudação + sino (abre Notificações); KPIs em grid 2×2 (ícone em chip azul, valor Sora 26px); card de gráfico compacto; "Ações rápidas" (Nova Célula abre sheet de criação; Novo Líder abre Novo Cadastro); "Visitantes recentes".
- **Visitantes** — busca, filtros pill com scroll horizontal, cards de visitante; detalhe em **bottom-sheet** (grabber, dados, chips de status, WhatsApp + Converter).
- **Células** — lista de cards (nome, líder, dia, membros) + "+ Nova Célula"; toque abre sheet de edição.
- **Relatórios** — 4 KPIs em grid 2×2 + gráfico de barras Captação × Integração + Exportar.
- **Bottom-nav (5 itens)**: Início, Visitantes, Células, Relatórios, **Mais**. Esta é a solução para o excesso de atalhos do rodapé atual.
- **Menu "Mais"** — todos os itens navegam para telas próprias: **Líderes**, **Supervisores**, **Coordenações** (com "+ Nova"), **Novo Cadastro** (tipo Líder/Supervisor/Coordenador + Informações Pessoais + Endereço + Salvar), **Células**, **Tipos de Célula** (com "+ Novo"), **Materiais** (upload + lista), **WhatsApp** (abas Em lote/Individual/Templates com CRUD de templates em bottom-sheet, chips de variáveis e Preview), **Cidades e Bairros** (abas + "+ Nova Cidade"/"+ Novo Bairro"), **Configurações** (perfil, alternar tema, sair).
- **Edição em bottom-sheet genérica** — todas as listas (células, líderes, supervisores, coordenações, tipos, cidades, bairros) abrem uma folha inferior com campos pré-preenchidos editáveis (inputs/selects) e botão "✓ Salvar". Telas com back button (←) retornam ao menu Mais.
- **Notificações** — feed com não-lidas destacadas (fundo `#F5F8FF`), acessível pelo sino do Dashboard.
- **Cadastro público** — wizard 3 passos com barra de progresso dourada no header navy e card branco arredondado; mesmos campos e opções do desktop.

## Interactions & Behavior
- Sidebar/bottom-nav trocam página sem recarregar; item ativo destacado.
- Hovers: linhas de lista → `#F9FAFB`; botões primários `#1E3A8A → #16307A`; cards selecionáveis ganham borda `#1E3A8A`.
- Seleção (filtros, chips, segmentos, checkboxes): borda 1.5px `#1E3A8A` + fundo `#EFF4FF` + texto `#1E3A8A`.
- Modais fecham por ✕, Cancelar ou clique no overlay; salvar mostra toast verde (~2.6s).
- CEP dispara busca automática de endereço (ViaCEP) no cadastro público e Nova Célula.
- Templates WhatsApp: chips de variável inserem o token na posição do texto; preview substitui tokens por dados de exemplo em tempo real; "Usar" leva o texto para o composer.
- Dark mode: alternância global (persistir preferência do usuário).

## State Management
Manter a arquitetura atual do app (BLoC/controllers já existentes). O redesign não muda contratos de dados. Estados de UI novos: tema (light/dark), aba ativa do WhatsApp, template em edição, filtros/busca de listas, modal aberto, passo do wizard.

## Assets
- `assets/logo.png` — logo da igreja (fornecido pelo usuário).
- Ícones: os protótipos usam glifos unicode como placeholders — no Flutter, usar `Icons`/`lucide`/ícones do design system existente com o mesmo significado semântico.
- Mapas: placeholders hachurados nos protótipos → integrar o mapa real já usado pelo app (Google Maps).

## Mapeamento para o repositório Flutter
- Tema/tokens → `design_system.dart` (+ pastas `colors/`, `typography/`, `spacing/`, `shadows/`, `theme/`): criar `ThemeData` light e dark com os tokens acima; fontes via `google_fonts` (Sora, Instrument Sans).
- Cadastro público → `lib/features/visitor/presentation/pages/visitor_self_register_page.dart` (manter campos, validações e opções "Como posso ajudar você?").
- Sheets de criação → `lib/features/dashboard/presentation/pages/new_visitor_sheet.dart`, `new_cell_sheet.dart`, `new_leader_sheet.dart` (redesenhar como modais/sheets conforme protótipo).
- Telas admin → `lib/features/admin/presentation/pages/` (`admin_leaders_page.dart`, `admin_supervisors_page.dart`, `admin_coordenacoes_page.dart`, `admin_location_page.dart`, `admin_cell_types_page.dart`, `admin_users_register_page.dart`).
- WhatsApp → `lib/features/whatsapp/presentation/pages/admin_whatsapp_page.dart` (adicionar aba Templates com CRUD).
- Mobile: substituir o rodapé atual cheio de atalhos por bottom-nav de 5 itens + tela "Mais".

### Ordem sugerida de implementação
1. Tokens + ThemeData light/dark + fontes.
2. Shell (sidebar desktop / bottom-nav + tela "Mais" mobile).
3. Login e Cadastro público.
4. Dashboard e Visitantes.
5. Demais telas admin e modais.
6. WhatsApp Templates.
7. Revisão dark mode em todas as telas.

## Files
- `Sistema Igreja.dc.html` — referência web desktop (todas as telas e modais)
- `Sistema Igreja Mobile.dc.html` — referência mobile
- `assets/logo.png`
- `support.js` — runtime para abrir os protótipos no navegador
