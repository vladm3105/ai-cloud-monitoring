---
title: "BRD-13: D6 REST APIs & Integrations"
tags:
  - brd
  - domain-module
  - d6-apis
  - layer-1-artifact
  - cost-monitoring-specific
custom_fields:
  document_type: brd
  artifact_type: BRD
  layer: 1
  module_id: D6
  module_name: REST APIs & Integrations
  descriptive_slug: d6_rest_apis
  architecture_approaches: [ai-agent-based]
  priority: primary
  development_status: draft
  schema_reference: "BRD_MVP_SCHEMA.yaml"
  schema_version: "1.0"
  template_profile: mvp
---

# BRD-13: D6 REST APIs & Integrations

> **Module Type**: Domain (Cost Monitoring-Specific)
> **Scope**: Admin API, AG-UI streaming, Webhooks, A2A Gateway, rate limiting

---

## 0. Document Control

| Item | Details |
|------|---------|
| **Project Name** | AI Cost Monitoring Platform v4.2 - D6 REST APIs |
| **Document Version** | 1.0.1 |
| **Date** | 2026-02-11T12:30:00 |
| **Document Owner** | Chief Architect |
| **Prepared By** | Antigravity AI |
| **Status** | Draft |
| **MVP Target Launch** | Phase 1 |
| **PRD-Ready Score** | 92/100 (Target: >=90/100) |

### Executive Summary (MVP)

The D6 REST APIs Module defines the HTTP API surfaces for the AI Cost Monitoring Platform. The platform exposes four distinct API surfaces: (1) AG-UI Streaming API for conversational AI, (2) REST Admin API for dashboard and management, (3) Webhook Ingestion API for cloud provider events, and (4) A2A Gateway API for external agent integration. Each surface has specific authentication, rate limiting, and response format requirements.

@ref: [API Endpoint Specification](../../00_REF/domain/05-api-endpoint-spec.md)

### Document Revision History

| Version | Date | Author | Changes Made | Approver |
|---------|------|--------|--------------|----------|
| 1.0.1 | 2026-02-11T12:30:00 | doc-brd-fixer | Fixed 4 broken links (nested folder path correction) | |
| 1.0 | 2026-02-08T00:00:00 | Antigravity AI | Initial BRD creation from API endpoint spec | |

---

## 1. Introduction

### 1.1 Purpose

This Business Requirements Document (BRD) defines the REST API requirements for all external interfaces of the platform, including conversational AI, administrative functions, event ingestion, and external agent communication.

### 1.2 Document Scope

This document covers:
- AG-UI Streaming API (conversational interface)
- REST Admin API (dashboard, management)
- Webhook Ingestion API (cloud provider events)
- A2A Gateway API (external agent integration)
- Authentication methods per API surface
- Rate limiting strategies
- Response format standards

**Out of Scope**:
- Internal service-to-service communication
- Agent orchestration logic (covered by D1)
- Database queries (covered by D5)

### 1.3 Intended Audience

- Backend developers (API implementation)
- Frontend developers (API consumption)
- Integration engineers (webhook, A2A)
- Security engineers (authentication review)

### 1.4 References

| Document | Location | Purpose |
|----------|----------|---------|
| API Endpoint Spec | [05-api-endpoint-spec.md](../../00_REF/domain/05-api-endpoint-spec.md) | Detailed endpoint definitions |
| Agent Routing Spec | [03-agent-routing-spec.md](../../00_REF/domain/03-agent-routing-spec.md) | AG-UI protocol |
| Security Auth Design | [06-security-auth-design.md](../../00_REF/domain/06-security-auth-design.md) | Authentication methods |

---

## 2. Business Context

### 2.1 Problem Statement

The platform requires multiple API surfaces to serve different client types:
- Interactive users need real-time streaming responses
- Dashboard UI needs CRUD operations for resources
- Cloud providers need webhook endpoints for events
- External AI agents need programmatic query access

### 2.2 Success Criteria

| Criterion | Target | MVP Target |
|-----------|--------|------------|
| API response time (p95) | <500ms | <1 second |
| Streaming first-token time | <500ms | <1 second |
| Uptime | 99.9% | 99.5% |
| Rate limit effectiveness | 100% | 100% |

---

## 3. Business Requirements

### 3.1 AG-UI Streaming API

**Business Capability**: Enable natural language conversations with AI agents via Server-Sent Events.

**Endpoints**:

| Method | Path | Purpose | Auth |
|--------|------|---------|------|
| POST | `/api/copilotkit` | Submit user query, receive streaming response | Bearer JWT |
| GET | `/api/copilotkit/health` | Health check | None |

**Request Format**:

```json
{
  "message": "What's our AWS spend this month?",
  "threadId": "conv-123",
  "context": {
    "selectedAccounts": ["acc-1", "acc-2"],
    "dateRange": { "start": "2026-01-01", "end": "2026-01-31" }
  }
}
```

**Response Format (SSE)**:

```
event: text
data: {"content": "Looking at your AWS spend..."}

event: component
data: {"type": "CostChart", "data": {...}}

event: done
data: {"threadId": "conv-123"}
```

**Business Acceptance Criteria**:

| Criteria ID | Criterion | MVP Target |
|-------------|-----------|------------|
| BRD.13.01.01 | First token latency | <1 second |
| BRD.13.01.02 | Stream reliability | >99% |
| BRD.13.01.03 | Concurrent connections | 100 per tenant |

### 3.2 REST Admin API

**Business Capability**: Provide CRUD operations for all platform resources.

**API Groups**:

| Group | Base Path | Resources | MVP Scope |
|-------|-----------|-----------|-----------|
| Tenant | `/api/tenant` | Tenant settings, billing | Yes |
| Accounts | `/api/cloud-accounts` | Cloud account CRUD | Yes |
| Users | `/api/users` | User management | Yes |
| Policies | `/api/policies` | Budget policies, alerts | Phase 2 |
| Recommendations | `/api/recommendations` | Optimization suggestions | Yes |
| Reports | `/api/reports` | Report generation | Phase 2 |
| Dashboard | `/api/dashboard` | Widget data endpoints | Yes |

**Standard CRUD Endpoints** (per resource):

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/{resource}` | List with pagination |
| GET | `/{resource}/{id}` | Get single item |
| POST | `/{resource}` | Create new item |
| PUT | `/{resource}/{id}` | Update item |
| DELETE | `/{resource}/{id}` | Delete item |

**Pagination Format**:

```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "pageSize": 20,
    "total": 150,
    "totalPages": 8
  }
}
```

**Business Acceptance Criteria**:

| Criteria ID | Criterion | MVP Target |
|-------------|-----------|------------|
| BRD.13.02.01 | API response time (p95) | <500ms |
| BRD.13.02.02 | Pagination support | All list endpoints |
| BRD.13.02.03 | OpenAPI documentation | Generated |

### 3.3 Webhook Ingestion API

**Business Capability**: Receive real-time events from cloud providers for Mode 3 event-driven processing.

**Endpoints**:

| Method | Path | Provider | Events |
|--------|------|----------|--------|
| POST | `/api/webhooks/aws` | AWS | Budget alerts, CloudWatch alarms |
| POST | `/api/webhooks/azure` | Azure | Budget alerts, Advisor events |
| POST | `/api/webhooks/gcp` | GCP | Budget notifications, alerts |

**Authentication**: HMAC signature verification per provider.

**AWS Signature Verification**:
```
x-amz-sns-signature: {base64 signature}
x-amz-sns-signing-cert-url: {certificate URL}
```

**GCP Pub/Sub Verification**:
```
Authorization: Bearer {OIDC token}
```

**Processing Requirements**:

| Requirement | Value | Purpose |
|-------------|-------|---------|
| Response time | <3 seconds | Acknowledge receipt |
| Processing | Async via Cloud Tasks | Decouple ingestion from processing |
| Idempotency | Event ID deduplication | Prevent duplicate processing |
| Retry | Exponential backoff | Handle transient failures |

**Business Acceptance Criteria**:

| Criteria ID | Criterion | MVP Target |
|-------------|-----------|------------|
| BRD.13.03.01 | Webhook acknowledgment | <3 seconds |
| BRD.13.03.02 | Signature verification | 100% |
| BRD.13.03.03 | Duplicate detection | Event ID check |

### 3.4 A2A Gateway API

**Business Capability**: Enable external AI agents to query the platform programmatically.

**Endpoints**:

| Method | Path | Purpose | Auth |
|--------|------|---------|------|
| POST | `/a2a/v1/query` | Submit agent query | mTLS + API Key |
| GET | `/a2a/v1/capabilities` | List available tools | mTLS + API Key |
| GET | `/a2a/v1/health` | Health check | None |

**Request Format**:

```json
{
  "query": "Get cost breakdown for last 7 days",
  "agentId": "external-agent-123",
  "context": {
    "tenantId": "tenant-uuid"
  }
}
```

**Response Format**:

```json
{
  "requestId": "req-uuid",
  "status": "success",
  "data": {
    "costs": [...],
    "summary": {...}
  },
  "usage": {
    "tokensUsed": 150,
    "responseTimeMs": 1200
  }
}
```

**Security Constraints**:

| Constraint | Value | Purpose |
|------------|-------|---------|
| Authentication | mTLS + API Key | Strong identity verification |
| Authorization | Registered agents only | Prevent unauthorized access |
| Default permissions | Read-only | Limit blast radius |
| Rate limit | 10 requests/minute/agent | Prevent abuse |

**Business Acceptance Criteria**:

| Criteria ID | Criterion | Target |
|-------------|-----------|--------|
| BRD.13.04.01 | Agent registration | Pre-approved list |
| BRD.13.04.02 | Response format | Structured JSON |
| BRD.13.04.03 | Rate limiting | Per-agent enforcement |

### 3.5 Authentication Methods

**Business Capability**: Apply appropriate authentication per API surface.

| API Surface | Primary Auth | Secondary Auth | Token Type |
|-------------|--------------|----------------|------------|
| AG-UI Streaming | Bearer JWT | - | Access token (1 hour) |
| REST Admin | Bearer JWT | - | Access token (1 hour) |
| Webhooks | HMAC Signature | IP whitelist | Provider-specific |
| A2A Gateway | mTLS | API Key | Client certificate |

**JWT Claims**:

```json
{
  "sub": "user-uuid",
  "org_id": "tenant-uuid",
  "roles": ["operator"],
  "permissions": ["cost:read", "recommendations:read"],
  "iat": 1707350400,
  "exp": 1707354000
}
```

**Business Acceptance Criteria**:

| Criteria ID | Criterion | MVP Target |
|-------------|-----------|------------|
| BRD.13.05.01 | JWT validation | All requests |
| BRD.13.05.02 | Token expiry | 1 hour |
| BRD.13.05.03 | Permission enforcement | Per-endpoint |

### 3.6 Rate Limiting

**Business Capability**: Protect the platform from abuse and ensure fair resource usage.

**Rate Limit Tiers**:

| Scope | Limit | Window | Action |
|-------|-------|--------|--------|
| Per IP (unauthenticated) | 100 | 1 minute | 429 response |
| Per User | 300 | 1 minute | 429 response |
| Per Tenant | 1000 | 1 minute | 429 response |
| Per Agent (A2A) | 10 | 1 minute | 429 response |

**Rate Limit Headers**:

```
X-RateLimit-Limit: 300
X-RateLimit-Remaining: 250
X-RateLimit-Reset: 1707350460
Retry-After: 30
```

**Business Acceptance Criteria**:

| Criteria ID | Criterion | MVP Target |
|-------------|-----------|------------|
| BRD.13.06.01 | Rate limit headers | All responses |
| BRD.13.06.02 | Limit enforcement | Real-time |
| BRD.13.06.03 | Graceful rejection | 429 + Retry-After |

### 3.7 Response Format Standards

**Business Capability**: Provide consistent response formats across all APIs.

**Success Response**:

```json
{
  "success": true,
  "data": { ... },
  "meta": {
    "requestId": "req-uuid",
    "timestamp": "2026-02-08T12:00:00Z"
  }
}
```

**Error Response**:

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid date range",
    "details": [
      { "field": "startDate", "message": "Must be before endDate" }
    ]
  },
  "meta": {
    "requestId": "req-uuid",
    "timestamp": "2026-02-08T12:00:00Z"
  }
}
```

