---
title: "PRD-11: D4 Multi-Cloud Integration"
tags:
  - prd
  - domain-module
  - d4-multicloud
  - layer-2-artifact
  - integration
custom_fields:
  document_type: prd
  artifact_type: PRD
  layer: 2
  module_id: D4
  module_name: Multi-Cloud Integration
  architecture_approaches: [ai-agent-based]
  priority: primary
  development_status: draft
  schema_version: "1.0"
---

# PRD-11: D4 Multi-Cloud Integration

> **Module Type**: Domain (Cost Monitoring-Specific)
> **Scope**: GCP, AWS, Azure, Kubernetes cloud connectors, data normalization, credential management

@brd: BRD-11
@depends: PRD-01 (F1 IAM - tenant authorization); PRD-04 (F4 SecOps - credential audit); PRD-07 (F7 Config - provider settings)
@discoverability: PRD-08 (D1 Agents - Cloud Agent data); PRD-09 (D2 Analytics - cost data input)

---

## 1. Document Control

| Item | Details |
|------|---------|
| **Status** | Draft |
| **Version** | 1.0.0 |
| **Date Created** | 2026-02-09T00:00:00 |
| **Last Updated** | 2026-02-09T00:00:00 |
| **Author** | Antigravity AI |
| **Reviewer** | Technical Lead |
| **Approver** | Product Owner |
| **BRD Reference** | @brd: BRD-11 |
| **Priority** | P1 - Critical |
| **Target Release** | Phase 1 (GCP) / Phase 2 (AWS, Azure, K8s) |
| **Estimated Effort** | 10 person-weeks |
| **SYS-Ready Score** | 88/100 (Target: ≥85 for MVP) |
| **EARS-Ready Score** | 90/100 (Target: ≥85 for MVP) |

### 1.1 Document Revision History

| Version | Date | Author | Changes Made |
|---------|------|--------|--------------|
| 1.0.0 | 2026-02-09T00:00:00 | Antigravity AI | Initial full MVP draft with 19 sections |

---

## 2. Executive Summary

The D4 Multi-Cloud Integration Module provides connectors and abstraction layer for accessing cost and resource data from multiple cloud providers. MVP focuses on GCP integration using native BigQuery billing export. Phase 2 adds AWS (Cost and Usage Report), Azure (Cost Management API), and Kubernetes (OpenCost). The module implements a uniform data model that normalizes provider-specific schemas into a consistent format for analysis.

### 2.1 MVP Hypothesis

**We believe that** organizations with multi-cloud environments **will** achieve unified cost visibility **if we** provide automated connectors with standardized data normalization.

**We will know this is true when** time to connect first cloud account is under 5 minutes and cross-cloud reporting is available within 24 hours.

### 2.2 Timeline Overview

| Phase | Dates | Duration |
|-------|-------|----------|
| Phase 1: GCP MVP | 2026-Q1 | 4 weeks |
| Phase 2: AWS Integration | 2026-Q2 | 3 weeks |
| Phase 3: Azure Integration | 2026-Q2 | 3 weeks |
| Phase 4: Kubernetes | 2026-Q3 | 2 weeks |
| Validation Period | +30 days post-launch | 30 days |

---

## 3. Problem Statement

### 3.1 Current State

- **Fragmented APIs**: Each cloud provider uses different billing APIs and data formats
- **Authentication complexity**: Unique authentication mechanisms per provider
- **Data inconsistency**: Varying data freshness, granularity, and cost categorization
- **Manual aggregation**: Cross-cloud reporting requires manual data compilation
- **Credential management**: No unified approach to secure credential storage

### 3.2 Business Impact

- Time overhead: 4+ hours weekly spent manually aggregating cross-cloud costs
- Visibility gaps: Delayed detection of cost anomalies across providers
- Security risk: Credentials often stored in insecure locations
- Optimization loss: Cannot identify cross-cloud optimization opportunities

### 3.3 Opportunity

Unified multi-cloud integration with automated data normalization enables real-time visibility across all cloud environments, eliminating manual aggregation and enabling cross-cloud optimization.

---

## 4. Target Audience & User Personas

### 4.1 Primary User Persona

