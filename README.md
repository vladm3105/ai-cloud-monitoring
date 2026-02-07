# AI Cloud Cost Monitoring

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![GCP](https://img.shields.io/badge/cloud-GCP-4285F4?logo=google-cloud)](https://cloud.google.com)
[![Status](https://img.shields.io/badge/status-in%20development-yellow)](https://github.com/vladm3105/ai-cloud-monitoring)

> **AI-agent-powered FinOps platform for intelligent cloud cost monitoring, optimization, and automated remediation across AWS, Azure, GCP, and Kubernetes.**

## What Makes This Different

**AI Agents + MCP Servers** — not traditional REST API integrations:

| Traditional Approach                 | This Platform                                          |
|--------------------------------------|--------------------------------------------------------|
| REST API calls from backend code     | AI agents call MCP (Model Context Protocol) servers    |
| Manual data aggregation              | Agents orchestrate multi-cloud queries automatically   |
| Static dashboards                    | Natural language interface with streaming responses    |
| Code-driven logic                    | Agent-driven reasoning and recommendations             |

**See [PROJECT_DEFINITION.md](PROJECT_DEFINITION.md) for the complete architectural vision.**

## Core Architecture

```text
User (Natural Language) → AI Agents → MCP Servers → Cloud APIs
                              │
                              ├── Coordinator Agent (intent routing)
                              ├── Domain Agents (cost, optimization, remediation)
                              ├── Cloud Agents (AWS, Azure, GCP, K8s)
                              └── MCP Servers (tool execution)
```

**MCP Server Strategy:**

- **Provider-native MCP servers** when available (preferred)
- **Custom-developed MCP servers** when provider doesn't offer one (using FastMCP)

All cloud MCP servers implement unified tool contracts (`get_costs`, `get_recommendations`, `execute_remediation`, etc.) for seamless multi-cloud agent orchestration.

## 🚀 Quick Start

> **[View System Architecture Diagram](docs/architecture/README.md)** 📊


### Deployment to GCP

The platform is designed to run on Google Cloud Platform using Cloud Run:

1. **Prerequisites**: GCP project with billing enabled, gcloud CLI installed
2. **Deploy**: Follow the [GCP Deployment Guide](GCP-DEPLOYMENT.md)
3. **Configure**: Use [CLOUD_CONFIG.md](CLOUD_CONFIG.md) and [.env.example](.env.example)
4. **Infrastructure**: Terraform configs in [terraform/](terraform/)

**Estimated Setup Time**: 30-45 minutes

**Monthly Cost (Single-Owner/Internal Team):**
| Scenario | Monthly Cost |
|----------|--------------|
| GCP only | $0.60-5.60 |
| Multi-cloud (GCP+AWS+Azure) | $1.50-11.50 |

Most infrastructure stays within GCP free tier. Primary cost is LLM inference (~$0.003/query).

**Monthly Cost (Multi-Tenant SaaS)**: ~$50-150 (Production at 100 tenants)

> **📋 MVP Architecture**: See [MVP_ARCHITECTURE.md](docs/architecture/MVP_ARCHITECTURE.md) for the simplified single-tenant stack using Firestore + BigQuery (no PostgreSQL required for MVP).

**Note:** Currently optimized for GCP deployment (per [ADR-002](docs/adr/002-gcp-only-first.md)). Multi-cloud expansion planned for future phases.

### For Developers

**New to the project?** Start here:
1. **[HANDOFF.md](HANDOFF.md)** - Project status, what's built, immediate next steps
2. **[DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md)** - Local setup, project structure, common tasks
3. **[CONTRIBUTING.md](CONTRIBUTING.md)** - Code standards, git workflow, testing guidelines
4. **[core/](core/)** - Complete technical specifications

**Quick Links:**
- [All Architecture Decisions (ADRs)](docs/adr/)
- [Database Schema](core/01-database-schema.md)
- [API Endpoints](core/05-api-endpoint-spec.md)
- [GCP Deployment Guide](GCP-DEPLOYMENT.md)


### Home Cloud vs Monitored Clouds

**Important Architectural Distinction:**

- **Home Cloud (Primary Cloud)**: Currently GCP - Where the platform itself runs
  - All platform infrastructure (frontend, backend,databases, task queues)
  - Infrastructure managed via Terraform
  - Can be deployed to AWS or Azure (see Technology Stack for cloud alternatives)

- **Monitored Clouds**: AWS, Azure, GCP, Kubernetes - What the platform analyzes
  - The platform connects to these clouds via APIs
  - Retrieves cost data, resource inventories, recommendations
  - Can execute remediation actions (with approval)
  - GCP appears in both roles (home cloud + monitored cloud)

**Example with GCP as Home Cloud (MVP)**:
- **Frontend**: Next.js on Cloud Run
- **Backend**: FastAPI on Cloud Run
- **Config Store**: Firestore (MVP) → PostgreSQL (multi-tenant)
- **Real-time UI**: Firestore listeners (no SSE infrastructure needed)
- **Analytics DB**: BigQuery
- **Task Queue**: Cloud Tasks + Cloud Scheduler
- **Secret Manager**: GCP Secret Manager

See [ADR-008](docs/adr/008-database-strategy-mvp.md) for the database strategy decision.

**Why This Matters:**

The platform is **cloud-agnostic in monitoring** but **cloud-specific in deployment**. You can monitor AWS, Azure, and Kubernetes costs while the platform itself runs entirely on GCP. This separation allows:

- **Predictable operational costs** - Home cloud costs are fixed and manageable
- **No lock-in concerns** - The platform can monitor any cloud, including competitors
- **Simplified operations** - Single cloud to manage for infrastructure
- **Future flexibility** - Could be deployed to Azure/AWS if needed (with infrastructure changes)

---

## 🌟 Key Features

### 🤖 Intelligent AI Agents
- **Natural Language Interface** - Ask questions like *"Why did our AWS bill spike last week?"* or *"Show me idle resources across all clouds"*
- **Multi-Agent Orchestration** - Specialized agents collaborate to handle complex queries
- **Context-Aware Responses** - Agents understand tenant context, user roles, and permissions

### 💰 Comprehensive Cost Management
- **Unified Cost View** - Single dashboard for AWS, Azure, GCP, and Kubernetes costs
- **Real-Time Cost Tracking** - Live cost data with anomaly detection
- **Budget Alerts** - Proactive notifications when spending exceeds thresholds
- **Cost Allocation** - Tag-based cost attribution by team, project, or environment

### ⚡ Smart Optimization
- **AI-Powered Rightsizing** - Machine learning-driven instance sizing suggestions
- **Idle Resource Detection** - Automatically identify and flag unused resources
- **Reserved Instance Planning** - Savings plan optimization recommendations
- **Cross-Cloud Arbitrage** - Compare pricing across cloud providers

### 🔧 Automated Remediation
- **One-Click Actions** - Execute optimizations directly from the UI
- **Approval Workflows** - Role-based approval chains for sensitive actions
- **Scheduled Operations** - Automate resource start/stop schedules
- **Rollback Capability** - Safely revert changes if needed

### 📊 Advanced Reporting & Forecasting
- **ML-Powered Forecasting** - Predictive spend analysis
- **Executive Dashboards** - High-level summaries for leadership
- **Team Chargeback** - Department-level cost reports
- **Multi-Format Export** - PDF reports, Slack notifications, API access

---

## 🏗️ Architecture

### 4-Layer Hierarchical Agent Design

```
┌─────────────────────────────────────────────────────────────┐
│  LAYER 1: COORDINATOR AGENT                                  │
│  Intent classification • Routing • A2UI rendering            │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────┐
│  LAYER 2: DOMAIN AGENTS (6 Agents)                           │
│  Cost • Optimization • Remediation • Reporting • Tenant      │
│  Cross-Cloud                                                 │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────┐
│  LAYER 3: CLOUD PROVIDER AGENTS (4 Agents)                   │
│  AWS Agent • Azure Agent • GCP Agent • Kubernetes Agent      │
│  Each owns its MCP server exclusively                        │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────┐
│  LAYER 4: MCP SERVERS (8 Servers)                            │
│  AWS MCP • Azure MCP • GCP MCP • OpenCost MCP                │
│  Forecast MCP • Remediation MCP • Policy MCP • Tenant MCP    │
└─────────────────────────────────────────────────────────────┘
```

### Architecture Benefits

| Benefit | Description |
|---------|-------------|
| **Parallel Execution** | Cloud agents query all providers simultaneously |
| **Clean Separation** | Domain logic separated from cloud-specific implementation |
| **Better Caching** | Per-cloud credential and response caching |
| **Fault Isolation** | One cloud failure doesn't affect others |
| **Scalability** | Add new cloud providers without changing domain logic |

---

## 📂 Project Structure

```
AI-cost-monitoring/
├── core/                           # Core specifications and architecture
│   ├── 01-database-schema.md       # Database schema and data model
│   ├── 02-mcp-tool-contracts.md    # MCP server tool contracts
│   ├── 03-agent-routing-spec.md    # Agent routing specifications
│   ├── 04-tenant-onboarding.md     # Tenant setup (optional multi-tenant)
│   ├── 05-api-endpoint-spec.md     # API endpoint specifications
│   ├── 07-deployment-infrastructure.md  # Deployment architecture
│   ├── 08-cost-model.md            # Cost model and pricing
│   └── *.svg                       # Architecture diagrams
├── docs/                           # Documentation
│   ├── architecture/               # Architecture documentation
│   │   ├── MVP_ARCHITECTURE.md     # MVP simplified stack
│   │   └── CLOUD_PLATFORM_COMPARISON.md
│   └── adr/                        # Architecture Decision Records
│       ├── 001-use-mcp-servers.md
│       ├── 002-gcp-only-first.md
│       ├── 003-use-bigquery-not-timescaledb.md
│       ├── 004-cloud-run-not-kubernetes.md
│       └── 008-database-strategy-mvp.md
├── terraform/                      # Infrastructure as Code
│   ├── main.tf                    # Main Terraform configuration
│   ├── variables.tf               # Variable declarations
│   ├── outputs.tf                 # Output values
│   └── modules/                   # Terraform modules
├── GCP-only/                       # GCP-specific implementation
├── UX/                            # User experience and UI documentation
├── config/                        # Configuration files
│   └── gcp-mvp.yaml              # GCP MVP configuration
├── CLOUD_CONFIG.md               # Cloud platform configuration guide
├── GCP-DEPLOYMENT.md              # GCP deployment guide
└── .env.example                   # Environment variable template
```

---


---

## 🎨 User Interface Architecture

The platform provides **two complementary interfaces** for different interaction modes:

### 1. Grafana Dashboards – Analytics & Visualization

**Purpose**: Pre-built, reliable dashboards for cost monitoring and analysis

**Features**:
- Real-time cost overview across all clouds
- Multi-cloud comparison dashboards
- Budget tracking and alerts
- Custom SQL queries to BigQuery
- Export and sharing capabilities
- Fast, cached visualizations

**Access**: `/dashboards` or embedded via iframe

**Technology**: Grafana with native BigQuery and Cloud SQL data sources (no Prometheus needed)

### 2. CopilotKit (AG-UI) – Conversational Interface

**Purpose**: Natural language interaction with AI agents for ad-hoc analysis

**Features**:
- Chat-based cost queries: *"Why did AWS costs spike yesterday?"*
- Agent-driven multi-cloud analysis
- Real-time streaming responses
- Actionable recommendations
- Complex multi-step investigations

**Access**: `/` or `/chat` – embedded chat widget

**Technology**: CopilotKit client → FastAPI AG-UI server → Agent hierarchy

### Hybrid Approach Benefits

| Use Case | Interface | Why |
|----------|-----------|-----|
| **Daily monitoring** | Grafana | Fast, reliable dashboards |
| **Budget alerts** | Grafana | Native alerting |
| **Ad-hoc questions** | AG-UI Chat | Natural language |
| **Root cause analysis** | AG-UI Chat | Multi-agent investigation |
| **Executive reports** | Grafana | Export/share dashboards |
| **Optimization recs** | AG-UI Chat | Agent-driven insights |

### Integration

**Loose Coupling**: Each UI is independent but can link to the other
- Grafana dashboard → "Ask AI about this" button → Opens CopilotKit
- Chat widget available in Grafana header/sidebar (optional)

Both UIs query the **same data sources** (BigQuery for metrics, Cloud SQL for metadata).

---

## 🔧 Technology Stack

### Frontend
- **Next.js 14** - React framework
- **CopilotKit** - AI chat interface implementing AG-UI protocol client
  - Real-time streaming chat widget with Server-Sent Events (SSE)
  - Progressive UI updates as agents work
  - Natural language queries routed to agent hierarchy
- **A2UI Components** - Real-time streaming UI components
- **Tailwind CSS + shadcn/ui** - Styling
- **OAuth 2.0/OIDC Provider** - Authentication (Auth0, Okta, Azure AD, Google, AWS Cognito, Keycloak, etc.)

### Agent Layer
- **Google ADK** - Agent Development Kit
- **Google A2A Protocol** - Agent-to-Agent communication
- **LiteLLM** - Vendor-neutral LLM abstraction layer
  - Supports: Gemini 2.0, Claude 3.5, GPT-4, Llama, Mistral, and 100+ providers
  - Single API for all LLM providers (avoid vendor lock-in)
  - Currently configured: Gemini 2.0 (GCP) or Claude 3.5 Sonnet (Anthropic)
  - Easy to switch providers via config
  - **Compliance option**: Use cloud provider LLM gateways for data residency/governance:
    - GCP: Vertex AI (Gemini, Claude, Llama via Model Garden)
    - Azure: Azure OpenAI Service (GPT-4, GPT-3.5)
    - AWS: Amazon Bedrock (Claude, Llama, Titan)
- **AG-UI Protocol** - Agent-to-UI streaming (FastAPI SSE endpoint: `/api/copilotkit`)

### Backend
- **FastAPI** - AG-UI server (handles SSE streaming, JWT validation, tenant context)
- **FastMCP** - MCP server framework
- **Cloud Task Queue & Scheduler** - Background jobs and workflow orchestration
  - Currently: GCP Cloud Tasks + Cloud Scheduler
  - AWS alternative: SQS + EventBridge + Lambda
  - Azure alternative: Service Bus + Azure Functions
  - Handles: Data sync (every 4 hours), anomaly detection, forecasts, approval workflows
- **Cloud Pub/Sub (optional)** - Event-driven messaging for webhooks
  - Free tier: 10 GiB messages/month
  - Use for: Webhook ingestion, async notifications, decoupled event processing
- **Workflows (optional)** - Multi-step orchestration
  - Free tier: 5,000 internal steps + 2,000 external HTTP calls/month
  - Use for: Remediation approval chains, complex onboarding flows
- **Cloud Logging** - Centralized logging
  - Free tier: 50 GiB logs/month

> [!NOTE]
> Background services (task queues, schedulers, secret managers, caching) use **home cloud native services** and will differ based on where the platform is deployed. The architecture pattern remains the same across clouds.

### Authentication & Security
- **OAuth 2.0/OIDC Provider** - Auth0 (current), or any OAuth provider
  - Alternatives: Okta, Azure AD, Google Identity, AWS Cognito, Keycloak
  - Provides SSO, MFA, social login, and session management
- **Home Cloud Secret Manager** - Uses the secret manager of the home cloud
  - Currently: GCP Secret Manager (auto-rotation, HA, IAM integration)
  - If home cloud changes: AWS Secrets Manager or Azure Key Vault
  - Stores cloud credentials for monitored accounts (never in database)
- **RBAC (optional)** - Role-based access control
  - Not required for single-tenant MVP (all authenticated users trusted)
  - Required for multi-tenant mode (tenant isolation, admin vs viewer roles)
  - Can be added later as needed

### Data Layer

- **Config Store (MVP)**: Firestore - Configuration, budgets, preferences, real-time streaming
  - **Persistent collections**: `users`, `config`, `policies`, `tasks`
  - **Ephemeral collections with TTL**: `task_progress` (24h), `messages` (7d), `recommendations` (30d)
  - **Real-time listeners**: Replace SSE for live UI updates (task progress, notifications, sync status)
  - Multi-tenant: Upgrade to PostgreSQL with Row-Level Security (see [ADR-008](docs/adr/008-database-strategy-mvp.md))
- **Relational Database (Multi-tenant)** - PostgreSQL for operational data with Row-Level Security
  - Currently: Cloud SQL PostgreSQL 16 (GCP)
  - AWS alternative: RDS PostgreSQL or Aurora PostgreSQL
  - Azure alternative: Azure Database for PostgreSQL
  - Stores: Tenants, accounts, users, workflow state
- **Analytics Database** - Time-series cost metrics (see [ADR-003](docs/adr/003-use-bigquery-not-timescaledb.md))
  - Currently: BigQuery (GCP)
  - AWS alternative: Athena + S3 or Redshift
  - Azure alternative: Azure Synapse Analytics
  - Stores: Cost data, usage metrics, forecasts
- **Object Storage** - Reports, exports, and backups
  - Currently: Cloud Storage (GCP)
  - AWS alternative: S3
  - Azure alternative: Azure Blob Storage
- **Cache (optional)** - High-traffic deployments only
  - Currently: Cloud Memorystore Redis (GCP)
  - AWS alternative: ElastiCache Redis
  - Azure alternative: Azure Cache for Redis
  - Use for: Query result caching, session storage

### Infrastructure
- **Serverless Containers** - Docker-based container execution
  - Currently: GCP Cloud Run (see [ADR-004](docs/adr/004-cloud-run-not-kubernetes.md))
  - AWS alternative: ECS Fargate or AWS App Runner
  - Azure alternative: Azure Container Apps
  - Serverless scaling, pay-per-use
- **Terraform** - Infrastructure as Code (cloud-agnostic)
- **Grafana** - Monitoring dashboards (native BigQuery & Cloud SQL integration)
  - Direct SQL queries to BigQuery for cost metrics
  - Direct SQL queries to Cloud SQL for operational data
  - No Prometheus needed - Grafana has native database support
- **Distributed Tracing & Metrics** - Application observability
  - Option 1 (Vendor-neutral): OpenTelemetry → Cloud Trace/X-Ray/App Insights
  - Option 2 (Cloud-native): Direct integration with Cloud Trace (GCP), X-Ray (AWS), Application Insights (Azure)
  - Use for: Debugging multi-agent flows, performance optimization, request tracing

### Why Distributed Tracing?

The platform uses a **multi-agent, multi-service architecture**. A single user query triggers a cascade of calls:

```
User: "Why did AWS costs spike yesterday?"
  ↓
AG-UI Server (50ms)
  ↓
Coordinator Agent (120ms)
  ↓ (parallel execution)
Cost Agent → AWS MCP → AWS Cost Explorer API (800ms)
Cost Agent → GCP MCP → BigQuery (200ms)
Cost Agent → Azure MCP → Cost Management API (TIMEOUT)
  ↓
Total response time: 1.2s
```

**Distributed tracing** shows you:
- ✅ Which agent/MCP call is slow
- ✅ Where timeouts occur
- ✅ End-to-end request latency
- ✅ Bottlenecks in the agent hierarchy

**Two implementation options**:
1. **OpenTelemetry** (vendor-neutral) → Works across all clouds
2. **Cloud-native** (GCP Cloud Trace, AWS X-Ray, Azure App Insights) → Simpler setup

Use for debugging multi-agent flows and performance optimization in production.


---

## 🔄 AG-UI Streaming Architecture

The platform uses **AG-UI (Agent-to-UI)** protocol for real-time streaming communication between agents and the user interface.

### How It Works

```
User Query → CopilotKit (Frontend)
    ↓ POST /api/copilotkit
AG-UI Server (FastAPI + SSE)
    ↓ JWT validation + tenant context injection
Coordinator Agent
    ↓ routes to appropriate agents
Domain Agents → Cloud Agents (parallel execution)
    ↓ MCP tool calls
Cloud APIs (AWS, Azure, GCP, K8s)
    ↓ stream results back
AG-UI Server (SSE stream)
    ↓ StateSnapshot events
CopilotKit (progressive UI rendering)
```

### Key Features

- **Real-Time Streaming**: Server-Sent Events (SSE) for one-way server-to-client updates
- **Firestore Real-Time (Single-Owner)**: Alternative streaming via Firestore listeners for task progress and notifications
- **Progressive Rendering**: UI updates as agents discover information
- **Stateful Sessions**: Maintains conversation context across multiple queries
- **Multi-Agent Coordination**: Single query triggers hierarchical agent execution
- **Security**: JWT authentication and tenant context validation at AG-UI server

### Implementation

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Frontend Client** | CopilotKit | Chat widget with AG-UI protocol support |
| **AG-UI Server** | FastAPI + SSE | Streaming endpoint, auth, routing |
| **Event Types** | StateSnapshot, ProgressUpdate | UI state and progress indicators |
| **Endpoint** | `/api/copilotkit` | Single SSE streaming endpoint |

See [`finops-agent-a2ui-flow.svg`](core/finops-agent-a2ui-flow.svg) for complete sequence diagram.

---


## 🚀 Operational Modes

AI Cost Monitoring operates in **four distinct modes** that work together:

### Mode 1: Interactive (User-Driven)
Conversational AI interface where users ask natural language questions and receive real-time streaming responses.

**Examples:**
- *"Why did our AWS bill increase by 40% last month?"*
- *"Show me all idle resources across clouds"*
- *"Compare our GCP vs Azure compute costs"*

### Mode 2: Scheduled (Background Pipeline)
Automated data pipeline that runs continuously, keeping the local database fresh.

**Key Jobs:**
- Cost Data Sync (every 4 hours)
- Resource Inventory (every 6 hours)
- Anomaly Detection (every 4 hours)
- Recommendation Refresh (daily at 2 AM)
- Forecast Update (daily at 3 AM)

### Mode 3: Event-Driven (Reactive)
Real-time response to events from cloud environments via webhooks.

**Event Sources:**
- AWS CloudWatch Alarms → SNS → Webhook
- Azure Monitor → Action Group → Webhook
- GCP Cloud Monitoring → Pub/Sub → Push
- Kubernetes Webhook: Cluster alerts (OpenCost or native) → HTTP endpoint

### Mode 4: A2A — Agent-to-Agent
External AI agents initiate queries through the Google A2A Protocol gateway.

**External Agent Types:**
- SlackBot Agent - Team cost queries in Slack
- Compliance Auditor - Nightly policy violation scans
- Vendor Advisor - Savings opportunity checks
- Security Scanner - Cost-related security checks

---

## 🔐 Security & Deployment Modes

### Deployment Modes

**Single-Tenant Mode (Default)**:
- Designed for one organization managing their own cloud costs
- Simplified setup and better performance (no RLS overhead)
- All users within organization have access based on RBAC roles
- Database uses a single tenant ID (randomly generated during setup)
- Recommended for most deployments

**Multi-Tenant Mode (Optional)**:
- Enable via `TENANT_MODE=multi` environment variable
- For MSPs, consultancies, or platforms managing multiple clients
- Full tenant isolation at database, cache, and storage layers
- Tenant selection required at login
- Row-Level Security (RLS) enforced for data isolation

### Tenant Isolation (Multi-Tenant Mode)

> [!NOTE]
> These isolation mechanisms are built into the schema but only enforced when `TENANT_MODE=multi`.

- **PostgreSQL Row-Level Security (RLS)** - Database-level tenant data isolation
- **PostgreSQL Partitioning** - Partitioned by `tenant_id` for multi-tenant performance
- **Redis Key Namespacing** - `tenant:{id}:*` pattern
- **Object Storage Path Isolation** - `/{tenant_id}/` paths
- **Secret Manager Path Isolation** - Home cloud's secret manager with tenant-specific naming
  - GCP: `projects/{project}/secrets/tenant-{id}-{provider}`
  - AWS: `tenant/{id}/{provider}`
  - Azure: `tenant-{id}-{provider}`

### Authentication
- **Single Sign-On (SSO)** - Google, Microsoft, Okta, SAML
- **Multi-Factor Authentication (MFA)** - TOTP, WebAuthn
- **Secure Session Management** - JWT with refresh tokens

### Authorization
- **5 Role-Based Access Levels**: Super Admin → Org Admin → Operator → Analyst → Viewer
- **Permission-Based Tool Access** - Every API call validated
- **Approval Workflows** - For sensitive remediation actions (optional multi-level in multi-tenant mode)

### Compliance
- **Audit Logging** - Immutable 7-year retention
- **SOC 2 Ready** - Security controls aligned
- **GDPR Compliant** - Data privacy controls
- **Encryption** - AES-256 at rest, TLS 1.3 in transit

---

## 🌐 Cloud Provider Integration

| Provider | Integration Method | Capabilities |
|----------|-------------------|--------------|
| **AWS** | IAM AssumeRole | Cost Explorer, Compute Optimizer, Trusted Advisor, CloudWatch |
| **Azure** | Service Principal | Cost Management, Advisor, Resource Graph, Monitor |
| **GCP** | Service Account | Cloud Billing, Recommender, Asset Inventory, Monitoring |
| **Kubernetes** | Kubeconfig | OpenCost, VPA/HPA, Resource Metrics |

---

## 👥 User Roles & Permissions

| Role | Description | Permissions |
|------|-------------|-------------|
| **Super Admin** | Platform administrator | Full system access |
| **Org Admin** | Tenant administrator | Manage users, roles, cloud accounts |
| **Operator** | Operations team | Execute remediation actions |
| **Analyst** | Finance/FinOps team | View costs, create reports |
| **Viewer** | Read-only access | View dashboards only |

---

## 📋 Architecture Decision Records

Key architectural decisions are documented in [docs/adr/](docs/adr/):

- **[ADR-001](docs/adr/001-use-mcp-servers.md)** - Use MCP Servers Instead of REST APIs
- **[ADR-002](docs/adr/002-gcp-only-first.md)** - Start with GCP-Only, Not Multi-Cloud
- **[ADR-003](docs/adr/003-use-bigquery-not-timescaledb.md)** - Use BigQuery for Metrics, Not TimescaleDB
- **[ADR-004](docs/adr/004-cloud-run-not-kubernetes.md)** - Deploy to Cloud Run, Not Kubernetes

---

## 📊 Project Metrics

| Metric | 15-Day MVP | Full Platform |
|--------|------------|---------------|
| **Cloud Providers** | 3 (AWS, Azure, GCP) | 4 (+ Kubernetes) |
| **AI Agents** | 1 (simple LLM) | 11 (multi-agent) |
| **MCP Servers** | 0 | 8 |
| **Dashboard** | Grafana | Grafana + AG-UI |
| **Monthly Cost** | $0-20 | $50-150 (SaaS) |
| **Development Time** | 15 days | ~9 months |

---

## 🗓️ Development Options

### Option A: 15-Day MVP (AI-Assisted)

For teams wanting quick multi-cloud visibility with basic AI chat:

| Week | Focus | Deliverables |
|------|-------|--------------|
| **Week 1** | Infrastructure + Connectors | GCP/AWS/Azure cost data flowing to BigQuery |
| **Week 2** | Backend + Dashboard | FastAPI API, Grafana dashboards |
| **Week 3** | LLM + Deploy | Simple chat interface, Cloud Run deployment |

**What you get:** Multi-cloud cost visibility, Grafana dashboards, basic LLM chat (~60-70% of full vision)

**What's excluded:** MCP servers, multi-agent orchestration, AG-UI streaming, anomaly detection, remediation workflows

**Cost:** $0-20/month infrastructure + $5-55 development costs

See [core/08-cost-model.md](core/08-cost-model.md#05-realistic-development-timeline-ai-assisted) for detailed breakdown.

### Option B: Full Platform (36 weeks)

For teams building the complete AI-agent architecture:

| Phase | Duration | Focus |
|-------|----------|-------|
| **Phase 1** | 5 weeks | Foundation (OAuth Provider, Secret Manager, PostgreSQL, Cloud Tasks) |
| **Phase 2** | 5 weeks | MCP Servers (AWS, Azure, GCP, OpenCost) |
| **Phase 3** | 5 weeks | Cloud Agents (AWS, Azure, GCP, K8s) |
| **Phase 4** | 5 weeks | Domain Agents (Cost, Optimization, Remediation) |
| **Phase 5** | 4 weeks | AG-UI/A2UI Integration |
| **Phase 6** | 4 weeks | Optional Multi-Tenant Support & A2A Gateway |
| **Phase 7** | 4 weeks | Security Hardening |
| **Phase 8** | 4 weeks | Testing & Documentation |

---

## 📚 Documentation

### Deployment & Configuration
- **[GCP Deployment Guide](GCP-DEPLOYMENT.md)** - Complete deployment instructions
- **[Cloud Configuration](CLOUD_CONFIG.md)** - GCP project and service settings
- **[Environment Variables](.env.example)** - Configuration template
- **[Terraform Infrastructure](terraform/)** - Infrastructure as Code

### Core Specifications
- **[Database Schema](core/01-database-schema.md)** - Complete data model and storage strategy
- **[MCP Tool Contracts](core/02-mcp-tool-contracts.md)** - MCP server specifications
- **[Agent Routing](core/03-agent-routing-spec.md)** - Agent orchestration logic
- **[Tenant Onboarding](core/04-tenant-onboarding.md)** - Multi-tenant setup flow
- **[API Endpoints](core/05-api-endpoint-spec.md)** - REST API specifications
- **[Deployment Infrastructure](core/07-deployment-infrastructure.md)** - Cloud Run deployment
- **[Cost Model](core/08-cost-model.md)** - Platform pricing and cost structure

### Architecture Diagrams
Located in the `core/` directory with `.svg` extension:
- `finops-architecture-final.svg` - Main system architecture
- `finops-auth-flow.svg` - Authentication flow
- `finops-agent-a2ui-flow.svg` - AG-UI streaming sequence
- `finops-agent-mcp-detail.svg` - MCP server specifications
- `ai-cost-monitoring-operational-modes.svg` - Operational modes

---

## 🤝 Contributing

This is a USDA AI Innovation Hub project. For contribution guidelines, please contact the project maintainers.

---

## 📄 License

This project is proprietary software developed by the USDA AI Innovation Hub.

---

## 📞 Contact

**Project:** AI Cloud Cost Monitoring  
**Organization:** USDA AI Innovation Hub  
**Repository:** [https://github.com/vladm3105/ai-cloud-monitoring](https://github.com/vladm3105/ai-cloud-monitoring)  
**Version:** 1.0  
**Last Updated:** February 2026

---

*Built with ❤️ by the USDA AI Innovation Hub*
