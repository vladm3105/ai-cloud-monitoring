---
title: "REQ-05: F5 Self-Sustaining Operations Atomic Requirements"
tags:
  - req
  - layer-7-artifact
  - f5-selfops
  - foundation-module
  - shared-architecture
custom_fields:
  document_type: req
  artifact_type: REQ
  layer: 7
  module_id: F5
  module_name: Self-Sustaining Operations
  spec_ready_score: 90
  ctr_ready_score: 90
  schema_version: "1.1"
---

# REQ-05: F5 Self-Sustaining Operations Atomic Requirements

**MVP Scope**: This requirement document focuses on essential, SPEC-ready requirements for MVP delivery.

## 1. Document Control

| Item | Details |
|------|---------|
| **Status** | Draft |
| **Version** | 1.0.0 |
| **Date Created** | 2026-02-09 |
| **Last Updated** | 2026-02-09 |
| **Author** | Platform Operations Team |
| **Priority** | P2 (High) |
| **Category** | Reliability |
| **Infrastructure Type** | Compute / Observability |
| **Source Document** | SYS-05 Sections 4.1-4.4 |
| **Verification Method** | Integration Test |
| **Assigned Team** | Site Reliability Engineering |
| **SPEC-Ready Score** | ✅ 90% (Target: ≥90%) |
| **CTR-Ready Score** | ✅ 90% (Target: ≥90%) |
| **Template Version** | 1.1 |

---

## 2. Requirement Description

### 2.1 Statement

**The system SHALL** provide automated health monitoring, incident detection, AI-powered root cause analysis, and YAML-based playbook execution for platform self-healing capabilities.

### 2.2 Context

F5 Self-Sustaining Operations enables the platform to detect, diagnose, and respond to operational issues with minimal human intervention. It consumes telemetry from F3 Observability and uses Vertex AI Claude for intelligent RCA. For MVP, manual approval is required before playbook execution.

### 2.3 Use Case

**Primary Flow**:
1. Health monitor polls service endpoints every 5 seconds
2. Degradation detected and incident created
3. RCA engine analyzes logs/metrics with Vertex AI
4. Playbook suggested to operator
5. Operator approves, playbook executes

**Error Flow**:
- When RCA fails, system SHALL fall back to rule-based diagnosis
- When playbook fails, system SHALL halt and notify operator

---

## 3. Functional Specification

### 3.1 Core Functionality

**Required Capabilities**:
- **REQ.05.01.01 Health Monitor**: Poll service health endpoints via Cloud Run Jobs
- **REQ.05.01.02 Incident Manager**: Detect, classify, and track operational incidents
- **REQ.05.01.03 RCA Engine**: Analyze incidents using Vertex AI + rule-based fallback
- **REQ.05.01.04 Playbook Executor**: Execute YAML-based remediation playbooks

### 3.2 Business Rules

**ID Format**: `REQ.05.21.SS` (Validation Rule)

| Rule ID | Condition | Action |
|---------|-----------|--------|
| REQ.05.21.01 | IF health check fails 3x | THEN create incident |
| REQ.05.21.02 | IF incident severity = CRITICAL | THEN page on-call immediately |
| REQ.05.21.03 | IF playbook requires approval | THEN wait for operator |
| REQ.05.21.04 | IF playbook step fails | THEN abort and alert |

### 3.3 Input/Output Specification

**Inputs**:

| Parameter | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| health_endpoint | string | Yes | Valid URL | Service health URL |
| incident | object | Conditional | Incident schema | Incident details |
| playbook_id | string | Conditional | Valid playbook | Playbook identifier |

**Outputs**:

| Field | Type | Description |
|-------|------|-------------|
| health_status | object | Aggregated health status |
| incident_id | string | Created incident ID |
| rca_result | object | Root cause analysis |
| playbook_result | object | Execution outcome |

### 3.4 Interface Protocol

```python
from typing import Protocol, Dict, Any, List, Literal
from datetime import datetime

class SelfOpsService(Protocol):
    """Interface for F5 self-sustaining operations."""

    async def check_health(
        self,
        endpoint: str,
        timeout_ms: int = 5000
    ) -> HealthResult:
        """
        Check service health.

        Args:
            endpoint: Health check URL
            timeout_ms: Request timeout

        Returns:
            HealthResult with status and latency
        """
        raise NotImplementedError("method not implemented")

    async def create_incident(
        self,
        title: str,
        severity: Literal["LOW", "MEDIUM", "HIGH", "CRITICAL"],
        source: str,
        details: Dict[str, Any]
    ) -> str:
        """Create and classify incident."""
        raise NotImplementedError("method not implemented")

    async def analyze_root_cause(
        self,
        incident_id: str
    ) -> RCAResult:
        """Perform root cause analysis."""
        raise NotImplementedError("method not implemented")

    async def execute_playbook(
        self,
        playbook_id: str,
        incident_id: str,
        approved_by: str
    ) -> PlaybookResult:
        """Execute remediation playbook."""
        raise NotImplementedError("method not implemented")
```

