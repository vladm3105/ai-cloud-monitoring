# AI Cost Monitoring — Security & Authentication Design

## Document Info

| Field | Value |
|-------|-------|
| **Document** | 06 — Security & Authentication Design |
| **Version** | 1.0 |
| **Date** | February 2026 |
| **Status** | Architecture |
| **Audience** | Architects, Security Engineers, Backend Developers |

---

## 1. Security Architecture Overview

This document consolidates all security-related specifications from the platform architecture. Security is enforced at multiple layers with defense-in-depth principles.

### 1.1 Security Layers

```
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 1: API GATEWAY                                           │
│  Rate limiting • TLS termination • Request validation           │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────┐
│  LAYER 2: AUTHENTICATION                                        │
│  Auth0 JWT validation • Token expiration • Signature check      │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────┐
│  LAYER 3: AUTHORIZATION                                         │
│  RBAC role check • Permission verification • TenantContext      │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────┐
│  LAYER 4: DATA ISOLATION                                        │
│  PostgreSQL RLS • BigQuery views • Redis namespacing            │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────┐
│  LAYER 5: CREDENTIAL MANAGEMENT                                  │
│  Cloud-native Secret Manager • Short-lived credentials          │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────┐
│  LAYER 6: AUDIT & MONITORING                                    │
│  Immutable audit log • SIEM integration • Anomaly detection     │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Key Security Principles

| Principle | Implementation |
|-----------|----------------|
| Never trust user input | All context injected server-side from JWT claims |
| Credentials never in database | All credentials in cloud-native Secret Manager |
| RLS at database layer | Multi-layer isolation (DB, cache, storage) |
| Every action audited | 7-year immutable audit log to external SIEM |
| Approval workflows for risk | Action risk levels determine approval requirements |
| Role-based access control | 5 tenant roles with granular permissions |
| Rate limiting at multiple levels | API Gateway, MCP servers, cloud APIs |
| External agents sandboxed | Registered, read-only by default, rate-limited |

---

## 2. Authentication

### 2.1 Auth0 Integration

**Deployment Scenarios:**

| Scenario | Authentication Method | Auth0 Usage |
|----------|----------------------|-------------|
| Single-Owner (Internal) | GCP IAM / Google Workspace | Not required |
| MVP (Single-Tenant SaaS) | Firebase Auth or Auth0 | Optional |
| Multi-Tenant Production | Auth0 Organizations | Required |

**Auth0 Organization Structure:**

| Entity | Purpose |
|--------|---------|
| Auth0 User | Platform user account (email, password, or SSO) |
| Auth0 Organization | Customer tenant container (`org_{slug}`) |
| Auth0 Membership | User → Organization binding with role |

### 2.2 JWT Token Structure

```json
{
  "sub": "<user_id>",
  "org_id": "<tenant_id>",
  "roles": ["org_admin"],
  "permissions": [
    "read:costs",
    "read:resources",
    "write:remediation"
  ],
  "aud": "finops-platform",
  "iss": "https://your-tenant.auth0.com/",
  "exp": "<expiration_timestamp>",
  "iat": "<issued_at_timestamp>"
}
```

### 2.3 Token Validation Flow

```
Request received with Authorization: Bearer <token>
  → Extract JWT from header
    → Validate signature against Auth0 JWKS
      → Check token expiration (exp claim)
        → Extract tenant_id from org_id claim
          → Extract user_id from sub claim
            → Lookup roles from JWT roles claim
              → Inject TenantContext into request pipeline
```

### 2.4 TenantContext Object

Every agent and API handler receives this context after JWT validation:

```python
class TenantContext:
    tenant_id: UUID       # From JWT org_id claim
    user_id: UUID         # From JWT sub claim
    roles: List[str]      # From JWT roles claim
    permissions: List[str] # From JWT permissions claim
    cloud_accounts: List   # DB lookup by tenant_id
    plan: str             # Tenant subscription tier
    timezone: str         # Tenant settings
