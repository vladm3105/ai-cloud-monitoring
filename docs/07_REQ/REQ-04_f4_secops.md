---
title: "REQ-04: F4 Security Operations Atomic Requirements"
tags:
  - req
  - layer-7-artifact
  - f4-secops
  - foundation-module
  - shared-architecture
custom_fields:
  document_type: req
  artifact_type: REQ
  layer: 7
  module_id: F4
  module_name: Security Operations
  spec_ready_score: 94
  ctr_ready_score: 93
  schema_version: "1.1"
---

# REQ-04: F4 Security Operations Atomic Requirements

**MVP Scope**: This requirement document focuses on essential, SPEC-ready requirements for MVP delivery.

## 1. Document Control

| Item | Details |
|------|---------|
| **Status** | Draft |
| **Version** | 1.0.0 |
| **Date Created** | 2026-02-09 |
| **Last Updated** | 2026-02-09 |
| **Author** | Platform Security Team |
| **Priority** | P1 (Critical) |
| **Category** | Security |
| **Infrastructure Type** | Security / Cache / Storage |
| **Source Document** | SYS-04 Sections 4.1-4.4 |
| **Verification Method** | Integration Test / Security Test |
| **Assigned Team** | Security Operations Team |
| **SPEC-Ready Score** | ✅ 94% (Target: ≥90%) |
| **CTR-Ready Score** | ✅ 93% (Target: ≥90%) |
| **Template Version** | 1.1 |

---

## 2. Requirement Description

### 2.1 Statement

**The system SHALL** provide tamper-proof audit logging with SHA-256 hash chain, Redis-based sliding window rate limiting, statistical threat detection, and OWASP ASVS 5.0 L2 compliance enforcement.

### 2.2 Context

F4 Security Operations provides security monitoring, threat detection, and compliance enforcement for the platform. It works closely with F1 for authentication events, F3 for security telemetry, and D7 for security architecture enforcement. The system ensures 7-year audit retention for compliance.

### 2.3 Use Case

**Primary Flow**:
1. Security event received from any module
2. F4 validates event and appends to hash chain
3. Event stored in BigQuery with previous hash reference
4. Rate limiting evaluated on each request
5. Threat patterns analyzed for anomalies

**Error Flow**:
- When hash chain integrity fails, system SHALL alert immediately
- When rate limit exceeded, system SHALL return 429 with Retry-After

---

## 3. Functional Specification

### 3.1 Core Functionality

**Required Capabilities**:
- **REQ.04.01.01 Audit Logger**: Record security events with SHA-256 hash chain for tamper detection
- **REQ.04.01.02 Rate Limiter**: Enforce sliding window rate limits per IP/user/tenant
- **REQ.04.01.03 Threat Detector**: Detect anomalies using Z-score statistical analysis
- **REQ.04.01.04 Compliance Validator**: Enforce OWASP ASVS 5.0 L2 and LLM Top 10

### 3.2 Business Rules

**ID Format**: `REQ.04.21.SS` (Validation Rule)

| Rule ID | Condition | Action |
|---------|-----------|--------|
| REQ.04.21.01 | IF hash chain broken | THEN alert critical, investigate |
| REQ.04.21.02 | IF request rate > tier limit | THEN reject with 429 |
| REQ.04.21.03 | IF Z-score > 3.0 | THEN flag as anomaly |
| REQ.04.21.04 | IF ASVS violation | THEN log and optionally block |

### 3.3 Input/Output Specification

**Inputs**:

| Parameter | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| event | object | Yes | Security event schema | Security event |
| request_meta | object | Yes | IP, user_id, tenant_id | Request metadata |
| compliance_check | string | Conditional | ASVS control ID | Compliance rule |

**Outputs**:

| Field | Type | Description |
|-------|------|-------------|
| audit_id | string | Audit record identifier |
| rate_decision | object | Allow/deny with headers |
| threat_score | float | Anomaly confidence (0-1) |
| compliance_result | object | Pass/fail with details |

### 3.4 Interface Protocol

```python
from typing import Protocol, Dict, Any, Literal
from datetime import datetime

class SecurityOperationsService(Protocol):
    """Interface for F4 security operations."""

    async def log_security_event(
        self,
        event_type: str,
        severity: Literal["INFO", "WARNING", "CRITICAL"],
        actor: Dict[str, Any],
        resource: str,
        action: str,
        outcome: Literal["SUCCESS", "FAILURE"]
    ) -> str:
        """
        Log security event with hash chain.

        Args:
            event_type: Type of security event
            severity: Event severity level
            actor: Actor information (user_id, ip, role)
            resource: Target resource
            action: Action performed
            outcome: Success or failure

        Returns:
            Audit record ID

        Raises:
            AuditError: If logging fails
        """
        raise NotImplementedError("method not implemented")

    async def check_rate_limit(
        self,
        identifier: str,
        tier: Literal["ip", "user", "tenant", "agent"]
    ) -> RateLimitResult:
        """Evaluate rate limit for identifier."""
        raise NotImplementedError("method not implemented")

    async def detect_threat(
        self,
        event_stream: list
    ) -> ThreatResult:
        """Analyze events for anomalies."""
        raise NotImplementedError("method not implemented")
```

