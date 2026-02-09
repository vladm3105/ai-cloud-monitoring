---
title: "BRD-11: D4 Multi-Cloud Integration"
tags:
  - brd
  - domain-module
  - d4-multicloud
  - layer-1-artifact
  - cost-monitoring-specific
custom_fields:
  document_type: brd
  artifact_type: BRD
  layer: 1
  module_id: D4
  module_name: Multi-Cloud Integration
  descriptive_slug: d4_multi_cloud
  architecture_approaches: [ai-agent-based]
  priority: primary
  development_status: draft
  schema_reference: "BRD_MVP_SCHEMA.yaml"
  schema_version: "1.0"
  template_profile: mvp
---

# BRD-11: D4 Multi-Cloud Integration

> **Module Type**: Domain (Cost Monitoring-Specific)
> **Scope**: GCP, AWS, Azure, Kubernetes cloud connectors

---

## 0. Document Control

| Item | Details |
|------|---------|
| **Project Name** | AI Cost Monitoring Platform v4.2 - D4 Multi-Cloud Integration |
| **Document Version** | 1.0 |
| **Date** | 2026-02-08 |
| **Document Owner** | Chief Architect |
| **Prepared By** | Antigravity AI |
| **Status** | Draft |
| **MVP Target Launch** | Phase 1 (GCP) / Phase 2 (AWS, Azure, K8s) |
| **PRD-Ready Score** | 92/100 (Target: >=90/100) |

### Executive Summary (MVP)

The D4 Multi-Cloud Integration Module provides the connectors and abstraction layer for accessing cost and resource data from multiple cloud providers. MVP focuses on GCP integration using native BigQuery billing export. Phase 2 adds AWS (Cost and Usage Report), Azure (Cost Management API), and Kubernetes (OpenCost). The module implements a uniform data model that normalizes provider-specific schemas into a consistent format for analysis.

### Document Revision History

| Version | Date | Author | Changes Made | Approver |
|---------|------|--------|--------------|----------|
| 1.0 | 2026-02-08 | Antigravity AI | Initial BRD creation from domain specs | |

---

## 1. Introduction

### 1.1 Purpose

This Business Requirements Document (BRD) defines the business requirements for the D4 Multi-Cloud Integration Module. This module handles cloud provider connections, credential management, data ingestion, and cross-provider data normalization.

@ref: [Tenant Onboarding Specification](../00_REF/domain/04-tenant-onboarding.md)
@ref: [Deployment Infrastructure](../00_REF/domain/07-deployment-infrastructure.md)
@ref: [ADR-002: GCP-Only First](../00_REF/domain/architecture/adr/002-gcp-only-first.md)

### 1.2 Document Scope

This document covers:
- Cloud provider connection workflows (GCP, AWS, Azure, K8s)
- Credential storage and rotation
- Data ingestion pipelines
- Cost data normalization
- Multi-cloud aggregation

**Out of Scope**:
- Foundation module capabilities (F1-F7)
- Agent orchestration (covered by D1)
- Analytics and recommendations (covered by D2)

### 1.3 Intended Audience

- Backend developers (connector implementation)
- DevOps engineers (credential management, pipeline deployment)
- Security engineers (credential security review)
- Cloud architects (multi-cloud strategy)

### 1.4 References

| Document | Location | Purpose |
|----------|----------|---------|
| Tenant Onboarding | [04-tenant-onboarding.md](../00_REF/domain/04-tenant-onboarding.md) | Connection flows |
| Deployment Infrastructure | [07-deployment-infrastructure.md](../00_REF/domain/07-deployment-infrastructure.md) | Infrastructure patterns |
| ADR-002 | [002-gcp-only-first.md](../00_REF/domain/architecture/adr/002-gcp-only-first.md) | GCP-first decision |
| MCP Tool Contracts | [02-mcp-tool-contracts.md](../00_REF/domain/02-mcp-tool-contracts.md) | Cloud API interfaces |

---

## 2. Business Context

### 2.1 Problem Statement

Organizations use multiple cloud providers, each with:
- Different billing APIs and data formats
- Unique authentication mechanisms
- Varying data freshness and granularity
- Incompatible cost categorization