```

**Critical:** TenantContext is injected by the AG-UI Server after JWT validation — never provided by the user or derived from the query.

---

## 3. Authorization (RBAC)

### 3.1 Role Definitions

| Role | Scope | Description |
|------|-------|-------------|
| `super_admin` | Platform | Platform-level administration (exceeds tenant scope) |
| `org_admin` | Tenant | Tenant administrator, full access within organization |
| `operator` | Tenant | Can execute remediation actions, approve medium-risk |
| `analyst` | Tenant | Can view, dismiss recommendations, request approval |
| `viewer` | Tenant | Read-only access, cannot execute or invoke actions |

### 3.2 Permission Matrix

| Capability | viewer | analyst | operator | org_admin |
|------------|--------|---------|----------|-----------|
| View cost data | ✓ | ✓ | ✓ | ✓ |
| View recommendations | ✓ | ✓ | ✓ | ✓ |
| Dismiss recommendations | ✗ | ✓ | ✓ | ✓ |
| Request action approval | ✗ | ✓ | ✓ | ✓ |
| Execute remediation | ✗ | ✗ | ✓ | ✓ |
| Approve low/medium risk | ✗ | ✗ | ✓ | ✓ |
| Approve high risk | ✗ | ✗ | ✗ | ✓ |
| Manage cloud accounts | ✗ | ✗ | ✗ | ✓ |
| Manage users | ✗ | ✗ | ✗ | ✓ |
| Manage policies | ✗ | ✗ | ✗ | ✓ |

### 3.3 Permission Scopes

| Scope | Description |
|-------|-------------|
| `read:costs` | Access cost data and anomalies |
| `read:resources` | Access resource inventory |
| `read:recommendations` | Access optimization suggestions |
| `write:remediation` | Execute cloud actions |
| `manage:policies` | Configure tenant policies |
| `manage:accounts` | Add/remove cloud accounts |
| `manage:users` | Invite/remove users, assign roles |

### 3.4 Permission Check Before Routing

```python
# Coordinator Agent checks permission before routing
if intent.requires_permission("write:remediation"):
    if "write:remediation" not in tenant_context.permissions:
        return Error(
            "Remediation actions require Operator role. "
            f"Your current role is {tenant_context.roles[0]}. "
            "Contact your Org Admin to request access."
        )
```

### 3.5 User Invitation Hierarchy

| Inviter Role | Can Assign Roles |
|--------------|------------------|
| org_admin | org_admin, operator, analyst, viewer |
| operator | analyst, viewer |
| analyst | viewer |
| viewer | (cannot invite) |

---

## 4. Tenant Isolation

### 4.1 Multi-Layer Isolation Strategy

| Layer | Mechanism | Enforcement |
|-------|-----------|-------------|
| PostgreSQL | Row-Level Security (RLS) | Connection-level `SET app.current_tenant` |
| BigQuery | Authorized views | Filter by authorized cloud accounts |
| Redis | Key namespacing | Prefix `tenant:{id}:*` |
| Object Storage | Path isolation | Bucket prefix `/{tenant_id}/` |
| Secret Manager | Path isolation | IAM policy per tenant credential |

### 4.2 PostgreSQL RLS Implementation

**Connection Setup:**

```sql
-- Set at connection start, derived from JWT org_id
SET app.current_tenant = '{tenant_id}';
```

**RLS Policy on Every Table:**

```sql
-- Applied to cost_metrics, resources, recommendations, etc.
CREATE POLICY tenant_isolation_policy ON cost_metrics
  USING (tenant_id = current_setting('app.current_tenant')::uuid);
