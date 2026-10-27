# Design de Arquitetura: Grafo Temporal de Portfólio, Reconciliação Multi-Fonte & Camada de Leitura Falsificável

**Data:** 2026-10-26  
**Status:** Em Revisão (Aguardando Aprovação do Usuário)  
**Escopo:** Ecossistema `fin` (`fin-db`, `fin-ingestion`, `fin-api`, `fin-web`, `fin-infra`)

---

## 1. Visão Geral & Tese de Produto

### 1.1 O "Momento Exato"
O ecossistema **fin** não compete como mais um silo vertical de classe de ativo (como Status Invest, Investidor10, Clube FII ou Mais Retorno). Sua diferenciação radical é a capacidade de **raciocinar sobre o portfólio completo do investidor real**, cruzando múltiplas fontes reconciliadas com proveniência e desdobrando ativos até a sua **concentração real por devedor/grupo econômico** (*look-through*).

O instante divisor de águas ocorre quando o investidor lê uma conclusão que nenhum portal vertical consegue gerar isoladamente:

> *"Sua exposição a crédito imobiliário de papel é 34% do patrimônio — soma de FII X (22%), fundo CVM 175 Y (9%) e CRI Z (3%). O rating do CRI Z caiu de AA para A em 12/09 (fonte: Brick360, atualizado 14:32). O FII X tem 18% do PL no mesmo emissor (fonte: Clube FII / SiiLA). Você não tem concentração por ticker — tem concentração por devedor."*

### 1.2 Os Três Rituais do Usuário
1. **Revisão Mensal de Carteira ("Por que meu número não bate?")**: Exibição da posição consolidada com matriz de divergência e explicação metodológica das discrepâncias entre os 12 portais.
2. **Impacto Consolidado de Eventos Corporativos**: Projeção de proventos, amortizações e desdobramentos na carteira total em tempo hábil.
3. **Parecer do Comitê IA Portfolio-Aware**: Análise analítica orientada à carteira específica daquele investidor, sustentada por frases falsificáveis e auditáveis.

---

## 2. Metas, Não-Metas e Anti-Metas

### 2.1 Metas (Goals)
- **Substrato Unificado (Grafo Temporal com MDM)**: Modelar a custódia do usuário e suas camadas subjacentes (FII -> imóvel/CRI -> devedor; Fundo CVM 175 -> CDA -> emissor) em um grafo bitemporal versionado.
- **Reconciliação como Peso e Confiança das Arestas**: A reconciliação multi-fonte pondera e audita diretamente as arestas de look-through e métricas de ativos.
- **Taxonomia Finita de Divergências**: Identificar e categorizar a causa de qualquer discrepância métrica entre fontes (janela temporal, tributação, data base, metodologia de proventos).
- **Transparência de Cobertura (Dois Buckets de Não-Desdobrável)**: Expor na UI desde a v1 os percentuais:
  - *(a) Estruturalmente Impossível/Opaco*: Ativos sem transparência de carteira (CRI de CRI subordinado, FII opaco).
  - *(b) Temporariamente Indisponível/Latência*: Defasagem regulatória ou atraso de publicação (ex: CDA CVM T+30).
- **Métrica Canônica como Árbitro Determinístico**: Não inventar uma 13ª opinião arbitrária. Publicar intervalo de consenso [min, max, IQR] e âncora determinística com rastreio de regras públicas.
- **Frase Falsificável e Auditável**: Gerada via templates enriquecidos por subgrafos estruturados, com logging de inferência e links diretos para as fontes.
- **Loop de Feedback do Usuário**: Permitir override local pelo usuário com fila de curadoria humana para enriquecimento do MDM global.
- **Fatiamento em MVP Vertical**: Entregar o ciclo completo com 1 classe (FII de papel), 1 fonte de lastro (CDA CVM 175), 1 nível de look-through, reconciliação de 2 fontes e frase template.

### 2.2 Não-Metas (Non-Goals)
- Não construir módulo de execução direta de ordens (home broker/trading execution) nesta fase.
- Não atuar como consultoria financeira regulada; as leituras são exclusivamente analítico-informativas.
- Não executar RAG ingênuo sobre PDFs brutos para o Comitê IA (o Comitê opera sobre contexto estruturado de grafo).

