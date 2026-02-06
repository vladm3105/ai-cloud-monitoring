# GCP Cost Monitoring Agent — Architectural Design

## Executive Summary

This document defines the structural and architectural design for a GCP Cost Monitoring Agent that provides:

1. **Organization Scanner** — Resource Manager API + Service Usage API for complete visibility
2. **Circuit Breaker** — Automatic cost control with configurable thresholds
3. **Proactive Budget Monitoring** — Multi-threshold alerts including forecasted spend
4. **Real-time Resource Tracking** — Cloud Asset Inventory feeds for instant notifications
5. **ML-Powered Recommendations** — Recommender API integration
6. **Anomaly Detection** — Statistical analysis of historical costs
7. **Conversational Interface** — Natural language queries

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              USER INTERFACE LAYER                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                    CONVERSATIONAL INTERFACE                              │   │
│  │                                                                          │   │
│  │   "Why did costs spike?"  ───►  Intent Classification  ───►  Response   │   │
│  │   "Show me idle VMs"      ───►  Entity Extraction     ───►  Actions     │   │
│  │   "Set budget to $5000"   ───►  Context Management    ───►  Approvals   │   │
│  │                                                                          │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                        │                                        │
└────────────────────────────────────────┼────────────────────────────────────────┘
                                         │
                                         ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              MCP SERVER LAYER (Port 8084)                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐   │
│  │ Organization  │  │    Circuit    │  │    Budget     │  │   Anomaly     │   │
│  │   Scanner     │  │    Breaker    │  │   Monitor     │  │   Detector    │   │
│  │               │  │               │  │               │  │               │   │
│  │ • Hierarchy   │  │ • Thresholds  │  │ • Alerts      │  │ • Statistics  │   │
│  │ • Projects    │  │ • Actions     │  │ • Forecasts   │  │ • Patterns    │   │
│  │ • Services    │  │ • Cooldowns   │  │ • Pub/Sub     │  │ • Trends      │   │
│  └───────────────┘  └───────────────┘  └───────────────┘  └───────────────┘   │
│                                                                                 │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐   │
│  │  Real-time    │  │      ML       │  │   Billing     │  │   Resource    │   │
│  │   Tracker     │  │  Recommender  │  │  Collector    │  │   Manager     │   │
│  │               │  │               │  │               │  │               │   │
│  │ • Asset Feed  │  │ • Idle VMs    │  │ • BigQuery    │  │ • Stop/Start  │   │
│  │ • Pub/Sub     │  │ • Rightsizing │  │ • Daily Costs │  │ • Scale       │   │
│  │ • Estimates   │  │ • CUDs        │  │ • Forecasts   │  │ • Delete      │   │
│  └───────────────┘  └───────────────┘  └───────────────┘  └───────────────┘   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              GCP API LAYER                                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌───────────┐│
│  │  Resource   │ │   Service   │ │   Budget    │ │   Cloud     │ │Recommender││
│  │  Manager    │ │   Usage     │ │    API      │ │   Asset     │ │   API     ││
│  │   API v3    │ │    API      │ │             │ │  Inventory  │ │           ││
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ └───────────┘│
│                                                                                 │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐             │
│  │   Billing   │ │   Compute   │ │  Pub/Sub    │ │  BigQuery   │             │
│  │    API      │ │   Engine    │ │             │ │  (Export)   │             │
│  │             │ │    API      │ │             │ │             │             │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘             │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Component Architecture

### 1. Organization Scanner

**Purpose:** Discover all projects and enabled services across the GCP organization.

**Method:** Resource Manager API + Service Usage API (detailed enumeration)