---

## 4. Interface Definition

### 4.1 API Contract

**Endpoint**: `POST /api/v1/security/audit`

**Request**:
```json
{
  "event_type": "auth.login.failure",
  "severity": "WARNING",
  "actor": {
    "user_id": "usr_123",
    "ip": "192.168.1.1"
  },
  "resource": "/api/v1/auth/login",
  "action": "authenticate",
  "outcome": "FAILURE"
}
```

**Response (Success)**:
```json
{
  "audit_id": "aud_abc123",
  "timestamp": "2026-02-09T10:30:00Z",
  "hash": "sha256:abc123...",
  "prev_hash": "sha256:xyz789..."
}
```

### 4.2 Data Schema

```python
from pydantic import BaseModel, Field
from datetime import datetime
from typing import Dict, Any, Literal

class AuditEvent(BaseModel):
    """Audit event structure."""
    event_id: str
    timestamp: datetime
    event_type: str
    severity: Literal["INFO", "WARNING", "CRITICAL"]
    actor: Dict[str, Any]
    resource: str
    action: str
    outcome: Literal["SUCCESS", "FAILURE"]
    hash: str
    prev_hash: str

class RateLimitResult(BaseModel):
    """Rate limit evaluation result."""
    allowed: bool
    remaining: int
    reset_at: datetime
    retry_after: int = None
```

---

## 5. Error Handling

### 5.1 Error Catalog

| Error Code | HTTP Status | Condition | User Message | System Action |
|------------|-------------|-----------|--------------|---------------|
| SEC_001 | 429 | Rate limit exceeded | Too many requests | Return Retry-After |
| SEC_002 | 500 | Hash chain corruption | Internal error | Alert critical |
| SEC_003 | 400 | Invalid audit event | Invalid event data | Reject |
| SEC_004 | 503 | BigQuery unavailable | Service unavailable | Buffer, retry |

### 5.2 Recovery Strategy

| Error Type | Retry? | Fallback | Alert |
|------------|--------|----------|-------|
| Rate limit exceeded | No | None | No |
| Hash chain corruption | No | Full investigation | Immediate |
| BigQuery unavailable | Yes (3x) | Local buffer | After retries |

### 5.3 Exception Definitions

```python
class SecurityError(Exception):
    """Base exception for F4 security errors."""
    pass

class RateLimitExceededError(SecurityError):
    """Raised when rate limit exceeded."""
    def __init__(self, retry_after: int):
        self.retry_after = retry_after

class HashChainCorruptionError(SecurityError):
    """Raised when hash chain integrity violated."""
    pass

class ComplianceViolationError(SecurityError):
    """Raised when compliance check fails."""
    def __init__(self, control_id: str, details: str):
        self.control_id = control_id
        self.details = details
```

---

## 6. Quality Attributes

**ID Format**: `REQ.04.02.SS` (Quality Attribute)

### 6.1 Performance (REQ.04.02.01)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Rate limit evaluation (p99) | < @threshold: PRD.04.perf.ratelimit.p99 (10ms) | APM traces |
| Security validation (p99) | < @threshold: PRD.04.perf.validation.p99 (100ms) | APM traces |
| Audit write (p99) | < 50ms | APM traces |
| Session revocation | < 1000ms | Event timing |

### 6.2 Security (REQ.04.02.02)

- [x] Audit immutability: SHA-256 hash chain
- [x] OWASP ASVS 5.0 L2: Full compliance
- [x] LLM Top 10: Prompt injection prevention

### 6.3 Reliability (REQ.04.02.03)

- Audit retention: 7 years (compliance requirement)
- Hash verification: Daily integrity check
- Availability: @threshold: PRD.04.sla.uptime (99.9%)

---

## 7. Configuration

### 7.1 Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| RATE_LIMIT_IP | int | 100/min | IP rate limit |
| RATE_LIMIT_USER | int | 300/min | User rate limit |
| RATE_LIMIT_TENANT | int | 1000/min | Tenant rate limit |
| RATE_LIMIT_AGENT | int | 10/min | Agent rate limit |
| THREAT_Z_THRESHOLD | float | 3.0 | Anomaly threshold |

### 7.2 Feature Flags

| Flag | Default | Description |
|------|---------|-------------|
| F4_THREAT_DETECTION | true | Enable threat detection |
| F4_STRICT_COMPLIANCE | false | Block on compliance failure |

### 7.3 Configuration Schema