### 2.3 Anti-Metas (Anti-Goals)
- **Zero Ocultação de Incerteza**: Jamais ocultar percentuais não desdobrados. O bucket "não desdobrável" é nosso fosso de confiança.
- **Zero Métrica sem Proveniência**: Jamais exibir um indicador proprietário sem permitir o clique que revela o cálculo, a fonte e a comparação com os portais de mercado.
- **Zero Recomendação Prescritiva Impositiva**: Jamais emitir julgamentos normativos sem que o usuário tenha configurado explicitamente sua política de alocação ou optado por benchmarks de mercado declarados.

---

## 3. Invariantes de Produto Inegociáveis

1. **Visibilidade Imediata da Cobertura (v1 UI Invariant)**: Todo card de alocação ou parecer de comitê deve exibir a barra de cobertura decomposta:
   `[ % Desdobrado | % Temporariamente Indisponível | % Estruturalmente Opaco ]`.
2. **Taxonomia Explícita de Divergência**: Toda divergência superior a $\Delta > 1.5\%$ deve apresentar o badge de causa (ex: `Janela de Dividendos (12M vs LTM)`, `Preço Fechamento vs Intraday`, `Bruto vs Líquido`).
3. **Auditabilidade da Inferência**: Toda frase emitida pelo Comitê IA possui um `inference_log_id` vinculando:
   `(user_id, portfolio_hash, subgraph_snapshot_id, prompt_template_v, model_version, timestamp)`.

---

## 4. Arquitetura do Grafo Temporal & MDM (Master Data Management)

### 4.1 Resolução de Devedor de CRIs em 3 Camadas (ANBIMA Data + Seed de Legado + Ferramenta de Curadoria)
Na CDA da CVM 175, o emissor registrado do CRI é formalmente a Securitizadora (Opea, Virgo, True, etc.). Além disso, a regulação ANBIMA estipula que o campo devedor só é preenchido para operações concentradas acima de 20% da oferta. A resolução do devedor econômico final é estruturada em uma esteira com hierarquia estrita:

1. **Camada 1 (Fonte Primária Externa / ANBIMA Data)**: Ingestão contínua da base pública de ofertas de CRIs da ANBIMA (disponível a partir de out/2026, cobrindo ofertas encerradas desde dez/2025). Mapeia diretamente:
   `Código ISIN / Negociação -> CNPJ Cedente/Devedor -> Razão Social / Nome Fantasia`.
2. **Camada 2 (Fallback de Legado Curado)**: Para CRIs anteriores a dez/2025 (presentes nas carteiras dos FIIs do MVP como KNIP11, KNCR11, CPTS11), uma tabela de referência curada e auditada (`canonical.cri_legacy_seeds`) mapeia ISIN para CNPJ do devedor e grupo econômico.
3. **Camada 3 (Ferramenta de Sugestão Interna / Parser Heurístico - Fora da Verdade do Grafo)**: Parsers de NLP/regex sobre termos de securitização e notas da CDA atuam unicamente gerando sugestões para a fila de curadoria humana no backoffice, **jamais** populando o grafo diretamente para evitar contaminação por falsos positivos.

### 4.2 Bitemporalidade Real
Cada aresta do grafo que conecta um ativo a outro ativo ou a um devedor final possui quatro dimensões de tempo:
- `valid_time_start` e `valid_time_end`: Período em que a relação descrita ocorreu no mundo real (ex: competência da carteira CDA em 31/08/2026).
- `transaction_time_start` e `transaction_time_end`: Período em que o sistema tomou conhecimento desse fato através da ingestão (ex: informe publicado em 15/09/2026 e retificado em 20/10/2026).

Isso garante a capacidade nativa de responder: *"Por que minha exposição mudou se eu não operei na carteira?"* (Diff temporal de retificação de dados de terceiros).

### 4.3 Camada de Resolução de Entidades (MDM)
Estrutura hierárquica canônica:
```
Grupo Econômico Canônico (ex: Grupo JHSF)
  └── Entidade Legal / Matriz (CNPJ Raiz)
        ├── SPEs e Subsidiárias (CNPJs Filiais / SPEs de Shopping / Galpões)
        ├── Nomes Fantasia / Aliases SiiLA ("Shopping Bela Vista SPE")
        └── Tickers / Instrumentos Vinculados (CRIs, Debêntures, FIIs com mono-locatário)
```
- Ingestão alimenta tabela de `raw_entities` com fonte e metadados.
- Pipeline determinístico de deduplicação (CNPJ base, Levenshtein em razão social limpa, matching de endereço SiiLA/CVM).
- Confiança da entidade: Score de 0 a 100. Casos com score $< 85$ entram na fila de curadoria humana.

