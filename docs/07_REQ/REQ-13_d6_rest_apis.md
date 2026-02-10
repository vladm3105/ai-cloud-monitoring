---
title: "REQ-13: D6 REST APIs & Integrations Atomic Requirements"
tags:
  - req
  - layer-7-artifact
  - d6-rest-apis
  - domain-module
custom_fields:
  document_type: req
  artifact_type: REQ
  layer: 7
  module_id: D6
  module_name: REST APIs & Integrations
  spec_ready_score: 92
  ctr_ready_score: 91
  schema_version: "1.1"
---

# REQ-13: D6 REST APIs & Integrations Atomic Requirements

**MVP Scope**: This requirement document focuses on essential, SPEC-ready requirements for MVP delivery.

## 1. Document Control

| Item | Details |
|------|---------|
| **Status** | Draft |
| **Version** | 1.0.0 |
| **Date Created** | 2026-02-09T00:00:00 |
| **Last Updated** | 2026-02-09T00:00:00 |
| **Author** | API Team |
| **Priority** | P1 (Critical) |
| **Category** | API |
| **Infrastructure Type** | Compute / Network |
| **Source Document** | SYS-13 Sections 4.1-4.4 |
| **Verification Method** | Integration Test / BDD |
| **Assigned Team** | API Team |
| **SPEC-Ready Score** | ✅ 92% (Target: ≥90%) |
| **CTR-Ready Score** | ✅ 91% (Target: ≥90%) |
| **Template Version** | 1.1 |

---

## 2. Requirement Description

### 2.1 Statement

**The system SHALL** provide FastAPI-based REST APIs with SSE streaming for AG-UI, distributed rate limiting via Redis, Cloud Armor WAF protection, and automatic OpenAPI documentation with Pydantic models.

### 2.2 Context

D6 REST APIs provides the API gateway and integration layer for all platform access. It implements four API surfaces: AG-UI Streaming (SSE), REST Admin APIs, Webhooks, and A2A Gateway. All external access flows through D6 with F1 JWT validation and rate limiting.

### 2.3 Use Case

**Primary Flow**:
1. Client sends request to API endpoint
2. Cloud Armor validates against WAF rules
3. F1 JWT validated and claims extracted
4. Rate limit checked against Redis
5. Request routed to appropriate handler
6. Response returned (JSON or SSE stream)

**Error Flow**:
- When rate limit exceeded, system SHALL return 429 with Retry-After
- When auth fails, system SHALL return 401 with RFC 7807 error

---

## 3. Functional Specification

### 3.1 Core Functionality

**Required Capabilities**:
- **REQ.13.01.01 SSE Streaming Gateway**: Stream D1 agent responses via SSE
- **REQ.13.01.02 REST Admin API**: CRUD endpoints for platform resources
- **REQ.13.01.03 Rate Limiter**: Distributed rate limiting via Redis
- **REQ.13.01.04 Webhook Dispatcher**: Send event notifications to external systems

### 3.2 Business Rules

**ID Format**: `REQ.13.21.SS` (Validation Rule)

| Rule ID | Condition | Action |
|---------|-----------|--------|
| REQ.13.21.01 | IF no F1 JWT | THEN reject with 401 |
| REQ.13.21.02 | IF rate limit exceeded | THEN return 429 |
| REQ.13.21.03 | IF invalid input | THEN return 400 with RFC 7807 |
| REQ.13.21.04 | IF webhook delivery fails | THEN retry with backoff |

### 3.3 Input/Output Specification

**Inputs**:

| Parameter | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| Authorization | header | Yes | Bearer JWT | F1 auth token |
| Content-Type | header | Conditional | application/json | Request content type |
| body | object | Conditional | Pydantic schema | Request body |

**Outputs**:

| Field | Type | Description |
|-------|------|-------------|
| data | object/array | Response data |
| error | object | RFC 7807 error (on failure) |
| stream | SSE | Event stream (for chat) |

### 3.4 Interface Protocol

```python
from typing import Protocol, AsyncIterator, Dict, Any

class APIGateway(Protocol):
    """Interface for D6 API gateway operations."""

    async def stream_chat(
        self,
        message: str,
        session_id: str,
        authorization: str
    ) -> AsyncIterator[str]:
        """
        Stream chat response via SSE.

        Args:
            message: User message
            session_id: F2 session ID
            authorization: F1 Bearer token

        Yields:
            SSE event strings

        Raises:
            AuthError: If JWT invalid
            RateLimitError: If rate exceeded
        """
        raise NotImplementedError("method not implemented")

    async def handle_request(
        self,
        method: str,
        path: str,
        body: Dict[str, Any],
        headers: Dict[str, str]
    ) -> Response:
        """Handle REST API request."""
        raise NotImplementedError("method not implemented")

    async def dispatch_webhook(
        self,
        event: str,
        payload: Dict[str, Any],
        webhook_id: str
    ) -> bool:
        """Dispatch webhook notification."""
        raise NotImplementedError("method not implemented")
```

