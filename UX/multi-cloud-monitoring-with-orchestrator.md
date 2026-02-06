# Multi-Cloud Monitoring Architecture with Orchestrator Agent
## AI Cost Monitoring Platform - Complete Architecture

**Document Version:** 2.0  
**Last Updated:** February 2026  
**Key Addition:** Orchestrator Agent for MCP Server Integration

---

## Executive Summary

**CRITICAL ARCHITECTURAL CHANGE:**

You need an **Orchestrator Agent** layer between your unified monitoring dashboard and the cloud-specific MCP servers. This agent:

1. ✅ Handles conversational queries from users
2. ✅ Determines which clouds to query based on tenant config
3. ✅ Calls cloud-specific MCP server REST APIs
4. ✅ Aggregates responses from multiple clouds
5. ✅ Returns unified results to Grafana/UI

**Why it's needed:** Grafana can only query Prometheus or databases directly. It cannot make REST API calls to your MCP servers. The Orchestrator Agent bridges this gap.

---

## Updated Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                    USER INTERFACE LAYER                           │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                Grafana Dashboard                            │ │
│  │  + Conversational AI Interface (CopilotKit/AG-UI)          │ │
│  │                                                              │ │
│  │  User asks: "How much did Gemini cost this week?"          │ │
│  └─────────────────────────┬────────────────────────────────── │
│                             │                                    │
└─────────────────────────────┼────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│              ORCHESTRATOR AGENT LAYER (NEW!)                      │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │           Multi-Cloud Orchestrator Agent                    │ │
│  │           (Google ADK / LangChain / Custom)                 │ │
│  │                                                              │ │
│  │  Responsibilities:                                           │ │
│  │  1. Parse user query intent                                  │ │
│  │  2. Check tenant cloud configuration                         │ │
│  │  3. Route to appropriate MCP server(s)                       │ │
│  │  4. Aggregate responses                                      │ │
│  │  5. Format unified response                                  │ │
│  └──────────┬─────────────┬─────────────┬─────────────────────┘ │
│             │             │             │                         │
│             ▼             ▼             ▼                         │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐            │
│  │  GCP MCP     │ │  AWS MCP     │ │ Azure MCP    │            │
│  │  Client      │ │  Client      │ │  Client      │            │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘            │
│         │                 │                 │                     │
└─────────┼─────────────────┼─────────────────┼─────────────────────┘
          │                 │                 │
          ▼                 ▼                 ▼
