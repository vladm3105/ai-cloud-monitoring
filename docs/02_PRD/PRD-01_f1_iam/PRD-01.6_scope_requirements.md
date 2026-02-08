---
title: "PRD-01.6: F1 Identity & Access Management - Scope & Requirements"
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
  section: 6
  module_id: F1
  module_name: Identity & Access Management
---

# PRD-01.6: F1 Identity & Access Management - Scope & Requirements

> **Navigation**: [Index](PRD-01.0_index.md) | [Previous: Success Metrics](PRD-01.5_success_metrics.md) | [Next: User Stories](PRD-01.7_user_stories.md)
> **Parent**: PRD-01 | **Section**: 6 of 17

---

## 6. Scope & Requirements

@brd: BRD.01.01.01, BRD.01.01.02, BRD.01.01.03, BRD.01.01.04, BRD.01.01.05, BRD.01.01.06, BRD.01.01.07

---

### 6.1 In-Scope (MVP Core Features)

| # | Feature | Priority | Description | BRD Reference |
|---|---------|----------|-------------|---------------|
| 1 | Multi-Provider Authentication | P1-Must | Auth0 primary, email/password fallback, mTLS, API keys | BRD.01.01.01 |
| 2 | 4D Authorization Matrix | P1-Must | ACTION x SKILL x RESOURCE x ZONE decision engine | BRD.01.01.02 |
| 3 | Trust Level System | P1-Must | 4-tier hierarchy (Viewer→Admin) with zone access | BRD.01.01.03 |
| 4 | MFA Enforcement | P1-Must | TOTP and WebAuthn for Trust 3+ users | BRD.01.01.04 |
| 5 | Token Management | P1-Must | JWT access tokens (30min), refresh rotation (7d) | BRD.01.01.05 |
| 6 | User Profile System | P1-Must | Profile storage with encrypted credential management | BRD.01.01.06 |
| 7 | Session Revocation API | P1-Must | Bulk session termination, instant propagation | BRD.01.01.07 |
| 8 | SCIM 2.0 Provisioning | P2-Should | Automated user lifecycle from enterprise IdP | BRD.01.01.08 |
| 9 | Passwordless Authentication | P2-Should | WebAuthn as primary auth option | BRD.01.01.09 |
| 10 | Role Hierarchy | P2-Should | Trust level inheritance, reduced configuration | BRD.01.01.11 |

---

### 6.2 Dependencies

| Dependency | Type | Status | Impact | Owner |
|------------|------|--------|--------|-------|
| Auth0 Tenant | External | Available | Blocking for OAuth | Platform Team |
| GCP Secret Manager | Technical | Available | Required for credentials | Infrastructure |
| PostgreSQL (F6) | Technical | Available | User profile storage | Infrastructure |
| Redis Cluster (F6) | Technical | Available | Session state, pub/sub | Infrastructure |
| F7 Config Manager | Technical | Available | Policy configuration | Platform Team |

**Fallback Paths**:
- Auth0 unavailable: Email/password fallback with local validation
- Redis unavailable: PostgreSQL session fallback (degraded performance)

---

### 6.3 Out-of-Scope (Post-MVP)

| Feature | Reason | Target Phase |
|---------|--------|--------------|
| Device Trust Verification (GAP-F1-04) | Requires MDM integration | Phase 2 |
| Time-Based Access Policies (GAP-F1-06) | Complex timezone handling | Phase 2 |
| Domain-specific skills | Injected by D1-D7 layers | N/A |
| Agent-specific permissions | Injected by D1 | N/A |
| Mobile app authentication | Different auth flow | v1.3.0 |
| Enterprise SAML/OIDC | Auth0 handles federation | v1.3.0 |

---

### 6.4 Scope Boundaries

```
┌─────────────────────────────────────────────────────────────┐
│                      F1 IAM Module                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ IN-SCOPE                                             │   │
│  │ • Authentication (Auth0, fallback, mTLS, API keys)   │   │
│  │ • Authorization (4D Matrix, trust levels)            │   │
│  │ • Token Management (JWT, refresh)                    │   │
│  │ • Session Management (revocation, limits)            │   │
│  │ • User Profiles (encrypted storage)                  │   │
│  │ • MFA (TOTP, WebAuthn)                              │   │
│  │ • SCIM 2.0 Provisioning                             │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ OUT-OF-SCOPE                                         │   │
│  │ • Domain-specific skills (injected at runtime)       │   │
│  │ • Business logic (handled by D1-D7)                  │   │
│  │ • UI components (handled by frontend)                │   │
│  │ • Mobile flows (future roadmap)                      │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

> **Navigation**: [Index](PRD-01.0_index.md) | [Previous: Success Metrics](PRD-01.5_success_metrics.md) | [Next: User Stories](PRD-01.7_user_stories.md)
