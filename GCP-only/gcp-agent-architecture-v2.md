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

```mermaid
flowchart TD
    UI[User Interface Layer]
    MCP[MCP Server Layer (Port ${MCP_SERVER_PORT})]
    GCP[GCP API Layer]

    UI -->|Conversational Interface| MCP
    MCP -->|Organization Scanner| GCP
    MCP -->|Circuit Breaker| GCP
    MCP -->|Budget Monitor| GCP
    MCP -->|Anomaly Detector| GCP

    subgraph UI
        UI1[Conversational Interface]
    end

    subgraph MCP
        ORG[Organization Scanner]
        CB[Circuit Breaker]
        BUD[Budget Monitor]
        ANOM[Anomaly Detector]
    end

    subgraph GCP
        RM[Resource Manager API]
        SU[Service Usage API]
        BA[Budget API]
        CA[Cloud Asset Inventory]
        BQ[BigQuery]
        CF[Compute Engine]
        PUB[Pub/Sub]
    end

    ORG --> RM
    ORG --> SU
    CB --> BA
    BUD --> PUB
    ANOM --> BQ

    RM --> CF
    SU --> CF
    CA --> PUB
    BQ --> PUB
```

**Legend**: arrows indicate data flow direction between components.
```mermaid
flowchart TD
    UI[User Interface]
    IC[Intent Classification]
    EE[Entity Extraction]
    CM[Context Management]
    RESP[Response]
    UI --> IC --> RESP
    UI --> EE --> "Actions"
    UI --> CM --> "Approvals"
```

**Legend**: arrows show the processing pipeline for user queries.

```mermaid
graph TD
    ORG[Organization Scanner]
    CB[Circuit Breaker]
    BUD[Budget Monitor]
    ANOM[Anomaly Detector]

    ORG --> CB
    ORG --> BUD
    ORG --> ANOM
```

**Legend**: arrows show data flow between core components within the MCP server layer.



```mermaid
flowchart LR
    AT[Asset Feed] --> RT[Real‑time Tracker]
    RT -->|Idle VM detection| IDLE[Idle VMs]
    RT -->|Rightsizing suggestions| RS[Rightsizing]
    RT -->|Cost forecasts| CF[Forecasts]
    RT -->|Scale actions| SC[Scale]
    RT -->|Delete resources| DEL[Delete]
```

**Legend**: arrows indicate data flow from the asset feed to various real‑time management actions.

```mermaid
flowchart LR
    RM[Resource Manager API]
    SU[Service Usage API]
    BA[Budget API]
    CA[Cloud Asset Inventory]
    RE[Recommender API]
    BIL[Billing API]
    CE[Compute Engine API]
    PS[Pub/Sub]
    BQ[BigQuery (Export)]
    RM --> CE
    SU --> CE
    CA --> PS
    BQ --> PS
    BA --> RE
    RE --> PS
    BIL --> RE
```

**Legend**: arrows indicate data flow between GCP services used by the agent.


---

## Component Architecture

### 1. Organization Scanner

**Purpose:** Discover all projects and enabled services across the GCP organization.

**Method:** Resource Manager API + Service Usage API (detailed enumeration)


```mermaid
graph TD
    Org[Organization: 123456789] -->|contains| FolderProd[Folder: Production]
    Org -->|contains| FolderDev[Folder: Development]
    FolderProd -->|projects| ProjWeb[Project: prod-web-app]
    FolderProd -->|projects| ProjAPI[Project: prod-api]
    FolderDev -->|projects| DevWeb[Project: dev-web-app]
    FolderDev -->|projects| DevML[Project: dev-ml-training]
    Org -->|projects| Shared[Project: shared-services]
```

**Legend**: arrows show containment hierarchy (organization → folders → projects).



**Data Flow:**


```mermaid
flowchart LR
    RM[Resource Manager API] --> SU[Service Usage API] --> BA[Billing API] --> SR[Scan Result]
    RM -->|folders| Folders
    SU -->|services| Services
    BA -->|accounts| BillingAccounts
    SR -->|enriched| EnrichedProjects
```

**Legend**: arrows indicate data flow between components of the budget monitoring pipeline.


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


