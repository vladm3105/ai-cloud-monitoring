# F6: Infrastructure Module
## AI Cloud Cost Monitoring - Adapted Specification

**Module**: `ai-cost-monitoring/foundation/infrastructure`
**Version**: 1.0.0
**Status**: Draft
**Source**: Trading Nexus F6 v1.2.0 (adapted)
**Date**: 2026-02-10T15:00:00

---

## 1. Executive Summary

The F6 Infrastructure Module provides cloud-agnostic abstractions for compute, database, AI services, and critically for this platform: **cloud billing APIs**. Since multi-cloud cost monitoring is the core value proposition, this module defines the abstraction layer for GCP, AWS, and Azure billing integrations.

### Key Capabilities

| Capability | Description |
|------------|-------------|
| **Compute Abstraction** | Cloud Run (GCP), Fargate (AWS), Container Apps (Azure) |
| **Database Abstraction** | Firestore/Cloud SQL (GCP), DynamoDB/RDS (AWS) |
| **Secret Management** | Secret Manager (GCP), Secrets Manager (AWS), Key Vault (Azure) |
| **Billing API Abstraction** | Unified interface for cost data across providers |
| **MCP Server Infrastructure** | Patterns for building cloud MCP servers |

### Key Difference from Trading Nexus

| Aspect | Trading Nexus | Cloud Cost Monitoring |
|--------|---------------|----------------------|
| **Primary Focus** | General cloud compute | **Cloud Billing APIs** |
| **Data Source** | IB API (trading) | BigQuery, Cost Explorer, Cost Management |
| **Multi-Cloud** | Optional | **Core requirement** |

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                 F6: INFRASTRUCTURE v1.0.0                        │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   COMPUTE   │  │  DATABASE   │  │   SECRETS   │             │
│  │             │  │             │  │             │             │
│  │ • Cloud Run │  │ • Firestore │  │ • Secret Mgr│             │
│  │ • Fargate   │  │ • BigQuery  │  │ • AWS SM    │             │
│  │ • ACI       │  │ • DynamoDB  │  │ • Key Vault │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              CLOUD BILLING API ABSTRACTION                 │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │  │
│  │  │   GCP    │  │   AWS    │  │  AZURE   │  │ OPENCOST │   │  │
│  │  │ BigQuery │  │Cost Exp. │  │Cost Mgmt │  │   K8s    │   │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
            ┌─────────────┐     ┌─────────────┐
            │ MCP SERVERS │     │   AGENTS    │
            │ (per cloud) │     │ (domain)    │
            └─────────────┘     └─────────────┘
```

---

## 3. Cloud Billing API Abstraction

### 3.1 Unified Cost Interface

All cloud MCP servers implement this interface:

```python
from typing import Protocol, List, Optional
from datetime import date
from decimal import Decimal

class CloudCostProvider(Protocol):
    """Unified interface for cloud billing data."""

    async def get_costs(
        self,
        start_date: date,
        end_date: date,
        granularity: str = "DAILY",  # DAILY, MONTHLY
        group_by: Optional[List[str]] = None,  # service, project, region
        filters: Optional[dict] = None
    ) -> CostResult:
        """Retrieve cost data from cloud provider."""

    async def get_forecast(
        self,
        start_date: date,
        end_date: date,
        granularity: str = "MONTHLY"
    ) -> ForecastResult:
        """Get cost forecast."""

    async def get_recommendations(
        self,
        category: Optional[str] = None  # compute, storage, network
    ) -> List[Recommendation]:
        """Fetch optimization recommendations."""

    async def get_resources(
        self,
        resource_type: Optional[str] = None
    ) -> List[Resource]:
        """List cloud resources with cost attribution."""
```

### 3.2 Cost Result Schema

```python
@dataclass
class CostResult:
    """Normalized cost data across providers."""
    provider: str  # gcp, aws, azure
    currency: str  # USD
    time_period: TimePeriod
    total_cost: Decimal
    breakdown: List[CostBreakdown]

