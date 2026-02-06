# Grafana Architecture: BigQuery Direct vs MCP Servers
## Comparing Two Approaches for Multi-Cloud LLM Cost Monitoring

**Document Version:** 1.0  
**Last Updated:** February 2026  
**Key Question:** Should we use Grafana → BigQuery directly, or build MCP servers?

---

## Executive Summary

**Grafana CAN query BigQuery directly** using its native BigQuery data source plugin. This changes the architectural decision significantly.

**The Choice:**
- **Simple Path:** Grafana → BigQuery (each cloud exports to BigQuery)
- **Advanced Path:** Grafana → Orchestrator → MCP Servers → TimescaleDB

---

## Option 1: Grafana → BigQuery Direct

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    USER INTERFACE                            │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                Grafana Dashboard                        │ │
│  │                                                          │ │
│  │  Data Sources:                                          │ │
│  │  • BigQuery (GCP Billing)                              │ │
│  │  • BigQuery (AWS Cost Explorer → BigQuery)             │ │
│  │  • BigQuery (Azure Cost Mgmt → BigQuery)               │ │
│  └──────────────────────────┬─────────────────────────────┘ │
│                              │                                │
└──────────────────────────────┼────────────────────────────────┘
                               │ SQL Queries
                               ▼
┌─────────────────────────────────────────────────────────────┐
│              GOOGLE BIGQUERY (UNIFIED)                       │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Dataset:     │  │ Dataset:     │  │ Dataset:     │      │
│  │ gcp_billing  │  │ aws_billing  │  │ azure_billing│      │
│  │              │  │              │  │              │      │
│  │ Table:       │  │ Table:       │  │ Table:       │      │
│  │ llm_costs    │  │ llm_costs    │  │ llm_costs    │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │               │
└─────────┼──────────────────┼──────────────────┼───────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ GCP Native   │   │ AWS → ETL    │   │ Azure → ETL  │
│ Billing      │   │ → BigQuery   │   │ → BigQuery   │
│ Export       │   │              │   │              │
└──────────────┘   └──────────────┘   └──────────────┘
```

### How It Works

**1. Export all cloud costs to BigQuery:**

**GCP (Native):**
```bash
# BigQuery billing export is native
# Automatically exports to BigQuery dataset
```

**AWS (ETL Pipeline):**
```python
# Lambda function runs daily
import boto3
from google.cloud import bigquery

def export_aws_to_bigquery(event, context):
    # 1. Query AWS Cost Explorer
    ce = boto3.client('ce')
    response = ce.get_cost_and_usage(
        TimePeriod={'Start': '2026-02-01', 'End': '2026-02-05'},
        Granularity='DAILY',
        Filter={'Dimensions': {'Key': 'SERVICE', 'Values': ['Amazon Bedrock']}},
        Metrics=['BlendedCost', 'UsageQuantity']
    )
    
    # 2. Transform to BigQuery schema
    rows = []
    for result in response['ResultsByTime']:
        rows.append({
            'date': result['TimePeriod']['Start'],
            'cloud_provider': 'AWS',
            'service': 'Bedrock',
            'cost_usd': float(result['Total']['BlendedCost']['Amount']),
            # ... more fields
        })
    
    # 3. Insert into BigQuery
    client = bigquery.Client()
    table_id = 'project.aws_billing.llm_costs'
    errors = client.insert_rows_json(table_id, rows)
```

**Azure (ETL Pipeline):**
```python
# Similar approach using Azure Cost Management API
# Export to BigQuery daily
```

**2. Create unified view in BigQuery:**

```sql
-- Create view combining all clouds
CREATE VIEW `project.unified.llm_costs` AS
SELECT * FROM `project.gcp_billing.llm_costs`
UNION ALL
SELECT * FROM `project.aws_billing.llm_costs`
UNION ALL
SELECT * FROM `project.azure_billing.llm_costs`;
```

**3. Query from Grafana:**

```sql
-- Grafana panel query
SELECT 
  cloud_provider,
  SUM(cost_usd) as total_cost