---

## 4. Interface Definition

### 4.1 API Contract

**Endpoint**: `POST /api/v1/ops/incidents`

**Request**:
```json
{
  "title": "Redis connection failures",
  "severity": "HIGH",
  "source": "health_monitor",
  "details": {
    "service": "f1_iam",
    "error_rate": 0.15,
    "affected_endpoints": ["/api/v1/auth/login"]
  }
}
```

**Response (Success)**:
```json
{
  "incident_id": "inc_abc123",
  "created_at": "2026-02-09T10:30:00Z",
  "severity": "HIGH",
  "status": "OPEN",
  "suggested_playbook": "redis_restart"
}
```

### 4.2 Data Schema

```python
from pydantic import BaseModel, Field
from datetime import datetime
from typing import Dict, Any, Literal, List

class Incident(BaseModel):
    """Incident data structure."""
    incident_id: str
    title: str
    severity: Literal["LOW", "MEDIUM", "HIGH", "CRITICAL"]
    source: str
    status: Literal["OPEN", "INVESTIGATING", "RESOLVED", "CLOSED"]
    created_at: datetime
    resolved_at: datetime = None
    details: Dict[str, Any] = {}

class Playbook(BaseModel):
    """Playbook definition."""
    id: str
    name: str
    trigger: str
    approval_required: bool = True
    steps: List[Dict[str, Any]]
```

---

## 5. Error Handling

### 5.1 Error Catalog

| Error Code | HTTP Status | Condition | User Message | System Action |
|------------|-------------|-----------|--------------|---------------|
| OPS_001 | 408 | Health check timeout | Service unreachable | Create incident |
| OPS_002 | 500 | RCA failed | Analysis failed | Use rule fallback |
| OPS_003 | 400 | Invalid playbook | Playbook not found | Reject execution |
| OPS_004 | 500 | Playbook step failed | Remediation failed | Abort, notify |

### 5.2 Recovery Strategy

| Error Type | Retry? | Fallback | Alert |
|------------|--------|----------|-------|
| Health check timeout | Yes (3x) | Mark unhealthy | After 3 failures |
| RCA failure | No | Rule-based analysis | Log only |
| Playbook failure | No | Manual intervention | Immediate |

### 5.3 Exception Definitions

```python
class SelfOpsError(Exception):
    """Base exception for F5 operations errors."""
    pass

class HealthCheckError(SelfOpsError):
    """Raised when health check fails."""
    pass

class RCAError(SelfOpsError):
    """Raised when root cause analysis fails."""
    pass

class PlaybookExecutionError(SelfOpsError):
    """Raised when playbook execution fails."""
    def __init__(self, step: str, details: str):
        self.step = step
        self.details = details
```

---

## 6. Quality Attributes

**ID Format**: `REQ.05.02.SS` (Quality Attribute)

### 6.1 Performance (REQ.05.02.01)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Health check cycle | < @threshold: PRD.05.perf.health.p99 (5s) | Timer |
| MTTD | < @threshold: PRD.05.perf.mttd (1 min) | Incident timing |
| RCA generation | < @threshold: PRD.05.perf.rca (30s) | Timer |
| MTTR | < @threshold: PRD.05.perf.mttr (5 min) | Incident timing |

### 6.2 Security (REQ.05.02.02)

- [x] Playbook authorization: F1 IAM integration
- [x] Incident access: Trust level based masking
- [x] Audit logging: All operations logged to F4

### 6.3 Reliability (REQ.05.02.03)

- Service uptime: @threshold: PRD.05.sla.uptime (99.9%)
- RCA accuracy: > 80% correct diagnosis
- Playbook success: > 95% execution success

---

## 7. Configuration

### 7.1 Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| HEALTH_CHECK_INTERVAL | duration | 5s | Check frequency |
| HEALTH_FAILURE_THRESHOLD | int | 3 | Failures before incident |
| RCA_TIMEOUT | duration | 30s | RCA generation timeout |
| PLAYBOOK_APPROVAL_TIMEOUT | duration | 15m | Approval wait time |

### 7.2 Feature Flags

| Flag | Default | Description |
|------|---------|-------------|
| F5_AI_RCA | true | Enable AI-powered RCA |
| F5_AUTO_REMEDIATION | false | Enable auto-remediation |

### 7.3 Configuration Schema

