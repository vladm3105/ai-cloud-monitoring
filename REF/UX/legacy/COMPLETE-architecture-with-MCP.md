# Complete Architecture: Simple vs Advanced (with MCP)
## AI Cost Monitoring Platform - All Options

**Document Version:** 1.0  
**Last Updated:** February 2026  
**Architecture Options:** 2 approaches (Simple vs Advanced)

---

## Executive Summary

You have **TWO architectural approaches** to choose from:

### Option A: Simple Architecture (Recommended for Start)
**Components:**
- Cloud Billing → Database (BigQuery) → Grafana + Conversational Widget
- **NO MCP servers**
- **NO Orchestrator/UX Agent**
- Cost: $50-115/month
- Use case: Cost monitoring, reporting, basic Q&A

### Option B: Advanced Architecture (Future Enhancement)
**Components:**
- Cloud Billing → Database → Grafana + MCP Servers + Orchestrator Agent
- **YES MCP servers** (real-time data access)
- **YES Orchestrator/UX Agent** (agentic workflows)
- Cost: $300-455/month
- Use case: Real-time monitoring, agentic cost optimization, automated actions

---

## Table of Contents

1. [Architecture Comparison](#architecture-comparison)
2. [Simple Architecture (No MCP)](#simple-architecture)
3. [Advanced Architecture (With MCP)](#advanced-architecture)
4. [When to Add MCP Servers](#when-to-add-mcp)
5. [Migration Path](#migration-path)

---

## Architecture Comparison

### Side-by-Side View

```
┌─────────────────────────────────────────────────────────────┐
│              OPTION A: SIMPLE ARCHITECTURE                   │
│                   (Phase 1 & 2)                              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  User Interfaces:                                           │
│  ├─ Grafana Dashboards (visual analytics)                  │
│  └─ Conversational Widget (natural language Q&A)           │
│                    ↓                                         │
│  Backend:                                                    │
│  ├─ Grafana → Direct SQL to BigQuery                       │
│  └─ Widget API → Claude AI → Generate SQL → BigQuery       │
│                    ↓                                         │
│  Database:                                                   │
│  └─ BigQuery (unified_costs view)                          │
│                    ↓                                         │
│  Data Sources:                                               │
│  ├─ GCP Billing Export (automatic)                         │
│  ├─ AWS ETL (Cloud Function → BigQuery)                    │
│  └─ Azure ETL (Cloud Function → BigQuery)                  │
│                                                              │
│  Cost: $50-115/month                                        │
│  Real-time: NO (daily updates)                             │
│  AI Actions: NO (read-only)                                │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│            OPTION B: ADVANCED ARCHITECTURE                   │
│                  (Future Phase 3)                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  User Interfaces:                                           │
│  ├─ Grafana Dashboards (visual analytics)                  │
│  └─ AI Agent Chat (powered by orchestrator)                │
│                    ↓                                         │
│  AI Orchestrator / UX Agent:                                │
│  ├─ Natural language understanding                          │
│  ├─ Intent routing                                          │
│  ├─ Multi-step workflows                                    │
│  ├─ Action execution                                        │
│  └─ Response formatting                                     │
│                    ↓                                         │
│  MCP Servers (Real-time data):                              │
│  ├─ GCP MCP Server → Cloud APIs (live)                     │
│  ├─ AWS MCP Server → CloudWatch (live)                     │
│  └─ Azure MCP Server → Monitor (live)                      │
│                    ↓                                         │
│  Database (Historical):                                      │
│  └─ BigQuery (for trends, history)                         │
│                                                              │
│  Cost: $300-455/month                                       │
│  Real-time: YES (15-second updates)                        │
│  AI Actions: YES (can take actions)                        │
└─────────────────────────────────────────────────────────────┘
```

---

## Simple Architecture (No MCP)

### What You Built in Phase 1 & 2

This is the **cost monitoring** architecture we've been building:

```
┌─────────────────────────────────────────────────────────────┐
│                     USER LAYER                               │
├─────────────────────┬───────────────────────────────────────┤
│  Grafana Dashboards │  Conversational Widget                │
│  • Cost trends      │  • "How much yesterday?"              │
│  • Model comparison │  • "Top customer?"                     │
│  • Budget tracking  │  • "Am I over budget?"                │
└──────────┬──────────┴──────────┬────────────────────────────┘
           │                     │
           │ SQL                 │ API → Claude AI → SQL
           ▼                     ▼
┌─────────────────────────────────────────────────────────────┐
│                   BIGQUERY DATABASE                          │
│  • gcp_llm_costs (daily updates from billing export)        │
│  • aws_llm_costs (daily ETL from Cost Explorer)             │
│  • azure_llm_costs (daily ETL from Cost Management)         │
│  • unified_costs view (UNION ALL)                           │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            │ Daily updates
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   DATA SOURCES                               │
│  • GCP Billing Export (automatic every 4-6 hours)           │
│  • AWS Cost & Usage Reports (daily to S3)                   │
│  • Azure Cost Management API (daily pull)                   │
└─────────────────────────────────────────────────────────────┘
```

### Characteristics

**Data Freshness:**
- ❌ NOT real-time (4-24 hour delay)
- ✅ Good for cost monitoring
- ✅ Daily/hourly granularity sufficient

**Query Method:**
- Grafana: Direct SQL to BigQuery
- Widget: Claude generates SQL → BigQuery

**Capabilities:**
- ✅ Historical cost analysis
- ✅ Trend visualization
- ✅ Budget tracking
- ✅ Model comparison
- ✅ Customer attribution
- ✅ Anomaly detection (after-the-fact)
- ❌ Real-time metrics
- ❌ Live alerts
- ❌ Automated actions

**Cost:** $50-115/month
- Grafana: $15-25
- Widget API: $5-10
- Claude AI: $30-80

---

## Advanced Architecture (With MCP)

### What MCP Servers Add

**MCP (Model Context Protocol) Servers** provide **real-time access to cloud APIs**:

```
┌─────────────────────────────────────────────────────────────┐
│                  ADVANCED ARCHITECTURE                       │
│              (With MCP Servers + Orchestrator)               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                     USER LAYER                               │
├─────────────────────┬───────────────────────────────────────┤
│  Grafana Dashboards │  AI Agent Chat Interface              │
│  • Cost trends      │  • "Show me live token usage"         │
│  • Model comparison │  • "Alert me if cost > $1K/hour"      │
│  • Budget tracking  │  • "Scale down idle models"           │
└──────────┬──────────┴──────────┬────────────────────────────┘
           │                     │
           │ SQL                 │ Natural Language
           ▼                     ▼
┌─────────────────────────────────────────────────────────────┐
│              AI ORCHESTRATOR / UX AGENT                      │
│                                                              │
│  Components:                                                 │
│  ├─ Natural Language Parser (Claude/GPT-4)                  │
│  ├─ Intent Router (which MCP server to call?)               │
│  ├─ Multi-Step Planner (complex workflows)                  │
│  ├─ Action Executor (can take actions, not just read)       │
│  ├─ Response Formatter (conversational replies)             │
│  └─ Memory Manager (conversation context)                   │
│                                                              │
│  Capabilities:                                               │
│  • Multi-turn conversations                                  │
│  • Complex queries across multiple clouds                    │
│  • Automated actions (e.g., "pause expensive model")        │
│  • Real-time alerts                                          │
│  • Cost optimization recommendations                         │
└────────┬────────────┬────────────┬───────────────────────────┘
         │            │            │
         ▼            ▼            ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│  GCP MCP    │ │  AWS MCP    │ │ Azure MCP   │
│  Server     │ │  Server     │ │  Server     │
│             │ │             │ │             │
│ REST API    │ │ REST API    │ │ REST API    │
│ Port: 3001  │ │ Port: 3002  │ │ Port: 3003  │
└──────┬──────┘ └──────┬──────┘ └──────┬──────┘
       │               │               │
       │ Real-time     │ Real-time     │ Real-time
       ▼               ▼               ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│ GCP Cloud   │ │ AWS Cloud   │ │ Azure Cloud │
│ APIs        │ │ APIs        │ │ APIs        │
│             │ │             │ │             │
│ • Vertex AI │ │ • Bedrock   │ │ • OpenAI    │
│ • Logging   │ │ • CloudWatch│ │ • Monitor   │
│ • Billing   │ │ • Cost Exp. │ │ • Cost Mgmt │
└─────────────┘ └─────────────┘ └─────────────┘
       │               │               │
       └───────────────┼───────────────┘
                       │
                       ▼
              ┌─────────────────┐
              │    BigQuery     │
              │   (Historical)  │
              └─────────────────┘
```

### MCP Server Architecture

Each cloud has its own MCP server:

#### GCP MCP Server

```python
# gcp_mcp_server.py
from fastapi import FastAPI
from google.cloud import aiplatform, logging, billing
from datetime import datetime, timedelta

app = FastAPI()

@app.get("/realtime/token-usage")
async def get_realtime_token_usage():
    """
    Get real-time token usage from Vertex AI
    Updates every 15 seconds
    """
    client = aiplatform.gapic.PredictionServiceClient()
    
    # Query live metrics
    metrics = client.list_model_evaluations(
        parent="projects/PROJECT/locations/us-central1",
        filter=f"timestamp >= {datetime.now() - timedelta(minutes=5)}"
    )
    
    return {
        "timestamp": datetime.now().isoformat(),
        "models": [
            {
                "name": "gemini-pro",
                "tokens_last_5min": 45234,
                "cost_last_5min": 5.92,
                "active_requests": 12
            }
        ]
    }

@app.get("/realtime/cost")
async def get_realtime_cost():
    """
    Get cost for current hour (not available in billing export yet)
    """
    # Query Cloud Logging for recent API calls
    log_client = logging.Client()
    
    # Calculate estimated cost from logs
    recent_calls = log_client.list_entries(
        filter_=f"timestamp >= {datetime.now() - timedelta(hours=1)}"
    )
    
    estimated_cost = sum([calculate_cost(entry) for entry in recent_calls])
    
    return {
        "hour": datetime.now().strftime("%Y-%m-%d %H:00"),
        "estimated_cost": estimated_cost,
        "status": "live"
    }

@app.post("/actions/pause-model")
async def pause_model(model_id: str):
    """
    Action: Pause a model to stop costs
    """
    # This is an ACTION, not just reading data
    client = aiplatform.gapic.EndpointServiceClient()
    
    endpoint = client.get_endpoint(name=model_id)
    # Undeploy model to stop costs
    client.undeploy_model(endpoint=endpoint.name)
    
    return {
        "action": "pause_model",
        "model_id": model_id,
        "status": "paused",
        "estimated_savings": "$50/hour"
    }
```

#### AWS MCP Server

```python
# aws_mcp_server.py
from fastapi import FastAPI
import boto3
from datetime import datetime, timedelta

app = FastAPI()

@app.get("/realtime/bedrock-usage")
async def get_bedrock_usage():
    """
    Get real-time Bedrock usage from CloudWatch
    """
    cloudwatch = boto3.client('cloudwatch')
    
    # Query CloudWatch metrics
    response = cloudwatch.get_metric_statistics(
        Namespace='AWS/Bedrock',
        MetricName='InvocationCount',
        StartTime=datetime.now() - timedelta(minutes=15),
        EndTime=datetime.now(),
        Period=60,
        Statistics=['Sum']
    )
    
    return {
        "timestamp": datetime.now().isoformat(),
        "invocations_last_15min": sum([d['Sum'] for d in response['Datapoints']]),
        "estimated_cost": calculate_cost(response['Datapoints'])
    }

@app.post("/actions/set-quota")
async def set_quota(model: str, max_tokens_per_hour: int):
    """
    Action: Set usage quota to prevent overspending
    """
    # This is an ACTION
    bedrock = boto3.client('bedrock')
    
    # Set quota using Service Quotas API
    service_quotas = boto3.client('service-quotas')
    service_quotas.request_service_quota_increase(
        ServiceCode='bedrock',
        QuotaCode='L-12345',
        DesiredValue=max_tokens_per_hour
    )
    
    return {
        "action": "set_quota",
        "model": model,
        "max_tokens_per_hour": max_tokens_per_hour,
        "status": "applied"
    }
```

#### Azure MCP Server

```python
# azure_mcp_server.py
from fastapi import FastAPI
from azure.monitor.query import MetricsQueryClient
from azure.identity import DefaultAzureCredential
from datetime import datetime, timedelta

app = FastAPI()

@app.get("/realtime/openai-usage")
async def get_openai_usage():
    """
    Get real-time Azure OpenAI usage
    """
    credential = DefaultAzureCredential()
    client = MetricsQueryClient(credential)
    
    # Query Azure Monitor
    response = client.query_resource(
        resource_uri="/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.CognitiveServices/accounts/{account}",
        metric_names=["TotalTokens", "TotalCalls"],
        timespan=timedelta(minutes=15)
    )
    
    return {
        "timestamp": datetime.now().isoformat(),
        "tokens_last_15min": sum([m.value for m in response.metrics[0].timeseries[0].data]),
        "estimated_cost": calculate_azure_cost(response)
    }
```

---

### AI Orchestrator / UX Agent

The orchestrator sits between the user and MCP servers:

```python
# orchestrator_agent.py
from anthropic import Anthropic
import httpx

anthropic = Anthropic(api_key="...")

class CostOptimizationOrchestrator:
    """
    AI Agent that can:
    1. Understand natural language requests
    2. Route to appropriate MCP servers
    3. Take actions (not just read)
    4. Handle multi-step workflows
    """
    
    def __init__(self):
        self.mcp_servers = {
            "gcp": "http://localhost:3001",
            "aws": "http://localhost:3002",
            "azure": "http://localhost:3003"
        }
        self.conversation_history = []
    
    async def process_request(self, user_message: str):
        """
        Main orchestration logic
        """
        
        # Step 1: Parse intent with Claude
        intent = await self.parse_intent(user_message)
        
        # Step 2: Plan action
        if intent["type"] == "query":
            return await self.handle_query(intent)
        elif intent["type"] == "action":
            return await self.handle_action(intent)
        elif intent["type"] == "multi_step":
            return await self.handle_workflow(intent)
    
    async def parse_intent(self, message: str):
        """
        Use Claude to understand what user wants
        """
        system_prompt = """You are a cost optimization AI agent.
        
        You can:
        1. QUERY: Get real-time or historical cost data
        2. ACTION: Take actions to optimize costs (pause models, set quotas, etc.)
        3. WORKFLOW: Multi-step optimization workflows
        
        Available MCP servers:
        - GCP: Vertex AI, Cloud Logging, Billing
        - AWS: Bedrock, CloudWatch, Cost Explorer
        - Azure: OpenAI, Monitor, Cost Management
        
        Parse the user's request and determine:
        - type: query, action, or multi_step
        - clouds: which clouds to query
        - specific_action: if action, what action?
        - parameters: any parameters needed
        """
        
        response = anthropic.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=1000,
            system=system_prompt,
            messages=[
                {"role": "user", "content": message}
            ]
        )
        
        # Parse Claude's response
        return parse_json(response.content[0].text)
    
    async def handle_query(self, intent):
        """
        Query MCP servers for data
        """
        results = []
        
        for cloud in intent["clouds"]:
            mcp_url = self.mcp_servers[cloud]
            endpoint = intent["endpoint"]  # e.g., "/realtime/token-usage"
            
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{mcp_url}{endpoint}")
                results.append(response.json())
        
        # Format response conversationally
        return await self.format_response(intent, results)
    
    async def handle_action(self, intent):
        """
        Execute action via MCP server
        
        IMPORTANT: This can CHANGE things, not just read
        """
        # Get confirmation first (safety)
        if not intent.get("confirmed"):
            return {
                "type": "confirmation_required",
                "action": intent["action"],
                "warning": "This will change your cloud resources. Confirm?"
            }
        
        # Execute action
        cloud = intent["cloud"]
        mcp_url = self.mcp_servers[cloud]
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{mcp_url}{intent['endpoint']}",
                json=intent["parameters"]
            )
        
        return {
            "type": "action_completed",
            "result": response.json()
        }
    
    async def handle_workflow(self, intent):
        """
        Multi-step optimization workflow
        
        Example: "Optimize my costs"
        Steps:
        1. Query current usage across all clouds
        2. Identify expensive idle models
        3. Recommend actions
        4. Execute approved actions
        """
        workflow_steps = intent["steps"]
        results = []
        
        for step in workflow_steps:
            if step["type"] == "query":
                result = await self.handle_query(step)
            elif step["type"] == "action":
                result = await self.handle_action(step)
            
            results.append(result)
            
            # Update conversation context
            self.conversation_history.append({
                "step": step,
                "result": result
            })
        
        return {
            "type": "workflow_completed",
            "results": results
        }


# Example usage
orchestrator = CostOptimizationOrchestrator()

# User: "Show me live token usage for Gemini"
response = await orchestrator.process_request("Show me live token usage for Gemini")
# → Calls GCP MCP Server /realtime/token-usage

# User: "Pause GPT-4 if it's using more than $100/hour"
response = await orchestrator.process_request("Pause GPT-4 if using > $100/hour")
# → Multi-step:
#   1. Query Azure MCP Server for current usage
#   2. If > $100/hour, call Azure MCP Server /actions/pause-model
#   3. Return confirmation
```

---

## When to Add MCP Servers

### Decision Matrix

| Factor | Simple (No MCP) | Advanced (With MCP) |
|--------|-----------------|---------------------|
| **Data Freshness** | 4-24 hour delay | 15-second updates |
| **Query Type** | Historical analysis | Real-time monitoring |
| **Actions** | Read-only | Can take actions |
| **Use Cases** | Cost reporting, trends | Live alerts, auto-optimization |
| **Complexity** | Low | High |
| **Cost** | $50-115/month | $300-455/month |
| **Development** | 2-3 weeks | 6-8 weeks |

### Add MCP Servers When:

✅ **Need real-time data:**
- "Show me token usage in the last 5 minutes"
- "Alert me if cost exceeds $1K in current hour"
- "How many active requests right now?"

✅ **Want automated actions:**
- "Pause model X if idle for 1 hour"
- "Scale down during off-peak hours"
- "Set quota to prevent runaway costs"

✅ **Require complex workflows:**
- "Optimize my costs" (multi-step analysis + actions)
- "Compare live performance across clouds"
- "Auto-switch to cheaper model when possible"

✅ **Have budget for complexity:**
- Revenue > $50K/month
- Can invest in advanced features
- Have engineering resources

### Don't Add MCP Servers When:

❌ **Daily updates sufficient:**
- Cost reporting
- Monthly budgets
- Trend analysis

❌ **Read-only queries:**
- "How much did we spend last week?"
- "Which customer spent most?"
- "Top 10 models by cost"

❌ **Budget constrained:**
- Early MVP stage
- < 20 customers
- Need to prove concept first

---

## Migration Path

### Phase 1: Simple Architecture (Months 1-6)
**Build:**
- Grafana dashboards
- Conversational widget (read-only)
- BigQuery with daily ETL

**Cost:** $50-115/month  
**Customers:** 0-20

---

### Phase 2: Add Real-Time Layer (After 20 customers)
**Add:**
- MCP servers (GCP, AWS, Azure)
- Prometheus for metrics
- Real-time alerting

**Keep:**
- Grafana dashboards
- BigQuery for history

**Cost:** $180-260/month  
**Customers:** 20-50

---

### Phase 3: Full Orchestrator (After 50 customers)
**Add:**
- AI Orchestrator/UX Agent
- Automated actions
- Multi-step workflows
- Advanced cost optimization

**Keep:**
- Everything from Phase 1 & 2

**Cost:** $300-455/month  
**Customers:** 50+

---

## Summary Table

| Component | Simple | Advanced | Purpose |
|-----------|--------|----------|---------|
| **Grafana** | ✅ | ✅ | Visual dashboards |
| **Conversational Widget** | ✅ | ❌ | Simple Q&A (replaced by orchestrator) |
| **AI Orchestrator** | ❌ | ✅ | Complex agent workflows |
| **MCP Servers** | ❌ | ✅ | Real-time cloud API access |
| **BigQuery** | ✅ | ✅ | Historical cost data |
| **Prometheus** | ❌ | ✅ | Real-time metrics |
| **Actions** | ❌ Read-only | ✅ Can change resources |
| **Data Freshness** | Daily | 15-second |
| **Cost/Month** | $50-115 | $300-455 |
| **Development** | 2-3 weeks | 6-8 weeks |

---

## Final Recommendation

### Start Simple (Phase 1):
```
Grafana + Conversational Widget + BigQuery
↓
Prove product-market fit
↓
Get 20 customers
```

### Add Real-Time (Phase 2):
```
+ MCP Servers + Prometheus
↓
Real-time monitoring
↓
Get 50 customers
```

### Add Orchestrator (Phase 3):
```
+ AI Orchestrator/UX Agent
↓
Automated cost optimization
↓
Scale to 100+ customers
```

**The conversational widget and AI orchestrator are DIFFERENT:**
- **Widget** = Simple Q&A, generates SQL, reads from BigQuery
- **Orchestrator** = Complex agent, calls MCP servers, takes actions

You don't lose anything - you evolve from simple to advanced!

---

**Document End**
