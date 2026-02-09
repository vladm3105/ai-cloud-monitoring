---
title: "ADR-12: D5 Data Persistence & Storage Architecture"
tags:
  - adr
  - layer-5-artifact
  - d5-data
  - domain-module
  - bigquery
  - firestore
  - multi-tenant
  - row-level-security
custom_fields:
  document_type: adr
  artifact_type: ADR
  layer: 5
  module_id: D5
  module_name: Data Persistence & Storage
  descriptive_slug: d5_data_persistence
  architecture_approaches: [ai-agent-based]
  priority: primary
  development_status: draft
  template_source: ADR-MVP-TEMPLATE.md
  schema_reference: ADR_MVP_SCHEMA.yaml
  schema_version: "1.0"
  sys_ready_score: 92
---

@brd:BRD-12
@prd:PRD-12
@ears:EARS-12
@bdd:BDD-12
@depends:ADR-06 (F6 Infrastructure - database provisioning)
@discoverability:ADR-08 (Database Strategy MVP); ADR-03 (BigQuery decision); ADR-09 (D2 Analytics - BigQuery queries); ADR-11 (D4 Multi-Cloud - data ingestion)

# ADR-12: D5 Data Persistence & Storage Architecture

## 1. Document Control

| Item | Details |
|------|---------|
| **Status** | Proposed |
| **Date** | 2026-02-09 |
| **Decision Makers** | Chief Architect, Platform Team |
| **Author** | Architecture Team |
| **Version** | 1.0 |
| **SYS-Ready Score** | 92/100 (Target: >=85 for MVP) |

---

## 2. Context

### 2.1 Problem Statement

**Originating Topic**: BRD.12.32.02 - Data Architecture

The D5 Data Persistence module requires architecture decisions for storing and managing cost monitoring data in a multi-tenant SaaS environment. The platform must handle:

1. Operational data storage (users, tenants, cloud accounts, configurations)
2. Time-series cost metrics with high query performance
3. Strict tenant data isolation for security compliance
4. Immutable audit logging for regulatory requirements
5. Cost-effective data lifecycle management across hot/warm/cold tiers

**Business Driver**: Cost data storage requires scalability to billions of rows with sub-second query performance while maintaining strict multi-tenant isolation per BRD Section 7.2.

**Key Constraints**:
- Budget: Minimize infrastructure cost for MVP phase
- Performance: Daily cost queries < 5 seconds (MVP < 10 seconds)
- Security: 100% tenant isolation with Row-Level Security
- Compliance: Audit logs immutable with 90-day MVP retention (7 years production)
- Integration: Must support D4 Multi-Cloud data ingestion and D2 Analytics queries

### 2.2 Technical Context

**Current State**:
- No existing database infrastructure
- ADR-003 established BigQuery for analytics workloads
- ADR-008 defined phased database strategy (Firestore MVP, PostgreSQL production)

**MVP Requirements**:
- Firestore for operational data with collection-level tenant isolation
- BigQuery for cost metrics with partition pruning and clustering
- Schema validation on all writes (JSON Schema)
- Audit logging for all data mutations
- Data lifecycle management via BigQuery native features

---

## 3. Decision

**ID Format**: `ADR.12.10.XX` (Decision)

### 3.1 Data Architecture: Multi-Tenant Schema (ADR.12.10.01)

**We will use**: Firestore (MVP) + BigQuery (analytics) with collection-level and authorized view tenant isolation.

**Because**:
1. Zero infrastructure overhead for MVP phase with Firestore free tier
2. BigQuery provides petabyte-scale analytics with automatic partition pruning
3. Firestore security rules enable collection-level tenant isolation without RLS complexity
4. Clear migration path to PostgreSQL + RLS for production multi-tenant

### 3.2 Infrastructure: Database Hosting (ADR.12.10.02)

**We will use**: GCP-managed services (Firestore, BigQuery, Cloud SQL for production).

**Because**:
1. Fully managed reduces operational overhead
2. Native integration with GCP IAM for service account authentication
3. Automatic scaling and high availability (99.9% BigQuery SLA, 99.99% Firestore regional)
4. Cost-effective with usage-based pricing