FROM `project.unified.llm_costs`
WHERE date BETWEEN $__timeFrom() AND $__timeTo()
  AND cloud_provider IN ($cloud_filter)
GROUP BY cloud_provider
```

### Pros

✅ **Simple Architecture** - No MCP servers, no orchestrator
✅ **Native Integration** - Grafana BigQuery plugin is official
✅ **SQL-Based** - Standard SQL queries everyone knows
✅ **Unified Storage** - All data in one place (BigQuery)
✅ **Low Cost** - BigQuery storage is cheap ($20/TB/month)
✅ **Google Managed** - BigQuery handles scaling, backups
✅ **Easy Multi-Cloud** - Just export AWS/Azure → BigQuery

### Cons

❌ **GCP Lock-in** - Requires BigQuery (Google Cloud)
❌ **ETL Complexity** - Need to build AWS/Azure → BigQuery pipelines
❌ **Query Cost** - BigQuery charges per query ($5/TB scanned)
❌ **No Real-Time** - ETL runs daily, not real-time
❌ **Limited by SQL** - Can't do complex orchestration logic
❌ **No MCP Benefits** - Loses conversational AI features
❌ **Latency** - BigQuery queries can be slow on large datasets

### Cost Breakdown

| Component | Monthly Cost |
|-----------|--------------|
| BigQuery Storage (100GB) | $2 |
| BigQuery Queries (~1TB/month) | $5 |
| AWS Lambda (ETL) | $5 |
| Azure Function (ETL) | $5 |
| Grafana (Cloud Run) | $15-25 |
| **TOTAL** | **$32-42/month** |

**Comparison:** $32-42/month vs $300-455/month (MCP approach)

---

## Option 2: MCP Servers + Orchestrator

### Architecture

```
User → Grafana → Orchestrator Agent → MCP Servers → TimescaleDB
```

(See previous SVG for full diagram)

### Pros

✅ **Cloud Agnostic** - Not locked into BigQuery/Google
✅ **Real-Time** - 15-second metric updates via Prometheus
✅ **Rich Features** - MCP tools, conversational AI, agentic workflows
✅ **Distributed** - Each cloud has its own database
✅ **Failure Isolation** - GCP down doesn't affect AWS data
✅ **Advanced Logic** - Orchestrator can do complex routing
✅ **Conversational** - Natural language queries via agent
✅ **Tool Integration** - MCP servers expose tools, not just data

### Cons

❌ **Complex Architecture** - Multiple components to manage
❌ **Higher Cost** - $300-455/month vs $32-42/month
❌ **More Maintenance** - MCP servers, TimescaleDB, orchestrator
❌ **Development Time** - 6-8 weeks to build vs 2-3 weeks
❌ **Learning Curve** - Team needs to learn MCP protocol

### Cost Breakdown

| Component | Monthly Cost |
|-----------|--------------|
| 3 × Cloud Environments | $240-350 |
| Unified Monitoring | $50-80 |
| Orchestrator Agent | $10-25 |
| **TOTAL** | **$300-455/month** |

---

## Decision Matrix

### Choose **Grafana → BigQuery Direct** if:

✅ You want the **simplest solution**
✅ Your primary use case is **dashboards and visualization**
✅ Daily cost updates are sufficient (not real-time)
✅ You're comfortable with GCP/BigQuery lock-in
✅ You have limited budget ($30-40/month is target)
✅ You don't need conversational AI features
✅ Standard SQL queries meet your needs
✅ You're okay with query costs scaling with usage

**Best for:** Startups, MVPs, simple monitoring, budget-conscious

---

### Choose **MCP Servers + Orchestrator** if:

✅ You want **real-time monitoring** (15-second updates)
✅ You need **conversational AI** / natural language queries
✅ You want **cloud independence** (not locked to BigQuery)
✅ You need **advanced orchestration** logic
✅ You plan to build **agentic workflows** on top
✅ **Failure isolation** between clouds is important
✅ You want to expose **MCP tools** (not just data)
✅ Budget allows $300-455/month

**Best for:** Enterprise, production systems, AI-first products, complex workflows

---

## Hybrid Approach (Recommended!)

**Use BOTH architectures together:**

```
┌─────────────────────────────────────────────────────────────┐
│                      GRAFANA                                 │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Dashboard Type 1: Cost Analytics                           │
│  Data Source: BigQuery (SQL queries)                        │
│  • Historical cost trends                                   │
│  • Budget tracking                                          │
│  • Cost forecasting                                         │
│                                                               │
│  Dashboard Type 2: Real-Time Operations                     │
│  Data Source: Orchestrator → MCP Servers                    │
│  • Live token usage                                         │
│  • Active requests per model                                │
│  • Real-time anomaly detection                              │
│                                                               │
│  Dashboard Type 3: Conversational                           │
│  Interface: Infinity Plugin → Orchestrator                  │
│  • "How much did Gemini cost today?"                        │
│  • "Which model is most expensive?"                         │
│  • Natural language queries                                 │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Hybrid Architecture