```

**Guarantee:** Even if application code has a bug, the database will not return another tenant's data.

### 4.3 BigQuery Isolation

```sql
-- Authorized view pattern
CREATE VIEW tenant_costs AS
SELECT *
FROM raw_billing_export
WHERE project_id IN (
  SELECT account_identifier
  FROM cloud_accounts
  WHERE tenant_id = @current_tenant_id
    AND provider = 'gcp'
);
```

### 4.4 Redis Namespacing

```python
# All cache keys include tenant prefix
cache_key = f"tenant:{tenant_id}:costs:{date_range}"
```

---

## 5. Credential Management

### 5.1 Cloud-Native Secret Managers

| Home Cloud | Secret Manager | Path Pattern |
|------------|----------------|--------------|
| GCP | Cloud Secret Manager | `projects/{project}/secrets/tenant-{id}-{provider}` |
| AWS | Secrets Manager | `tenant/{tenant_id}/{provider}/{account_id}` |
| Azure | Key Vault | `tenant-{tenant_id}-{provider}-{account_id}` |

### 5.2 Credential Path Conventions

| Provider | GCP Secret Manager Path | Stored Data |
|----------|------------------------|-------------|
| AWS | `tenant-{id}-aws-{account_id}` | role_arn, external_id |
| Azure | `tenant-{id}-azure-{subscription_id}` | client_id, client_secret, tenant_id |
| GCP | `tenant-{id}-gcp-{project_id}` | service_account_json |
| Kubernetes | `tenant-{id}-k8s-{cluster_name}` | kubeconfig or token |

### 5.3 Credential Flow

```
Agent receives tenant_id from Coordinator context
  → MCP Server receives tenant_id as tool parameter
    → MCP Server calls Home Cloud Secret Manager:
        GET projects/{project}/secrets/tenant-{tenant_id}-{provider}
      → Secret Manager returns credentials
        → MCP Server uses credentials for cloud API call
          → Credentials discarded after request (never cached)
```

### 5.4 Credential Security Rules

| Rule | Enforcement |
|------|-------------|
| Never stored in database | Credentials only in Secret Manager |
| Never returned in API responses | Masked in all outputs |
| Never sent to frontend | Backend-only access |
| Never cached beyond request | Fetch fresh per request |
| Short-lived when possible | Use temporary credentials (STS) |

### 5.5 Credential Validation on Connect

| Validation | Check | On Failure |
|------------|-------|------------|
| Format | Regex/schema validation | Inline form error |
| Connectivity | Attempt API call | "Unable to connect — check permissions" |
| Permissions | Call required APIs | "Missing permission: ce:GetCostAndUsage" |
| Duplicate | Check existing accounts | "Account already connected" |

---

## 6. API Security

### 6.1 Authentication Methods by API Surface

| API Surface | Auth Method | Description |
|-------------|-------------|-------------|
| AG-UI Streaming | Bearer JWT | Auth0 signature verification |
| REST Admin APIs | Bearer JWT | Auth0 signature verification |
| Webhook Ingestion | HMAC Signature | Per-provider secret |
| A2A Gateway | mTLS or API Key | Per-agent registration |

### 6.2 Rate Limiting

| Scope | Limit | Response |
|-------|-------|----------|
| Per IP (unauthenticated) | 100 req/min | 429 + Retry-After |
| Per user (authenticated) | 300 req/min | 429 + Retry-After |
| Per tenant | 1000 req/min | 429 + Retry-After |
| Per A2A agent | 10 req/min | 429 + Retry-After |

### 6.3 Cloud API Rate Limits

| Provider | Cloud Limit | Platform Limit (80%) |
|----------|-------------|---------------------|
| AWS Cost Explorer | 5 req/sec | 4 req/sec |
| Azure Cost Management | 30 req/min | 24 req/min |
| GCP Cloud Billing | 60 req/min | 48 req/min |
| OpenCost | 100 req/sec | 80 req/sec |

### 6.4 Security Headers

```
Authorization: Bearer <jwt_token>
X-Request-ID: <uuid>  # For distributed tracing
Content-Type: application/json
```

---

## 7. Webhook Security

### 7.1 Webhook Authentication by Provider

| Provider | Auth Method | Verification |
|----------|-------------|--------------|
| AWS SNS | HMAC Signature | Verify SNS message signature |
| Azure Action Groups | Shared Secret | HMAC validation |
| GCP Pub/Sub | OIDC Token | Verify Pub/Sub push token |
| Kubernetes | Bearer Token | Alertmanager token |

### 7.2 Webhook Processing Flow

```
Webhook received at /api/webhooks/{provider}
  → Verify signature/token (reject if invalid → 401)
    → Extract tenant_id from URL parameters
      → Validate tenant_id exists and is active
        → Parse provider-specific payload → common event format
          → Store in events table
            → Enqueue to Cloud Tasks (async processing)
              → Return 200 immediately (< 3 seconds)
