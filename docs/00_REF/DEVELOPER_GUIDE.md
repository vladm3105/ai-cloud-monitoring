# Developer Guide

Complete guide for setting up and working with the AI Cost Monitoring platform locally.

## Table of Contents

- [Development Paths](#development-paths)
- [Prerequisites](#prerequisites)
- [Quick Start (15-Day MVP)](#quick-start-15-day-mvp)
- [Project Structure](#project-structure)
- [Local Development](#local-development)
- [Common Tasks](#common-tasks)
- [Debugging](#debugging)
- [Deployment](#deployment)
- [Troubleshooting](#troubleshooting)
- [AI-Assisted Development](#ai-assisted-development)

---

## Development Paths

This project supports two development approaches:

| Path | Timeline | Stack | Use Case |
|------|----------|-------|----------|
| **15-Day MVP** | 3 weeks | Firestore + BigQuery + Grafana | Quick multi-cloud visibility |
| **Full Platform** | 9 months | PostgreSQL + BigQuery + AG-UI | Complete AI-agent architecture |

**This guide focuses on the 15-Day MVP path.** For full platform development, see [HANDOFF.md](HANDOFF.md).

---

## Prerequisites

### Required Software

| Tool | Version | Purpose |
|------|---------|---------|
| **Python** | 3.11+ | Backend API, connectors |
| **Node.js** | 18+ | Frontend (if building AG-UI) |
| **gcloud CLI** | Latest | GCP interaction |
| **Docker** | Optional | Local container testing |
| **Git** | Latest | Version control |

### Install gcloud CLI

```bash
# macOS
brew install google-cloud-sdk

# Linux
curl https://sdk.cloud.google.com | bash

# Verify
gcloud --version
```

### Cloud Accounts

**Home Cloud (where the platform runs):**
- **GCP** (recommended) - Best free tier for MVP

**Monitored Clouds (what the platform analyzes):**
- GCP, AWS, Azure - as needed

---

## Quick Start (15-Day MVP)

### Day 1-2: GCP Project Setup

#### 1. Create GCP Project

```bash
# Set project ID
export PROJECT_ID="ai-cost-monitoring-$(date +%s)"

# Create project
gcloud projects create $PROJECT_ID --name="AI Cost Monitoring"

# Set as default
gcloud config set project $PROJECT_ID

# Enable billing (required)
# Visit: https://console.cloud.google.com/billing/linkedaccount?project=$PROJECT_ID
```

#### 2. Enable Required APIs

```bash
# Enable all required APIs
gcloud services enable \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  firestore.googleapis.com \
  bigquery.googleapis.com \
  cloudtasks.googleapis.com \
  cloudscheduler.googleapis.com \
  secretmanager.googleapis.com \
  artifactregistry.googleapis.com
```

#### 3. Set Up Firestore

```bash
# Create Firestore database (Native mode)
gcloud firestore databases create --location=us-central1
```

#### 4. Set Up BigQuery Billing Export

```bash
# Create dataset for billing export
bq mk --dataset --location=US ${PROJECT_ID}:billing_export

# Enable billing export in console:
# Billing > Billing Export > BigQuery Export > Enable
```

### Day 3: Clone and Configure

#### 1. Clone Repository

```bash
git clone https://github.com/your-org/ai-cloud-cost-monitoring.git
cd ai-cloud-cost-monitoring
```

#### 2. Set Up Python Environment

```bash
# Create virtual environment
python3.11 -m venv venv

# Activate (macOS/Linux)
source venv/bin/activate

# Activate (Windows)
venv\Scripts\activate

# Install dependencies
pip install --upgrade pip
pip install -r requirements.txt
```

#### 3. Configure Environment

```bash
# Copy example environment file
cp .env.example .env

# Edit with your values
nano .env
```

**MVP Environment Variables:**

```bash
# GCP Configuration
GCP_PROJECT_ID=your-project-id
GCP_REGION=us-central1

# BigQuery
BIGQUERY_DATASET=billing_export
BIGQUERY_BILLING_TABLE=gcp_billing_export_v1_XXXXXX_XXXXXX

# LLM (choose one)
GOOGLE_API_KEY=your-gemini-api-key
# or
ANTHROPIC_API_KEY=your-claude-api-key

# Optional: Multi-cloud connectors
AWS_ACCESS_KEY_ID=your-aws-key
AWS_SECRET_ACCESS_KEY=your-aws-secret
AZURE_CLIENT_ID=your-azure-client-id
AZURE_CLIENT_SECRET=your-azure-secret
AZURE_TENANT_ID=your-azure-tenant
```

#### 4. Authenticate with GCP

```bash
# Login to GCP
gcloud auth login

# Set application default credentials
gcloud auth application-default login

# Verify
gcloud config list
```

### Day 4-5: Verify Setup

#### Test BigQuery Connection

```bash
# Run test query
python -c "
from google.cloud import bigquery
client = bigquery.Client()
query = 'SELECT 1 as test'
result = list(client.query(query).result())
print('BigQuery connected:', result)
"
```

#### Test Firestore Connection

```bash
# Run test write/read
python -c "
from google.cloud import firestore
db = firestore.Client()
doc_ref = db.collection('test').document('connection')
doc_ref.set({'status': 'connected'})
doc = doc_ref.get()
print('Firestore connected:', doc.to_dict())
doc_ref.delete()
"
```

---

## Project Structure

### MVP Structure (15-Day)

```
ai-cloud-cost-monitoring/
├── src/
│   ├── api/                    # FastAPI backend
│   │   ├── main.py            # API entry point
│   │   ├── routes/            # API endpoints
│   │   │   ├── costs.py       # Cost query endpoints
│   │   │   ├── health.py      # Health check
│   │   │   └── chat.py        # LLM chat endpoint
│   │   └── middleware/        # Auth, CORS
│   │
│   ├── connectors/             # Cloud cost connectors
│   │   ├── gcp.py             # GCP BigQuery connector
│   │   ├── aws.py             # AWS Cost Explorer connector
│   │   └── azure.py           # Azure Cost Management connector
│   │
│   ├── llm/                    # LLM integration
│   │   ├── chat.py            # Simple chat interface
│   │   └── prompts.py         # System prompts
│   │
│   └── utils/                  # Shared utilities
│       ├── bigquery.py        # BigQuery helpers
│       ├── firestore.py       # Firestore helpers
│       └── auth.py            # GCP IAM auth
│
├── grafana/                    # Grafana dashboards
│   ├── dashboards/            # JSON dashboard definitions
│   └── datasources/           # BigQuery data source config
│
├── terraform/                  # Infrastructure as Code
│   └── gcp/                   # GCP resources
│
├── tests/                      # Tests
│   ├── unit/
│   └── integration/
│
├── core/                       # Specifications (reference)
├── docs/                       # Documentation
├── .env.example               # Environment template
├── requirements.txt           # Python dependencies
└── README.md                  # Project overview
```

### Full Platform Structure (reference)

See [HANDOFF.md](HANDOFF.md) for full structure including:
- `src/agents/` - AI agent hierarchy
- `src/mcp/` - MCP servers
- `ag-ui-server/` - Next.js frontend with CopilotKit

---

## Local Development

### Running the Backend API

```bash
# Development mode (auto-reload)
uvicorn src.api.main:app --reload --port 8000

# With environment
ENVIRONMENT=development uvicorn src.api.main:app --reload
```

### Working with BigQuery

**Query GCP billing data:**

```python
from google.cloud import bigquery

client = bigquery.Client()
query = """
    SELECT
        DATE(usage_start_time) as date,
        service.description as service,
        SUM(cost) as total_cost
    FROM `{project}.billing_export.gcp_billing_export_v1_*`
    WHERE DATE(usage_start_time) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    GROUP BY date, service
    ORDER BY total_cost DESC
    LIMIT 20
"""
results = client.query(query.format(project=PROJECT_ID)).result()
for row in results:
    print(f"{row.date} | {row.service}: ${row.total_cost:.2f}")
```

### Working with Firestore

**Store configuration:**

```python
from google.cloud import firestore

db = firestore.Client()

# Save cloud account config
db.collection('config').document('aws-account-1').set({
    'provider': 'aws',
    'account_id': '123456789',
    'display_name': 'Production AWS',
    'status': 'active',
    'last_sync': firestore.SERVER_TIMESTAMP
})

# Read with real-time listener
def on_snapshot(doc_snapshot, changes, read_time):
    for doc in doc_snapshot:
        print(f'Config updated: {doc.id} => {doc.to_dict()}')

doc_ref = db.collection('config')
doc_ref.on_snapshot(on_snapshot)
```

### Adding AWS Cost Connector

```python
# src/connectors/aws.py
import boto3
from datetime import datetime, timedelta

def get_aws_costs(days: int = 30) -> list:
    """Fetch AWS costs from Cost Explorer."""
    client = boto3.client('ce')

    end = datetime.now()
    start = end - timedelta(days=days)

    response = client.get_cost_and_usage(
        TimePeriod={
            'Start': start.strftime('%Y-%m-%d'),
            'End': end.strftime('%Y-%m-%d')
        },
        Granularity='DAILY',
        Metrics=['UnblendedCost'],
        GroupBy=[
            {'Type': 'DIMENSION', 'Key': 'SERVICE'}
        ]
    )

    return response['ResultsByTime']
```

### Adding Azure Cost Connector

```python
# src/connectors/azure.py
from azure.identity import ClientSecretCredential
from azure.mgmt.costmanagement import CostManagementClient

def get_azure_costs(subscription_id: str, days: int = 30) -> dict:
    """Fetch Azure costs from Cost Management API."""
    credential = ClientSecretCredential(
        tenant_id=os.getenv('AZURE_TENANT_ID'),
        client_id=os.getenv('AZURE_CLIENT_ID'),
        client_secret=os.getenv('AZURE_CLIENT_SECRET')
    )

    client = CostManagementClient(credential)

    scope = f'/subscriptions/{subscription_id}'

    # Query costs
    result = client.query.usage(
        scope=scope,
        parameters={
            'type': 'ActualCost',
            'timeframe': 'MonthToDate',
            'dataset': {
                'granularity': 'Daily',
                'aggregation': {
                    'totalCost': {'name': 'Cost', 'function': 'Sum'}
                }
            }
        }
    )

    return result
```

---

## Common Tasks

### Adding a New API Endpoint

1. **Create route** in `src/api/routes/`:

```python
# src/api/routes/costs.py
from fastapi import APIRouter, HTTPException
from src.connectors import gcp, aws, azure

router = APIRouter(prefix="/api/costs", tags=["costs"])

@router.get("/summary")
async def get_cost_summary(days: int = 30):
    """Get multi-cloud cost summary."""
    try:
        gcp_costs = gcp.get_costs(days)
        aws_costs = aws.get_aws_costs(days)
        # azure_costs = azure.get_azure_costs(subscription_id, days)

        return {
            "gcp": gcp_costs,
            "aws": aws_costs,
            # "azure": azure_costs,
            "period_days": days
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
```

2. **Register in main app**:

```python
# src/api/main.py
from fastapi import FastAPI
from src.api.routes import costs, health, chat

app = FastAPI(title="AI Cost Monitoring API")

app.include_router(health.router)
app.include_router(costs.router)
app.include_router(chat.router)
```

### Adding Simple LLM Chat

```python
# src/llm/chat.py
import google.generativeai as genai

genai.configure(api_key=os.getenv('GOOGLE_API_KEY'))

SYSTEM_PROMPT = """You are a cloud cost analyst assistant.
You have access to cost data from GCP, AWS, and Azure.
Answer questions about cloud spending, trends, and optimization opportunities.
Be concise and data-driven in your responses."""

def chat_with_costs(user_query: str, cost_context: dict) -> str:
    """Answer cost questions using LLM."""
    model = genai.GenerativeModel('gemini-1.5-flash')

    prompt = f"""{SYSTEM_PROMPT}

Current cost data:
{cost_context}

User question: {user_query}

Provide a helpful, data-driven response:"""

    response = model.generate_content(prompt)
    return response.text
```

### Running Tests

```bash
# All Python tests
pytest

# Specific test file
pytest tests/unit/test_connectors.py

# With coverage
pytest --cov=src --cov-report=html
open htmlcov/index.html
```

---

## Debugging

### Python Debugging

**VS Code configuration (`.vscode/launch.json`):**

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "FastAPI",
      "type": "python",
      "request": "launch",
      "module": "uvicorn",
      "args": ["src.api.main:app", "--reload"],
      "env": {"ENVIRONMENT": "development"}
    }
  ]
}
```

### Logging

```python
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

logger.info("Cost sync started")
logger.error("AWS connection failed", exc_info=True)
```

---

## Deployment

### Deploy to Cloud Run

```bash
# Build and deploy API
gcloud run deploy ai-cost-api \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated

# Get service URL
gcloud run services describe ai-cost-api --region=us-central1 --format='value(status.url)'
```

### Set Up Cloud Scheduler for Sync

```bash
# Create sync job (every 4 hours)
gcloud scheduler jobs create http cost-sync-job \
  --location=us-central1 \
  --schedule="0 */4 * * *" \
  --uri="https://YOUR-SERVICE-URL/api/sync" \
  --http-method=POST \
  --oidc-service-account-email=YOUR-SERVICE-ACCOUNT@PROJECT.iam.gserviceaccount.com
```

See [GCP-DEPLOYMENT.md](GCP-DEPLOYMENT.md) for complete deployment guide.

---

## Adding New Cloud Providers

The platform uses a hybrid agent registration pattern that makes adding new cloud providers straightforward. See [ADR-009](docs/adr/009-hybrid-agent-registration-pattern.md) for the registration pattern and [ADR-010](docs/adr/010-agent-card-specification.md) for the AgentCard specification.

### Overview

Adding a new cloud provider requires:

| Component | Description | Effort |
|-----------|-------------|--------|
| MCP Server | Wraps cloud provider APIs | 2-4 hours |
| Cloud Agent | Self-registering agent with AgentCard | 1-2 hours |
| Credential Schema | Pydantic model for credential validation | 30 min |
| Tests | Unit tests for MCP tools | 1-2 hours |

**No changes required to:** Coordinator Agent, Domain Agents, routing logic, or frontend.

### Step 1: Create MCP Server

Create a new MCP server that implements the 6 required tools:

```python
# src/mcp_servers/oracle_mcp.py
from src.mcp_servers.base import BaseMCPServer, cloud_provider
from src.models.responses import CostDataResponse, ResourceListResponse

@cloud_provider("oracle", port=8090)
class OracleMCPServer(BaseMCPServer):
    """MCP Server for Oracle Cloud Infrastructure"""

    async def get_costs(self, tenant_id: str, account_id: str, **params) -> CostDataResponse:
        credentials = await self.get_credentials(tenant_id, account_id)
        # Call Oracle Usage API
        # Transform response to CostDataResponse
        ...

    async def get_resources(self, tenant_id: str, account_id: str, **params) -> ResourceListResponse:
        # Call Oracle Resource Manager API
        ...

    async def get_recommendations(self, tenant_id: str, account_id: str, **params):
        # Call Oracle Cloud Advisor API
        ...

    async def get_anomalies(self, tenant_id: str, account_id: str, **params):
        # Implement anomaly detection
        ...

    async def execute_action(self, tenant_id: str, account_id: str, **params):
        # Call Oracle compute/database APIs for remediation
        ...

    async def get_idle_resources(self, tenant_id: str, account_id: str, **params):
        # Query Oracle Monitoring for idle resources
        ...
```

### Step 2: Create Cloud Agent

Create a self-registering Cloud Agent with an **AgentCard**. The AgentCard is a Pydantic model that declares the agent's capabilities for dynamic discovery:

| AgentCard Field | Purpose | Example |
|-----------------|---------|---------|
| `name` | Unique identifier | `"oracle"` |
| `type` | Agent category | `AgentType.CLOUD_PROVIDER` |
| `version` | Semantic version | `"1.0.0"` |
| `capabilities.tools` | Supported operations | `["get_costs", "get_resources", ...]` |
| `capabilities.providers` | Cloud provider(s) | `["oracle"]` |
| `capabilities.permissions_required` | RBAC permissions | `["read:costs"]` |

Create a self-registering Cloud Agent:

```python
# src/agents/cloud/oracle_agent.py
from src.agents.base import BaseCloudAgent
from src.core.agent_registry import AgentRegistry, AgentCard, AgentType, AgentCapability
from src.mcp_servers.oracle_mcp import OracleMCPServer

class OracleCloudAgent(BaseCloudAgent):
    """Oracle Cloud Agent - self-registers on instantiation"""

    CARD = AgentCard(
        name="oracle",
        type=AgentType.CLOUD_PROVIDER,
        version="1.0.0",
        capabilities=AgentCapability(
            tools=["get_costs", "get_resources", "get_recommendations",
                   "get_anomalies", "execute_action", "get_idle_resources"],
            providers=["oracle"],
            permissions_required=["read:costs", "read:resources"]
        )
    )

    def __init__(self, mcp_server: OracleMCPServer = None):
        super().__init__()
        self.mcp = mcp_server or OracleMCPServer()
        AgentRegistry.register(self.CARD, self)  # Auto-registration

    async def get_costs(self, tenant_context, params):
        return await self.mcp.get_costs(
            tenant_id=tenant_context.tenant_id,
            account_id=params.get("account_id"),
            **params
        )

    # Implement other methods...
```

### Step 3: Add Credential Schema

Define the credential validation schema:

```python
# src/credentials/schemas.py (add to existing file)
from pydantic import BaseModel, SecretStr

class OracleCredentials(BaseModel):
    """Oracle Cloud Infrastructure credentials"""
    tenancy_ocid: str
    user_ocid: str
    fingerprint: str
    private_key: SecretStr
    region: str = "us-ashburn-1"

# Add to registry
CREDENTIAL_SCHEMAS["oracle"] = OracleCredentials
```

### Step 4: Add Provider Configuration

Add provider metadata to config:

```yaml
# config/providers.yaml (add to existing file)
providers:
  oracle:
    name: "Oracle Cloud Infrastructure"
    mcp_port: 8090
    credential_type: "api_key"
    credential_fields:
      - tenancy_ocid
      - user_ocid
      - fingerprint
      - private_key
    cost_api: "Usage API"
    resource_api: "Resource Manager"
    recommendation_api: "Cloud Advisor"
    rate_limits:
      requests_per_second: 10
      burst: 20
```

### Step 5: Register on Startup

Ensure the agent is instantiated on application startup:

```python
# src/main.py (add to startup)
from src.agents.cloud.oracle_agent import OracleCloudAgent

def initialize_agents():
    # Existing agents...
    OracleCloudAgent()  # Self-registers
```

### Step 6: Add Tests

```python
# tests/mcp_servers/test_oracle_mcp.py
from tests.base import BaseMCPServerTest
from src.mcp_servers.oracle_mcp import OracleMCPServer

class TestOracleMCPServer(BaseMCPServerTest):
    @pytest.fixture
    def mcp_server(self):
        return OracleMCPServer()

    # Inherits standard tests from BaseMCPServerTest
    # Add Oracle-specific tests below

    async def test_oracle_specific_behavior(self, mcp_server):
        # Test Oracle-specific functionality
        ...
```

### Verification

After deployment, the new provider is automatically discoverable:

```python
# Domain Agent automatically finds the new provider
cloud_agents = AgentRegistry.get_cloud_agents()
# Returns: [AWSAgent, AzureAgent, GCPAgent, K8sAgent, OracleAgent]

# Tenant with Oracle account connected will include it in queries
costs = await cost_agent.get_multi_cloud_costs(tenant_context, params)
# Includes Oracle costs if tenant has oracle account
```

### Provider Checklist

Before deploying a new provider:

- [ ] MCP Server implements all 6 required tools
- [ ] Cloud Agent has valid AgentCard with capabilities
- [ ] Credential schema validates all required fields
- [ ] Secret Manager path follows convention: `tenant-{id}-{provider}`
- [ ] Unit tests pass for all MCP tools
- [ ] Integration test with real cloud API (sandbox account)
- [ ] Rate limits configured appropriately
- [ ] Error handling returns standard MCPError format

---

## Troubleshooting

### Common Issues

**Issue:** `ModuleNotFoundError: No module named 'src'`

```bash
# Solution: Run from project root with -m flag
cd /path/to/ai-cloud-cost-monitoring
source venv/bin/activate
python -m src.api.main
```

**Issue:** BigQuery authentication fails

```bash
# Solution: Re-authenticate
gcloud auth application-default login

# Or use service account
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
```

**Issue:** Firestore permission denied

```bash
# Solution: Check IAM roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:YOUR-EMAIL" \
  --role="roles/datastore.user"
```

**Issue:** AWS Cost Explorer returns empty results

```bash
# Solution: Enable Cost Explorer (first time takes 24h)
# Visit: https://console.aws.amazon.com/cost-management/home#/cost-explorer

# Check IAM permissions
aws iam get-user
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-02 --granularity DAILY --metrics "UnblendedCost"
```

**Issue:** Port already in use

```bash
# Solution: Kill process on port
lsof -ti:8000 | xargs kill -9

# Or use different port
uvicorn src.api.main:app --port 8001
```

**Issue:** Cloud Run deployment fails

```bash
# Check build logs
gcloud builds list --limit=5

# View specific build
gcloud builds log BUILD_ID

# Common fix: Ensure Dockerfile or requirements.txt exists
```

**Issue:** Secret Manager access denied

```bash
# Grant access
gcloud secrets add-iam-policy-binding SECRET_NAME \
  --member="serviceAccount:YOUR-SA@PROJECT.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

---

## AI-Assisted Development

This project is designed to work efficiently with AI coding assistants (Claude Code, GitHub Copilot, Cursor, etc.).

### Why This Project Works Well with AI

| Factor | Benefit |
|--------|---------|
| Detailed ADRs | AI understands architectural decisions |
| Complete specs | Database, API, config specs pre-defined |
| Clear file structure | AI can navigate and modify confidently |
| Inline documentation | Context available in every file |

### Recommended AI Workflow

**1. Start Each Session with Context**

```
Read these files first:
- README.md (overview)
- HANDOFF.md (current status)
- core/ (specs for your task)
```

**2. Use AI for These Tasks**

| Task | How to Prompt |
|------|---------------|
| **Setup** | "Set up GCP project following DEVELOPER_GUIDE.md Quick Start" |
| **New Connector** | "Add Cloudflare cost connector following pattern in src/connectors/aws.py" |
| **API Endpoint** | "Create endpoint per core/05-api-endpoint-spec.md" |
| **Debugging** | "Debug this error. Check BigQuery table schema first." |
| **Cost Analysis** | "Query BigQuery for top 10 expensive services this month" |

**3. Multi-Cloud Setup with AI**

```
"Set up Azure Cost Management connector.
Follow the pattern in src/connectors/aws.py.
Store credentials in Secret Manager.
Add endpoint to src/api/routes/costs.py."
```

### Key Documents for AI Context

| Document | When to Reference |
|----------|-------------------|
| `README.md` | Project overview |
| `HANDOFF.md` | Current status, next steps |
| `core/01-database-schema.md` | Data structure |
| `core/05-api-endpoint-spec.md` | API design |
| `core/08-cost-model.md` | Cost estimates, timeline |
| `docs/adr/*.md` | Why decisions were made |

### AI-Assisted Timeline

With AI coding assistants, typical tasks complete faster:

| Task | Manual | AI-Assisted |
|------|--------|-------------|
| Cloud connector | 4-6 hours | 1-2 hours |
| API endpoint | 1-2 hours | 20-30 min |
| Dashboard setup | 2-3 hours | 1 hour |
| Full MVP | 30 days | 15 days |

### Tips for Effective AI Collaboration

1. **Provide file paths** - AI works better with explicit paths
2. **Reference specs** - Point to relevant `core/*.md` files
3. **Chain tasks** - Complete one task fully before the next
4. **Verify outputs** - Review AI-generated code before deploying
5. **Update docs** - Ask AI to update documentation after changes

### Using AI for Ongoing Operations

After deployment, AI assistants can help with:

| Operation | Example Prompt |
|-----------|----------------|
| Cost investigation | "Query BigQuery: Why did GCP costs spike last Tuesday?" |
| Optimization | "Find idle Cloud Run services from Cloud Monitoring" |
| New connector | "Add Neo4j Aura cost tracking to the platform" |
| Bug fix | "The Azure connector returns 401. Debug and fix." |
| Reports | "Generate weekly cost summary, format as Slack message" |

### Claude Code Specific Tips

```bash
# Start session with project context
claude "Read HANDOFF.md and core/08-cost-model.md. I want to start Week 1 of the 15-day MVP."

# Deploy infrastructure
claude "Deploy BigQuery billing export following GCP-DEPLOYMENT.md section 3"

# Add connector
claude "Implement AWS Cost Explorer connector. Use boto3. Follow pattern in src/connectors/gcp.py"

# Debug issue
claude "This error appears when querying BigQuery: [paste error]. Fix it."
```

---

## Additional Resources

- **[README.md](./README.md)** - Project overview
- **[HANDOFF.md](./HANDOFF.md)** - Project status and next steps
- **[CONTRIBUTING.md](./CONTRIBUTING.md)** - Contribution guidelines
- **[GCP-DEPLOYMENT.md](./GCP-DEPLOYMENT.md)** - GCP deployment guide
- **[core/](./core/)** - Technical specifications
- **[docs/adr/](./docs/adr/)** - Architecture decisions
- **[core/08-cost-model.md](./core/08-cost-model.md)** - 15-day MVP timeline

---

**Happy coding!**
