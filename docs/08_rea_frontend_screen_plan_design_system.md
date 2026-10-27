# REA dos 12 Sites de Análise Financeira & Plano Diretor de Telas (Design System Futurista)

**Projeto:** `fin-web` (`https://github.com/barrosrafa/fin-web`)  
**Repositórios Relacionados:** `fin-db` (PostgreSQL 18/TimescaleDB), `fin-api` (FastAPI), `fin-ingestion` (Python/Prefect), `fin-infra`  
**Data:** 2026-10-26  
**Status:** Aprovado para Implementação em Next.js (App Router, React 19, TypeScript, Zod, Pure CSS Layout)  

---

## 1. Engenharia Reversa (REA) dos 12 Portais de Análise Financeira

Abaixo está o mapeamento detalhado dos 12 maiores portais brasileiros de análise de investimentos, extraindo seus pontos fortes únicos, falhas de UX, payloads de dados e diferenciais que foram incorporados e aperfeiçoados no `fin-web`:

```
┌───────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   OS 12 PORTAIS ANALISADOS                                    │
├─────────────────────┬─────────────────────┬─────────────────────┬─────────────────────────────┤
│ 1. Status Invest    │ 2. Investidor10     │ 3. Fundamentei      │ 4. Fundamentus              │
│ 5. Clube FII        │ 6. Funds Explorer   │ 7. FIIs.com.br      │ 8. Mais Retorno             │
│ 9. Análise de Ações │ 10. Brick360        │ 11. ADVFN Brasil    │ 12. ETFs Brasil             │
└─────────────────────┴─────────────────────┴─────────────────────┴─────────────────────────────┘
```

---

### S01. Status Invest (`statusinvest.com.br`)
* **Superpoderes:**
  - Séries históricas de 5 a 10 anos de DRE (`/acao/getdre`) e Fluxo de Caixa (`/acao/getfluxocaixa`).
  - Monitoramento de aluguel de ações (BTC) com taxas de tomador/doador e % do free float alugado.
  - Grade completa de derivativos/opções com gregas (Delta, Gamma, Theta, Vega) e preços teóricos Black-Scholes.
  - Carteira detalhada de CRIs de FIIs com indexadores e garantias.
* **Falhas de UX / Design Antigo:**
  - Layout denso e poluído com excesso de banners de anúncios agressivos.
  - Visual cinza/azul corporativo datado (ASP.NET clássico), sem animações de transição.
  - Responsividade móvel frágil em tabelas financeiras longas.
* **Inovações Adotadas no `fin-web`:**
  - DRE e DFC interativas com modo de cascata (waterfall) e drill-down em SVG puro.
  - Monitor de Aluguel de Ações (BTC) e Termo com gráfico de pressão vendedora.
  - Matriz de Opções e Volatilidade Implícita com heatmaps futuristas.

---

### S02. Investidor10 (`investidor10.com.br`)
* **Superpoderes:**
  - "Checklist do Investidor" (6 critérios objetivos para Buy & Hold com badges visuais).
  - Decomposição de receita por segmento de negócio e por geografia (`companyRevenues` e `companyBussinesRevenues`).
  - Mapa anual de dividendos com grade mês a mês e proventos pagos vs. provisionados.
  - Comparação instantânea com as médias do setor.
* **Falhas de UX:**
  - Excesso de paywalls ("Assine o Pro para ver mais de 3 anos").
  - Animações genéricas em Chart.js sem física de movimento suave.
* **Inovações Adotadas no `fin-web`:**
  - Checklist Dinâmico com radar de conformidade de 6 a 10 pilares.
  - Gráfico de Decomposição de Receita (Segmentos & Geografia) em SVG nativo.
  - Mapa de Calor de Proventos Mensais com projeção de renda passiva futura.

---

### S03. Fundamentei (`fundamentei.com`)
* **Superpoderes:**
  - Visão ultra-longo prazo (15 a 20+ anos de balanços anuais normalizados).
  - KPIs operacionais específicos por setor (BOE/dia para petróleo, celulose/ton, SSS para varejo).
  - Integração de governança com diretores, conselheiros, remuneração e notas do Reclame Aqui.
* **Falhas de UX:**
  - Muito minimalista a ponto de esconder informações vitais para quem opera no curto/médio prazo.
  - Falta de ferramentas avançadas de screening e cálculo de múltiplos técnicos.
* **Inovações Adotadas no `fin-web`:**
  - Timeline de Longo Prazo com toggle Anual / Trimestral / LTM (Last Twelve Months).
  - Bloco de KPIs Operacionais Customizados por Setor CVM.
  - Painel de Governança e Reputação com árvore hierárquica societária.

---

