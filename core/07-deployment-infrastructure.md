# AI Cost Monitoring — Deployment & Infrastructure Architecture

## Document Info

| Field | Value |
|-------|-------|
| **Document** | 07 — Deployment & Infrastructure Architecture |
| **Version** | 1.0 |
| **Date** | February 2026 |
| **Status** | Architecture |
| **Audience** | Architects, DevOps Engineers, SRE |

---

## 1. Infrastructure Overview

### 1.1 Target Environment

| Aspect | Choice | Rationale |
|--------|--------|-----------|
| Primary Cloud | AWS (or GCP) | Most mature K8s managed service, broadest service catalog |
| Container Orchestration | Kubernetes (EKS or GKE) | Multi-service deployment, auto-scaling, health management |
| Infrastructure as Code | Terraform | Multi-cloud capability, state management, module ecosystem |
| CI/CD | GitHub Actions | Integrated with repo, good K8s ecosystem |
| Container Registry | ECR (or Artifact Registry) | Close to K8s cluster, integrated auth |

### 1.2 Environment Strategy

| Environment | Purpose | Infra Scale | Data |
|-------------|---------|-------------|------|
| **dev** | Developer testing, feature branches | Minimal (single replica) | Synthetic / sample data |
| **staging** | Pre-production validation, integration tests | Production-like (scaled down) | Anonymized production snapshot |
| **production** | Live customer traffic | Full scale, HA | Real tenant data |

---

## 2. Kubernetes Architecture

### 2.1 Namespace Strategy

```
finops-system/           ← Platform infrastructure
  ├── api-gateway (Kong/Envoy)
  ├── cert-manager
  └── monitoring (Prometheus, Grafana, Loki)

finops-frontend/         ← User-facing
  └── next-app (Next.js + CopilotKit)

finops-agents/           ← Agent layer
  ├── ag-ui-server (FastAPI)
  ├── coordinator-agent
  ├── cost-agent
  ├── optimization-agent
  ├── remediation-agent
  ├── reporting-agent
  ├── tenant-agent
  └── cross-cloud-agent

finops-mcp/              ← MCP servers
  ├── aws-mcp
  ├── azure-mcp
  ├── gcp-mcp
  ├── opencost-mcp
  ├── forecast-mcp
  ├── remediation-mcp
  ├── policy-mcp
  └── tenant-mcp

finops-workers/          ← Background processing
  ├── celery-beat (scheduler)
  ├── celery-workers (data sync, anomaly detection, etc.)
  └── event-processor (webhook consumer)

finops-data/             ← Data layer
  ├── postgresql-timescaledb (StatefulSet or managed)
  ├── redis (StatefulSet or managed)
  └── openbao (StatefulSet with HA)

finops-a2a/              ← External agent gateway
  └── a2a-gateway
```

### 2.2 Scaling Strategy

| Component | Scaling Type | Min Replicas | Max Replicas | Scale Trigger |
|-----------|-------------|-------------|-------------|---------------|
| Next.js frontend | HPA | 2 | 10 | CPU > 70% |
| AG-UI Server | HPA | 3 | 20 | Active SSE connections |
| Coordinator Agent | HPA | 2 | 10 | Request queue depth |
| Domain Agents | HPA | 2 | 8 each | Request queue depth |
| Cloud MCP servers | HPA | 2 | 6 each | Request rate |
| Celery workers | HPA | 3 | 20 | Queue length |
| Event processor | HPA | 2 | 10 | Event queue depth |
| A2A Gateway | HPA | 2 | 6 | Request rate |
| PostgreSQL/TimescaleDB | Vertical (managed) | 1 primary + 1 replica | — | Storage/connections |
| Redis | Vertical (managed) | 1 primary + 1 replica | — | Memory/connections |
| OpenBao | Fixed HA | 3 (Raft consensus) | 3 | — |

### 2.3 Resource Estimates (Production Starting Point)

| Component | CPU Request | Memory Request | Notes |
|-----------|------------|----------------|-------|
| AG-UI Server | 500m | 512Mi | Per replica |
| Each Agent | 250m | 256Mi | Per replica (LLM calls are I/O bound) |
| Each MCP Server | 250m | 256Mi | Per replica |
| Celery worker | 500m | 512Mi | Data processing |
| PostgreSQL | 4 CPU | 16Gi | Managed service recommended |
| TimescaleDB | 4 CPU | 16Gi | Same instance as PostgreSQL |
| Redis | 2 CPU | 8Gi | Managed service recommended |
| OpenBao | 500m | 512Mi | Per node (3 nodes) |

---

