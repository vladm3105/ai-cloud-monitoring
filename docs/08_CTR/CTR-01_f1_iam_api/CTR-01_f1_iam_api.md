---
title: "CTR-01: F1 Identity & Access Management API Contract"
tags:
  - ctr
  - layer-8-artifact
  - f1-iam
  - foundation-module
  - shared-architecture
  - api-contract
custom_fields:
  document_type: ctr
  artifact_type: CTR
  layer: 8
  module_id: F1
  module_name: Identity & Access Management
  spec_ready_score: 92
  schema_version: "1.0"
---

# CTR-01: F1 Identity & Access Management API Contract

## Document Control

| Item | Details |
|------|---------|
| **CTR ID** | CTR-01 |
| **Title** | F1 Identity & Access Management API Contract |
| **Status** | Active |
| **Version** | 1.0.0 |
| **Created** | 2026-02-11 |
| **Author** | Platform Architecture Team |
| **Owner** | Platform Security Team |
| **Last Updated** | 2026-02-11 |
| **SPEC-Ready Score** | ✅ 92% (Target: ≥90%) |

---

## 1. Contract Overview

### 1.1 Purpose

This contract defines the API interface for the F1 Identity & Access Management module, providing authentication, authorization, token management, and session management capabilities for the AI Cloud Cost Monitoring Platform.

### 1.2 Scope

| Aspect | Coverage |
|--------|----------|
| **Authentication** | Auth0 OIDC, email/password, MFA |
| **Authorization** | 4D Matrix (Action-Skill-Resource-Zone) |
| **Token Management** | JWT issuance, validation, refresh |
| **Session Management** | Redis sessions, concurrent limits |

### 1.3 Version Information

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-02-11 | Initial contract definition |

### 1.4 Contract Definition

**OpenAPI Specification**: [CTR-01_f1_iam_api.yaml](CTR-01_f1_iam_api.yaml)

---

## 2. Business Context

### 2.1 Business Need

F1 IAM serves as the authentication and authorization backbone for all platform modules. Domain modules (D1-D7) depend on F1 for secure identity verification, role-based access control, and session management.

### 2.2 Source Requirements

| Source | Reference | Description |
|--------|-----------|-------------|
| REQ-01 | Section 4.1 | API Contract specifications |
| REQ-01 | Section 4.2 | Data Schema definitions |
| REQ-01 | Section 5 | Error Handling catalog |

---

## 3. Interface Definitions

### 3.1 Authentication Endpoints

#### CTR.01.16.01: Login Endpoint

| Attribute | Value |
|-----------|-------|
| **Path** | `POST /api/v1/auth/login` |
| **Description** | Authenticate user with email/password |
| **Authentication** | None (public endpoint) |
| **Rate Limit** | 5 requests/5 minutes per IP |

#### CTR.01.16.02: OIDC Callback Endpoint

| Attribute | Value |
|-----------|-------|
| **Path** | `POST /api/v1/auth/oidc/callback` |
| **Description** | Auth0 OIDC callback handler |
| **Authentication** | None (OIDC flow) |
| **Rate Limit** | 10 requests/minute per IP |

#### CTR.01.16.03: Token Refresh Endpoint

| Attribute | Value |
|-----------|-------|
| **Path** | `POST /api/v1/auth/refresh` |
| **Description** | Refresh access token using refresh token |
| **Authentication** | Refresh token in body |
| **Rate Limit** | 30 requests/minute per user |

#### CTR.01.16.04: Logout Endpoint

| Attribute | Value |
|-----------|-------|
| **Path** | `POST /api/v1/auth/logout` |
| **Description** | Invalidate session and tokens |
| **Authentication** | Bearer token |
| **Rate Limit** | 10 requests/minute per user |

#### CTR.01.16.05: MFA Verification Endpoint

| Attribute | Value |
|-----------|-------|
| **Path** | `POST /api/v1/auth/mfa/verify` |
| **Description** | Verify MFA TOTP code |
| **Authentication** | Partial session token |
| **Rate Limit** | 5 requests/5 minutes per user |

### 3.2 Authorization Endpoints

#### CTR.01.16.06: Authorization Check Endpoint

| Attribute | Value |
|-----------|-------|
| **Path** | `POST /api/v1/authz/check` |
| **Description** | Evaluate 4D Matrix authorization |
| **Authentication** | Bearer token |
| **Rate Limit** | 1000 requests/minute (internal) |

### 3.3 Session Endpoints

#### CTR.01.16.07: Session Status Endpoint

| Attribute | Value |
|-----------|-------|
| **Path** | `GET /api/v1/session/status` |
| **Description** | Get current session information |
| **Authentication** | Bearer token |
| **Rate Limit** | 60 requests/minute per user |

#### CTR.01.16.08: Session List Endpoint