### S04. Fundamentus (`fundamentus.com.br`)
* **Superpoderes:**
  - Velocidade bruta de screening (tabela completa de todas as ações e FIIs da bolsa com dezenas de múltiplos).
  - Transparência de dados contábeis em formato tabular conciso sem ruído visual.
  - Detalhamento de programas de recompra e negociações de insiders.
* **Falhas de UX:**
  - Design estático dos anos 2000 (PHP puro, tabelas HTML sem estilo moderno, sem gráficos interativos).
  - Não responsivo em smartphones.
* **Inovações Adotadas no `fin-web`:**
  - "Super Screener Ultra-Rápido" com renderização virtualizada, 30+ filtros em tempo real e exportação instantânea.
  - Cards de Programas de Recompra e Insiders (Compras/Vendas de controladores).

---

### S05. Clube FII (`clubefii.com.br`)
* **Superpoderes:**
  - Ecossistema mais aprofundado para Fundos Imobiliários no Brasil.
  - Mapa geográfico de imóveis físicos com dados da parceria SiiLA (padrão construtivo A+, vacância da região, cap rates).
  - Histórico de transações de compra e venda de imóveis com apuração de ganho de capital e TIR.
  - Cronograma de vencimento de contratos de locação (típicos vs. atípicos) e concentração de inquilinos.
* **Falhas de UX:**
  - Interface extremamente fragmentada, menus confusos, carregamento lento de páginas e paywall agressivo.
* **Inovações Adotadas no `fin-web`:**
  - "FII Immersive Cockpit": mapa interativo SVG/Canvas de imóveis, ABL total, filtros por estado/cidade.
  - Linha do tempo de Transações Imobiliárias (vendas, aquisições, cap rates).
  - Matriz de Risco de Inquilinos com radar de concentração dos Top 5 locatários e vencimentos ano a ano.

---

### S06. Funds Explorer (`fundsexplorer.com.br`)
* **Superpoderes:**
  - Ranking de FIIs de 30 colunas com forte adoção pela comunidade.
  - Comparação clara de Preço vs. Valor Patrimonial (P/VP) e Dividend Yield anualizado.
  - Histórico de vacância física vs. vacância financeira ao longo do tempo.
* **Falhas de UX:**
  - Lentidão severa no carregamento da tabela principal de ranking (WordPress bloated).
  - Layout com propagandas invasivas.
* **Inovações Adotadas no `fin-web`:**
  - Tabela de Ranking de FIIs Instantânea com cache otimizado, badges de desconto (P/VP < 1.00 em verde neon).
  - Gráfico de Evolução Patrimonial (VPC vs. Cotação de Mercado) com preenchimento gradiente.

---

### S07. FIIs.com.br (`fiis.com.br`)
* **Superpoderes:**
  - Agenda de dividendos precisa com foco no mês de competência da distribuição (`mes_referencia`).
  - Feed de comunicados, fatos relevantes e relatórios gerenciais em tempo real.
  - Simulador simplificado de reinvestimento de dividendos (Magic Number - número de cotas para comprar 1 cota todo mês com rendimentos).
* **Falhas de UX:**
  - Falta de métricas aprofundadas de alavancagem e passivo de FIIs.
* **Inovações Adotadas no `fin-web`:**
  - "Calculadora do Magic Number" interativa com sliders táteis.
  - Agenda de Proventos com distinção visual entre Data-Com, Data-Pagamento e Mês de Competência.

---

### S08. Mais Retorno (`maisretorno.com`)
* **Superpoderes:**
  - Motor de análise quantitativa de risco líder de mercado para Fundos CVM 175 (10 janelas temporais x 10 métricas estatísticas: Sharpe, Sortino, Treynor, Alfa de Jensen, Beta, Tracking Error, Drawdown Máximo e Tempo de Recuperação).
  - CDA (Composição e Demonstração de Ativos) aberto com histórico de compras e vendas declaradas.
  - Comparador multiativo dinâmico contra 170+ benchmarks e índices econômicos.
* **Falhas de UX:**
  - Páginas muito longas com dados fragmentados em abas que recarregam a página.
* **Inovações Adotadas no `fin-web`:**
  - "Quantitative Risk Matrix 10x10" com código de cores térmicas em tempo real.
  - Explorador de Carteira CDA com distribuição em Sunburst/Donut de Ações, Renda Fixa e Derivativos.
  - Comparador Multiativo de Alta Performance com normalização em base 100 ou retorno percentual.

---

