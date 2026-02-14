---
title: "CTR-02: F2 Session Management API Contract"
tags:
  - ctr
  - layer-8-artifact
  - f2-session
  - foundation-module
  - shared-architecture
  - api-contract
custom_fields:
  document_type: ctr
  artifact_type: CTR
  layer: 8
  module_id: F2
  module_name: Session Management
  spec_ready_score: 91
  schema_version: "1.0"
---

# CTR-02: F2 Session Management API Contract

## Document Control

| Item | Details |
|------|---------|
| **CTR ID** | CTR-02 |
| **Title** | F2 Session Management API Contract |
| **Status** | Active |
| **Version** | 1.0.0 |
| **Created** | 2026-02-11 |
| **Author** | Platform Architecture Team |
| **Owner** | Platform Team |
| **Last Updated** | 2026-02-11 |
| **SPEC-Ready Score** | ✅ 91% (Target: ≥90%) |

---

## 1. Contract Overview

### 1.1 Purpose

This contract defines the API interface for the F2 Session Management module, providing session lifecycle management, context assembly, and memory persistence for the AI Cloud Cost Monitoring Platform.

### 1.2 Scope

| Aspect | Coverage |
|--------|----------|
| **Session Lifecycle** | Create, extend, invalidate, list |
| **Context Assembly** | User, workspace, memory aggregation |
| **Memory Management** | Short-term and long-term memory |
| **Concurrency Control** | Max 3 sessions per user |

### 1.3 Contract Definition

**OpenAPI Specification**: [CTR-02_f2_session_api.yaml](CTR-02_f2_session_api.yaml)

---

## 2. Business Context

### 2.1 Business Need

F2 Session Management provides stateful session tracking for all user interactions. It maintains context across requests and enables the AI agent to remember conversation history and user preferences.

### 2.2 Source Requirements

| Source | Reference | Description |
|--------|-----------|-------------|
| REQ-02 | Section 4.1 | API Contract specifications |
| REQ-02 | Section 4.2 | Data Schema definitions |

---

## 3. Interface Definitions

### 3.1 Session Endpoints

#### CTR.02.16.01: Create Session

| Attribute | Value |
|-----------|-------|
| **Path** | `POST /api/v1/session` |
| **Description** | Create new user session |
| **Authentication** | Bearer token |
| **Rate Limit** | 10 requests/minute per user |

#### CTR.02.16.02: Get Session

| Attribute | Value |
|-----------|-------|
| **Path** | `GET /api/v1/session/{session_id}` |
| **Description** | Get session details |
| **Authentication** | Bearer token |
| **Rate Limit** | 60 requests/minute per user |

#### CTR.02.16.03: Extend Session

| Attribute | Value |
|-----------|-------|
| **Path** | `PUT /api/v1/session/{session_id}/extend` |
| **Description** | Extend session TTL |
| **Authentication** | Bearer token |
| **Rate Limit** | 30 requests/minute per user |

#### CTR.02.16.04: Invalidate Session

| Attribute | Value |
|-----------|-------|
| **Path** | `DELETE /api/v1/session/{session_id}` |
| **Description** | End session |
| **Authentication** | Bearer token |
| **Rate Limit** | 10 requests/minute per user |

### 3.2 Context Endpoints

#### CTR.02.16.05: Get Context

| Attribute | Value |
|-----------|-------|
| **Path** | `GET /api/v1/session/{session_id}/context` |
| **Description** | Get assembled context |
| **Authentication** | Bearer token |
| **Rate Limit** | 100 requests/minute per user |

#### CTR.02.16.06: Update Memory

| Attribute | Value |
|-----------|-------|
| **Path** | `PUT /api/v1/session/{session_id}/memory` |
| **Description** | Update session memory |
| **Authentication** | Bearer token |
| **Rate Limit** | 30 requests/minute per user |

---

## 4. Data Models

### 4.1 Request Models

#### CTR.02.17.01: CreateSessionRequest

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| `user_id` | string | Yes | Non-empty | User identifier |
| `trust_level` | integer | Yes | 1-4 | Trust level from auth |
| `device_fingerprint` | string | Yes | Non-empty | Device identifier |
| `workspace_id` | string | No | UUID | Optional workspace |

#### CTR.02.17.02: UpdateMemoryRequest

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| `key` | string | Yes | Max 255 chars | Memory key |
| `value` | any | Yes | JSON serializable | Memory value |
| `ttl_seconds` | integer | No | 60-86400 | Optional TTL |

### 4.2 Response Models

#### CTR.02.17.03: Session

| Field | Type | Description |
|-------|------|-------------|
| `session_id` | string | Unique session identifier |
| `user_id` | string | User identifier |
| `trust_level` | integer | Trust level (1-4) |
| `device_fingerprint` | string | Device identifier |
| `created_at` | datetime | Creation timestamp |
| `last_accessed` | datetime | Last access timestamp |
| `expires_at` | datetime | Expiration timestamp |
| `idle_timeout` | integer | Idle timeout in seconds |

#### CTR.02.17.04: Context

| Field | Type | Description |
|-------|------|-------------|
| `user` | object | User profile data |
| `session` | object | Session metadata |
| `workspace` | object | Active workspace |
| `memory` | object | Session memory |

---

## 5. Error Handling

### 5.1 Error Response Format

All errors follow RFC 7807 Problem Details format.

### 5.2 Error Catalog

#### CTR.02.20.01: Session Errors

| Error Code | HTTP Status | Title | Detail |
|------------|-------------|-------|--------|
| SESS_001 | 404 | Session Not Found | Session does not exist |
| SESS_002 | 409 | Session Limit Exceeded | Maximum 3 concurrent sessions |
| SESS_003 | 401 | Session Expired | Session has expired |
| SESS_004 | 403 | Session Access Denied | Cannot access this session |

---

## 6. Usage Examples

### 6.1 Create Session

**Request**:
```http
POST /api/v1/session HTTP/1.1
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "user_id": "usr_abc123",
  "trust_level": 2,
  "device_fingerprint": "fp_hash_xyz"
}
```

**Response** (201 Created):
```json
{
  "session_id": "sess_def456",
  "user_id": "usr_abc123",
  "trust_level": 2,
  "created_at": "2026-02-11T10:30:00Z",
  "expires_at": "2026-02-11T11:00:00Z",
  "idle_timeout": 1800
}
```

### 6.2 Get Context

**Request**:
```http
GET /api/v1/session/sess_def456/context HTTP/1.1
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response** (200 OK):
```json
{
  "user": {
    "id": "usr_abc123",
    "email": "user@example.com",
    "trust_level": 2
  },
  "session": {
    "session_id": "sess_def456",
    "created_at": "2026-02-11T10:30:00Z"
  },
  "workspace": {
    "id": "ws_123",
    "name": "Production"
  },
  "memory": {
    "last_query": "monthly costs",
    "preferred_chart": "bar"
  }
}
```

---

## 7. Traceability

### 7.1 Cumulative Tags

```markdown
@brd: BRD.02.01.01
@prd: PRD.02.07.01
@ears: EARS.02.25.01
@bdd: BDD.02.14.01
@adr: ADR-02
@sys: SYS.02.26.01
@req: REQ.02.01.01
```

---

**Document Version**: 1.0.0
**SPEC-Ready Score**: 91%
**Last Updated**: 2026-02-11T19:00:00
