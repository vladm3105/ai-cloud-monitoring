---
title: "REQ-06: F6 Infrastructure Platform Atomic Requirements"
tags:
  - req
  - layer-7-artifact
  - f6-infrastructure
  - foundation-module
  - shared-architecture
custom_fields:
  document_type: req
  artifact_type: REQ
  layer: 7
  module_id: F6
  module_name: Infrastructure Platform
  spec_ready_score: 92
  ctr_ready_score: 91
  schema_version: "1.1"
---

# REQ-06: F6 Infrastructure Platform Atomic Requirements

**MVP Scope**: This requirement document focuses on essential, SPEC-ready requirements for MVP delivery.

## 1. Document Control

| Item | Details |
|------|---------|
| **Status** | Draft |
| **Version** | 1.0.0 |
| **Date Created** | 2026-02-09T00:00:00 |
| **Last Updated** | 2026-02-09T00:00:00 |
| **Author** | Platform Infrastructure Team |
| **Priority** | P1 (Critical) |
| **Category** | Infra |
| **Infrastructure Type** | Compute / Database / Network |
| **Source Document** | SYS-06 Sections 4.1-4.4 |
| **Verification Method** | Integration Test |
| **Assigned Team** | Infrastructure Team |
| **SPEC-Ready Score** | ✅ 92% (Target: ≥90%) |
| **CTR-Ready Score** | ✅ 91% (Target: ≥90%) |
| **Template Version** | 1.1 |

---

## 2. Requirement Description

### 2.1 Statement

**The system SHALL** provide Cloud Run serverless compute, Cloud SQL PostgreSQL with pgvector, LiteLLM-based AI gateway, and Terraform IaC for all infrastructure provisioning on GCP.

### 2.2 Context

F6 Infrastructure Platform provides the foundational compute, database, and networking infrastructure for all platform services. It manages Cloud Run deployments, PostgreSQL connections, Redis caching, and routes LLM requests through LiteLLM to Vertex AI with fallback providers. MVP targets ~$500/month infrastructure cost.

### 2.3 Use Case

**Primary Flow**:
1. Application deploys to Cloud Run via Terraform
2. Service connects to Cloud SQL via connection pooling
3. LLM requests routed through LiteLLM gateway
4. Health endpoints monitored for auto-scaling

**Error Flow**:
- When primary LLM fails, system SHALL fallback to secondary provider
- When database unavailable, system SHALL retry with exponential backoff

---

## 3. Functional Specification

### 3.1 Core Functionality

**Required Capabilities**:
- **REQ.06.01.01 Compute Orchestrator**: Provision and scale Cloud Run services (0-10 instances)
- **REQ.06.01.02 Database Manager**: Manage PostgreSQL connections with pooling
- **REQ.06.01.03 AI Gateway**: Route LLM requests via LiteLLM with fallback
- **REQ.06.01.04 Infrastructure Provisioner**: Apply Terraform configurations

### 3.2 Business Rules

**ID Format**: `REQ.06.21.SS` (Validation Rule)

| Rule ID | Condition | Action |
|---------|-----------|--------|
| REQ.06.21.01 | IF CPU > 70% | THEN scale up instances |
| REQ.06.21.02 | IF primary LLM fails | THEN route to fallback |
| REQ.06.21.03 | IF db connections > 80 | THEN queue requests |
| REQ.06.21.04 | IF deployment fails | THEN rollback automatically |

### 3.3 Input/Output Specification

**Inputs**:

| Parameter | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| container_image | string | Yes | GCR URL | Docker image |
| terraform_config | object | Yes | Valid HCL | Infrastructure config |
| llm_request | object | Yes | LLM schema | AI prompt request |

**Outputs**:

| Field | Type | Description |
|-------|------|-------------|
| service_url | string | Cloud Run service URL |
| db_connection | object | Database connection handle |
| llm_response | object | AI model response |

### 3.4 Interface Protocol

```python
from typing import Protocol, Dict, Any, Optional

class InfrastructureService(Protocol):
    """Interface for F6 infrastructure operations."""

    async def deploy_service(
        self,
        image: str,
        name: str,
        config: Dict[str, Any]
    ) -> DeploymentResult:
        """
        Deploy container to Cloud Run.

        Args:
            image: Container image URL
            name: Service name
            config: Deployment configuration

        Returns:
            DeploymentResult with service URL

        Raises:
            DeploymentError: If deployment fails
        """
        raise NotImplementedError("method not implemented")

    async def get_db_connection(
        self,
        database: str
    ) -> DBConnection:
        """Get pooled database connection."""
        raise NotImplementedError("method not implemented")

    async def call_llm(
        self,
        prompt: str,
        model: str = "gemini-1.5-pro",
        max_tokens: int = 4096
    ) -> LLMResponse:
        """Route LLM request through gateway."""
        raise NotImplementedError("method not implemented")
```