**HTTP Status Codes**:

| Code | Meaning | Usage |
|------|---------|-------|
| 200 | OK | Successful GET, PUT |
| 201 | Created | Successful POST |
| 204 | No Content | Successful DELETE |
| 400 | Bad Request | Validation errors |
| 401 | Unauthorized | Missing/invalid auth |
| 403 | Forbidden | Insufficient permissions |
| 404 | Not Found | Resource not found |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Error | Server error |

**Business Acceptance Criteria**:

| Criteria ID | Criterion | MVP Target |
|-------------|-----------|------------|
| BRD.13.07.01 | Response envelope | All endpoints |
| BRD.13.07.02 | Request ID tracking | All requests |
| BRD.13.07.03 | Error code consistency | Standardized codes |

---

## 4. Technology Stack

| Component | Technology | Reference |
|-----------|------------|-----------|
| API Framework | FastAPI (Python) | - |
| Streaming | Server-Sent Events | ADR-007 |
| Documentation | OpenAPI 3.0 | Generated |
| Rate Limiting | Redis / Cloud Armor | - |

---

## 5. Dependencies

### 5.1 Foundation Module Dependencies

| Module | Dependency | Purpose |
|--------|------------|---------|
| F1 IAM | Authentication | JWT validation, RBAC |
| F3 Observability | Logging | Request tracing |
| F4 SecOps | Rate limiting | Abuse prevention |

### 5.2 Domain Module Dependencies

| Module | Dependency | Purpose |
|--------|------------|---------|
| D1 Agents | AG-UI backend | Query processing |
| D5 Data | Data access | CRUD operations |
| D7 Security | Auth enforcement | Permission checks |

---

## 6. Risks and Mitigations

