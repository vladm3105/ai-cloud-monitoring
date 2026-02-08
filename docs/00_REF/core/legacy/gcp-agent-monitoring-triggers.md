# GCP Agent: Monitoring Triggers & Built-in Tools Strategy

## Overview

This document explains how the GCP Cost Monitoring Agent leverages **GCP's built-in monitoring and alerting capabilities** rather than building custom infrastructure. The result is a minimal-infrastructure architecture that is cost-effective and easy to maintain.

---

## 1. Monitoring Triggers and Events

There are **two distinct trigger mechanisms** in GCP:

### A. Real-time Event Triggers (Built-in, No Infrastructure Needed)

#### Budget Alerts (Fully Managed by GCP)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    BUDGET ALERTS - FULLY MANAGED                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   You create budget → GCP monitors automatically → GCP sends alerts         │
│                                                                             │
│   ┌──────────────┐      ┌──────────────┐      ┌──────────────┐            │
│   │  Budget API  │      │  GCP Budget  │      │   Pub/Sub    │            │
│   │  (one-time   │─────►│   Service    │─────►│   Topic      │            │
│   │   setup)     │      │  (managed)   │      │  (optional)  │            │
│   └──────────────┘      └──────────────┘      └──────────────┘            │
│                                │                      │                    │
│                                ▼                      ▼                    │
│                         ┌──────────────┐      ┌──────────────┐            │
│                         │    Email     │      │ Cloud Function│            │
│                         │   Alerts     │      │  (optional)   │            │
│                         │  (built-in)  │      └──────────────┘            │
│                         └──────────────┘                                   │
│                                                                             │
│   NO POLLING REQUIRED — GCP pushes notifications when thresholds hit       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**How it works:**
1. You create a budget via Budget API (one-time setup)
2. GCP Budget Service monitors spend continuously (managed by Google)
3. When threshold is reached, GCP automatically:
   - Sends email to billing admins
   - Publishes message to Pub/Sub topic (if configured)
4. **No polling, no scheduled jobs, no infrastructure to maintain**

#### Cloud Asset Inventory Feeds (Fully Managed by GCP)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ASSET INVENTORY FEEDS - FULLY MANAGED                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   You create feed → GCP monitors resource changes → GCP pushes events      │
│                                                                             │
│   ┌──────────────┐      ┌──────────────┐      ┌──────────────┐            │
│   │  Asset Feed  │      │  GCP Asset   │      │   Pub/Sub    │            │
│   │  (one-time   │─────►│  Inventory   │─────►│   Topic      │            │
│   │   setup)     │      │  (managed)   │      │              │            │
│   └──────────────┘      └──────────────┘      └──────────────┘            │
│                                                                             │
│   Triggers on: CREATE, UPDATE, DELETE of any resource type                 │
│   NO POLLING REQUIRED — GCP pushes events in real-time                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**How it works:**
1. You create an Asset Feed via Asset Inventory API (one-time setup)
2. Specify which resource types to monitor (VMs, disks, GKE clusters, etc.)
3. GCP monitors all resource changes across your organization
4. When a resource is created/updated/deleted, GCP publishes event to Pub/Sub
5. **No polling, no scheduled jobs, no infrastructure to maintain**

---

### B. On-Demand Queries (Agent-Initiated)

These happen **only when the user asks a question** — not on a schedule:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    AGENT-INITIATED QUERIES                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  User: "Why did costs spike?"                                               │
│         │                                                                   │
│         ▼                                                                   │
│   ┌─────────────────────────────────────────────────────────────────┐      │
│   │  Agent queries GCP APIs on-demand:                              │      │
│   │                                                                  │      │
│   │  • Billing Export (BigQuery) — historical cost data             │      │
│   │  • Recommender API — current recommendations                    │      │
│   │  • Resource Manager — project/folder structure                  │      │
│   │  • Service Usage — enabled services                             │      │
│   └─────────────────────────────────────────────────────────────────┘      │
│                                                                             │
│   NO SCHEDULED JOBS — queries only when user interacts                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Key insight:** The agent doesn't need to continuously poll APIs. It queries them **on-demand** when the user asks a question. This reduces API costs and eliminates the need for data synchronization infrastructure.

---

## 2. Infrastructure Requirements — Minimal!

### What GCP Provides (USE THESE — Don't Rebuild!)

| Capability | GCP Built-in Service | Our Role |
|------------|---------------------|----------|
| **Cost Data Storage** | BigQuery Billing Export | Just query it |
| **Budget Monitoring** | Budget API + Email Alerts | Just create budgets |
| **Recommendations** | Recommender API | Just query it |
| **Resource Inventory** | Cloud Asset Inventory | Just query it |
| **Real-time Events** | Asset Inventory Feeds → Pub/Sub | Just subscribe |
| **Historical Metrics** | Cloud Monitoring | Just query it |

