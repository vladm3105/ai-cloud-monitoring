# F1: Identity & Access Management (IAM) Module
## AI Cloud Cost Monitoring - Adapted Specification

**Module**: `ai-cost-monitoring/foundation/iam`
**Version**: 1.0.0
**Status**: Draft
**Source**: Trading Nexus F1 v1.2.0 (adapted)
**Date**: February 2026

---

## 1. Executive Summary

The F1 IAM Module provides authentication and authorization for the AI Cloud Cost Monitoring platform. Unlike the source Trading Nexus 4D Matrix, this adaptation uses a simplified **RBAC model** appropriate for a FinOps platform.

### Key Differences from Trading Nexus F1

| Aspect | Trading Nexus | Cloud Cost Monitoring |
|--------|---------------|----------------------|
| Authorization Model | 4D Matrix (ACTION × SKILL × RESOURCE × ZONE) | RBAC (5 roles) |
| Primary Auth | Auth0 | GCP IAM (single-owner), Auth0 (multi-tenant) |
| Trust Levels | 4 tiers | 5 roles (viewer → billing_admin) |
| Zones | paper/live/admin | Not applicable |
| Skills | 32 agent skills | Not applicable |

### Key Capabilities

| Capability | Description |
|------------|-------------|
| **Dual Authentication** | GCP IAM (internal) or Auth0 (SaaS) |
| **RBAC Authorization** | 5-role model with permission scopes |
| **Tenant Isolation** | RLS + namespace isolation |
| **TenantContext Injection** | Server-side context for all agents |
| **Domain Agnostic** | Configuration-driven, no business logic |

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    F1: IAM MODULE v1.0.0                         │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────┐ │
│  │  AUTHENTICATION  │  │  AUTHORIZATION   │  │ TENANT CONTEXT│ │
│  │                  │  │                  │  │               │ │
│  │  • GCP IAM       │  │  • RBAC Model    │  │ • Injection   │ │
│  │  • Auth0         │  │  • 5 Roles       │  │ • Propagation │ │
│  │  • Service Acct  │  │  • Permissions   │  │ • Validation  │ │
│  └──────────────────┘  └──────────────────┘  └───────────────┘ │
└─────────────────────────────────────────────────────────────────┘
         │                       │                    │
         ▼                       ▼                    ▼
┌─────────────┐          ┌─────────────┐      ┌─────────────┐
│F3 Observ.   │          │F7 Config    │      │ D1 Agents   │
│(Audit Logs) │          │(Roles YAML) │      │ (Context)   │
└─────────────┘          └─────────────┘      └─────────────┘
```

### Design Principles

| Principle | Description |
|-----------|-------------|
| **Zero Domain Knowledge** | IAM knows nothing about costs, clouds, or agents |
| **Configuration-Driven** | Roles and permissions defined in YAML |
| **Server-Side Context** | TenantContext injected, never from user input |
| **Fail-Secure** | Default deny; explicit grants required |
| **Cloud-Native** | Leverages GCP IAM and Secret Manager |

---

## 3. Authentication

### 3.1 Deployment Scenarios

| Scenario | Auth Method | Description |
|----------|-------------|-------------|
| **Single-Owner** | GCP IAM | Internal team using Google Workspace |
| **MVP SaaS** | Auth0 | Single-tenant with Auth0 |
| **Multi-Tenant** | Auth0 Organizations | Full multi-tenant SaaS |

### 3.2 GCP IAM (Single-Owner Mode)

For internal deployments with existing Google Workspace:

```yaml
# f1-iam-config.yaml (single-owner mode)
authentication:
  mode: gcp_iam
  allowed_domains:
    - company.com
  service_account:
    enabled: true
    key_source: workload_identity
