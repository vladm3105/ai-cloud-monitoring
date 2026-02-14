---
title: "CTR-13: D6 REST APIs Gateway Contract"
tags:
  - ctr
  - layer-8-artifact
  - d6-rest-apis
  - domain-module
  - shared-architecture
  - api-contract
  - api-gateway
custom_fields:
  document_type: ctr
  artifact_type: CTR
  layer: 8
  module_id: D6
  module_name: REST APIs Gateway
  spec_ready_score: 94
  schema_version: "1.0"
---

# CTR-13: D6 REST APIs Gateway Contract

## Document Control

| Item | Details |
|------|---------|
| **CTR ID** | CTR-13 |
| **Title** | D6 REST APIs Gateway Contract |
| **Status** | Active |
| **Version** | 1.0.0 |
| **Created** | 2026-02-11 |
| **Author** | Platform Architecture Team |
| **Owner** | Platform Team |
| **Last Updated** | 2026-02-11 |
| **SPEC-Ready Score** | ✅ 94% (Target: ≥90%) |

---

## 1. Contract Overview

### 1.1 Purpose

This contract defines the unified API Gateway for the AI Cloud Cost Monitoring Platform. It aggregates endpoints from all modules and provides consistent authentication, rate limiting, and error handling.

### 1.2 Scope

| Aspect | Coverage |
|--------|----------|
| **AG-UI** | SSE streaming for agent chat |
| **REST** | CRUD operations for all entities |
| **Webhooks** | Event notifications |
| **A2A** | Agent-to-agent communication |

### 1.3 API Surfaces

| Surface | Protocol | Base Path | Purpose |
|---------|----------|-----------|---------|
| AG-UI | SSE | `/api/v1/chat` | Agent streaming |
| REST | JSON | `/api/v1/*` | CRUD operations |
| Webhooks | POST | `/webhooks/*` | Event notifications |
| A2A | JSON | `/a2a/*` | Agent-to-agent |
| Docs | GET | `/docs`, `/openapi.json` | API documentation |

### 1.4 Contract Definition

**OpenAPI Specification**: [CTR-13_d6_rest_apis_gateway.yaml](CTR-13_d6_rest_apis_gateway.yaml)

---

## 2. Business Context

### 2.1 Business Need

D6 REST APIs provides the unified API gateway that all clients interact with. It enforces consistent security, rate limiting, and error handling across all platform capabilities.

### 2.2 Source Requirements

| Source | Reference | Description |
|--------|-----------|-------------|
| REQ-13 | Section 4.1 | API surfaces definition |
| REQ-13 | Section 4.2 | OpenAPI endpoints |
| REQ-13 | Section 4.3 | Error format (RFC 7807) |

---

## 3. Interface Definitions

### 3.1 Cost Endpoints

#### CTR.13.16.01: Query Costs

| Attribute | Value |
|-----------|-------|
| **Path** | `GET /api/v1/costs` |
| **Description** | Query cost data |
| **Authentication** | Bearer token |
| **Rate Limit** | 60 requests/minute |
| **Upstream** | CTR-09 (D2 Cost Analytics) |

#### CTR.13.16.02: Cost Breakdown

| Attribute | Value |
|-----------|-------|
| **Path** | `GET /api/v1/costs/breakdown` |
| **Description** | Cost breakdown by dimension |
| **Authentication** | Bearer token |
| **Rate Limit** | 30 requests/minute |
| **Upstream** | CTR-09 (D2 Cost Analytics) |

### 3.2 Alert Endpoints

#### CTR.13.16.03: List Alerts

| Attribute | Value |
|-----------|-------|
| **Path** | `GET /api/v1/alerts` |
| **Description** | List user alerts |
| **Authentication** | Bearer token |
| **Rate Limit** | 60 requests/minute |

#### CTR.13.16.04: Create Alert

| Attribute | Value |
|-----------|-------|
| **Path** | `POST /api/v1/alerts` |
| **Description** | Create cost alert |
| **Authentication** | Bearer token |
| **Rate Limit** | 10 requests/minute |

### 3.3 Report Endpoints

#### CTR.13.16.05: List Reports

| Attribute | Value |
|-----------|-------|
| **Path** | `GET /api/v1/reports` |
| **Description** | List saved reports |
| **Authentication** | Bearer token |
| **Rate Limit** | 60 requests/minute |

#### CTR.13.16.06: Create Report

| Attribute | Value |
|-----------|-------|
| **Path** | `POST /api/v1/reports` |
| **Description** | Create scheduled report |
| **Authentication** | Bearer token |
| **Rate Limit** | 5 requests/minute |

### 3.4 Workspace Endpoints

#### CTR.13.16.07: List Workspaces

| Attribute | Value |
|-----------|-------|
| **Path** | `GET /api/v1/workspaces` |
| **Description** | List user workspaces |
| **Authentication** | Bearer token |
| **Rate Limit** | 60 requests/minute |

#### CTR.13.16.08: CRUD Workspace

| Attribute | Value |
|-----------|-------|
| **Paths** | `POST/GET/PUT/DELETE /api/v1/workspaces/{id}` |
| **Description** | Workspace CRUD operations |
| **Authentication** | Bearer token |
| **Rate Limit** | 30 requests/minute |

### 3.5 Chat Endpoint (SSE)

#### CTR.13.16.09: Chat Stream