@dataclass
class CostBreakdown:
    """Cost breakdown by dimension."""
    dimension: str  # service, project, region
    value: str  # e.g., "Cloud Run", "my-project"
    cost: Decimal
    usage_quantity: Optional[float]
    usage_unit: Optional[str]
```

### 3.3 Provider Implementations

#### GCP (Primary - per ADR-002)

```yaml
# f6-gcp-config.yaml
gcp:
  billing:
    source: bigquery
    dataset: ${BILLING_DATASET}  # e.g., billing_export
    table: gcp_billing_export_v1
    project: ${GCP_PROJECT}

  recommendations:
    source: recommender_api
    recommenders:
      - google.compute.instance.MachineTypeRecommender
      - google.compute.commitment.UsageCommitmentRecommender

  authentication:
    method: workload_identity
```

**BigQuery Cost Query Pattern:**

```sql
SELECT
  DATE(usage_start_time) as date,
  service.description as service,
  project.id as project,
  SUM(cost) as cost,
  SUM(usage.amount) as usage_amount,
  usage.unit as usage_unit
FROM `project.dataset.gcp_billing_export_v1`
WHERE DATE(usage_start_time) BETWEEN @start_date AND @end_date
  AND project.id IN UNNEST(@authorized_projects)
GROUP BY date, service, project, usage_unit
ORDER BY date, cost DESC
```

#### AWS (Phase 2)

```yaml
# f6-aws-config.yaml
aws:
  billing:
    source: cost_explorer
    region: us-east-1

  recommendations:
    source: compute_optimizer

  authentication:
    method: assume_role
    role_arn: ${AWS_ROLE_ARN}
```

#### Azure (Phase 2)

```yaml
# f6-azure-config.yaml
azure:
  billing:
    source: cost_management
    subscription_id: ${AZURE_SUBSCRIPTION}

  recommendations:
    source: advisor_api

  authentication:
    method: service_principal
    tenant_id: ${AZURE_TENANT}
```

---

## 4. Compute Abstraction

### 4.1 Container Runtime

Per ADR-004, Cloud Run is the primary compute platform:

| Feature | Cloud Run | Fargate | Container Apps |
|---------|-----------|---------|----------------|
| **Scaling** | 0 to N | 1 to N | 0 to N |
| **Cold Start** | ~500ms | ~30s | ~5s |
| **Memory** | 32 GiB max | 120 GiB | 32 GiB |
| **Concurrency** | 1000 req | - | 100 |

### 4.2 Container Configuration

```yaml
# f6-compute-config.yaml
compute:
  provider: cloud_run

  services:
    - name: ag-ui-server
      memory: 512Mi
      cpu: 1
      min_instances: 0
      max_instances: 10
      concurrency: 80

    - name: gcp-mcp-server
      memory: 256Mi
      cpu: 1
      min_instances: 0
      max_instances: 5
      timeout: 300s

    - name: coordinator-agent
      memory: 1Gi
      cpu: 2
      min_instances: 1  # Always warm
      max_instances: 20
```

---

## 5. Database Abstraction

### 5.1 Database Strategy (per ADR-008)

| Phase | Metadata | Analytics |
|-------|----------|-----------|
| **MVP** | Firestore | BigQuery |
| **Production** | PostgreSQL + RLS | BigQuery |

### 5.2 Firestore Schema (MVP)

```
tenants/
  {tenant_id}/
    config/
      settings
      policies
    cloud_accounts/
      {account_id}
    users/
      {user_id}
    conversations/
      {conversation_id}
```

### 5.3 PostgreSQL Schema (Production)

See `00_REF/domain/01-database-schema.md` for full schema with RLS policies.

### 5.4 BigQuery Analytics

```yaml
# f6-bigquery-config.yaml
bigquery:
  project: ${GCP_PROJECT}
  datasets:
    - name: billing_export
      description: Raw billing data from cloud providers
    - name: cost_analytics
      description: Processed cost metrics and aggregations
    - name: llm_usage
      description: LLM token and cost tracking