| Attribute | Value |
|-----------|-------|
| **Path** | `GET /api/v1/session/list` |
| **Description** | List all active sessions for user |
| **Authentication** | Bearer token |
| **Rate Limit** | 10 requests/minute per user |

#### CTR.01.16.09: Session Revoke Endpoint

| Attribute | Value |
|-----------|-------|
| **Path** | `DELETE /api/v1/session/{session_id}` |
| **Description** | Revoke specific session |
| **Authentication** | Bearer token |
| **Rate Limit** | 10 requests/minute per user |

---

## 4. Data Models

### 4.1 Request Models

#### CTR.01.17.01: LoginRequest

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| `email` | string | Yes | Email format, max 255 | User email address |
| `password` | string | Yes | Min 12 chars | User password |
| `mfa_code` | string | No | 6 digits | TOTP code if MFA enabled |

#### CTR.01.17.02: OIDCCallbackRequest

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| `code` | string | Yes | Non-empty | Authorization code |
| `state` | string | Yes | Non-empty | CSRF state token |

#### CTR.01.17.03: RefreshTokenRequest

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| `refresh_token` | string | Yes | Non-empty | Valid refresh token |

#### CTR.01.17.04: AuthzCheckRequest

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| `action` | string | Yes | Non-empty | Action being performed |
| `skill` | string | Yes | Non-empty | Skill context |
| `resource` | string | Yes | Non-empty | Resource identifier |
| `zone` | string | Yes | Non-empty | Zone identifier |

### 4.2 Response Models

#### CTR.01.17.05: TokenResponse

| Field | Type | Description |
|-------|------|-------------|
| `access_token` | string | JWT (RS256) with 15-minute expiry |
| `refresh_token` | string | Opaque token with 7-day expiry |
| `token_type` | string | Always "Bearer" |
| `expires_in` | integer | Seconds until access token expiry |
| `session_id` | string | Redis session identifier |

#### CTR.01.17.06: AuthzDecision

| Field | Type | Description |
|-------|------|-------------|
| `allowed` | boolean | Authorization decision |
| `reason` | string | Explanation for decision |
| `trust_level` | integer | Required trust level (1-4) |

#### CTR.01.17.07: SessionInfo

| Field | Type | Description |
|-------|------|-------------|
| `session_id` | string | Session identifier |
| `user_id` | string | User identifier |
| `created_at` | string | ISO 8601 timestamp |
| `expires_at` | string | ISO 8601 timestamp |
| `last_activity` | string | ISO 8601 timestamp |
| `device_info` | object | Device metadata |

### 4.3 JWT Claims

#### CTR.01.17.08: JWTClaims

| Field | Type | Description |
|-------|------|-------------|
| `sub` | string | User ID |
| `trust_level` | integer | Trust level (1-4) |
| `zones` | array[string] | Accessible zones |
| `exp` | integer | Expiration timestamp |
| `iat` | integer | Issued at timestamp |
| `jti` | string | Unique token identifier |

---

## 5. Error Handling

### 5.1 Error Response Format

All errors follow RFC 7807 Problem Details format:

```json
{
  "type": "https://api.example.com/errors/{error-type}",
  "title": "Human-readable title",
  "status": 401,
  "detail": "Detailed error message",
  "instance": "/api/v1/auth/login"
}
```

### 5.2 Error Catalog

#### CTR.01.20.01: Authentication Errors

| Error Code | HTTP Status | Title | Detail |
|------------|-------------|-------|--------|
| AUTH_001 | 401 | Authentication Failed | Invalid email or password |
| AUTH_002 | 401 | Token Expired | Session expired, please login |
| AUTH_003 | 403 | Insufficient Trust Level | Additional verification required |
| AUTH_004 | 429 | Rate Limit Exceeded | Too many attempts, try again later |
| AUTH_005 | 503 | Service Unavailable | Auth service temporarily unavailable |

#### CTR.01.20.02: Authorization Errors

| Error Code | HTTP Status | Title | Detail |
|------------|-------------|-------|--------|
| AUTHZ_001 | 403 | Access Denied | Insufficient permissions for this action |
| AUTHZ_002 | 403 | Zone Restricted | Access to zone not permitted |
| AUTHZ_003 | 403 | Resource Restricted | Resource access denied |

#### CTR.01.20.03: Session Errors

| Error Code | HTTP Status | Title | Detail |
|------------|-------------|-------|--------|
| SESS_001 | 401 | Session Not Found | Session does not exist or expired |
| SESS_002 | 403 | Session Limit Exceeded | Maximum concurrent sessions reached |
| SESS_003 | 401 | Session Revoked | Session has been revoked |

### 5.3 Retry Strategy

| Error Type | Retry? | Backoff | Max Retries |
|------------|--------|---------|-------------|
| AUTH_001 | No | - | - |
| AUTH_002 | Yes | Silent refresh | 1 |
| AUTH_004 | Yes | Retry-After header | 3 |
| AUTH_005 | Yes | Exponential | 3 |

---