┌─────────────────────────────────────────────────────────────────┐
│              CLOUD-SPECIFIC MCP SERVERS                          │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │  GCP MCP     │  │  AWS MCP     │  │  Azure MCP   │         │
│  │  Server      │  │  Server      │  │  Server      │         │
│  │              │  │              │  │              │         │
│  │  REST API    │  │  REST API    │  │  REST API    │         │
│  │  /metrics/*  │  │  /metrics/*  │  │  /metrics/*  │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Orchestrator Agent Detailed Design

### Component Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                 ORCHESTRATOR AGENT COMPONENTS                     │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  1. QUERY ROUTER                                            │ │
│  │                                                              │ │
│  │  Input: "How much did Gemini cost this week for cust_001?" │ │
│  │                                                              │ │
│  │  Processing:                                                 │ │
│  │  • Extract intent: cost_query                               │ │
│  │  • Extract entities:                                         │ │
│  │    - model: "gemini"                                        │ │
│  │    - timeframe: "this week"                                 │ │
│  │    - customer_id: "cust_001"                                │ │
│  │  • Determine cloud: GCP (Gemini = Vertex AI)               │ │
│  └──────────────────────────┬───────────────────────────────── │
│                              │                                   │
│                              ▼                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  2. TENANT CONFIG RESOLVER                                  │ │
│  │                                                              │ │
│  │  Query: SELECT cloud_provider FROM tenant_cloud_config      │ │
│  │         WHERE tenant_id = 'cust_001' AND is_enabled = true  │ │
│  │                                                              │ │
│  │  Result: ['gcp', 'aws'] (Azure disabled for this tenant)   │ │
│  │                                                              │ │
│  │  Decision: Query only GCP (matches model + enabled)         │ │
│  └──────────────────────────┬───────────────────────────────── │
│                              │                                   │
│                              ▼                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  3. MCP CLIENT POOL                                         │ │
│  │                                                              │ │
│  │  HTTP Clients for each cloud:                               │ │
│  │  • GCP: https://gcp-mcp-server.run.app                     │ │
│  │  • AWS: https://aws-mcp-server.elb.amazonaws.com           │ │
│  │  • Azure: https://azure-mcp-server.azurecontainerapps.io   │ │
│  │                                                              │ │
│  │  Features:                                                   │ │
│  │  • Connection pooling                                        │ │
│  │  • Retry logic (3 attempts)                                 │ │
│  │  • Circuit breaker (if cloud down)                          │ │
│  │  • Timeout: 30 seconds                                      │ │
│  └──────────────────────────┬───────────────────────────────── │
│                              │                                   │
│                              ▼                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  4. RESPONSE AGGREGATOR                                     │ │
│  │                                                              │ │
│  │  If querying multiple clouds:                               │ │
│  │  • Parallel requests (asyncio)                              │ │
│  │  • Merge results                                             │ │
│  │  • Calculate totals                                          │ │
│  │  • Format unified response                                   │ │
│  └──────────────────────────┬───────────────────────────────── │
│                              │                                   │
│                              ▼                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  5. RESPONSE FORMATTER                                      │ │
│  │                                                              │ │
│  │  Converts MCP JSON → User-friendly response                │ │
│  │                                                              │ │
│  │  "Gemini (GCP) cost this week for cust_001: $1,234.56      │ │
│  │   • Input tokens: 5.2M                                      │ │
│  │   • Output tokens: 1.8M                                     │ │
│  │   • Average cost per 1K tokens: $0.18"                     │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

---

## Implementation Options

### Option 1: Google ADK Orchestrator (Recommended)

**Why Google ADK:**
- Built for multi-agent orchestration
- Native MCP client support
- Streaming responses
- Tool calling for MCP servers

**Architecture:**

```python
from google_adk import Agent, MCPClient

# Define MCP clients as tools
gcp_mcp = MCPClient(
    name="gcp_llm_costs",
    url="https://gcp-mcp-server.run.app",
    description="Query GCP LLM costs (Gemini, PaLM, Vertex AI)"
)

aws_mcp = MCPClient(
    name="aws_llm_costs", 
    url="https://aws-mcp-server.elb.amazonaws.com",
    description="Query AWS LLM costs (Bedrock, SageMaker)"
)

azure_mcp = MCPClient(
    name="azure_llm_costs",
    url="https://azure-mcp-server.azurecontainerapps.io", 
    description="Query Azure LLM costs (Azure OpenAI)"
)

# Orchestrator agent
orchestrator = Agent(
    name="MultiCloudCostOrchestrator",
    model="gemini-2.0-flash-exp",
    tools=[gcp_mcp, aws_mcp, azure_mcp],
    instruction="""
    You are a multi-cloud LLM cost monitoring assistant.
    
    When user asks about costs:
    1. Determine which cloud(s) based on the model mentioned
    2. Check tenant's enabled clouds
    3. Query appropriate MCP server(s)
    4. Aggregate results if multiple clouds
    5. Provide clear, concise answer
    
    Cloud-to-Model mapping:
    - GCP: Gemini, PaLM, Document AI, Vision AI
    - AWS: Claude (Bedrock), Titan, SageMaker models
    - Azure: GPT-4, GPT-3.5, Cognitive Services
    """
)

# Usage
async def handle_query(user_query: str, tenant_id: str):
    # Get tenant's enabled clouds
    enabled_clouds = get_tenant_clouds(tenant_id)
    
    # Add context to query
    context = f"Tenant {tenant_id} has enabled: {', '.join(enabled_clouds)}"
    
    # Run orchestrator
    response = await orchestrator.run(
        user_query,
        context=context
    )
    
    return response
```

---

### Option 2: Custom FastAPI Orchestrator

If you want more control:

```python
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import httpx
from typing import List, Dict, Any
import asyncio

app = FastAPI()

class QueryRequest(BaseModel):
    query: str
    tenant_id: str

class MCPClient:
    def __init__(self, cloud_provider: str, base_url: str):
        self.cloud_provider = cloud_provider
        self.base_url = base_url
        self.client = httpx.AsyncClient(timeout=30.0)
    
    async def get_daily_costs(
        self, 
        start_date: str, 
        end_date: str,
        customer_id: str = None
    ) -> Dict[str, Any]:
        """Query MCP server for daily costs"""
        url = f"{self.base_url}/metrics/costs/daily"
        params = {
            "start_date": start_date,
            "end_date": end_date
        }
        if customer_id:
            params["customer_id"] = customer_id
        
        try:
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            return response.json()
        except httpx.HTTPError as e:
            return {"error": str(e), "cloud_provider": self.cloud_provider}
    
    async def get_model_costs(
        self,
        model: str,
        start_date: str,
        end_date: str
    ) -> Dict[str, Any]:
        """Query MCP server for specific model costs"""
        url = f"{self.base_url}/metrics/tokens/{model}"
        params = {
            "start_date": start_date,
            "end_date": end_date
        }
        
        try:
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            return response.json()
        except httpx.HTTPError as e:
            return {"error": str(e), "cloud_provider": self.cloud_provider}

# Initialize MCP clients
mcp_clients = {
    "gcp": MCPClient("gcp", "https://gcp-mcp-server.run.app"),
    "aws": MCPClient("aws", "https://aws-mcp-server.elb.amazonaws.com"),
    "azure": MCPClient("azure", "https://azure-mcp-server.azurecontainerapps.io")
}

def get_tenant_enabled_clouds(tenant_id: str) -> List[str]:
    """Query database for tenant's enabled clouds"""
    # Simplified - replace with actual DB query
    return ["gcp", "aws"]  # Example: Azure disabled

def parse_query_intent(query: str) -> Dict[str, Any]:
    """Parse user query to extract intent and entities"""
    # Simplified - use actual NLP or LLM here
    query_lower = query.lower()
    
    intent = {
        "type": None,
        "model": None,
        "timeframe": None,
        "clouds": []
    }
    
    # Detect cost query
    if "cost" in query_lower or "spend" in query_lower:
        intent["type"] = "cost_query"
    
    # Detect model
    if "gemini" in query_lower or "palm" in query_lower:
        intent["model"] = "gemini"
        intent["clouds"] = ["gcp"]
    elif "claude" in query_lower or "bedrock" in query_lower:
        intent["model"] = "claude"
        intent["clouds"] = ["aws"]
    elif "gpt" in query_lower or "openai" in query_lower:
        intent["model"] = "gpt"
        intent["clouds"] = ["azure"]
    
    # Detect timeframe
    if "this week" in query_lower:
        intent["timeframe"] = "this_week"
    elif "this month" in query_lower:
        intent["timeframe"] = "this_month"
    elif "yesterday" in query_lower:
        intent["timeframe"] = "yesterday"
    
    return intent

@app.post("/query")
async def orchestrate_query(request: QueryRequest):
    """
    Main orchestrator endpoint
    Handles multi-cloud cost queries
    """
    # 1. Parse user query
    intent = parse_query_intent(request.query)
    
    # 2. Get tenant's enabled clouds
    enabled_clouds = get_tenant_enabled_clouds(request.tenant_id)
    
    # 3. Filter clouds based on intent and tenant config
    query_clouds = [
        cloud for cloud in intent["clouds"] 
        if cloud in enabled_clouds
    ]
    
    if not query_clouds:
        # If no specific cloud mentioned, query all enabled
        query_clouds = enabled_clouds
    
    # 4. Determine date range based on timeframe
    from datetime import datetime, timedelta
    end_date = datetime.now().date()
    if intent["timeframe"] == "this_week":
        start_date = end_date - timedelta(days=7)
    elif intent["timeframe"] == "this_month":
        start_date = end_date - timedelta(days=30)
    elif intent["timeframe"] == "yesterday":
        start_date = end_date - timedelta(days=1)
        end_date = start_date
    else:
        start_date = end_date - timedelta(days=7)  # Default
    
    # 5. Query MCP servers in parallel
    tasks = []
    for cloud in query_clouds:
        client = mcp_clients[cloud]
        if intent["model"]:
            task = client.get_model_costs(
                intent["model"],
                str(start_date),
                str(end_date)
            )
        else:
            task = client.get_daily_costs(
                str(start_date),
                str(end_date),
                request.tenant_id
            )
        tasks.append(task)
    
    # Execute all queries concurrently
    results = await asyncio.gather(*tasks, return_exceptions=True)
    
    # 6. Aggregate results
    total_cost = 0
    cloud_breakdown = {}
    
    for i, result in enumerate(results):
        cloud = query_clouds[i]
        if isinstance(result, dict) and "error" not in result:
            cloud_cost = result.get("data", [{}])[0].get("total_cost", 0)
            total_cost += cloud_cost
            cloud_breakdown[cloud] = {
                "cost": cloud_cost,
                "data": result
            }
    
    # 7. Format response
    response = {
        "query": request.query,
        "tenant_id": request.tenant_id,
        "timeframe": {
            "start": str(start_date),
            "end": str(end_date)
        },
        "total_cost": total_cost,
        "clouds_queried": query_clouds,
        "breakdown": cloud_breakdown,
        "summary": f"Total cost across {len(query_clouds)} cloud(s): ${total_cost:,.2f}"
    }
    
    return response

# Health check
@app.get("/health")
async def health_check():
    """Check health of all MCP servers"""
    health_status = {}
    
    for cloud, client in mcp_clients.items():
        try:
            response = await client.client.get(f"{client.base_url}/health")
            health_status[cloud] = {
                "status": "healthy" if response.status_code == 200 else "unhealthy",
                "latency_ms": response.elapsed.total_seconds() * 1000
            }
        except Exception as e:
            health_status[cloud] = {
                "status": "down",
                "error": str(e)
            }
    
    return {
        "orchestrator": "healthy",
        "mcp_servers": health_status
    }
```

---

## Updated Data Flow

```
User Query: "How much did Gemini cost this week?"
         │
         ▼
┌────────────────────────────────────────────────────────┐
│  Step 1: Orchestrator receives query                   │
│  • Parse: model=gemini, timeframe=this_week            │
│  • Determine: cloud=GCP                                 │
└────────────────────┬───────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────┐
│  Step 2: Check tenant configuration                    │
│  • Query: tenant_cloud_config table                    │
│  • Result: GCP=enabled, AWS=enabled, Azure=disabled    │
│  • Decision: Proceed with GCP query                    │
└────────────────────┬───────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────┐
│  Step 3: Call GCP MCP Server                          │
│  • HTTP GET: gcp-mcp-server/metrics/tokens/gemini     │
│  • Params: start_date, end_date                        │
│  • Response: {cost: 1234.56, tokens: {...}}           │
└────────────────────┬───────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────┐
│  Step 4: Format response                               │
│  • Convert JSON to natural language                    │
│  • "Gemini cost this week: $1,234.56"                 │
│  • Add breakdown: tokens, requests, etc.              │
└────────────────────┬───────────────────────────────────┘
                     │
                     ▼
                 User sees result
```

---

## Deployment Architecture

### Where to Deploy Orchestrator

**Option 1: Same cloud as Grafana (Recommended)**

```
GCP (Primary):
├── Grafana (Cloud Run)
├── Orchestrator Agent (Cloud Run)  ← Deploy here
├── Prometheus Federation (Cloud Run)
└── Cloud Registry DB (Cloud SQL)
```

**Why:** Minimal latency between Grafana and Orchestrator

**Option 2: Separate service**

```
Orchestrator (Cloud Run/ECS/Container App)
├── Exposed via HTTPS
├── API key authentication
└── CORS enabled for Grafana
```

---

## Integration with Grafana

### Using Infinity Data Source Plugin

Grafana can call your Orchestrator REST API using the Infinity plugin:

```json
{
  "datasource": "Infinity",
  "url": "https://orchestrator.run.app/query",
  "method": "POST",
  "body": {
    "query": "${query_text}",
    "tenant_id": "${tenant_id}"
  },
  "headers": {
    "Authorization": "Bearer ${api_key}"
  }
}
```

### Dashboard Variable Configuration

```json
{
  "templating": {
    "list": [
      {
        "name": "query_text",
        "type": "textbox",
        "label": "Ask about costs:",
        "current": {
          "value": "How much did Gemini cost this week?"
        }
      },
      {
        "name": "tenant_id",
        "type": "query",
        "query": "SELECT tenant_id FROM tenants"
      }
    ]
  }
}
```

---

## Cost Impact

**New Component: Orchestrator Agent**

| Deployment | Monthly Cost |
|------------|--------------|
| Cloud Run (GCP) | $10-20 |
| ECS Fargate (AWS) | $15-25 |
| Container App (Azure) | $12-22 |

**Updated Total Cost:**

| Layer | Before | After | Increase |
|-------|--------|-------|----------|
| Cloud Environments (×3) | $240-350 | $240-350 | $0 |
| Unified Monitoring | $50-80 | $50-80 | $0 |
| **Orchestrator (NEW)** | **$0** | **$10-25** | **+$10-25** |
| **Grand Total** | **$290-430** | **$300-455** | **+$10-25** |

---

## Summary

**YES, you absolutely need an Orchestrator Agent because:**

1. ✅ **Grafana limitations** - Cannot call REST APIs directly
2. ✅ **Multi-cloud routing** - Determines which MCP server(s) to query
3. ✅ **Tenant management** - Enforces cloud enable/disable settings
4. ✅ **Response aggregation** - Combines results from multiple clouds
5. ✅ **Natural language** - Translates user queries → MCP API calls

**Architecture Flow:**
```
User → Grafana → Orchestrator Agent → MCP Servers (GCP/AWS/Azure) → Back to User
```

**Recommended Implementation:**
- Use Google ADK for orchestrator (native MCP support)
- Deploy on same cloud as Grafana (low latency)
- ~$10-25/month additional cost
- Enables true conversational multi-cloud monitoring

---

**Document End**