### S09. Análise de Ações (`analisedeacoes.com`)
* **Superpoderes:**
  - Modelos matemáticos de valuation automáticos:
    - Preço Justo de Graham: $V = \sqrt{22.5 \times LPA \times VPA}$
    - Preço Teto de Décio Bazin: $P_{teto} = \frac{DPA_{medio}}{0.06}$
    - Fluxo de Caixa Descontado (DCF simplificado com WACC e crescimento perpétuo).
  - Checklist dos 5 Pilares de Valuation com notas de 0 a 100.
  - Mapeamento de dias habituais de anúncio e corte de proventos.
* **Falhas de UX:**
  - Visual estático e limitado em interatividade.
* **Inovações Adotadas no `fin-web`:**
  - Calculadora de Valuation em Tempo Real com sliders para ajustar margem de segurança, taxa de desconto e payout projetado.
  - Widget de Preço Teto vs. Preço Atual com velocímetro de desconto.

---

### S10. Brick360 (`brick360.com.br`)
* **Superpoderes:**
  - "Brick Score" proprietário dividido em 6 eixos (Imobiliário, Financeiro/Alavancagem, Inquilinos, Gestão, Risco de Crédito e Preço).
  - Comitê de Inteligência Artificial com parecer SWOT sintetizado sobre relatórios gerenciais e fatos relevantes.
  - DRE contábil padronizada CVM trimestral com despesas de administração, consultoria e receitas financeiras.
* **Falhas de UX:**
  - Acesso muito restrito/fechado com poucas telas abertas para usuários convidados.
* **Inovações Adotadas no `fin-web`:**
  - Radar Spider Chart SVG de 6 Eixos do Score do Ativo.
  - Comitê de IA com análise de sentimento (Bullish / Neutral / Bearish) e sumário executivo em áudio/texto.
  - Demonstração de Resultado Trimestral padronizada CVM.

---

### S11. ADVFN Brasil (`br.advfn.com`)
* **Superpoderes:**
  - 13 Indicadores Técnicos calculados em 9 timeframes (MMS 5/21/50/200, MME, IFR/RSI, Estocástico, MACD, Bollinger, Parabolic SAR, HiLo, OBV, ADX).
  - Cálculo de 4 Suportes ($S_1..S_4$), Ponto de Pivô ($PP$) e 3 Resistências ($R_1..R_3$).
  - Detecção algorítmica de padrões de Candlestick (Martelo, Engolfo, Doji, etc.).
  - Consenso de Analistas Sell-Side com preço-alvo médio/mínimo/máximo e projeções futuras (2026–2028).
* **Falhas de UX:**
  - Interface do início dos anos 2000, hiper-poluída, popups de anúncios intrusivos.
* **Inovações Adotadas no `fin-web`:**
  - Painel Técnico Futurista com termômetro de consenso (Compra Forte / Neutro / Venda Forte).
  - Mini mapa de Suportes e Resistências com linhas horizontais dinâmicas.
  - Painel de Consenso de Mercado com gráfico de dispersão de preços-alvo de analistas.

---

### S12. ETFs Brasil (`etfsbrasil.com.br`)
* **Superpoderes:**
  - Universo completo de ETFs locais B3 e internacionais (UCITS, EUA) com custo total (TER - primária + secundária).
  - Spread NAV (Ágio ou deságio em relação ao valor patrimonial líquido da carteira).
  - Fluxo de criação e destruição de cotas em 30 dias pelo formador de mercado.
  - Política de dividendos (Acumulativa com reinvestimento automático vs. Distributiva).
* **Falhas de UX:**
  - Funcionalidades restritas e design funcional simples sem motion ou polimento premium.
* **Inovações Adotadas no `fin-web`:**
  - Comparador de Custo Efetivo Total de ETFs (TER).
  - Monitor de Spread NAV com indicador de liquidez e fluxo institucional de 30 dias.

---

## 2. Matriz de Síntese e Inovações Exclusivas do `fin-web`

| Funcionalidade / Tela | Fonte de Inspiração | Diferencial Tecnológico no `fin-web` |
|---|---|---|
| **Cockpit / Home** | Bloomberg Terminal + Linear | Visão unificada com Ticker Tape de alta frequência, Heatmap setorial, Calendário de Resultados e Radar Macro |
| **DRE & DFC Interativas** | Status Invest + Fundamentei | Drill-down sem reload, comutação Nominal / % da Receita / Variação YoY, gráfico de cascata em SVG puro |
| **Valuation Graham / Bazin / DCF** | Análise de Ações | Sliders reativos com cálculo instantâneo no cliente e margem de segurança configurável |
| **Checklist Fundamentalista** | Investidor10 + Análise de Ações | Radar Chart SVG dos pilares, regras de conformidade com justificativa matemática e nota final |
| **FII Deep-Dive & Imóveis** | Clube FII + Brick360 + Funds Explorer | Mapa interativo de ativos físicos, ABL, SiiLA padrão construtivo, concentração de contratos e Brick Score 6 eixos |
| **Quant Risk 10x10 (Fundos)** | Mais Retorno | Tabela térmica de Sharpe, Sortino, Treynor, Alfa de Jensen e Drawdown em 10 timeframes com animação fluida |
| **ETFs & Custo TER** | ETFs Brasil | Desmembramento de taxas primárias/secundárias, spread NAV e simulação de impacto de taxa no longo prazo |
| **Screener Universal Multiativo** | Fundamentus + Status Invest | 80+ métricas filtráveis, busca fuzzy ultra-rápida, ordenação instantânea e presets recomendados |
| **Consenso de Analistas & Técnico** | ADVFN Brasil | Suportes e resistências automáticos, radar de 13 indicadores técnicos e projeções de analistas para 2026–2028 |
| **Comitê de IA & Fatos Relevantes** | Brick360 + Fundamentei | Resumo executivo de fatos relevantes com análise de sentimento em tempo real |

