# Developer Guide

Complete guide for setting up and working with the AI Cost Monitoring platform locally.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Local Development](#local-development)
- [Common Tasks](#common-tasks)
- [Debugging](#debugging)
- [Deployment](#deployment)

---

## Prerequisites

### Required Software

- **Python 3.11+** - Backend services, agents, MCP servers
- **Node.js 18+** - Frontend, AG-UI components
- **Docker** (optional) - Local testing of containers
- **gcloud CLI** - GCP interaction (if using GCP as home cloud)
- **Git** - Version control

### Cloud Accounts

**Choose ONE as your "home cloud"** (where the platform runs):
- **GCP** (recommended for MVP) - Free tier available
- **AWS** - Alternative home cloud
- **Azure** - Alternative home cloud

**Note:** The platform monitors costs across ALL clouds, but needs to run in one.

---

## Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/your-org/AI-cost-monitoring.git
cd AI-cost-monitoring
```

### 2. Set Up Python Environment

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

### 3. Set Up Node.js Environment

```bash
cd frontend  # or cd ag-ui-server
npm install
cd ..
```

### 4. Configure Environment

```bash
# Copy example environment file
cp .env.example .env

# Edit with your values
nano .env  # or your preferred editor
```

**Minimum required variables:**
```bash
GCP_PROJECT_ID=your-project-id
DATABASE_URL=postgresql://user:pass@localhost:5432/ai_cost_monitoring
GOOGLE_API_KEY=your-gemini-api-key
```

### 5. Set Up Local Database

**Option A: Cloud SQL (recommended for production-like setup)**
```bash
# Follow GCP-DEPLOYMENT.md to set up Cloud SQL
# Connect via Cloud SQL Proxy
cloud-sql-proxy your-project:us-central1:ai-cost-db
```

**Option B: Local PostgreSQL (for quick dev)**
```bash
# Install PostgreSQL 16
# Create database
createdb ai_cost_monitoring

# Run migrations (when implemented)
alembic upgrade head
```

### 6. Run Services

```bash
# Backend API
python -m src.api.main

# AG-UI Server (separate terminal)
cd ag-ui-server
npm run dev

# MCP Server (separate terminal)
python -m src.mcp.gcp_server
```

### 7. Verify Setup

```bash
# Check API health
curl http://localhost:8000/health

# Check AG-UI
curl http://localhost:3000/health
```

---

## Project Structure

```
AI-cost-monitoring/
├── src/
│   ├── api/                    # REST API (FastAPI)
│   │   ├── main.py            # API entry point
│   │   ├── routes/            # API endpoints
│   │   └── middleware/        # Auth, CORS, etc.
│   │
│   ├── agents/                 # AI agents
│   │   ├── coordinator.py     # Main coordinator
│   │   ├── cost_agent.py      # Cost analysis
│   │   └── optimization_agent.py
│   │
│   ├── mcp/                    # MCP servers
│   │   ├── gcp_server.py      # GCP cost monitoring
│   │   ├── aws_server.py      # AWS cost monitoring
│   │   └── tools/             # Common MCP tools
│   │
│   ├── models/                 # Database models
│   │   ├── tenant.py
│   │   ├── cost_metric.py
│   │   └── base.py
│   │
│   └── utils/                  # Shared utilities
│       ├── bigquery.py
│       ├── auth.py
│       └── cache.py
│
├── ag-ui-server/               # AG-UI frontend (Next.js)
│   ├── src/
│   │   ├── app/               # Next.js app router
│   │   ├── components/        # React components
│   │   └── lib/               # Client utilities
│   └── package.json
│
├── terraform/                  # Infrastructure as Code
│   ├── modules/
│   │   ├── gcp/              # GCP resources
│   │   ├── aws/              # AWS resources
│   │   └── azure/            # Azure resources
│   └── main.tf
│
├── tests/                      # Tests
│   ├── unit/
│   ├── integration/
│   └── e2e/
│
├── docs/                       # Documentation
│   └── adr/                   # Architecture decisions
│
├── core/                       # Specifications
│   ├── 01-database-schema.md
│   ├── 02-mcp-tool-contracts.md
│   └── ...
│
├── .env.example               # Environment template
├── requirements.txt           # Python dependencies
├── README.md                  # Project overview
└── CONTRIBUTING.md            # Contribution guidelines
```

---

## Local Development

### Running Individual Services

**Backend API:**
```bash
# Development mode (auto-reload)
uvicorn src.api.main:app --reload --port 8000

# With specific config
ENVIRONMENT=development uvicorn src.api.main:app --reload
```

**AG-UI Server:**
```bash
cd ag-ui-server
npm run dev  # Runs on http://localhost:3000
```

**MCP Server:**
```bash
# GCP MCP Server
python -m src.mcp.gcp_server --port 8001

# AWS MCP Server
python -m src.mcp.aws_server --port 8002
```

### Database Migrations

```bash
# Create new migration
alembic revision --autogenerate -m "description"

# Apply migrations
alembic upgrade head

# Rollback one migration
alembic downgrade -1
```

### Working with BigQuery

**Local development setup:**
```bash
# Authenticate with GCP
gcloud auth application-default login

# Set project
gcloud config set project your-project-id

# Test query
python scripts/test_bigquery.py
```

**Sample query:**
```python
from google.cloud import bigquery

client = bigquery.Client()
query = \"\"\"
    SELECT 
        DATE(usage_start_time) as date,
        SUM(cost) as total_cost
    FROM `project.dataset.gcp_billing_export_v1`
    WHERE DATE(usage_start_time) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
    GROUP BY date
    ORDER BY date DESC
\"\"\"
results = client.query(query).result()
for row in results:
    print(f\"{row.date}: ${row.total_cost:.2f}\")
```

---

## Common Tasks

### Adding a New MCP Tool

1. **Create tool function** in `src/mcp/tools/`:
```python
# src/mcp/tools/get_idle_resources.py
from mcp.types import Tool

async def get_idle_resources(cloud_provider: str, threshold_days: int = 30):
    \"\"\"Find resources idle for N days.\"\"\"
    # Implementation
    pass

# Tool definition
TOOL_DEFINITION = Tool(
    name=\"get_idle_resources\",
    description=\"Find resources with no activity\",
    inputSchema={
        \"type\": \"object\",
        \"properties\": {
            \"cloud_provider\": {\"type\": \"string\"},
            \"threshold_days\": {\"type\": \"integer\", \"default\": 30}
        }
    }
)
```

2. **Register in MCP server** (`src/mcp/gcp_server.py`):
```python
server.add_tool(TOOL_DEFINITION, get_idle_resources)
```

3. **Add tests** (`tests/unit/test_idle_resources.py`)

4. **Update documentation** (`core/02-mcp-tool-contracts.md`)

### Adding a New API Endpoint

1. **Create route** in `src/api/routes/`:
```python
# src/api/routes/costs.py
from fastapi import APIRouter, Depends
from src.models.cost_metric import CostMetric

router = APIRouter(prefix=\"/api/costs\", tags=[\"costs\"])

@router.get(\"/summary\")
async def get_cost_summary(
    start_date: str,
    end_date: str,
    tenant_id: str = Depends(get_current_tenant)
):
    # Implementation
    return {\"total\": 1234.56, \"currency\": \"USD\"}
```

2. **Register in main app** (`src/api/main.py`):
```python
from src.api.routes import costs
app.include_router(costs.router)
```

3. **Add tests**

4. **Update API spec** (`core/05-api-endpoint-spec.md`)

### Running Tests

```bash
# All Python tests
pytest

# Specific test file
pytest tests/unit/test_mcp_gcp.py

# With coverage
pytest --cov=src --cov-report=html
open htmlcov/index.html  # View coverage report

# All TypeScript tests
cd ag-ui-server
npm test

# Watch mode
npm test -- --watch
```

---

## Debugging

### Python Debugging

**VS Code configuration (`.vscode/launch.json`):**
```json
{
  \"version\": \"0.2.0\",
  \"configurations\": [
    {
      \"name\": \"FastAPI\",
      \"type\": \"python\",
      \"request\": \"launch\",
      \"module\": \"uvicorn\",
      \"args\": [\"src.api.main:app\", \"--reload\"],
      \"env\": {\"ENVIRONMENT\": \"development\"}
    }
  ]
}
```

**Debugging with pdb:**
```python
import pdb; pdb.set_trace()  # Add breakpoint
```

### TypeScript Debugging

**Chrome DevTools:**
1. Start dev server: `npm run dev`
2. Open http://localhost:3000
3. Open Chrome DevTools (F12)
4. Set breakpoints in Sources tab

### Logging

**Python:**
```python
import logging
logger = logging.getLogger(__name__)

logger.debug(\"Detailed info\")
logger.info(\"General info\")
logger.warning(\"Warning message\")
logger.error(\"Error occurred\")
```

**TypeScript:**
```typescript
console.log('Debug:', data);
console.warn('Warning:', warning);
console.error('Error:', error);
```

---

## Deployment

See deployment guides for detailed instructions:
- **[GCP-DEPLOYMENT.md](./GCP-DEPLOYMENT.md)** - Deploy to Google Cloud
- **[AWS-DEPLOYMENT.md](./AWS-DEPLOYMENT.md)** - Deploy to AWS
- **[AZURE-DEPLOYMENT.md](./AZURE-DEPLOYMENT.md)** - Deploy to Azure

**Quick deploy to GCP:**
```bash
# Build and deploy API
gcloud run deploy ai-cost-api \\
  --source . \\
  --platform managed \\
  --region us-central1

# Build and deploy frontend
cd ag-ui-server
gcloud run deploy ai-cost-ui \\
  --source . \\
  --platform managed \\
  --region us-central1
```

---

## Troubleshooting

### Common Issues

**Issue:** `ModuleNotFoundError: No module named 'src'`
```bash
# Solution: Ensure you're in project root and venv is activated
source venv/bin/activate
python -m src.api.main  # Use -m flag
```

**Issue:** BigQuery authentication fails
```bash
# Solution: Re-authenticate
gcloud auth application-default login
export GOOGLE_APPLICATION_CREDENTIALS=\"path/to/service-account-key.json\"
```

**Issue:** Port already in use
```bash
# Solution: Kill process on port
lsof -ti:8000 | xargs kill -9
```

---

## Additional Resources

- **[CONTRIBUTING.md](./CONTRIBUTING.md)** - Contribution guidelines
- **[README.md](./README.md)** - Project overview
- **[core/](./core/)** - Technical specifications
- **[docs/adr/](./docs/adr/)** - Architecture decisions

---

**Happy coding!** 🚀
