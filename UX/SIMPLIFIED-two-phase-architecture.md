# SIMPLIFIED Two-Phase Architecture (No Prometheus!)
## AI Cost Monitoring - Grafana + Cloud Databases Only

**Document Version:** 2.0 (CORRECTED)  
**Last Updated:** February 2026  
**Key Simplification:** No Prometheus, No Exporters, No TimescaleDB needed!

---

## Critical Clarification

**YOU DO NOT NEED PROMETHEUS FOR COST MONITORING**

Prometheus is for:
- ✅ Real-time application metrics (15-second intervals)
- ✅ Live system monitoring (CPU, memory, requests/sec)
- ✅ Operational dashboards

**Your use case is cost monitoring, which needs:**
- ✅ Daily/hourly cost data from cloud billing
- ✅ Historical analysis
- ✅ Cost trends and forecasting

**Solution:** Grafana queries databases directly via SQL. No Prometheus needed.

---

## Simplified Architecture

### Phase 1: All-in-BigQuery

```
┌─────────────────────────────────────────────────────────────┐
│                        GRAFANA                               │
│              (Single BigQuery Data Source)                   │
│                                                              │
│  Queries: SELECT * FROM unified_costs WHERE ...             │
└────────────────────────┬────────────────────────────────────┘
                         │ SQL Queries
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    GOOGLE BIGQUERY                           │
│                                                              │
│  Dataset: multi_cloud_costs                                 │
│  Tables:                                                     │
│  • gcp_llm_costs    ← GCP Billing Export (automatic)       │
│  • aws_llm_costs    ← ETL from AWS Cost Explorer           │
│  • azure_llm_costs  ← ETL from Azure Cost API              │
│                                                              │
│  View: unified_costs (UNION ALL of 3 tables)               │
└───────┬────────────────────┬────────────────────┬───────────┘
        │                    │                    │
        ▼                    ▼                    ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ GCP Billing  │   │ AWS Cost     │   │ Azure Cost   │
│ Export       │   │ Explorer     │   │ Mgmt API     │
│ (Automatic)  │   │ → S3         │   │              │
└──────────────┘   └──────┬───────┘   └──────┬───────┘
                          │                   │
                   ┌──────▼─────┐      ┌──────▼─────┐
                   │ Cloud      │      │ Cloud      │
                   │ Function   │      │ Function   │
                   │ (ETL)      │      │ (ETL)      │
                   └────────────┘      └────────────┘
```

**NO Prometheus. NO Exporters. NO TimescaleDB.**

Just: **Cloud Billing → Database → Grafana**

---

## Phase 1: Detailed Components

### 1. GCP → BigQuery (Native)

**No code needed - it's automatic!**

```bash
# Enable in GCP Console
# Billing → Billing Export → BigQuery Export
# Select dataset: multi_cloud_costs

# Done! Data flows automatically every few hours
```

**Data appears in BigQuery table:**
```
project.multi_cloud_costs.gcp_billing_export_v1_XXXXXX
```

### 2. AWS → BigQuery (ETL)

**Cloud Function to copy AWS costs to BigQuery:**

```python
# cloud_function.py
from google.cloud import bigquery
import boto3
import pandas as pd
from datetime import datetime, timedelta

def aws_to_bigquery(event, context):
    """
    Simple ETL: AWS Cost Explorer → BigQuery
    Runs daily via Cloud Scheduler
    """
    
    # Query AWS Cost Explorer
    ce = boto3.client('ce')
    
    yesterday = (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d')
    
    response = ce.get_cost_and_usage(
        TimePeriod={'Start': yesterday, 'End': yesterday},
        Granularity='DAILY',
        Filter={
            'Dimensions': {
                'Key': 'SERVICE',
                'Values': ['Amazon Bedrock', 'Amazon SageMaker']
            }
        },
        Metrics=['BlendedCost', 'UsageQuantity'],
        GroupBy=[
            {'Type': 'DIMENSION', 'Key': 'USAGE_TYPE'},
            {'Type': 'TAG', 'Key': 'customer_id'}
        ]
    )
    
    # Transform to DataFrame
    rows = []
    for result in response['ResultsByTime']:
        for group in result['Groups']:
            rows.append({
                'date': yesterday,
                'cloud_provider': 'AWS',
                'service': 'Bedrock',
                'model': extract_model(group['Keys'][0]),
                'cost_usd': float(group['Metrics']['BlendedCost']['Amount']),
                'usage_amount': float(group['Metrics']['UsageQuantity']['Amount']),
                'customer_id': group['Keys'][1] if len(group['Keys']) > 1 else None
            })
    
    df = pd.DataFrame(rows)
    
    # Load to BigQuery
    client = bigquery.Client()
    table_id = 'project.multi_cloud_costs.aws_llm_costs'
    
    job = client.load_table_from_dataframe(df, table_id)
    job.result()
    
    print(f"Loaded {len(df)} rows")

def extract_model(usage_type):
    if 'Claude' in usage_type:
        return 'claude-v2'
    elif 'Titan' in usage_type:
        return 'titan'
    return 'unknown'
```

