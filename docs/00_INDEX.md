# AI Cloud Cost Monitoring - Document Flow Index

**Project:** AI Cloud Cost Monitoring Platform
**Framework:** Document Flow Framework v2.0 (MVP Track)
**Status:** Setup Complete, Ready for BRD Creation

---

## Layer Overview

| Layer | Folder | Status | Next Action |
|-------|--------|--------|-------------|
| L1 | [01_BRD](01_BRD/) | Index Ready | Create BRD-01 |
| L2 | [02_PRD](02_PRD/) | Index Ready | Awaiting BRD-01 |
| L3 | [03_EARS](03_EARS/) | Index Ready | Awaiting PRD-01 |
| L4 | [04_BDD](04_BDD/) | Index Ready | Awaiting EARS-01 |
| L5 | [05_ADR](05_ADR/) | Index Ready | Reference REF/docs/adr/ |
| L6 | [06_SYS](06_SYS/) | Index Ready | Awaiting ADRs |
| L7 | [07_REQ](07_REQ/) | Index Ready | Awaiting PRD-01 |
| L8 | [08_CTR](08_CTR/) | Index Ready | Awaiting REQ-01 |
| L9 | [09_SPEC](09_SPEC/) | Index Ready | Awaiting CTR-01 |
| L10 | [10_TSPEC](10_TSPEC/) | Index Ready | Awaiting BDD-01 |
| L11 | [11_TASKS](11_TASKS/) | Index Ready | Awaiting SPEC-01 |
| L12 | [12_IPLAN](12_IPLAN/) | Index Ready | Awaiting TASKS-01 |

---

## Reference Materials (REF/)

Pre-existing architectural documentation:

| Category | Location | Contents |
|----------|----------|----------|
| ADRs | [REF/docs/adr/](../REF/docs/adr/) | 10 architectural decisions |
| Core Specs | [REF/core/](../REF/core/) | 8 specification documents |
| Deployment | [REF/GCP-DEPLOYMENT.md](../REF/GCP-DEPLOYMENT.md) | GCP setup guide |
| Project Def | [REF/PROJECT_DEFINITION.md](../REF/PROJECT_DEFINITION.md) | Full project definition |
| Handoff | [REF/HANDOFF.md](../REF/HANDOFF.md) | Developer handoff document |

---

## Quick Start - MVP Workflow

1. **Create BRD-01** using [BRD-MVP-TEMPLATE](https://github.com/docs_flow_framework/ai_dev_flow/01_BRD/BRD-MVP-TEMPLATE.md)
   - Source: REF/PROJECT_DEFINITION.md, REF/core/executive-summary.md

2. **Create PRD-01** using PRD-MVP-TEMPLATE
   - Focus: Phase 1 MVP (GCP cost monitoring)

3. **Create EARS-01** mapping PRD features to logic statements

4. **Create BDD-01.feature** with critical scenarios

5. **Continue through layers** following traceability links

---

## Framework Reference

- Template source: `/opt/data/docs_flow_framework/ai_dev_flow/`
- Workflow guide: `/opt/data/docs_flow_framework/ai_dev_flow/MVP_WORKFLOW_GUIDE.md`
- Validation: `python3 ai_dev_flow/scripts/validate_documentation_paths.py --root ai_dev_flow`
