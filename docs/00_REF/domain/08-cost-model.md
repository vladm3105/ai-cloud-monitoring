# AI Cost Monitoring — Cost Model & Unit Economics

## Document Info

| Field | Value |
|-------|-------|
| **Document** | 08 — Cost Model & Unit Economics |
| **Version** | 1.0 |
| **Date** | 2026-02-10T15:00:00 |
| **Status** | Architecture |
| **Audience** | Architects, Product, Business |

---

> **Scope Note:** This cost model covers three deployment scenarios:
> - **Single-Owner (Internal Team):** Firestore + BigQuery — minimal costs, free tier optimized
> - **MVP (Single-Tenant SaaS):** Firestore + BigQuery — lower fixed costs, serverless
> - **Multi-Tenant Production:** PostgreSQL + BigQuery — higher capacity, RLS isolation
>
> The tables below show multi-tenant costs by default, with single-owner and MVP alternatives noted where applicable.

---

## 0. Single-Owner Cost Model (Internal Team Use)

For teams deploying this platform to monitor their own cloud costs (not as a SaaS product).

### 0.1 Monthly Infrastructure Cost

| Component | Monthly Cost | Notes |
|-----------|--------------|-------|
| **Authentication** | $0 | GCP IAM / Cloud Identity (existing Google accounts) |
| **Firestore** | $0 | Free tier: 1 GiB storage, 50K reads/day, 20K writes/day |
| **BigQuery** | $0 | Free tier: 1TB queries/month, 10GB storage |
| **Cloud Tasks** | $0 | Free tier: 1M operations/month |
| **Cloud Scheduler** | $0 | Free tier: 3 jobs/month (sufficient for sync schedules) |
| **Secret Manager** | $0-1 | Free tier: 6 secret versions, $0.06/10K access ops |
| **Cloud Run** | $0-10 | Free tier: 2M requests/month, 360K vCPU-seconds |
| **Cloud Storage** | $0 | Free tier: 5GB storage |
| **Cloud Logging** | $0 | Free tier: 50 GiB logs/month |
| **Total Infrastructure** | **$0-11/month** | Typically $0-5/month within free tiers |

### 0.1.1 Additional Free Tier Services (Available)

These GCP services are available within free tier limits and can enhance the platform:

| Service | Free Tier Limit | Potential Use |
|---------|-----------------|---------------|
| **Cloud Pub/Sub** | 10 GiB messages/month | Event-driven webhook ingestion, async notifications |
| **Cloud Run Functions** | 2M invocations, 400K GB-seconds | Lightweight webhooks, event handlers |
| **Workflows** | 5,000 internal steps + 2,000 HTTP calls/month | Remediation approval chains, multi-step onboarding |
| **Cloud Build** | 2,500 build-minutes/month | CI/CD pipeline for deployments |
| **Artifact Registry** | 0.5 GB storage/month | Docker image storage for Cloud Run |
| **Cloud Deploy** | 1 active delivery pipeline | Automated deployments |
| **Natural Language API** | 5,000 units/month | Entity extraction from user queries (optional) |
| **Translation API** | 500K characters/month | Multi-language support (optional) |

**Architecture enhancement with Pub/Sub:**

```text
Cloud Provider Webhook → Pub/Sub Topic → Cloud Run Function → Processing
```

Benefits: Decoupling, built-in retry, dead-letter queues for failed messages.

**Firestore handles:**

- Users, config, policies (persistent)
- Task progress, sync status (ephemeral, real-time listeners)
- Messages, notifications (short-lived, auto-delete via TTL)
- Real-time UI streaming (no SSE infrastructure needed)

**No Auth0 required** — Single-owner deployments use GCP IAM with existing Google/Workspace identities.

### 0.2 LLM Inference Cost (Single Team)

| Usage Pattern | Queries/Month | Cost/Query | Monthly Cost |
|---------------|---------------|------------|--------------|
| Light (weekly check-ins) | 50 | $0.003 | $0.15 |
| Moderate (daily queries) | 200 | $0.003 | $0.60 |
| Heavy (hourly analysis) | 1,000 | $0.003 | $3.00 |

### 0.3 Cloud API Costs