## 3. Terraform Module Structure

```
terraform/
  ├── environments/
  │     ├── dev/
  │     │     ├── main.tf
  │     │     ├── variables.tf
  │     │     └── terraform.tfvars
  │     ├── staging/
  │     └── production/
  │
  ├── modules/
  │     ├── networking/          ← VPC, subnets, security groups
  │     ├── kubernetes/          ← EKS/GKE cluster, node groups
  │     ├── database/            ← RDS PostgreSQL + TimescaleDB
  │     ├── cache/               ← ElastiCache Redis
  │     ├── secrets/             ← OpenBao deployment
  │     ├── auth/                ← Auth0 tenant configuration
  │     ├── monitoring/          ← Prometheus, Grafana, alerts
  │     ├── storage/             ← S3/GCS buckets for reports
  │     ├── dns/                 ← Route53/Cloud DNS
  │     └── certificates/        ← ACM/cert-manager
  │
  └── shared/
        ├── providers.tf
        └── backend.tf          ← Remote state in S3/GCS
```

### 3.1 Module Dependency Order

```
1. networking (VPC, subnets)
  → 2. kubernetes (cluster, node groups)
    → 3. database + cache + secrets (data layer)
      → 4. monitoring (needs K8s cluster)
        → 5. storage + dns + certificates (supporting services)
```

---

## 4. CI/CD Pipeline

### 4.1 Pipeline Stages

```
Developer pushes to feature branch
  → Lint & Type Check (Python: ruff, mypy / JS: eslint, tsc)
    → Unit Tests (pytest / jest)
      → Build Docker Images (multi-stage builds)
        → Integration Tests (against test containers)
          → Security Scan (container image + dependency audit)
            → Push to Container Registry (tagged with commit SHA)

Merge to main
  → All above +
    → Deploy to staging (automatic)
      → E2E Tests against staging
        → Manual approval gate
          → Deploy to production (blue-green or rolling)
            → Smoke tests
              → Monitor for 15 minutes
                → Promote or rollback
```

### 4.2 Deployment Strategy

| Strategy | Used For | Rollback Time |
|----------|----------|---------------|
| **Rolling update** | Stateless services (agents, MCP, API) | < 2 minutes |
| **Blue-green** | Frontend (Next.js) | Instant (DNS switch) |
| **Canary** | Agent prompt changes, model updates | < 5 minutes |
| **Manual** | Database migrations, OpenBao upgrades | Planned maintenance window |

### 4.3 Docker Image Strategy

Each component has its own Dockerfile with multi-stage builds:

```
Base images:
  ├── python:3.12-slim     ← Agents, MCP servers, Celery workers
  ├── node:20-alpine       ← Next.js frontend
  └── vault:latest         ← OpenBao (official image)

Shared layers:
  ├── finops-agent-base    ← Common Python deps for all agents
  ├── finops-mcp-base      ← Common Python deps for all MCP servers
  └── finops-worker-base   ← Common Python deps for Celery workers
```

---

## 5. Network Architecture

### 5.1 Network Zones

```
┌─────────────────────────────────────────────────────────────┐
│  PUBLIC ZONE (Internet-Facing)                               │
│  ├── CloudFlare (WAF + DDoS protection)                      │
│  └── API Gateway (Kong/Envoy) — SSL termination              │
├─────────────────────────────────────────────────────────────┤
│  DMZ (API Layer)                                             │
│  ├── Next.js frontend                                        │
│  ├── AG-UI Server                                            │
│  └── A2A Gateway                                             │
├─────────────────────────────────────────────────────────────┤
│  APPLICATION ZONE (Internal Only)                            │
│  ├── All Agent services                                      │
│  ├── All MCP servers                                         │
│  ├── Celery workers                                          │
│  └── Event processor                                         │
├─────────────────────────────────────────────────────────────┤
│  DATA ZONE (Most Restricted)                                 │
│  ├── PostgreSQL / TimescaleDB                                │
│  ├── Redis                                                   │
│  ├── OpenBao                                                 │
│  └── Object Storage (S3/GCS)                                 │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Network Rules

| Source → Destination | Allowed | Protocol |
|---------------------|---------|----------|
| Internet → Public Zone | Yes | HTTPS (443) |
| Public Zone → DMZ | Yes | HTTP (internal) |
| DMZ → Application Zone | Yes | gRPC / HTTP |
| Application Zone → Data Zone | Yes | PostgreSQL (5432), Redis (6379), OpenBao (8200) |
| Data Zone → Internet | No | Blocked (except cloud API egress) |
| Application Zone → Cloud APIs | Yes | HTTPS (443, egress only) |
| Cross-namespace within same zone | Yes | K8s NetworkPolicy |
| Cross-zone without explicit rule | No | Blocked by default |

---

## 6. Secrets Injection

### 6.1 OpenBao ↔ Kubernetes Integration

```
OpenBao Agent Injector (sidecar pattern)
  → Agents/MCP pods request secrets at startup
    → OpenBao Agent authenticates with K8s service account
      → OpenBao returns secrets as volume-mounted files
        → Application reads from file (not environment variable)
          → Secrets auto-refreshed on rotation