### 4.4 Substrato do Grafo no Banco de Dados (`fin-db`)
Tabelas centrais no schema `graph` e `canonical`:
- `graph.entities`: Entidades econômicas canônicas (grupos, devedores, emissores).
- `graph.entity_aliases`: Mapeamento de termos de busca, SPEs, códigos SiiLA, tickers.
- `graph.edges_bitemporal`: Arestas direcionadas versionadas:
  - `source_id` (ex: FII X)
  - `target_id` (ex: Grupo Y)
  - `weight` (percentual do PL ou valor contábil)
  - `edge_type` (`HOLDS_SHARE`, `CREDIT_RECEIVABLE`, `REAL_ESTATE_TENANT`, `SUBSIDIARY_OF`)
  - `valid_range` (`tstzrange`)
  - `transaction_range` (`tstzrange`)
  - `provenance_source_id` (ANBIMA Data, Seed Legado, CVM CDA, SiiLA)
  - `confidence_score` (0.0 a 1.0)
  - `coverage_category` (`RESOLVED`, `OPAQUE_UNAVAILABLE`, `TEMPORARY_PENDING`)

---

## 5. Motor de Reconciliação Multi-Fonte & Métrica Canônica

### 5.1 Taxonomia das Causas de Divergência
O motor compara métricas coletadas dos portais (Status Invest, Investidor10, Clube FII, Funds Explorer, etc.) e classifica discrepâncias nas categorias:
1. `PRICE_TIMESTAMP_MISMATCH`: Fechamento oficial vs Último negócio intraday vs Preço médio ponderado.
2. `DIVIDEND_WINDOW_MISMATCH`: 12 meses corridos vs Ano fiscal (YTD) vs Anualização do último provento pago.
3. `TAX_TREATMENT_MISMATCH`: Valor bruto vs Líquido de IR (relevante para Fiagros, Fundos Infra e Ações com JCP).
4. `CAPITAL_BASE_MISMATCH`: Lucro básico vs Lucro diluído / PL contábil vs PL de mercado.
5. `AMORTIZATION_ACCOUNTING`: Tratamento de amortização de principal como provento/rendimento vs redução de custo de aquisição.
6. `SOURCE_STALENESS_OR_ERROR`: Defasagem de sincronização da fonte de origem (> 48h sem refresh).

*Estratégia de Classificação no MVP:* Abordagem híbrida baseada em uma matriz estática de catalogação de metodologias conhecidas (`reconciliation.divergence_taxonomies`) combinada com verificação analítica pontual do delta (ex: checar se a diferença coincide com a anualização do provento do último mês). Não há necessidade de um motor de cálculo reverso complexo no MVP.

### 5.2 Regra Determinística do Árbitro
Para qualquer métrica financeira $M$ de um ativo:
- **Intervalo de Consenso**: Exibido como $[M_{\min}, M_{\max}]$ com $\text{IQR}$ (Interquartile Range) e desvio padrão.
- **Âncora de Referência (Canonical Anchor)**: Selecionada por critério hierárquico estrito e versionado:
  1. *Fonte Primária Regulatória* (CVM / B3 direta): se presente, é a âncora oficial.
  2. *Fonte Secundária Qualificada*: Se a fonte primária não calcula o derivado (ex: DY projetado), a âncora é a fonte com maior pontuação no algoritmo de confiabilidade:
     $$\text{Score} = w_1 \cdot \text{Freshness} + w_2 \cdot \text{PublicMethodologyDoc} + w_3 \cdot \text{HistoricalStability}$$
  3. A âncora nunca altera silenciosamente o histórico: qualquer alteração de metodologia de cálculo de uma fonte é registrada em `audit.methodology_changelog`.

---

## 6. Origem dos Limiares, Benchmarks & Enquadramento Regulatório

### 6.1 Origem dos Limiares
Para garantir conformidade estrita e evitar recomendações de investimento não solicitadas:
- **Nível 1 - Limites Definidos pelo Usuário (Custom Limits)**: O usuário configura no cockpit seus tetos de apetite a risco (ex: "Concentração máxima por devedor: 20%", "Alocação mínima em tijolo: 40%").
- **Nível 2 - Políticas Declaradas com Opt-in (Templates de Alocação)**: O usuário adota perfis conceituais (ex: "Conservador Renda Passiva", "Diversificação de Risco de Crédito").
- **Nível 3 - Benchmarks Neutros de Mercado**: Comparativos objetivos contra IFIX, CDI, IPCA ou mediana agregada de pares anonimizados do sistema (percentil na base geral).