```
┌─────────────────────────────────────────────────────────────────┐
│                    ORGANIZATION SCANNER                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              HIERARCHY DISCOVERY                         │   │
│  │                                                          │   │
│  │   Organization (123456789)                               │   │
│  │        │                                                 │   │
│  │        ├── Folder: Production                            │   │
│  │        │      ├── Project: prod-web-app                  │   │
│  │        │      └── Project: prod-api                      │   │
│  │        │                                                 │   │
│  │        ├── Folder: Development                           │   │
│  │        │      ├── Project: dev-web-app                   │   │
│  │        │      └── Project: dev-ml-training               │   │
│  │        │                                                 │   │
│  │        └── Project: shared-services                      │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                           │                                     │
│                           ▼                                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              SERVICE ENUMERATION                         │   │
│  │                                                          │   │
│  │   For each project:                                      │   │
│  │     → Query Service Usage API (filter: state:ENABLED)    │   │
│  │     → Classify by cost risk level                        │   │
│  │     → Store service metadata                             │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                           │                                     │
│                           ▼                                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              HIGH-COST SERVICE DETECTION                 │   │
│  │                                                          │   │
│  │   CRITICAL: aiplatform.googleapis.com (Vertex AI)        │   │
│  │   HIGH:     compute.googleapis.com (VMs, GPUs)           │   │
│  │   HIGH:     bigquery.googleapis.com                      │   │
│  │   HIGH:     container.googleapis.com (GKE)               │   │
│  │   HIGH:     dataflow.googleapis.com                      │   │
│  │   MEDIUM:   sqladmin.googleapis.com (Cloud SQL)          │   │
│  │   MEDIUM:   run.googleapis.com (Cloud Run)               │   │
│  │   LOW:      cloudfunctions.googleapis.com                │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Data Flow:**

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   Resource   │    │   Service    │    │   Billing    │    │   Scan       │
│   Manager    │───►│   Usage      │───►│    API       │───►│   Result     │
│   API v3     │    │   API        │    │              │    │              │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
      │                   │                   │                    │
      │                   │                   │                    │
      ▼                   ▼                   ▼                    ▼
  Folders &          Enabled             Billing              Enriched
  Projects           Services            Accounts             Projects
```

**Scan Result Schema:**

```yaml
OrganizationScanResult:
  organization_id: string
  scan_timestamp: datetime
  folders:
    - folder_id: string
      display_name: string
      parent: string
  projects:
    - project_id: string
      display_name: string
      parent: string
      enabled_services:
        - name: string
          risk: CRITICAL | HIGH | MEDIUM | LOW
          category: string
      billing_account: string
      monthly_cost: float
  service_summary:
    service_name: [project_ids]
  high_cost_services:
    service_name: [project_ids]
  total_monthly_cost: float
```

---

### 2. Circuit Breaker

**Purpose:** Automatically control costs when thresholds are exceeded.

**Architecture:**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CIRCUIT BREAKER                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                      THRESHOLD CONFIGURATION                          │ │
│  │                                                                        │ │
│  │   Level 1: WARNING      $1,000/day    → Alert Only                    │ │
│  │   Level 2: ELEVATED     $2,500/day    → Alert Only                    │ │
│  │   Level 3: CRITICAL     $5,000/day    → Stop High-Cost Resources      │ │
│  │   Level 4: EMERGENCY    $10,000/day   → Disable Billing               │ │
│  │                                                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                    │                                        │
│                                    ▼                                        │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                      STATE MACHINE                                     │ │
│  │                                                                        │ │
│  │         ┌─────────┐                    ┌─────────┐                    │ │
│  │         │ CLOSED  │──── threshold ────►│  OPEN   │                    │ │
│  │         │(normal) │     exceeded       │(tripped)│                    │ │
│  │         └─────────┘                    └─────────┘                    │ │
│  │              ▲                              │                          │ │
│  │              │                              │                          │ │
│  │              │         ┌──────────┐         │                          │ │
│  │              └─────────│HALF-OPEN │◄────────┘                          │ │
│  │                reset   │(testing) │   cooldown                        │ │
│  │                        └──────────┘   expires                         │ │
│  │                                                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                    │                                        │
│                                    ▼                                        │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                      TRIP ACTIONS                                      │ │
│  │                                                                        │ │
│  │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │ │
│  │   │ ALERT_ONLY  │  │STOP_RESOURCES│ │ SCALE_DOWN  │  │DISABLE_BILLING││ │
│  │   │             │  │             │  │             │  │             │ │ │
│  │   │ Send alerts │  │ Stop VMs    │  │ Scale GKE   │  │ Remove      │ │ │
│  │   │ to Slack,   │  │ Stop Vertex │  │ to 0 nodes  │  │ billing     │ │ │
│  │   │ email,      │  │ endpoints   │  │ Reduce DB   │  │ account     │ │ │
│  │   │ PagerDuty   │  │ Stop jobs   │  │ instances   │  │ association │ │ │
│  │   └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘ │ │
│  │                                                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Threshold Configuration Schema:**

```yaml
CircuitBreakerConfig:
  project_id: string
  enabled: boolean
  dry_run: boolean  # Log actions without executing
  thresholds:
    - name: string
      threshold_usd: float
      action: ALERT_ONLY | STOP_RESOURCES | SCALE_DOWN | DISABLE_BILLING
      services: [string]  # Specific services to affect (null = all)
      cooldown_hours: int
      auto_reset: boolean
      notify_channels: [slack, email, pagerduty]
  global_daily_limit_usd: float
  global_monthly_limit_usd: float
  excluded_services: [string]
  require_approval_for_reset: boolean
```