```

### 6.2 What Goes Where

| Secret Type | Storage | Injection Method |
|-------------|---------|-----------------|
| Tenant cloud credentials | OpenBao | Runtime API call per request |
| Database connection strings | OpenBao | Pod startup injection (sidecar) |
| Redis password | OpenBao | Pod startup injection |
| Auth0 client secrets | OpenBao | Pod startup injection |
| API Gateway TLS certificates | cert-manager | K8s Secret (auto-renewed) |
| LLM API keys (Gemini/Claude) | OpenBao | Pod startup injection |

---

## 7. Monitoring & Observability

### 7.1 Three Pillars

| Pillar | Tool | What It Covers |
|--------|------|----------------|
| **Metrics** | Prometheus + Grafana | System metrics, agent performance, cache hit rates, cloud API latencies |
| **Logs** | Loki (or ELK) | Structured JSON logs from all services, correlated by request_id |
| **Traces** | OpenTelemetry + Jaeger | End-to-end request tracing through all 4 agent layers |

### 7.2 Key Dashboards

| Dashboard | Audience | Key Metrics |
|-----------|----------|-------------|
| System Health | SRE | Service uptime, error rates, resource utilization |
| Agent Performance | Developers | Response times (p50/p95/p99), routing accuracy, tool call counts |
| MCP Performance | Developers | Cloud API latencies, cache hit ratios, circuit breaker states |
| Tenant Usage | Product | Active tenants, queries per day, feature adoption |
| Security | Security | Auth failures, cross-tenant attempts, rate limit hits |
| Business | Leadership | Total tenants, MRR, savings delivered |

### 7.3 Alert Rules (PagerDuty/Slack)

| Alert | Severity | Threshold |
|-------|----------|-----------|
| Service down (any component) | Critical | Health check fails for 2 minutes |
| Error rate spike | High | >5% error rate for 5 minutes |
| Agent response time | High | p95 > 10 seconds for 10 minutes |
| Database connection pool exhausted | Critical | Available connections < 5 |
| OpenBao sealed | Critical | Immediate |
| Cloud API circuit breaker open | Medium | Any provider circuit open |
| Disk usage >80% | Medium | Any persistent volume |
| Certificate expiring | Low | Within 14 days |

---

## 8. Disaster Recovery

| Aspect | Strategy | Target |
|--------|----------|--------|
| **RPO** (Recovery Point Objective) | 1 hour | Maximum data loss |
| **RTO** (Recovery Time Objective) | 4 hours | Maximum downtime |
| Database backup | Continuous WAL archiving to S3 + daily snapshots | Point-in-time recovery |
| Redis backup | AOF persistence + hourly RDB snapshots | 1-hour data loss acceptable |
| OpenBao backup | Auto-unseal keys in separate region + Raft snapshots | |
| Object storage | Cross-region replication | |
| Configuration | All in Git (Terraform + Helm + config) | Rebuild from scratch |
| Multi-region (future) | Active-passive failover | <30 min failover |

---

## Developer Notes

> **DEV-INF-001:** Use managed database services (RDS, ElastiCache, Cloud SQL) for production. Self-hosted databases in K8s are not worth the operational overhead for this team size.

> **DEV-INF-002:** Every service must have a `/health` endpoint that returns 200 when healthy. K8s liveness and readiness probes should hit this endpoint. Readiness should also check database connectivity.

> **DEV-INF-003:** Terraform state must be stored remotely (S3 + DynamoDB locking) from day one. Never commit state files to Git.

> **DEV-INF-004:** Docker images should use pinned base image versions with digest hashes, not `:latest`. Run Trivy or Snyk scanning on every build.

> **DEV-INF-005:** The OpenBao cluster is the most operationally critical component. If OpenBao is unavailable, no agent can retrieve cloud credentials. Plan for HA from day one (3-node Raft), and test unseal procedures monthly.

> **DEV-INF-006:** Namespace-level resource quotas should be set for each K8s namespace to prevent any single component from starving others. Set both requests and limits.
