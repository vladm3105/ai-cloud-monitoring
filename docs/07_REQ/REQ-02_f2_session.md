---
title: "REQ-02: F2 Session & Context Management Atomic Requirements"
tags:
  - req
  - layer-7-artifact
  - f2-session
  - foundation-module
  - shared-architecture
custom_fields:
  document_type: req
  artifact_type: REQ
  layer: 7
  module_id: F2
  module_name: Session & Context Management
  spec_ready_score: 91
  ctr_ready_score: 90
  schema_version: "1.1"
---

# REQ-02: F2 Session & Context Management Atomic Requirements

**MVP Scope**: This requirement document focuses on essential, SPEC-ready requirements for MVP delivery.

## 1. Document Control

| Item | Details |
|------|---------|
| **Status** | Draft |
| **Version** | 1.0.0 |
| **Date Created** | 2026-02-09T00:00:00 |
| **Last Updated** | 2026-02-09T00:00:00 |
| **Author** | Platform Architecture Team |
| **Priority** | P1 (Critical) |
| **Category** | Functional |
| **Infrastructure Type** | Cache / Database |
| **Source Document** | SYS-02 Sections 4.1-4.4 |
| **Verification Method** | Integration Test / BDD |
| **Assigned Team** | Platform Team |
| **SPEC-Ready Score** | ✅ 91% (Target: ≥90%) |
| **CTR-Ready Score** | ✅ 90% (Target: ≥90%) |
| **Template Version** | 1.1 |

---

## 2. Requirement Description

### 2.1 Statement

**The system SHALL** manage user sessions with three-tier hierarchical memory (Session/Workspace/Profile), provide context assembly for downstream services, and implement automatic failover from Redis to PostgreSQL.

### 2.2 Context

F2 Session & Context Management provides stateful session handling and context enrichment for all platform interactions. D1 Agent Orchestration consumes assembled context for AI interactions. The system must support 10,000 concurrent sessions with sub-10ms lookup latency.

### 2.3 Use Case

**Primary Flow**:
1. User session created after F1 authentication
2. System stores session in Redis with device fingerprint
3. System assembles context from F1 profile + session + workspace
4. Downstream services receive enriched context

**Error Flow**:
- When Redis unavailable, system SHALL failover to PostgreSQL within 5 seconds
- When context stale, system SHALL return data with staleness flag

---

## 3. Functional Specification

### 3.1 Core Functionality

**Required Capabilities**:
- **REQ.02.01.01 Session Manager**: Create, validate, renew, and terminate user sessions with UUID v4 tokens
- **REQ.02.01.02 Memory Manager**: Manage hierarchical memory across Session/Workspace/Profile tiers
- **REQ.02.01.03 Context Manager**: Assemble enriched context for agents and UI
- **REQ.02.01.04 Workspace Manager**: Persist workspace data across sessions

### 3.2 Business Rules

**ID Format**: `REQ.02.21.SS` (Validation Rule)

| Rule ID | Condition | Action |
|---------|-----------|--------|
| REQ.02.21.01 | IF session idle > 30 minutes | THEN expire session |
| REQ.02.21.02 | IF session age > 24 hours | THEN force re-authentication |
| REQ.02.21.03 | IF memory size > tier limit | THEN reject write |
| REQ.02.21.04 | IF Redis unavailable | THEN failover to PostgreSQL |

### 3.3 Input/Output Specification

**Inputs**:

| Parameter | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| session_id | string | Yes | UUID format | Session identifier |
| user_id | string | Yes | UUID format | User identifier |
| memory_key | string | Conditional | Max 256 chars | Memory storage key |
| tier | enum | Conditional | session/workspace/profile | Target memory tier |

**Outputs**:

| Field | Type | Description |
|-------|------|-------------|
| session | object | Session state object |
| context | object | Assembled context for consumers |
| memory | object | Memory data for specified tier |

### 3.4 Interface Protocol

```python
from typing import Protocol, Optional, Dict, Any, Literal
from datetime import datetime

class SessionManager(Protocol):
    """Interface for F2 session operations."""

    async def create_session(
        self,
        user_id: str,
        trust_level: int,
        device_fingerprint: str
    ) -> Session:
        """
        Create new user session.

        Args:
            user_id: User identifier from F1
            trust_level: Trust level from F1 token
            device_fingerprint: Client device hash

        Returns:
            Session object with token and metadata

        Raises:
            SessionError: If creation fails
        """
        raise NotImplementedError("method not implemented")

    async def get_session(self, session_id: str) -> Optional[Session]:
        """Retrieve session by ID with failover support."""
        raise NotImplementedError("method not implemented")

    async def assemble_context(
        self,
        session_id: str,
        target: Literal["agent", "ui", "event"]
    ) -> Context:
        """Assemble enriched context for target consumer."""
        raise NotImplementedError("method not implemented")
```

