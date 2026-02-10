# MVP Architecture: Single-Tenant Cloud Cost Monitoring

**Document:** MVP_ARCHITECTURE.md
**Version:** 1.0.0
**Date:** 2026-02-07T00:00:00
**Status:** Approved
**Scope:** Single-tenant MVP with multi-tenant readiness

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Architecture Principles](#2-architecture-principles)
3. [System Architecture](#3-system-architecture)
4. [Service Components](#4-service-components)
5. [Data Architecture](#5-data-architecture)
6. [Multi-Tenant Readiness](#6-multi-tenant-readiness)
7. [Cost Estimate](#7-cost-estimate)
8. [Migration Path](#8-migration-path)

---

## 1. Executive Summary

### 1.1 MVP Scope

| Aspect | MVP Decision |
|--------|--------------|
| Tenancy | Single-tenant (one organization) |
| Home Cloud | GCP |
| Database | Firestore (config) + BigQuery (cost data) |
| PostgreSQL | Deferred to multi-tenant phase |
| Authentication | Auth0 free tier or GCP Identity Platform |
| Monitored Clouds | AWS, Azure, GCP, Kubernetes |

### 1.2 Home Cloud vs Monitored Clouds

**Critical Distinction:**

| Concept             | Definition                                 | MVP Implementation                   |
|---------------------|--------------------------------------------|------------------------------------- |
| **Home Cloud**      | Where the platform infrastructure runs     | GCP (Cloud Run, Firestore, BigQuery) |
| **Monitored Clouds**| What clouds the platform analyzes for costs| AWS, Azure, GCP, Kubernetes          |

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         HOME CLOUD: GCP                                      │
│  (Platform Infrastructure - where our code runs)                             │
│                                                                              │
│  Cloud Run │ Firestore │ BigQuery │ Secret Manager │ Cloud Scheduler        │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
                                   │ Monitors via APIs
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        ▼                          ▼                          ▼
┌───────────────┐         ┌───────────────┐         ┌───────────────┐
│     AWS       │         │    AZURE      │         │  KUBERNETES   │
│ Cost Explorer │         │Cost Management│         │   OpenCost    │
│     API       │         │     API       │         │     API       │
└───────────────┘         └───────────────┘         └───────────────┘

        ▲
        │
┌───────────────┐
│     GCP       │  ◄── GCP is BOTH home cloud AND monitored
│   Billing     │
│    Export     │
└───────────────┘
```

**Why This Matters:**

- Platform costs are fixed (GCP infrastructure ~$0-10/month for MVP)
- Can monitor unlimited cloud accounts across any provider
- No vendor lock-in for monitored clouds
- GCP billing data accessed directly via BigQuery (most efficient)

### 1.3 Design Philosophy

- **Simplicity first**: Minimize infrastructure for faster time-to-value
- **Cost efficiency**: Leverage free tiers aggressively
- **Multi-tenant ready**: Design abstractions that scale to multi-tenant
- **No premature optimization**: Add complexity only when needed

### 1.3 Monthly Cost Target

| Component | MVP Cost | Multi-Tenant Cost |
|-----------|----------|-------------------|
| Compute (Cloud Run) | $0-5 | $20-50 |
| Analytics (BigQuery) | $0 | $5-20 |
| Config Store (Firestore) | $0 | $0-5 |
| Secrets (Secret Manager) | $0 | $1-3 |
| Logging | $0 | $0-10 |
| Database (PostgreSQL) | $0 (not used) | $19-50 |
| **Total** | **$0-10** | **$50-140** |

---

## 2. Architecture Principles

### 2.1 MVP Constraints

| Principle | Implementation |
|-----------|----------------|
| No PostgreSQL in MVP | Use Firestore for config, BigQuery for analytics |
| Stateless services | All state in managed services, not in containers |
| Scale-to-zero | Cloud Run with min instances = 0 |
| Free tier first | Stay within free limits for MVP validation |
| Config as code | Budget thresholds in Firestore, not hardcoded |

### 2.2 Multi-Tenant Readiness Patterns

Even in single-tenant MVP, use these patterns for future scalability:

| Pattern | MVP Implementation | Multi-Tenant Upgrade |
|---------|-------------------|----------------------|
| Tenant context | Hardcoded `DEFAULT_TENANT` constant | JWT claim `tenant_id` |
| Data isolation | Single Firestore collection | Collection per tenant or RLS |
| Credential scope | Single Secret Manager path | Path includes `tenant_id` |
| BigQuery access | Direct project access | Authorized views per tenant |

---

## 3. System Architecture

### 3.1 High-Level Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              END USERS                                       │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CLOUDFLARE (FREE TIER)                               │
│                    DNS, CDN, WAF, DDoS Protection                            │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         GCP (us-central1) - HOME CLOUD                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                         CLOUD RUN                                     │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐       │   │
│  │  │  cost-monitor   │  │  ui-server      │  │  mcp-server     │       │   │
│  │  │  (API + Agent)  │  │  (Next.js SSR)  │  │  (Tool Server)  │       │   │
│  │  │  Min: 0, Max: 3 │  │  Min: 0, Max: 2 │  │  Min: 0, Max: 3 │       │   │
│  │  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘       │   │
│  └───────────┼────────────────────┼────────────────────┼────────────────┘   │
│              │                    │                    │                    │
│              └────────────────────┼────────────────────┘                    │
│                                   │                                         │
│  ┌────────────────────────────────┼────────────────────────────────────┐   │
│  │                                ▼                                     │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐      │   │
│  │  │    FIRESTORE    │  │    BIGQUERY     │  │ SECRET MANAGER  │      │   │
│  │  │  (Config/Prefs) │  │  (Cost Data)    │  │  (Credentials)  │      │   │
│  │  │                 │  │                 │  │                 │      │   │
│  │  │  - budgets      │  │  - billing      │  │  - aws_creds    │      │   │
│  │  │  - thresholds   │  │    export       │  │  - azure_creds  │      │   │
│  │  │  - preferences  │  │  - cost_metrics │  │  - gcp_sa_key   │      │   │
│  │  │  - alerts       │  │  - forecasts    │  │  - k8s_config   │      │   │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘      │   │
│  │                         DATA LAYER                                   │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                      OPERATIONS                                       │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐       │   │
│  │  │ Cloud Scheduler │  │  Cloud Logging  │  │ Cloud Monitoring│       │   │
│  │  │ (Cost Sync Job) │  │  (50GB Free)    │  │  (Alerting)     │       │   │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘       │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
            ┌──────────────────────────┼──────────────────────────┐
            ▼                          ▼                          ▼
┌─────────────────────┐   ┌─────────────────────┐   ┌─────────────────────┐
│        AWS          │   │       AZURE         │   │    KUBERNETES       │
│  Cost Explorer API  │   │ Cost Management API │   │     OpenCost        │
│  (Monitored)        │   │  (Monitored)        │   │    (Monitored)      │
└─────────────────────┘   └─────────────────────┘   └─────────────────────┘
```

### 3.2 Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DATA FLOW                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  1. COST DATA COLLECTION                                                     │
│     ┌─────────────┐                                                          │
│     │ Cloud       │──▶ Triggers cost-monitor service every 4 hours          │
│     │ Scheduler   │                                                          │
│     └─────────────┘                                                          │
│            │                                                                 │
│            ▼                                                                 │
│     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                 │
│     │ cost-monitor│────▶│ Secret Mgr  │────▶│ Cloud APIs  │                 │
│     │ service     │     │ (get creds) │     │ (fetch cost)│                 │
│     └──────┬──────┘     └─────────────┘     └─────────────┘                 │
│            │                                                                 │
│            ▼                                                                 │
│     ┌─────────────┐                                                          │
│     │  BigQuery   │◀── Store normalized cost data                           │
│     │             │                                                          │
│     └─────────────┘                                                          │
│                                                                              │
│  2. USER QUERY                                                               │
│     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                 │
│     │    User     │────▶│  ui-server  │────▶│ mcp-server  │                 │
│     │   Request   │     │             │     │  (agent)    │                 │
│     └─────────────┘     └─────────────┘     └──────┬──────┘                 │
│                                                     │                        │
│                         ┌───────────────────────────┼───────────────────┐   │
│                         ▼                           ▼                   ▼   │
│                  ┌─────────────┐           ┌─────────────┐     ┌──────────┐│
│                  │  BigQuery   │           │  Firestore  │     │ LLM API  ││
│                  │ (cost data) │           │  (config)   │     │(analysis)││
│                  └─────────────┘           └─────────────┘     └──────────┘│
│                                                                              │
│  3. ALERTING                                                                 │
│     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                 │
│     │  BigQuery   │────▶│ cost-monitor│────▶│  Firestore  │                 │
│     │  (current   │     │ (threshold  │     │  (alert     │                 │
│     │   spend)    │     │  check)     │     │   config)   │                 │
│     └─────────────┘     └─────────────┘     └──────┬──────┘                 │
│                                                     │                        │
│                                                     ▼                        │
│                                              ┌─────────────┐                 │
│                                              │ Notification│                 │
│                                              │ (Email/Slack│                 │
│                                              └─────────────┘                 │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Service Components

### 4.1 Cloud Run Services

| Service | Purpose | Resources | Scale |
|---------|---------|-----------|-------|
| **cost-monitor** | Cost collection, threshold checks, API | 512MB, 1 vCPU | 0-3 |
| **ui-server** | Next.js frontend with SSR | 256MB, 0.5 vCPU | 0-2 |
| **mcp-server** | MCP tool server for AI agent | 512MB, 1 vCPU | 0-3 |

### 4.2 Service Details

#### cost-monitor

```yaml
name: cost-monitor
runtime: python3.11
memory: 512Mi
cpu: 1
timeout: 300s
min_instances: 0
max_instances: 3
concurrency: 40

endpoints:
  - GET /health
  - GET /api/costs/summary
  - GET /api/costs/by-service
  - GET /api/costs/by-account
  - GET /api/costs/forecast
  - POST /api/sync/trigger
  - GET /api/alerts/status

triggers:
  - Cloud Scheduler: every 4 hours (cost sync)
  - Cloud Scheduler: every 15 minutes (threshold check)
```

#### mcp-server

```yaml
name: mcp-server
runtime: python3.11
memory: 512Mi
cpu: 1
timeout: 300s
min_instances: 0
max_instances: 3
concurrency: 20

tools:
  - get_cost_summary
  - get_cost_breakdown
  - get_recommendations
  - get_forecast
  - compare_periods
  - explain_anomaly

dependencies:
  - BigQuery (cost data)
  - Firestore (config)
  - Secret Manager (LLM API key)
  - LiteLLM (LLM abstraction)
```

---

## 5. Data Architecture

### 5.1 Firestore Collections (MVP)

```
firestore/
├── config/                     # Application configuration
│   └── settings (document)
│       ├── default_currency: "USD"
│       ├── sync_interval_hours: 4
│       ├── retention_days: 90
│       └── features: { forecasting: true, recommendations: true }
│
├── budgets/                    # Budget definitions
│   └── {budget_id} (document)
│       ├── name: "Monthly Cloud Budget"
│       ├── amount: 500.00
│       ├── period: "monthly"
│       ├── alerts: [50, 80, 95, 100]
│       └── scope: { providers: ["aws", "gcp"], accounts: ["all"] }
│
├── cloud_accounts/             # Connected cloud accounts
│   └── {account_id} (document)
│       ├── provider: "aws"
│       ├── display_name: "Production AWS"
│       ├── account_identifier: "123456789012"
│       ├── credential_secret: "projects/xxx/secrets/aws-prod"
│       ├── status: "active"
│       ├── last_sync: Timestamp
│       └── config: { regions: ["us-east-1", "us-west-2"] }
│
├── alerts/                     # Alert history
│   └── {alert_id} (document)
│       ├── type: "budget_threshold"
│       ├── budget_id: "xxx"
│       ├── threshold_percent: 80
│       ├── current_spend: 420.50
│       ├── triggered_at: Timestamp
│       └── acknowledged: false
│
└── preferences/                # User preferences
    └── ui (document)
        ├── theme: "light"
        ├── default_view: "dashboard"
        ├── chart_type: "bar"
        └── notifications: { email: true, slack: false }
```

### 5.2 BigQuery Schema (Cost Data)

```sql
-- Dataset: cost_monitoring

-- Table: cost_daily (partitioned by date, clustered by provider)
CREATE TABLE cost_monitoring.cost_daily (
  date DATE NOT NULL,
  provider STRING NOT NULL,           -- aws, azure, gcp, kubernetes
  account_id STRING NOT NULL,         -- Cloud account identifier
  service STRING NOT NULL,            -- Service name (EC2, Cloud Run, etc.)
  region STRING,                      -- Region if applicable
  cost_usd NUMERIC(12,4) NOT NULL,    -- Cost in USD
  usage_quantity NUMERIC(18,6),       -- Usage amount
  usage_unit STRING,                  -- Usage unit (hours, GB, requests)
  tags JSON,                          -- Resource tags
  ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY date
CLUSTER BY provider, account_id;

-- Table: cost_hourly (for high-resolution monitoring)
CREATE TABLE cost_monitoring.cost_hourly (
  timestamp TIMESTAMP NOT NULL,
  provider STRING NOT NULL,
  account_id STRING NOT NULL,
  service STRING NOT NULL,
  cost_usd NUMERIC(12,4) NOT NULL,
  ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(timestamp)
CLUSTER BY provider;

-- View: cost_summary (aggregated view for dashboards)
CREATE VIEW cost_monitoring.cost_summary AS
SELECT
  date,
  provider,
  SUM(cost_usd) as total_cost,
  COUNT(DISTINCT service) as service_count,
  COUNT(DISTINCT account_id) as account_count
FROM cost_monitoring.cost_daily
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
GROUP BY date, provider;

-- View: cost_by_service (top services)
CREATE VIEW cost_monitoring.cost_by_service AS
SELECT
  provider,
  service,
  SUM(cost_usd) as total_cost,
  AVG(cost_usd) as avg_daily_cost
FROM cost_monitoring.cost_daily
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY provider, service
ORDER BY total_cost DESC;
```

### 5.3 Secret Manager Structure

```
projects/{project-id}/secrets/
├── aws-credentials              # AWS IAM credentials (JSON)
│   └── { "access_key_id": "...", "secret_access_key": "...", "role_arn": "..." }
│
├── azure-credentials            # Azure Service Principal (JSON)
│   └── { "tenant_id": "...", "client_id": "...", "client_secret": "...", "subscription_id": "..." }
│
├── gcp-service-account          # GCP SA key for cross-project access (JSON)
│   └── { "type": "service_account", "project_id": "...", ... }
│
├── kubernetes-config            # Kubeconfig for K8s clusters (YAML)
│   └── <kubeconfig content>
│
├── llm-api-key                  # LLM provider API key
│   └── sk-...
│
└── notification-config          # Slack webhook, email SMTP (JSON)
    └── { "slack_webhook": "...", "smtp_host": "...", ... }
```

---

## 6. Multi-Tenant Readiness

### 6.1 Abstraction Patterns

Even in single-tenant MVP, implement these abstractions:

#### Tenant Context

```python
# mvp/context.py
from dataclasses import dataclass
from typing import Optional

@dataclass
class TenantContext:
    tenant_id: str
    tenant_name: str
    plan: str = "free"

# MVP: Hardcoded default tenant
DEFAULT_TENANT = TenantContext(
    tenant_id="default",
    tenant_name="Default Organization",
    plan="free"
)

def get_current_tenant() -> TenantContext:
    """
    MVP: Returns default tenant.
    Multi-tenant: Extract from JWT claim.
    """
    # TODO: In multi-tenant, extract from request context
    # tenant_id = get_jwt_claim("tenant_id")
    # return load_tenant(tenant_id)
    return DEFAULT_TENANT
```

#### Data Access Layer

```python
# mvp/data_access.py
from google.cloud import firestore, bigquery

class ConfigStore:
    """
    Abstraction over Firestore.
    MVP: Single collection.
    Multi-tenant: Collection per tenant or subcollection.
    """

    def __init__(self, tenant_id: str = "default"):
        self.db = firestore.Client()
        self.tenant_id = tenant_id
        # MVP: Single collection
        # Multi-tenant: f"tenants/{tenant_id}/config"
        self.collection = self.db.collection("config")

    def get_budgets(self) -> list:
        # MVP: All budgets belong to default tenant
        # Multi-tenant: Filter by tenant_id
        return [doc.to_dict() for doc in self.collection.document("budgets").collections()]

class CostStore:
    """
    Abstraction over BigQuery.
    MVP: Direct table access.
    Multi-tenant: Authorized views with tenant filter.
    """

    def __init__(self, tenant_id: str = "default"):
        self.client = bigquery.Client()
        self.tenant_id = tenant_id
        self.dataset = "cost_monitoring"

    def get_cost_summary(self, days: int = 30) -> list:
        # MVP: No tenant filter needed
        # Multi-tenant: Add WHERE tenant_id = @tenant_id
        query = f"""
        SELECT date, provider, SUM(cost_usd) as total
        FROM `{self.dataset}.cost_daily`
        WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL {days} DAY)
        GROUP BY date, provider
        ORDER BY date
        """
        return list(self.client.query(query).result())
```

#### Credential Access

```python
# mvp/credentials.py
from google.cloud import secretmanager

class CredentialManager:
    """
    Abstraction over Secret Manager.
    MVP: Flat secret paths.
    Multi-tenant: Tenant-prefixed paths.
    """

    def __init__(self, project_id: str, tenant_id: str = "default"):
        self.client = secretmanager.SecretManagerServiceClient()
        self.project_id = project_id
        self.tenant_id = tenant_id

    def _secret_path(self, secret_name: str) -> str:
        # MVP: projects/{project}/secrets/{secret_name}
        # Multi-tenant: projects/{project}/secrets/{tenant_id}-{secret_name}
        return f"projects/{self.project_id}/secrets/{secret_name}/versions/latest"

    def get_aws_credentials(self) -> dict:
        path = self._secret_path("aws-credentials")
        response = self.client.access_secret_version(name=path)
        return json.loads(response.payload.data.decode())
```

### 6.2 Migration Checklist (MVP → Multi-Tenant)

When ready to add multi-tenancy:

| Step | Action | Complexity |
|------|--------|------------|
| 1 | Add Neon.tech PostgreSQL | Low |
| 2 | Create `tenants`, `users` tables with RLS | Medium |
| 3 | Update Auth0 for multi-tenant orgs | Low |
| 4 | Migrate Firestore data to PostgreSQL | Medium |
| 5 | Add `tenant_id` to BigQuery tables | Low |
| 6 | Create authorized views per tenant | Medium |
| 7 | Update Secret Manager paths | Low |
| 8 | Add tenant context middleware | Low |

---

## 7. Cost Estimate

### 7.1 MVP Monthly Costs

| Service | Free Tier | Expected Usage | Cost |
|---------|-----------|----------------|------|
| Cloud Run | 2M requests, 180K vCPU-sec | ~500K requests | $0 |
| BigQuery | 10GB storage, 1TB queries | ~5GB, ~100GB queries | $0 |
| Firestore | 1GB storage, 50K reads/day | ~100MB, ~10K reads/day | $0 |
| Secret Manager | 6 secrets free | 5 secrets | $0 |
| Cloud Logging | 50GB/month | ~5GB | $0 |
| Cloud Scheduler | 3 jobs free | 2 jobs | $0 |
| Cloudflare | Unlimited | CDN + DNS | $0 |
| **Total** | | | **$0-5** |

### 7.2 Growth Projection

| Stage | Users | Requests/mo | BigQuery | Est. Cost |
|-------|-------|-------------|----------|-----------|
| MVP | 1-5 | 100K | 10GB | $0 |
| Early | 10-20 | 500K | 50GB | $5-15 |
| Growth | 50-100 | 2M | 200GB | $30-60 |
| Multi-tenant | 100+ | 5M+ | 500GB+ | $100+ |

---

## 8. Migration Path

### 8.1 Phase 1: MVP (Current)

```
Duration: 4-6 weeks
Stack: Cloud Run + Firestore + BigQuery + Secret Manager
Database: None (Firestore for config)
Tenancy: Single
Auth: Basic (API key or Auth0 free)
```

### 8.2 Phase 2: Enhanced MVP

```
Duration: 2-4 weeks after MVP
Additions:
  - Full Auth0 integration
  - Slack/Email notifications
  - Basic forecasting
  - Optimization recommendations
Stack: Same as MVP
```

### 8.3 Phase 3: Pre-Multi-Tenant

```
Duration: 4-6 weeks
Additions:
  - Neon.tech PostgreSQL ($19/mo)
  - Tenant/User tables with RLS
  - Migrate config from Firestore
  - Auth0 Organizations
Stack: Cloud Run + PostgreSQL + BigQuery + Firestore (cache only)
```

### 8.4 Phase 4: Multi-Tenant Production

```
Duration: 4-8 weeks
Additions:
  - Full tenant isolation
  - Per-tenant billing
  - Admin dashboard
  - Audit logging
Stack: Cloud Run + PostgreSQL + BigQuery
Consider: Cloud SQL if compliance requires
```

---

## Appendix: Related Documents

- [ADR-002: GCP as First Home Cloud](../adr/002-gcp-only-first.md)
- [ADR-008: Database Strategy](../adr/008-database-strategy-mvp.md) (to be created)
- [CLOUD_PLATFORM_COMPARISON.md](CLOUD_PLATFORM_COMPARISON.md)
- [MULTI_CLOUD_INFRASTRUCTURE.md](../MULTI_CLOUD_INFRASTRUCTURE.md) (legacy, to be updated)