---

## 4. Interface Definition

### 4.1 API Surfaces

| Surface | Protocol | Base Path | Purpose |
|---------|----------|-----------|---------|
| AG-UI | SSE | `/api/v1/chat` | Agent streaming |
| REST | JSON | `/api/v1/*` | CRUD operations |
| Webhooks | POST | `/webhooks/*` | Event notifications |
| A2A | JSON | `/a2a/*` | Agent-to-agent |

### 4.2 OpenAPI Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/costs` | GET | Query costs |
| `/api/v1/costs/breakdown` | GET | Cost breakdown |
| `/api/v1/alerts` | GET/POST | Alert management |
| `/api/v1/reports` | GET/POST | Report management |
| `/api/v1/workspaces` | CRUD | Workspace management |
| `/api/v1/chat` | POST (SSE) | Agent chat |
| `/docs` | GET | OpenAPI UI |
| `/openapi.json` | GET | OpenAPI spec |

### 4.3 Error Format (RFC 7807)

```json
{
  "type": "https://api.costmonitor.io/errors/validation",
  "title": "Validation Error",
  "status": 400,
  "detail": "Field 'date_range' is required",
  "instance": "/api/v1/costs/query"
}
```

---

## 5. Error Handling

### 5.1 Error Catalog

| Error Code | HTTP Status | Condition | User Message | System Action |
|------------|-------------|-----------|--------------|---------------|
| API_001 | 401 | Invalid JWT | Unauthorized | Return error |
| API_002 | 403 | Insufficient permissions | Forbidden | Return error |
| API_003 | 429 | Rate limit exceeded | Too many requests | Return Retry-After |
| API_004 | 400 | Validation error | Invalid request | Return RFC 7807 |
| API_005 | 500 | Internal error | Internal error | Log, return error |

### 5.2 Recovery Strategy

| Error Type | Retry? | Fallback | Alert |
|------------|--------|----------|-------|
| Auth failure | No | None | No |
| Rate limit | Client retry | None | No |
| Internal error | No | None | Log |
| Webhook delivery | Yes (3x) | Dead letter | After retries |

### 5.3 Exception Definitions

```python
from fastapi import HTTPException

class APIError(HTTPException):
    """Base API exception with RFC 7807 support."""
    def __init__(
        self,
        status_code: int,
        error_type: str,
        title: str,
        detail: str,
        instance: str = None
    ):
        self.error_type = error_type
        self.title = title
        self.instance = instance
        super().__init__(status_code=status_code, detail=detail)

class RateLimitError(APIError):
    """Rate limit exceeded error."""
    def __init__(self, retry_after: int):
        self.retry_after = retry_after
        super().__init__(
            status_code=429,
            error_type="/errors/rate_limit",
            title="Rate Limit Exceeded",
            detail="Too many requests"
        )
```

---

## 6. Quality Attributes

**ID Format**: `REQ.13.02.SS` (Quality Attribute)

### 6.1 Performance (REQ.13.02.01)

| Metric | Target | Measurement |
|--------|--------|-------------|
| SSE first-token (p95) | < @threshold: PRD.13.perf.sse.first_token (1s) | Timer |
| REST response (p95) | < @threshold: PRD.13.perf.rest.p95 (1s) | APM |
| Rate limit check | < 5ms | Timer |
| API uptime | > 99.5% | Monitoring |

### 6.2 Security (REQ.13.02.02)

- [x] F1 JWT validation: All requests
- [x] Cloud Armor WAF: OWASP CRS rules
- [x] TLS 1.3: Required
- [x] CORS: Configurable origins

### 6.3 Reliability (REQ.13.02.03)

- Webhook delivery: > 99% success
- Error responses: RFC 7807 compliant
- Rate limiting: Distributed consistency

---

## 7. Configuration

### 7.1 Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| RATE_LIMIT_IP | int | 100/min | IP rate limit |
| RATE_LIMIT_USER | int | 300/min | User rate limit |
| RATE_LIMIT_TENANT | int | 1000/min | Tenant rate limit |
| WEBHOOK_TIMEOUT | duration | 10s | Webhook timeout |
| WEBHOOK_RETRIES | int | 3 | Max retries |

### 7.2 Feature Flags

| Flag | Default | Description |
|------|---------|-------------|
| D6_WEBHOOKS | true | Enable webhooks |
| D6_A2A_GATEWAY | false | Enable A2A gateway |

### 7.3 Configuration Schema

