# Multi-Cloud Infrastructure Architecture

**Document:** MULTI_CLOUD_INFRASTRUCTURE.md
**Version:** 1.2.0
**Date:** 2026-02-07
**Status:** Reference (Future Phase)
**Phase:** Multi-Tenant Production
**Related:** [MULTI_CLOUD_COST_REALITY_CHECK.md](MULTI_CLOUD_COST_REALITY_CHECK.md)

---

**⚠️ IMPORTANT: This document describes the FUTURE multi-tenant architecture.**

For the current MVP (single-tenant) implementation, see:

- **[MVP_ARCHITECTURE.md](architecture/MVP_ARCHITECTURE.md)** - Simplified stack using Firestore + BigQuery
- **[ADR-008: Database Strategy](adr/008-database-strategy-mvp.md)** - Why we defer PostgreSQL to multi-tenant phase

| Phase                       | Stack                                                  | Monthly Cost |
|-----------------------------|--------------------------------------------------------|--------------|
| **MVP (Current)**           | GCP Cloud Run + Firestore + BigQuery + Secret Manager  | ~$0-10       |
| **Multi-Tenant (This Doc)** | GCP + Azure + Neon.tech + Neo4j                        | ~$100-150    |

---

> **Note:** This document focuses on architectural design and structural decisions for the multi-tenant production phase.
> Detailed implementation specifications (environment variables, API schemas, etc.)
> will be developed in subsequent implementation phases.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Architecture Overview](#2-architecture-overview)
3. [Provider Selection Rationale](#3-provider-selection-rationale)
4. [Service Architecture](#4-service-architecture)
5. [Network Architecture](#5-network-architecture)
6. [Cost Monitoring Infrastructure](#6-cost-monitoring-infrastructure)
7. [Service Control Automation](#7-service-control-automation)
8. [Deployment Environments](#8-deployment-environments)
9. [Infrastructure as Code Structure](#9-infrastructure-as-code-structure)
10. [Monitoring and Observability](#10-monitoring-and-observability)
11. [Disaster Recovery](#11-disaster-recovery)
12. [Security Architecture](#12-security-architecture)
13. [Operational Runbooks](#13-operational-runbooks)
14. [Migration Plan](#14-migration-plan)
15. [SLA and Capacity Planning](#15-sla-and-capacity-planning)

---

## 1. Executive Summary

### 1.1 Architecture Philosophy

This multi-cloud architecture prioritizes:
- **Cost efficiency** through strategic use of free tiers and best-priced services
- **Operational simplicity** via managed services requiring minimal DevOps expertise
- **Reliability** through provider diversification and automated failover
- **Budget safety** via automated cost monitoring and service control

### 1.2 Budget Targets

| Environment | Infrastructure | LLM API | Total | Hard Limit |
|-------------|----------------|---------|-------|------------|
| Development | $15-25/mo | $10-20/mo | $25-45/mo | $50/mo |
| Production (20-30 customers) | $70-100/mo | $30-50/mo | $100-150/mo | $150/mo |

**Budget Components:**

- **Infrastructure**: Cloud providers, databases, CDN, monitoring
- **LLM API**: OpenAI/Claude API calls for knowledge processing
- LLM costs are usage-variable; infrastructure costs are more predictable

### 1.3 Provider Distribution

| Provider | Role | Services |
|----------|------|----------|
| **GCP** | Primary Compute | Cloud Run, Secret Manager, Cloud Logging |
| **Azure** | Static Hosting | Static Web Apps |
| **Cloudflare** | Edge/CDN | DNS, CDN, WAF, DDoS Protection |
| **Neon.tech** | Vector Database | PostgreSQL with pgvector |
| **Neo4j** | Graph Database | AuraDB |

---

## 2. Architecture Overview

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              END USERS (US-BASED)                           │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CLOUDFLARE (FREE TIER)                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │     DNS     │  │     CDN     │  │     WAF     │  │    DDoS     │        │
│  │  (Global)   │  │  (Caching)  │  │  (Security) │  │ (Protection)│        │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘        │
└─────────┼────────────────┼────────────────┼────────────────┼────────────────┘
          │                │                │                │
          └────────────────┴────────┬───────┴────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
┌───────────────────────────────────┐   ┌───────────────────────────────────┐
│     AZURE (FREE TIER)             │   │        GCP (us-central1)          │
│  ┌─────────────────────────────┐  │   │                                   │
│  │   STATIC WEB APPS           │  │   │  ┌─────────────────────────────┐  │
│  │   ┌───────────────────┐     │  │   │  │      CLOUD RUN              │  │
│  │   │  Next.js Frontend │     │  │   │  │  ┌───────────────────────┐  │  │
│  │   │  - SSG/SSR        │     │──┼───┼──│  │  MCP Servers (4)      │  │  │
│  │   │  - Edge Functions │     │  │   │  │  │  - rac-knowledge-mcp  │  │  │
│  │   │  - 100GB BW Free  │     │  │   │  │  │  - rac-system-admin   │  │  │
│  │   └───────────────────┘     │  │   │  │  │  - rac-ops-storage    │  │  │
│  └─────────────────────────────┘  │   │  │  │  - rac-knowledge-api  │  │  │
└───────────────────────────────────┘   │  │  └───────────────────────┘  │  │
                                        │  │  ┌───────────────────────┐  │  │
                                        │  │  │  UI Server            │  │  │
                                        │  │  │  - rac-ui-server      │  │  │
                                        │  │  └───────────────────────┘  │  │
                                        │  │  ┌───────────────────────┐  │  │
                                        │  │  │  Background Services  │  │  │
                                        │  │  │  - log-analyzer       │  │  │
                                        │  │  └───────────────────────┘  │  │
                                        │  └─────────────────────────────┘  │
                                        │                                   │
                                        │  ┌─────────────────────────────┐  │
                                        │  │     SECRET MANAGER          │  │
                                        │  │  - API Keys                 │  │
                                        │  │  - Database Credentials     │  │
                                        │  │  - Service Tokens           │  │
                                        │  └─────────────────────────────┘  │
                                        │                                   │
                                        │  ┌─────────────────────────────┐  │
                                        │  │     CLOUD OPERATIONS        │  │
                                        │  │  - Logging (50GB free)      │  │
                                        │  │  - Monitoring               │  │
                                        │  │  - Alerting                 │  │
                                        │  └─────────────────────────────┘  │
                                        └───────────────────────────────────┘
                                                        │
                            ┌───────────────────────────┴───────────────────────────┐
                            ▼                                                       ▼
              ┌─────────────────────────────────┐           ┌─────────────────────────────────┐
              │        NEON.TECH                │           │        NEO4J AURA               │
              │  ┌───────────────────────────┐  │           │  ┌───────────────────────────┐  │
              │  │  PostgreSQL + pgvector    │  │           │  │  Graph Database           │  │
              │  │  - Vector embeddings      │  │           │  │  - Knowledge graph        │  │
              │  │  - Document storage       │  │           │  │  - Entity relationships   │  │
              │  │  - User data              │  │           │  │  - Semantic connections   │  │
              │  │  - Pro: $19/mo            │  │           │  │  - Free: 50K nodes        │  │
              │  │  - Scale-to-zero          │  │           │  │  - Pro: $65/mo            │  │
              │  └───────────────────────────┘  │           │  └───────────────────────────┘  │
              │  Region: US-East-1              │           │  Region: US-East-1              │
              └─────────────────────────────────┘           └─────────────────────────────────┘
```

### 2.2 Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           REQUEST FLOW                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. User Request                                                            │
│     └──▶ Cloudflare DNS (resolve rac.domain.com)                           │
│           └──▶ Cloudflare CDN (cache check)                                │
│                 ├──▶ [Cache HIT] Return cached response                    │
│                 └──▶ [Cache MISS] Route to origin                          │
│                                                                             │
│  2. Static Content                                                          │
│     └──▶ Azure Static Web Apps (Next.js)                                   │
│           └──▶ Return HTML/JS/CSS                                          │
│                                                                             │
│  3. API Request                                                             │
│     └──▶ Azure Edge Functions (API proxy)                                  │
│           └──▶ GCP Cloud Run (MCP Servers)                                 │
│                 ├──▶ GCP Secret Manager (credentials)                      │
│                 ├──▶ Neon.tech PostgreSQL (data/vectors)                   │
│                 └──▶ Neo4j AuraDB (graph queries)                          │
│                                                                             │
│  4. Response                                                                │
│     └──▶ Cloud Run ──▶ Azure ──▶ Cloudflare ──▶ User                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Provider Selection Rationale

### 3.1 Selection Criteria Matrix

| Criteria | Weight | GCP | AWS | Azure | Winner |
|----------|--------|-----|-----|-------|--------|
| Free tier generosity | 25% | 9 | 7 | 8 | GCP |
| Scale-to-zero support | 20% | 10 | 6 | 8 | GCP |
| Serverless containers | 20% | 10 | 8 | 9 | GCP |
| Cost at low volume | 20% | 9 | 7 | 8 | GCP |
| Ease of setup | 15% | 8 | 7 | 9 | Azure |

### 3.2 Service-by-Service Selection

| Service Category | Selected Provider | Alternative | Reason |
|------------------|-------------------|-------------|--------|
| Container Compute | GCP Cloud Run | AWS Fargate | Scale-to-zero, 2M free requests |
| Static Hosting | Azure Static Web Apps | Vercel | Free tier with Edge Functions |
| CDN/DNS | Cloudflare | GCP Cloud CDN | Unlimited free bandwidth |
| PostgreSQL | Neon.tech | Supabase | Native pgvector, serverless |
| Graph Database | Neo4j AuraDB | AWS Neptune | Free tier, native graph |
| Secrets | GCP Secret Manager | HashiCorp Vault | Managed, cheap |
| Logging | GCP Cloud Logging | Datadog | 50GB free |

### 3.3 Cost Comparison Summary

| Provider | Free Tier Value | Paid Starting At |
|----------|-----------------|------------------|
| GCP Cloud Run | ~$50/mo equivalent | $0.00002400/vCPU-sec |
| Azure Static Web Apps | ~$30/mo equivalent | $9/mo Standard |
| Cloudflare | Unlimited CDN | $20/mo Pro |
| Neon.tech | 0.5GB storage | $19/mo Pro |
| Neo4j AuraDB | 50K nodes | $65/mo Pro |

---

## 4. Service Architecture

### 4.1 Compute Services (GCP Cloud Run)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        GCP CLOUD RUN SERVICES                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    rac-knowledge-mcp                                 │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  │   │
│  │  │ Min: 0 (dev)│  │ Max: 5      │  │ Memory: 1Gi │                  │   │
│  │  │ Min: 1 (prd)│  │ Concurrency │  │ CPU: 1      │                  │   │
│  │  │             │  │ 80 req/inst │  │ Timeout: 5m │                  │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘                  │   │
│  │  Endpoints: /search, /get_document, /semantic_search                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    rac-system-admin-mcp                              │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  │   │
│  │  │ Min: 0      │  │ Max: 3      │  │ Memory: 512 │                  │   │
│  │  │             │  │ Concurrency │  │ CPU: 0.5    │                  │   │
│  │  │             │  │ 50 req/inst │  │ Timeout: 5m │                  │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘                  │   │
│  │  Endpoints: /users, /workspaces, /credentials                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    rac-ops-storage-mcp                               │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  │   │
│  │  │ Min: 0      │  │ Max: 5      │  │ Memory: 512 │                  │   │
│  │  │             │  │ Concurrency │  │ CPU: 1      │                  │   │
│  │  │             │  │ 80 req/inst │  │ Timeout: 5m │                  │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘                  │   │
│  │  Endpoints: /upload, /files, /github_sync                           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    rac-knowledge-api (LightRAG)                      │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  │   │
│  │  │ Min: 0 (dev)│  │ Max: 5      │  │ Memory: 2Gi │                  │   │
│  │  │ Min: 1 (prd)│  │ Concurrency │  │ CPU: 2      │                  │   │
│  │  │             │  │ 40 req/inst │  │ Timeout: 10m│                  │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘                  │   │
│  │  Endpoints: /query, /insert, /hybrid_search                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    rac-ui-server                                     │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  │   │
│  │  │ Min: 0      │  │ Max: 3      │  │ Memory: 512 │                  │   │
│  │  │             │  │ Concurrency │  │ CPU: 0.5    │                  │   │
│  │  │             │  │ 100 req/ins │  │ Timeout: 1m │                  │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘                  │   │
│  │  Endpoints: /api/*, SSR routes                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    log-analyzer (Background)                         │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  │   │
│  │  │ Min: 0      │  │ Max: 1      │  │ Memory: 256 │                  │   │
│  │  │             │  │ Concurrency │  │ CPU: 0.25   │                  │   │
│  │  │             │  │ 10 req/inst │  │ Timeout: 15m│                  │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘                  │   │
│  │  Trigger: Cloud Scheduler (every 15 minutes)                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Database Services

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          DATABASE ARCHITECTURE                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    NEON.TECH POSTGRESQL                              │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                       │   │
│  │  Project: rac-production                                              │   │
│  │  Region: US-East-1 (AWS)                                              │   │
│  │  Plan: Pro ($19/month)                                                │   │
│  │                                                                       │   │
│  │  ┌─────────────────────┐  ┌─────────────────────┐                    │   │
│  │  │   Main Branch       │  │   Dev Branch        │                    │   │
│  │  │   (Production)      │  │   (Development)     │                    │   │
│  │  │   - Read/Write      │  │   - Read/Write      │                    │   │
│  │  │   - Auto-scale      │  │   - Scale-to-zero   │                    │   │
│  │  └─────────────────────┘  └─────────────────────┘                    │   │
│  │                                                                       │   │
│  │  Extensions:                                                          │   │
│  │  - pgvector (vector similarity)                                       │   │
│  │  - pg_trgm (text search)                                              │   │
│  │  - uuid-ossp (UUID generation)                                        │   │
│  │                                                                       │   │
│  │  Connection Pooling:                                                  │   │
│  │  - Built-in pooler enabled                                            │   │
│  │  - Max connections: 100                                               │   │
│  │  - Pool mode: Transaction                                             │   │
│  │                                                                       │   │
│  │  Quotas (Cost Control):                                               │   │
│  │  - active_time_seconds: 1,080,000 (300 hours)                         │   │
│  │  - compute_time_seconds: 1,080,000                                    │   │
│  │  - written_data_bytes: 10GB                                           │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    NEO4J AURADB                                       │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                       │   │
│  │  Instance: rac-knowledge-graph                                        │   │
│  │  Region: US-East-1                                                    │   │
│  │  Tier: Free (upgrade to Pro when >40K nodes)                          │   │
│  │                                                                       │   │
│  │  Free Tier Limits:                                                    │   │
│  │  - Nodes: 50,000                                                      │   │
│  │  - Relationships: 175,000                                             │   │
│  │  - Memory: 256MB                                                      │   │
│  │  - Auto-pause: After 3 days idle                                      │   │
│  │                                                                       │   │
│  │  Pro Tier ($65/mo):                                                   │   │
│  │  - Nodes: Unlimited                                                   │   │
│  │  - Memory: 1GB+                                                       │   │
│  │  - No auto-pause                                                      │   │
│  │                                                                       │   │
│  │  Upgrade Triggers:                                                    │   │
│  │  - Node count > 40,000 (warning)                                      │   │
│  │  - Node count > 48,000 (critical)                                     │   │
│  │  - Relationship count > 140,000 (warning)                             │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.3 Cold Start Mitigation Strategy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    COLD START MITIGATION                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ISSUE: Services scale to zero for cost savings, but cold starts           │
│  impact user experience.                                                    │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Service          │ Cold Start Time │ Mitigation Strategy            │   │
│  ├───────────────────┼─────────────────┼────────────────────────────────┤   │
│  │  Cloud Run        │ 2-5 seconds     │ Min instances = 1 (production) │   │
│  │  Neon.tech        │ 0.5-2 seconds   │ Connection pooling, keep-alive │   │
│  │  Neo4j Free       │ 30-60 seconds   │ Keep-alive ping (see below)    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  NEO4J FREE TIER KEEP-ALIVE STRATEGY:                                       │
│  ─────────────────────────────────────                                      │
│  Problem: Free tier auto-pauses after 3 days of inactivity                 │
│  Solution: Scheduled ping to prevent pause                                  │
│                                                                             │
│  Implementation:                                                            │
│  - Cloud Scheduler triggers every 48 hours                                 │
│  - Lightweight Cypher query: RETURN 1                                      │
│  - Cost: ~$0 (within free tier limits)                                     │
│                                                                             │
│  PRODUCTION RECOMMENDATION:                                                 │
│  ─────────────────────────────                                              │
│  - Cloud Run: 1 minimum instance for critical services (~$47/mo)           │
│  - Neo4j: If >10 customers, upgrade to Pro ($65/mo) for no auto-pause      │
│  - Neon: Enable connection pooling (included in Pro)                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Network Architecture

### 5.1 DNS and Routing

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          DNS CONFIGURATION                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Domain: rac.example.com (managed by Cloudflare)                            │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  DNS Records                                                          │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                       │   │
│  │  @              CNAME    azure-static-web-apps.net     (proxied)     │   │
│  │  www            CNAME    azure-static-web-apps.net     (proxied)     │   │
│  │  api            CNAME    rac-api-xxxxx.run.app         (proxied)     │   │
│  │  mcp            CNAME    rac-mcp-xxxxx.run.app         (proxied)     │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Cloudflare Page Rules                                                │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                       │   │
│  │  /api/*         Cache: Bypass, Security: High                        │   │
│  │  /static/*      Cache: 1 month, Edge TTL: 1 week                     │   │
│  │  /_next/*       Cache: 1 week, Edge TTL: 1 day                       │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Cross-Cloud Connectivity

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CROSS-CLOUD NETWORK TOPOLOGY                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                          PUBLIC INTERNET                                    │
│                               │                                             │
│        ┌──────────────────────┼──────────────────────┐                     │
│        │                      │                      │                     │
│        ▼                      ▼                      ▼                     │
│  ┌───────────┐          ┌───────────┐          ┌───────────┐              │
│  │ Cloudflare│          │   Azure   │          │    GCP    │              │
│  │  (Edge)   │◀────────▶│  (West US)│◀────────▶│(us-central│              │
│  │           │   HTTPS  │           │   HTTPS  │    1)     │              │
│  └───────────┘          └───────────┘          └─────┬─────┘              │
│                                                       │                    │
│                              ┌────────────────────────┴───────┐            │
│                              │                                │            │
│                              ▼                                ▼            │
│                       ┌───────────┐                    ┌───────────┐       │
│                       │ Neon.tech │                    │  Neo4j    │       │
│                       │ (AWS East)│                    │(AWS East) │       │
│                       │           │                    │           │       │
│                       └───────────┘                    └───────────┘       │
│                                                                             │
│  Connection Security:                                                       │
│  - All connections via TLS 1.3                                             │
│  - Database connections via connection pooler                               │
│  - No VPC peering required (public endpoints + auth)                        │
│                                                                             │
│  Latency Estimates:                                                         │
│  - Cloudflare → Azure: <10ms                                               │
│  - Azure → GCP: 20-40ms                                                    │
│  - GCP → Neon.tech: 30-50ms                                                │
│  - GCP → Neo4j: 30-50ms                                                    │
│  - Total round-trip: 80-150ms                                              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.3 CORS Configuration

Cross-Origin Resource Sharing (CORS) is required for Azure Static Web Apps to communicate with GCP Cloud Run APIs.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CORS REQUIREMENTS                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Azure Static Web Apps (rac.example.com)                                    │
│         │                                                                   │
│         │  API Calls (fetch/axios)                                          │
│         ▼                                                                   │
│  GCP Cloud Run (api.rac.example.com)                                        │
│                                                                             │
│  Required CORS Headers on Cloud Run:                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Access-Control-Allow-Origin: https://rac.example.com               │   │
│  │  Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS      │   │
│  │  Access-Control-Allow-Headers: Content-Type, Authorization          │   │
│  │  Access-Control-Max-Age: 86400                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Implementation Options:                                                    │
│  - Option A: FastAPI middleware (application-level)                        │
│  - Option B: Cloudflare Transform Rules (edge-level, recommended)          │
│                                                                             │
│  Note: Cloudflare proxying simplifies CORS by making requests              │
│  appear same-origin when properly configured.                              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.4 Health Check Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    HEALTH CHECK ENDPOINTS                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Each Cloud Run service exposes a standardized health endpoint:             │
│                                                                             │
│  Endpoint: GET /health                                                      │
│  Response: { "status": "healthy", "service": "<name>", "version": "x.x" }  │
│  Timeout: 10 seconds                                                        │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Health Check Levels:                                                │   │
│  │                                                                       │   │
│  │  Level 1 - Liveness (required):                                      │   │
│  │  - Service is running and accepting requests                         │   │
│  │  - Used by Cloud Run for container health                            │   │
│  │                                                                       │   │
│  │  Level 2 - Readiness (recommended):                                  │   │
│  │  - Database connections are valid                                    │   │
│  │  - External dependencies are reachable                               │   │
│  │  - Used for traffic routing decisions                                │   │
│  │                                                                       │   │
│  │  Level 3 - Deep Health (optional):                                   │   │
│  │  - Full dependency check including Neo4j, Neon                       │   │
│  │  - Used for monitoring dashboards                                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  External Monitoring:                                                       │
│  - UptimeRobot: Checks Level 1 every 5 minutes                             │
│  - GCP Cloud Monitoring: Checks Level 2 every 1 minute                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Cost Monitoring Infrastructure

### 6.1 Monitoring Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    COST MONITORING SYSTEM ARCHITECTURE                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    COST COLLECTOR SERVICE                            │   │
│  │                    (GCP Cloud Run - Scheduled)                       │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                       │   │
│  │  Trigger: Cloud Scheduler (every 15 minutes)                         │   │
│  │  Runtime: Python 3.11                                                 │   │
│  │  Timeout: 5 minutes                                                   │   │
│  │  Memory: 256MB                                                        │   │
│  │                                                                       │   │
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐             │   │
│  │  │  GCP Client   │  │ Azure Client  │  │ Neon Client   │             │   │
│  │  │  - Billing API│  │ - Cost Mgmt  │  │ - Consumption │             │   │
│  │  │  - Usage API  │  │   REST API    │  │   API v2      │             │   │
│  │  └───────┬───────┘  └───────┬───────┘  └───────┬───────┘             │   │
│  │          │                  │                  │                      │   │
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐             │   │
│  │  │ Neo4j Client  │  │   CF Client   │  │ OpenAI Client │             │   │
│  │  │ - Metrics API │  │ - GraphQL API │  │ - Usage API   │             │   │
│  │  └───────┬───────┘  └───────┬───────┘  └───────┬───────┘             │   │
│  │          │                  │                  │                      │   │
│  │          └──────────┬───────┴──────────┬───────┘                      │   │
│  │                     ▼                                                 │   │
│  │          ┌───────────────────────────────────┐                       │   │
│  │          │        COST AGGREGATOR            │                       │   │
│  │          │  - Normalize to USD               │                       │   │
│  │          │  - Calculate daily/monthly totals │                       │   │
│  │          │  - Project month-end costs        │                       │   │
│  │          └───────────────┬───────────────────┘                       │   │
│  │                          │                                            │   │
│  └──────────────────────────┼────────────────────────────────────────────┘   │
│                             │                                               │
│                             ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    DATA STORAGE                                      │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                       │   │
│  │  Option A: Neon.tech PostgreSQL (cost_metrics table)                 │   │
│  │  Option B: GCP BigQuery (for long-term analytics)                    │   │
│  │  Option C: Cloud Firestore (simple key-value)                        │   │
│  │                                                                       │   │
│  │  Schema:                                                              │   │
│  │  ┌─────────────────────────────────────────────────────────────┐     │   │
│  │  │  cost_snapshots                                              │     │   │
│  │  │  - id: UUID                                                  │     │   │
│  │  │  - timestamp: TIMESTAMP                                      │     │   │
│  │  │  - provider: VARCHAR (gcp, azure, neon, neo4j, cloudflare)  │     │   │
│  │  │  - service: VARCHAR                                          │     │   │
│  │  │  - metric_name: VARCHAR                                      │     │   │
│  │  │  - metric_value: DECIMAL                                     │     │   │
│  │  │  - cost_usd: DECIMAL                                         │     │   │
│  │  │  - period: VARCHAR (hourly, daily, monthly)                  │     │   │
│  │  └─────────────────────────────────────────────────────────────┘     │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│                             │                                               │
│                             ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    THRESHOLD CHECKER                                 │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                       │   │
│  │  Thresholds Configuration:                                           │   │
│  │  ┌─────────────────────────────────────────────────────────────┐     │   │
│  │  │  thresholds:                                                 │     │   │
│  │  │    monthly_budget: 100.00                                    │     │   │
│  │  │    warning_percent: 0.50   # 50% = $50                       │     │   │
│  │  │    alert_percent: 0.80     # 80% = $80                       │     │   │
│  │  │    critical_percent: 0.95  # 95% = $95                       │     │   │
│  │  │    shutdown_percent: 1.00  # 100% = $100                     │     │   │
│  │  │                                                              │     │   │
│  │  │  per_service_limits:                                         │     │   │
│  │  │    gcp_cloud_run: 50.00                                      │     │   │
│  │  │    neon_postgres: 35.00                                      │     │   │
│  │  │    neo4j_aura: 0.00  # free tier only                        │     │   │
│  │  └─────────────────────────────────────────────────────────────┘     │   │
│  │                                                                       │   │
│  │  Actions per threshold:                                               │   │
│  │  - 50%: Log warning, send email                                      │   │
│  │  - 80%: Send Slack/email alert, increase monitoring frequency        │   │
│  │  - 95%: Send urgent alert, prepare shutdown commands                 │   │
│  │  - 100%: Execute automatic service shutdown                          │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Provider API Endpoints

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    COST/USAGE API ENDPOINTS BY PROVIDER                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  GCP                                                                  │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Authentication: Service Account JSON                                │   │
│  │                                                                       │   │
│  │  Billing Export (BigQuery):                                          │   │
│  │  - Dataset: billing_export                                           │   │
│  │  - Table: gcp_billing_export_v1_XXXXXX                               │   │
│  │  - Query: SELECT service, SUM(cost) FROM table WHERE date = today    │   │
│  │                                                                       │   │
│  │  Cloud Billing API:                                                   │   │
│  │  - GET /v1/billingAccounts/{id}/projects                             │   │
│  │                                                                       │   │
│  │  Cloud Run Metrics API:                                               │   │
│  │  - Metric: run.googleapis.com/container/cpu/utilization              │   │
│  │  - Metric: run.googleapis.com/request_count                          │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Azure                                                                │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Authentication: Service Principal (Client ID + Secret)              │   │
│  │                                                                       │   │
│  │  Cost Management API:                                                 │   │
│  │  - POST /subscriptions/{id}/providers/Microsoft.CostManagement/query │   │
│  │  - Body: { "type": "Usage", "timeframe": "MonthToDate" }             │   │
│  │                                                                       │   │
│  │  Usage API:                                                           │   │
│  │  - GET /subscriptions/{id}/providers/Microsoft.Consumption/usageDetails │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Neon.tech                                                            │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Authentication: API Key (Bearer token)                              │   │
│  │                                                                       │   │
│  │  Consumption History API:                                             │   │
│  │  - GET /api/v2/consumption_history/v2/account                        │   │
│  │  - GET /api/v2/consumption_history/v2/projects/{id}                  │   │
│  │  - Params: from, to, granularity (hourly, daily, monthly)            │   │
│  │                                                                       │   │
│  │  Metrics Returned:                                                    │   │
│  │  - compute_unit_seconds                                               │   │
│  │  - root_branch_bytes_month                                            │   │
│  │  - public_network_transfer_bytes                                      │   │
│  │                                                                       │   │
│  │  Rate Limit: 50 requests/minute                                       │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Neo4j AuraDB                                                         │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Authentication: API Key                                             │   │
│  │                                                                       │   │
│  │  Metrics API:                                                         │   │
│  │  - GET /v1/instances/{id}/metrics                                    │   │
│  │                                                                       │   │
│  │  Instance Info:                                                       │   │
│  │  - GET /v1/instances/{id}                                            │   │
│  │  - Returns: node_count, relationship_count, storage_bytes            │   │
│  │                                                                       │   │
│  │  Note: Free tier has fixed cost ($0), monitor usage limits only      │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Cloudflare                                                           │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Authentication: API Token                                           │   │
│  │                                                                       │   │
│  │  GraphQL Analytics API:                                               │   │
│  │  - POST /client/v4/graphql                                           │   │
│  │  - Query: workersInvocationsAdaptive { sum { requests } }            │   │
│  │                                                                       │   │
│  │  Zone Analytics:                                                      │   │
│  │  - GET /zones/{id}/analytics/dashboard                               │   │
│  │                                                                       │   │
│  │  Note: Free tier, monitor for approaching limits only                │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  OpenAI / LLM Providers                                              │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Authentication: API Key (Bearer token)                              │   │
│  │                                                                       │   │
│  │  Usage API:                                                           │   │
│  │  - GET /v1/organization/usage                                        │   │
│  │  - GET /v1/dashboard/billing/usage                                   │   │
│  │  - Params: start_date, end_date                                      │   │
│  │                                                                       │   │
│  │  Metrics Returned:                                                    │   │
│  │  - context_tokens_total                                               │   │
│  │  - generated_tokens_total                                             │   │
│  │  - requests_total                                                     │   │
│  │  - cost_usd (aggregated by model)                                     │   │
│  │                                                                       │   │
│  │  Cost Control: Set usage limits in OpenAI dashboard                  │   │
│  │  Hard Limit: Auto-blocks requests when reached                        │   │
│  │  Soft Limit: Email notification only                                  │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 7. Service Control Automation

### 7.1 Service Control Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SERVICE CONTROL SYSTEM ARCHITECTURE                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    CONTROL PLANE                                     │   │
│  │                    (GCP Cloud Run or Cloud Function)                 │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                       │   │
│  │  Triggers:                                                            │   │
│  │  1. Cost threshold exceeded (from Cost Monitor)                      │   │
│  │  2. Manual trigger via API                                           │   │
│  │  3. Scheduled maintenance window                                     │   │
│  │  4. Pub/Sub message from GCP Budget Alert                            │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│                             │                                               │
│      ┌──────────────────────┼──────────────────────┐                       │
│      │                      │                      │                       │
│      ▼                      ▼                      ▼                       │
│  ┌─────────┐          ┌─────────┐          ┌─────────┐                    │
│  │   GCP   │          │  NEON   │          │  NEO4J  │                    │
│  │ Control │          │ Control │          │ Control │                    │
│  └────┬────┘          └────┬────┘          └────┬────┘                    │
│       │                    │                    │                          │
│       ▼                    ▼                    ▼                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    AVAILABLE ACTIONS                                 │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                       │   │
│  │  GCP Cloud Run:                                                       │   │
│  │  ┌─────────────────────────────────────────────────────────────┐     │   │
│  │  │  ACTION: scale_to_zero                                       │     │   │
│  │  │  API: PATCH /v2/projects/{}/locations/{}/services/{}        │     │   │
│  │  │  Body: { "scaling": { "minInstanceCount": 0, "maxInstance   │     │   │
│  │  │         Count": 0 } }                                        │     │   │
│  │  │  Effect: Service stops accepting requests                    │     │   │
│  │  │  Reversible: Yes (set maxInstanceCount > 0)                  │     │   │
│  │  └─────────────────────────────────────────────────────────────┘     │   │
│  │  ┌─────────────────────────────────────────────────────────────┐     │   │
│  │  │  ACTION: disable_billing                                     │     │   │
│  │  │  API: PATCH /v1/projects/{}/billingInfo                      │     │   │
│  │  │  Body: { "billingAccountName": "" }                          │     │   │
│  │  │  Effect: All GCP services stop (DESTRUCTIVE)                 │     │   │
│  │  │  Reversible: Yes (re-link billing account)                   │     │   │
│  │  └─────────────────────────────────────────────────────────────┘     │   │
│  │                                                                       │   │
│  │  Neon.tech:                                                           │   │
│  │  ┌─────────────────────────────────────────────────────────────┐     │   │
│  │  │  ACTION: suspend_endpoint                                    │     │   │
│  │  │  API: POST /projects/{}/endpoints/{}/suspend                 │     │   │
│  │  │  Effect: Database stops, no billing for compute              │     │   │
│  │  │  Reversible: Yes (auto-resumes on connection)                │     │   │
│  │  └─────────────────────────────────────────────────────────────┘     │   │
│  │  ┌─────────────────────────────────────────────────────────────┐     │   │
│  │  │  ACTION: set_quota_zero                                      │     │   │
│  │  │  API: PATCH /projects/{}                                     │     │   │
│  │  │  Body: { "quota": { "active_time_seconds": 0 } }             │     │   │
│  │  │  Effect: Endpoint auto-suspends, cannot resume               │     │   │
│  │  │  Reversible: Yes (increase quota)                            │     │   │
│  │  └─────────────────────────────────────────────────────────────┘     │   │
│  │                                                                       │   │
│  │  Neo4j AuraDB:                                                        │   │
│  │  ┌─────────────────────────────────────────────────────────────┐     │   │
│  │  │  ACTION: pause_instance                                      │     │   │
│  │  │  API: POST /v1/instances/{}/pause                            │     │   │
│  │  │  Effect: Database pauses, billed at 20% (Pro) or $0 (Free)  │     │   │
│  │  │  Reversible: Yes (POST /v1/instances/{}/resume)              │     │   │
│  │  └─────────────────────────────────────────────────────────────┘     │   │
│  │  ┌─────────────────────────────────────────────────────────────┐     │   │
│  │  │  ACTION: delete_instance (DESTRUCTIVE)                       │     │   │
│  │  │  API: DELETE /v1/instances/{}                                │     │   │
│  │  │  Effect: Instance deleted, data lost                         │     │   │
│  │  │  Reversible: No                                              │     │   │
│  │  └─────────────────────────────────────────────────────────────┘     │   │
│  │                                                                       │   │
│  │  Azure Static Web Apps:                                               │   │
│  │  ┌─────────────────────────────────────────────────────────────┐     │   │
│  │  │  Note: Free tier cannot be "disabled" - only deleted         │     │   │
│  │  │  Recommendation: Leave running (zero cost on free tier)      │     │   │
│  │  └─────────────────────────────────────────────────────────────┘     │   │
│  │                                                                       │   │
│  │  Cloudflare:                                                          │   │
│  │  ┌─────────────────────────────────────────────────────────────┐     │   │
│  │  │  Note: Free tier cannot exceed limits                        │     │   │
│  │  │  ACTION: disable_proxy                                       │     │   │
│  │  │  API: PATCH /zones/{}/dns_records/{}                         │     │   │
│  │  │  Body: { "proxied": false }                                  │     │   │
│  │  │  Effect: Traffic goes direct, loses CDN/WAF                  │     │   │
│  │  └─────────────────────────────────────────────────────────────┘     │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 Shutdown Sequence

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GRACEFUL SHUTDOWN SEQUENCE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  TRIGGER: Monthly cost exceeds $95 (95% of $100 budget)                     │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  PHASE 1: ALERT (Immediate)                                          │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  1. Send email to admin                                              │   │
│  │  2. Send Slack notification                                          │   │
│  │  3. Log to Cloud Logging with severity=CRITICAL                      │   │
│  │  4. Set maintenance banner on UI (if possible)                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                             │                                               │
│                             ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  PHASE 2: PREPARE (T+5 minutes)                                      │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  1. Take database snapshot (Neon point-in-time backup)               │   │
│  │  2. Export Neo4j graph (if Pro tier)                                │   │
│  │  3. Notify active users via websocket                                │   │
│  │  4. Complete in-flight requests (drain connections)                  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                             │                                               │
│                             ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  PHASE 3: SCALE DOWN (T+10 minutes)                                  │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Order of shutdown (least to most critical):                         │   │
│  │                                                                       │   │
│  │  1. log-analyzer (background service)                                │   │
│  │     └─▶ Scale Cloud Run to 0                                        │   │
│  │                                                                       │   │
│  │  2. rac-ui-server                                                    │   │
│  │     └─▶ Scale Cloud Run to 0                                        │   │
│  │                                                                       │   │
│  │  3. rac-system-admin-mcp                                             │   │
│  │     └─▶ Scale Cloud Run to 0                                        │   │
│  │                                                                       │   │
│  │  4. rac-ops-storage-mcp                                              │   │
│  │     └─▶ Scale Cloud Run to 0                                        │   │
│  │                                                                       │   │
│  │  5. rac-knowledge-mcp                                                │   │
│  │     └─▶ Scale Cloud Run to 0                                        │   │
│  │                                                                       │   │
│  │  6. rac-knowledge-api                                                │   │
│  │     └─▶ Scale Cloud Run to 0                                        │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                             │                                               │
│                             ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  PHASE 4: DATABASE SUSPEND (T+15 minutes)                            │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                       │   │
│  │  1. Neon.tech: Suspend compute endpoint                              │   │
│  │     └─▶ POST /projects/{}/endpoints/{}/suspend                      │   │
│  │                                                                       │   │
│  │  2. Neo4j: Pause instance (if Pro)                                  │   │
│  │     └─▶ POST /v1/instances/{}/pause                                 │   │
│  │     Note: Free tier auto-pauses after 3 days anyway                 │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                             │                                               │
│                             ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  PHASE 5: CONFIRM (T+20 minutes)                                     │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  1. Verify all services scaled to 0                                  │   │
│  │  2. Verify databases suspended                                       │   │
│  │  3. Send confirmation email with:                                    │   │
│  │     - Final cost snapshot                                            │   │
│  │     - Services shut down                                             │   │
│  │     - Recovery instructions                                          │   │
│  │  4. Update status page (Cloudflare Workers)                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  SERVICES LEFT RUNNING (Zero Cost):                                         │
│  - Cloudflare DNS/CDN (free tier)                                          │
│  - Azure Static Web Apps (free tier) - shows maintenance page              │
│  - GCP Secret Manager (static secrets, minimal cost)                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7.3 Recovery Sequence

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SERVICE RECOVERY SEQUENCE                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  TRIGGER: New billing period OR manual intervention                         │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  PHASE 1: PRE-CHECKS                                                  │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  1. Verify budget has reset or been increased                        │   │
│  │  2. Confirm payment method is valid                                   │   │
│  │  3. Check for any provider-side issues                               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                             │                                               │
│                             ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  PHASE 2: DATABASE RESUME                                            │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  1. Neon.tech: Resume endpoint (auto on connection) or              │   │
│  │     └─▶ PATCH /projects/{} with quota > 0                           │   │
│  │  2. Neo4j: Resume instance                                          │   │
│  │     └─▶ POST /v1/instances/{}/resume                                │   │
│  │  3. Wait for databases to be ready (health checks)                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                             │                                               │
│                             ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  PHASE 3: COMPUTE RESUME                                             │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Order of startup (most to least critical):                          │   │
│  │                                                                       │   │
│  │  1. rac-knowledge-api                                                │   │
│  │     └─▶ PATCH with minInstanceCount: 1, maxInstanceCount: 5         │   │
│  │                                                                       │   │
│  │  2. rac-knowledge-mcp                                                │   │
│  │     └─▶ PATCH with minInstanceCount: 1, maxInstanceCount: 5         │   │
│  │                                                                       │   │
│  │  3. rac-ops-storage-mcp                                              │   │
│  │     └─▶ PATCH with minInstanceCount: 0, maxInstanceCount: 5         │   │
│  │                                                                       │   │
│  │  4. rac-system-admin-mcp                                             │   │
│  │     └─▶ PATCH with minInstanceCount: 0, maxInstanceCount: 3         │   │
│  │                                                                       │   │
│  │  5. rac-ui-server                                                    │   │
│  │     └─▶ PATCH with minInstanceCount: 0, maxInstanceCount: 3         │   │
│  │                                                                       │   │
│  │  6. log-analyzer                                                     │   │
│  │     └─▶ PATCH with minInstanceCount: 0, maxInstanceCount: 1         │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                             │                                               │
│                             ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  PHASE 4: HEALTH VERIFICATION                                        │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  1. Hit health endpoints for each service                           │   │
│  │  2. Verify database connectivity                                     │   │
│  │  3. Run smoke tests                                                  │   │
│  │  4. Update status page                                               │   │
│  │  5. Send recovery notification                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Deployment Environments

### 8.1 Environment Configuration

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ENVIRONMENT CONFIGURATION                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  DEVELOPMENT                                                          │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Budget: $50/month                                                    │   │
│  │  Target: $15-25/month actual spend                                   │   │
│  │                                                                       │   │
│  │  Cloud Run:                                                           │   │
│  │  - All services: minInstances = 0 (full scale-to-zero)              │   │
│  │  - Accept cold starts (5-15 seconds)                                 │   │
│  │  - Lower memory/CPU allocations                                      │   │
│  │                                                                       │   │
│  │  Databases:                                                           │   │
│  │  - Neon: Free tier or dev branch of Pro                              │   │
│  │  - Neo4j: Free tier (50K nodes sufficient)                           │   │
│  │                                                                       │   │
│  │  Monitoring:                                                          │   │
│  │  - Cost check: Every hour                                             │   │
│  │  - Alerts: Email only                                                 │   │
│  │                                                                       │   │
│  │  Domain: dev.rac.example.com                                          │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  STAGING                                                              │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Budget: $30/month (shared from production budget)                   │   │
│  │                                                                       │   │
│  │  Cloud Run:                                                           │   │
│  │  - Primary services: minInstances = 0                                │   │
│  │  - Deployed only during testing windows                              │   │
│  │                                                                       │   │
│  │  Databases:                                                           │   │
│  │  - Neon: Separate branch (free with Pro)                             │   │
│  │  - Neo4j: Shared free tier instance                                  │   │
│  │                                                                       │   │
│  │  Domain: staging.rac.example.com                                      │   │
│  │                                                                       │   │
│  │  Note: Staging auto-shuts down after 2 hours of inactivity           │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  PRODUCTION                                                           │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Budget: $100/month (hard limit with auto-shutdown)                  │   │
│  │  Target: $80-95/month actual spend                                   │   │
│  │                                                                       │   │
│  │  Cloud Run:                                                           │   │
│  │  - rac-knowledge-api: minInstances = 1 (always warm)                │   │
│  │  - rac-knowledge-mcp: minInstances = 1 (always warm)                │   │
│  │  - Other services: minInstances = 0                                  │   │
│  │                                                                       │   │
│  │  Databases:                                                           │   │
│  │  - Neon: Pro tier ($19/month + overages)                             │   │
│  │  - Neo4j: Free tier (upgrade trigger at 40K nodes)                   │   │
│  │                                                                       │   │
│  │  Monitoring:                                                          │   │
│  │  - Cost check: Every 15 minutes                                      │   │
│  │  - Alerts: Email + Slack                                             │   │
│  │  - Auto-shutdown at 100% budget                                      │   │
│  │                                                                       │   │
│  │  Domain: rac.example.com                                              │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 9. Infrastructure as Code Structure

### 9.1 Repository Structure

```
rac-infrastructure/
├── README.md                          # This document
├── .github/
│   └── workflows/
│       ├── deploy-dev.yml             # Development deployment
│       ├── deploy-staging.yml         # Staging deployment
│       ├── deploy-prod.yml            # Production deployment
│       ├── cost-monitor.yml           # Scheduled cost checks
│       └── terraform-plan.yml         # PR terraform plan
│
├── terraform/
│   ├── main.tf                        # Root module
│   ├── providers.tf                   # Provider configurations
│   ├── variables.tf                   # Input variables
│   ├── outputs.tf                     # Output values
│   ├── backend.tf                     # State backend (GCS)
│   │
│   ├── modules/
│   │   ├── gcp-cloud-run/
│   │   │   ├── main.tf               # Cloud Run service definition
│   │   │   ├── variables.tf          # Service configuration
│   │   │   ├── outputs.tf            # Service URL, etc.
│   │   │   └── iam.tf                # Service account bindings
│   │   │
│   │   ├── gcp-secrets/
│   │   │   ├── main.tf               # Secret Manager resources
│   │   │   └── variables.tf          # Secret definitions
│   │   │
│   │   ├── gcp-monitoring/
│   │   │   ├── main.tf               # Logging, monitoring, alerts
│   │   │   ├── budgets.tf            # Budget alerts
│   │   │   └── dashboards.tf         # Monitoring dashboards
│   │   │
│   │   ├── azure-static-web/
│   │   │   ├── main.tf               # Static Web App resource
│   │   │   └── variables.tf
│   │   │
│   │   ├── cloudflare-dns/
│   │   │   ├── main.tf               # DNS records, page rules
│   │   │   └── variables.tf
│   │   │
│   │   └── cost-monitor/
│   │       ├── main.tf               # Cost monitoring function
│   │       ├── scheduler.tf          # Cloud Scheduler trigger
│   │       └── pubsub.tf             # Budget alert subscription
│   │
│   └── environments/
│       ├── dev.tfvars                # Development variables
│       ├── staging.tfvars            # Staging variables
│       └── prod.tfvars               # Production variables
│
├── scripts/
│   ├── cost-monitor/
│   │   ├── Dockerfile               # Container for cost monitor
│   │   ├── requirements.txt         # Python dependencies
│   │   ├── config.yaml              # Thresholds and settings
│   │   └── src/
│   │       ├── __init__.py
│   │       ├── main.py              # Entry point
│   │       ├── collectors/          # Per-provider collectors
│   │       ├── aggregator.py        # Cost aggregation
│   │       ├── thresholds.py        # Threshold checking
│   │       └── actions.py           # Service control actions
│   │
│   ├── service-control/
│   │   ├── shutdown.sh              # Manual shutdown script
│   │   ├── startup.sh               # Manual startup script
│   │   └── health-check.sh          # Health verification
│   │
│   └── database/
│       ├── backup-neon.sh           # Neon backup script
│       ├── backup-neo4j.sh          # Neo4j export script
│       └── restore.sh               # Restore procedures
│
├── config/
│   ├── budgets.yaml                 # Budget configurations
│   ├── alerts.yaml                  # Alert routing rules
│   └── thresholds.yaml              # Cost thresholds
│
├── docs/
│   ├── ARCHITECTURE.md              # This document
│   ├── RUNBOOKS.md                  # Operational procedures
│   ├── MIGRATION.md                 # Migration guide
│   └── TROUBLESHOOTING.md           # Common issues
│
└── docker/
    ├── cost-monitor/
    │   └── Dockerfile
    └── service-control/
        └── Dockerfile
```

### 9.2 Terraform Module Dependencies

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TERRAFORM MODULE DEPENDENCY GRAPH                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                         ┌───────────────────┐                               │
│                         │   Root Module     │                               │
│                         │   (main.tf)       │                               │
│                         └─────────┬─────────┘                               │
│                                   │                                         │
│          ┌────────────────────────┼────────────────────────┐               │
│          │                        │                        │               │
│          ▼                        ▼                        ▼               │
│  ┌───────────────┐       ┌───────────────┐       ┌───────────────┐        │
│  │ gcp-secrets   │       │cloudflare-dns │       │azure-static-  │        │
│  │               │       │               │       │web            │        │
│  └───────┬───────┘       └───────┬───────┘       └───────────────┘        │
│          │                       │                                         │
│          │                       │  (DNS records depend on                 │
│          │                       │   Cloud Run URLs)                       │
│          │                       │                                         │
│          ▼                       │                                         │
│  ┌───────────────┐               │                                         │
│  │gcp-cloud-run  │◀──────────────┘                                         │
│  │               │                                                          │
│  │ (Depends on   │                                                          │
│  │  secrets for  │                                                          │
│  │  env vars)    │                                                          │
│  └───────┬───────┘                                                          │
│          │                                                                  │
│          ▼                                                                  │
│  ┌───────────────┐       ┌───────────────┐                                 │
│  │gcp-monitoring │       │ cost-monitor  │                                 │
│  │               │       │               │                                 │
│  │ (Dashboards,  │       │ (Scheduled    │                                 │
│  │  alerts for   │◀──────│  function to  │                                 │
│  │  Cloud Run)   │       │  check costs) │                                 │
│  └───────────────┘       └───────────────┘                                 │
│                                                                             │
│  External Dependencies (not managed by Terraform):                          │
│  - Neon.tech PostgreSQL (managed via Neon console/API)                     │
│  - Neo4j AuraDB (managed via Aura console/API)                             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 10. Monitoring and Observability

### 10.1 Monitoring Stack

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    OBSERVABILITY ARCHITECTURE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    GCP CLOUD OPERATIONS SUITE                        │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                       │   │
│  │  CLOUD LOGGING (50GB free/month):                                    │   │
│  │  ┌─────────────────────────────────────────────────────────────┐     │   │
│  │  │  Sources:                                                    │     │   │
│  │  │  - Cloud Run container logs                                  │     │   │
│  │  │  - Cloud Run request logs                                    │     │   │
│  │  │  - Cloud Function logs                                       │     │   │
│  │  │  - Audit logs                                                │     │   │
│  │  │                                                              │     │   │
│  │  │  Log Sinks:                                                  │     │   │
│  │  │  - errors → Cloud Monitoring (trigger alerts)               │     │   │
│  │  │  - audit → BigQuery (long-term retention)                   │     │   │
│  │  │  - cost-events → Pub/Sub (trigger actions)                  │     │   │
│  │  └─────────────────────────────────────────────────────────────┘     │   │
│  │                                                                       │   │
│  │  CLOUD MONITORING:                                                    │   │
│  │  ┌─────────────────────────────────────────────────────────────┐     │   │
│  │  │  Metrics:                                                    │     │   │
│  │  │  - Cloud Run: request_count, latency, cpu, memory           │     │   │
│  │  │  - Custom: cost_current, cost_projected, budget_remaining   │     │   │
│  │  │                                                              │     │   │
│  │  │  Dashboards:                                                 │     │   │
│  │  │  - Service Health: All Cloud Run services                   │     │   │
│  │  │  - Cost Overview: Current spend by provider                 │     │   │
│  │  │  - Performance: Latency percentiles, error rates            │     │   │
│  │  └─────────────────────────────────────────────────────────────┘     │   │
│  │                                                                       │   │
│  │  ALERTING POLICIES:                                                   │   │
│  │  ┌─────────────────────────────────────────────────────────────┐     │   │
│  │  │  Critical:                                                   │     │   │
│  │  │  - Error rate > 5% for 5 minutes                            │     │   │
│  │  │  - Cost > 95% of budget                                     │     │   │
│  │  │  - Service unavailable > 2 minutes                          │     │   │
│  │  │                                                              │     │   │
│  │  │  Warning:                                                    │     │   │
│  │  │  - Latency p99 > 5s for 10 minutes                          │     │   │
│  │  │  - Cost > 80% of budget                                     │     │   │
│  │  │  - Neo4j nodes > 40,000                                     │     │   │
│  │  │                                                              │     │   │
│  │  │  Notification Channels:                                      │     │   │
│  │  │  - Email: admin@example.com                                  │     │   │
│  │  │  - Slack: #rac-alerts (via webhook)                         │     │   │
│  │  └─────────────────────────────────────────────────────────────┘     │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    EXTERNAL MONITORING                               │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                       │   │
│  │  UPTIMEROBOT (Free - 50 monitors):                                   │   │
│  │  - https://rac.example.com (HTTP 200)                                │   │
│  │  - https://api.rac.example.com/health (HTTP 200)                     │   │
│  │  - Check interval: 5 minutes                                         │   │
│  │                                                                       │   │
│  │  CLOUDFLARE ANALYTICS (Free):                                        │   │
│  │  - Request volume                                                    │   │
│  │  - Cache hit rate                                                    │   │
│  │  - Threat mitigation                                                 │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 11. Disaster Recovery

### 11.1 Backup Strategy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    BACKUP AND RECOVERY STRATEGY                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  NEON.TECH POSTGRESQL                                                │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                       │   │
│  │  Built-in (Pro Plan):                                                │   │
│  │  - Point-in-time recovery (PITR): Last 7 days                        │   │
│  │  - Automatic: Every change is logged                                 │   │
│  │  - Recovery: Restore to any point in time                            │   │
│  │                                                                       │   │
│  │  Additional (Manual):                                                 │   │
│  │  - Weekly pg_dump to GCS bucket                                      │   │
│  │  - Retention: 30 days                                                │   │
│  │  - Trigger: Cloud Scheduler (Sundays 3 AM UTC)                       │   │
│  │                                                                       │   │
│  │  Recovery Time Objective (RTO): < 1 hour                             │   │
│  │  Recovery Point Objective (RPO): < 5 minutes (PITR)                  │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  NEO4J AURADB                                                         │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                       │   │
│  │  Free Tier:                                                           │   │
│  │  - No automatic backups                                              │   │
│  │  - Manual: Weekly Cypher export to GCS                               │   │
│  │                                                                       │   │
│  │  Pro Tier ($65/mo):                                                   │   │
│  │  - Daily automated snapshots                                         │   │
│  │  - On-demand snapshots                                               │   │
│  │  - 7-day retention                                                   │   │
│  │                                                                       │   │
│  │  Recovery Time Objective (RTO): < 2 hours (restore from export)      │   │
│  │  Recovery Point Objective (RPO): < 24 hours (weekly export)          │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  APPLICATION STATE                                                    │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                       │   │
│  │  Cloud Run Services: Stateless (no backup needed)                    │   │
│  │  - Container images stored in Artifact Registry                      │   │
│  │  - Environment from Secret Manager                                   │   │
│  │                                                                       │   │
│  │  Infrastructure as Code:                                              │   │
│  │  - Terraform state in GCS bucket (versioned)                         │   │
│  │  - Git repository for all configurations                             │   │
│  │                                                                       │   │
│  │  Secrets:                                                             │   │
│  │  - GCP Secret Manager (versioned, no backup needed)                  │   │
│  │  - Documented in secure password manager                             │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 12. Security Architecture

### 12.1 Authentication and Authorization

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SECURITY ARCHITECTURE                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  SECRETS MANAGEMENT                                                   │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                       │   │
│  │  GCP Secret Manager:                                                  │   │
│  │  ┌─────────────────────────────────────────────────────────────┐     │   │
│  │  │  Secrets Stored:                                             │     │   │
│  │  │  - NEON_DATABASE_URL (PostgreSQL connection string)         │     │   │
│  │  │  - NEO4J_URI, NEO4J_USER, NEO4J_PASSWORD                    │     │   │
│  │  │  - OPENAI_API_KEY                                            │     │   │
│  │  │  - GITHUB_TOKEN (for sync)                                   │     │   │
│  │  │  - JWT_SECRET (session signing)                              │     │   │
│  │  │  - NEON_API_KEY (for cost monitoring)                        │     │   │
│  │  │  - NEO4J_API_KEY (for cost monitoring)                       │     │   │
│  │  │                                                              │     │   │
│  │  │  Access Control:                                             │     │   │
│  │  │  - Cloud Run SA: secretAccessor on specific secrets         │     │   │
│  │  │  - Cost Monitor SA: secretAccessor on API keys only          │     │   │
│  │  │  - No human access in production                             │     │   │
│  │  └─────────────────────────────────────────────────────────────┘     │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  SERVICE AUTHENTICATION                                               │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                       │   │
│  │  Provider API Keys (stored in Secret Manager):                       │   │
│  │  - Neon: Bearer token for API calls                                  │   │
│  │  - Neo4j: Basic auth or API key                                      │   │
│  │  - Cloudflare: API token (scoped to zone)                            │   │
│  │  - Azure: Service Principal (Client ID + Secret)                     │   │
│  │  - GCP: Service Account JSON                                         │   │
│  │                                                                       │   │
│  │  Inter-Service Auth (Cloud Run to Cloud Run):                        │   │
│  │  - Option A: IAM-based (require authentication)                      │   │
│  │  - Option B: Internal service account tokens                         │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  NETWORK SECURITY                                                     │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                       │   │
│  │  Cloudflare (Edge):                                                   │   │
│  │  - DDoS protection (automatic)                                       │   │
│  │  - WAF rules (OWASP Top 10 blocking)                                 │   │
│  │  - Rate limiting (100 req/min per IP)                                │   │
│  │  - Bot management (challenge suspicious)                             │   │
│  │                                                                       │   │
│  │  TLS/SSL:                                                             │   │
│  │  - All traffic HTTPS (TLS 1.3)                                       │   │
│  │  - Cloudflare origin certificates                                    │   │
│  │  - HSTS enabled                                                      │   │
│  │                                                                       │   │
│  │  Database Connections:                                                │   │
│  │  - Neon: SSL required, connection pooling                            │   │
│  │  - Neo4j: Bolt+s (encrypted)                                         │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 13. Operational Runbooks

### 13.1 Common Operations

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    OPERATIONAL RUNBOOKS                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  RUNBOOK: Deploy New Version                                                │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Trigger: Git push to main branch                                           │
│  Automation: GitHub Actions workflow                                        │
│                                                                             │
│  Steps:                                                                     │
│  1. Build container images                                                  │
│  2. Push to GCP Artifact Registry                                           │
│  3. Deploy to Cloud Run (traffic split 10% → 100%)                         │
│  4. Run smoke tests                                                         │
│  5. If tests fail: automatic rollback                                       │
│                                                                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                                                             │
│  RUNBOOK: Investigate High Latency                                          │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Trigger: Alert - Latency p99 > 5s                                          │
│                                                                             │
│  Steps:                                                                     │
│  1. Check Cloud Run metrics (CPU, memory, instance count)                   │
│  2. Check Neon metrics (compute usage, connection count)                    │
│  3. Check Neo4j metrics (query time, memory)                                │
│  4. Review recent deployments                                               │
│  5. Check for cold starts (min instances = 0?)                              │
│                                                                             │
│  Common Causes:                                                             │
│  - Cold start: Increase minInstances                                        │
│  - Database: Slow query, add index                                          │
│  - Memory: Increase Cloud Run memory                                        │
│                                                                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                                                             │
│  RUNBOOK: Cost Threshold Exceeded                                           │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Trigger: Cost > 80% of budget                                              │
│                                                                             │
│  Steps:                                                                     │
│  1. Check which provider/service is over-consuming                          │
│  2. Review recent traffic patterns                                          │
│  3. Identify optimization opportunities:                                    │
│     - Reduce minInstances (accept cold starts)                              │
│     - Lower Neon compute quota                                              │
│     - Implement caching                                                     │
│  4. If cannot reduce: Prepare for shutdown at 100%                          │
│  5. Notify stakeholders                                                     │
│                                                                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                                                             │
│  RUNBOOK: Neo4j Node Limit Approaching                                      │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Trigger: Neo4j nodes > 40,000                                              │
│                                                                             │
│  Steps:                                                                     │
│  1. Evaluate current graph size and growth rate                             │
│  2. Identify data that can be archived or deleted                           │
│  3. If cleanup not sufficient:                                              │
│     - Option A: Upgrade to AuraDB Pro ($65/mo)                              │
│     - Option B: Migrate to self-hosted on GCP Compute                       │
│  4. Plan migration during low-traffic window                                │
│  5. Update budget projections                                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 14. Migration Plan

### 14.1 Migration Phases

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MIGRATION FROM DOCKER COMPOSE TO MULTI-CLOUD              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PHASE 1: FOUNDATION (Week 1-2)                                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│  □ Create GCP project with billing account                                 │
│  □ Create Azure subscription (free tier)                                   │
│  □ Create Cloudflare account and zone                                      │
│  □ Create Neon.tech project                                                │
│  □ Create Neo4j AuraDB instance (free tier)                                │
│  □ Set up Terraform backend (GCS bucket)                                   │
│  □ Initialize Terraform project structure                                  │
│  □ Configure GitHub Actions for CI/CD                                      │
│                                                                             │
│  Deliverables:                                                              │
│  - All provider accounts created                                            │
│  - Terraform modules drafted                                                │
│  - CI/CD pipeline skeleton                                                  │
│                                                                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                                                             │
│  PHASE 2: DATABASE MIGRATION (Week 3-4)                                     │
│  ─────────────────────────────────────────────────────────────────────────  │
│  □ Export PostgreSQL schema from current database                          │
│  □ Export PostgreSQL data (pg_dump)                                        │
│  □ Import to Neon.tech (psql)                                              │
│  □ Enable pgvector extension                                               │
│  □ Verify vector search functionality                                      │
│  □ Export Neo4j data (Cypher export or APOC)                               │
│  □ Import to AuraDB                                                        │
│  □ Verify graph queries                                                    │
│  □ Update connection strings in Secret Manager                             │
│  □ Test application against new databases                                  │
│                                                                             │
│  Deliverables:                                                              │
│  - Databases migrated and verified                                          │
│  - Connection strings in Secret Manager                                     │
│  - Data integrity confirmed                                                 │
│                                                                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                                                             │
│  PHASE 3: APPLICATION DEPLOYMENT (Week 5-6)                                 │
│  ─────────────────────────────────────────────────────────────────────────  │
│  □ Build container images for Cloud Run                                    │
│  □ Push images to Artifact Registry                                        │
│  □ Deploy MCP servers to Cloud Run                                         │
│  □ Configure environment variables from Secret Manager                     │
│  □ Deploy Next.js to Azure Static Web Apps                                 │
│  □ Configure Cloudflare DNS and routing                                    │
│  □ Set up SSL/TLS certificates                                             │
│  □ Verify end-to-end functionality                                         │
│                                                                             │
│  Deliverables:                                                              │
│  - All services running on cloud                                            │
│  - DNS pointing to new infrastructure                                       │
│  - End-to-end tests passing                                                 │
│                                                                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                                                             │
│  PHASE 4: MONITORING AND AUTOMATION (Week 7-8)                              │
│  ─────────────────────────────────────────────────────────────────────────  │
│  □ Deploy cost monitoring function                                         │
│  □ Configure Cloud Scheduler triggers                                      │
│  □ Set up budget alerts in GCP                                             │
│  □ Configure alerting policies                                             │
│  □ Create monitoring dashboards                                            │
│  □ Set up Neon.tech consumption limits                                     │
│  □ Test shutdown/recovery procedures                                       │
│  □ Document runbooks                                                       │
│  □ Performance testing and optimization                                    │
│                                                                             │
│  Deliverables:                                                              │
│  - Cost monitoring active                                                   │
│  - Alerts configured                                                        │
│  - Runbooks documented                                                      │
│  - Performance baselines established                                        │
│                                                                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                                                             │
│  PHASE 5: CUTOVER (Week 9)                                                  │
│  ─────────────────────────────────────────────────────────────────────────  │
│  □ Final data sync from old to new databases                               │
│  □ Update DNS to point to new infrastructure                               │
│  □ Monitor for issues (24-hour watch)                                      │
│  □ Decommission old infrastructure                                         │
│  □ Update documentation                                                    │
│                                                                             │
│  Deliverables:                                                              │
│  - Production traffic on new infrastructure                                 │
│  - Old infrastructure decommissioned                                        │
│  - Documentation updated                                                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 15. SLA and Capacity Planning

### 15.1 Service Level Objectives

| Component | Availability Target | Latency P99 | Recovery Time |
|-----------|---------------------|-------------|---------------|
| API Backend (Cloud Run) | 99.5% | 500ms | < 5 min |
| Frontend (Azure SWA) | 99.9% | 100ms | Automatic |
| PostgreSQL (Neon) | 99.95% | 50ms | < 2 min |
| Graph Database (Neo4j) | 99.0% | 200ms | < 60 sec (cold start) |
| CDN (Cloudflare) | 99.9% | 20ms | Automatic |

### 15.2 Free Tier Capacity Limits

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    FREE TIER CAPACITY PLANNING                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  NEON.TECH FREE TIER                                                        │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Compute: 191.9 hours/month (~6.4 hrs/day)                                  │
│  Storage: 512 MB                                                            │
│  Branches: 10 maximum                                                       │
│                                                                             │
│  Capacity Estimate (20-30 users):                                           │
│  - Avg session: 2 hours/user/day                                            │
│  - Total: 40-60 compute hours/day                                           │
│  - Result: EXCEEDS free tier → Pro plan required ($19/mo)                   │
│                                                                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                                                             │
│  NEO4J AURADB FREE TIER                                                     │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Nodes: 50,000 maximum                                                      │
│  Relationships: 175,000 maximum                                             │
│  Storage: ~100 MB                                                           │
│  Cold start: 30-60 seconds after inactivity                                 │
│                                                                             │
│  Capacity Estimate (knowledge base):                                        │
│  - Documents: ~5,000                                                        │
│  - Nodes per doc: 5-10 (sections, entities)                                 │
│  - Total nodes: 25,000-50,000                                               │
│  - Result: FITS free tier for development/small production                  │
│                                                                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                                                             │
│  GCP CLOUD RUN FREE TIER                                                    │
│  ─────────────────────────────────────────────────────────────────────────  │
│  CPU: 180,000 vCPU-seconds/month                                            │
│  Memory: 360,000 GiB-seconds/month                                          │
│  Requests: 2 million/month                                                  │
│                                                                             │
│  Capacity Estimate (API backend):                                           │
│  - Avg request: 0.5 vCPU for 200ms                                          │
│  - 20-30 users × 100 requests/day = 2,000-3,000 requests/day                │
│  - Daily CPU: 200-300 vCPU-seconds                                          │
│  - Monthly: 6,000-9,000 vCPU-seconds                                        │
│  - Result: FITS free tier with margin                                       │
│                                                                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                                                             │
│  CLOUDFLARE FREE TIER                                                       │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Workers: 100,000 requests/day                                              │
│  Pages: Unlimited static hosting                                            │
│  CDN: Unlimited bandwidth                                                   │
│                                                                             │
│  Result: FITS free tier comfortably                                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 15.3 Scaling Decision Points

| Metric | Threshold | Action |
|--------|-----------|--------|
| Neon compute hours | >150 hrs/mo | Upgrade to Pro ($19/mo) |
| Neo4j nodes | >40,000 | Plan migration to Pro ($65/mo) |
| Cloud Run requests | >1.5M/mo | Review optimization or accept costs |
| LLM token usage | >$50/mo | Implement caching, reduce context |
| Response latency P99 | >1000ms | Add min instances to Cloud Run |

### 15.4 Cost Escalation Path

```
DEVELOPMENT ($0-25/mo)
       │
       ▼ Neon exceeds free tier
EARLY PRODUCTION ($25-50/mo)
       │
       ▼ Neo4j exceeds limits + LLM usage grows
GROWTH PHASE ($70-100/mo)
       │
       ▼ Add Cloud Run min instance + higher LLM usage
STABLE PRODUCTION ($100-150/mo)
```

---

## Appendix A: Cost Summary

### Infrastructure Costs

| Component | Development | Production | Notes |
|-----------|-------------|------------|-------|
| GCP Cloud Run | $0 (free tier) | $47 (1 min instance) | Scale-to-zero in dev |
| GCP Secret Manager | $0 | $1-2 | ~20 secrets |
| GCP Cloud Logging | $0 | $0 | 50GB free |
| Azure Static Web Apps | $0 | $0 | Free tier |
| Cloudflare | $0 | $0 | Free tier |
| Neon.tech | $0 (free) | $19-35 | Pro tier required |
| Neo4j AuraDB | $0 (free) | $0-65 | Free → Pro if needed |
| **Infrastructure Subtotal** | **$0-5** | **$67-100** | |

### LLM API Costs

| Provider | Development | Production | Notes |
|----------|-------------|------------|-------|
| OpenAI API | $10-20 | $30-50 | GPT-4o for complex queries |
| **LLM Subtotal** | **$10-20** | **$30-50** | |

### Total Budget

| Category | Development | Production | Hard Limit |
|----------|-------------|------------|------------|
| Infrastructure | $0-5 | $67-100 | - |
| LLM API | $10-20 | $30-50 | - |
| **Grand Total** | **$15-25** | **$100-150** | **$50 / $150** |

---

## Appendix B: API Reference Quick Card

| Provider | Cost API | Disable API | Auth |
|----------|----------|-------------|------|
| GCP | BigQuery billing export | Cloud Billing API | Service Account |
| Azure | Cost Management REST | Resource Management | Service Principal |
| Neon | /api/v2/consumption_history | /endpoints/{}/suspend | API Key |
| Neo4j | /v1/instances/{}/metrics | /v1/instances/{}/pause | API Key |
| Cloudflare | GraphQL Analytics | /zones/{}/dns_records | API Token |
| OpenAI | /v1/organization/usage | Dashboard hard limit | API Key |

---

## Appendix C: Threshold Reference

### Infrastructure Thresholds

| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| Monthly infra cost | 50% of budget | 95% of budget | Alert / Shutdown |
| Cloud Run vCPU-sec | 150K | 180K | Alert / Optimize |
| Neon compute hours | 250 | 290 | Alert / Upgrade |
| Neo4j nodes | 40K | 48K | Plan migration |
| Neo4j relationships | 140K | 170K | Plan migration |

### LLM API Thresholds

| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| LLM monthly spend | $25 (dev) / $40 (prod) | $45 (dev) / $48 (prod) | Alert / Enable caching |
| Daily token usage | 500K tokens | 1M tokens | Alert / Review queries |
| Request error rate | 5% | 10% | Alert / Check prompts |

---

**Document Maintainer:** Infrastructure Team
**Last Updated:** 2026-02-07
**Review Schedule:** Monthly
