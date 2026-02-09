# AI Cloud Cost Monitoring - Claude Instructions

## Project Overview

**Project**: AI Cloud Cost Monitoring Platform v4.2
**Documentation Framework**: Specification-Driven Development (SDD)
**Architecture**: AI Agent-Based (Primary)

---

## Mandatory Skill Usage Rules

### Rule 1: Always Use Skills for Artifact Generation

When generating SDD artifacts (Layers 1-11), you MUST invoke the corresponding skill. Never bypass skills by directly reading/writing files.

| Artifact | Required Skill | Validator Skill |
|----------|----------------|-----------------|
| BRD (Layer 1) | `doc-brd` or `doc-brd-autopilot` | `doc-brd-validator` |
| PRD (Layer 2) | `doc-prd` or `doc-prd-autopilot` | `doc-prd-validator` |
| EARS (Layer 3) | `doc-ears` or `doc-ears-autopilot` | `doc-ears-validator` |
| BDD (Layer 4) | `doc-bdd` or `doc-bdd-autopilot` | `doc-bdd-validator` |
| ADR (Layer 5) | `doc-adr` or `doc-adr-autopilot` | `doc-adr-validator` |
| SYS (Layer 6) | `doc-sys` or `doc-sys-autopilot` | `doc-sys-validator` |
| REQ (Layer 7) | `doc-req` or `doc-req-autopilot` | `doc-req-validator` |
| CTR (Layer 8) | `doc-ctr` or `doc-ctr-autopilot` | `doc-ctr-validator` |
| SPEC (Layer 9) | `doc-spec` or `doc-spec-autopilot` | `doc-spec-validator` |
| TSPEC (Layer 10) | `doc-tspec` or `doc-tspec-autopilot` | `doc-tspec-validator` |
| TASKS (Layer 11) | `doc-tasks` or `doc-tasks-autopilot` | `doc-tasks-validator` |

### Rule 2: Follow Complete Autopilot Workflow

When using autopilot skills (e.g., `doc-prd-autopilot`), execute ALL phases:

1. **Phase 1**: Dependency Analysis - DO NOT SKIP
2. **Phase 2**: BRD Readiness Validation - DO NOT SKIP
3. **Phase 3**: PRD Generation with Template - DO NOT SKIP
4. **Phase 4**: PRD Validation (`doc-prd-validator`) - DO NOT SKIP
5. **Phase 5**: Final Review - DO NOT SKIP
6. **Phase 6**: Continue/Parallel Processing
7. **Phase 7**: Summary Report

**CRITICAL**: Never skip validation phases (Phase 4-5) even when generating multiple artifacts in batch.

### Rule 3: Template Compliance is Mandatory

All artifacts MUST follow their respective templates regardless of source document structure:

| Template | Location | Required Sections |
|----------|----------|-------------------|
| PRD-MVP-TEMPLATE | `ai_dev_flow/02_PRD/PRD-MVP-TEMPLATE.md` | 17 sections (15 mandatory) |
| BRD-MVP-TEMPLATE | `ai_dev_flow/01_BRD/BRD-MVP-TEMPLATE.md` | 18 sections |

**DO NOT abbreviate structure based on source document size or complexity.**

### Rule 4: Validator Must Pass Before Completion

Never mark an artifact as "complete" or "generated" until:

1. Validator skill has been invoked
2. All ERROR-level issues are resolved
3. EARS-Ready/SYS-Ready score meets threshold (≥85% MVP, ≥90% full)

### Rule 5: Re-Read Template Before Each Generation

When generating multiple artifacts in batch:
- Re-read the template before EACH artifact
- Do not rely on memory from previous generations
- Validate structure matches template after creation

---

## Error Prevention Checklist

Before generating any SDD artifact:

- [ ] Identified the correct skill for this artifact type
- [ ] Read the skill's SKILL.md file to understand workflow
- [ ] Read the template file to understand required sections
- [ ] Planned to run validator after generation

After generating each artifact:

- [ ] Invoked validator skill
- [ ] Confirmed all ERROR issues resolved
- [ ] Confirmed score meets threshold
- [ ] Verified all required sections present

---

## Common Anti-Patterns to Avoid

| Anti-Pattern | Why It's Wrong | Correct Approach |
|--------------|----------------|------------------|
| Direct file write for artifacts | Bypasses template and validation | Use skill system |
| Abbreviating sections for "simpler" modules | Violates template compliance | All modules use full template |
| Skipping validation for batch efficiency | Allows errors to propagate | Validate each artifact inline |
| Assuming structure from source document | Template defines structure, not source | Always follow template |
| Marking complete before validation | No quality gate | Validator must pass first |

---

## Project-Specific Configuration

### Document Locations

| Artifact Type | Directory |
|---------------|-----------|
| BRD | `docs/01_BRD/` |
| PRD | `docs/02_PRD/` |
| Reference | `docs/00_REF/` |
| Templates | `ai_dev_flow/` |
| Skills | `.claude/skills/` |

### Module Structure

**Foundation Modules (F1-F7)**: Domain-agnostic, reusable across projects
**Domain Modules (D1-D7)**: Cost monitoring-specific

Both module types use the SAME template structure. No abbreviation for domain modules.

### Scoring Thresholds

| Score Type | MVP Threshold | Full Threshold |
|------------|---------------|----------------|
| PRD-Ready | ≥90% | ≥90% |
| EARS-Ready | ≥85% | ≥90% |
| SYS-Ready | ≥85% | ≥90% |

---

## Quick Reference Commands

```bash
# Generate PRD with proper workflow
/doc-prd-autopilot BRD-XX

# Validate existing PRD
/doc-prd-validator docs/02_PRD/

# Check skill requirements
Read .claude/skills/doc-prd-autopilot/SKILL.md
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-09 | Initial creation - Added skill usage rules, error prevention checklist, anti-patterns |