```yaml
d6_config:
  api:
    version: "v1"
    docs_enabled: true
    cors_origins:
      - "https://app.costmonitor.io"
  rate_limiting:
    ip: 100
    user: 300
    tenant: 1000
    agent: 10
    window_seconds: 60
  webhooks:
    enabled: true
    timeout_seconds: 10
    max_retries: 3
    retry_delay_seconds: 5
```

---

## 8. Testing Requirements

### 8.1 Unit Tests

| Test Case | Input | Expected Output | Coverage |
|-----------|-------|-----------------|----------|
| **[Logic] JWT Validation** | Valid token | Claims extracted | REQ.13.01.02 |
| **[Logic] Rate Limit** | 101 requests | 429 on 101st | REQ.13.01.03 |
| **[Logic] SSE Streaming** | Chat message | Event stream | REQ.13.01.01 |
| **[Validation] Invalid Body** | Bad JSON | 400 RFC 7807 | REQ.13.21.03 |
| **[Edge] Webhook Retry** | Delivery fail | 3 retries | REQ.13.01.04 |

### 8.2 Integration Tests

- [ ] End-to-end REST CRUD
- [ ] SSE streaming flow
- [ ] Rate limiting enforcement
- [ ] Webhook delivery and retry

### 8.3 BDD Scenarios

**Feature**: REST APIs
**File**: `04_BDD/BDD-13_d6_api/BDD-13.01_api.feature`

| Scenario | Priority | Status |
|----------|----------|--------|
| Authenticated user queries costs | P1 | Pending |
| Rate limit blocks excessive requests | P1 | Pending |
| Chat streams response via SSE | P1 | Pending |
| Webhook delivered to endpoint | P2 | Pending |

---

## 9. Acceptance Criteria

**ID Format**: `REQ.13.06.SS` (Acceptance Criteria)

### 9.1 Functional Acceptance

| Criteria ID | Criterion | Measurable Outcome | Status |
|-------------|-----------|-------------------|--------|
| REQ.13.06.01 | SSE streaming works | First token < 1s | [ ] |
| REQ.13.06.02 | REST APIs work | Response < 1s | [ ] |
| REQ.13.06.03 | Rate limiting works | 429 returned | [ ] |
| REQ.13.06.04 | OpenAPI generated | /docs accessible | [ ] |
| REQ.13.06.05 | RFC 7807 errors | Compliant format | [ ] |

### 9.2 Quality Acceptance

| Criteria ID | Criterion | Target | Status |
|-------------|-----------|--------|--------|
| REQ.13.06.06 | API latency | @threshold: REQ.13.02.01 (p95 < 1s) | [ ] |
| REQ.13.06.07 | Availability | > 99.5% | [ ] |
| REQ.13.06.08 | Webhook delivery | > 99% | [ ] |

---

## 10. Traceability

### 10.1 Upstream Sources

| Source Type | Document ID | Element Reference | Relationship |
|-------------|-------------|-------------------|--------------|
| BRD | BRD-13 | BRD.13.07.02 | Primary business need |
| PRD | PRD-13 | PRD.13.08.01 | Product requirement |
| EARS | EARS-13 | EARS.13.01.01-04 | Formal requirements |
| BDD | BDD-13 | BDD.13.01.01 | Acceptance test |
| ADR | ADR-13 | — | Architecture decision |
| SYS | SYS-13 | SYS.13.01.01-04 | System requirement |

### 10.2 Downstream Artifacts

| Artifact | Status | Relationship |
|----------|--------|--------------|
| CTR-13 | TBD | API contract |
| SPEC-13 | TBD | Technical specification |
| TASKS-13 | TBD | Implementation tasks |

### 10.3 Traceability Tags

```markdown
@brd: BRD-13
@prd: PRD-13
@ears: EARS-13
@bdd: BDD-13
@adr: ADR-13
@sys: SYS-13
```

### 10.4 Cross-Links

```markdown
@depends: REQ-01 (F1 JWT); REQ-04 (F4 rate limiting)
@discoverability: REQ-10 (D3 API consumer); REQ-08 (D1 SSE provider)
```

---

## 11. Implementation Notes

### 11.1 Technical Approach

Use FastAPI with Pydantic for automatic OpenAPI generation. Implement SSE with sse-starlette. Use Redis for distributed rate limiting with sliding window algorithm.

### 11.2 Code Location

- **Primary**: `src/domain/d6_api/`
- **Tests**: `tests/domain/test_d6_api/`

### 11.3 Dependencies

| Package/Service | Version | Purpose |
|-----------------|---------|---------|
| fastapi | 0.109+ | API framework |
| pydantic | 2.6+ | Data validation |
| sse-starlette | 1.8+ | SSE streaming |
| redis-py | 5.0+ | Rate limiting |

---

**Document Version**: 1.0.0
**Template Version**: 1.1 (MVP)
**Last Updated**: 2026-02-09T00:00:00