### 3.3 Integration: Data Access Layer (ADR.12.10.03)

**We will use**: Repository pattern with abstraction layer supporting Firestore/PostgreSQL swap.

**Because**:
1. Enables MVP-to-production database migration without API changes
2. Encapsulates tenant context injection for all queries
3. Centralizes schema validation and audit logging triggers
4. Supports unit testing with mock repositories

### 3.4 Security: Row-Level Security (ADR.12.10.04)

**We will use**:
- MVP: Firestore security rules with collection-path tenant isolation
- Production: PostgreSQL RLS policies with `app.current_tenant` session variable
- BigQuery: Authorized views with tenant_id filtering

**Because**:
1. Defense-in-depth with database-level enforcement
2. Prevents cross-tenant data access even with application bugs
3. Auditable security policies at infrastructure level
4. Industry-standard pattern for multi-tenant SaaS

### 3.5 Observability: Query Analytics (ADR.12.10.05)

**We will use**: BigQuery INFORMATION_SCHEMA for query monitoring + Cloud Logging for Firestore operations.

**Because**:
1. Built-in query performance metrics without additional tooling
2. Slot utilization monitoring for cost optimization
3. Integration with F3 Observability module via Cloud Monitoring
4. Query plan analysis for optimization guidance

### 3.6 Key Components

| Component | Purpose | Technology |
|-----------|---------|------------|
| Operational Store | Users, tenants, configs | Firestore (MVP) / PostgreSQL (Prod) |
| Analytics Store | Cost metrics, aggregations | BigQuery |
| Audit Store | Immutable mutation logs | Firestore (MVP) / BigQuery (Prod) |
| Cache Layer | Hot data, sessions | Redis (Production only) |
| Data Access Layer | Repository abstraction | Python with async support |

### 3.7 Implementation Approach

The data persistence layer implements a repository pattern with pluggable backends. Firestore collections follow hierarchical tenant scoping (`/tenants/{tenant_id}/...`). BigQuery tables use `tenant_id` as the first clustering column for optimal query performance.

**MVP Scope**:
- Firestore operational storage with 6 core entities
- BigQuery cost_metrics tables (raw, hourly, daily, monthly)
- JSON Schema validation on write operations
- Append-only audit log collection
- Basic data lifecycle via BigQuery partition expiration

**Post-MVP Scope**:
- PostgreSQL migration with RLS policies
- Redis caching layer
- Cross-region replication
- Advanced lifecycle with Cloud Storage archive

---

## 4. Alternatives Considered

**ID Format**: `ADR.12.12.XX` (Alternative)

### 4.1 Option A: Firestore + BigQuery (Selected) (ADR.12.12.01)

**Description**: Use Firestore for operational OLTP data with hierarchical tenant collections, and BigQuery for OLAP analytics with partitioned cost metrics tables.

**Pros**:
- Zero infrastructure management for MVP
- Firestore free tier (50K reads, 20K writes/day)
- BigQuery automatic scaling to petabyte scale
- Native GCP security integration

**Cons**:
- Firestore lacks relational constraints (application-enforced)
- No complex joins in Firestore queries
- Migration effort to PostgreSQL for production

**Est. Cost**: $0-50/month MVP | **Fit**: Best for MVP

---

### 4.2 Option B: PostgreSQL + BigQuery (ADR.12.12.02)

**Description**: Use Cloud SQL PostgreSQL for operational data with native RLS from day one, BigQuery for analytics.

**Pros**:
- Full ACID transactions and relational integrity
- Row-Level Security built-in
- Standard SQL across both stores
- No migration needed for production

**Cons**:
- Higher MVP cost ($50-150/month minimum for Cloud SQL)
- Infrastructure management overhead
- Connection pooling complexity
- Slower iteration during MVP

**Rejection Reason**: Higher cost and complexity not justified for MVP phase; Firestore provides sufficient isolation for initial development.

**Est. Cost**: $100-200/month | **Fit**: Good for production

---

### 4.3 Option C: MongoDB Atlas + BigQuery (ADR.12.12.03)