```
                    ┌─────────────┐
                    │   GRAFANA   │
                    └──────┬──────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  BigQuery    │  │ Orchestrator │  │ Prometheus   │
│  (Historical)│  │ (Conversational)│ (Real-time)  │
└──────────────┘  └──────────────┘  └──────────────┘
                          │
                          ▼
                  ┌──────────────┐
                  │ MCP Servers  │
                  └──────────────┘
```

### Hybrid Benefits

✅ **Cost Efficiency** - Use BigQuery for historical (cheap storage)
✅ **Real-Time** - Use MCP for live metrics (15s updates)
✅ **Conversational** - Use Orchestrator for natural language
✅ **Flexibility** - Right tool for each use case
✅ **Gradual Migration** - Start with BigQuery, add MCP later

### Hybrid Cost

| Component | Monthly Cost |
|-----------|--------------|
| BigQuery (historical) | $5-10 |
| MCP Servers (real-time) | $100-150 |
| Orchestrator (conversational) | $10-25 |
| **TOTAL** | **$115-185/month** |

**Sweet spot:** 60% cost savings vs full MCP, with 80% of features

---

## Grafana BigQuery Configuration

### 1. Install BigQuery Data Source

```bash
# Built-in to Grafana Cloud
# Or for self-hosted:
grafana-cli plugins install grafana-bigquery-datasource
```

### 2. Configure Data Source

```yaml
# grafana/provisioning/datasources/bigquery.yml
apiVersion: 1

datasources:
  - name: BigQuery - GCP Costs
    type: doitintl-bigquery-datasource
    access: proxy
    jsonData:
      authenticationType: gce
      defaultProject: your-gcp-project
      defaultDataset: gcp_billing
    isDefault: false
  
  - name: BigQuery - Multi-Cloud
    type: doitintl-bigquery-datasource
    access: proxy
    jsonData:
      authenticationType: gce
      defaultProject: your-gcp-project
      defaultDataset: unified
    isDefault: true
```

### 3. Create Dashboard with SQL Queries

```sql
-- Panel 1: Total Cost by Cloud
SELECT 
  cloud_provider,
  SUM(cost_usd) as total_cost
FROM `project.unified.llm_costs`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY cloud_provider
ORDER BY total_cost DESC

-- Panel 2: Cost Trend Over Time
SELECT 
  DATE(date) as day,
  cloud_provider,
  SUM(cost_usd) as daily_cost
FROM `project.unified.llm_costs`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY day, cloud_provider
ORDER BY day

-- Panel 3: Top Models by Cost
SELECT 
  model,
  cloud_provider,
  SUM(cost_usd) as model_cost,
  SUM(total_tokens) as tokens
FROM `project.unified.llm_costs`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
GROUP BY model, cloud_provider
ORDER BY model_cost DESC
LIMIT 10

-- Panel 4: Cost per Customer
SELECT 
  customer_id,
  SUM(cost_usd) as customer_cost
FROM `project.unified.llm_costs`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  AND customer_id IS NOT NULL
GROUP BY customer_id
ORDER BY customer_cost DESC
LIMIT 20
```