This fragmentation prevents unified cost visibility and optimization.

### 2.2 Business Opportunity

| Opportunity | Impact | Measurement |
|-------------|--------|-------------|
| Unified visibility | Single pane of glass | Time to generate cross-cloud report |
| Simplified onboarding | Self-service connection | Time to connect first account |
| Secure credential handling | Zero credential exposure | Security audit findings |
| Real-time data access | Near-instant insights | Data freshness lag |

### 2.3 Success Criteria

| Criterion | Target | MVP Target |
|-----------|--------|------------|
| Connection success rate | >99% | >95% |
| Data freshness | 4 hours | 4 hours |
| Supported providers | 4 | 1 (GCP) |
| Credential rotation | Automatic | Manual |

---

## 3. Business Requirements

### 3.1 GCP Integration (MVP)

**Business Capability**: Connect to GCP projects and ingest billing data via BigQuery export.

**Connection Flow**:
1. User creates Service Account with Viewer + Billing Account Viewer roles
2. User uploads Service Account JSON key
3. Platform stores key in GCP Secret Manager
4. Platform validates access by listing projects
5. Platform configures BigQuery billing export query

**Data Sources**:

| Source | Data Type | Refresh Rate |
|--------|-----------|--------------|
| BigQuery Billing Export | Cost details | Near real-time |
| Cloud Asset Inventory | Resource metadata | Hourly |
| Recommender API | Optimization suggestions | Daily |

**Business Acceptance Criteria**:

| Criteria ID | Criterion | MVP Target |
|-------------|-----------|------------|
| BRD.11.01.01 | Connection time | <2 minutes |
| BRD.11.01.02 | Data validation | Schema check |
| BRD.11.01.03 | Permission verification | Automatic |

### 3.2 AWS Integration (Phase 2)

**Business Capability**: Connect to AWS accounts using IAM Role assumption.

**Connection Flow**:
1. User deploys CloudFormation template (creates IAM Role)
2. User provides Role ARN and External ID
3. Platform stores credentials in Secret Manager
4. Platform validates via AssumeRole + GetCallerIdentity
5. Platform configures CUR data access

**Data Sources**:

| Source | Data Type | Refresh Rate |
|--------|-----------|--------------|
| Cost and Usage Report (CUR) | Cost details | Daily |
| Cost Explorer API | Summary data | Real-time |
| Compute Optimizer | Recommendations | Daily |

**Business Acceptance Criteria**:

| Criteria ID | Criterion | Target |
|-------------|-----------|--------|
| BRD.11.02.01 | Cross-account role setup | Guided wizard |
| BRD.11.02.02 | CUR data ingestion | <24 hours |
| BRD.11.02.03 | Cost Explorer queries | Per-request |

### 3.3 Azure Integration (Phase 2)

**Business Capability**: Connect to Azure subscriptions using Service Principal.

**Connection Flow**:
1. User creates App Registration with Reader + Cost Management Reader roles
2. User provides Client ID, Client Secret, Tenant ID, Subscription ID
3. Platform stores credentials in Secret Manager
4. Platform validates via authentication + subscription list
5. Platform configures Cost Management export

**Data Sources**:

| Source | Data Type | Refresh Rate |
|--------|-----------|--------------|
| Cost Management Export | Cost details | Daily |
| Cost Management API | Summary data | Real-time |
| Advisor API | Recommendations | Daily |

**Business Acceptance Criteria**:

| Criteria ID | Criterion | Target |
|-------------|-----------|--------|
| BRD.11.03.01 | Service Principal setup | Documented |
| BRD.11.03.02 | Export configuration | Automatic |
| BRD.11.03.03 | API rate handling | Throttling aware |

### 3.4 Kubernetes Integration (Phase 2)

**Business Capability**: Connect to Kubernetes clusters using OpenCost.

**Connection Flow**:
1. User provides cluster API endpoint + kubeconfig/token
2. Platform verifies OpenCost is installed
3. Platform stores credentials in Secret Manager
4. Platform tests namespace listing + OpenCost endpoint
5. Platform configures cost allocation queries

**Data Sources**:

| Source | Data Type | Refresh Rate |
|--------|-----------|--------------|
| OpenCost API | Pod/namespace costs | Hourly |
| Kubernetes API | Resource metadata | Real-time |