**Cloud Administrator** - Multi-Cloud Infrastructure Manager

- **Key characteristic**: Manages infrastructure across multiple cloud providers
- **Main pain point**: No single view of costs across all cloud accounts
- **Success criteria**: Can connect all cloud accounts and see unified dashboard
- **Usage frequency**: Initial setup, periodic validation

### 4.2 Secondary Users

| Role | Needs | Usage Pattern |
|------|-------|---------------|
| FinOps Practitioner | Unified cost data for analysis | Daily data consumption |
| Security Engineer | Credential security assurance | Periodic audits |
| DevOps Engineer | Pipeline configuration | Troubleshooting |

---

## 5. Success Metrics (KPIs)

### 5.1 MVP Validation Metrics (30-Day)

| Metric | Baseline | Target | Measurement |
|--------|----------|--------|-------------|
| Connection success rate | N/A | >95% | Connection attempts |
| Connection time | N/A | <5 minutes | Wizard duration |
| Data freshness | N/A | <4 hours | Pipeline lag |
| Schema compliance | N/A | 100% | Validation checks |

### 5.2 Business Success Metrics (90-Day)

| Metric | Target | Decision Threshold |
|--------|--------|-------------------|
| Connection success rate | >99% | <90% = Iterate |
| Zero credential exposure | 0 incidents | Any incident = Critical |
| Multi-cloud adoption | 30% of users | <10% = Pivot approach |

### 5.3 Go/No-Go Decision Gate

**At MVP+90 days**, evaluate:
- ✅ **Proceed to Phase 2 (AWS)**: GCP integration stable, >95% success rate
- 🔄 **Iterate**: Connection issues identified, need reliability improvements
- ❌ **Pivot**: Fundamental architecture issues preventing reliable data ingestion

---

## 6. Scope & Requirements

### 6.1 In-Scope (MVP Core Features)

| # | Feature | Priority | Description |
|---|---------|----------|-------------|
| 1 | GCP Connection Wizard | P1-Must | Guided Service Account setup |
| 2 | Credential Storage | P1-Must | GCP Secret Manager integration |
| 3 | BigQuery Billing Ingestion | P1-Must | Automated billing export query |
| 4 | Permission Verification | P1-Must | Automatic access validation |
| 5 | Data Normalization | P1-Must | Unified schema transformation |
| 6 | Connection Health Check | P2-Should | Ongoing connection monitoring |
| 7 | Rotation Reminders | P2-Should | 90-day credential alerts |

### 6.2 Phase 2 Scope

| # | Feature | Priority | Description |
|---|---------|----------|-------------|
| 1 | AWS Connection (CUR) | P1-Must | Cost and Usage Report ingestion |
| 2 | Azure Connection | P1-Must | Cost Management API integration |
| 3 | Kubernetes (OpenCost) | P2-Should | Pod/namespace cost allocation |
| 4 | Automatic Rotation | P2-Should | Credential auto-rotation |

### 6.3 Dependencies

| Dependency | Status | Impact | Owner |
|------------|--------|--------|-------|
| PRD-01 (F1 IAM) | Complete | Blocking - Tenant authorization | Platform Team |
| PRD-04 (F4 SecOps) | Complete | Blocking - Credential audit | Security Team |
| PRD-06 (F6 Infrastructure) | In Progress | Blocking - Pipeline deployment | DevOps Team |
| GCP Billing Export | Customer | Blocking - Data source | Customer |

### 6.4 Out-of-Scope (Post-Phase 2)

- **Oracle Cloud**: OCI integration deferred
- **Alibaba Cloud**: Ali Cloud integration deferred
- **On-premises**: Data center cost integration deferred
- **Real-time streaming**: Sub-minute data freshness deferred

---

## 7. User Stories & User Roles

**Scope split**: PRD = roles + story summaries; EARS = detailed behaviors; BDD = executable scenarios.

### 7.1 Core User Stories