```

**Flow:**
1. User authenticates via Google Workspace
2. Cloud Run validates IAM token
3. Map Google identity to internal user
4. Inject TenantContext (single tenant)

### 3.3 Auth0 (Multi-Tenant Mode)

For SaaS deployments:

```yaml
# f1-iam-config.yaml (multi-tenant mode)
authentication:
  mode: auth0
  domain: ${AUTH0_DOMAIN}
  audience: finops-platform
  organization:
    enabled: true  # Auth0 Organizations for multi-tenancy
```

**JWT Token Structure:**

```json
{
  "sub": "<user_id>",
  "org_id": "<tenant_id>",
  "roles": ["org_admin"],
  "permissions": ["read:costs", "write:remediation"],
  "aud": "finops-platform",
  "iss": "https://your-tenant.auth0.com/",
  "exp": "<timestamp>"
}
```

### 3.4 Service Authentication

For MCP servers and background jobs:

| Method | Use Case |
|--------|----------|
| **Workload Identity** | Cloud Run → GCP services |
| **Service Account Key** | External integrations (avoid if possible) |
| **API Key** | Rate-limited external access |

---

## 4. Authorization (RBAC)

### 4.1 Role Hierarchy

```
┌─────────────────────────────────────────────────┐
│           super_admin (Platform)                │
│     Full platform access, exceeds tenants       │
└─────────────────────────────────────────────────┘
                       │
┌─────────────────────────────────────────────────┐
│              org_admin (Tenant)                  │
│    Full access within organization              │
├─────────────────────────────────────────────────┤
│              operator (Tenant)                   │
│    Execute remediation, approve medium-risk     │
├─────────────────────────────────────────────────┤
│              analyst (Tenant)                    │
│    View + dismiss, request approvals            │
├─────────────────────────────────────────────────┤
│              viewer (Tenant)                     │
│    Read-only access                             │
└─────────────────────────────────────────────────┘
```

### 4.2 Permission Scopes

| Scope | Description |
|-------|-------------|
| `read:costs` | View cost data and anomalies |
| `read:resources` | View cloud resource inventory |
| `read:recommendations` | View optimization suggestions |
| `write:remediation` | Execute cloud actions |
| `manage:policies` | Configure tenant policies |
| `manage:accounts` | Add/remove cloud accounts |
| `manage:users` | User invitation and role assignment |

### 4.3 Permission Matrix

| Permission | viewer | analyst | operator | org_admin |
|------------|:------:|:-------:|:--------:|:---------:|
| `read:costs` | ✓ | ✓ | ✓ | ✓ |
| `read:resources` | ✓ | ✓ | ✓ | ✓ |
| `read:recommendations` | ✓ | ✓ | ✓ | ✓ |
| `write:remediation` | ✗ | ✗ | ✓ | ✓ |
| `manage:policies` | ✗ | ✗ | ✗ | ✓ |
| `manage:accounts` | ✗ | ✗ | ✗ | ✓ |
| `manage:users` | ✗ | ✗ | ✗ | ✓ |

### 4.4 Configuration Schema

```yaml
# f1-authorization-config.yaml
authorization:
  model: rbac

  roles:
    - id: viewer
      description: Read-only access
      permissions:
        - read:costs
        - read:resources
        - read:recommendations

    - id: analyst
      description: View + analysis capabilities
      inherits: viewer
      permissions:
        - dismiss:recommendations
        - request:approval

    - id: operator
      description: Can execute remediation
      inherits: analyst
      permissions:
        - write:remediation
        - approve:low_risk
        - approve:medium_risk

    - id: org_admin
      description: Full tenant access
      inherits: operator
      permissions:
        - approve:high_risk
        - manage:policies
        - manage:accounts
        - manage:users
```

---

## 5. TenantContext

### 5.1 Context Object

Every agent and API handler receives this after authentication:

```python
@dataclass
class TenantContext:
    """Injected by F1 IAM after JWT validation."""
    tenant_id: UUID       # From JWT org_id claim
    user_id: UUID         # From JWT sub claim
    roles: List[str]      # From JWT roles claim
    permissions: Set[str] # Expanded from roles
    cloud_accounts: List[CloudAccount]  # DB lookup
    plan: str             # Subscription tier
    timezone: str         # Tenant preference

    def has_permission(self, permission: str) -> bool:
        return permission in self.permissions

    def can_access_account(self, account_id: str) -> bool:
        return any(a.id == account_id for a in self.cloud_accounts)
