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

## New ADRs (docs/05_ADR/)

New architectural decisions during implementation will be created here.

| ID | Title | Status |
|----|-------|--------|
| ADR-02 | [F2 Session & Context Management](ADR-02_f2_session.md) | Accepted |
| ADR-03 | F3 Observability Architecture Decisions | Accepted |
| ADR-04 | F4 Security Operations Architecture Decisions | Accepted |
| ADR-06 | F6 Infrastructure Platform Architecture Decisions | Accepted |
| ADR-07 | [F7 Configuration Manager Architecture Decisions](ADR-07_f7_config.md) | Accepted |
| ADR-08 | D1 Agent Orchestration Architecture | Accepted |
| ADR-10 | D3 User Experience Architecture | Accepted |
| ADR-12 | [D5 Data Persistence & Storage Architecture](ADR-12_d5_data_persistence.md) | Proposed |
| ADR-14 | [D7 Security Architecture](ADR-14_d7_security.md) | Accepted |

---

## Traceability

- **Upstream:** BRD-01, PRD-01
- **Downstream:** SYS-01, SPEC-01
