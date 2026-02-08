---
title: "PRD-01.11: F1 Identity & Access Management - Constraints & Assumptions"
tags:
  - prd
  - foundation-module
  - f1-iam
  - layer-2-artifact
custom_fields:
  document_type: prd-section
  artifact_type: PRD
  layer: 2
  parent_doc: PRD-01
  section: 11
  module_id: F1
  module_name: Identity & Access Management
---

# PRD-01.11: F1 Identity & Access Management - Constraints & Assumptions

> **Navigation**: [Index](PRD-01.0_index.md) | [Previous: Architecture Requirements](PRD-01.10_architecture_requirements.md) | [Next: Risk Assessment](PRD-01.12_risk_assessment.md)
> **Parent**: PRD-01 | **Section**: 11 of 17

---

## 11. Constraints & Assumptions

@brd: BRD.01.03.01, BRD.01.03.02, BRD.01.03.03, BRD.01.04.01, BRD.01.04.02

---

### 11.1 Business Constraints

| ID | Constraint Category | Description | Impact | Mitigation |
|----|---------------------|-------------|--------|------------|
| PRD.01.03.01 | Platform | Auth0 as primary identity provider | Vendor dependency | Multi-provider adapter pattern |
| PRD.01.03.02 | Technology | GCP platform (Secret Manager, Cloud SQL) | Cloud lock-in | Abstract infrastructure interfaces |
| PRD.01.03.03 | Format | JWT token format (RS256) | Interoperability | Standard OIDC compliance |
| PRD.01.03.04 | Budget | Infrastructure budget ~$500/month | Resource limits | Optimize for cost efficiency |
| PRD.01.03.05 | Timeline | MVP delivery in Phase 1 | Scope pressure | Prioritize P1 requirements |

---

### 11.2 Technical Constraints

| Constraint | Description | Impact |
|------------|-------------|--------|
| Domain-Agnostic Design | F1 cannot contain business logic | Skills injected at runtime |
| Session Limit | Maximum 3 concurrent sessions per user | Security vs. convenience tradeoff |
| Token Lifetime | Access tokens expire in 30 minutes | Frequent refresh required |
| MFA Requirement | Mandatory for Trust 3+ users | User onboarding friction |

---

### 11.3 Assumptions

| ID | Assumption | Risk Level | Validation Method | Impact if False |
|----|------------|------------|-------------------|-----------------|
| PRD.01.04.01 | Auth0 availability meets 99.9% SLA | Medium | Monitor Auth0 status | Enable fallback auth immediately |
| PRD.01.04.02 | Users have MFA-capable devices | Low | Enrollment tracking | Support TOTP-only (no WebAuthn) |
| PRD.01.04.03 | Redis Cluster performance meets SLA | Low | Load testing | PostgreSQL session fallback |
| PRD.01.04.04 | GCP Secret Manager available | Low | Health checks | Local encryption key fallback |
| PRD.01.04.05 | Domain layers provide valid skill definitions | Medium | Schema validation | Reject invalid skill registrations |

---

### 11.4 Resource Constraints

| Resource | Limit | Notes |
|----------|-------|-------|
| Development Team | 2-3 engineers | F1 module scope |
| Timeline | 8-12 weeks MVP | Phase 1 delivery |
| Infrastructure Budget | ~$500/month | GCP services |
| External Dependencies | Auth0, GCP | Managed services |

---

### 11.5 Constraint/Risk Pairs

| Constraint | Associated Risk | Owner | Trigger |
|------------|-----------------|-------|---------|
| Auth0 dependency | Provider outage | Platform Team | Auth0 status page alerts |
| GCP lock-in | Migration cost | Architecture | >30% cost increase |
| MFA requirement | User friction | Product | <80% enrollment in 30 days |
| Session limits | User complaints | Product | >10% support tickets |

---

> **Navigation**: [Index](PRD-01.0_index.md) | [Previous: Architecture Requirements](PRD-01.10_architecture_requirements.md) | [Next: Risk Assessment](PRD-01.12_risk_assessment.md)