### What We Actually Need to Build

#### Option A: Fully Serverless (Recommended for SMB)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MINIMAL INFRASTRUCTURE                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────┐                                                       │
│   │  MCP Server     │  ← The agent itself (stateless)                      │
│   │  (Cloud Run)    │                                                       │
│   │                 │    Responsibilities:                                  │
│   │  ~$10-50/month  │    • Receives user queries                           │
│   │                 │    • Calls GCP APIs on-demand                        │
│   │                 │    • Formats responses                               │
│   └─────────────────┘                                                       │
│                                                                             │
│   That's it! Everything else is GCP managed services.                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Cost estimate:** $10-50/month for Cloud Run (pay per request)

#### Option B: With Circuit Breaker Automation

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    WITH AUTOMATED ACTIONS                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────┐      ┌─────────────────┐                             │
│   │  MCP Server     │      │  Cloud Function │                             │
│   │  (Cloud Run)    │      │  (Budget Alert  │  ← Triggered by Pub/Sub     │
│   │                 │      │   Handler)      │    when budget threshold    │
│   │  ~$10-50/month  │      │  ~$5/month      │    is exceeded              │
│   └─────────────────┘      └─────────────────┘                             │
│                                    │                                        │
│                                    ▼                                        │
│                            Executes circuit breaker actions:                │
│                            • Stop VMs                                       │
│                            • Scale down GKE                                 │
│                            • Send alerts                                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Cost estimate:** $15-55/month total

---

## 3. Simplified Architecture Using Built-in GCP Tools

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SIMPLIFIED ARCHITECTURE                                   │
│                    (Leveraging GCP Built-in Tools)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                         ┌─────────────────┐                                 │
│                         │      USER       │                                 │
│                         └────────┬────────┘                                 │
│                                  │                                          │
│                                  ▼                                          │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                     MCP SERVER (Cloud Run)                             │ │
│  │                                                                        │ │
│  │   • Conversational Interface                                          │ │
│  │   • Query Router                                                       │ │
│  │   • Response Formatter                                                 │ │
│  │   • Circuit Breaker Logic (state in Firestore or memory)              │ │
│  │                                                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                  │                                          │
│                    ┌─────────────┼─────────────┐                           │
│                    │             │             │                           │
│                    ▼             ▼             ▼                           │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                    GCP BUILT-IN SERVICES                             │  │
│  │                    (No infrastructure to manage)                     │  │
│  │                                                                       │  │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐   │  │
│  │  │  BigQuery   │ │  Budget     │ │ Recommender │ │Cloud Asset  │   │  │
│  │  │  Billing    │ │  Alerts     │ │    API      │ │ Inventory   │   │  │
│  │  │  Export     │ │             │ │             │ │             │   │  │
│  │  │             │ │ • Auto      │ │ • Idle VMs  │ │ • Resource  │   │  │
│  │  │ • All cost  │ │   email     │ │ • Rightsize │ │   history   │   │  │
│  │  │   history   │ │ • Pub/Sub   │ │ • CUDs      │ │ • Real-time │   │  │
│  │  │ • By service│ │   notify    │ │             │ │   feeds     │   │  │
│  │  │ • By project│ │ • Forecast  │ │             │ │             │   │  │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘   │  │
│  │                                                                       │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Optional: Automated Actions Layer

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    OPTIONAL: AUTOMATED CIRCUIT BREAKER                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│       Budget Alert                         Asset Feed                       │
│       (Pub/Sub)                            (Pub/Sub)                        │
│           │                                    │                            │
│           ▼                                    ▼                            │
│   ┌─────────────────┐                 ┌─────────────────┐                  │
│   │ Cloud Function  │                 │ Cloud Function  │                  │
│   │ "Budget Handler"│                 │ "Resource Alert"│                  │
│   │                 │                 │                 │                  │
│   │ • Check if      │                 │ • Estimate cost │                  │
│   │   threshold     │                 │   of new        │                  │
│   │   exceeded      │                 │   resource      │                  │
│   │                 │                 │                 │                  │
│   │ • Execute       │                 │ • Send alert if │                  │
│   │   circuit       │                 │   high-cost     │                  │
│   │   breaker       │                 │   (>$500/mo)    │                  │
│   │   action        │                 │                 │                  │
│   └─────────────────┘                 └─────────────────┘                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Trigger Summary