**Circuit Breaker Flow:**

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   Current    │    │   Compare    │    │   Check      │    │   Execute    │
│   Cost       │───►│   Against    │───►│   Cooldown   │───►│   Action     │
│   (from API) │    │   Thresholds │    │   & Override │    │              │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
                                                                   │
                          ┌────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ACTION EXECUTION                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  IF action = ALERT_ONLY:                                                    │
│      → Send notifications to configured channels                            │
│                                                                             │
│  IF action = STOP_RESOURCES:                                                │
│      → List VMs with label "cost-protection: stoppable"                     │
│      → Stop each VM via Compute Engine API                                  │
│      → Undeploy Vertex AI endpoints                                         │
│      → Cancel running Dataflow jobs                                         │
│      → Send notification with affected resources                            │
│                                                                             │
│  IF action = SCALE_DOWN:                                                    │
│      → Scale GKE node pools to min_nodes: 0                                 │
│      → Reduce Cloud SQL instances to smallest tier                          │
│      → Scale Cloud Run services to min_instances: 0                         │
│                                                                             │
│  IF action = DISABLE_BILLING:                                               │
│      → Call Billing API to remove billing account                           │
│      → WARNING: This stops ALL billable services!                           │
│      → Requires manual re-enablement                                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### 3. Proactive Budget Monitoring

**Purpose:** Create and monitor budgets with multi-threshold alerts including forecasted spend.

**Architecture:**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        BUDGET MONITORING SYSTEM                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                      MULTI-THRESHOLD ALERTS                           │ │
│  │                                                                        │ │
│  │   Budget: $10,000/month                                               │ │
│  │                                                                        │ │
│  │   ┌─────────────────────────────────────────────────────────────────┐│ │
│  │   │ $12,000 ─────────────────────────────────── 120% EMERGENCY     ││ │
│  │   │                                                                  ││ │
│  │   │ $10,000 ═════════════════════════════════════ 100% CRITICAL    ││ │
│  │   │                                                                  ││ │
│  │   │ $9,000  ─────────────────────────────────────  90% CRITICAL    ││ │
│  │   │                                                                  ││ │
│  │   │ $8,000  ═════════════════════════════════════  80% FORECASTED  ││ │
│  │   │                                                                  ││ │
│  │   │ $7,000  ─────────────────────────────────────  70% WARNING     ││ │
│  │   │                                                                  ││ │
│  │   │ $5,000  ─────────────────────────────────────  50% INFO        ││ │
│  │   │                                                                  ││ │
│  │   │ $0      ─────────────────────────────────────                   ││ │
│  │   └─────────────────────────────────────────────────────────────────┘│ │
│  │              ▲                           ▲                            │ │
│  │              │                           │                            │ │
│  │        CURRENT SPEND              FORECASTED SPEND                    │ │
│  │                                                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                    │                                        │
│                                    ▼                                        │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                      NOTIFICATION FLOW                                 │ │
│  │                                                                        │ │
│  │   Budget API  ───►  Pub/Sub Topic  ───►  Cloud Function  ───►  Agent  │ │
│  │      │                                          │                      │ │
│  │      │                                          ▼                      │ │
│  │      │                                   ┌─────────────┐               │ │
│  │      └──────────────────────────────────►│ Circuit     │               │ │
│  │              (if threshold >= 100%)      │ Breaker     │               │ │
│  │                                          └─────────────┘               │ │
│  │                                                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Budget Types:**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           BUDGET TYPES                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. PROJECT BUDGET                                                          │
│     ┌─────────────────────────────────────────────────────────────────┐    │
│     │ Scope: Single project                                            │    │
│     │ Use: Default protection for each project                        │    │
│     │ Example: prod-web-app → $5,000/month                            │    │
│     └─────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  2. SERVICE BUDGET                                                          │
│     ┌─────────────────────────────────────────────────────────────────┐    │
│     │ Scope: Specific GCP services across projects                    │    │
│     │ Use: Control spend on expensive services                        │    │
│     │ Example: Vertex AI → $10,000/month (all projects)               │    │
│     └─────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  3. LABEL BUDGET                                                            │
│     ┌─────────────────────────────────────────────────────────────────┐    │
│     │ Scope: Resources with specific labels                           │    │
│     │ Use: Team-based or environment-based budgets                    │    │
│     │ Example: team=ml-research → $20,000/month                       │    │
│     └─────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  4. ORGANIZATION BUDGET                                                     │
│     ┌─────────────────────────────────────────────────────────────────┐    │
│     │ Scope: Entire organization                                       │    │
│     │ Use: Global cost cap                                             │    │
│     │ Example: All projects → $100,000/month                          │    │
│     └─────────────────────────────────────────────────────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### 4. Real-time Resource Tracking

