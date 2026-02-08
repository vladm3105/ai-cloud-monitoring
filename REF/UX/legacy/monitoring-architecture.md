# AI Cost Monitoring Agent — Monitoring & Observability Architecture

## Context

This document defines the monitoring, observability, and cost protection architecture for the **AI Cost Monitoring product** — a conversational AI agent that helps SMBs optimize their GCP cloud spend. The monitoring stack serves two purposes:

1. **Operational health** — Ensuring the product itself runs reliably for customers
2. **LLM cost control** — Protecting product margins by monitoring and limiting the AI consumption that powers the agent

The product's unit economics depend directly on controlling LLM costs per customer session. With a three-tier pricing model ($49/$99/$199/mo), every dollar of uncontrolled LLM spend erodes margin. A single runaway agent session — recursive tool calls, oversized context windows, or unbounded reasoning loops — can destroy profitability on a customer for the entire billing period.

---

## Architecture Overview

The monitoring architecture consists of **three layers** that work together as a unified observability stack, all deployable via Docker Compose or Cloud Run.

```
Layer 1: AI Gateway        — LiteLLM Proxy (cost enforcement, routing, rate limiting)
Layer 2: LLM Observability — Langfuse (traces, cost attribution, session analysis)
Layer 3: Infrastructure    — Grafana + Prometheus + Loki (compute, networking, logs)
```

All three layers feed into **Grafana** as the single pane of glass for operational visibility.

---

## Layer 1: AI Gateway — LiteLLM Proxy

### Role

LiteLLM acts as the **mandatory gateway** between the MCP Server agent and all LLM providers. Every LLM call — whether to Anthropic Claude, Google Gemini, or a self-hosted model — routes through LiteLLM. This is the enforcement layer that prevents cost blowouts.

### Capabilities

| Capability | Purpose | Priority |
|---|---|---|
| **Budget Caps** | Hard per-customer and per-session spend limits | CRITICAL |
| **Rate Limiting** | Tokens-per-minute caps to catch runaway loops | CRITICAL |
| **Cost Tracking** | Real-time token counting and cost calculation per request | HIGH |
| **Model Routing** | Route simple queries to cheaper models (Haiku/Flash), complex to Sonnet/Pro | HIGH |
| **Caching** | Cache repeated prompt patterns to reduce redundant API calls | MEDIUM |
| **Fallback/Retry** | Automatic failover between providers on errors or rate limits | MEDIUM |
| **Unified API** | Single OpenAI-compatible endpoint regardless of downstream provider | HIGH |

### Budget Enforcement Strategy

```
Per-Customer Limits (Monthly):
├── Tier 1 ($49/mo plan):  $8/mo LLM budget  → ~16% COGS target
├── Tier 2 ($99/mo plan):  $18/mo LLM budget → ~18% COGS target
└── Tier 3 ($199/mo plan): $35/mo LLM budget → ~18% COGS target

Per-Session Limits:
├── Single conversation: $0.50 hard cap
├── Tokens per minute:   50,000 TPM cap
└── Max requests/session: 100 LLM calls

Alert Thresholds (per customer):
├── 50% budget consumed → Log warning
├── 80% budget consumed → Slack/email alert to ops
└── 95% budget consumed → Degrade to cheaper model
└── 100% budget consumed → Block with user-facing message
```

### Model Routing Rules

| Query Complexity | Target Model | Estimated Cost/Query |
|---|---|---|
| Simple lookups ("what's my spend?") | Gemini Flash / Haiku | $0.001-0.005 |
| Analysis ("why did costs spike?") | Sonnet / Gemini Pro | $0.01-0.05 |
| Deep recommendations ("optimize my Vertex AI") | Sonnet / Opus | $0.05-0.20 |
| Cached/repeated patterns | Local cache (no LLM call) | $0.00 |

### Integration Points

- **Inbound**: MCP Server agent sends all LLM requests to `http://litellm:4000`
- **Outbound**: LiteLLM forwards to Anthropic API, Google Vertex AI, or self-hosted models
- **Logging**: Callbacks configured to send traces to Langfuse via OpenTelemetry
- **Metrics**: Prometheus metrics endpoint exposed at `/metrics` for Grafana scraping

---

## Layer 2: LLM Observability — Langfuse

### Role

Langfuse provides **deep LLM-specific observability** — prompt/response tracing, cost attribution per customer, session replay, and quality evaluation. While LiteLLM enforces limits, Langfuse tells you *why* costs are what they are and where to optimize.

### Capabilities