```

### 7.3 Webhook URL Pattern

```
https://api.domain.com/api/webhooks/{provider}?tenant={tenant_id}&account={account_id}
```

---

## 8. Remediation Action Security

### 8.1 Action Risk Levels

| Risk Level | Examples | Approval Required |
|------------|----------|-------------------|
| Low | Stop dev instance, schedule stop | May auto-approve per policy |
| Medium | Rightsize production instance | Requires operator approval |
| High | Terminate resource, delete data | Requires org_admin approval |

### 8.2 Remediation Workflow

```
User clicks "Execute" on recommendation
  → Validate user has operator+ role
    → Determine action risk level from tenant policies
      → If approval needed:
          → Create approval workflow (Temporal)
          → Notify approvers
          → Wait for approval
      → If approved or auto-approved:
          → Execute dry_run first (preview changes)
          → Capture rollback state (pre-action snapshot)
          → Execute actual action
          → Confirm and return results
      → If rollback requested:
          → Verify rollback data exists
          → Execute reversal
          → Log rollback
```

### 8.3 execute_action Tool Security

| Check | Enforcement |
|-------|-------------|
| Role check | User must have operator+ role |
| Approval check | Action must be approved if policy requires |
| Resource ownership | Target resource must belong to tenant's account |
| Dry run | Always execute dry_run before actual |
| Rollback capture | Store previous state for reversal |
| Audit logging | Log all parameters, outcome, duration |

---

## 9. External Agent (A2A) Security

### 9.1 Agent Registration

All external A2A agents must be:
- Registered by an org_admin
- Approved before activation
- Rate-limited (default: 10 req/min)
- Read-only by default

### 9.2 A2A Agent Record

| Field | Purpose |
|-------|---------|
| name | Agent display name |
| type | slackbot / compliance_auditor / vendor_advisor / custom |
| endpoint | A2A endpoint URL |
| auth_method | mtls / api_key |
| api_key_hash | Hashed API key |
| certificate_fingerprint | mTLS cert fingerprint |
| capabilities | AgentCard capabilities (tools, permissions) |
| rate_limit | Requests per minute |
| status | active / suspended / pending_approval |

### 9.3 A2A Request Flow

```
External Agent sends A2A request
  → A2A Gateway validates auth (cert or API key)
    → Lookup agent registration → get tenant_id, permissions
      → Verify agent is active and not rate-limited
        → Construct TenantContext from registration (NOT from request)
          → Forward to Coordinator Agent
            → Return response in A2A format