## 6. Usage Examples

### 6.1 Successful Login

**Request**:
```http
POST /api/v1/auth/login HTTP/1.1
Host: api.example.com
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "securePassword123"
}
```

**Response** (200 OK):
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "dGhpcyBpcyBhIHJlZnJlc2ggdG9rZW4...",
  "token_type": "Bearer",
  "expires_in": 900,
  "session_id": "sess_abc123"
}
```

### 6.2 Failed Login (Invalid Credentials)

**Request**:
```http
POST /api/v1/auth/login HTTP/1.1
Host: api.example.com
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "wrongPassword"
}
```

**Response** (401 Unauthorized):
```json
{
  "type": "https://api.example.com/errors/authentication",
  "title": "Authentication Failed",
  "status": 401,
  "detail": "Invalid email or password",
  "instance": "/api/v1/auth/login"
}
```

### 6.3 Token Refresh

**Request**:
```http
POST /api/v1/auth/refresh HTTP/1.1
Host: api.example.com
Content-Type: application/json

{
  "refresh_token": "dGhpcyBpcyBhIHJlZnJlc2ggdG9rZW4..."
}
```

**Response** (200 OK):
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "bmV3IHJlZnJlc2ggdG9rZW4...",
  "token_type": "Bearer",
  "expires_in": 900,
  "session_id": "sess_abc123"
}
```

### 6.4 Authorization Check

**Request**:
```http
POST /api/v1/authz/check HTTP/1.1
Host: api.example.com
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "action": "read",
  "skill": "cost_analysis",
  "resource": "costs/report/monthly",
  "zone": "production"
}
```

**Response** (200 OK):
```json
{
  "allowed": true,
  "reason": "User has read permission for cost_analysis in production zone",
  "trust_level": 2
}
```

### 6.5 Rate Limit Exceeded

**Request**:
```http
POST /api/v1/auth/login HTTP/1.1
Host: api.example.com
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "attempt6"
}
```

**Response** (429 Too Many Requests):
```json
{
  "type": "https://api.example.com/errors/rate-limit",
  "title": "Rate Limit Exceeded",
  "status": 429,
  "detail": "Too many login attempts. Try again in 900 seconds.",
  "instance": "/api/v1/auth/login"
}
```
**Headers**:
```
Retry-After: 900
```

---

## 7. Security Considerations

### 7.1 Authentication Requirements

| Endpoint | Auth Required | Token Type |
|----------|---------------|------------|
| `/auth/login` | No | - |
| `/auth/oidc/callback` | No | - |
| `/auth/refresh` | Refresh Token | refresh_token |
| `/auth/logout` | Yes | access_token |
| `/auth/mfa/verify` | Partial | partial_session |
| `/authz/check` | Yes | access_token |
| `/session/*` | Yes | access_token |

### 7.2 Security Headers

| Header | Value | Purpose |
|--------|-------|---------|
| `X-Content-Type-Options` | nosniff | Prevent MIME sniffing |
| `X-Frame-Options` | DENY | Prevent clickjacking |
| `Strict-Transport-Security` | max-age=31536000 | Enforce HTTPS |
| `X-Request-ID` | UUID | Request tracing |

---

## 8. Quality Attributes

### 8.1 Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| Authentication latency (p99) | < 100ms | APM traces |
| Authorization latency (p99) | < 10ms | APM traces |
| Token validation (p99) | < 5ms | APM traces |

### 8.2 Availability

| Metric | Target |
|--------|--------|
| Uptime SLA | 99.9% |
| Error rate | < 0.1% |

---

## 9. Traceability

### 9.1 Upstream Sources

| Source Type | Document ID | Element Reference | Relationship |
|-------------|-------------|-------------------|--------------|
| BRD | BRD-01 | BRD.01.07.02 | Business requirement |
| PRD | PRD-01 | PRD.01.08.01 | Product feature |
| EARS | EARS-01 | EARS.01.25.01 | Formal requirement |
| BDD | BDD-01 | BDD.01.14.01 | Test scenario |
| ADR | ADR-01 | — | Architecture decision |
| SYS | SYS-01 | SYS.01.26.01 | System requirement |
| REQ | REQ-01 | REQ.01.01.01 | Atomic requirement |

### 9.2 Downstream Artifacts

| Artifact | Status | Relationship |
|----------|--------|--------------|
| SPEC-01 | TBD | Technical specification |
| TSPEC-01 | TBD | Test specification |
| TASKS-01 | TBD | Implementation tasks |

### 9.3 Cumulative Tags

```markdown
@brd: BRD.01.01.01
@prd: PRD.01.07.01
@ears: EARS.01.25.01
@bdd: BDD.01.14.01
@adr: ADR-01
@sys: SYS.01.26.01
@req: REQ.01.01.01
```

---

**Document Version**: 1.0.0
**SPEC-Ready Score**: 92%
**Last Updated**: 2026-02-11T18:30:00
