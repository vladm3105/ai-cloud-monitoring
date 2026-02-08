# Legacy Documentation

This folder contains historical documentation from earlier phases of the AI Cost Monitoring project. These documents are kept for reference only and **do not reflect the current architecture**.

## What Changed

The project evolved from a **GCP-only, Kubernetes-based architecture** to a **cloud-agnostic, serverless architecture**. The documents in this folder represent the old approach.

## Current vs Legacy Architecture

| Aspect | Legacy (this folder) | Current (parent core/) |
|--------|---------------------|------------------------|
| **Cloud Support** | GCP-only | GCP as first home cloud, monitors AWS/Azure/GCP/K8s |
| **Container Platform** | Kubernetes (GKE) | Serverless containers (Cloud Run / ECS Fargate / Azure Container Apps) |
| **Analytics Database** | TimescaleDB (self-hosted) | BigQuery / Athena / Synapse (serverless) |
| **Task Queue** | Celery + Redis | Cloud Tasks / SQS / Service Bus |
| **Deployment Complexity** | High (K8s cluster management) | Low (managed services) |
| **Monthly Cost (100 tenants)** | ~$2,150 | ~$570-690 |

## Contents

### Old GCP-Specific Architecture Documents
- `gcp-agent-*.md` - Early GCP-only agent specifications
- `gcp-agent-*.svg` - GCP-only architecture diagrams

### Old Multi-Agent Architecture
- `multi-agent-architecture.md` - Earlier multi-agent design (superseded)
- `finops-agent-*.svg` - Old agent flow diagrams

### Scenario Documents
- `scenario-llm-cost-breach.md` - Use case scenarios (still relevant conceptually)
- `scenario-*.svg` - Scenario diagrams

### Other Legacy Files
- `ai-cost-monitoring-review.md` - Historical project review
- `ai-cost-monitoring-operational-modes.svg` - Old operational modes diagram
- `vertex-ai-stopping-explained.md` - GCP-specific resource management
- `AI-Cost-Monitoring-SMB-ROI-Analysis.docx` - Old ROI analysis

## Why We Changed

See the following ADRs for architectural decisions:
- [ADR-002: GCP as First Home Cloud](../domain/architecture/adr/002-gcp-only-first.md) - Why GCP first, but not GCP-only
- [ADR-003: Use BigQuery, Not TimescaleDB](../domain/architecture/adr/003-use-bigquery-not-timescaledb.md) - Serverless analytics
- [ADR-004: Serverless Containers, Not Kubernetes](../domain/architecture/adr/004-cloud-run-not-kubernetes.md) - Simpler deployment
- [ADR-006: Cloud-Native Task Queues, Not Celery](../domain/architecture/adr/006-cloud-native-task-queues-not-celery.md) - Managed background jobs

## Active Documentation

For current specifications, see the parent `core/` directory:
- [Database Schema](../01-database-schema.md)
- [Deployment Infrastructure](../07-deployment-infrastructure.md)
- [Executive Summary](../executive-summary.md)
- [Architecture Description](../ai-cost-monitoring-description.md)

---

**Note:** These legacy documents are preserved for historical reference and to understand the evolution of the project. Do not use them as the source of truth for implementation.
