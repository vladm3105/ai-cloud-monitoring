# AI Cloud Cost Monitoring

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![GCP](https://img.shields.io/badge/cloud-GCP-4285F4?logo=google-cloud)](https://cloud.google.com)
[![Status](https://img.shields.io/badge/status-in%20development-yellow)](https://github.techtrend.us/USDA-AI-Innovation-Hub/AI-Cloud-Cost-Monitoring)

> **Self-hosted AI-powered FinOps platform for intelligent cloud cost analysis, optimization, and automated remediation across AWS, Azure, GCP, and Kubernetes.**

AI Cloud Cost Monitoring leverages AI agents built on Google ADK (Agent Development Kit) to provide natural language interactions for cloud cost management with real-time streaming UI responses. Designed for **single-organization deployments** with optional multi-tenant support for MSPs and consultancies.

## 🚀 Quick Start

### Deployment to GCP

The platform is designed to run on Google Cloud Platform using Cloud Run:

1. **Prerequisites**: GCP project with billing enabled, gcloud CLI installed
2. **Deploy**: Follow the [GCP Deployment Guide](GCP-DEPLOYMENT.md)
3. **Configure**: Use [cloud-config.yaml](cloud-config.yaml) and [.env.example](.env.example)
4. **Infrastructure**: Terraform configs in [terraform/](terraform/)

**Estimated Setup Time**: 30-45 minutes  
**Monthly Cost**: ~$75-130 (MVP), ~$420-770 (Production)

> [!NOTE]
> Currently optimized for GCP deployment (per [ADR-002](docs/adr/002-gcp-only-first.md)). Multi-cloud expansion planned for future phases.

### Home Cloud vs Monitored Clouds

**Important Architectural Distinction:**

- **Home Cloud (Primary Cloud)**: GCP - Where the platform itself runs
  - Hosts the frontend (Next.js on Cloud Run)
  - Hosts the backend orchestrator (FastAPI on Cloud Run)
  - Hosts the database (Cloud SQL PostgreSQL)
  - Hosts the cache (Cloud Memorystore Redis)
  - Infrastructure managed via Terraform

- **Monitored Clouds**: AWS, Azure, GCP, Kubernetes - What the platform analyzes
  - The platform connects to these clouds via APIs
  - Retrieves cost data, resource inventories, recommendations
  - Can execute remediation actions (with approval)
  - GCP appears in both roles (home cloud + monitored cloud)

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
│   └── adr/                        # Architecture Decision Records
│       ├── 001-use-mcp-servers.md
│       ├── 002-gcp-only-first.md
│       ├── 003-use-bigquery-not-timescaledb.md
│       └── 004-cloud-run-not-kubernetes.md
├── terraform/                      # Infrastructure as Code
│   ├── main.tf                    # Main Terraform configuration
│   ├── variables.tf               # Variable declarations
│   ├── outputs.tf                 # Output values
│   └── modules/                   # Terraform modules
├── GCP-only/                       # GCP-specific implementation
├── UX/                            # User experience and UI documentation
├── cloud-config.yaml              # Cloud platform configuration
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
- **Gemini 2.0 / Claude** - LLM backbone
- **AG-UI Protocol** - Agent-to-UI streaming (FastAPI SSE endpoint: `/api/copilotkit`)

### Backend
- **FastAPI** - AG-UI server (handles SSE streaming, JWT validation, tenant context)
- **FastMCP** - MCP server framework
- **Cloud Task Queue & Scheduler** - Background jobs and workflow orchestration
  - Currently: GCP Cloud Tasks + Cloud Scheduler
  - AWS alternative: SQS + EventBridge + Lambda
  - Azure alternative: Service Bus + Azure Functions
  - Handles: Data sync (every 4 hours), anomaly detection, forecasts, approval workflows

### Authentication & Security
- **OAuth 2.0/OIDC Provider** - Auth0 (current), or any OAuth provider
  - Alternatives: Okta, Azure AD, Google Identity, AWS Cognito, Keycloak
  - Provides SSO, MFA, social login, and session management
- **Home Cloud Secret Manager** - Uses the secret manager of the home cloud
  - Currently: GCP Secret Manager (auto-rotation, HA, IAM integration)
  - If home cloud changes: AWS Secrets Manager or Azure Key Vault
  - Stores cloud credentials for monitored accounts (never in database)
- **JWT/OIDC** - Token-based authentication
- **RBAC** - Role-based access control

### Data Layer
- **Cloud SQL PostgreSQL 16** - Relational data with Row-Level Security
- **BigQuery** - Time-series cost metrics (per [ADR-003](docs/adr/003-use-bigquery-not-timescaledb.md))
- **Cloud Memorystore Redis 7** - Caching and message queue
- **Cloud Storage** - Object storage for reports and backups

### Infrastructure
- **Docker + Cloud Run** - Serverless containers (see [ADR-004](docs/adr/004-cloud-run-not-kubernetes.md))
- **Terraform** - Infrastructure as Code
- **Grafana** - Monitoring dashboards (native BigQuery & Cloud SQL integration)
  - Direct SQL queries to BigQuery for cost metrics
  - Direct SQL queries to Cloud SQL for operational data
  - No Prometheus needed - Grafana has native database support
- **OpenTelemetry** - Distributed tracing and application metrics


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
- **TimescaleDB Partitioning** - Partitioned by `tenant_id`
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

| Metric | Value |
|--------|-------|
| **Total Agents** | 11 |
| **Domain Agents** | 6 |
| **Cloud Agents** | 4 |
| **MCP Servers** | 8 |
| **Cloud Providers Supported** | 4 (AWS, Azure, GCP, K8s) |
| **RBAC Roles** | 5 |
| **Estimated Development Timeline** | ~9 months |

---

## 🗓️ Development Phases

| Phase | Duration | Focus |
|-------|----------|-------|
| **Phase 1** | 5 weeks | Foundation (OAuth Provider, Secret Manager, PostgreSQL, Redis) |
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
- **[Cloud Configuration](cloud-config.yaml)** - GCP project and service settings
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
**Repository:** [https://github.techtrend.us/USDA-AI-Innovation-Hub/AI-Cloud-Cost-Monitoring](https://github.techtrend.us/USDA-AI-Innovation-Hub/AI-Cloud-Cost-Monitoring)  
**Version:** 1.0  
**Last Updated:** February 2026

---

*Built with ❤️ by the USDA AI Innovation Hub*