---

## 4. Interface Definition

### 4.1 API Contract

**Endpoint**: `POST /api/v1/infrastructure/deploy`

**Request**:
```json
{
  "service_name": "cost-api",
  "image": "gcr.io/project/cost-api:v1.0",
  "replicas": {
    "min": 0,
    "max": 10
  },
  "resources": {
    "cpu": "2",
    "memory": "2Gi"
  }
}
```

**Response (Success)**:
```json
{
  "service_url": "https://cost-api-abc123-uc.a.run.app",
  "revision": "cost-api-00001-abc",
  "status": "READY",
  "deployed_at": "2026-02-09T10:30:00Z"
}
```

### 4.2 Data Schema

```python
from pydantic import BaseModel, Field
from datetime import datetime
from typing import Dict, Any

class DeploymentConfig(BaseModel):
    """Deployment configuration."""
    service_name: str
    image: str
    replicas_min: int = 0
    replicas_max: int = 10
    cpu: str = "2"
    memory: str = "2Gi"
    env_vars: Dict[str, str] = {}

class LLMRequest(BaseModel):
    """LLM request structure."""
    prompt: str
    model: str = "gemini-1.5-pro"
    max_tokens: int = Field(default=4096, le=32768)
    temperature: float = Field(default=0.7, ge=0, le=2)
```

---

## 5. Error Handling

### 5.1 Error Catalog

| Error Code | HTTP Status | Condition | User Message | System Action |
|------------|-------------|-----------|--------------|---------------|
| INFRA_001 | 503 | Cloud Run unavailable | Service unavailable | Retry deployment |
| INFRA_002 | 503 | Database unavailable | Database unavailable | Retry with backoff |
| INFRA_003 | 503 | LLM provider error | AI service unavailable | Fallback provider |
| INFRA_004 | 500 | Terraform error | Infrastructure error | Rollback |

### 5.2 Recovery Strategy

| Error Type | Retry? | Fallback | Alert |
|------------|--------|----------|-------|
| Deployment failure | Yes (1x) | Rollback | Immediate |
| Database timeout | Yes (3x) | None | After 3 failures |
| LLM failure | Yes (1x) | Secondary provider | Log only |

### 5.3 Exception Definitions

```python
class InfrastructureError(Exception):
    """Base exception for F6 infrastructure errors."""
    pass

class DeploymentError(InfrastructureError):
    """Raised when deployment fails."""
    pass

class DatabaseConnectionError(InfrastructureError):
    """Raised when database connection fails."""
    pass

class LLMGatewayError(InfrastructureError):
    """Raised when LLM gateway fails."""
    def __init__(self, model: str, fallback_used: bool):
        self.model = model
        self.fallback_used = fallback_used
```

---

## 6. Quality Attributes

**ID Format**: `REQ.06.02.SS` (Quality Attribute)

### 6.1 Performance (REQ.06.02.01)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Deployment latency (p95) | < @threshold: PRD.06.perf.deploy.p95 (60s) | Timer |
| DB connection (p95) | < @threshold: PRD.06.perf.db.p95 (100ms) | APM |
| LLM response (p99) | < @threshold: PRD.06.perf.llm.p99 (5s) | Timer |
| Blue-green switch | < 30s | Timer |

### 6.2 Security (REQ.06.02.02)

- [x] Secrets in Secret Manager
- [x] TLS 1.3 for all connections
- [x] VPC private networking

### 6.3 Reliability (REQ.06.02.03)

- Service uptime: @threshold: PRD.06.sla.uptime (99.9%)
- Database HA: Automatic Cloud SQL failover
- AI Gateway: Multi-provider fallback

---

## 7. Configuration

### 7.1 Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| CLOUD_RUN_MAX_INSTANCES | int | 10 | Max auto-scale instances |
| DB_POOL_SIZE | int | 10 | Connection pool size |
| LLM_TIMEOUT | duration | 30s | LLM request timeout |
| TERRAFORM_APPLY_TIMEOUT | duration | 10m | IaC timeout |

### 7.2 Feature Flags

| Flag | Default | Description |
|------|---------|-------------|
| F6_LLM_FALLBACK | true | Enable LLM fallback |
| F6_AUTO_ROLLBACK | true | Auto-rollback on failure |

### 7.3 Configuration Schema

```yaml
f6_config:
  compute:
    max_instances: 10
    cpu: "2"
    memory: "2Gi"
  database:
    instance: "db-custom-2-8192"
    pool_size: 10
    max_connections: 100
  llm:
    primary: "vertex_ai/gemini-1.5-pro"
    fallback: "anthropic/claude-3-haiku"
    timeout_seconds: 30
  terraform:
    backend: "gcs"
    apply_timeout: "10m"
```

