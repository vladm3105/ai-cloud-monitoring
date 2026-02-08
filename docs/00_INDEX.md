# AI Cloud Cost Monitoring - Document Flow Index

**Project:** AI Cloud Cost Monitoring Platform
**Framework:** Document Flow Framework v2.0 (MVP Track)
**Status:** Foundation BRDs Complete

---

## Layer Overview

| Layer | Folder | Status | Next Action |
|-------|--------|--------|-------------|
| L0 | [00_REF](00_REF/) | Complete | Reference documentation |
| L1 | [01_BRD](01_BRD/) | **7 Foundation BRDs** | Create Domain BRDs (08-11) |
| L2 | [02_PRD](02_PRD/) | Index Ready | Awaiting BRDs |
| L3 | [03_EARS](03_EARS/) | Index Ready | Awaiting PRD-01 |
| L4 | [04_BDD](04_BDD/) | Index Ready | Awaiting EARS-01 |
| L5 | [05_ADR](05_ADR/) | Index Ready | Reference 00_REF/domain/architecture/adr/ |
| L6 | [06_SYS](06_SYS/) | Index Ready | Awaiting ADRs |
| L7 | [07_REQ](07_REQ/) | Index Ready | Awaiting PRD-01 |
| L8 | [08_CTR](08_CTR/) | Index Ready | Awaiting REQ-01 |
| L9 | [09_SPEC](09_SPEC/) | Index Ready | Awaiting CTR-01 |
| L10 | [10_TSPEC](10_TSPEC/) | Index Ready | Awaiting BDD-01 |
| L11 | [11_TASKS](11_TASKS/) | Index Ready | Awaiting SPEC-01 |
| L12 | [12_IPLAN](12_IPLAN/) | Index Ready | Awaiting TASKS-01 |

---

## Reference Materials (00_REF/)

Pre-existing architectural documentation:

| Category | Location | Contents |
|----------|----------|----------|
| Foundation | [00_REF/foundation/](00_REF/foundation/) | F1-F7 technical specifications |
| ADRs | [00_REF/domain/architecture/adr/](00_REF/domain/architecture/adr/) | 10 architectural decisions |
| Architecture | [00_REF/domain/architecture/](00_REF/domain/architecture/) | System diagrams, MVP architecture |
| Domain Specs | [00_REF/domain/](00_REF/domain/) | 8 specification documents |
| Deployment | [00_REF/GCP-DEPLOYMENT.md](00_REF/GCP-DEPLOYMENT.md) | GCP setup guide |
| Project Def | [00_REF/PROJECT_DEFINITION.md](00_REF/PROJECT_DEFINITION.md) | Full project definition |
| Handoff | [00_REF/HANDOFF.md](00_REF/HANDOFF.md) | Developer handoff document |

---

## Foundation BRDs (Complete)

Adapted from Trading Nexus v4.2:

| BRD | Module | Status |
|-----|--------|--------|
| [BRD-01](01_BRD/BRD-01_f1_iam.md) | F1 IAM | Draft |
| [BRD-02](01_BRD/BRD-02_f2_session.md) | F2 Session | Draft |
| [BRD-03](01_BRD/BRD-03_f3_observability.md) | F3 Observability | Draft |
| [BRD-04](01_BRD/BRD-04_f4_secops.md) | F4 SecOps | Draft |
| [BRD-05](01_BRD/BRD-05_f5_selfops.md) | F5 Self-Ops | Draft |
| [BRD-06](01_BRD/BRD-06_f6_infrastructure.md) | F6 Infrastructure | Draft |
| [BRD-07](01_BRD/BRD-07_f7_config.md) | F7 Config | Draft |

---

## Next Steps

1. **Review Foundation BRDs** for domain-specific accuracy
2. **Create Domain BRDs** (BRD-08 to BRD-11)
3. **Proceed to PRD layer** for feature specifications

---

## Framework Reference

- Template source: `/opt/data/docs_flow_framework/ai_dev_flow/`
- Workflow guide: `/opt/data/docs_flow_framework/ai_dev_flow/MVP_WORKFLOW_GUIDE.md`
