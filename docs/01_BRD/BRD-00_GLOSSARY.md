---
title: "BRD-00: Master Glossary"
tags:
  - brd
  - glossary
  - reference
  - layer-1-artifact
custom_fields:
  document_type: glossary
  artifact_type: BRD-REFERENCE
  layer: 1
  created_by: doc-brd-fixer
  created_date: "2026-02-10"
---

# BRD-00: Master Glossary

Common terminology used across all Business Requirements Documents for the AI Cost Monitoring Platform.

---

## Business Terms

| Term | Definition | Context |
|------|------------|---------|
| MVP | Minimum Viable Product - smallest set of features to deliver value | Scope definition |
| SLA | Service Level Agreement - formal commitment between service provider and client | Quality requirements |
| KPI | Key Performance Indicator - measurable value demonstrating effectiveness | Success metrics |
| ROI | Return on Investment - ratio between net profit and cost of investment | Business case |
| TCO | Total Cost of Ownership - complete cost of a solution over its lifecycle | Cost analysis |

---

## Technical Terms

| Term | Definition | Context |
|------|------------|---------|
| API | Application Programming Interface - methods for software communication | Integration |
| JWT | JSON Web Token - compact token format for secure claims transmission | Authentication |
| OIDC | OpenID Connect - identity layer on top of OAuth 2.0 | Identity federation |
| mTLS | Mutual TLS - two-way authentication using certificates | Service authentication |
| TOTP | Time-based One-Time Password - algorithm for MFA | Multi-factor auth |
| WebAuthn | Web Authentication API - passwordless authentication standard | Passwordless auth |
| SCIM | System for Cross-domain Identity Management - user provisioning protocol | User lifecycle |
| RBAC | Role-Based Access Control - authorization based on roles | Access control |

---

## Platform Terms

| Term | Definition | Context |
|------|------------|---------|
| Foundation Module | Domain-agnostic reusable component (F1-F7) | Architecture |
| Domain Module | Business-specific component (D1-D7) | Architecture |
| Trust Level | 4-tier access hierarchy (Viewer, Operator, Producer, Admin) | Authorization |
| 4D Matrix | ACTION x SKILL x RESOURCE x ZONE authorization model | Authorization |
| Zone | Environment context (paper, live, admin, system) | Access control |

---

## Security Terms

| Term | Definition | Context |
|------|------------|---------|
| Zero-Trust | Security model requiring verification for all access | Security architecture |
| MFA | Multi-Factor Authentication - multiple verification methods | Authentication |
| PII | Personally Identifiable Information - data identifying individuals | Data protection |
| AES-256-GCM | Encryption algorithm for data at rest | Credential storage |

---

## Infrastructure Terms

| Term | Definition | Context |
|------|------------|---------|
| GCP | Google Cloud Platform - cloud services provider | Infrastructure |
| Cloud Run | GCP serverless container platform | Deployment |
| Cloud SQL | GCP managed database service | Data storage |
| Secret Manager | GCP service for secure credential storage | Security |
| Redis | In-memory data store for caching and sessions | Session management |

---

## Document Terms

| Term | Definition | Context |
|------|------------|---------|
| BRD | Business Requirements Document - Layer 1 artifact | Documentation |
| PRD | Product Requirements Document - Layer 2 artifact | Documentation |
| ADR | Architecture Decision Record - Layer 5 artifact | Documentation |
| SDD | Specification-Driven Development - documentation methodology | Workflow |

---

*Master Glossary for AI Cost Monitoring Platform v4.2*
*Created by doc-brd-fixer v1.0 | 2026-02-10*