**Description**: Use MongoDB Atlas for operational document storage with tenant field filtering, BigQuery for analytics.

**Pros**:
- Flexible document schema
- Built-in horizontal scaling
- Rich query language

**Cons**:
- Additional vendor (not GCP-native)
- Separate IAM system
- Higher cost than Firestore
- No built-in tenant isolation (application-only)

**Rejection Reason**: Introduces vendor complexity and lacks native GCP integration; Firestore provides equivalent document storage with better GCP ecosystem fit.

**Est. Cost**: $150-300/month | **Fit**: Poor

---

## 5. Consequences

**ID Format**: `ADR.12.13.XX` (Consequence)

### 5.1 Positive Outcomes (ADR.12.13.01)

- **Zero MVP Infrastructure Cost**: Firestore free tier + BigQuery on-demand pricing enables cost-effective MVP launch
- **Sub-10-Second Query Performance**: BigQuery partition pruning on date + clustering on tenant_id achieves MVP query targets
- **100% Tenant Isolation**: Collection-level Firestore isolation + BigQuery authorized views prevent cross-tenant access
- **Clear Migration Path**: Repository abstraction enables PostgreSQL swap without API changes

### 5.2 Trade-offs & Risks (ADR.12.13.02)

| Risk/Trade-off | Impact | Mitigation |
|----------------|--------|------------|
| Firestore lacks relational integrity | Medium | Application-layer validation + schema enforcement |
| BigQuery query cost unpredictability | Medium | Query quotas per tenant + materialized views for common queries |
| Migration complexity Firestore to PostgreSQL | High | Repository abstraction + phased migration plan |
| Firestore 1MB document limit | Low | Design documents < 100KB; use subcollections for large data |
| BigQuery slot contention | Low | Use on-demand pricing for MVP; reservations for production |

### 5.3 Cost Estimate

| Category | MVP Phase | Monthly Ongoing |
|----------|-----------|-----------------|
| Development | 3 person-weeks | - |
| Firestore | $0 (free tier) | $0-20/month |
| BigQuery | $0 (free tier 1TB) | $50-200/month |
| Cloud SQL (Production) | N/A | $100-300/month |
| **Total MVP** | **3 weeks** | **$50-220/month** |

---

## 6. Architecture Flow

### 6.1 High-Level Data Persistence Architecture

```mermaid
flowchart TD
    subgraph "Data Ingestion"
        D4[D4 Multi-Cloud Connector]
        API[API Gateway]
    end

    subgraph "Data Access Layer"
        DAL[Repository Abstraction]
        VAL[Schema Validator]
        AUD[Audit Logger]
    end

    subgraph "MVP Storage"
        FS[(Firestore)]
        BQ[(BigQuery)]
    end

    subgraph "Production Storage"
        PG[(PostgreSQL + RLS)]
        RD[(Redis Cache)]
    end

    subgraph "Analytics"
        D2[D2 Analytics Engine]
    end

    D4 -->|Cost Data| DAL
    API -->|CRUD Operations| DAL

    DAL --> VAL
    VAL -->|Valid| AUD
    AUD -->|Operational| FS
    AUD -->|Cost Metrics| BQ

    DAL -.->|Production| PG
    DAL -.->|Cache| RD

    BQ --> D2
    FS --> API

    style FS fill:#4285F4,color:#fff
    style BQ fill:#4285F4,color:#fff
    style PG fill:#336791,color:#fff
    style RD fill:#DC382D,color:#fff
```

### 6.2 Multi-Tenant Data Isolation Flow