| Trigger Type | Mechanism | Infrastructure Needed |
|--------------|-----------|----------------------|
| **User asks question** | On-demand API query | MCP Server only |
| **Budget threshold hit** | GCP Budget Service → Pub/Sub | None (GCP managed) |
| **Resource created** | Asset Inventory Feed → Pub/Sub | None (GCP managed) |
| **Auto circuit breaker** | Cloud Function triggered by Pub/Sub | 1 Cloud Function (optional) |
| **Recommendations refresh** | GCP Recommender (continuous) | None (GCP managed) |
| **Cost data update** | BigQuery Billing Export (daily) | None (GCP managed) |

---

## 5. One-Time Setup Required

### Step 1: Enable Billing Export to BigQuery

```
Location: GCP Console → Billing → Billing Export

Settings:
  - Project: [your-project]
  - Dataset: billing_export
  - Table prefix: gcp_billing

GCP automatically exports cost data daily. No scheduled jobs needed.
```

### Step 2: Create Budget with Pub/Sub Notifications

```
Location: GCP Console → Billing → Budgets & alerts

Configuration:
  - Budget name: "Monthly Cost Limit"
  - Budget amount: $5,000 (example)
  - Thresholds:
    - 50% ($2,500) — Actual spend
    - 80% ($4,000) — Forecasted spend
    - 90% ($4,500) — Actual spend
    - 100% ($5,000) — Actual spend
  - Notifications:
    - Email: billing-admins@company.com
    - Pub/Sub topic: projects/[project]/topics/budget-alerts

GCP sends alerts automatically when thresholds are reached.
```

### Step 3: Create Asset Inventory Feed (Optional)

```
Purpose: Real-time alerts when expensive resources are created

API Call:
  POST https://cloudasset.googleapis.com/v1/organizations/{org_id}/feeds

Feed Configuration:
  - Asset types:
    - compute.googleapis.com/Instance
    - container.googleapis.com/Cluster
    - sqladmin.googleapis.com/Instance
    - aiplatform.googleapis.com/Endpoint
  - Feed output: Pub/Sub topic

GCP monitors continuously and pushes events in real-time.
```

### Step 4: Deploy MCP Server

```
Deployment: Cloud Run

Components:
  - Conversational interface
  - GCP API clients
  - Circuit breaker logic
  - Response formatter

Connects to:
  - BigQuery (billing data)
  - Budget API (budget status)
  - Recommender API (optimization suggestions)
  - Resource Manager API (project/folder structure)
  - Service Usage API (enabled services)
  - Compute Engine API (for circuit breaker actions)
```

---

## 6. Cost Comparison

### Traditional Approach (DON'T DO THIS)

| Component | Monthly Cost |
|-----------|-------------|
| Dedicated VM for polling | $50-100 |
| Custom database for metrics | $50-200 |
| Message queue infrastructure | $20-50 |
| Scheduled job runner | $10-30 |
| **Total** | **$130-380/month** |

### Our Approach (GCP Built-in Tools)

| Component | Monthly Cost |
|-----------|-------------|
| MCP Server (Cloud Run) | $10-50 |
| Cloud Function (optional) | $5 |
| BigQuery queries | $5-20 |
| Pub/Sub messages | $1-5 |
| **Total** | **$21-80/month** |

**Savings: 70-80% reduction in infrastructure costs**

---

## 7. Key Architectural Decisions

### ✅ We Use GCP Built-in:

1. **BigQuery Billing Export** — Cost data storage and historical analysis
2. **Budget API** — Threshold monitoring and email alerts
3. **Recommender API** — ML-powered optimization suggestions
4. **Cloud Asset Inventory** — Resource tracking and real-time feeds
5. **Pub/Sub** — Event delivery for automated actions
6. **Cloud Monitoring** — Metrics and alerting (if needed)

### ✅ We Build Only:

1. **MCP Server** — Conversational interface and query routing
2. **Cloud Function** — Circuit breaker automation (optional)

### ❌ We Don't Build:

1. ~~Custom metrics database~~
2. ~~Polling/scheduled jobs~~
3. ~~Custom alerting system~~
4. ~~Resource inventory database~~
5. ~~Cost aggregation pipeline~~

---

## 8. Summary

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           BOTTOM LINE                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   We use GCP's built-in monitoring, storage, and alerting.                 │
│                                                                             │
│   The only infrastructure we build:                                         │
│                                                                             │
│     1. MCP Server (Cloud Run)                                               │
│        - Handles user conversations                                         │
│        - Queries GCP APIs on-demand                                         │
│        - Formats responses                                                  │
│                                                                             │
│     2. Cloud Function (optional)                                            │
│        - Automated circuit breaker actions                                  │
│        - Triggered by Pub/Sub (budget alerts)                              │
│                                                                             │
│   Everything else is managed by Google Cloud Platform.                      │
│                                                                             │
│   Total infrastructure cost: $20-80/month                                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```