| Attribute | Value |
|-----------|-------|
| **Path** | `POST /api/v1/chat` |
| **Description** | AG-UI streaming chat |
| **Protocol** | SSE |
| **Authentication** | Bearer token |
| **Rate Limit** | 10 requests/minute |
| **Upstream** | CTR-08 (D1 Agent Orch) |

### 3.6 Documentation Endpoints

#### CTR.13.16.10: OpenAPI Spec

| Attribute | Value |
|-----------|-------|
| **Path** | `GET /openapi.json` |
| **Description** | OpenAPI specification |
| **Authentication** | None |

#### CTR.13.16.11: Swagger UI

| Attribute | Value |
|-----------|-------|
| **Path** | `GET /docs` |
| **Description** | Interactive API documentation |
| **Authentication** | None |

---

## 4. Data Models

### 4.1 Alert Models

#### CTR.13.17.01: Alert

| Field | Type | Description |
|-------|------|-------------|
| `alert_id` | string | Alert identifier |
| `name` | string | Alert name |
| `condition` | object | Trigger condition |
| `threshold` | float | Cost threshold |
| `channels` | array | Notification channels |
| `enabled` | boolean | Active status |
| `created_at` | datetime | Creation timestamp |

#### CTR.13.17.02: CreateAlertRequest

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Alert name |
| `condition_type` | enum | Yes | threshold, anomaly, budget |
| `threshold` | float | Conditional | Cost threshold |
| `channels` | array | Yes | Notification channels |

### 4.2 Report Models

#### CTR.13.17.03: Report

| Field | Type | Description |
|-------|------|-------------|
| `report_id` | string | Report identifier |
| `name` | string | Report name |
| `schedule` | string | Cron expression |
| `filters` | object | Report filters |
| `format` | enum | pdf, csv, json |
| `last_run` | datetime | Last execution |

### 4.3 Workspace Models

#### CTR.13.17.04: Workspace

| Field | Type | Description |
|-------|------|-------------|
| `workspace_id` | string | Workspace identifier |
| `name` | string | Workspace name |
| `filters` | object | Saved filters |
| `default_view` | string | Default dashboard |
| `shared_with` | array | Shared users |

---

## 5. Error Handling

### 5.1 RFC 7807 Format

All errors use RFC 7807 Problem Details:

```json
{
  "type": "https://api.costmonitor.io/errors/validation",
  "title": "Validation Error",
  "status": 400,
  "detail": "Field 'date_range' is required",
  "instance": "/api/v1/costs/query"
}
```

### 5.2 Error Catalog

#### CTR.13.20.01: API Gateway Errors

| Error Code | HTTP Status | Title | Detail |
|------------|-------------|-------|--------|
| API_001 | 401 | Unauthorized | Invalid or expired JWT |
| API_002 | 403 | Forbidden | Insufficient permissions |
| API_003 | 429 | Rate Limited | Too many requests |
| API_004 | 400 | Validation Error | Request validation failed |
| API_005 | 500 | Internal Error | Unexpected server error |

---

## 6. Usage Examples

### 6.1 Create Alert

**Request**:
```http
POST /api/v1/alerts HTTP/1.1
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "name": "High Compute Spend",
  "condition_type": "threshold",
  "threshold": 1000.00,
  "channels": ["email", "slack"]
}
```

**Response** (201 Created):
```json
{
  "alert_id": "alert_abc123",
  "name": "High Compute Spend",
  "condition_type": "threshold",
  "threshold": 1000.00,
  "channels": ["email", "slack"],
  "enabled": true,
  "created_at": "2026-02-11T10:30:00Z"
}
```

### 6.2 List Workspaces

**Request**:
```http
GET /api/v1/workspaces HTTP/1.1
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response** (200 OK):
```json
{
  "workspaces": [
    {
      "workspace_id": "ws_123",
      "name": "Production Analysis",
      "default_view": "cost_summary",
      "created_at": "2026-01-15T08:00:00Z"
    }
  ],
  "total": 1
}
```

---

## 7. Security

### 7.1 Authentication

All API endpoints (except `/docs` and `/openapi.json`) require Bearer token authentication.

### 7.2 Rate Limiting

| Tier | Limit | Window |
|------|-------|--------|
| Default | 60 req | per minute |
| Heavy | 30 req | per minute |
| Expensive | 10 req | per minute |
| Admin | 5 req | per minute |

### 7.3 CORS

| Origin | Methods | Headers |
|--------|---------|---------|
| *.example.com | GET, POST, PUT, DELETE | Authorization, Content-Type |

---

## 8. Traceability

### 8.1 Upstream CTR References

| CTR | Module | Aggregated Endpoints |
|-----|--------|----------------------|
| CTR-01 | F1 IAM | `/api/v1/auth/*` |
| CTR-02 | F2 Session | `/api/v1/session/*` |
| CTR-08 | D1 Agent | `/api/v1/chat` |
| CTR-09 | D2 Cost | `/api/v1/costs/*` |
| CTR-11 | D4 Multi-Cloud | `/api/v1/providers/*` |

### 8.2 Cumulative Tags

```markdown
@brd: BRD.13.01.01
@prd: PRD.13.07.01
@ears: EARS.13.25.01
@bdd: BDD.13.14.01
@adr: ADR-13
@sys: SYS.13.26.01
@req: REQ.13.01.01
```

---

**Document Version**: 1.0.0
**SPEC-Ready Score**: 94%
**Last Updated**: 2026-02-11T19:15:00