**Business Acceptance Criteria**:

| Criteria ID | Criterion | Target |
|-------------|-----------|--------|
| BRD.11.04.01 | OpenCost version support | 1.0+ |
| BRD.11.04.02 | Cost allocation accuracy | ±5% |
| BRD.11.04.03 | Multi-cluster support | Yes |

### 3.5 Data Normalization

**Business Capability**: Transform provider-specific data into unified schema.

**Normalized Schema**:

| Field | Description | Source Mapping |
|-------|-------------|----------------|
| tenant_id | Customer identifier | Platform |
| account_id | Cloud account reference | Provider account/project/subscription |
| provider | Cloud provider enum | gcp, aws, azure, kubernetes |
| date | Cost date | Billing period |
| service | Service name | Normalized service taxonomy |
| region | Geographic region | Normalized region code |
| cost | Cost amount (USD) | Converted to USD |
| usage_quantity | Resource usage | Provider units |
| tags | Resource tags | Key-value pairs |

**Business Acceptance Criteria**:

| Criteria ID | Criterion | MVP Target |
|-------------|-----------|------------|
| BRD.11.05.01 | Schema compliance | 100% |
| BRD.11.05.02 | Currency conversion | Daily rates |
| BRD.11.05.03 | Service mapping | 50 services |

### 3.6 Credential Management

**Business Capability**: Securely store and manage cloud credentials.

**Security Requirements**:

| Requirement | Implementation | Verification |
|-------------|----------------|--------------|
| Encryption at rest | GCP Secret Manager | Automatic |
| Access control | IAM-based | Per-tenant isolation |
| Rotation support | Manual (MVP) / Auto (Prod) | Rotation alerts |
| Audit logging | All access logged | F4 SecOps |

**Business Acceptance Criteria**:

| Criteria ID | Criterion | MVP Target |
|-------------|-----------|------------|
| BRD.11.06.01 | Credential isolation | Per-tenant secrets |
| BRD.11.06.02 | Access logging | 100% |
| BRD.11.06.03 | Rotation reminders | 90-day alert |

---

## 4. Technology Stack

| Component | Technology | Reference |
|-----------|------------|-----------|
| Credential Storage | GCP Secret Manager | ADR-008 |
| Data Pipeline | Cloud Functions + Scheduler | ADR-006 |
| Billing Data | BigQuery | ADR-003 |
| Container Platform | Cloud Run | ADR-004 |

---

## 5. Dependencies

### 5.1 Foundation Module Dependencies

| Module | Dependency | Purpose |
|--------|------------|---------|
| F1 IAM | Authorization | Multi-tenant access control |
| F4 SecOps | Audit | Credential access logging |
| F6 Infrastructure | Cloud Resources | Pipeline deployment |
| F7 Config | Settings | Provider configurations |

### 5.2 External Dependencies

| Dependency | Purpose | Risk Mitigation |
|------------|---------|-----------------|
| Cloud Provider APIs | Cost data retrieval | Rate limiting, caching |
| Secret Manager | Credential storage | Multi-region backup |
| OpenCost | Kubernetes costs | Version compatibility |

---

## 6. Risks and Mitigations

| Risk ID | Risk Description | Likelihood | Impact | Mitigation Strategy |
|---------|------------------|------------|--------|---------------------|
| BRD.11.R01 | API rate limits | High | Medium | Request batching, caching |
| BRD.11.R02 | Credential expiration | Medium | High | Rotation monitoring, alerts |
| BRD.11.R03 | Data format changes | Low | Medium | Schema versioning, alerts |
| BRD.11.R04 | Multi-cloud complexity | Medium | Medium | Phased rollout (GCP first) |

---

## 7. Traceability

### 7.1 Upstream Dependencies
- Business stakeholder requirements
- Domain specifications (04, 07)
- Architecture decisions (ADR-002)

### 7.2 Architecture Decision Requirements

#### 7.2.1 Infrastructure (BRD.11.32.01)

**Status**: N/A - Handled by F6 Infrastructure

**PRD Requirements**: None for this module (see BRD-06)

---

#### 7.2.2 Data Architecture (BRD.11.32.02)