```mermaid
flowchart TD
    subgraph Thresholds["Threshold Configuration"]
        L1[Level 1: WARNING $1,000/day → Alert Only]
        L2[Level 2: ELEVATED $2,500/day → Alert Only]
        L3[Level 3: CRITICAL $5,000/day → Stop High-Cost Resources]
        L4[Level 4: EMERGENCY $10,000/day → Disable Billing]
    end
    
    subgraph StateMachine["State Machine"]
        CLOSED[CLOSED normal]
        OPEN[OPEN tripped]
        HALF[HALF-OPEN testing]
        
        CLOSED -->|threshold exceeded| OPEN
        OPEN -->|reset| HALF
        HALF -->|reset| CLOSED
        OPEN -->|cooldown expires| CLOSED
    end
    
    subgraph Actions["Trip Actions"]
        ALERT[ALERT_ONLY<br/>Send alerts to Slack, email, PagerDuty]
        STOP[STOP_RESOURCES<br/>Stop VMs, Vertex endpoints, jobs]
        SCALE[SCALE_DOWN<br/>Scale GKE to 0 nodes, reduce DB instances]
        DISABLE[DISABLE_BILLING<br/>Remove billing account association]
    end
    
    Thresholds --> StateMachine
    StateMachine --> Actions
```

**Legend**: diagram shows the three components of the circuit breaker: threshold configuration, state machine transitions, and available trip actions.

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

```mermaid
flowchart LR
    COST[Current Cost<br/>from API] --> COMPARE[Compare Against<br/>Thresholds]
    COMPARE --> CHECK[Check Cooldown<br/>& Override]
    CHECK --> EXEC[Execute Action]
    EXEC --> ACTIONS
    
    subgraph ACTIONS["Action Execution"]
        direction TB
        A1[ALERT_ONLY: Send notifications]
        A2[STOP_RESOURCES: Stop VMs, endpoints, jobs]
        A3[SCALE_DOWN: Scale GKE, reduce DB instances]
        A4[DISABLE_BILLING: Remove billing account]
    end
```

**Legend**: flowchart shows the circuit breaker decision pipeline from cost comparison to action execution.

---

### 3. Proactive Budget Monitoring

**Purpose:** Create and monitor budgets with multi-threshold alerts including forecasted spend.

**Architecture:**

```mermaid
flowchart TD
    subgraph Thresholds["Multi-Threshold Alerts (Budget: $10,000/month)"]
        T1["120% ($12,000) EMERGENCY"]
        T2["100% ($10,000) CRITICAL"]
        T3["90% ($9,000) CRITICAL"]
        T4["80% ($8,000) FORECASTED"]
        T5["70% ($7,000) WARNING"]
        T6["50% ($5,000) INFO"]
    end
    
    CURRENT[Current Spend] --> Thresholds
    FORECAST[Forecasted Spend] --> Thresholds
    
    Thresholds --> FLOW
    
    subgraph FLOW["Notification Flow"]
        BA[Budget API] --> PS[Pub/Sub Topic]
        PS --> CF[Cloud Function]
        CF --> AG[Agent]
        BA -->|if threshold >= 100%| CB[Circuit Breaker]
    end
```

**Legend**: diagram shows budget thresholds, dual sources (current + forecasted spend), and notification flow to the agent and circuit breaker.

**Budget Types:**

```mermaid
flowchart LR
    subgraph BT["Budget Types"]
        direction TB
        P["1. PROJECT BUDGET<br/>Scope: Single project<br/>Use: Default protection<br/>Example: prod-web-app → $5K/month"]
        S["2. SERVICE BUDGET<br/>Scope: Specific GCP services<br/>Use: Control expensive services<br/>Example: Vertex AI → $10K/month"]
        L["3. LABEL BUDGET<br/>Scope: Resources with labels<br/>Use: Team/environment budgets<br/>Example: team=ml-research → $20K/month"]
        O["4. ORGANIZATION BUDGET<br/>Scope: Entire organization<br/>Use: Global cost cap<br/>Example: All projects → $100K/month"]
    end
```

**Legend**: four types of budgets available in the GCP cost monitoring system.

---

### 4. Real-time Resource Tracking

**Purpose:** Instantly detect creation of expensive resources via Cloud Asset Inventory feeds.

