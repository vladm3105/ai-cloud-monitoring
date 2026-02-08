---
title: "PRD-01.4: F1 Identity & Access Management - Target Audience"
tags:
  - prd
  - foundation-module
  - f1-iam
  - layer-2-artifact
custom_fields:
  document_type: prd-section
  artifact_type: PRD
  layer: 2
  parent_doc: PRD-01
  section: 4
  module_id: F1
  module_name: Identity & Access Management
---

# PRD-01.4: F1 Identity & Access Management - Target Audience

> **Navigation**: [Index](PRD-01.0_index.md) | [Previous: Problem Statement](PRD-01.3_problem_statement.md) | [Next: Success Metrics](PRD-01.5_success_metrics.md)
> **Parent**: PRD-01 | **Section**: 4 of 17

---

## 4. Target Audience & User Personas

@brd: BRD.01.09.01, BRD.01.09.02, BRD.01.09.03

---

### 4.1 Primary User Personas

#### Persona 1: Platform Administrator

**Role**: Manages IAM policies, trust levels, and access configurations

| Attribute | Details |
|-----------|---------|
| **Key characteristic** | Responsible for platform security posture |
| **Main pain point** | Complex policy management across multiple systems |
| **Success criteria** | Unified IAM configuration with audit visibility |
| **Usage frequency** | Daily - policy updates, access reviews |
| **Trust Level** | 4 (Admin) |

**User Stories**:
- Configure trust level policies without code changes
- Monitor authentication patterns and anomalies
- Revoke compromised sessions across all devices instantly

---

#### Persona 2: DevOps Engineer

**Role**: Deploys and integrates IAM module with infrastructure

| Attribute | Details |
|-----------|---------|
| **Key characteristic** | Manages deployment pipelines and service integration |
| **Main pain point** | Complex auth integration across microservices |
| **Success criteria** | Single API surface for all IAM operations |
| **Usage frequency** | Weekly - deployments, integration updates |
| **Trust Level** | 3-4 (Producer/Admin) |

**User Stories**:
- Integrate F1 APIs with domain services
- Configure secret rotation and key management
- Monitor IAM health metrics and alerts

---

#### Persona 3: Security/Compliance Officer

**Role**: Audits access, enforces policies, validates compliance

| Attribute | Details |
|-----------|---------|
| **Key characteristic** | Responsible for compliance and security audits |
| **Main pain point** | Lack of centralized audit logging |
| **Success criteria** | Complete audit trail with compliance reports |
| **Usage frequency** | Weekly - audits, compliance reviews |
| **Trust Level** | 4 (Admin - read-only audit access) |

**User Stories**:
- View comprehensive audit logs for all auth events
- Generate compliance reports for SOC 2/ISO 27001
- Detect and investigate anomalous access patterns

---

#### Persona 4: Development Team Member

**Role**: Integrates F1 APIs into domain layer applications

| Attribute | Details |
|-----------|---------|
| **Key characteristic** | Builds domain-specific features using F1 SDK |
| **Main pain point** | Complex authorization integration |
| **Success criteria** | Simple SDK with clear documentation |
| **Usage frequency** | Daily - development, testing |
| **Trust Level** | 2-3 (Operator/Producer) |

**User Stories**:
- Check permissions using 4D Matrix API
- Handle token refresh and session management
- Implement MFA flows in applications

---

### 4.2 Secondary Users

| User Type | Description | Access Pattern |
|-----------|-------------|----------------|
| End Users | Authenticate and access platform features | Login, MFA, session management |
| Service Accounts | Machine-to-machine authentication | API keys, mTLS certificates |
| External IdP Administrators | Manage Auth0/Google federation | SSO configuration, user sync |

---

### 4.3 User Role Summary

| Role | Purpose | Permissions | Trust Level |
|------|---------|-------------|-------------|
| Viewer | Read-only access to paper zone | view:* on own resources | 1 |
| Operator | Full access to paper zone | view, create, update on own/workspace | 2 |
| Producer | Full access to paper and live zones | All except admin actions | 3 |
| Admin | Full access including admin zone | All permissions | 4 |

---

> **Navigation**: [Index](PRD-01.0_index.md) | [Previous: Problem Statement](PRD-01.3_problem_statement.md) | [Next: Success Metrics](PRD-01.5_success_metrics.md)