| Provider | API Calls/Month | Cost |
|----------|-----------------|------|
| GCP Cloud Billing | Unlimited | $0 (free) |
| AWS Cost Explorer | ~5,000 | $0.50 (heaviest cost) |
| Azure Cost Management | Unlimited | $0 (free) |

### 0.4 Total Single-Owner Monthly Cost

| Scenario | Infrastructure | LLM | Cloud APIs | **Total** |
|----------|----------------|-----|------------|-----------|
| **GCP only** | $0-5 | $0.60 | $0 | **$0.60-5.60** |
| **AWS only** | $0-5 | $0.60 | $0.50 | **$1.10-6.10** |
| **Multi-cloud (GCP+AWS+Azure)** | $0-10 | $1.00 | $0.50 | **$1.50-11.50** |

**Bottom line:** Internal team deployment costs **$0-12/month** for most organizations, dominated by LLM usage.

---

## 0.5 Realistic Development Timeline (AI-Assisted)

This section provides a realistic assessment of what can be built with AI coding assistants (Claude Code, GitHub Copilot) by a solo developer or small team.

### 0.5.1 15-Day MVP with AI Assistance

**Assumptions:**
- Developer with GCP/cloud experience
- Full-time effort (~8 hours/day)
- AI assistant (Claude Code or similar) for code generation
- Well-documented architecture (this repository)

**Week 1: Infrastructure + Data Connectors**

| Day | Tasks | Deliverables |
|-----|-------|--------------|
| 1-2 | GCP project setup, enable APIs, Firestore/BigQuery config | Working GCP environment |
| 3-4 | GCP billing export → BigQuery pipeline | GCP cost data flowing |
| 5 | AWS Cost Explorer connector (boto3) | AWS cost retrieval working |

**Week 2: Backend API + Dashboard**

| Day | Tasks | Deliverables |
|-----|-------|--------------|
| 6-7 | FastAPI backend with cost aggregation endpoints | REST API for cost data |
| 8-9 | Azure Cost Management connector | Multi-cloud data retrieval |
| 10 | Grafana setup with BigQuery data source | Basic cost dashboards |

**Week 3: LLM Integration + Deployment**

| Day | Tasks | Deliverables |
|-----|-------|--------------|
| 11-12 | Simple LLM chat (single model, not multi-agent) | "Ask about costs" feature |
| 13-14 | Cloud Run deployment, basic auth | Deployed application |
| 15 | Testing, bug fixes, documentation | Production-ready MVP |

### 0.5.2 What's Included in 15-Day MVP

| Feature | Included | Notes |
|---------|----------|-------|
| Multi-cloud cost visibility | ✅ | GCP, AWS, Azure |
| Grafana dashboards | ✅ | 3-5 basic dashboards |
| Simple LLM chat | ✅ | Single model (Gemini Flash or Claude Haiku) |
| Cloud Run deployment | ✅ | Serverless, auto-scaling |
| Basic authentication | ✅ | GCP IAM or simple API key |
| Daily cost sync | ✅ | Via Cloud Scheduler |

**Estimated Value Delivered:** ~60-70% of the full platform vision

### 0.5.3 What's NOT Included in 15-Day MVP

| Feature | Status | Why Excluded |
|---------|--------|--------------|
| MCP servers | ❌ | Architecture overhead, not essential for MVP |
| Multi-agent orchestration | ❌ | Complex, requires significant development |
| AG-UI streaming | ❌ | CopilotKit integration takes time |
| Anomaly detection | ❌ | ML models need training data |
| Remediation workflows | ❌ | Requires approval chains, testing |
| Kubernetes/OpenCost | ❌ | Additional connector complexity |
| Multi-tenant SaaS | ❌ | RLS, Auth0, tenant isolation |

**These features require additional development phases** (see HANDOFF.md for full roadmap).

### 0.5.4 AI-Assisted Development Reality Check

| Task Type | AI Acceleration | Notes |
|-----------|-----------------|-------|
| Boilerplate code (CRUD, schemas) | ~50% faster | AI excels at repetitive patterns |
| Cloud API integration | ~30% faster | Still requires understanding APIs |
| Complex agent logic | ~10% faster | Requires human design and debugging |
| Infrastructure/Terraform | ~40% faster | AI helps with syntax, not architecture |
| Debugging/troubleshooting | Variable | Often slower with AI hallucinations |