```yaml
f5_config:
  health:
    interval_seconds: 5
    timeout_ms: 5000
    failure_threshold: 3
  incident:
    notification_channels:
      critical: ["pagerduty"]
      high: ["pagerduty", "slack"]
      medium: ["slack"]
      low: ["email"]
  rca:
    timeout_seconds: 30
    model: "gemini-1.5-flash"
  playbook:
    approval_timeout_minutes: 15
    auto_remediation: false
```

---

## 8. Testing Requirements

### 8.1 Unit Tests

| Test Case | Input | Expected Output | Coverage |
|-----------|-------|-----------------|----------|
| **[Logic] Health Check** | Valid endpoint | Status returned | REQ.05.01.01 |
| **[Logic] Incident Creation** | Failure event | Incident created | REQ.05.01.02 |
| **[Logic] RCA Analysis** | Incident context | Root cause | REQ.05.01.03 |
| **[State] Failure Threshold** | 3 failures | Incident triggered | REQ.05.21.01 |
| **[Edge] RCA Timeout** | Slow AI response | Fallback used | REQ.05.01.03 |

### 8.2 Integration Tests

- [ ] End-to-end health monitoring
- [ ] Incident creation and notification
- [ ] Vertex AI RCA generation
- [ ] Playbook execution flow

### 8.3 BDD Scenarios

**Feature**: Self-Sustaining Operations
**File**: `04_BDD/BDD-05_f5_selfops/BDD-05.01_operations.feature`

| Scenario | Priority | Status |
|----------|----------|--------|
| Health check detects service failure | P1 | Pending |
| Incident created on threshold breach | P1 | Pending |
| RCA provides actionable analysis | P1 | Pending |
| Playbook executes after approval | P1 | Pending |

---

## 9. Acceptance Criteria

**ID Format**: `REQ.05.06.SS` (Acceptance Criteria)

### 9.1 Functional Acceptance

| Criteria ID | Criterion | Measurable Outcome | Status |
|-------------|-----------|-------------------|--------|
| REQ.05.06.01 | Health monitoring works | Status reported < 5s | [ ] |
| REQ.05.06.02 | Incidents created | Incident ID returned | [ ] |
| REQ.05.06.03 | RCA generated | Analysis < 30s | [ ] |
| REQ.05.06.04 | Playbook executes | Steps completed | [ ] |
| REQ.05.06.05 | Notifications sent | On-call paged | [ ] |

### 9.2 Quality Acceptance

| Criteria ID | Criterion | Target | Status |
|-------------|-----------|--------|--------|
| REQ.05.06.06 | MTTD | < 1 minute | [ ] |
| REQ.05.06.07 | MTTR | < 5 minutes | [ ] |
| REQ.05.06.08 | RCA accuracy | > 80% | [ ] |

---

## 10. Traceability

### 10.1 Upstream Sources

| Source Type | Document ID | Element Reference | Relationship |
|-------------|-------------|-------------------|--------------|
| BRD | BRD-05 | BRD.05.07.02 | Primary business need |
| PRD | PRD-05 | PRD.05.08.01 | Product requirement |
| EARS | EARS-05 | EARS.05.01.01-04 | Formal requirements |
| BDD | BDD-05 | BDD.05.01.01 | Acceptance test |
| ADR | ADR-05 | — | Architecture decision |
| SYS | SYS-05 | SYS.05.01.01-04 | System requirement |

### 10.2 Downstream Artifacts

| Artifact | Status | Relationship |
|----------|--------|--------------|
| SPEC-05 | TBD | Technical specification |
| TASKS-05 | TBD | Implementation tasks |

### 10.3 Traceability Tags

```markdown
@brd: BRD-05
@prd: PRD-05
@ears: EARS-05
@bdd: BDD-05
@adr: ADR-05
@sys: SYS-05
```

### 10.4 Cross-Links

```markdown
@depends: REQ-03 (F3 telemetry source)
@discoverability: REQ-06 (F6 infrastructure health)
```

---

## 11. Implementation Notes

### 11.1 Technical Approach

Implement using Cloud Run Jobs for scheduled health checks. Use Vertex AI Claude (gemini-1.5-flash) for RCA with structured prompt. Parse YAML playbooks with PyYAML and execute async steps.

### 11.2 Code Location

- **Primary**: `src/foundation/f5_selfops/`
- **Tests**: `tests/foundation/test_f5_selfops/`

### 11.3 Dependencies

| Package/Service | Version | Purpose |
|-----------------|---------|---------|
| aiohttp | 3.9+ | Health check HTTP |
| google-cloud-aiplatform | 1.40+ | Vertex AI |
| pyyaml | 6.0+ | Playbook parsing |
| google-cloud-bigquery | 3.14+ | Incident storage |

---

**Document Version**: 1.0.0
**Template Version**: 1.1 (MVP)
**Last Updated**: 2026-02-09
