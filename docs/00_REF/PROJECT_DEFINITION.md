# AI Cloud Cost Monitoring — Project Definition

**Document:** PROJECT_DEFINITION.md
**Version:** 1.0.0
**Date:** 2026-02-07T00:00:00
**Status:** Approved

---

## Executive Summary

**AI Cloud Cost Monitoring** is an AI-agent-powered FinOps platform that provides intelligent cloud cost analysis, optimization recommendations, and automated remediation across AWS, Azure, GCP, and Kubernetes.

**Core Differentiator:** The platform uses **AI agents with MCP (Model Context Protocol) servers** as the primary integration pattern—not traditional REST API calls. Users interact with the system through natural language, and AI agents orchestrate all cloud operations.

---

## Project Purpose

### Problem Statement

Organizations face challenges with multi-cloud cost management:

| Challenge | Impact |
|-----------|--------|
| Fragmented visibility | Costs scattered across AWS, Azure, GCP consoles |
| Manual analysis | Time-consuming, requires deep expertise |
| Reactive optimization | Issues discovered after budget overruns |
| No unified interface | Different tools for different clouds |

### Solution

An AI-driven platform where:

1. **Users ask questions in natural language** → "Why did AWS costs spike last week?"
2. **AI agents analyze and respond** → Coordinator routes to specialized agents
3. **Agents use MCP tools** → Not REST APIs, but AI-native MCP protocol
4. **Real-time streaming UI** → Progressive updates as agents work

---

## Architecture Philosophy

### AI Agents as First-Class Citizens

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              USER INTERFACE                                  │
│                     Natural Language Chat (CopilotKit)                       │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           AI AGENT LAYER                                     │
│  ┌─────────────────┐                                                        │
│  │   COORDINATOR   │ ← Single entry point, intent classification            │
│  └────────┬────────┘                                                        │
│           │                                                                  │
│  ┌────────┴────────────────────────────────────────────────────────────┐   │
│  │                      DOMAIN AGENTS (6)                               │   │
│  │  Cost │ Optimization │ Remediation │ Reporting │ Tenant │ Cross-Cloud│   │
│  └────────┬────────────────────────────────────────────────────────────┘   │
│           │                                                                  │
│  ┌────────┴────────────────────────────────────────────────────────────┐   │
│  │                    CLOUD PROVIDER AGENTS (4)                         │   │
│  │           AWS Agent │ Azure Agent │ GCP Agent │ K8s Agent            │   │
│  └────────┬────────────────────────────────────────────────────────────┘   │
└───────────┼─────────────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          MCP SERVER LAYER                                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   AWS MCP   │  │  Azure MCP  │  │   GCP MCP   │  │ OpenCost MCP│        │
│  │   Server    │  │   Server    │  │   Server    │  │   Server    │        │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘        │
│         │                │                │                │                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Forecast MCP│  │Remediation  │  │  Policy MCP │  │  Tenant MCP │        │
│  │   Server    │  │ MCP Server  │  │   Server    │  │   Server    │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CLOUD PROVIDER APIs                                  │
│       AWS Cost Explorer │ Azure Cost Management │ GCP Billing │ OpenCost    │
└─────────────────────────────────────────────────────────────────────────────┘
```

### MCP Servers — Not REST APIs

**Why MCP instead of REST?**

| Aspect | REST API | MCP Server |
|--------|----------|------------|
| Designed for | Web applications | AI agents |
| Schema | OpenAPI (manual) | Auto-generated from code |
| State | Session-based | Stateless, cacheable |
| Error handling | HTTP status codes | Structured error envelopes |
| AI integration | Requires wrapper | Native tool calling |

**MCP Server Strategy:**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        MCP SERVER SOURCING                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  OPTION 1: Provider-Native MCP Servers (Preferred)                          │
│  ────────────────────────────────────────────────                           │
│  When cloud providers offer official MCP servers, use them directly:        │
│  • Maintained by provider                                                   │
│  • Automatic API updates                                                    │
│  • Official support                                                         │
│                                                                              │
│  OPTION 2: Custom-Developed MCP Servers (Fallback)                          │
│  ─────────────────────────────────────────────────                          │
│  When no provider MCP exists, we build our own:                             │
│  • Wrap provider REST APIs in MCP protocol                                  │
│  • Use FastMCP framework                                                    │
│  • Maintain parity across all cloud MCP servers                             │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Current Status (2026-02):                                           │   │
│  │                                                                       │   │
│  │  AWS MCP     → Custom (wraps Cost Explorer, Compute Optimizer)       │   │
│  │  Azure MCP   → Custom (wraps Cost Management API)                    │   │
│  │  GCP MCP     → Custom (wraps Cloud Billing, Recommender)             │   │
│  │  OpenCost MCP→ Custom (wraps OpenCost API for Kubernetes)            │   │
│  │                                                                       │   │
│  │  Note: As providers release official MCP servers, migrate to them.   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Unified MCP Tool Contracts

All cloud MCP servers implement identical tool signatures for agent interoperability:

```python
# Every cloud MCP server exposes these tools:
tools = [
    "get_costs",           # Retrieve cost data with filters
    "get_resources",       # List cloud resources
    "get_recommendations", # Fetch optimization recommendations
    "execute_remediation", # Perform corrective actions
    "get_budget_status",   # Check budget thresholds
    "get_forecast",        # Predict future costs
    "get_usage_metrics",   # Resource utilization data
    "compare_periods",     # Period-over-period analysis
]
```

---

## Infrastructure Architecture

### Home Cloud vs Monitored Clouds

| Concept | Definition | Current Choice |
|---------|------------|----------------|
| **Home Cloud** | Where platform infrastructure runs | GCP |
| **Monitored Clouds** | What clouds the platform analyzes | AWS, Azure, GCP, Kubernetes |

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         HOME CLOUD: GCP                                      │
│              (Platform Infrastructure - AI Agents Run Here)                  │
│                                                                              │
│  Cloud Run (Agents + MCP Servers) │ BigQuery │ Firestore │ Secret Manager   │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       │ AI Agents query via MCP
                                       │
        ┌──────────────────────────────┼──────────────────────────────┐
        ▼                              ▼                              ▼
┌───────────────┐             ┌───────────────┐             ┌───────────────┐
│     AWS       │             │    AZURE      │             │  KUBERNETES   │
│  (Monitored)  │             │  (Monitored)  │             │  (Monitored)  │
│               │             │               │             │               │
│ Cost Explorer │             │Cost Management│             │   OpenCost    │
│ Compute Opt.  │             │    Advisor    │             │   Metrics     │
└───────────────┘             └───────────────┘             └───────────────┘

        ▲
        │
┌───────────────┐
│     GCP       │  ◄── GCP is BOTH home cloud AND monitored
│  (Monitored)  │
│               │
│ Billing Export│
│  Recommender  │
└───────────────┘
```