**Realistic expectation:** AI assistants accelerate development but don't eliminate the need for domain expertise. A 15-day MVP with AI is roughly equivalent to 25-30 days without AI assistance.

### 0.5.5 Development Cost Summary (15-Day MVP)

| Cost Type | Amount | Notes |
|-----------|--------|-------|
| Infrastructure (Month 1) | $0-20 | Mostly free tier |
| LLM API for chat feature | $5-15 | Development + testing queries |
| AI coding assistant | $0-20 | Claude Code, Copilot subscription |
| **Total Development Cost** | **$5-55** | Excluding developer time |

**Post-deployment monthly cost:** $0-12/month (see Section 0.4)

---

## 1. Cost Categories

Running AI Cost Monitoring has four primary cost categories:

```
Platform Operating Cost = Infrastructure + LLM Inference + Cloud API + Operations
```

| Category | Description | Scales With |
|----------|-------------|-------------|
| **Infrastructure** | Compute, database, storage, networking | Number of tenants + data volume |
| **LLM Inference** | Gemini / Claude API calls for agent responses | Number of interactive queries |
| **Cloud API Calls** | AWS/Azure/GCP API calls for data sync + live queries | Number of cloud accounts × sync frequency |
| **Operations** | Monitoring, logging, backup, support | Relatively fixed |

---

## 2. Per-Tenant Cost Model

### 2.1 Infrastructure Cost per Tenant

Shared infrastructure amortized across tenants (GCP serverless example):

| Component | Monthly Cost (100 tenants) | Per Tenant | Notes |
|-----------|---------------------------|------------|-------|
| Cloud Run (all services) | $300-500 | $3.00-5.00 | Pay-per-use, scales to zero |
| Cloud SQL PostgreSQL (db-n1-standard-2) | $100 | $1.00 | Multi-tenant production: shared DB, RLS isolated |
| BigQuery (billing export queries) | $10-30 | $0.10-0.30 | Serverless analytics |
| Cloud Tasks + Scheduler | $10 | $0.10 | Serverless background jobs |
| Cloud Storage (reports) | $10 | $0.10 | Per-tenant path |
| Cloud Memorystore Redis (optional) | $40 | $0.40 | 1GB instance for L2 cache |
| Cloud Load Balancing + CDN | $50 | $0.50 | Shared |
| Cloud Monitoring/Logging | $50 | $0.50 | Shared |
| **Subtotal** | **$570-690** | **$5.70-6.90** | |

**MVP Alternative (Single-Tenant):**

| Component | Monthly Cost | Notes |
|-----------|--------------|-------|
| Firestore | $0-25 | Free tier covers most MVP usage |
| BigQuery | $0-10 | 1TB queries free/month |
| Cloud Tasks | $0-5 | Generous free tier |
| Secret Manager | $0-1 | Per-secret pricing |
| **MVP Subtotal** | **$0-41** | Mostly within free tier |

**Cost advantage:** Serverless saves ~$1,460/month vs Kubernetes ($2,150 - $690 = $1,460).

At scale (500 tenants), per-tenant infrastructure cost drops to ~$2-3/month.

### 2.2 LLM Inference Cost per Tenant

Based on estimated query volume and token usage:

| Metric | Free Tier | Pro Tier | Enterprise Tier |
|--------|-----------|----------|-----------------|
| Queries per month | 100 | 1,000 | 5,000+ |
| Avg input tokens per query | 2,000 | 2,000 | 3,000 |
| Avg output tokens per query | 1,000 | 1,000 | 1,500 |
| LLM model | Gemini 2.0 Flash | Gemini 2.0 Flash | Gemini 2.0 Pro / Claude |

**LLM cost per query** (estimated, Gemini 2.0 Flash pricing):

| Component | Tokens | Cost |
|-----------|--------|------|
| Input (system + context + query) | ~2,000 | ~$0.0003 |
| Output (response) | ~1,000 | ~$0.0006 |
| Multi-agent overhead (2-3 agents per query) | ×3 | ×3 |
| **Total per query** | | **~$0.003** |

**Monthly LLM cost per tenant:**

| Tier | Queries | Cost per Query | Monthly LLM Cost |
|------|---------|---------------|------------------|
| Free | 100 | $0.003 | $0.30 |
| Pro | 1,000 | $0.003 | $3.00 |
| Enterprise | 5,000 | $0.004 (Pro model mix) | $20.00 |