**Purpose:** Instantly detect creation of expensive resources via Cloud Asset Inventory feeds.

**Architecture:**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    REAL-TIME RESOURCE TRACKING                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                CLOUD ASSET INVENTORY FEED                              │ │
│  │                                                                        │ │
│  │   Scope: organizations/123456789                                      │ │
│  │   Asset Types:                                                        │ │
│  │     • compute.googleapis.com/Instance                                 │ │
│  │     • compute.googleapis.com/Disk                                     │ │
│  │     • sqladmin.googleapis.com/Instance                                │ │
│  │     • container.googleapis.com/Cluster                                │ │
│  │     • aiplatform.googleapis.com/Endpoint                              │ │
│  │     • aiplatform.googleapis.com/CustomJob                             │ │
│  │     • dataflow.googleapis.com/Job                                     │ │
│  │                                                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                    │                                        │
│                                    │ Asset Change Events                    │
│                                    ▼                                        │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                      PUB/SUB TOPIC                                     │ │
│  │                                                                        │ │
│  │   projects/my-project/topics/gcp-resource-changes                     │ │
│  │                                                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                    │                                        │
│                                    ▼                                        │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                      EVENT PROCESSOR                                   │ │
│  │                                                                        │ │
│  │   1. Parse asset change event                                         │ │
│  │   2. Determine event type (CREATE, UPDATE, DELETE)                    │ │
│  │   3. Extract resource details (type, project, location)               │ │
│  │   4. Estimate monthly cost                                            │ │
│  │   5. Assess risk level                                                │ │
│  │   6. Trigger alerts if high-cost                                      │ │
│  │                                                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                    │                                        │
│                                    ▼                                        │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                      COST ESTIMATION                                   │ │
│  │                                                                        │ │
│  │   Resource Type          Estimation Method                            │ │
│  │   ─────────────────────────────────────────────────────────────────   │ │
│  │   VM Instance            machine_type → pricing table + GPU costs     │ │
│  │   Cloud SQL              tier → pricing table × HA multiplier         │ │
│  │   GKE Cluster            mgmt fee + (node_count × VM cost)            │ │
│  │   Vertex Endpoint        base prediction cost estimate                │ │
│  │   Vertex CustomJob       worker_specs × GPU costs × est. hours        │ │
│  │   Dataflow Job           vCPU/memory hours estimate                   │ │
│  │                                                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**GPU Pricing Reference:**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        GPU COST REFERENCE                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   GPU Type              Hourly Cost      Monthly (730 hrs)                  │
│   ─────────────────────────────────────────────────────────────────────    │
│   NVIDIA T4              $0.35           $255                               │
│   NVIDIA L4              $0.55           $401                               │
│   NVIDIA P4              $0.60           $438                               │
│   NVIDIA P100            $1.46           $1,066                             │
│   NVIDIA V100            $2.48           $1,810                             │
│   NVIDIA A100 (40GB)     $3.67           $2,679                             │
│   NVIDIA H100 (80GB)     $10.20          $7,446                             │
│                                                                             │
│   Alert Trigger: Any resource with estimated cost > $500/month              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Event Flow:**

```
Resource Created         Asset Inventory         Pub/Sub              Agent
in GCP Console          Feed Triggers           Message              Processor
      │                       │                    │                     │
      │  VM with 8x A100      │                    │                     │
      ├──────────────────────►│                    │                     │
      │                       │  Asset Change      │                     │
      │                       ├───────────────────►│                     │
      │                       │                    │  Event Message      │
      │                       │                    ├────────────────────►│
      │                       │                    │                     │
      │                       │                    │                     │  Estimate Cost
      │                       │                    │                     │  $21,432/month
      │                       │                    │                     │
      │                       │                    │                     │  Risk: CRITICAL
      │                       │                    │                     │
      │                       │                    │                 ┌───┴───┐
      │                       │                    │                 │ ALERT │
      │                       │                    │                 └───────┘
```

---

### 5. ML-Powered Recommendations

**Purpose:** Leverage GCP Recommender API for cost optimization suggestions.

