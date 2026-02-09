---
title: "PRD-12: D5 Data Persistence & Storage"
tags:
  - prd
  - domain-module
  - d5-data
  - layer-2-artifact
  - database
custom_fields:
  document_type: prd
  artifact_type: PRD
  layer: 2
  module_id: D5
  module_name: Data Persistence & Storage
  architecture_approaches: [ai-agent-based]
  priority: primary
  development_status: draft
  schema_version: "1.0"
---

# PRD-12: D5 Data Persistence & Storage

> **Module Type**: Domain (Cost Monitoring-Specific)
> **Scope**: Database schema, Row-Level Security, data partitioning, audit logging

@brd: BRD-12
@depends: PRD-06 (F6 Infrastructure - Cloud SQL, BigQuery); PRD-04 (F4 SecOps - audit)
@discoverability: PRD-09 (D2 Analytics - BigQuery queries); PRD-11 (D4 Multi-Cloud - data ingestion)

---

## 1. Document Control

| Item | Details |
|------|---------|
| **Status** | Draft |
| **Version** | 1.0 |
| **Date Created** | 2026-02-09 |
| **Last Updated** | 2026-02-09 |
| **Author** | Antigravity AI |
| **BRD Reference** | @brd: BRD-12 |
| **Priority** | P1 - Critical |
| **Target Release** | Phase 1 MVP |
| **EARS-Ready Score** | 90/100 |

---

## 2. Executive Summary

The D5 Data Persistence Module defines the database architecture for the platform. MVP uses Firestore for operational data and BigQuery for cost analytics. Production upgrades to PostgreSQL with Row-Level Security for multi-tenant isolation. This module covers schema design, tenant isolation patterns, data partitioning, and data lifecycle management.

### 2.1 MVP Hypothesis

**We believe that** multi-tenant isolation and performant analytics **will** enable secure, scalable cost monitoring **if we** implement RLS and partitioned BigQuery storage.

---

## 3. Core User Stories

| ID | User Story | Priority | Acceptance Criteria |
|----|------------|----------|---------------------|
| PRD.12.09.01 | As a tenant, I want my data isolated | P1 | 100% RLS/Firestore rules coverage |
| PRD.12.09.02 | As a FinOps user, I want fast cost queries | P1 | <5 second daily queries |
| PRD.12.09.03 | As an admin, I want audit trail | P1 | 100% mutations logged |
| PRD.12.09.04 | As compliance officer, I want 7-year retention | P2 | Tiered storage lifecycle |

---

## 4. Functional Requirements

### 4.1 Database Technology

| Deployment | Operational DB | Analytics DB |
|------------|----------------|--------------|
| MVP (Single-Tenant) | Firestore | BigQuery |
| Production (Multi-Tenant) | PostgreSQL 16 + RLS | BigQuery |

### 4.2 Core Entity Schema

| Entity | Purpose | MVP Storage |
|--------|---------|-------------|
| tenants | Customer organizations | Firestore |
| users | Platform users | Firestore |
| cloud_accounts | Connected accounts | Firestore |
| resources | Discovered resources | Firestore |
| recommendations | Optimization suggestions | Firestore |

### 4.3 Cost Metrics Storage (BigQuery)

| Table | Granularity | Partition | Retention |
|-------|-------------|-----------|-----------|
| cost_metrics_hourly | Hourly | Day | 30 days |
| cost_metrics_daily | Daily | Month | 2 years |
| cost_metrics_monthly | Monthly | Year | 7 years |

### 4.4 Row-Level Security (Production)

```sql
CREATE POLICY tenant_isolation ON users
  FOR ALL
  USING (tenant_id = current_setting('app.current_tenant')::uuid);
```

---

## 5. Architecture Requirements

### 5.1 Data Architecture (PRD.12.32.02)

**Status**: [X] Selected

**MVP Selection**: BigQuery (analytics) + Firestore (operational)

**Production Selection**: BigQuery + PostgreSQL + Redis

---

## 6. Quality Attributes

| Metric | Target | MVP Target |
|--------|--------|------------|
| Tenant isolation | 100% RLS | Firestore rules |
| Query performance | <5 seconds | <10 seconds |
| Audit log retention | 7 years | 90 days |

---

## 7. Traceability

| Related PRD | Relationship | Integration Point |
|-------------|--------------|-------------------|
| PRD-04 (F4 SecOps) | Peer | Audit logging |
| PRD-06 (F6 Infrastructure) | Upstream | Database provisioning |
| PRD-09 (D2 Analytics) | Downstream | Cost metrics queries |
| PRD-11 (D4 Multi-Cloud) | Upstream | Data ingestion |

---

*PRD-12: D5 Data Persistence & Storage - AI Cost Monitoring Platform v4.2*
*Generated: 2026-02-09 | EARS-Ready Score: 90/100*