### 2.3 Cloud API Cost per Tenant

Cloud provider API calls for data sync (Mode 2):

| API | Calls per Sync | Syncs per Day | Monthly Calls | Cost per 1K | Monthly Cost |
|-----|---------------|---------------|---------------|-------------|--------------|
| AWS Cost Explorer | 10-50 | 6 | 1,800-9,000 | $0.01 | $0.09 |
| AWS CloudWatch | 50-200 | 6 | 9,000-36,000 | Free tier | $0.00 |
| Azure Cost Management | 10-30 | 6 | 1,800-5,400 | Free | $0.00 |
| GCP Cloud Billing | 10-30 | 6 | 1,800-5,400 | Free | $0.00 |
| **Total per account** | | | | | **~$0.10 - $1.00** |

**Note:** AWS Cost Explorer is the most expensive API at ~$0.01 per request. Other providers have free/low-cost billing APIs. A tenant with 5 AWS accounts ≈ $0.50-5.00/month in cloud API costs.

### 2.4 Total Per-Tenant Cost Summary

| Cost Component | Free Tier | Pro Tier | Enterprise Tier |
|---------------|-----------|----------|-----------------|
| Infrastructure (shared) | $21.50 | $21.50 | $25.00 |
| LLM inference | $0.30 | $3.00 | $20.00 |
| Cloud API calls | $0.50 | $2.00 | $10.00 |
| Operations overhead | $2.00 | $2.00 | $5.00 |
| **Total cost per tenant** | **$24.30** | **$28.50** | **$60.00** |

At scale (500 tenants), infrastructure share drops significantly:

| Cost Component | Free (at scale) | Pro (at scale) | Enterprise (at scale) |
|---------------|-----------------|----------------|----------------------|
| Infrastructure | $8.00 | $10.00 | $15.00 |
| LLM inference | $0.30 | $3.00 | $20.00 |
| Cloud API calls | $0.50 | $2.00 | $10.00 |
| Operations | $1.00 | $1.00 | $3.00 |
| **Total** | **$9.80** | **$16.00** | **$48.00** |

---

## 3. Pricing Tiers

### 3.1 Proposed Pricing

| Feature | Free | Pro ($49/mo) | Enterprise ($199/mo) |
|---------|------|-------------|---------------------|
| Cloud accounts | 1 | 5 | Unlimited |
| Cloud providers | 1 | All 4 | All 4 |
| Interactive queries | 100/mo | 1,000/mo | 5,000/mo |
| Data retention | 90 days | 1 year | 3 years |
| Users | 2 | 10 | Unlimited |
| Scheduled sync | Every 12 hours | Every 4 hours | Every 1 hour |
| Anomaly detection | Basic | Advanced | Advanced + custom |
| Recommendations | View only | View + execute | View + execute + auto |
| Reports | Basic dashboard | PDF + scheduled | Custom + API export |
| A2A Gateway | — | — | ✓ |
| Alert channels | Email only | Email + Slack | All channels |
| SSO | — | — | ✓ |
| Support | Community | Email | Dedicated |

### 3.2 Margin Analysis

| Tier | Price | Cost (at scale) | Gross Margin |
|------|-------|-----------------|--------------|
| Free | $0 | $9.80 | -$9.80 (acquisition cost) |
| Pro | $49 | $16.00 | $33.00 (67%) |
| Enterprise | $199 | $48.00 | $151.00 (76%) |

**Free tier economics:** The free tier is an acquisition channel. Target: 10% conversion to Pro within 3 months. At 10% conversion, the blended acquisition cost is ~$98 per Pro customer ($9.80 × 10 free users).

### 3.3 Breakeven Analysis

| Metric | Value |
|--------|-------|
| Fixed monthly cost (team + infrastructure base) | ~$15,000 (estimated) |
| Breakeven at Pro-only pricing | 455 Pro tenants |
| Breakeven at 70% Pro + 30% Enterprise mix | 165 paid tenants |
| Target Year 1 | 200 paid tenants |

---

## 4. Cost Optimization Levers

### 4.1 LLM Cost Reduction