**Status**: Selected

**Business Driver**: Multi-cloud billing data normalization

**Business Constraints**: Must support 4 cloud providers + Kubernetes

**Recommended Selection**: Unified schema in BigQuery with provider-specific ETL

**PRD Requirements**: Normalized schema design, service taxonomy mapping

---

#### 7.2.3 Integration (BRD.11.32.03)

**Status**: Selected

**Business Driver**: Cloud provider API integration

**Alternatives Overview**:
| Option | Function | Est. Monthly Cost | Selection Rationale |
|--------|----------|-------------------|---------------------|
| Native APIs | Direct integration | $0 | Full control |
| Cloud SDK | Abstraction layer | $0 | Easier maintenance |
| Third-party tools | Aggregated data | $100-500 | Pre-built connectors |

**Recommended Selection**: Native cloud billing APIs + BigQuery exports

**PRD Requirements**: Connector specifications, credential requirements

---

#### 7.2.4 Security (BRD.11.32.04)

**Status**: Selected

**Business Driver**: Multi-tenant credential isolation

**Recommended Selection**: GCP Secret Manager with per-tenant secrets

**PRD Requirements**: Credential storage design, rotation policy

---

#### 7.2.5 Observability (BRD.11.32.05)

**Status**: N/A - Handled by F3 Observability

**PRD Requirements**: None for this module (see BRD-03)

---

#### 7.2.6 AI/ML (BRD.11.32.06)

**Status**: N/A - No ML in this module

**PRD Requirements**: None for current scope

---

#### 7.2.7 Technology Selection (BRD.11.32.07)

**Status**: Selected

**Business Driver**: Data pipeline technology

**Recommended Selection**: Cloud Functions + Cloud Scheduler (per ADR-006)

**PRD Requirements**: Pipeline specifications, refresh schedules

---

### 7.3 Downstream Artifacts
- PRD: Multi-cloud feature specifications (pending)
- SPEC: Implementation specifications (pending)
- TASKS: Implementation tasks (pending)

### 7.4 Cross-References

| Related BRD | Relationship | Integration Point |
|-------------|--------------|-------------------|
| BRD-01 (F1 IAM) | Upstream | Tenant authorization |
| BRD-04 (F4 SecOps) | Upstream | Credential audit |
| BRD-07 (F7 Config) | Upstream | Provider settings |
| BRD-08 (D1 Agents) | Downstream | Cloud Agent data source |
| BRD-09 (D2 Analytics) | Downstream | Cost data input |

---

## 8. Appendices

### Appendix A: Provider Comparison

| Capability | GCP | AWS | Azure | Kubernetes |
|------------|-----|-----|-------|------------|
| Real-time costs | Yes (BigQuery export) | No (CUR is daily) | Yes (API) | Yes (OpenCost) |
| Tag support | Labels | Tags | Tags | Labels |
| Recommendations | Recommender API | Compute Optimizer | Advisor | - |
| Permission model | Service Account | IAM Role | Service Principal | kubeconfig |
| MVP Scope | Yes | Phase 2 | Phase 2 | Phase 2 |

### Appendix B: Service Taxonomy Mapping

| Normalized Service | GCP | AWS | Azure |
|--------------------|-----|-----|-------|
| compute | Compute Engine | EC2 | Virtual Machines |
| storage | Cloud Storage | S3 | Blob Storage |
| database | Cloud SQL | RDS | Azure SQL |
| analytics | BigQuery | Athena | Synapse |
| networking | VPC | VPC | Virtual Network |
| kubernetes | GKE | EKS | AKS |

### Appendix C: Credential Path Patterns

| Provider | Secret Manager Path |
|----------|---------------------|
| GCP | `projects/{project}/secrets/tenant-{tenant_id}-gcp-{account_id}` |
| AWS | `projects/{project}/secrets/tenant-{tenant_id}-aws-{account_id}` |
| Azure | `projects/{project}/secrets/tenant-{tenant_id}-azure-{account_id}` |
| Kubernetes | `projects/{project}/secrets/tenant-{tenant_id}-k8s-{cluster_id}` |

---

**Document Status**: Draft
**Next Review**: Upon PRD creation