**Deploy:**
```bash
gcloud functions deploy aws-to-bigquery \
  --runtime python311 \
  --trigger-topic aws-cost-etl \
  --entry-point aws_to_bigquery

gcloud scheduler jobs create pubsub aws-daily-etl \
  --schedule="0 3 * * *" \
  --topic=aws-cost-etl \
  --message-body="run"
```

### 3. Azure → BigQuery (ETL)

**Cloud Function to copy Azure costs to BigQuery:**

```python
# cloud_function.py
from google.cloud import bigquery
from azure.identity import ClientSecretCredential
from azure.mgmt.costmanagement import CostManagementClient
import pandas as pd
from datetime import datetime, timedelta

def azure_to_bigquery(event, context):
    """
    Simple ETL: Azure Cost Management → BigQuery
    Runs daily via Cloud Scheduler
    """
    
    # Azure credentials
    credential = ClientSecretCredential(
        tenant_id=os.environ['AZURE_TENANT_ID'],
        client_id=os.environ['AZURE_CLIENT_ID'],
        client_secret=os.environ['AZURE_CLIENT_SECRET']
    )
    
    cost_client = CostManagementClient(credential)
    scope = f"/subscriptions/{os.environ['AZURE_SUBSCRIPTION_ID']}"
    
    yesterday = (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d')
    
    # Query Azure Cost Management API
    query = {
        "type": "Usage",
        "timeframe": "Custom",
        "timePeriod": {"from": yesterday, "to": yesterday},
        "dataset": {
            "granularity": "Daily",
            "aggregation": {
                "totalCost": {"name": "Cost", "function": "Sum"}
            },
            "filter": {
                "dimensions": {
                    "name": "ServiceName",
                    "operator": "In",
                    "values": ["Azure OpenAI", "Cognitive Services"]
                }
            }
        }
    }
    
    result = cost_client.query.usage(scope, query)
    
    # Transform to DataFrame
    rows = []
    for row in result.rows:
        rows.append({
            'date': yesterday,
            'cloud_provider': 'Azure',
            'service': row[1],
            'model': extract_azure_model(row[2]),
            'cost_usd': float(row[3]),
            'usage_amount': 0,
            'customer_id': None
        })
    
    df = pd.DataFrame(rows)
    
    # Load to BigQuery
    client = bigquery.Client()
    table_id = 'project.multi_cloud_costs.azure_llm_costs'
    
    job = client.load_table_from_dataframe(df, table_id)
    job.result()
    
    print(f"Loaded {len(df)} rows")

def extract_azure_model(meter_category):
    if 'GPT-4' in meter_category:
        return 'gpt-4'
    elif 'GPT-3.5' in meter_category:
        return 'gpt-3.5-turbo'
    return 'unknown'
```

### 4. Grafana Configuration

**Single data source:**

```yaml
# grafana/provisioning/datasources/bigquery.yml
apiVersion: 1

datasources:
  - name: Multi-Cloud Costs
    type: doitintl-bigquery-datasource
    access: proxy
    jsonData:
      authenticationType: gce
      defaultProject: your-gcp-project
      defaultDataset: multi_cloud_costs
    isDefault: true
```

**Dashboard queries (pure SQL):**

```sql
-- Total cost by cloud
SELECT 
  cloud_provider,
  SUM(cost_usd) as total_cost
FROM (
  SELECT date, 'GCP' as cloud_provider, SUM(cost) as cost_usd
  FROM `project.multi_cloud_costs.gcp_billing_export_v1_*`
  WHERE DATE(_TABLE_SUFFIX) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  GROUP BY date
  
  UNION ALL
  
  SELECT date, cloud_provider, cost_usd
  FROM `project.multi_cloud_costs.aws_llm_costs`
  WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  
  UNION ALL
  
  SELECT date, cloud_provider, cost_usd
  FROM `project.multi_cloud_costs.azure_llm_costs`
  WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
)
GROUP BY cloud_provider
```

---

## Phase 1 Infrastructure

### What You Need:

1. **BigQuery** (storage + queries)
2. **2 Cloud Functions** (AWS & Azure ETL)
3. **Cloud Scheduler** (trigger ETL daily)
4. **Grafana** (dashboards)

### What You DON'T Need:

❌ Prometheus  
❌ Prometheus Exporters  
❌ TimescaleDB  
❌ MCP Servers  
❌ Orchestrator Agent  

### Cost Breakdown:

| Component | Monthly Cost |
|-----------|--------------|
| BigQuery (50GB storage) | $1 |
| BigQuery (500GB queries) | $2.50 |
| Cloud Functions (2 × daily) | $5 |
| Cloud Scheduler | $0.10 |
| Grafana (Cloud Run) | $15-25 |
| **TOTAL** | **$23.60-33.60** |