**Architecture:**

```mermaid
flowchart TD
    subgraph Feed["Cloud Asset Inventory Feed (Scope: organizations/123456789)"]
        Types["Asset Types:<br/>• compute/Instance<br/>• compute/Disk<br/>• sqladmin/Instance<br/>• container/Cluster<br/>• aiplatform/Endpoint<br/>• aiplatform/CustomJob<br/>• dataflow/Job"]
    end
    
    Feed -->|Asset Change Events| Topic[Pub/Sub Topic<br/>projects/my-project/topics/gcp-resource-changes]
    Topic --> Proc
    
    subgraph Proc["Event Processor"]
        P1["1. Parse asset change event"]
        P2["2. Determine event type (CREATE, UPDATE, DELETE)"]
        P3["3. Extract resource details (type, project, location)"]
        P4["4. Estimate monthly cost"]
        P5["5. Assess risk level"]
        P6["6. Trigger alerts if high-cost"]
        P1 --> P2 --> P3 --> P4 --> P5 --> P6
    end
    
    Proc --> Est
    
    subgraph Est["Cost Estimation"]
        E1["VM Instance: machine_type → pricing table + GPU costs"]
        E2["Cloud SQL: tier → pricing table × HA multiplier"]
        E3["GKE Cluster: mgmt fee + (node_count × VM cost)"]
        E4["Vertex Endpoint: base prediction cost estimate"]
        E5["Vertex CustomJob: worker_specs × GPU costs × est. hours"]
        E6["Dataflow Job: vCPU/memory hours estimate"]
    end
```

**Legend**: the pipeline shows how asset changes flow from Cloud Asset Inventory through event processing to cost estimation and alerting.

**GPU Pricing Reference:**

| GPU Type | Hourly Cost | Monthly (730 hrs) |
|----------|-------------|-------------------|
| NVIDIA T4 | $0.35 | $255 |
| NVIDIA L4 | $0.55 | $401 |
| NVIDIA P4 | $0.60 | $438 |
| NVIDIA P100 | $1.46 | $1,066 |
| NVIDIA V100 | $2.48 | $1,810 |
| NVIDIA A100 (40GB) | $3.67 | $2,679 |
| NVIDIA H100 (80GB) | $10.20 | $7,446 |

**Alert Trigger:** Any resource with estimated cost > $500/month

**Event Flow:**

```mermaid
sequenceDiagram
    participant Console as Resource Created<br/>in GCP Console
    participant Feed as Asset Inventory<br/>Feed Triggers
    participant PubSub as Pub/Sub<br/>Message
    participant Agent as Agent<br/>Processor
    
    Console->>Feed: VM with 8x A100
    Feed->>PubSub: Asset Change
    PubSub->>Agent: Event Message
    Note over Agent: Estimate Cost<br/>$21,432/month
    Note over Agent: Risk: CRITICAL
    Agent->>Agent: ALERT
```

**Legend**: sequence diagram showing real-time flow from resource creation to alert generation.

---

### 5. ML-Powered Recommendations

**Purpose:** Leverage GCP Recommender API for cost optimization suggestions.

**Architecture:**

```mermaid
flowchart TD
    subgraph Recommenders["Recommender Types"]
        IV["Idle VM Recommender<br/>• 8-day window<br/>• CPU < 1%<br/>• Network < 1%"]
        RS["Rightsizing Recommender<br/>• Usage-based<br/>• Machine type<br/>suggestions"]
        ID["Idle Disk Recommender<br/>• Unattached disks<br/>• Snapshot-only"]
        CM["Commitment Recommender<br/>• CUD analysis<br/>• 1-year/3-year<br/>• Up to 57% off"]
        IS["Idle SQL Recommender<br/>• Idle Cloud SQL<br/>instances<br/>• Low queries"]
        IA["Idle Address Recommender<br/>• Unused static IPs<br/>• $7.30/month"]
    end
    
    Recommenders --> Workflow
    
    subgraph Workflow["Recommendation Workflow"]
        Fetch[Fetch from API] --> Parse[Parse & Map]
        Parse --> Prior[Prioritize & Filter]
        Prior --> Present[Present to User]
        Present --> Impl[Implement<br/>approval required]
    end
```