```

---

## 6. Secret Management

### 6.1 Cloud Credential Storage

Per existing ADRs, all cloud credentials stored in Secret Manager:

```yaml
# f6-secrets-config.yaml
secrets:
  provider: gcp_secret_manager
  project: ${GCP_PROJECT}

  patterns:
    cloud_credentials: "cloud-creds/{tenant_id}/{provider}"
    api_keys: "api-keys/{tenant_id}/{service}"
    llm_keys: "llm/{provider}"  # LiteLLM API keys
```

### 6.2 Credential Rotation

```python
class SecretManager(Protocol):
    """Secret management interface."""

    async def get_secret(
        self,
        name: str,
        version: str = "latest"
    ) -> str:
        """Retrieve secret value."""

    async def create_secret(
        self,
        name: str,
        value: str,
        labels: Optional[dict] = None
    ) -> SecretVersion:
        """Create new secret."""

    async def rotate_secret(
        self,
        name: str,
        new_value: str
    ) -> SecretVersion:
        """Rotate secret to new value."""
```

---

## 7. MCP Server Infrastructure

### 7.1 MCP Server Pattern

All cloud MCP servers follow this structure:

```python
from mcp import FastMCP

class CloudMCPServer:
    """Base class for cloud provider MCP servers."""

    def __init__(self, config: CloudConfig):
        self.mcp = FastMCP(f"{config.provider}-mcp-server")
        self.cost_provider = self._create_cost_provider(config)

    @mcp.tool()
    async def get_costs(
        self,
        start_date: str,
        end_date: str,
        granularity: str = "DAILY",
        group_by: Optional[List[str]] = None
    ) -> CostResult:
        """Get cost data from cloud provider."""
        return await self.cost_provider.get_costs(
            start_date=parse_date(start_date),
            end_date=parse_date(end_date),
            granularity=granularity,
            group_by=group_by
        )

    @mcp.tool()
    async def get_recommendations(
        self,
        category: Optional[str] = None
    ) -> List[Recommendation]:
        """Get optimization recommendations."""
        return await self.cost_provider.get_recommendations(category)
```

### 7.2 MCP Tool Contracts

See `00_REF/domain/02-mcp-tool-contracts.md` for full tool specifications.

---

## 8. Public Interface

```python
class InfrastructureModule:
    """Foundation Module F6: Infrastructure"""

    # Cloud Providers
    def get_cost_provider(self, provider: str) -> CloudCostProvider:
        """Get cost provider for cloud (gcp, aws, azure)."""

    # Secrets
    def get_secret_manager(self) -> SecretManager:
        """Get secret management interface."""

    # Database
    def get_firestore_client(self) -> FirestoreClient:
        """Get Firestore client for metadata."""

    def get_bigquery_client(self) -> BigQueryClient:
        """Get BigQuery client for analytics."""

    # Compute
    def get_compute_config(self, service: str) -> ComputeConfig:
        """Get compute configuration for service."""
```

---

## 9. Dependencies

| Module | Dependency Type | Description |
|--------|----------------|-------------|
| **F7 Config** | Upstream | Cloud provider settings |
| **F1 IAM** | Upstream | Tenant context for isolation |
| **F3 Observability** | Downstream | Infrastructure metrics |
| **MCP Servers** | Downstream | Cloud API abstractions |

---

## 10. MVP Scope

### Included in MVP

- [x] GCP BigQuery billing integration
- [x] GCP Recommender API integration
- [x] Firestore for metadata
- [x] Secret Manager for credentials
- [x] Cloud Run compute patterns
- [x] GCP MCP server implementation

### Phase 2

- [ ] AWS Cost Explorer integration
- [ ] AWS Compute Optimizer integration
- [ ] Azure Cost Management integration
- [ ] OpenCost (Kubernetes) integration

---

*Adapted from Trading Nexus F6 v1.2.0 — February 2026*