**Architecture:**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      ML RECOMMENDATION ENGINE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                   RECOMMENDER TYPES                                    │ │
│  │                                                                        │ │
│  │   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐      │ │
│  │   │   IDLE VM       │  │   RIGHTSIZING   │  │   IDLE DISK     │      │ │
│  │   │   Recommender   │  │   Recommender   │  │   Recommender   │      │ │
│  │   │                 │  │                 │  │                 │      │ │
│  │   │ • 8-day window  │  │ • Usage-based   │  │ • Unattached    │      │ │
│  │   │ • CPU < 1%      │  │ • Machine type  │  │   disks         │      │ │
│  │   │ • Network < 1%  │  │   suggestions   │  │ • Snapshot-only │      │ │
│  │   └─────────────────┘  └─────────────────┘  └─────────────────┘      │ │
│  │                                                                        │ │
│  │   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐      │ │
│  │   │   COMMITMENT    │  │   IDLE SQL      │  │   IDLE ADDRESS  │      │ │
│  │   │   Recommender   │  │   Recommender   │  │   Recommender   │      │ │
│  │   │                 │  │                 │  │                 │      │ │
│  │   │ • CUD analysis  │  │ • Idle Cloud    │  │ • Unused static │      │ │
│  │   │ • 1-year/3-year │  │   SQL instances │  │   IP addresses  │      │ │
│  │   │ • Up to 57% off │  │ • Low queries   │  │ • $7.30/month   │      │ │
│  │   └─────────────────┘  └─────────────────┘  └─────────────────┘      │ │
│  │                                                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                    │                                        │
│                                    ▼                                        │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                   RECOMMENDATION WORKFLOW                              │ │
│  │                                                                        │ │
│  │   ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐           │ │
│  │   │  Fetch  │───►│  Parse  │───►│Prioritize───►│ Present │           │ │
│  │   │  from   │    │  & Map  │    │& Filter │    │ to User │           │ │
│  │   │  API    │    │         │    │         │    │         │           │ │
│  │   └─────────┘    └─────────┘    └─────────┘    └─────────┘           │ │
│  │                                                       │               │ │
│  │                                                       ▼               │ │
│  │                                              ┌─────────────┐          │ │
│  │                                              │  Implement  │          │ │
│  │                                              │  (approval  │          │ │
│  │                                              │   required) │          │ │
│  │                                              └─────────────┘          │ │
│  │                                                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Recommendation Schema:**

```yaml
CostRecommendation:
  recommendation_id: string
  recommendation_type: string  # idle_vm, rightsizing, commitment, etc.
  project_id: string
  resource_name: string
  description: string
  primary_action: string  # stop, resize, delete, purchase_cud
  estimated_monthly_savings: float
  estimated_annual_savings: float
  priority: P1 | P2 | P3 | P4
  state: ACTIVE | CLAIMED | SUCCEEDED | FAILED
  auto_implementable: boolean  # Safe to auto-implement
  risk_level: LOW | MEDIUM | HIGH
```

**Auto-Implementation Rules:**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    AUTO-IMPLEMENTATION CRITERIA                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Recommendation Type      Auto-Implement?    Reason                        │
│   ─────────────────────────────────────────────────────────────────────    │
│   Idle VM (P1/P2)          ✓ YES             Low risk, clear savings        │
│   Idle Disk                ✓ YES             No running workloads           │
│   Idle Address             ✓ YES             Unused, safe to release        │
│   Rightsizing              ✗ NO              Requires downtime              │
│   CUD Purchase             ✗ NO              Financial commitment           │
│   Idle Cloud SQL           ✗ NO              Data preservation risk         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### 6. Anomaly Detection

**Purpose:** Detect unusual spending patterns using statistical analysis.

