---
title: "BRD-12: D5 Data Persistence & Storage"
tags:
  - brd
  - domain-module
  - d5-data
  - layer-1-artifact
  - cost-monitoring-specific
custom_fields:
  document_type: brd
  artifact_type: BRD
  layer: 1
  module_id: D5
  module_name: Data Persistence & Storage
  descriptive_slug: d5_data_persistence
  architecture_approaches: [ai-agent-based]
  priority: primary
  development_status: draft
  schema_reference: "BRD_MVP_SCHEMA.yaml"
  schema_version: "1.0"
  template_profile: mvp
---

# BRD-12: D5 Data Persistence & Storage

> **Module Type**: Domain (Cost Monitoring-Specific)
> **Scope**: Database schema, Row-Level Security, data partitioning, audit logging, data lifecycle

---

## 0. Document Control

| Item | Details |
|------|---------|
| **Project Name** | AI Cost Monitoring Platform v4.2 - D5 Data Persistence |
| **Document Version** | 1.0.1 |
| **Date** | 2026-02-11T12:30:00 |
| **Document Owner** | Chief Architect |
| **Prepared By** | Antigravity AI |
| **Status** | Draft |
| **MVP Target Launch** | Phase 1 |
| **PRD-Ready Score** | 92/100 (Target: >=90/100) |

### Executive Summary (MVP)

The D5 Data Persistence Module defines the database architecture for the AI Cost Monitoring Platform. MVP uses Firestore for operational data and BigQuery for cost analytics (per ADR-008). Production upgrades to PostgreSQL with Row-Level Security for multi-tenant isolation. This module covers schema design, tenant isolation patterns, data partitioning strategies, audit logging requirements, and data lifecycle management.

@ref: [Database Schema Specification](../../00_REF/domain/01-database-schema.md)
@ref: [ADR-008: Database Strategy](../../00_REF/domain/architecture/adr/008-database-strategy-mvp.md)

### Document Revision History

| Version | Date | Author | Changes Made | Approver |
|---------|------|--------|--------------|----------|
| 1.0.1 | 2026-02-11T12:30:00 | doc-brd-fixer | Fixed 5 broken links (nested folder path correction) | |
| 1.0 | 2026-02-08T00:00:00 | Antigravity AI | Initial BRD creation from database schema spec | |

---

## 1. Introduction

### 1.1 Purpose

This Business Requirements Document (BRD) defines the data persistence requirements for the platform, including database selection, schema design, multi-tenant isolation, and data lifecycle management.

### 1.2 Document Scope

This document covers:
- Database technology selection (MVP vs Production)
- Core entity schemas (users, tenants, cloud_accounts, resources)
- Cost metrics storage in BigQuery
- Row-Level Security for multi-tenant isolation
- Data partitioning and indexing strategies
- Audit logging and compliance
- Data retention and lifecycle management

**Out of Scope**:
- Application logic (covered by D1, D2)
- API endpoints (covered by D6)
- Infrastructure provisioning (covered by F6)

### 1.3 Intended Audience

- Database engineers (schema implementation)
- Backend developers (data access patterns)
- Security engineers (RLS policy review)
- DevOps engineers (database deployment)

### 1.4 References

| Document | Location | Purpose |
|----------|----------|---------|
| Database Schema Spec | [01-database-schema.md](../../00_REF/domain/01-database-schema.md) | Detailed schema definitions |
| ADR-008 | [008-database-strategy-mvp.md](../../00_REF/domain/architecture/adr/008-database-strategy-mvp.md) | Database strategy decision |
| ADR-003 | [003-use-bigquery-not-timescaledb.md](../../00_REF/domain/architecture/adr/003-use-bigquery-not-timescaledb.md) | Analytics database decision |

---

## 2. Business Context

### 2.1 Problem Statement

A multi-tenant cost monitoring platform requires:
- Strict tenant data isolation
- High-performance cost queries across large datasets
- Immutable audit trails for compliance
- Flexible schema for multi-cloud data normalization
- Cost-effective storage with appropriate retention

### 2.2 Success Criteria

| Criterion | Target | MVP Target |
|-----------|--------|------------|
| Tenant isolation | 100% RLS coverage | Firestore collections |
| Query performance | <5 seconds | <10 seconds |
| Audit log retention | 7 years | 90 days |
| Data freshness | 4 hours | 4 hours |

---

## 3. Business Requirements

### 3.1 Database Technology Selection

**Business Capability**: Use appropriate database technology per deployment phase.