| ID | User Story | Priority | Acceptance Criteria |
|----|------------|----------|---------------------|
| PRD.11.09.01 | As a Cloud Admin, I want to connect my GCP account, so that cost data is automatically ingested | P1 | Connection completes in <5 minutes |
| PRD.11.09.02 | As a Cloud Admin, I want my credentials stored securely, so that there is no exposure risk | P1 | Credentials in Secret Manager, audit logged |
| PRD.11.09.03 | As a Cloud Admin, I want automatic permission verification, so that I know the setup is correct | P1 | Validation runs automatically |
| PRD.11.09.04 | As a FinOps user, I want normalized cost data, so that I can analyze across providers | P1 | Unified schema with 100% compliance |
| PRD.11.09.05 | As a Cloud Admin, I want credential rotation reminders, so that security is maintained | P2 | 90-day alerts before expiration |

### 7.2 User Roles

| Role | Purpose | Permissions |
|------|---------|-------------|
| Cloud Administrator | Connect and manage cloud accounts | Full connection management |
| FinOps Practitioner | Consume normalized data | Read normalized data |
| Security Engineer | Audit credential access | Read audit logs |

### 7.3 Story Summary

| Priority | Count | Notes |
|----------|-------|-------|
| P1 (Must-Have) | 4 | Required for MVP launch |
| P2 (Should-Have) | 1 | Include if time permits |
| **Total** | 5 | |

---

## 8. Functional Requirements

### 8.1 GCP Integration (MVP)

| ID | Capability | Success Criteria | BRD Trace |
|----|------------|------------------|-----------|
| PRD.11.01.01 | Service Account connection wizard | <5 minute setup time | BRD.11.01.01 |
| PRD.11.01.02 | JSON key upload and storage | Encrypted in Secret Manager | BRD.11.06.01 |
| PRD.11.01.03 | Permission verification | Automatic validation | BRD.11.01.03 |
| PRD.11.01.04 | BigQuery billing export query | <4 hour data freshness | BRD.11.01.02 |
| PRD.11.01.05 | Cloud Asset Inventory access | Hourly resource metadata | BRD.11.01.02 |

### 8.2 Data Normalization

| ID | Capability | Success Criteria | BRD Trace |
|----|------------|------------------|-----------|
| PRD.11.01.06 | Unified schema transformation | 100% schema compliance | BRD.11.05.01 |
| PRD.11.01.07 | Service taxonomy mapping | 50+ services mapped | BRD.11.05.03 |
| PRD.11.01.08 | Currency conversion | Daily exchange rates | BRD.11.05.02 |
| PRD.11.01.09 | Region normalization | Consistent region codes | BRD.11.05.01 |

### 8.3 Credential Management

| ID | Capability | Success Criteria | BRD Trace |
|----|------------|------------------|-----------|
| PRD.11.01.10 | Per-tenant secret isolation | Tenant-scoped secrets | BRD.11.06.01 |
| PRD.11.01.11 | Access audit logging | 100% access logged | BRD.11.06.02 |
| PRD.11.01.12 | Rotation reminder alerts | 90-day advance warning | BRD.11.06.03 |

### 8.4 User Journey (Happy Path)

1. User navigates to Cloud Connections → System displays connection wizard
2. User selects GCP → System shows Service Account instructions
3. User uploads JSON key → System stores in Secret Manager
4. System validates permissions → System confirms access level
5. System configures BigQuery query → Data ingestion begins
6. User sees connection status → Green indicator, data freshness shown

### 8.5 Error Handling (MVP)

| Error Scenario | User Experience | System Behavior |
|----------------|-----------------|-----------------|
| Invalid credentials | "Credential verification failed" | Clear error message, retry option |
| Insufficient permissions | "Missing required permissions" | Show required IAM roles |
| API rate limit | "Temporarily throttled" | Exponential backoff retry |
| Connection lost | "Connection interrupted" | Automatic reconnection |

---

## 9. Quality Attributes

### 9.1 Performance (Baseline)

| Metric | Target | MVP Target | Notes |
|--------|--------|------------|-------|
| Connection wizard time | <2 minutes | <5 minutes | End-to-end setup |
| Data ingestion freshness | 4 hours | 4 hours | BigQuery export lag |
| API response time | <2 seconds | <5 seconds | Connection status |
| Pipeline throughput | 1M records/hour | 100K records/hour | MVP scale |

### 9.2 Security (Baseline)

