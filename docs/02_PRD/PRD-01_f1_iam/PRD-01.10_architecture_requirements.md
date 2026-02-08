---
title: "PRD-01.10: F1 Identity & Access Management - Architecture Requirements"
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
  section: 10
  module_id: F1
  module_name: Identity & Access Management
---

# PRD-01.10: F1 Identity & Access Management - Architecture Requirements

> **Navigation**: [Index](PRD-01.0_index.md) | [Previous: Quality Attributes](PRD-01.9_quality_attributes.md) | [Next: Constraints & Assumptions](PRD-01.11_constraints_assumptions.md)
> **Parent**: PRD-01 | **Section**: 10 of 17

---

## 10. Architecture Requirements

> Architecture topics requiring ADRs. Full ADRs live separately in `docs/05_ADR/`.

@brd: BRD.01.10.01, BRD.01.10.02, BRD.01.10.03, BRD.01.10.04, BRD.01.10.05, BRD.01.10.06, BRD.01.10.07

---

### 10.1 Infrastructure (PRD.01.32.01)

**Status**: [X] Selected

**Business Driver**: Session persistence across service restarts with sub-second access latency.

**Selected Approach**: Redis Cluster with AOF persistence

**Rationale**:
- Meets p99 <5ms session lookup requirement
- AOF persistence survives process restarts
- Cluster mode enables horizontal scaling for 10K concurrent users
- Native TTL support for session expiration
- Pub/sub capability for session revocation broadcast

**PRD Requirements**:
- Session replication strategy (Redis Sentinel)
- Failover behavior (automatic promotion)
- Cache invalidation pattern (pub/sub broadcast)

**Estimated Cost**: ~$200/month (GCP Memorystore)

---

### 10.2 Data Architecture (PRD.01.32.02)

**Status**: [X] Selected

**Business Driver**: Secure token storage for stateless authentication.

**Selected Approach**: JWT with RS256 asymmetric signing, refresh tokens hashed in database.

**Rationale**:
- Asymmetric signing allows public key verification
- Refresh token hashing prevents token theft from database
- Stateless access tokens reduce session lookup overhead

**PRD Requirements**:
- Key rotation policy (90-day rotation)
- Token claim schema (user_id, trust_level, zones, exp, iat, jti)

---

### 10.3 Integration (PRD.01.32.03)

**Status**: [X] Selected

**Business Driver**: Enterprise SSO and user federation.

**Selected Approach**: Auth0 as primary IdP with OIDC federation.

**Rationale**:
- Auth0 provides enterprise SSO out-of-box
- OIDC standard enables Google/Azure AD federation
- Managed service reduces operational overhead

**PRD Requirements**:
- Provider failover strategy (email/password fallback)
- Token exchange flow (Auth0 token → platform JWT)

---

### 10.4 Security (PRD.01.32.04)

**Status**: [X] Selected

**Business Driver**: Balance security with user experience for MFA.

**Selected Approach**: Auth0 MFA (TOTP + WebAuthn) with platform-native fallback.

**Rationale**:
- TOTP provides universal compatibility
- WebAuthn offers phishing-resistant authentication
- Platform fallback ensures availability

**PRD Requirements**:
- Recovery flow design (backup codes)
- Backup code generation (10 single-use codes)

---

### 10.5 Observability (PRD.01.32.05)

**Status**: [X] Selected

**Business Driver**: Security compliance and incident investigation.

**Selected Approach**: Hybrid (Cloud Logging + BigQuery export).

**Rationale**:
- Cloud Logging for real-time monitoring (30-day hot storage)
- BigQuery export for long-term retention (5-year compliance)
- Cost-effective compared to dedicated SIEM

**Audit Events Captured**:
- auth.login.success, auth.login.failure
- auth.logout, auth.session.revoked
- authz.decision (allow/deny with context)
- mfa.enrolled, mfa.verified, mfa.failed
- token.issued, token.refreshed, token.revoked

**PRD Requirements**:
- Log retention policy (30 days hot, 5 years cold)
- Alerting thresholds (5 failed logins/5min triggers alert)

---

### 10.6 AI/ML (PRD.01.32.06)

**Status**: [ ] N/A

**Business Driver**: F1 IAM is a foundation module focused on authentication and authorization infrastructure.

**Approach**: N/A for F1 IAM Module. AI/ML capabilities (anomaly detection, behavioral analysis) are handled by D1 Agent Orchestration layer.

---

### 10.7 Technology Selection (PRD.01.32.07)

**Status**: [X] Selected

**Business Driver**: Secure password storage with future-proof algorithm.

**Selected Approach**: bcrypt with cost factor 12 (Argon2 for future consideration).

**Rationale**:
- bcrypt is well-established and widely supported
- Cost factor 12 provides ~250ms hash time
- Argon2 migration path defined for future

**PRD Requirements**:
- Migration path for algorithm upgrades (transparent on next password change)

---

### 10.8 Technology Stack Summary

| Component | MVP | Production | Notes |
|-----------|-----|------------|-------|
| Primary IdP | Firebase Auth | Auth0 | ADR-008 decision |
| Token Format | JWT (RS256) | JWT (RS256) | Asymmetric signing |
| Password Hashing | Firebase managed | bcrypt (cost 12) | Platform-managed |
| MFA | Firebase (optional) | TOTP + WebAuthn | Required for Trust 3+ |
| Secrets | GCP Secret Manager | GCP Secret Manager | F6 dependency |
| Database | Firestore | PostgreSQL | ADR-008 decision |
| Session Cache | - | Redis Cluster | F6 dependency |

---

> **Navigation**: [Index](PRD-01.0_index.md) | [Previous: Quality Attributes](PRD-01.9_quality_attributes.md) | [Next: Constraints & Assumptions](PRD-01.11_constraints_assumptions.md)