| Deployment | Operational DB | Analytics DB | Rationale |
|------------|----------------|--------------|-----------|
| **MVP (Single-Tenant)** | Firestore | BigQuery | Zero infrastructure, free tier |
| **Production (Multi-Tenant)** | PostgreSQL 16 + RLS | BigQuery | Enterprise isolation, ACID |

**Business Acceptance Criteria**:

| Criteria ID | Criterion | MVP Target |
|-------------|-----------|------------|
| BRD.12.01.01 | Operational database | Firestore |
| BRD.12.01.02 | Analytics database | BigQuery |
| BRD.12.01.03 | Migration path documented | Yes |

### 3.2 Core Entity Schema

**Business Capability**: Store operational data for users, tenants, and cloud accounts.

**Core Entities**:

| Entity | Purpose | Key Fields | MVP Storage |
|--------|---------|------------|-------------|
| **tenants** | Customer organizations | id, name, plan, status | Firestore |
| **users** | Platform users | id, tenant_id, email, role | Firestore |
| **cloud_accounts** | Connected cloud accounts | id, tenant_id, provider, credentials_ref | Firestore |
| **resources** | Discovered cloud resources | id, account_id, resource_type, tags | Firestore |
| **recommendations** | Optimization suggestions | id, tenant_id, type, impact, status | Firestore |
| **policies** | Cost policies and budgets | id, tenant_id, type, thresholds | Firestore |

**Business Acceptance Criteria**:

| Criteria ID | Criterion | MVP Target |
|-------------|-----------|------------|
| BRD.12.02.01 | Core entities supported | 6 entities |
| BRD.12.02.02 | Schema validation | JSON Schema |
| BRD.12.02.03 | Referential integrity | Application-enforced |

### 3.3 Cost Metrics Storage (BigQuery)

**Business Capability**: Store and query time-series cost data efficiently.

**Cost Metrics Schema**:

| Table | Granularity | Partition | Retention | Purpose |
|-------|-------------|-----------|-----------|---------|
| `cost_metrics_raw` | Event | Day | 7 days | Raw billing events |
| `cost_metrics_hourly` | Hourly | Day | 30 days | Hourly aggregates |
| `cost_metrics_daily` | Daily | Month | 2 years | Daily summaries |
| `cost_metrics_monthly` | Monthly | Year | 7 years | Monthly reports |

**Key Fields**:

```sql
-- BigQuery cost metrics schema
tenant_id STRING NOT NULL,
account_id STRING NOT NULL,
date DATE NOT NULL,
provider STRING NOT NULL,  -- gcp, aws, azure, kubernetes
service STRING NOT NULL,
region STRING,
cost NUMERIC(15,4) NOT NULL,
usage_quantity NUMERIC(15,4),
usage_unit STRING,
tags JSON,
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
```

**Business Acceptance Criteria**:

| Criteria ID | Criterion | MVP Target |
|-------------|-----------|------------|
| BRD.12.03.01 | Daily cost query | <5 seconds |
| BRD.12.03.02 | Monthly aggregation | <10 seconds |
| BRD.12.03.03 | Storage cost | <$0.50/tenant/month |

### 3.4 Row-Level Security (Production)

**Business Capability**: Enforce tenant data isolation at the database level.

**RLS Implementation (PostgreSQL)**:

```sql
-- Enable RLS on all tenant-scoped tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE cloud_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE resources ENABLE ROW LEVEL SECURITY;
ALTER TABLE recommendations ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only access their tenant's data
CREATE POLICY tenant_isolation ON users
  FOR ALL
  USING (tenant_id = current_setting('app.current_tenant')::uuid);

-- Set tenant context on each connection
SET app.current_tenant = '{tenant_id}';
```

**BigQuery Authorized Views**:

```sql
-- Authorized view for tenant-scoped cost data
CREATE VIEW tenant_costs AS
SELECT * FROM cost_metrics_daily
WHERE tenant_id = SESSION_USER();
```

**Business Acceptance Criteria**:

| Criteria ID | Criterion | Target |
|-------------|-----------|--------|
| BRD.12.04.01 | RLS on all tenant tables | 100% |
| BRD.12.04.02 | Cross-tenant access prevention | Verified by tests |
| BRD.12.04.03 | BigQuery authorized views | Per-tenant |

### 3.5 Data Partitioning Strategy

**Business Capability**: Optimize query performance and manage storage costs.

**Partitioning Rules**:

| Table | Partition Key | Partition Type | Cluster Key |
|-------|---------------|----------------|-------------|
| cost_metrics_daily | date | DATE (Monthly) | tenant_id, provider, service |
| cost_metrics_hourly | date | DATE (Daily) | tenant_id, provider |
| audit_log | timestamp | DATE (Monthly) | tenant_id, action |

