# BRD Index - AI Cloud Cost Monitoring

**Project:** AI Cloud Cost Monitoring Platform
**Layer:** 01_BRD (Business Requirements)
**Status:** Foundation BRDs Complete

---

## Hybrid BRD Structure

The AI Cost Monitoring Platform uses a **Hybrid Structure** (adapted from Trading Nexus v4.2):
- **7 Foundation BRDs (BRD-01 to BRD-07)**: Domain-agnostic, portable infrastructure modules
- **Domain BRDs (BRD-08+)**: Project-specific cost monitoring capabilities

---

## Foundation BRDs (Portable, Domain-Agnostic)

| BRD ID | Title | Module | Source | Status |
|:-------|:------|:-------|:-------|:-------|
| **BRD-01** | [F1 Identity & Access Management](BRD-01_f1_iam.md) | F1 IAM | Adapted from Trading Nexus | Draft |
| **BRD-02** | [F2 Session & Context Management](BRD-02_f2_session.md) | F2 Session | Adapted from Trading Nexus | Draft |
| **BRD-03** | [F3 Observability](BRD-03_f3_observability.md) | F3 Observability | Adapted from Trading Nexus | Draft |
| **BRD-04** | [F4 Security Operations](BRD-04_f4_secops.md) | F4 SecOps | Adapted from Trading Nexus | Draft |
| **BRD-05** | [F5 Self-Sustaining Operations](BRD-05_f5_selfops.md) | F5 Self-Ops | Adapted from Trading Nexus | Draft |
| **BRD-06** | [F6 Infrastructure](BRD-06_f6_infrastructure.md) | F6 Infrastructure | Adapted from Trading Nexus | Draft |
| **BRD-07** | [F7 Configuration Manager](BRD-07_f7_config.md) | F7 Config | Adapted from Trading Nexus | Draft |

---

## Domain BRDs (Cost Monitoring-Specific)

| BRD ID | Title | Module | Scope | Status |
|:-------|:------|:-------|:------|:-------|
| **BRD-08** | [D1 Agent Orchestration & MCP](BRD-08_d1_agent_orchestration.md) | D1 Agents | Coordinator, domain agents, MCP servers | Draft |
| **BRD-09** | [D2 Cloud Cost Analytics](BRD-09_d2_cost_analytics.md) | D2 Analytics | BigQuery, cost analysis, recommendations | Draft |
| **BRD-10** | [D3 User Experience](BRD-10_d3_user_experience.md) | D3 UX | Grafana + AG-UI hybrid interface | Draft |
| **BRD-11** | [D4 Multi-Cloud Integration](BRD-11_d4_multi_cloud.md) | D4 Multi-Cloud | GCP, AWS, Azure, Kubernetes connectors | Draft |

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
- **Downstream:** PRD layer (02_PRD)