| Capability | Purpose | Priority |
|---|---|---|
| **Trace Collection** | Full request lifecycle: prompt → reasoning → tool calls → response | CRITICAL |
| **Cost Attribution** | Per-customer, per-session, per-query cost breakdown | CRITICAL |
| **Session Analysis** | Multi-turn conversation tracking with cost accumulation | HIGH |
| **Model Comparison** | A/B test cost/quality between models for same query types | HIGH |
| **Prompt Management** | Version control and performance tracking of system prompts | MEDIUM |
| **Quality Evaluation** | LLM-as-judge scoring for response quality monitoring | MEDIUM |
| **Token Analytics** | Input vs output token distribution, context window utilization | HIGH |

### Tagging Strategy

Every LLM request is tagged with metadata for granular attribution:

```
Tags per request:
├── customer_id:     "cust_abc123"
├── plan_tier:       "tier_2"
├── session_id:      "sess_xyz789"
├── query_type:      "cost_analysis" | "recommendation" | "simple_lookup" | "action"
├── model_used:      "claude-sonnet-4-20250514"
├── gcp_project:     "customer-project-id"
├── tools_invoked:   ["bigquery_billing", "recommender_api"]
└── environment:     "production"
```

### Key Dashboards in Langfuse

1. **Cost per Customer** — Monthly LLM spend per customer vs. their plan revenue
2. **Cost per Session** — Distribution of session costs, identify outlier sessions
3. **Model Usage Mix** — Ratio of cheap vs. expensive model usage over time
4. **Token Efficiency** — Input/output token ratio, context window utilization
5. **Query Classification** — Breakdown of query types and their cost profiles
6. **Margin Tracker** — Real-time (Revenue - LLM Cost) per tier

### Architecture Components

```
Langfuse Stack:
├── langfuse-web      — Web UI + API server (port 3000)
├── langfuse-worker   — Async trace processor
├── postgres           — Transactional database (traces metadata, projects, users)
├── clickhouse         — OLAP database (trace data, spans, scores — optimized for analytics)
└── redis              — Queue + cache (trace ingestion buffering)
```

### Integration Points

- **Inbound**: Receives OTLP traces from LiteLLM proxy callbacks
- **Inbound**: Direct SDK instrumentation from MCP Server for non-LLM spans (tool calls, GCP API latency)
- **Outbound**: Grafana can query Langfuse API for dashboard panels (optional)
- **Storage**: ClickHouse retains trace data for historical cost analysis

---

## Layer 3: Infrastructure Observability — Grafana + Prometheus + Loki

### Role

Traditional infrastructure monitoring for the product's runtime environment. Ensures the Cloud Run / Docker services are healthy, performant, and scaling appropriately.

### Components

#### Prometheus — Metrics Collection

Scrapes and stores time-series metrics from all product components.

| Metric Source | What It Collects |
|---|---|
| **MCP Server (Cloud Run)** | Request latency, error rates, active sessions, GCP API call duration |
| **LiteLLM Proxy** | LLM request count, token throughput, cache hit rate, model routing decisions, cost per request |
| **Langfuse** | Trace ingestion rate, worker queue depth, database query latency |
| **Postgres** | Connection pool usage, query duration, replication lag |
| **ClickHouse** | Query performance, disk usage, ingestion throughput |
| **Redis** | Memory usage, queue length, eviction rate |
| **Cloud Run** | Instance count, cold start frequency, CPU/memory utilization, billing metrics |

#### Loki + Promtail — Log Aggregation

Centralized log collection and search across all services.

| Log Source | Key Signals |
|---|---|
| **MCP Server** | Customer queries, GCP API errors, tool execution logs |
| **LiteLLM** | Rate limit hits, budget enforcement events, model fallbacks, provider errors |
| **Langfuse** | Trace processing errors, ingestion failures |
| **Application** | Authentication events, customer session lifecycle |

#### Grafana — Unified Dashboards

Single visualization layer pulling from all data sources.

### Grafana Dashboard Structure

```
Grafana Dashboards:
│
├── 📊 Executive Overview
│   ├── Total LLM spend (today / this week / this month)
│   ├── Revenue vs. LLM COGS by tier
│   ├── Active customers / sessions
│   └── System health summary
│
├── 💰 LLM Cost Operations
│   ├── Real-time spend rate ($/hour) with anomaly detection
│   ├── Per-customer cost breakdown (table + sparklines)
│   ├── Model usage distribution (pie: Haiku vs Sonnet vs Opus)
│   ├── Cache hit rate and savings
│   ├── Budget utilization per customer (gauge charts)
│   └── Cost outlier sessions (top 10 most expensive)
│
├── 🤖 Agent Performance
│   ├── Query latency (p50, p95, p99)
│   ├── Tool call success/failure rates
│   ├── GCP API response times (BigQuery, Recommender, Asset)
│   ├── Conversation length distribution
│   └── Query type classification breakdown
│
├── 🏗️ Infrastructure
│   ├── Cloud Run: instances, CPU, memory, cold starts
│   ├── Database: Postgres connections, ClickHouse disk, Redis memory
│   ├── Network: request throughput, error rates
│   └── Container health across all services
│
└── 🚨 Alerts & Incidents
    ├── Active alerts timeline
    ├── Budget breach events log
    ├── Provider outage / degradation history
    └── Error rate anomalies
```