**Indexing Strategy (PostgreSQL)**:

| Table | Index | Type | Purpose |
|-------|-------|------|---------|
| users | (tenant_id, email) | B-tree | User lookup |
| cloud_accounts | (tenant_id, provider) | B-tree | Account queries |
| resources | (account_id, resource_type) | B-tree | Resource discovery |
| resources | tags | GIN (JSONB) | Tag-based queries |

**Business Acceptance Criteria**:

| Criteria ID | Criterion | MVP Target |
|-------------|-----------|------------|
| BRD.12.05.01 | Partition pruning | Automatic |
| BRD.12.05.02 | Index coverage | Key queries |
| BRD.12.05.03 | Query explain analysis | Documented |

### 3.6 Audit Logging

**Business Capability**: Maintain immutable audit trail for compliance.

**Audit Log Schema**:

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Primary key |
| tenant_id | UUID | Tenant scope |
| user_id | UUID | Acting user |
| action | String | Action performed |
| resource_type | String | Affected resource type |
| resource_id | UUID | Affected resource |
| old_value | JSON | Previous state |
| new_value | JSON | New state |
| ip_address | String | Client IP |
| user_agent | String | Client identifier |
| timestamp | Timestamp | Event time |

**Immutability Constraints**:

- No UPDATE allowed on audit_log table
- No DELETE allowed on audit_log table
- Append-only with cryptographic hash chain (optional)

**Business Acceptance Criteria**:

| Criteria ID | Criterion | MVP Target |
|-------------|-----------|------------|
| BRD.12.06.01 | All mutations logged | 100% |
| BRD.12.06.02 | Log immutability | Enforced |
| BRD.12.06.03 | Retention period | 90 days (MVP), 7 years (Prod) |

### 3.7 Data Lifecycle Management

**Business Capability**: Manage data retention and archival automatically.

**Retention Policy**:

| Data Type | Hot (Online) | Warm (Archive) | Cold (Compliance) | Delete |
|-----------|--------------|----------------|-------------------|--------|
| cost_metrics_hourly | 30 days | - | - | 30 days |
| cost_metrics_daily | 90 days | 2 years | - | 2 years |
| cost_metrics_monthly | 2 years | 5 years | 7 years | 7 years |
| audit_log | 90 days | 1 year | 7 years | 7 years |
| recommendations | 30 days | - | - | 30 days |

**Lifecycle Actions**:

| Transition | Trigger | Action |
|------------|---------|--------|
| Hot → Warm | Age > threshold | Move to archive storage |
| Warm → Cold | Age > threshold | Compress, move to cold storage |
| Cold → Delete | Age > retention | Permanent deletion |

**Business Acceptance Criteria**:

| Criteria ID | Criterion | MVP Target |
|-------------|-----------|------------|
| BRD.12.07.01 | Automatic lifecycle | BigQuery native |
| BRD.12.07.02 | Storage cost optimization | Tiered pricing |
| BRD.12.07.03 | Compliance retention | Configurable |

---

## 4. Technology Stack

| Component | MVP | Production | Reference |
|-----------|-----|------------|-----------|
| Operational DB | Firestore | PostgreSQL 16 | ADR-008 |
| Analytics DB | BigQuery | BigQuery | ADR-003 |
| Caching | None | Redis | Optional |
| Audit Storage | Firestore | PostgreSQL + Archive | F4 SecOps |

---

## 5. Dependencies

### 5.1 Foundation Module Dependencies

| Module | Dependency | Purpose |
|--------|------------|---------|
| F4 SecOps | Audit logging | Compliance integration |
| F6 Infrastructure | Database provisioning | Cloud SQL, BigQuery |
| F7 Config | Connection settings | Database credentials |

### 5.2 Domain Module Dependencies

| Module | Dependency | Purpose |
|--------|------------|---------|
| D1 Agents | Data access | Agent queries |
| D2 Analytics | Cost metrics | BigQuery queries |
| D4 Multi-Cloud | Data ingestion | Cost data storage |

---

## 6. Risks and Mitigations

| Risk ID | Risk Description | Likelihood | Impact | Mitigation Strategy |
|---------|------------------|------------|--------|---------------------|
| BRD.12.R01 | RLS performance overhead | Medium | Medium | Query optimization, connection pooling |
| BRD.12.R02 | BigQuery cost overrun | Low | Medium | Query quotas, caching |
| BRD.12.R03 | Migration complexity | Medium | High | Abstraction layer, phased migration |
| BRD.12.R04 | Data corruption | Low | Critical | Backups, point-in-time recovery |