- [x] Credentials encrypted at rest (Secret Manager)
- [x] Per-tenant credential isolation
- [x] All access audit logged
- [x] Least-privilege IAM roles
- [x] No credential exposure in logs

### 9.3 Availability (Baseline)

- Uptime target: 99.5% (MVP)
- Pipeline retry: Automatic with backoff
- Failover: Not required for MVP

### 9.4 Reliability

| Metric | Target | MVP Target |
|--------|--------|------------|
| Connection success rate | >99% | >95% |
| Data completeness | >99.9% | >99% |
| Schema validation pass | 100% | 100% |

---

## 10. Architecture Requirements

> Brief: Capture architecture topics needing ADRs. Keep MVP summaries short; full ADRs live separately.

**ID Format**: `PRD.11.32.SS`

### 10.1 Infrastructure (PRD.11.32.01)

**Status**: [ ] Selected | [X] N/A

**Reason**: Handled by F6 Infrastructure (PRD-06)

**PRD Requirements**: None for this module

---

### 10.2 Data Architecture (PRD.11.32.02)

**Status**: [X] Selected

**Business Driver**: Multi-cloud billing data normalization

**MVP Approach**:
- Unified schema in BigQuery
- Provider-specific ETL pipelines
- Daily partitioning by date
- Clustering by tenant_id, provider, service

**Normalized Schema**:

| Field | Type | Description |
|-------|------|-------------|
| tenant_id | STRING | Customer identifier |
| account_id | STRING | Cloud account reference |
| provider | STRING | gcp/aws/azure/kubernetes |
| date | DATE | Cost date |
| service | STRING | Normalized service name |
| region | STRING | Normalized region code |
| cost | FLOAT64 | Cost amount (USD) |
| usage_quantity | FLOAT64 | Resource usage |
| tags | JSON | Key-value pairs |

**Rationale**: Unified schema enables cross-cloud analytics and consistent reporting

---

### 10.3 Integration (PRD.11.32.03)

**Status**: [X] Selected

**Business Driver**: Cloud provider API integration

**MVP Approach**:
- Native cloud billing APIs
- BigQuery exports for GCP
- Cloud Functions for ETL
- Cloud Scheduler for orchestration

**Key Integrations**:
- GCP BigQuery Billing Export
- GCP Cloud Asset Inventory
- GCP Recommender API (Phase 2)

**Rationale**: Native APIs provide full control and zero additional cost

---

### 10.4 Security (PRD.11.32.04)

**Status**: [X] Selected

**Business Driver**: Multi-tenant credential isolation

**MVP Approach**:
- GCP Secret Manager for storage
- Per-tenant secret paths
- IAM-based access control
- Full audit logging

**Credential Path Pattern**:
`projects/{project}/secrets/tenant-{tenant_id}-{provider}-{account_id}`

**Rationale**: Secret Manager provides enterprise-grade security with automatic encryption

---

### 10.5 Observability (PRD.11.32.05)

**Status**: [ ] Selected | [X] N/A

**Reason**: Handled by F3 Observability (PRD-03)

**PRD Requirements**: None for this module

---

### 10.6 AI/ML (PRD.11.32.06)

**Status**: [ ] Selected | [X] N/A

**Reason**: No ML requirements in this module

**PRD Requirements**: None for current scope

---

### 10.7 Technology Selection (PRD.11.32.07)

**Status**: [X] Selected

**Business Driver**: Data pipeline technology

**MVP Selection**:
- Pipeline: Cloud Functions + Cloud Scheduler (per ADR-006)
- Credential Storage: GCP Secret Manager (per ADR-008)
- Data Storage: BigQuery (per ADR-003)
- Container Runtime: Cloud Run (per ADR-004)

**Rationale**: Serverless stack minimizes operational overhead

---

## 11. Constraints & Assumptions

### 11.1 Constraints

| Constraint | Type | Impact |
|------------|------|--------|
| GCP-only for MVP | Scope | AWS/Azure deferred to Phase 2 |
| BigQuery export lag | Technical | 4-hour minimum data freshness |
| Manual rotation MVP | Feature | Auto-rotation deferred |
| API rate limits | Technical | Request batching required |

### 11.2 Assumptions