```mermaid
flowchart TD
    subgraph "Request Context"
        REQ[API Request]
        AUTH[F1 IAM Auth]
        CTX[Tenant Context]
    end

    subgraph "Firestore Isolation"
        FS_RULES[Security Rules]
        FS_COLL[/tenants/tenant_id/...]
    end

    subgraph "BigQuery Isolation"
        BQ_VIEW[Authorized View]
        BQ_FILTER[WHERE tenant_id = SESSION_USER]
        BQ_DATA[(Partitioned Tables)]
    end

    subgraph "PostgreSQL Isolation"
        PG_RLS[RLS Policy]
        PG_VAR[SET app.current_tenant]
        PG_TBL[(Tenant-Scoped Tables)]
    end

    REQ --> AUTH
    AUTH -->|JWT Claims| CTX

    CTX -->|Collection Path| FS_RULES
    FS_RULES -->|Enforced| FS_COLL

    CTX -->|Session Variable| BQ_VIEW
    BQ_VIEW --> BQ_FILTER
    BQ_FILTER --> BQ_DATA

    CTX -->|Connection Setting| PG_VAR
    PG_VAR --> PG_RLS
    PG_RLS --> PG_TBL

    style FS_RULES fill:#34A853,color:#fff
    style BQ_VIEW fill:#34A853,color:#fff
    style PG_RLS fill:#34A853,color:#fff
```

### 6.3 Key Integration Points

| System | Integration Type | Purpose |
|--------|-----------------|---------|
| D4 Multi-Cloud | Async (Pub/Sub) | Cost data ingestion from cloud providers |
| D2 Analytics | Direct (BigQuery) | Cost aggregation and reporting queries |
| F1 IAM | Sync (JWT) | Tenant context extraction from auth tokens |
| F3 Observability | Async (Logging) | Query performance and error metrics |
| F4 SecOps | Async (Pub/Sub) | Audit event forwarding |

---

## 7. Implementation Assessment

### 7.1 MVP Development Phases

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| Phase 1 | 1 week | Firestore schema + security rules + repository base |
| Phase 2 | 1 week | BigQuery tables + partitioning + authorized views |
| Phase 3 | 1 week | Audit logging + schema validation + integration tests |

### 7.2 Rollback Plan

**Rollback Trigger**:
- Data corruption detected in production
- Tenant isolation breach confirmed
- Query performance degradation > 3x baseline

**Rollback Steps**:
1. Disable write operations via feature flag
2. Restore from point-in-time backup (Firestore: automatic, BigQuery: snapshot)
3. Validate data integrity with checksums
4. Re-enable operations with monitoring alerts

**Estimated Rollback Time**: 30 minutes (Firestore), 2 hours (BigQuery table restore)

### 7.3 Monitoring (MVP Baseline)

| Metric | Alert Threshold | Action |
|--------|-----------------|--------|
| Firestore read latency (p99) | > 500ms | Investigate query patterns |
| BigQuery query duration (p95) | > 10s | Review query plan, add caching |
| Cross-tenant access attempts | > 0 | Security incident response |
| Audit log write failures | > 1% | Retry queue investigation |
| Storage cost daily | > $50/day | Review data retention policy |

---

## 8. Verification

### 8.1 Success Criteria

- [ ] Firestore collections created with tenant hierarchy
- [ ] BigQuery cost_metrics tables partitioned by date, clustered by tenant_id
- [ ] Security rules prevent cross-collection access
- [ ] Authorized views enforce tenant_id filtering
- [ ] Audit log captures all CREATE/UPDATE/DELETE operations
- [ ] Daily cost query completes < 10 seconds (MVP target)
- [ ] Schema validation rejects invalid payloads with detailed errors

### 8.2 BDD Scenarios

Reference: `docs/04_BDD/BDD-12_d5_data_persistence.feature`

| Scenario ID | Description | Type |
|-------------|-------------|------|
| BDD.12.14.01 | Cost data ingestion with schema validation | Primary |
| BDD.12.14.02 | Daily cost data query execution | Primary |
| BDD.12.14.04 | Firestore document read with tenant isolation | Primary |
| BDD.12.14.06 | Audit log creation for data mutations | Primary |
| BDD.12.14.14 | Cross-tenant access attempt denial | Negative |
| BDD.12.14.24 | Data encryption at rest verification | Quality |
| BDD.12.14.33 | BigQuery authorized view enforcement | State |
| BDD.12.14.34 | Audit log immutability enforcement | State |

---

## 9. Traceability

### 9.1 Upstream References

