---
title: "BRD-00: Index - AI Cloud Cost Monitoring"
tags:
  - brd-index
  - layer-1-artifact
  - shared-architecture
custom_fields:
  document_type: index
  artifact_type: BRD
  layer: 1
  development_status: active
  total_brds: 14
  foundation_brds: 7
  domain_brds: 7
---

# BRD Index - AI Cloud Cost Monitoring

**Project:** AI Cloud Cost Monitoring Platform
**Layer:** 01_BRD (Business Requirements)
**Status:** Complete (14 BRDs: 7 Foundation + 7 Domain)

---

## Hybrid BRD Structure

The AI Cost Monitoring Platform uses a **Hybrid Structure** (adapted from Trading Nexus v4.2):
- **7 Foundation BRDs (BRD-01 to BRD-07)**: Domain-agnostic, portable infrastructure modules (section-based)
- **Domain BRDs (BRD-08+)**: Project-specific cost monitoring capabilities (monolithic)

---

## Foundation BRDs (Section-Based Structure)

| BRD ID | Title | Module | Sections | Status |
|:-------|:------|:-------|:---------|:-------|
| **BRD-01** | [F1 Identity & Access Management](BRD-01_f1_iam/BRD-01.0_index.md) | F1 IAM | [Core](BRD-01_f1_iam/BRD-01.1_core.md) \| [Reqs](BRD-01_f1_iam/BRD-01.2_requirements.md) \| [Ops](BRD-01_f1_iam/BRD-01.3_quality_ops.md) | Draft |
| **BRD-02** | [F2 Session & Context Management](BRD-02_f2_session/BRD-02.0_index.md) | F2 Session | [Core](BRD-02_f2_session/BRD-02.1_core.md) \| [Reqs](BRD-02_f2_session/BRD-02.2_requirements.md) \| [Ops](BRD-02_f2_session/BRD-02.3_quality_ops.md) | Draft |
| **BRD-03** | [F3 Observability](BRD-03_f3_observability/BRD-03.0_index.md) | F3 Observability | [Core](BRD-03_f3_observability/BRD-03.1_core.md) \| [Reqs](BRD-03_f3_observability/BRD-03.2_requirements.md) \| [Ops](BRD-03_f3_observability/BRD-03.3_quality_ops.md) | Draft |
| **BRD-04** | [F4 Security Operations](BRD-04_f4_secops/BRD-04.0_index.md) | F4 SecOps | [Core](BRD-04_f4_secops/BRD-04.1_core.md) \| [Reqs](BRD-04_f4_secops/BRD-04.2_requirements.md) \| [Ops](BRD-04_f4_secops/BRD-04.3_quality_ops.md) | Draft |
| **BRD-05** | [F5 Self-Sustaining Operations](BRD-05_f5_selfops/BRD-05.0_index.md) | F5 Self-Ops | [Core](BRD-05_f5_selfops/BRD-05.1_core.md) \| [Reqs](BRD-05_f5_selfops/BRD-05.2_requirements.md) \| [Ops](BRD-05_f5_selfops/BRD-05.3_quality_ops.md) | Draft |
| **BRD-06** | [F6 Infrastructure](BRD-06_f6_infrastructure/BRD-06.0_index.md) | F6 Infrastructure | [Core](BRD-06_f6_infrastructure/BRD-06.1_core.md) \| [Reqs](BRD-06_f6_infrastructure/BRD-06.2_requirements.md) \| [Ops](BRD-06_f6_infrastructure/BRD-06.3_quality_ops.md) | Draft |
| **BRD-07** | [F7 Configuration Manager](BRD-07_f7_config/BRD-07.0_index.md) | F7 Config | [Core](BRD-07_f7_config/BRD-07.1_core.md) \| [Reqs](BRD-07_f7_config/BRD-07.2_requirements.md) \| [Ops](BRD-07_f7_config/BRD-07.3_quality_ops.md) | Draft |

---

## Domain BRDs (Monolithic Structure)

| BRD ID | Title | Module | Scope | Status |
|:-------|:------|:-------|:------|:-------|
| **BRD-08** | [D1 Agent Orchestration & MCP](BRD-08_d1_agent_orchestration.md) | D1 Agents | Coordinator, domain agents, MCP servers | Draft |
| **BRD-09** | [D2 Cloud Cost Analytics](BRD-09_d2_cost_analytics.md) | D2 Analytics | BigQuery, cost analysis, recommendations | Draft |
| **BRD-10** | [D3 User Experience](BRD-10_d3_user_experience.md) | D3 UX | Grafana + AG-UI hybrid interface | Draft |
| **BRD-11** | [D4 Multi-Cloud Integration](BRD-11_d4_multi_cloud.md) | D4 Multi-Cloud | GCP, AWS, Azure, Kubernetes connectors | Draft |
| **BRD-12** | [D5 Data Persistence & Storage](BRD-12_d5_data_persistence.md) | D5 Storage | Firestore/PostgreSQL, BigQuery, RLS | Draft |
| **BRD-13** | [D6 REST APIs & Integrations](BRD-13_d6_rest_apis.md) | D6 APIs | AG-UI streaming, REST admin, webhooks | Draft |
| **BRD-14** | [D7 Security Architecture](BRD-14_d7_security.md) | D7 Security | Defense-in-depth, RBAC, tenant isolation | Draft |

---

## Reference Materials

| Source | Location | Description |
|--------|----------|-------------|
| PROJECT_DEFINITION | [00_REF/PROJECT_DEFINITION.md](../00_REF/PROJECT_DEFINITION.md) | Full project definition |
| Foundation Specs | [00_REF/foundation/](../00_REF/foundation/) | F1-F7 technical specifications |
| ADRs | [00_REF/domain/architecture/adr/](../00_REF/domain/architecture/adr/) | Architectural decisions |
| Core Specs | [00_REF/domain/](../00_REF/domain/) | Implementation specifications |

---

## Adaptation Notes

Foundation BRDs were adapted from Trading Nexus v4.2 with these domain replacements:

| Trading Nexus Term | Cloud Cost Monitoring Term |
|--------------------|---------------------------|
| trading platform | cost monitoring platform |
| paper trading | sandbox mode |
| live trading | production mode |
| execute_trade | execute_remediation |
| portfolios | cloud_accounts |
| strategies | policies |

---

## Traceability

- **Upstream:** Business stakeholder requirements
- **Downstream:** PRD layer (pending)