### Alerting Rules

| Alert | Condition | Severity | Action |
|---|---|---|---|
| **Cost Spike** | LLM spend rate > 3× rolling average | CRITICAL | Slack + PagerDuty |
| **Customer Budget 80%** | Customer monthly LLM spend > 80% of cap | WARNING | Slack notification |
| **Customer Budget 100%** | Customer hits hard cap | INFO | Log + verify degradation active |
| **High Latency** | P95 response time > 10s for 5 min | WARNING | Slack notification |
| **Error Spike** | Error rate > 5% for 3 min | CRITICAL | Slack + PagerDuty |
| **Provider Down** | LLM provider returning 5xx for 2 min | CRITICAL | Verify fallback active |
| **Runaway Session** | Single session > $0.30 | WARNING | Inspect trace in Langfuse |
| **Cold Start Surge** | > 50% requests hitting cold starts | WARNING | Review scaling config |
| **Database Saturation** | Postgres connections > 80% pool | WARNING | Slack notification |
| **Disk Pressure** | ClickHouse disk > 80% | WARNING | Review retention policy |

---

## Data Flow Architecture

### Request Flow (Happy Path)

```
Customer Query
      │
      ▼
┌─────────────────┐
│   MCP Server    │  ← Instrumented with Langfuse SDK + Prometheus metrics
│   (Cloud Run)   │
└────────┬────────┘
         │
         ├──── GCP API calls ──► BigQuery, Recommender, Asset Inventory
         │     (latency tracked by Prometheus)
         │
         ▼
┌─────────────────┐
│  LiteLLM Proxy  │  ← Budget check → Rate limit check → Route to model
│   (AI Gateway)  │
└────────┬────────┘
         │
         ├──── If budget OK ────► LLM Provider (Anthropic/Google/Self-hosted)
         │                              │
         │                              ▼
         │                        LLM Response
         │                              │
         ├──── Trace + cost data ──► Langfuse (via OTLP)
         ├──── Metrics ────────────► Prometheus
         └──── Logs ───────────────► Loki
```

### Cost Protection Flow (Enforcement Path)

```
LLM Request arrives at LiteLLM
      │
      ▼
┌── Budget Check ──┐
│                  │
│  Within limit?   │
│                  │
├── YES ───────────┼──► Rate Limit Check ──┐
│                  │                       │
├── > 95% ─────────┼──► Route to CHEAPER   │  Within TPM?
│                  │    model (degrade)    │
│                  │                       ├── YES ──► Forward to LLM
├── = 100% ────────┼──► BLOCK request      │
│                  │    Return user msg    ├── NO ───► Queue / 429 response
└──────────────────┘                       │
                                           └──► Log event to Langfuse
                                                Alert via Grafana
```

---

## Deployment Architecture

### Docker Compose Topology

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Docker Compose / Cloud Run                       │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  APPLICATION TIER                                             │   │
│  │                                                               │   │
│  │  ┌─────────────┐    ┌──────────────┐                         │   │
│  │  │ MCP Server  │───►│ LiteLLM      │───► LLM Providers      │   │
│  │  │ (Agent)     │    │ Proxy        │    (Anthropic/Google)   │   │
│  │  │ :8080       │    │ :4000        │                         │   │
│  │  └─────────────┘    └──────────────┘                         │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  LLM OBSERVABILITY TIER                                       │   │
│  │                                                               │   │
│  │  ┌──────────────┐  ┌─────────────┐                           │   │
│  │  │ Langfuse Web │  │ Langfuse    │                           │   │
│  │  │ :3000        │  │ Worker      │                           │   │
│  │  └──────────────┘  └─────────────┘                           │   │
│  │                                                               │   │
│  │  ┌──────────┐  ┌────────────┐  ┌─────────┐                  │   │
│  │  │ Postgres │  │ ClickHouse │  │  Redis  │                  │   │
│  │  │ :5432    │  │ :8123      │  │  :6379  │                  │   │
│  │  └──────────┘  └────────────┘  └─────────┘                  │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  INFRASTRUCTURE OBSERVABILITY TIER                            │   │
│  │                                                               │   │
│  │  ┌────────────┐  ┌──────────┐  ┌───────────┐                │   │
│  │  │ Prometheus │  │   Loki   │  │ Promtail  │                │   │
│  │  │ :9090      │  │  :3100   │  │ (sidecar) │                │   │
│  │  └────────────┘  └──────────┘  └───────────┘                │   │
│  │                                                               │   │
│  │  ┌────────────┐                                              │   │
│  │  │  Grafana   │  ← Unified dashboards (all data sources)    │   │
│  │  │  :3001     │                                              │   │
│  │  └────────────┘                                              │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Resource Estimates