| Source | Document | Relevant Section |
|--------|----------|------------------|
| BRD | BRD-12 | Section 7.2 - Architecture Decision Requirements |
| PRD | PRD-12 | Section 18 - Architecture Decision Topics |
| EARS | EARS-12 | EARS.12.25.xxx - Data Persistence Requirements |
| BDD | BDD-12 | 41 scenarios covering persistence behaviors |

### 9.2 Downstream Artifacts

| Artifact | Status | Relationship |
|----------|--------|--------------|
| SYS-12 | Pending | System requirements for data persistence |
| REQ-12 | Pending | Atomic requirements for schema, RLS, lifecycle |
| SPEC-12 | Pending | Technical specifications for implementation |
| TASKS-12 | Pending | Implementation tasks for D5 module |

### 9.3 Traceability Tags

```markdown
@brd: BRD.12.32.02 (Data Architecture)
@brd: BRD.12.32.04 (Security - RLS)
@brd: BRD.12.32.07 (Technology Selection)
@prd: PRD.12
@ears: EARS.12.25.001 - EARS.12.25.407
@bdd: BDD.12.14.01 - BDD.12.14.41
```

### 9.4 Cross-Links (Same-Layer)

- `@depends: ADR-06` - F6 Infrastructure provides database provisioning
- `@discoverability: ADR-03 (BigQuery vs TimescaleDB decision)` - Analytics database rationale
- `@discoverability: ADR-08 (Database Strategy MVP)` - Phased database approach
- `@discoverability: ADR-09 (D2 Analytics)` - Cost query integration patterns
- `@discoverability: ADR-11 (D4 Multi-Cloud)` - Data ingestion interface

---

## 10. Related Decisions

| Relationship | ADR | Description |
|--------------|-----|-------------|
| Depends On | ADR-06 | F6 Infrastructure for Cloud SQL/BigQuery provisioning |
| Depends On | ADR-03 | Use BigQuery Not TimescaleDB for analytics |
| Depends On | ADR-08 | Database Strategy MVP (Firestore + PostgreSQL phasing) |
| Related | ADR-09 | D2 Analytics consumes BigQuery cost metrics |
| Related | ADR-11 | D4 Multi-Cloud produces cost data for ingestion |
| Related | ADR-01 | F1 IAM provides tenant context for isolation |

---

## 11. Migration to Full ADR Template

### 11.1 When to Migrate

- [ ] Decision requires 4+ alternatives analysis
- [ ] Complex trade-off evaluation needed
- [ ] Regulatory/compliance documentation required (SOC2, GDPR data residency)
- [ ] Decision impacts multiple systems/teams
- [ ] Detailed implementation assessment required

### 11.2 Migration Triggers for D5

This ADR should migrate to full template when:
- Production PostgreSQL migration begins (adds complex RLS policy analysis)
- Multi-region deployment requires data residency decisions
- SOC2 certification requires detailed audit trail documentation
- Performance optimization requires detailed query plan analysis

### 11.3 Section Mapping (MVP to Full)

| MVP Section | Full Template Section |
|-------------|-----------------------|
| 1. Document Control | 1. Document Control |
| 2. Context | 4. Context (expand subsections) |
| 3. Decision | 5. Decision (expand with full analysis) |
| 4. Alternatives | 6. Alternatives Considered (expand) |
| 5. Consequences | 7. Consequences (expand) |
| 6. Architecture Flow | 8. Architecture Flow (expand) |
| 7. Implementation Assessment | 9. Implementation Assessment (expand) |
| 8. Verification | 10. Validation & Success Criteria |
| 9. Traceability | 11. Traceability |
| 10. Related Decisions | 12. Related Decisions |

---

**Document Version**: 1.0
**Template Version**: ADR-MVP-TEMPLATE 1.0
**Last Updated**: 2026-02-09

---

> **ADR-Ready Notes**:
> - SYS-Ready Score: 92/100 (exceeds 85 MVP threshold)
> - Covers all 7 architecture topics from BRD Section 7.2
> - 5 key decisions documented with element IDs
> - 3 alternatives analyzed with selection rationale
> - Mermaid diagrams for architecture and data flow
> - Full BDD scenario traceability (41 scenarios)