---

## Operational Modes

The platform operates in **four distinct modes** that work together:

### Mode 1: Interactive (On-Demand via UX)

User-driven queries through natural language chat interface.

```text
User Query → CopilotKit → AG-UI Server → Coordinator Agent
                                              │
                                              ▼
                                        Domain Agents
                                              │
                                              ▼
                                    Cloud Agents (parallel)
                                              │
                                              ▼
                                        MCP Servers
                                              │
                                              ▼
                                        Cloud APIs
                                              │
                                              ▼
                                   Streaming Response (A2UI)
```

**Characteristics:**
- Trigger: User action (natural language query)
- Latency: 2-5 seconds
- Data source: Pre-synced local DB (from Mode 2), fallback to live API
- Examples: "Why did AWS costs spike?", "Show idle resources"

### Mode 2: Scheduled (Background Data Export)

Automated pipeline that syncs cloud data on schedule, keeping local database fresh.

```text
Cloud Scheduler → Cloud Tasks → Sync Service → Cloud APIs
                                                    │
                                                    ▼
                                    BigQuery (cost data)
                                    Firestore (metadata)
```

**Schedule:**

| Job | Frequency | Purpose |
|-----|-----------|---------|
| Cost Data Sync | Every 4 hours | Pull latest cost metrics |
| Resource Inventory | Every 6 hours | Discover resources |
| Anomaly Detection | Every 4 hours | Flag spending spikes |
| Recommendation Refresh | Daily 2 AM | Recalculate optimizations |
| Forecast Update | Daily 3 AM | ML spend predictions |

**Why This Mode Exists:**
- Cloud billing APIs have 4-24 hour data delay
- Pre-syncing enables instant interactive responses
- Reduces API calls and costs

### Mode 3: Event-Driven (Push Alerts from Clouds)

Real-time response to cloud provider alerts via webhooks.

```text
Cloud Event → Webhook Endpoint → Event Processor → Policy Check
                                                        │
                                          ┌─────────────┴─────────────┐
                                          ▼                           ▼
                                    Notification              Auto-Remediate
                                  (Slack/Email)              (if policy allows)
```

**Event Sources:**

| Cloud | Mechanism | Events |
|-------|-----------|--------|
| AWS | CloudWatch → SNS → Webhook | Budget threshold, anomaly |
| Azure | Azure Monitor → Action Group | Budget alerts, Advisor |
| GCP | Cloud Monitoring → Pub/Sub | Budget notifications |
| K8s | Prometheus Alertmanager | Pod OOM, quota exceeded |