```

### 9.4 A2A Security Constraints

| Constraint | Enforcement |
|------------|-------------|
| Tenant context | Derived from registration, not request |
| Permission scoping | Can only call tools in registration |
| Rate limiting | Per-agent limit (configurable) |
| Read-only default | No execute_action unless granted |
| Audit logging | Every request logged with agent identity |

---

## 10. Audit Logging

### 10.1 Audit Log Schema

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Primary key |
| tenant_id | UUID | Tenant scope |
| timestamp | Timestamp | Event time (UTC) |
| event_type | Enum | query / tool_call / remediation / login / config_change / approval / a2a_request |
| actor_type | Enum | user / agent / system / a2a_agent |
| actor_id | String | User ID, agent name, or system identifier |
| action | String | Specific action performed |
| target_type | String | Entity type affected |
| target_id | String | Entity ID affected |
| details | JSONB | Parameters, results, metadata |
| ip_address | String | Source IP |
| session_id | String | Session identifier |
| outcome | Enum | success / failure / denied |

### 10.2 Audit Rules

| Rule | Enforcement |
|------|-------------|
| Append-only | No UPDATE or DELETE at database level |
| 7-year retention | Compliance requirement |
| SIEM integration | Real-time streaming to Splunk/Datadog |
| Every MCP call logged | Tool, parameters, outcome, duration |
| Cache hit tracking | Log whether result was cached |

### 10.3 What Gets Logged

| Event | Logged Data |
|-------|-------------|
| User login | user_id, ip_address, auth_method |
| Cost query | query_params, date_range, cloud_accounts |
| Recommendation view | recommendation_id, user_id |
| Action execution | action_type, resource_id, dry_run, outcome |
| Approval | action_id, approver_id, decision |
| Config change | setting, old_value, new_value |
| A2A request | agent_id, tool_called, permissions_used |

---

## 11. Session Security

### 11.1 Conversation Context

| Setting | Value |
|---------|-------|
| Context buffer | Last 10 conversation turns |
| Session TTL | 30 minutes |
| Storage | Redis (optional) or in-memory |
| Older turns | Summarized to save tokens |

### 11.2 Session Cookies (Web UI)

| Setting | Value |
|---------|-------|
| Secure | true (HTTPS only) |
| HttpOnly | true (no JavaScript access) |
| SameSite | lax |

---

## 12. Security Checklist

### 12.1 Before Deployment

- [ ] Auth0 organization configured
- [ ] JWT validation middleware implemented
- [ ] RLS policies applied to all tables
- [ ] Secret Manager paths configured
- [ ] Rate limiting enabled at API Gateway
- [ ] HTTPS/TLS configured
- [ ] CORS origins restricted
- [ ] Audit logging enabled

### 12.2 Per-Tenant Onboarding

- [ ] Tenant record created
- [ ] Auth0 organization created
- [ ] First user assigned org_admin
- [ ] Cloud account credentials stored in Secret Manager
- [ ] Credential connectivity verified
- [ ] Webhook endpoints configured
- [ ] Initial audit log entry created

### 12.3 Ongoing Operations

- [ ] Monitor rate limit violations
- [ ] Review audit logs for anomalies
- [ ] Rotate API keys periodically
- [ ] Update Auth0 JWKS cache
- [ ] Review and revoke inactive agent registrations
- [ ] Verify backup encryption

---

## Developer Notes

> **DEV-SEC-001:** Never log credentials, API keys, or secrets. Use Secret Manager references only.

> **DEV-SEC-002:** All permission checks must happen before any data access. Check RBAC first, then proceed.

> **DEV-SEC-003:** TenantContext must be injected by the API layer, never constructed from user input.

> **DEV-SEC-004:** When adding new tables, always include `tenant_id` FK and create RLS policy.

> **DEV-SEC-005:** Webhook handlers must respond within 3 seconds. Use async processing via Cloud Tasks.

> **DEV-SEC-006:** External A2A agents are untrusted by default. Always validate against registration record.

> **DEV-SEC-007:** Audit log writes must never fail silently. Use async queue with retry if needed.

---

## Related Documents

- [01-database-schema.md](01-database-schema.md) - RLS implementation, audit_log table
- [02-mcp-tool-contracts.md](02-mcp-tool-contracts.md) - Credential flow, rate limiting
- [03-agent-routing-spec.md](03-agent-routing-spec.md) - JWT validation, RBAC enforcement
- [04-tenant-onboarding.md](04-tenant-onboarding.md) - Auth0 setup, credential storage
- [05-api-endpoint-spec.md](05-api-endpoint-spec.md) - API authentication, webhooks
- [ADR-009](../docs/adr/009-hybrid-agent-registration-pattern.md) - A2A agent registration
- [ADR-010](../docs/adr/010-agent-card-specification.md) - AgentCard permissions