| Strategy | Savings | Implementation |
|----------|---------|----------------|
| Response caching | 30-40% | Cache identical query results per tenant (Redis L2) |
| Prompt optimization | 15-20% | Reduce system prompt size, use fewer tokens |
| Model routing | 20-30% | Use Flash for simple queries, Pro only for complex |
| Batch processing | 10-15% | Batch Mode 2 agent calls where possible |

### 4.2 Infrastructure Cost Reduction

| Strategy | Savings | Implementation |
|----------|---------|----------------|
| Scale to zero | 40-60% | Cloud Run services scale to 0 during off-peak hours |
| Minimum instances = 0 | 20-30% | Only backend API keeps 1 warm instance |
| BigQuery slot reservations | 30-40% | For predictable query workloads |
| Committed use discounts | 20-30% | 1-year commit for Cloud SQL, Redis |

### 4.3 Cloud API Cost Reduction

| Strategy | Savings | Implementation |
|----------|---------|----------------|
| Adaptive sync frequency | 30-50% | Less frequent sync for low-activity accounts |
| Delta sync | 40-60% | Only query changed data since last sync |
| Aggregated queries | 20-30% | Batch multiple metrics in single API call |

---

## 5. Revenue Projections (Year 1)

### 5.1 Growth Assumptions

| Month | Free Tenants | Pro Tenants | Enterprise Tenants | MRR |
|-------|-------------|-------------|-------------------|-----|
| 1 | 50 | 5 | 0 | $245 |
| 3 | 200 | 25 | 2 | $1,623 |
| 6 | 500 | 75 | 8 | $5,267 |
| 9 | 800 | 150 | 15 | $10,335 |
| 12 | 1,000 | 250 | 30 | $18,220 |

**Year 1 total revenue (cumulative):** ~$100,000 (estimated)

### 5.2 Key Assumptions

- Free → Pro conversion: 10% within 3 months
- Pro → Enterprise upgrade: 5% within 6 months
- Monthly churn: 3% (Free), 2% (Pro), 1% (Enterprise)
- Average cloud accounts per Pro tenant: 3
- Average cloud accounts per Enterprise tenant: 10+

---

## 6. Value Metrics for Customers

The strongest selling point is demonstrable ROI:

| Metric | How We Track It | Customer Impact |
|--------|-----------------|-----------------|
| Total savings identified | Sum of recommendation estimated_savings | "We found $X in savings" |
| Total savings realized | Sum of executed recommendation actual_savings | "You saved $X" |
| Time to insight | Average query response time | "Answers in seconds, not hours" |
| Anomaly detection speed | Time from cost change to alert | "Caught a $5K/day leak in 4 hours" |
| Coverage | % of cloud accounts monitored | "100% visibility across 3 clouds" |

**Target value proposition:** Platform pays for itself within the first month. A single rightsizing recommendation can save more than the annual subscription cost.

---

## Developer Notes

> **DEV-COST-001:** Implement LLM token counting and cost tracking from day one. Store per-query token usage in the query_interactions table. This is essential for monitoring margin per tenant.

> **DEV-COST-002:** The free tier rate limit (100 queries/month) should be enforced at the AG-UI server level with a simple counter in Redis. Show the user their remaining quota in the UI.

> **DEV-COST-003:** Cloud API costs are the hardest to predict because they depend on tenant account size. Implement metering for cloud API calls per tenant to identify outliers that might need usage-based pricing adjustments.

> **DEV-COST-004:** Cloud Run with min instances = 0 is safe for most services because startup time is < 1 second. Only backend API needs min = 1 for low latency. Background jobs via Cloud Tasks automatically retry on failure.

> **DEV-COST-005:** The savings tracking feature (recommendation estimated vs. actual) is the most important business metric. It directly proves platform ROI to customers. Build this measurement pipeline in Phase 5 alongside the self-learning Loop 2.

> **DEV-COST-006:** Consider usage-based pricing as a future option for Enterprise tier — charge per cloud account monitored rather than a flat fee. This aligns cost with value better for large customers with 50+ accounts.

> **DEV-COST-007:** MVP uses Firestore + BigQuery (serverless, free tier friendly). Migrate to PostgreSQL + BigQuery when multi-tenant isolation (RLS) becomes necessary — typically at 50+ tenants or when enterprise customers require database-level isolation guarantees.