```yaml
f4_config:
  rate_limiting:
    ip: 100
    user: 300
    tenant: 1000
    agent: 10
    window_seconds: 60
  audit:
    retention_years: 7
    hash_algorithm: sha256
    verify_interval: daily
  threat:
    z_threshold: 3.0
    detection_window: 300  # 5 minutes
```

---

## 8. Testing Requirements

### 8.1 Unit Tests

| Test Case | Input | Expected Output | Coverage |
|-----------|-------|-----------------|----------|
| **[Logic] Hash Chain** | Two events | Chained hashes | REQ.04.01.01 |
| **[Logic] Rate Limit** | 101 requests | 429 on 101st | REQ.04.01.02 |
| **[Logic] Z-Score** | Anomalous pattern | Score > 3.0 | REQ.04.01.03 |
| **[Validation] Invalid Event** | Missing fields | Rejection | REQ.04.01.01 |
| **[State] Hash Corruption** | Modified entry | Alert raised | REQ.04.21.01 |

### 8.2 Integration Tests

- [ ] Audit log write and hash verification
- [ ] Rate limiting across distributed instances
- [ ] Threat detection alert generation
- [ ] OWASP compliance validation

### 8.3 BDD Scenarios

**Feature**: Security Operations
**File**: `04_BDD/BDD-04_f4_secops/BDD-04.01_security.feature`

| Scenario | Priority | Status |
|----------|----------|--------|
| Audit event logged with hash chain | P1 | Pending |
| Rate limit blocks excessive requests | P1 | Pending |
| Threat anomaly detected and alerted | P1 | Pending |
| Hash chain corruption detected | P1 | Pending |

---

## 9. Acceptance Criteria

**ID Format**: `REQ.04.06.SS` (Acceptance Criteria)

### 9.1 Functional Acceptance

| Criteria ID | Criterion | Measurable Outcome | Status |
|-------------|-----------|-------------------|--------|
| REQ.04.06.01 | Audit events logged | Hash chain verified | [ ] |
| REQ.04.06.02 | Rate limiting works | 429 returned on excess | [ ] |
| REQ.04.06.03 | Threats detected | Alert generated | [ ] |
| REQ.04.06.04 | ASVS compliance | All controls pass | [ ] |
| REQ.04.06.05 | 7-year retention | Audit accessible | [ ] |

### 9.2 Quality Acceptance

| Criteria ID | Criterion | Target | Status |
|-------------|-----------|--------|--------|
| REQ.04.06.06 | Rate limit latency | @threshold: REQ.04.02.01 (p99 < 10ms) | [ ] |
| REQ.04.06.07 | Hash verification | Daily pass | [ ] |
| REQ.04.06.08 | Security | No critical vulnerabilities | [ ] |

---

## 10. Traceability

### 10.1 Upstream Sources

| Source Type | Document ID | Element Reference | Relationship |
|-------------|-------------|-------------------|--------------|
| BRD | BRD-04 | BRD.04.07.02 | Primary business need |
| PRD | PRD-04 | PRD.04.08.01 | Product requirement |
| EARS | EARS-04 | EARS.04.01.01-04 | Formal requirements |
| BDD | BDD-04 | BDD.04.01.01 | Acceptance test |
| ADR | ADR-04 | — | Architecture decision |
| SYS | SYS-04 | SYS.04.01.01-04 | System requirement |

### 10.2 Downstream Artifacts

| Artifact | Status | Relationship |
|----------|--------|--------------|
| CTR-04 | TBD | API contract |
| SPEC-04 | TBD | Technical specification |
| TASKS-04 | TBD | Implementation tasks |

### 10.3 Traceability Tags

```markdown
@brd: BRD-04
@prd: PRD-04
@ears: EARS-04
@bdd: BDD-04
@adr: ADR-04
@sys: SYS-04
```

### 10.4 Cross-Links

```markdown
@depends: REQ-01 (F1 auth events); REQ-03 (F3 telemetry)
@discoverability: REQ-14 (D7 security architecture)
```

---

## 11. Implementation Notes

### 11.1 Technical Approach

Implement using Python with Redis for rate limiting sliding window. Use BigQuery streaming insert for audit logs with hash chain. Apply Z-score calculation using NumPy for threat detection.

### 11.2 Code Location

- **Primary**: `src/foundation/f4_secops/`
- **Tests**: `tests/foundation/test_f4_secops/`

### 11.3 Dependencies

| Package/Service | Version | Purpose |
|-----------------|---------|---------|
| redis-py | 5.0+ | Rate limiting |
| google-cloud-bigquery | 3.14+ | Audit storage |
| numpy | 1.26+ | Statistical analysis |
| hashlib | stdlib | SHA-256 hashing |

---

**Document Version**: 1.0.0
**Template Version**: 1.1 (MVP)
**Last Updated**: 2026-02-09