**Rounded: $25-35/month**

---

## Phase 2: Cloud-Native (No Prometheus Either!)

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        GRAFANA                               │
│              (3 Independent Data Sources)                    │
└────┬─────────────────┬─────────────────┬───────────────────┘
     │                 │                 │
     │ SQL             │ SQL             │ SQL
     ▼                 ▼                 ▼
┌────────────┐   ┌────────────┐   ┌────────────┐
│  BigQuery  │   │  Redshift  │   │ Azure SQL  │
│   (GCP)    │   │   (AWS)    │   │  (Azure)   │
└────────────┘   └────────────┘   └────────────┘
     ▲                 ▲                 ▲
     │                 │                 │
┌────┴────┐      ┌────┴────┐      ┌────┴────┐
│   GCP   │      │  Lambda │      │ Function│
│ Billing │      │   ETL   │      │App ETL  │
└─────────┘      └─────────┘      └─────────┘
```

**Still no Prometheus!**

### Infrastructure Changes:

**From Phase 1:**
- BigQuery (GCP costs only)
- 2 Cloud Functions → 2 native ETL (Lambda + Function App)
- Grafana (3 data sources instead of 1)

**Still NOT needed:**
❌ Prometheus  
❌ Exporters  
❌ TimescaleDB  

### Cost Breakdown:

| Component | Monthly Cost |
|-----------|--------------|
| BigQuery (GCP only) | $2-5 |
| Redshift dc2.large | $50-80 |
| Azure SQL S0 | $15-30 |
| Lambda (AWS ETL) | $3-5 |
| Function App (Azure ETL) | $3-5 |
| Grafana | $15-25 |
| **TOTAL** | **$88-150** |

**Rounded: $90-150/month**

---

## When Would You Need Prometheus?

### **Only if you want REAL-TIME metrics:**

**Example use case:**
- "Show me token usage in the last 15 seconds"
- "Alert if requests/sec > 1000 right now"
- "Live dashboard of active LLM requests"

**Architecture with Prometheus:**
```
Applications
    ↓ (expose /metrics endpoint)
Prometheus (scrapes every 15s)
    ↓
Grafana (real-time charts)
```

**But for your cost monitoring product:**
- Customers care about **daily/weekly costs**
- Not **15-second request rates**
- So you **DON'T need Prometheus**

---

## Corrected Comparison

### Without Prometheus (Your Use Case):

| Phase | Components | Cost/Month |
|-------|-----------|------------|
| **Phase 1** | BigQuery + 2 Cloud Functions + Grafana | $25-35 |
| **Phase 2** | 3 Databases + 3 ETL + Grafana | $90-150 |

### With Prometheus (NOT your use case):

| Phase | Components | Cost/Month |
|-------|-----------|------------|
| **Complex** | Databases + Prometheus + Exporters + TimescaleDB + Grafana | $300-455 |

---

## Summary

### What You're Building:

```
Cloud Billing Data → ETL → Database → Grafana
```

**That's it. Simple SQL queries in Grafana.**

### What You're NOT Building:

```
Applications → Prometheus Exporter → Prometheus → TimescaleDB → Grafana
```

**This is for real-time metrics, not cost monitoring.**

---

## Implementation Checklist (Corrected)

### Phase 1 (2-3 weeks):

- [ ] Week 1: Setup
  - [ ] Enable GCP Billing Export to BigQuery ✅
  - [ ] Create BigQuery dataset ✅
  - [ ] Enable AWS Cost & Usage Reports ✅
  - [ ] Set up Azure Cost Management API access ✅
  
- [ ] Week 2: ETL
  - [ ] Build Cloud Function: AWS → BigQuery ✅
  - [ ] Build Cloud Function: Azure → BigQuery ✅
  - [ ] Set up Cloud Scheduler (daily) ✅
  - [ ] Test data flow ✅
  
- [ ] Week 3: Dashboards
  - [ ] Configure Grafana BigQuery data source ✅
  - [ ] Build dashboards with SQL queries ✅
  - [ ] Test with real data ✅

**NO Prometheus setup. NO Exporter development. NO TimescaleDB.**

### Phase 2 (7 weeks):

- [ ] Deploy Redshift (AWS)
- [ ] Deploy Azure SQL (Azure)
- [ ] Modify ETL to write to native DBs
- [ ] Add Grafana data sources
- [ ] Migrate customers gradually

**Still NO Prometheus needed.**

---

## Final Answer

**NO - You do NOT need Prometheus if you're using BigQuery/Redshift/Azure SQL.**

Your architecture is simply:

```
Cloud APIs → ETL → Database → Grafana
```

**Cost:**
- Phase 1: $25-35/month (not $300-455!)
- Phase 2: $90-150/month

I apologize for the confusion in earlier documents. The Prometheus stack was a significant overcomplication for cost monitoring use cases.

---

**Document End**