**Architecture:**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ANOMALY DETECTION                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                   DETECTION METHODS                                    │ │
│  │                                                                        │ │
│  │   1. DAILY SPIKE DETECTION                                            │ │
│  │      ┌────────────────────────────────────────────────────────────┐  │ │
│  │      │  • Calculate 30-day mean and standard deviation            │  │ │
│  │      │  • Flag if today > mean + (2 × std)                        │  │ │
│  │      │  • Severity based on deviation magnitude                   │  │ │
│  │      └────────────────────────────────────────────────────────────┘  │ │
│  │                                                                        │ │
│  │   2. SERVICE SPIKE DETECTION                                          │ │
│  │      ┌────────────────────────────────────────────────────────────┐  │ │
│  │      │  • Per-service historical analysis                          │  │ │
│  │      │  • Identify which service caused the spike                 │  │ │
│  │      │  • Correlate with resource changes                         │  │ │
│  │      └────────────────────────────────────────────────────────────┘  │ │
│  │                                                                        │ │
│  │   3. SUSTAINED INCREASE DETECTION                                     │ │
│  │      ┌────────────────────────────────────────────────────────────┐  │ │
│  │      │  • Compare recent 5-day avg vs historical avg              │  │ │
│  │      │  • Flag if increase > 20% sustained                        │  │ │
│  │      │  • Indicates new baseline, not one-time spike              │  │ │
│  │      └────────────────────────────────────────────────────────────┘  │ │
│  │                                                                        │ │
│  │   4. NEW SERVICE COST DETECTION                                       │ │
│  │      ┌────────────────────────────────────────────────────────────┐  │ │
│  │      │  • Identify services with costs that weren't in history    │  │ │
│  │      │  • Alert if new service cost > $100                        │  │ │
│  │      │  • Verify intentional enablement                           │  │ │
│  │      └────────────────────────────────────────────────────────────┘  │ │
│  │                                                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Statistical Analysis:**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SPIKE DETECTION VISUALIZATION                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Daily Cost ($)                                                            │
│        │                                                                    │
│   $800 │                                            ╭───╮                   │
│        │                                            │   │ ← SPIKE!          │
│        │                                            │   │   (4.2 std dev)   │
│   $600 │                                          ──┤   │                   │
│        │   ══════════════════════════════════════   │   │ ← EMERGENCY       │
│        │         mean + 2 std (CRITICAL)            │   │                   │
│   $400 │   ──────────────────────────────────────   │   │ ← CRITICAL        │
│        │         mean + 1.5 std (WARNING)           │   │                   │
│        │                                            │   │                   │
│   $200 │   ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄  │   │ ← mean            │
│        │                                            ╰───╯                   │
│     $0 └────────────────────────────────────────────────────────────────    │
│           Day 1                              Day 29  Day 30                  │
│                                                                             │
│   Sensitivity Configuration:                                                │
│     LOW:    3.0 standard deviations                                         │
│     MEDIUM: 2.0 standard deviations (default)                               │
│     HIGH:   1.5 standard deviations                                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Anomaly Schema:**

```yaml
CostAnomaly:
  anomaly_id: string
  anomaly_type: DAILY_SPIKE | SERVICE_SPIKE | SUSTAINED_INCREASE | NEW_SERVICE
  severity: INFO | WARNING | CRITICAL | EMERGENCY
  detected_at: datetime
  project_id: string (optional)
  service: string (optional)
  current_cost: float
  expected_cost: float
  deviation_percent: float
  deviation_std: float
  description: string
  recommended_action: string
  related_resources: [string]
```

---

### 7. Conversational Interface

**Purpose:** Natural language queries that replace the need for GCP console expertise.