---

## 3. Plano Diretor de Telas (Architecture & Routes)

```
fin-web/src/app/
├── layout.tsx                     # Shell Global (Dark Obsidian, Glass Nav, Ticker Tape, Footer)
├── page.tsx                       # Dashboard / Cockpit Central
├── acoes/
│   ├── page.tsx                   # Screener e Lista de Ações B3 com Heatmap
│   └── [ticker]/page.tsx          # Deep-Dive da Ação (DRE, Múltiplos, Valuation, Governança, Consenso)
├── fiis/
│   ├── page.tsx                   # Screener e Ranking de FIIs e Fiagros
│   └── [ticker]/page.tsx          # Deep-Dive do FII (Imóveis, SiiLA, Inquilinos, CRIs, Brick Score, DRE)
├── fundos/
│   ├── page.tsx                   # Lista e Screener de Fundos de Investimento CVM 175
│   └── [id]/page.tsx              # Deep-Dive do Fundo (CDA aberto, Matriz de Risco 10x10, Gestora)
├── etfs/
│   ├── page.tsx                   # Explorador de ETFs (B3 e Internacionais)
│   └── [ticker]/page.tsx          # Deep-Dive do ETF (TER, Spread NAV, Ativos subjacentes)
├── renda-fixa/
│   └── page.tsx                   # Tesouro Direto, Curva Zero ETTJ ANBIMA, Debêntures
├── screener/
│   └── page.tsx                   # Screener Universal Multiativo Ultra-Rápido
├── comparador/
│   └── page.tsx                   # Comparador Head-to-Head com Radar de Eixos e Rentabilidade
├── carteira/
│   └── page.tsx                   # Gestão de Carteira, Projeção de Dividendos e Magic Number
└── radar-ia/
    └── page.tsx                   # Central de Inteligência IA, Fatos Relevantes e Sentimento
```

---

## 4. Design System Futurista: Tokens, Motion e Arquitetura

### 4.1 Identidade Visual (Ethereal Dark Obsidian)
- **Fundo Base:** `#060709` (Obsidian OLED) com gradiente radial sutil `#0B0E14` e orbes de luz esmeralda/ciano com opacidade baixa.
- **Cartões & Containers (Double-Bezel Architecture):**
  - *Outer Shell:* `border border-white/10 bg-white/[0.02] p-1 rounded-2xl`
  - *Inner Core:* `bg-[#0C0F17]/90 rounded-xl p-5 border border-white/5 shadow-inner`
- **Cores de Destaque Semântico:**
  - Cyber Emerald (`#00F5A0`): Rentabilidade positiva, proventos, recomendações de compra, selos de qualidade.
  - Cyber Crimson (`#FF3B69`): Queda de cotação, endividamento de risco, sinais de venda.
  - Laser Cyan (`#00D9F5`): Métricas de liquidez, múltiplos de mercado, benchmarks.
  - Electric Violet (`#A855F7`): Inteligência Artificial, Comitê e Valuation preditivo.
  - Amber Glow (`#F59E0B`): Alertas de vencimento de contratos, volatilidade, advertências CVM.

### 4.2 Motion Choreography & CSS Puro
- **Transições com Física de Mola:**
  `transition: all 400ms cubic-bezier(0.32, 0.72, 0, 1);`
- **Micro-interações de Botão (Button-in-Button):**
  Botão em pílula com ícone destacado em círculo independente que desliza no hover.
- **Zero bibliotecas externas de layout:**
  Utilização estrita de **CSS Grid**, **Flexbox**, **CSS Variables** e transições aceleradas por GPU (`transform`, `opacity`).
- **Validação de Schemas com Zod:**
  Todas as interfaces e contratos de dados tipados e validados rigorosamente com `zod`.
