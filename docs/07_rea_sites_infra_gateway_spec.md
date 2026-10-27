# SDD & REA (v3.5) — Engenharia Reversa dos 12 Sites, Especificação de Egress Gateway & Infraestrutura

**Versão:** 3.5  
**Data:** 2026-10-26  
**Repositório de Infraestrutura:** `https://github.com/barrosrafa/fin-infra`  
**Repositório do Banco de Dados:** `https://github.com/barrosrafa/fin-db`  
**Repositório da API:** `https://github.com/barrosrafa/fin-api`  
**Repositório de Ingestão:** `https://github.com/barrosrafa/fin-ingestion`  

Para a especificação completa de engenharia reversa dos 12 sites e implementação do gateway de egress, consulte a documentação detalhada no repositório `fin-infra`:
- [`fin-infra/docs/REA_ANALYSIS_AND_GATEWAY_SPEC.md`](file:///Users/rafaelaparecido/fin-infra/docs/REA_ANALYSIS_AND_GATEWAY_SPEC.md)

### Resumo dos Perfis de Egress por Fonte:
1. **Perfil 1 (Direct VPC NAT):** B3, CVM, BCB, ETFs Brasil.
2. **Perfil 2 (Datacenter Rotating):** Status Invest, Fundamentei, Brick360, Funds Explorer.
3. **Perfil 3 (Sticky Session ISP):** Investidor10, Fundamentus, Clube FII.
4. **Perfil 4 (Residential Rotating):** Mais Retorno, ADVFN Brasil.