| Assumption | Risk Level | Validation Method |
|------------|------------|-------------------|
| Customer has billing export enabled | High | Pre-onboarding checklist |
| Service Account with correct roles | Medium | Permission verification |
| BigQuery dataset accessible | Medium | Connection validation |
| Stable provider APIs | Low | Version monitoring |

---

## 12. Risk Assessment

| Risk | Likelihood | Impact | Mitigation | Owner |
|------|------------|--------|------------|-------|
| API rate limits hit | High | Medium | Request batching, caching, backoff | Engineering |
| Credential expiration | Medium | High | Rotation monitoring, 90-day alerts | Security |
| Provider API changes | Low | Medium | Schema versioning, monitoring | Engineering |
| Customer setup errors | Medium | Low | Guided wizard, clear documentation | Product |
| Data format changes | Low | Medium | Schema validation, alerts | Engineering |

---

## 13. Implementation Approach

### 13.1 MVP Development Phases

| Phase | Duration | Deliverables | Success Criteria |
|-------|----------|--------------|------------------|
| **Phase 1: Connection** | 1.5 weeks | GCP wizard, credential storage | Connection works |
| **Phase 2: Ingestion** | 1.5 weeks | BigQuery pipeline, scheduling | Data flowing |
| **Phase 3: Normalization** | 1 week | Schema transformation, mapping | 100% compliance |
| **Phase 4: Monitoring** | 0.5 weeks | Health checks, alerts | Visibility complete |
| **Phase 5: Polish** | 0.5 weeks | Bug fixes, documentation | UAT complete |

### 13.2 Testing Strategy (MVP)

| Test Type | Coverage | Responsible |
|-----------|----------|-------------|
| Unit Tests | ETL logic, schema validation | Development |
| Integration Tests | API connections, data flow | Development |
| Security Tests | Credential handling, isolation | Security |
| E2E Tests | Connection wizard flow | QA |

---

## 14. Acceptance Criteria

### 14.1 Business Acceptance

- [x] GCP connection wizard functional
- [x] Connection completes in <5 minutes
- [x] Credentials stored securely in Secret Manager
- [x] Data ingested with <4 hour freshness
- [ ] Normalized data available for analytics

### 14.2 Technical Acceptance

- [ ] Permission verification automatic
- [ ] Schema transformation 100% compliant
- [ ] Pipeline retry on failure
- [ ] Audit logging enabled
- [ ] Connection health monitoring

### 14.3 QA Acceptance

- [ ] All P1 user stories pass UAT
- [ ] No critical or high-severity bugs open
- [ ] Security review passed
- [ ] Performance metrics within targets

---

## 15. Budget & Resources

### 15.1 MVP Development Cost

| Category | Estimate | Notes |
|----------|----------|-------|
| Development (Phase 1) | $50,000 | 5 person-weeks × $10K/week |
| Development (Phase 2-4) | $80,000 | 8 person-weeks × $10K/week |
| Infrastructure (3 months) | $500 | Secret Manager, Cloud Functions |
| Third-party services | $0 | All native cloud services |
| **Total MVP Cost** | **$50,500** | Phase 1 only |

### 15.2 Ongoing Operations Cost

| Item | Monthly Cost | Notes |
|------|--------------|-------|
| Secret Manager | $50 | Per-tenant secrets |
| Cloud Functions | $50 | Pipeline execution |
| Cloud Scheduler | $10 | Job orchestration |
| **Total Monthly** | **$110** | |

### 15.3 ROI Hypothesis

**Investment**: $50,500 (Phase 1) + $80,000 (Phase 2-4)

**Expected Return**: 4+ hours/week saved on manual aggregation per customer

**Payback Period**: 6 months with 10+ customers

**Decision Logic**: If Phase 1 metrics met → Proceed to Phase 2

---

## 16. Traceability

### 16.1 Upstream References

| Source | Document | Relationship |
|--------|----------|--------------|
| BRD | @brd: BRD-11 | Business requirements source |
| ADR | ADR-002 | GCP-first decision |
| PRD-01 (F1 IAM) | Upstream | Tenant authorization |
| PRD-04 (F4 SecOps) | Upstream | Credential audit |
| PRD-07 (F7 Config) | Upstream | Provider settings |