### 4. Grafana Variables

```json
{
  "templating": {
    "list": [
      {
        "name": "cloud_provider",
        "type": "query",
        "datasource": "BigQuery - Multi-Cloud",
        "query": "SELECT DISTINCT cloud_provider FROM `project.unified.llm_costs` ORDER BY cloud_provider",
        "multi": true,
        "includeAll": true
      },
      {
        "name": "customer_id",
        "type": "query",
        "datasource": "BigQuery - Multi-Cloud",
        "query": "SELECT DISTINCT customer_id FROM `project.unified.llm_costs` WHERE customer_id IS NOT NULL ORDER BY customer_id",
        "multi": false,
        "includeAll": false
      }
    ]
  }
}
```

---

## Recommendation

### For Your Use Case (AI Cost Monitoring SMB Product):

**Start with Hybrid Approach:**

**Phase 1 (MVP - Weeks 1-3):** BigQuery Direct
- Export GCP billing to BigQuery (native)
- Build ETL for AWS/Azure → BigQuery
- Create Grafana dashboards with SQL queries
- **Cost:** $30-40/month
- **Time to market:** 2-3 weeks

**Phase 2 (Enhancement - Weeks 4-8):** Add Real-Time Layer
- Deploy GCP MCP server + TimescaleDB
- Add Prometheus for real-time metrics
- Keep BigQuery for historical analysis
- **Additional cost:** $70-100/month
- **Total:** $100-140/month

**Phase 3 (Advanced - Weeks 9-12):** Add Orchestrator
- Deploy orchestrator agent
- Enable conversational queries
- Add AWS/Azure MCP servers
- **Additional cost:** $80-120/month
- **Total:** $180-260/month

### Why This Approach?

1. ✅ **Fast MVP** - BigQuery gets you live in 2-3 weeks
2. ✅ **Low Initial Cost** - $30-40/month proves concept
3. ✅ **Incremental Investment** - Add features as revenue grows
4. ✅ **Flexibility** - Can pivot without rewriting everything
5. ✅ **Customer Validation** - Prove value before building complex system

---

## Comparison Table

| Feature | BigQuery Direct | MCP Servers | Hybrid |
|---------|----------------|-------------|--------|
| **Cost** | $32-42/mo | $300-455/mo | $115-185/mo |
| **Complexity** | Low | High | Medium |
| **Setup Time** | 2-3 weeks | 6-8 weeks | 4-6 weeks |
| **Real-Time** | No (daily) | Yes (15s) | Yes |
| **Conversational AI** | No | Yes | Yes |
| **Cloud Lock-in** | Yes (BigQuery) | No | Partial |
| **Query Cost** | Variable | Fixed | Mixed |
| **Historical Data** | Excellent | Good | Excellent |
| **Live Metrics** | Poor | Excellent | Excellent |
| **Multi-Tenant** | SQL-based | Native | Both |
| **Maintenance** | Low | High | Medium |

---

## Final Recommendation

**For your AI Cost Monitoring product targeting SMBs:**

🎯 **Start with BigQuery Direct (Phase 1)**
- Prove the value proposition quickly
- Keep costs low during customer acquisition
- $30-40/month fits SMB economics

🎯 **Add MCP Servers (Phase 2) when:**
- You have 10+ paying customers
- Customers request real-time features
- Revenue supports $180-260/month infrastructure

🎯 **Build Full Orchestrator (Phase 3) when:**
- You have 50+ customers
- Conversational AI becomes differentiator
- Can charge premium for AI features

**This staged approach de-risks the investment and lets you learn from customers before building complex infrastructure.**

---

**Document End**