---

## 8. Testing Requirements

### 8.1 Unit Tests

| Test Case | Input | Expected Output | Coverage |
|-----------|-------|-----------------|----------|
| **[Logic] Deployment** | Valid config | Service URL | REQ.06.01.01 |
| **[Logic] DB Connection** | Database name | Connection handle | REQ.06.01.02 |
| **[Logic] LLM Routing** | Prompt | Response | REQ.06.01.03 |
| **[State] Auto-scale** | High CPU | Instance scaled | REQ.06.21.01 |
| **[Edge] LLM Fallback** | Primary fails | Fallback used | REQ.06.21.02 |

### 8.2 Integration Tests

- [ ] Cloud Run deployment and scaling
- [ ] PostgreSQL connection pooling
- [ ] LiteLLM multi-provider routing
- [ ] Terraform apply and destroy

### 8.3 BDD Scenarios

**Feature**: Infrastructure Platform
**File**: `04_BDD/BDD-06_f6_infrastructure/BDD-06.01_infra.feature`

| Scenario | Priority | Status |
|----------|----------|--------|
| Service deploys to Cloud Run | P1 | Pending |
| Database connection pooled | P1 | Pending |
| LLM fallback on provider failure | P1 | Pending |
| Auto-rollback on deployment failure | P1 | Pending |

---

## 9. Acceptance Criteria

**ID Format**: `REQ.06.06.SS` (Acceptance Criteria)

### 9.1 Functional Acceptance

| Criteria ID | Criterion | Measurable Outcome | Status |
|-------------|-----------|-------------------|--------|
| REQ.06.06.01 | Cloud Run deployment | Service URL returned | [ ] |
| REQ.06.06.02 | DB connections work | Queries execute | [ ] |
| REQ.06.06.03 | LLM gateway routes | Response returned | [ ] |
| REQ.06.06.04 | Terraform applies | Resources created | [ ] |
| REQ.06.06.05 | Auto-scaling works | Instances scale | [ ] |

### 9.2 Quality Acceptance

| Criteria ID | Criterion | Target | Status |
|-------------|-----------|--------|--------|
| REQ.06.06.06 | Deployment latency | @threshold: REQ.06.02.01 (p95 < 60s) | [ ] |
| REQ.06.06.07 | Availability | 99.9% uptime | [ ] |
| REQ.06.06.08 | Cost | ~$500/month | [ ] |

---

## 10. Traceability

### 10.1 Upstream Sources

| Source Type | Document ID | Element Reference | Relationship |
|-------------|-------------|-------------------|--------------|
| BRD | BRD-06 | BRD.06.07.02 | Primary business need |
| PRD | PRD-06 | PRD.06.08.01 | Product requirement |
| EARS | EARS-06 | EARS.06.01.01-04 | Formal requirements |
| BDD | BDD-06 | BDD.06.01.01 | Acceptance test |
| ADR | ADR-06 | — | Architecture decision |
| SYS | SYS-06 | SYS.06.01.01-04 | System requirement |

### 10.2 Downstream Artifacts

| Artifact | Status | Relationship |
|----------|--------|--------------|
| SPEC-06 | TBD | Technical specification |
| TASKS-06 | TBD | Implementation tasks |

### 10.3 Traceability Tags

```markdown
@brd: BRD-06
@prd: PRD-06
@ears: EARS-06
@bdd: BDD-06
@adr: ADR-06
@sys: SYS-06
```

### 10.4 Cross-Links

```markdown
@depends: None (foundation layer)
@discoverability: REQ-08 (D1 uses LLM gateway); REQ-01 (F1 uses DB)
```

---

## 11. Implementation Notes

### 11.1 Technical Approach

Use Terraform with GCS backend for state management. Implement LiteLLM as proxy for multi-provider LLM routing. Use Cloud SQL Auth Proxy for secure database connections.

### 11.2 Code Location

- **Primary**: `src/foundation/f6_infrastructure/`
- **Infrastructure**: `terraform/`
- **Tests**: `tests/foundation/test_f6_infrastructure/`

### 11.3 Dependencies

| Package/Service | Version | Purpose |
|-----------------|---------|---------|
| terraform | 1.7+ | Infrastructure as Code |
| litellm | 1.30+ | LLM gateway |
| asyncpg | 0.29+ | PostgreSQL driver |
| google-cloud-run | 0.10+ | Cloud Run SDK |

---

**Document Version**: 1.0.0
**Template Version**: 1.1 (MVP)
**Last Updated**: 2026-02-09T00:00:00