### 6.2 Enquadramento de Copy e Compliance
- Toda notificação ou insight utiliza linguagem estritamente diagnóstica:
  - Permitido: *"Sua exposição ao Grupo JHSF está em 34%, superando o limiar de 25% definido por você."*
  - Permitido: *"O ativo FII X possui 18% do PL alocado no mesmo devedor ao qual você já possui exposição via CRI Z."*
  - Proibido: *"Você deve vender FII X para rebalancear sua carteira."*
- Disclaimer institucional fixo em rodapé e modal de proveniência.

---

## 7. Arquitetura da "Frase Falsificável" & Comitê IA

### 7.1 Geração 100% Determinística no MVP (Templates com Slots + Subgrafo)
Para assegurar custo zero de inferência, latência ultrarrápida (< 10ms síncronos) e reprodutibilidade matemática irrefutável, o MVP executará geração puramente determinística:
1. **Extração de Fatos Estruturados (Fact Graph Extraction)**:
   O backend extrai o subgrafo bitemporal da carteira do investidor:
   - Percentuais agregados por devedor/grupo econômico;
   - Arestas de lastro e ratings mais recentes (Brick360 / CVM);
   - Divergências ativas com badges de taxonomia;
   - Limiares do usuário violados.
2. **Template Engine Determinístico**:
   O motor em Python monta a frase preenchendo slots validados:
   `"Sua exposição a {classe_macro} é {pct_total}% — soma de {ativos_decompostos}. O rating de {ativo_critico} variou de {rating_antigo} para {rating_novo} em {data_rating} (fonte: {fonte_rating}). {alerta_limiar}"`
3. **Pills Clicáveis (UI Falsificável)**:
   Cada termo entre chaves é renderizado no frontend como um *pill interativo*:
   - Clicar em `{pct_total}` abre o modal com a árvore completa de cálculo e decomposição dos lastros.
   - Clicar em `{fonte_rating}` abre o comprovante da citação com timestamp e link para a fonte externa.
4. **Logging de Inferência Obrigatório**:
   Mesmo sendo determinístico, cada bloco persistido registra:
   `inference_id`, `user_id`, `portfolio_version_hash`, `subgraph_snapshot_json`, `template_id`, `generated_text`, `created_at`. Chamadas a LLMs (Gemini/Claude) para enriquecimento de estilo permanecem como camada opcional pós-MVP.

---

## 8. Loop de Correção do Usuário (Human-in-the-Loop) & Persistência

1. **Semântica e Persistência de Overrides de Usuário**:
   Para sobreviver às ingestões mensais e substituição de arestas bitemporais da CDA, o override local do usuário (`wealth.user_graph_overrides`) é indexado pelo trio estável:
   `(user_id, source_asset_id, target_entity_id)` acompanhado de `override_type` (`EXCLUDE_EDGE`, `REMAP_ENTITY`, `OVERRIDE_WEIGHT`) e timestamp.
   Na query de travessia do look-through no `fin-api`, o motor aplica um `LEFT JOIN` com `COALESCE` sobre as arestas ativas.
2. **Sinal de Discrepância / Feedback Flag**: A ação do usuário gera um registro auditável em `audit.discrepancies` contendo a justificativa do investidor.
3. **Fila de Curadoria Global no MVP**: No MVP, as discrepâncias são consolidadas em tabelas de auditoria e revisadas pela equipe via scripts/SQL. A construção de uma interface web administrativa de backoffice fica para a Fase 2.

---

## 9. Fatiamento em MVP Vertical (Vertical Slice)

Para validar o "momento exato" em semanas com integridade institucional:

| Componente | Escopo do MVP Vertical | O que fica para etapas seguintes |
|---|---|---|
| **Classes de Ativos** | FIIs de Papel (CRI) | Ações, Fundos Multimercado, ETFs, BDRs |
| **Resolução de Devedor** | Híbrida: ANBIMA Data (out/2026, pós dez/2025) + Seed Curado de Legado (pré dez/2025) | Extrator de NLP/Termos de securitização no pipeline de produção |
| **Fontes de Lastro** | CDA CVM 175 (Composição de Carteira dos FIIs) | Informes trimestrais manuais, SiiLA scraping contínuo |
| **Profundidade do Grafo** | 1 nível de look-through (Cota FII -> Emissor/Devedor do CRI) | Grafo recursivo de participações societárias complexas |
| **Reconciliação** | 2 fontes (Status Invest vs Funds Explorer) | Reconciliação dos 12 portais simultâneos |
| **Camada de UX** | Cockpit com card de devedor oculto + frase template + 2 buckets de não desdobrado | Chat conversacional aberto com Comitê IA |
| **Carteiras Mistas** | Ativos nível 0 (ações diretas, tesouro) entram com 100% resolvido; UI permite toggle entre "Exposição Total" e "Recorte Crédito/FIIs" | Look-through automatizado em fundos de ações CVM 175 |

---

## 10. Divisão de Responsabilidades por Repositório

### 10.1 `fin-db` (Banco de Dados & Modelos)
- Criar migrations para o schema `graph` (`graph.entities`, `graph.edges_bitemporal`, `graph.entity_aliases`).
- Criar schema `reconciliation` (`reconciliation.metric_snapshots`, `reconciliation.divergences`, `reconciliation.divergence_taxonomies`, `reconciliation.canonical_metrics`).
- Adicionar suporte a bitemporalidade (`tstzrange`) com índices GiST para queries de as-of eficientes.
- Criar tabelas para logging de inferência (`audit.inference_logs`), auditoria de discrepâncias (`audit.discrepancies`) e overrides de usuário (`wealth.user_graph_overrides`).
- Tabela de seeds curados de legado (`canonical.cri_legacy_seeds`).

### 10.2 `fin-ingestion` (Pipelines de Coleta & Parsing)
- Coletor da base pública da ANBIMA Data (cedentes e devedores de CRIs por ISIN/CNPJ).
- Parser de CDA CVM 175 para extração das carteiras de CRIs dos FIIs listados.
- Coletor de ratings de CRIs (Brick360 / CVM).
- Pipeline de reconciliação de métricas de FIIs entre Status Invest e Funds Explorer com classificação pela taxonomia estática/delta.
- Script de carga e validação do seed legado para CRIs pré-dez/2025.

### 10.3 `fin-api` (Serviços de Domínio & GraphQL/REST)
- Serviço de Look-Through: Algoritmo de travessia do subgrafo da carteira do usuário calculando exposição agregada por grupo econômico e buckets não desdobráveis com suporte a overrides de usuário estáveis.
- Motor de Arbitragem: Cálculo determinístico do intervalo de consenso e seleção da âncora canônica.
- Motor de Frases Falsificáveis: Montagem dos templates parametrizados em Python (< 10ms) e logging de inferência auditável.
- Endpoints de User Override e reporte de divergências.

### 10.4 `fin-web` (Frontend & Experiência Cockpit)
- Card de **Concentração Real por Devedor**: visualização da carteira desagrupada de tickers e reagrupada por grupo econômico.
- Barra de Cobertura Tripla com Semântica Clara: `[ % Identificado | % Não Coberto ANBIMA (Pré-Dez/25) / Pendente de Curadoria | % Estruturalmente Opaco ]`.
- Badges e Modais de Divergência Multi-Fonte: exibição do "Por que meu número não bate?" com detalhamento da metodologia.
- Frase Falsificável interativa com pills clicáveis para auditoria instantânea da fonte.
- Interface de override de relacionamento de entidades para o usuário.
- Toggle de visualização: "Exposição Total da Carteira" vs "Recorte Crédito/FIIs".

### 10.5 `fin-infra` (Infraestrutura, Workers & Observabilidade)
- Configuração de filas e workers (Redis / Celery) para processamento assíncrono de CDAs e base ANBIMA.
- Configuração de retenção e índices de busca para logs de auditoria e inferência.
- Monitoramento de drift de scraping e alertas de indisponibilidade de fontes primárias.

---

## 11. O Que Fica a Cargo do Implementador (Decisões de Engenharia)
- Nomes exatos de índices, particionamento de hypertables e constraints no PostgreSQL.
- Escolha da biblioteca de fuzzy matching em Python/Node para a resolução inicial de nomes de SPEs.
- Detalhes de estilização visual (Tailwind CSS tokens, layout responsivo) no `fin-web`.