---

## 4. Interface Definition

### 4.1 API Contract

**Endpoint**: `POST /api/v1/session`

**Request**:
```json
{
  "user_id": "usr_abc123",
  "trust_level": 2,
  "device_fingerprint": "fp_hash_xyz"
}
```

**Response (Success)**:
```json
{
  "session_id": "sess_def456",
  "created_at": "2026-02-09T10:30:00Z",
  "expires_at": "2026-02-09T11:00:00Z",
  "idle_timeout": 1800
}
```

### 4.2 Data Schema

```python
from pydantic import BaseModel, Field
from datetime import datetime
from typing import Dict, Any, Optional

class Session(BaseModel):
    """Session data structure."""
    session_id: str
    user_id: str
    trust_level: int = Field(..., ge=1, le=4)
    device_fingerprint: str
    created_at: datetime
    last_accessed: datetime
    memory: Dict[str, Any] = {}

class Context(BaseModel):
    """Assembled context structure."""
    user: Dict[str, Any]
    session: Dict[str, Any]
    workspace: Optional[Dict[str, Any]] = None
    memory: Dict[str, Any] = {}
```

---

## 5. Error Handling

### 5.1 Error Catalog

| Error Code | HTTP Status | Condition | User Message | System Action |
|------------|-------------|-----------|--------------|---------------|
| SESS_001 | 404 | Session not found | Session expired | Prompt re-login |
| SESS_002 | 400 | Invalid session token | Invalid session | Force re-auth |
| SESS_003 | 413 | Memory limit exceeded | Storage limit reached | Reject write |
| SESS_004 | 503 | Storage unavailable | Service temporarily unavailable | Activate failover |

### 5.2 Recovery Strategy

| Error Type | Retry? | Fallback | Alert |
|------------|--------|----------|-------|
| Session not found | No | Force re-login | No |
| Redis unavailable | Yes (1x) | PostgreSQL | Immediate |
| Memory limit | No | Reject write | No |
| Context assembly | Yes (1x) | Partial context | After retry |

### 5.3 Exception Definitions

```python
class SessionError(Exception):
    """Base exception for F2 session errors."""
    pass

class SessionNotFoundError(SessionError):
    """Raised when session does not exist."""
    pass

class SessionExpiredError(SessionError):
    """Raised when session has expired."""
    pass

class MemoryLimitError(SessionError):
    """Raised when memory tier limit exceeded."""
    def __init__(self, tier: str, limit: int, current: int):
        self.tier = tier
        self.limit = limit
        self.current = current
```

---

## 6. Quality Attributes

**ID Format**: `REQ.02.02.SS` (Quality Attribute)

### 6.1 Performance (REQ.02.02.01)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Session lookup (p95) | < @threshold: PRD.02.perf.session.p95 (10ms) | APM traces |
| Context assembly (p95) | < @threshold: PRD.02.perf.context.p95 (50ms) | APM traces |
| Memory operations (p95) | < 20ms (session), <100ms (workspace) | APM traces |
| Concurrent sessions | @threshold: PRD.02.scale.sessions (10,000) | Load test |

### 6.2 Security (REQ.02.02.02)

- [x] Input validation: Session tokens validated
- [x] Authentication: Requires valid F1 JWT
- [x] Data protection: AES-256-GCM encryption for memory data

### 6.3 Reliability (REQ.02.02.03)

- Failover time: < 5 seconds Redis to PostgreSQL
- Data durability: Session data persisted via Redis AOF
- Availability: @threshold: PRD.02.sla.uptime (99.9%)

---

## 7. Configuration

### 7.1 Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| SESSION_IDLE_TTL | duration | 30m | Session idle timeout |
| SESSION_ABSOLUTE_TTL | duration | 24h | Absolute session timeout |
| MEMORY_SESSION_LIMIT | bytes | 100KB | Session tier size limit |
| MEMORY_WORKSPACE_LIMIT | bytes | 10MB | Workspace tier size limit |

### 7.2 Feature Flags

| Flag | Default | Description |
|------|---------|-------------|
| F2_FAILOVER_ENABLED | true | Enable PostgreSQL failover |
| F2_CONTEXT_CACHE | true | Cache assembled context |

### 7.3 Configuration Schema

```yaml
f2_config:
  session:
    idle_ttl: 1800  # @threshold: PRD.02.session.idle_ttl
    absolute_ttl: 86400
  memory:
    session_limit: 102400  # 100KB
    workspace_limit: 10485760  # 10MB
  failover:
    enabled: true
    timeout_ms: 5000
```