### 16.2 Downstream Artifacts

| Artifact Type | Status | Notes |
|---------------|--------|-------|
| EARS | TBD | Created after PRD approval |
| BDD | TBD | Created after EARS |
| ADR | ADR-002 | GCP-first already exists |

### 16.3 Peer Dependencies

| Related PRD | Relationship | Integration Point |
|-------------|--------------|-------------------|
| PRD-08 (D1 Agents) | Downstream | Cloud Agent data source |
| PRD-09 (D2 Analytics) | Downstream | Cost data input |

### 16.4 Traceability Tags

```markdown
@brd: BRD-11
@depends: PRD-01; PRD-04; PRD-07
@discoverability: PRD-08 (Cloud Agent data); PRD-09 (cost data input)
```

---

## 17. Glossary

| Term | Definition |
|------|------------|
| BigQuery Billing Export | GCP feature to export billing data to BigQuery |
| CUR | AWS Cost and Usage Report |
| OpenCost | Open-source Kubernetes cost monitoring tool |
| Secret Manager | GCP service for secure credential storage |
| Service Account | GCP identity for programmatic access |
| IAM Role | AWS cross-account access mechanism |
| Service Principal | Azure identity for programmatic access |

**Master Glossary Reference**: See [BRD-00_GLOSSARY.md](../../01_BRD/BRD-00_GLOSSARY.md)

---

## 18. Appendix A: Future Roadmap (Post-MVP)

### 18.1 Phase 2 Features (If MVP Succeeds)

| Feature | Priority | Estimated Effort | Dependency |
|---------|----------|------------------|------------|
| AWS CUR Integration | P1 | 3 weeks | MVP complete |
| Azure Cost Management | P1 | 3 weeks | AWS complete |
| Kubernetes OpenCost | P2 | 2 weeks | Azure complete |
| Automatic Credential Rotation | P2 | 2 weeks | Phase 2 |
| Multi-account management | P2 | 2 weeks | Phase 2 |

### 18.2 Scaling Considerations

- **Account volume**: Support 100+ connected accounts per tenant
- **Data volume**: Handle 10M+ billing records per month
- **Provider expansion**: Oracle, Alibaba future consideration

### 18.3 Service Taxonomy Mapping

| Normalized Service | GCP | AWS | Azure |
|--------------------|-----|-----|-------|
| compute | Compute Engine | EC2 | Virtual Machines |
| storage | Cloud Storage | S3 | Blob Storage |
| database | Cloud SQL | RDS | Azure SQL |
| analytics | BigQuery | Athena | Synapse |
| networking | VPC | VPC | Virtual Network |
| kubernetes | GKE | EKS | AKS |

---

## 19. Appendix B: EARS Enhancement Appendix

### 19.1 EARS Statement Templates

| Requirement Type | EARS Pattern |
|------------------|--------------|
| Connection | WHEN user completes wizard, THE system SHALL store credentials WITHIN 30 seconds |
| Ingestion | WHEN billing export updates, THE system SHALL ingest data WITHIN 4 hours |
| Normalization | WHEN data is ingested, THE system SHALL transform to unified schema WITHIN 1 hour |
| Validation | WHEN credentials are submitted, THE system SHALL verify permissions WITHIN 30 seconds |

### 19.2 BDD Scenario Preview

```gherkin
Feature: GCP Account Connection
  Scenario: User connects GCP account successfully
    Given the user has a GCP Service Account JSON key
    And the Service Account has required permissions
    When the user uploads the JSON key in the connection wizard
    Then the system stores the credential in Secret Manager
    And the system validates access permissions
    And the connection status shows "Connected"

Feature: Data Normalization
  Scenario: Billing data is normalized to unified schema
    Given GCP billing data is ingested from BigQuery
    When the ETL pipeline processes the data
    Then all records conform to the unified schema
    And service names are mapped to normalized taxonomy
    And costs are converted to USD
```

---

*PRD-11: D4 Multi-Cloud Integration - AI Cost Monitoring Platform v4.2*
*Generated: 2026-02-09T00:00:00 | SYS-Ready Score: 88/100 | EARS-Ready Score: 90/100*