### Mode 4: A2A (Agent-to-Agent Requests)

External AI agents initiate queries through A2A Protocol gateway.

```text
External Agent → A2A Gateway → Auth Check (mTLS/API Key)
                                        │
                                        ▼
                              Coordinator Agent
                                        │
                                        ▼
                              (Same flow as Mode 1)
```

**External Agent Types:**
- SlackBot Agent — Team cost questions in Slack
- Compliance Auditor — Nightly policy scans
- Vendor Advisor — Savings opportunity checks

**Security:**
- Pre-registered agents only
- Read-only by default
- Rate limited: 10 req/min per agent

### How Modes Work Together

```text
Example Scenario: AWS Cost Spike

1. MODE 2 (2:00 AM): Scheduled sync detects 40% EC2 cost increase
   └── Stores anomaly in database, generates recommendations

2. MODE 3 (7:30 AM): AWS Budget alarm fires at 80% threshold
   └── Webhook received, Slack alert sent to finance team

3. MODE 1 (9:00 AM): Admin asks "Why did AWS costs spike?"
   └── Agent instantly has data from Mode 2 + anomaly flagged
   └── Shows 12 over-provisioned instances with one-click fix

4. REMEDIATION: Admin clicks "Rightsize all 12"
   └── Approval workflow triggers, operator approves
   └── AWS Agent executes via MCP, audit logged

Result: $12,400/month savings — all modes contributed
```

---

## User Interaction Model

### AI-First Interface

Users interact with the platform through natural language:

```
User: "Why did our AWS costs increase 40% last month?"

┌─────────────────────────────────────────────────────────────────────────────┐
│ COORDINATOR AGENT                                                            │
│ → Classifies intent: cost_analysis                                          │
│ → Routes to: Cost Agent                                                     │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ COST AGENT                                                                   │
│ → Needs AWS-specific data                                                   │
│ → Delegates to: AWS Agent                                                   │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ AWS AGENT                                                                    │
│ → Calls MCP tools: get_costs(), compare_periods()                           │
│ → Uses: AWS MCP Server                                                      │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ AWS MCP SERVER                                                               │
│ → Retrieves credentials from Secret Manager                                 │
│ → Calls AWS Cost Explorer API                                               │
│ → Returns structured cost data                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ RESPONSE (Streaming via AG-UI)                                               │
│                                                                              │
│ "Your AWS costs increased 40% ($12,400 → $17,360) primarily due to:         │
│  1. EC2 instances: +$3,200 (new production cluster launched 2/15)           │
│  2. S3 storage: +$1,100 (video assets bucket grew 2TB)                      │
│  3. Data transfer: +$660 (API traffic spike during campaign)                │
│                                                                              │
│  Recommendations:                                                            │
│  • Consider Reserved Instances for the new EC2 cluster (save ~$800/mo)      │
│  • Enable S3 Intelligent Tiering for video assets (save ~$200/mo)"          │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Dual Interface Strategy

| Interface | Purpose | Technology |
|-----------|---------|------------|
| **CopilotKit Chat** | Natural language queries, ad-hoc analysis | AG-UI protocol, SSE streaming |
| **Grafana Dashboards** | Pre-built visualizations, monitoring | Native BigQuery connector |

---

## Key Capabilities

### Cost Monitoring

- Unified view across AWS, Azure, GCP, Kubernetes
- Real-time cost tracking with 4-hour sync
- Anomaly detection and spike alerts
- Tag-based cost allocation
- ML-powered forecasting

### Optimization

- AI-driven rightsizing recommendations
- Idle resource detection
- Reserved instance planning
- Cross-cloud price comparison

### Remediation

- One-click optimization actions
- Approval workflows for sensitive changes
- Scheduled resource operations
- Rollback capability

---

## Technology Stack Summary

| Layer | Technology | Purpose |
|-------|------------|---------|
| **UI** | CopilotKit + Next.js | Natural language chat interface |
| **Agents** | Google ADK + LiteLLM | AI agent orchestration |
| **MCP Servers** | FastMCP | Cloud integration via MCP protocol |
| **Analytics** | BigQuery | Cost data storage and queries |
| **Config** | Firestore (MVP) → PostgreSQL | Operational data |
| **Secrets** | GCP Secret Manager | Cloud credentials |
| **Compute** | Cloud Run | Serverless container hosting |
| **Dashboards** | Grafana | Pre-built cost visualizations |

---

## MVP Scope

| Aspect | Decision |
|--------|----------|
| Tenancy | Single-tenant |
| Home Cloud | GCP |
| Database | Firestore + BigQuery (no PostgreSQL) |
| Monitored Clouds | AWS, Azure, GCP, Kubernetes |
| Monthly Cost | ~$0-10 (free tiers) |

---

## Scope Clarification

### What This Project IS

| Category | Description |
|----------|-------------|
| **AI-Agent Platform** | AI agents handle all user interactions and cloud operations |
| **MCP-First Integration** | Cloud integrations via MCP servers, not direct REST calls |
| **Cost Monitoring Tool** | Tracks, analyzes, and optimizes cloud costs |
| **Multi-Cloud Capable** | Monitors AWS, Azure, GCP, Kubernetes from single interface |
| **Natural Language Interface** | Users ask questions in plain English |
| **Self-Hosted** | Runs on your own GCP project |

### What This Project is NOT

| Category | Clarification |
|----------|---------------|
| **Not a SaaS product** | Self-hosted on your infrastructure (MVP) |
| **Not a REST API backend** | Agents use MCP protocol, not traditional APIs |
| **Not cloud-agnostic deployment** | Home cloud is GCP (monitoring is multi-cloud) |
| **Not real-time streaming costs** | Cost sync every 4 hours (cloud API limitation) |
| **Not a replacement for cloud consoles** | Complements, doesn't replace native tools |

### Key Decisions (Locked)

| Decision | Choice | Rationale | ADR |
|----------|--------|-----------|-----|
| Integration Pattern | MCP Servers | AI-native, better DX than REST | ADR-001 |
| Home Cloud | GCP | Best free tier, scale-to-zero | ADR-002 |
| Analytics DB | BigQuery | Native billing export, 1TB free | ADR-003 |
| Compute | Cloud Run | Serverless, scale-to-zero | ADR-004 |
| MVP Database | Firestore | No PostgreSQL until multi-tenant | ADR-008 |
| Agent Framework | Google ADK + LiteLLM | Vendor-neutral LLM support | — |
| UI Framework | CopilotKit + Next.js | AG-UI protocol support | — |

### Open Questions (To Be Decided)

| Question | Options | Status |
|----------|---------|--------|
| Default LLM provider | Gemini 2.0, Claude 3.5, GPT-4 | User configurable via LiteLLM |
| Authentication provider | Auth0, GCP Identity Platform, Okta | To be decided |
| Grafana deployment | Self-hosted vs Grafana Cloud | To be decided |
| OpenCost integration | Prometheus vs direct API | To be decided |

### MVP Success Criteria

| Criterion | Metric |
|-----------|--------|
| **Cost Query** | User asks "What's my AWS spend this month?" → Agent responds with data |
| **Multi-Cloud** | Single query returns data from 2+ cloud providers |
| **Streaming UI** | Response streams progressively (not all-at-once) |
| **Recommendations** | Agent provides at least 1 optimization suggestion |
| **Cost Threshold** | System within $10/month infrastructure cost |

### Common Misconceptions

| Misconception | Reality |
|---------------|---------|
| "Agents call REST APIs directly" | Agents call MCP servers; MCP servers wrap REST APIs |
| "Need PostgreSQL for MVP" | Firestore + BigQuery sufficient for single-tenant |
| "Must use all 11 agents" | MVP can start with Coordinator + 1 Cloud Agent |
| "Real-time cost updates" | Cloud APIs have 4-24 hour delay; we sync every 4 hours |
| "Runs on any cloud" | Platform runs on GCP; monitors any cloud |

### Terminology

| Term | Definition |
|------|------------|
| **Home Cloud** | Where platform infrastructure runs (GCP) |
| **Monitored Cloud** | Clouds being analyzed for costs (AWS, Azure, GCP, K8s) |
| **MCP Server** | Tool server that agents call (Model Context Protocol) |
| **AG-UI** | Agent-to-UI streaming protocol (SSE-based) |
| **Domain Agent** | High-level agent for a capability (Cost, Optimization, etc.) |
| **Cloud Agent** | Cloud-specific agent (AWS Agent, Azure Agent, etc.) |

---

## Related Documents

- [MVP_ARCHITECTURE.md](domain/architecture/MVP_ARCHITECTURE.md) — Simplified MVP stack
- [ADR-001](domain/architecture/adr/001-use-mcp-servers.md) — MCP over REST decision
- [ADR-002](domain/architecture/adr/002-gcp-only-first.md) — GCP as home cloud
- [core/02-mcp-tool-contracts.md](core/02-mcp-tool-contracts.md) — MCP tool specifications
- [core/03-agent-routing-spec.md](core/03-agent-routing-spec.md) — Agent hierarchy