---

## 8. Testing Requirements

### 8.1 Unit Tests

| Test Case | Input | Expected Output | Coverage |
|-----------|-------|-----------------|----------|
| **[Logic] Session Create** | `user_id='123'` | Valid session object | REQ.02.01.01 |
| **[Logic] Context Assembly** | `session_id='sess_1'` | Merged context | REQ.02.01.03 |
| **[Validation] Memory Limit** | `data=200KB` | `MemoryLimitError` | REQ.02.21.03 |
| **[State] Session Expiry** | `idle=31min` | Session expired | REQ.02.21.01 |
| **[Edge] Failover** | Redis unavailable | PostgreSQL used | REQ.02.21.04 |

### 8.2 Integration Tests

- [ ] Session lifecycle: create, lookup, renew, terminate
- [ ] Redis to PostgreSQL failover
- [ ] Context assembly with F1 profile
- [ ] Memory tier operations

### 8.3 BDD Scenarios

**Feature**: Session Management
**File**: `04_BDD/BDD-02_f2_session/BDD-02.01_session.feature`

| Scenario | Priority | Status |
|----------|----------|--------|
| Session created on authentication | P1 | Pending |
| Session expires after idle timeout | P1 | Pending |
| Context assembled for agent | P1 | Pending |
| Failover to PostgreSQL on Redis failure | P1 | Pending |

---

## 9. Acceptance Criteria

**ID Format**: `REQ.02.06.SS` (Acceptance Criteria)

### 9.1 Functional Acceptance

| Criteria ID | Criterion | Measurable Outcome | Status |
|-------------|-----------|-------------------|--------|
| REQ.02.06.01 | Session created on auth | Session ID returned | [ ] |
| REQ.02.06.02 | Session lookup works | Session retrieved < 10ms | [ ] |
| REQ.02.06.03 | Context assembly works | Context returned < 50ms | [ ] |
| REQ.02.06.04 | Failover completes | < 5 seconds switchover | [ ] |
| REQ.02.06.05 | Memory promotion works | Data promoted between tiers | [ ] |

### 9.2 Quality Acceptance

| Criteria ID | Criterion | Target | Status |
|-------------|-----------|--------|--------|
| REQ.02.06.06 | Session lookup latency | @threshold: REQ.02.02.01 (p95 < 10ms) | [ ] |
| REQ.02.06.07 | Availability | 99.9% uptime | [ ] |
| REQ.02.06.08 | Test coverage | ≥ 85% | [ ] |

---

## 10. Traceability

### 10.1 Upstream Sources

| Source Type | Document ID | Element Reference | Relationship |
|-------------|-------------|-------------------|--------------|
| BRD | BRD-02 | BRD.02.07.02 | Primary business need |
| PRD | PRD-02 | PRD.02.08.01 | Product requirement |
| EARS | EARS-02 | EARS.02.01.01-04 | Formal requirements |
| BDD | BDD-02 | BDD.02.01.01 | Acceptance test |
| ADR | ADR-02 | — | Architecture decision |
| SYS | SYS-02 | SYS.02.01.01-04 | System requirement |

### 10.2 Downstream Artifacts

| Artifact | Status | Relationship |
|----------|--------|--------------|
| CTR-02 | TBD | API contract |
| SPEC-02 | TBD | Technical specification |
| TASKS-02 | TBD | Implementation tasks |

### 10.3 Traceability Tags

```markdown
@brd: BRD-02
@prd: PRD-02
@ears: EARS-02
@bdd: BDD-02
@adr: ADR-02
@sys: SYS-02
```

### 10.4 Cross-Links

```markdown
@depends: REQ-01 (F1 authentication required)
@discoverability: REQ-08 (D1 context consumer); REQ-10 (D3 context consumer)
```

---

## 11. Implementation Notes

### 11.1 Technical Approach

Implement using Python FastAPI with async Redis client. Use connection pooling for both Redis and PostgreSQL. Apply parallel fetching pattern for context assembly (F1 profile + session + workspace fetched concurrently).

### 11.2 Code Location

- **Primary**: `src/foundation/f2_session/`
- **Tests**: `tests/foundation/test_f2_session/`

### 11.3 Dependencies

| Package/Service | Version | Purpose |
|-----------------|---------|---------|
| redis-py | 5.0+ | Session storage |
| asyncpg | 0.29+ | PostgreSQL fallback |
| cryptography | 42.0+ | Memory encryption |
| aiohttp | 3.9+ | Async HTTP client |

---

**Document Version**: 1.0.0
**Template Version**: 1.1 (MVP)
**Last Updated**: 2026-02-09T00:00:00