| Risk ID | Risk Description | Likelihood | Impact | Mitigation Strategy |
|---------|------------------|------------|--------|---------------------|
| BRD.13.R01 | API abuse | Medium | High | Rate limiting, WAF |
| BRD.13.R02 | Webhook forgery | Low | Critical | Signature verification |
| BRD.13.R03 | Streaming disconnects | Medium | Medium | Reconnection handling |
| BRD.13.R04 | API versioning conflicts | Low | Medium | Versioned endpoints |

---

## 7. Traceability

### 7.1 Upstream Dependencies
- Domain specification: 05-api-endpoint-spec.md
- Security design: 06-security-auth-design.md

### 7.2 Architecture Decision Requirements

#### 7.2.1 Infrastructure (BRD.13.32.01)

**Status**: N/A - Handled by F6 Infrastructure

**PRD Requirements**: None for this module (see BRD-06)

---

#### 7.2.2 Data Architecture (BRD.13.32.02)

**Status**: N/A - Data from D5 Data Persistence

**PRD Requirements**: None for this module (see BRD-12)

---

#### 7.2.3 Integration (BRD.13.32.03)

**Status**: Selected

**Business Driver**: RESTful API and streaming interfaces

**Business Constraints**: Must support AG-UI streaming, OpenAPI 3.0 compliance

**Alternatives Overview**:
| Option | Function | Est. Monthly Cost | Selection Rationale |
|--------|----------|-------------------|---------------------|
| FastAPI | Python REST framework | $0 | Async, OpenAPI native |
| Express.js | Node.js framework | $0 | JavaScript ecosystem |
| Cloud Endpoints | API management | $50-200 | GCP native |

**Recommended Selection**: FastAPI with Cloud Run (per ADR-004)

**PRD Requirements**: OpenAPI specification, endpoint design

---

#### 7.2.4 Security (BRD.13.32.04)

**Status**: Selected

**Business Driver**: API security

**Recommended Selection**: JWT authentication, rate limiting via F4 SecOps

**PRD Requirements**: Auth middleware, rate limiting policies

---

#### 7.2.5 Observability (BRD.13.32.05)

**Status**: N/A - Handled by F3 Observability

**PRD Requirements**: None for this module (see BRD-03)

---

#### 7.2.6 AI/ML (BRD.13.32.06)

**Status**: N/A - No ML in this module

**PRD Requirements**: None for current scope

---

#### 7.2.7 Technology Selection (BRD.13.32.07)

**Status**: Selected

**Business Driver**: API framework and deployment

**Recommended Selection**: FastAPI + Cloud Run (per ADR-004)

**PRD Requirements**: Framework configuration, deployment specs

---

### 7.3 Downstream Artifacts
- PRD: API feature specifications (pending)
- CTR: OpenAPI contracts (pending)
- SPEC: Implementation specifications (pending)

### 7.4 Cross-References

| Related BRD | Relationship | Integration Point |
|-------------|--------------|-------------------|
| BRD-01 (F1 IAM) | Upstream | JWT authentication |
| BRD-04 (F4 SecOps) | Upstream | Rate limiting |
| BRD-08 (D1 Agents) | Downstream | AG-UI streaming |
| BRD-10 (D3 UX) | Downstream | Dashboard API consumption |
| BRD-14 (D7 Security) | Peer | Auth enforcement |

---

## 8. Appendices

### Appendix A: OpenAPI Specification Structure

```yaml
openapi: 3.0.3
info:
  title: AI Cost Monitoring API
  version: 1.0.0
paths:
  /api/cloud-accounts:
    get:
      summary: List cloud accounts
      security:
        - BearerAuth: []
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/CloudAccountList'
```

### Appendix B: Webhook Event Types

| Provider | Event Type | Trigger |
|----------|------------|---------|
| AWS | `aws.budgets.alert` | Budget threshold exceeded |
| AWS | `aws.cloudwatch.alarm` | CloudWatch alarm state change |
| Azure | `azure.costmanagement.budget` | Budget alert |
| Azure | `azure.advisor.recommendation` | New recommendation |
| GCP | `gcp.billing.budget` | Budget notification |
| GCP | `gcp.monitoring.alert` | Monitoring alert |

### Appendix C: Error Code Reference

| Code | Description | HTTP Status |
|------|-------------|-------------|
| `AUTH_REQUIRED` | Authentication required | 401 |
| `AUTH_INVALID` | Invalid credentials | 401 |
| `PERMISSION_DENIED` | Insufficient permissions | 403 |
| `NOT_FOUND` | Resource not found | 404 |
| `VALIDATION_ERROR` | Request validation failed | 400 |
| `RATE_LIMITED` | Too many requests | 429 |
| `INTERNAL_ERROR` | Server error | 500 |

---

**Document Status**: Draft
**Next Review**: Upon PRD creation