```

### 5.2 Context Injection Points

| Layer | Injection Method |
|-------|-----------------|
| **AG-UI Server** | Middleware after JWT validation |
| **MCP Servers** | Context passed from coordinator |
| **Cloud Tasks** | Serialized in task payload |
| **Pub/Sub** | Message attribute |

### 5.3 Context Propagation

```python
# Coordinator Agent injects context to domain agents
async def route_to_cost_agent(query: str, context: TenantContext):
    # Context automatically scopes all operations
    return await cost_agent.execute(
        query=query,
        tenant_context=context  # Never from user input
    )
```

---

## 6. Tenant Isolation

### 6.1 Multi-Layer Strategy

| Layer | Mechanism | Enforcement |
|-------|-----------|-------------|
| **PostgreSQL** | Row-Level Security | `SET app.current_tenant` |
| **BigQuery** | Authorized views | Account filter |
| **Firestore** | Collection paths | `tenants/{id}/...` |
| **Redis** | Key namespacing | `tenant:{id}:*` prefix |
| **Storage** | Path isolation | `/{tenant_id}/` prefix |

### 6.2 RLS Implementation

```sql
-- Enable RLS on all tenant-scoped tables
ALTER TABLE cloud_accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON cloud_accounts
  USING (tenant_id = current_setting('app.current_tenant')::uuid);

-- Connection setup (from TenantContext)
SET app.current_tenant = '{tenant_context.tenant_id}';
```

---

## 7. Public Interface

```python
class IAMModule:
    """Foundation Module F1: Identity & Access Management"""

    # Authentication
    async def authenticate(self, token: str) -> AuthResult:
        """Validate JWT and return claims."""

    async def create_tenant_context(self, claims: TokenClaims) -> TenantContext:
        """Build TenantContext from validated claims."""

    # Authorization
    async def authorize(
        self,
        context: TenantContext,
        permission: str,
        resource_id: Optional[str] = None
    ) -> AuthzDecision:
        """Check if context has permission on resource."""

    async def check_action_risk(
        self,
        context: TenantContext,
        action: RemediationAction
    ) -> RiskLevel:
        """Determine approval requirements for action."""

    # User Management
    async def invite_user(
        self,
        context: TenantContext,
        email: str,
        role: str
    ) -> Invitation:
        """Invite user to tenant with role."""

    async def list_users(self, context: TenantContext) -> List[User]:
        """List users in tenant."""
```

---

## 8. Events

All authentication and authorization actions emit events for F3 Observability:

| Event | Description |
|-------|-------------|
| `iam.auth.success` | Successful authentication |
| `iam.auth.failure` | Failed authentication attempt |
| `iam.authz.granted` | Permission check passed |
| `iam.authz.denied` | Permission check failed |
| `iam.user.invited` | User invitation sent |
| `iam.user.role_changed` | User role updated |

---

## 9. Dependencies

| Module | Dependency Type | Description |
|--------|----------------|-------------|
| **F7 Config** | Upstream | Role definitions, auth settings |
| **F3 Observability** | Downstream | Audit events |
| **F6 Infrastructure** | Upstream | Secret Manager for credentials |

---

## 10. MVP Scope

### Included in MVP

- [x] GCP IAM authentication (single-owner)
- [x] Auth0 authentication (optional)
- [x] RBAC with 5 roles
- [x] TenantContext injection
- [x] Permission checks
- [x] Firestore tenant isolation

### Deferred to Phase 4

- [ ] Enterprise SSO (SAML/OIDC)
- [ ] MFA enforcement
- [ ] Advanced audit logging
- [ ] API key management portal

---

*Adapted from Trading Nexus F1 v1.2.0 — February 2026*