**Architecture:**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CONVERSATIONAL INTERFACE                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                   INTENT CLASSIFICATION                                │ │
│  │                                                                        │ │
│  │   User Query                            Detected Intent                │ │
│  │   ─────────────────────────────────────────────────────────────────   │ │
│  │   "How much did I spend this month?"    → COST_QUERY                  │ │
│  │   "Why did costs spike?"                → SPIKE_ANALYSIS              │ │
│  │   "How can I save money?"               → RECOMMENDATION              │ │
│  │   "What's my budget status?"            → BUDGET_STATUS               │ │
│  │   "Are there any anomalies?"            → ANOMALY_CHECK               │ │
│  │   "Show circuit breaker status"         → CIRCUIT_BREAKER             │ │
│  │   "Stop the expensive VMs"              → REMEDIATION                 │ │
│  │   "Compare to last month"               → COMPARISON                  │ │
│  │   "What will I spend by month end?"     → FORECAST                    │ │
│  │                                                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                    │                                        │
│                                    ▼                                        │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                   ENTITY EXTRACTION                                    │ │
│  │                                                                        │ │
│  │   "Show costs for project prod-api last week"                         │ │
│  │                      │            │                                    │ │
│  │                      ▼            ▼                                    │ │
│  │              project: prod-api    time: 7 days                         │ │
│  │                                                                        │ │
│  │   Extracted Entities:                                                  │ │
│  │     • project: GCP project ID                                          │ │
│  │     • service: compute, bigquery, etc.                                 │ │
│  │     • amount: dollar amounts                                           │ │
│  │     • time_reference: today, yesterday, last week, etc.               │ │
│  │                                                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                    │                                        │
│                                    ▼                                        │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                   RESPONSE GENERATION                                  │ │
│  │                                                                        │ │
│  │   ┌─────────────────────────────────────────────────────────────────┐│ │
│  │   │ 📊 **Cost Summary for project prod-api** (last 7 days)          ││ │
│  │   │                                                                  ││ │
│  │   │ **Total Spend:** $2,345.67                                      ││ │
│  │   │ **Daily Average:** $335.10                                       ││ │
│  │   │                                                                  ││ │
│  │   │ **Top Services:**                                                ││ │
│  │   │ • Compute Engine: $1,200.00                                     ││ │
│  │   │ • Cloud SQL: $800.00                                            ││ │
│  │   │ • BigQuery: $345.67                                             ││ │
│  │   │                                                                  ││ │
│  │   │ [See breakdown] [Compare to last week] [Find savings]           ││ │
│  │   └─────────────────────────────────────────────────────────────────┘│ │
│  │                                                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Conversation Flow:**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MULTI-TURN CONVERSATION                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   User: "Why did my costs spike this week?"                                 │
│                                                                             │
│   Agent: 🔍 **Cost Spike Analysis**                                         │
│                                                                             │
│          I detected a cost spike on Tuesday (45% above average).            │
│                                                                             │
│          **Root Cause:**                                                    │
│          • 8 new GPU VMs created in project ml-training                     │
│          • Estimated impact: $3,200/day                                     │
│                                                                             │
│          **Recommendation:**                                                │
│          These VMs are using A100 GPUs. Consider:                           │
│          • Using preemptible/spot VMs for training                          │
│          • Setting up auto-shutdown after training completes                │
│                                                                             │
│          Would you like me to stop these VMs?                               │
│          [Yes, stop them] [Schedule shutdown] [Keep running]                │
│                                                                             │
│   ─────────────────────────────────────────────────────────────────────    │
│                                                                             │
│   User: "Yes, stop them"                                                    │
│                                                                             │
│   Agent: ⚠️ **Action Required**                                             │
│                                                                             │
│          I'll stop 8 VMs in project ml-training:                            │
│          • gpu-training-1 through gpu-training-8                            │
│          • This will terminate any running training jobs                    │
│                                                                             │
│          **Estimated savings:** $3,200/day                                  │
│                                                                             │
│          Please confirm: [Approve] [Cancel]                                 │
│                                                                             │
│   ─────────────────────────────────────────────────────────────────────    │
│                                                                             │
│   User: "Approve"                                                           │
│                                                                             │
│   Agent: ✅ **Completed**                                                    │
│                                                                             │
│          Successfully stopped 8 VMs.                                        │
│          Your daily spend should decrease by ~$3,200.                       │
│                                                                             │
│          Would you like me to:                                              │
│          [Set up budget alert] [Create circuit breaker] [View costs]        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## MCP Tool Definitions

```yaml
# Organization Scanning Tools
scan_organization:
  description: Perform complete scan of GCP organization
  parameters:
    include_services: boolean
    include_billing: boolean
  returns: OrganizationScanResult

list_project_services:
  description: List enabled services for a project
  parameters:
    project_id: string
  returns: ServiceList

# Circuit Breaker Tools
get_circuit_breaker_status:
  description: Get current circuit breaker status
  parameters:
    project_id: string (optional)
  returns: CircuitBreakerStatus

configure_circuit_breaker:
  description: Configure circuit breaker thresholds
  parameters:
    project_id: string
    thresholds: ThresholdConfig[]
    enabled: boolean
    dry_run: boolean
  returns: ConfigurationResult

reset_circuit_breaker:
  description: Reset a tripped circuit breaker
  parameters:
    threshold_name: string
    approval_token: string (optional)
  returns: ResetResult

# Budget Tools
create_budget:
  description: Create budget with multi-threshold alerts
  parameters:
    project_id: string
    monthly_budget_usd: float
    alert_thresholds: float[]
    include_forecasted: boolean
  returns: BudgetResult

list_budgets:
  description: List all configured budgets
  returns: BudgetList

# Real-time Tracking Tools
setup_realtime_monitoring:
  description: Configure Cloud Asset Inventory feed
  parameters:
    resource_types: string[]
    pubsub_topic: string
  returns: MonitoringConfig

get_recent_expensive_resources:
  description: Get recently created expensive resources
  parameters:
    hours_back: int
    min_cost_threshold: float
  returns: ResourceEventList

# Recommendation Tools
get_recommendations:
  description: Get ML-powered cost recommendations
  parameters:
    project_id: string (optional)
    min_savings: float
  returns: RecommendationList

implement_recommendation:
  description: Implement a recommendation
  parameters:
    recommendation_id: string
    dry_run: boolean
  returns: ImplementationResult

# Anomaly Detection Tools
detect_anomalies:
  description: Detect cost anomalies
  parameters:
    project_id: string (optional)
    sensitivity: low | medium | high
  returns: AnomalyList

# Conversational Tool
chat:
  description: Process natural language query
  parameters:
    user_id: string
    message: string
    project_id: string (optional)
  returns: ConversationalResponse
```