**Legend**: diagram shows six recommendation types and their processing workflow from API fetch to implementation.

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
| Recommendation Type | Auto-Implement? | Reason |
|---------------------|-----------------|--------|
| Idle VM (P1/P2) | ✓ YES | Low risk, clear savings |
| Idle Disk | ✓ YES | No running workloads |
| Idle Address | ✓ YES | Unused, safe to release |
| Rightsizing | ✗ NO | Requires downtime |
| CUD Purchase | ✗ NO | Financial commitment |
| Idle Cloud SQL | ✗ NO | Data preservation risk |
```

---

### 6. Anomaly Detection

**Purpose:** Detect unusual spending patterns using statistical analysis.

**Architecture:**

```
```mermaid
graph TD
    Daily[Daily Spike Detection]
    Service[Service Spike Detection]
    Sustained[Sustained Increase Detection]
    NewService[New Service Cost Detection]

    Daily -->|30‑day mean+2σ| Flag[Flag Spike]
    Service -->|Per‑service analysis| Flag
    Sustained -->|5‑day avg vs historic| Flag
    NewService -->|Cost > $100| Flag
```

**Legend**: each detection method feeds into a common flagging step that triggers alerts.
```mermaid
flowchart TD
    subgraph Detection["Anomaly Detection System"]
        D1["1. DAILY SPIKE DETECTION<br/>• Calculate 30-day mean and std dev<br/>• Flag if today > mean + (2 × std)<br/>• Severity based on deviation magnitude"]
        D2["2. SERVICE SPIKE DETECTION<br/>• Per-service historical analysis<br/>• Identify which service caused the spike<br/>• Correlate with resource changes"]
        D3["3. SUSTAINED INCREASE DETECTION<br/>• Compare recent 5-day avg vs historical avg<br/>• Flag if increase > 20% sustained<br/>• Indicates new baseline, not one-time spike"]
        D4["4. NEW SERVICE COST DETECTION<br/>• Identify services with costs that weren't in history<br/>• Alert if new service cost > $100<br/>• Verify intentional enablement"]
    end
```

**Legend**: the four primary methods used by the agent to detect cost anomalies.
```

**Statistical Analysis:**

```
```mermaid
xychart-beta
    title "Daily Cost with Spike Detection Support"
    x-axis [Day 1, Day 5, Day 10, Day 15, Day 20, Day 25, Day 30]
    y-axis "Cost ($)" 0 --> 800
    bar [150, 160, 155, 140, 150, 165, 750]
    line [160, 160, 160, 160, 160, 160, 160]
```

**Legend**: visualization of a cost spike exceeding the standard deviation threshold (simulated data).

**Sensitivity Configuration:**
- **LOW**: 3.0 standard deviations
- **MEDIUM**: 2.0 standard deviations (default)
- **HIGH**: 1.5 standard deviations
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
```mermaid
flowchart TD
    UI[Conversational Interface]
    Intent[Intent Classification]
    Entity[Entity Extraction]
    Response[Response Generation]

    UI --> Intent
    Intent --> Entity
    Entity --> Response
```

**Legend**: arrows show the processing pipeline from user query to generated response.
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
```mermaid
sequenceDiagram
    participant U as User
    participant A as Agent
    
    U->>A: "Why did my costs spike this week?"
    Note over A: 🔍 Cost Spike Analysis<br/>Detected spike on Tuesday (45% above avg)
    A->>U: Root Cause: 8 new GPU VMs created in project ml-training<br/>Est. impact: $3,200/day<br/>Recommendation: Use spot VMs or auto-shutdown.<br/>Would you like me to stop these VMs?
    
    U->>A: "Yes, stop them"
    Note over A: ⚠️ Action Required<br/>Stopping 8 VMs in project ml-training<br/>Est. savings: $3,200/day
    A->>U: Please confirm: [Approve] [Cancel]
    
    U->>A: "Approve"
    Note over A: ✅ Completed<br/>Successfully stopped 8 VMs.<br/>Daily spend should decrease by ~$3,200.
    A->>U: Would you like me to: [Set budget] [Circuit breaker]
```

**Legend**: multi-turn conversation showing diagnosis, recommendation, and action confirmation.
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