---

## 7. Traceability

### 7.1 Upstream Dependencies
- Domain specification: 01-database-schema.md
- Architecture decisions: ADR-003, ADR-008

### 7.2 Architecture Decision Requirements

#### 7.2.1 Infrastructure (BRD.12.32.01)

**Status**: N/A - Handled by F6 Infrastructure

**PRD Requirements**: None for this module (see BRD-06)

---

#### 7.2.2 Data Architecture (BRD.12.32.02)

**Status**: Selected

**Business Driver**: Cost data storage, multi-tenant isolation

**Business Constraints**: Scalable to billions of rows, sub-second queries

**Alternatives Overview**:
| Option | Function | Est. Monthly Cost | Selection Rationale |
|--------|----------|-------------------|---------------------|
| BigQuery | OLAP, analytics | $100-500 | Pay-per-query, scalable |
| PostgreSQL | OLTP, metadata | $50-150 | Transactional data |
| Redis | Caching | $50-100 | Session, hot data |

**Cloud Provider Comparison**:
| Criterion | GCP | Azure | AWS |
|-----------|-----|-------|-----|
| Analytics DB | BigQuery | Synapse | Redshift |
| Relational | Cloud SQL | Azure SQL | RDS |
| Caching | Memorystore | Azure Cache | ElastiCache |

**Recommended Selection**: BigQuery (analytics) + Cloud SQL PostgreSQL (metadata) + Redis (caching)

**PRD Requirements**: Schema design, partition strategy, RLS implementation

---

#### 7.2.3 Integration (BRD.12.32.03)

**Status**: N/A - Data from D4 Multi-Cloud connectors

**PRD Requirements**: None for this module (see BRD-11)

---

#### 7.2.4 Security (BRD.12.32.04)

**Status**: Selected

**Business Driver**: Multi-tenant data isolation

**Recommended Selection**: Row-Level Security (RLS) in BigQuery and PostgreSQL

**PRD Requirements**: RLS policy design, tenant isolation verification

---

#### 7.2.5 Observability (BRD.12.32.05)

**Status**: N/A - Handled by F3 Observability

**PRD Requirements**: None for this module (see BRD-03)

---

#### 7.2.6 AI/ML (BRD.12.32.06)

**Status**: N/A - No ML in this module

**PRD Requirements**: None for current scope

---

#### 7.2.7 Technology Selection (BRD.12.32.07)

**Status**: Selected

**Business Driver**: Database technology stack

**Recommended Selection**: BigQuery + Cloud SQL PostgreSQL (per ADR-003)

**PRD Requirements**: Database provisioning, backup strategy

---

### 7.3 Downstream Artifacts
- PRD: Data persistence features (pending)
- SPEC: Schema implementation (pending)
- TASKS: Database setup tasks (pending)

### 7.4 Cross-References

| Related BRD | Relationship | Integration Point |
|-------------|--------------|-------------------|
| BRD-01 (F1 IAM) | Upstream | User authentication data |
| BRD-04 (F4 SecOps) | Peer | Audit logging |
| BRD-06 (F6 Infrastructure) | Upstream | Database provisioning |
| BRD-09 (D2 Analytics) | Downstream | Cost metrics queries |
| BRD-11 (D4 Multi-Cloud) | Upstream | Data ingestion |

---

## 8. Appendices

### Appendix A: Firestore Collection Structure (MVP)

```
/tenants/{tenant_id}
  /users/{user_id}
  /cloud_accounts/{account_id}
  /resources/{resource_id}
  /recommendations/{rec_id}
  /policies/{policy_id}
  /audit_log/{log_id}
```

### Appendix B: PostgreSQL Migration Checklist

| Step | Description | Estimated Effort |
|------|-------------|------------------|
| 1 | Create PostgreSQL schema | 2 hours |
| 2 | Enable RLS on all tables | 1 hour |
| 3 | Create RLS policies | 2 hours |
| 4 | Update connection pooling | 1 hour |
| 5 | Migrate data from Firestore | 4 hours |
| 6 | Validate tenant isolation | 2 hours |
| 7 | Performance testing | 4 hours |
| **Total** | | **2-4 days** |

### Appendix C: BigQuery Cost Optimization

| Optimization | Savings | Implementation |
|--------------|---------|----------------|
| Partition pruning | 60-80% | DATE partitioning |
| Clustering | 30-50% | tenant_id, provider |
| Materialized views | 40-60% | Pre-aggregated summaries |
| Slot reservations | 20-40% | For high-volume tenants |

---

**Document Status**: Draft
**Next Review**: Upon PRD creation
