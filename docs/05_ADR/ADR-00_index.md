# ADR Index - AI Cloud Cost Monitoring

**Project:** AI Cloud Cost Monitoring Platform
**Layer:** 05_ADR (Architecture Decision Records)
**Status:** Active

---

## Reference ADRs (in 00_REF/domain/architecture/adr/)

Existing architectural decisions are maintained in [00_REF/domain/architecture/adr/](../00_REF/domain/architecture/adr/):

| ID | Title | Status |
|----|-------|--------|
| ADR-001 | Use MCP Servers | Accepted |
| ADR-002 | GCP-Only First | Accepted |
| ADR-003 | Use BigQuery Not TimescaleDB | Accepted |
| ADR-004 | Cloud Run Not Kubernetes | Accepted |
| ADR-005 | Use LiteLLM for LLMs | Accepted |
| ADR-006 | Cloud-Native Task Queues Not Celery | Accepted |
| ADR-007 | Grafana Plus AG-UI Hybrid | Accepted |
| ADR-008 | Database Strategy MVP | Accepted |
| ADR-009 | Hybrid Agent Registration Pattern | Accepted |
| ADR-010 | Agent Card Specification | Accepted |

---

## Module ADRs (docs/05_ADR/)

Architecture decisions for each module derived from BRD Architecture Decision Requirements.

### Foundation Modules (F1-F7)

| ID | Module | Title | Status |
|----|--------|-------|--------|
| ADR-01 | F1 | [Identity & Access Management Architecture](ADR-01_f1_iam.md) | Accepted |
| ADR-02 | F2 | [Session & Context Management Architecture](ADR-02_f2_session.md) | Accepted |
| ADR-03 | F3 | [Observability Architecture](ADR-03_f3_observability.md) | Accepted |
| ADR-04 | F4 | [Security Operations Architecture](ADR-04_f4_secops.md) | Accepted |
| ADR-05 | F5 | [Self-Sustaining Operations Architecture](ADR-05_f5_selfops.md) | Accepted |
| ADR-06 | F6 | [Infrastructure Platform Architecture](ADR-06_f6_infrastructure.md) | Accepted |
| ADR-07 | F7 | [Configuration Manager Architecture](ADR-07_f7_config.md) | Accepted |

### Domain Modules (D1-D7)

| ID | Module | Title | Status |
|----|--------|-------|--------|
| ADR-08 | D1 | [Agent Orchestration Architecture](ADR-08_d1_agent_orchestration.md) | Accepted |
| ADR-09 | D2 | [Cloud Cost Analytics Architecture](ADR-09_d2_cost_analytics.md) | Accepted |
| ADR-10 | D3 | [User Experience Architecture](ADR-10_d3_user_experience.md) | Accepted |
| ADR-11 | D4 | [Multi-Cloud Integration Architecture](ADR-11_d4_multi_cloud.md) | Accepted |
| ADR-12 | D5 | [Data Persistence & Storage Architecture](ADR-12_d5_data_persistence.md) | Accepted |
| ADR-13 | D6 | [REST APIs & Integrations Architecture](ADR-13_d6_rest_apis.md) | Accepted |
| ADR-14 | D7 | [Security Architecture](ADR-14_d7_security.md) | Accepted |

---

## Traceability

- **Upstream:** BRD-01 through BRD-14 (Architecture Decision Requirements sections)
- **Downstream:** SYS-01 through SYS-14