| Service | RAM | CPU | Disk | Notes |
|---|---|---|---|---|
| MCP Server | 256-512 MB | 0.5 vCPU | — | Stateless, scales horizontally |
| LiteLLM Proxy | 512 MB | 0.5 vCPU | — | In-memory budget tracking |
| Langfuse Web | 512 MB | 0.5 vCPU | — | UI + API |
| Langfuse Worker | 256 MB | 0.25 vCPU | — | Async processing |
| Postgres | 512 MB | 0.5 vCPU | 10 GB | Transactional data |
| ClickHouse | 1 GB | 0.5 vCPU | 20 GB | Trace analytics (grows with usage) |
| Redis | 256 MB | 0.25 vCPU | — | Queue + cache |
| Prometheus | 512 MB | 0.25 vCPU | 10 GB | 15-day retention default |
| Loki | 512 MB | 0.25 vCPU | 10 GB | Log storage |
| Promtail | 128 MB | 0.1 vCPU | — | Log shipping sidecar |
| Grafana | 256 MB | 0.25 vCPU | 1 GB | Dashboards + alerting |
| **TOTAL** | **~4.5-5 GB** | **~3.5 vCPU** | **~51 GB** | Fits on single e2-standard-4 |

### Estimated Monthly Infrastructure Cost (Monitoring Stack Only)

| Deployment Option | Monthly Cost | Notes |
|---|---|---|
| **Single GCE VM (e2-standard-4)** | $95-120 | Simplest, good for early stage |
| **Cloud Run (all services)** | $60-150 | Variable with usage, auto-scaling |
| **GKE Autopilot** | $150-250 | Best for scaling, higher baseline |

---

## Technology Decision Matrix

| Concern | Considered Options | Selected | Rationale |
|---|---|---|---|
| **AI Gateway** | Helicone, Portkey, custom | **LiteLLM** | Open-source, self-hosted, budget enforcement built-in, 100+ provider support |
| **LLM Observability** | Langfuse, Helicone, custom Grafana | **Langfuse** | MIT license, self-hosted, best cost attribution, ClickHouse analytics, native LiteLLM integration |
| **Metrics** | Datadog, Cloud Monitoring, Prometheus | **Prometheus** | Free, proven, Cloud Run native metrics, extensible |
| **Logs** | Cloud Logging, ELK, Loki | **Loki** | Lightweight, Grafana-native, label-based (no full-text indexing overhead) |
| **Visualization** | Datadog, Langfuse UI only, Grafana | **Grafana** | Free, unifies all data sources, extensible, alerting built-in |
| **Traces (infra)** | Jaeger, Tempo, Zipkin | **Grafana Tempo** (optional) | Grafana-native, OTLP-compatible, add later if needed |

---

## Why This Stack (and Not Just Grafana+Prometheus)

The critical distinction is **proactive vs. reactive** cost protection:

| Approach | How It Works | When You Learn About Problems |
|---|---|---|
| Prometheus alert on cost metric | Scrapes metric → evaluates rule → fires alert | **After** the costly request completes |
| LiteLLM budget enforcement | Checks budget **before** forwarding request | **Before** the cost is incurred |

Prometheus alerting tells you "a customer just spent $2 on one session." LiteLLM budget caps prevent that session from exceeding $0.50 in the first place. Both are necessary — enforcement for prevention, monitoring for visibility and optimization.

Similarly, Grafana dashboards show aggregate trends, but Langfuse shows you the actual prompt that cost $0.15 and lets you decide whether to optimize it. They serve different audiences: Grafana for ops, Langfuse for product/ML engineering.

---

## Retention & Scaling Considerations

| Data Type | Retention | Scaling Strategy |
|---|---|---|
| Prometheus metrics | 15 days local, optional Thanos for long-term | Increase retention or add remote storage as customer base grows |
| Loki logs | 7 days (configurable) | Compress + ship to GCS for archival |
| Langfuse traces | 90 days in ClickHouse | ClickHouse handles well; archive older traces to GCS |
| LiteLLM budget state | In-memory + Postgres | Stateless restart recovery from DB |

---

## Phase Rollout

| Phase | Components | Timeline | Purpose |
|---|---|---|---|
| **Phase 1** | LiteLLM + Langfuse | Week 1-2 | Core cost protection + LLM visibility |
| **Phase 2** | Prometheus + Grafana | Week 3-4 | Infrastructure monitoring + unified dashboards |
| **Phase 3** | Loki + Promtail | Week 4-5 | Centralized logging |
| **Phase 4** | Advanced Grafana dashboards + alerting | Week 5-6 | Operational maturity |
| **Phase 5** | Tempo (optional) | As needed | Distributed tracing for infrastructure |