---

## Data Flow Summary

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         COMPLETE DATA FLOW                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────┐                                                           │
│   │    User     │                                                           │
│   │   Query     │                                                           │
│   └──────┬──────┘                                                           │
│          │                                                                  │
│          ▼                                                                  │
│   ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                  │
│   │   Intent    │────►│   Entity    │────►│   Route to  │                  │
│   │   Classify  │     │   Extract   │     │   Handler   │                  │
│   └─────────────┘     └─────────────┘     └──────┬──────┘                  │
│                                                  │                          │
│          ┌───────────────────────────────────────┼───────────────────┐      │
│          │                                       │                   │      │
│          ▼                                       ▼                   ▼      │
│   ┌─────────────┐                         ┌─────────────┐     ┌───────────┐│
│   │Organization │                         │   Budget    │     │  Anomaly  ││
│   │  Scanner    │                         │   Monitor   │     │  Detector ││
│   └──────┬──────┘                         └──────┬──────┘     └─────┬─────┘│
│          │                                       │                   │      │
│          ▼                                       ▼                   ▼      │
│   ┌─────────────┐                         ┌─────────────┐     ┌───────────┐│
│   │  Resource   │                         │   Budget    │     │ Historical││
│   │  Manager    │                         │    API      │     │   Costs   ││
│   │    API      │                         └─────────────┘     │ (BigQuery)││
│   └─────────────┘                                             └───────────┘│
│          │                                                                  │
│          ▼                                                                  │
│   ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                  │
│   │  Service    │────►│  Billing    │────►│ Recommender │                  │
│   │  Usage API  │     │    API      │     │    API      │                  │
│   └─────────────┘     └─────────────┘     └──────┬──────┘                  │
│                                                  │                          │
│          ┌───────────────────────────────────────┘                          │
│          │                                                                  │
│          ▼                                                                  │
│   ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                  │
│   │   Aggregate │────►│   Format    │────►│   Return    │                  │
│   │   Results   │     │   Response  │     │   to User   │                  │
│   └─────────────┘     └─────────────┘     └─────────────┘                  │
│                                                                             │
│                              ┌───────────┐                                  │
│                              │  Circuit  │◄── Continuous Monitoring         │
│                              │  Breaker  │                                  │
│                              └─────┬─────┘                                  │
│                                    │                                        │
│                                    ▼                                        │
│                           ┌───────────────┐                                 │
│                           │ Auto-Actions  │                                 │
│                           │ (if tripped)  │                                 │
│                           └───────────────┘                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## IAM Requirements

```yaml
Required Permissions:
  
  Organization Level:
    - resourcemanager.organizations.get
    - resourcemanager.folders.list
    - cloudasset.assets.searchAllResources
    - cloudasset.feeds.create
  
  Folder Level:
    - resourcemanager.folders.get
  
  Project Level:
    - resourcemanager.projects.list
    - resourcemanager.projects.get
    - serviceusage.services.list
    - recommender.computeInstanceIdleResourceRecommendations.list
    - recommender.computeInstanceMachineTypeRecommendations.list
    - compute.instances.list
    - compute.instances.stop
    - compute.instances.start
  
  Billing Level:
    - billing.accounts.get
    - billing.budgets.create
    - billing.budgets.list
    - billing.budgets.update
    - billing.resourceCosts.get

Recommended Custom Role:
  name: CostMonitoringAgent
  permissions:
    - All above permissions
```

---

## Summary

This architectural design provides a comprehensive GCP cost monitoring solution that:

| Component | Key Capability |
|-----------|----------------|
| **Organization Scanner** | Complete visibility via Resource Manager + Service Usage APIs |
| **Circuit Breaker** | Automatic cost control with multi-threshold protection |
| **Budget Monitor** | Proactive alerts including forecasted spend |
| **Real-time Tracker** | Instant notification of expensive resource creation |
| **ML Recommendations** | Intelligent optimization suggestions from Recommender API |
| **Anomaly Detection** | Statistical analysis to flag unusual patterns |
| **Conversational Interface** | Natural language queries replacing console expertise |

The architecture enables SMB owners to maintain cloud cost control without requiring deep GCP expertise.
