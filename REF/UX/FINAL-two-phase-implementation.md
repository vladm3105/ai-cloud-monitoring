# FINAL Two-Phase Implementation Guide
## AI Cost Monitoring Platform - Simple Architecture

**Document Version:** 3.0 (FINAL - SIMPLIFIED)  
**Last Updated:** February 2026  
**Architecture:** Cloud Billing → Database → Grafana (No Prometheus!)

---

## Executive Summary

**Simple, Cost-Effective Architecture for LLM Cost Monitoring**

### Phase 1: All-in-BigQuery MVP
- **Cost:** $25-35/month
- **Time:** 2-3 weeks
- **Target:** First 20 customers

### Phase 2: Cloud-Native Independence
- **Cost:** $90-150/month
- **Time:** 7 weeks migration
- **Target:** Enterprise customers (20+)

### What You DON'T Need:
❌ Prometheus  
❌ Prometheus Exporters  
❌ TimescaleDB  
❌ MCP Servers  
❌ Orchestrator Agent  

### What You DO Need:
✅ Cloud Billing APIs  
✅ ETL Functions (AWS/Azure → Database)  
✅ Databases (BigQuery or Cloud-Native)  
✅ Grafana (SQL queries only)  

---

## Table of Contents

1. [Phase 1: All-in-BigQuery MVP](#phase-1-all-in-bigquery-mvp)
2. [Phase 2: Cloud-Native Independence](#phase-2-cloud-native-independence)
3. [Cost Comparison](#cost-comparison)
4. [Implementation Timeline](#implementation-timeline)
5. [Migration Strategy](#migration-strategy)

---

## Phase 1: All-in-BigQuery MVP

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        GRAFANA                               │
│              (Single BigQuery Data Source)                   │
│                                                              │
│  Dashboards query unified_costs view via SQL                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ SQL Queries
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    GOOGLE BIGQUERY                           │
│                                                              │
│  Dataset: multi_cloud_costs                                 │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Tables:                                                │ │
│  │  • gcp_llm_costs    ← GCP Billing (automatic) ✅       │ │
│  │  • aws_llm_costs    ← Cloud Function ETL ⚠️            │ │
│  │  • azure_llm_costs  ← Cloud Function ETL ⚠️            │ │
│  │                                                          │ │
│  │  View: unified_costs                                    │ │
│  │  (UNION ALL of 3 tables)                               │ │
│  └────────────────────────────────────────────────────────┘ │
└───────┬────────────────────┬────────────────────┬───────────┘
        │                    │                    │
        ▼                    ▼                    ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ GCP Billing  │   │ AWS Cost     │   │ Azure Cost   │
│ Export       │   │ Explorer     │   │ Mgmt API     │
│ (Automatic)  │   │ → S3 Export  │   │ (Direct API) │
└──────────────┘   └──────┬───────┘   └──────┬───────┘
                          │                   │
                   ┌──────▼─────┐      ┌──────▼─────┐
                   │ Cloud      │      │ Cloud      │
                   │ Function   │      │ Function   │
                   │ (Python)   │      │ (Python)   │
                   └────────────┘      └────────────┘
```

### Key Points

1. **GCP → BigQuery:** Automatic, no code needed
2. **AWS → BigQuery:** Requires Cloud Function ETL (reads S3, writes BigQuery)
3. **Azure → BigQuery:** Requires Cloud Function ETL (reads Cost API, writes BigQuery)
4. **Grafana:** Queries BigQuery directly via SQL (no Prometheus!)

---

## Phase 1: Step-by-Step Implementation

### Week 1: Infrastructure Setup

#### 1.1 Enable GCP Billing Export

```bash
# In GCP Console:
# Navigation → Billing → Billing Export → BigQuery Export
# ✓ Enable detailed usage cost data
# Dataset: multi_cloud_costs

# Or via gcloud:
gcloud billing accounts export-configs create \
  --billing-account=XXXXXX-XXXXXX-XXXXXX \
  --dataset=multi_cloud_costs \
  --project=your-project-id
```

**Result:** Data automatically flows to:
```
project.multi_cloud_costs.gcp_billing_export_v1_XXXXXX
```

#### 1.2 Enable AWS Cost & Usage Reports

```bash
# Via AWS CLI:
aws cur put-report-definition \
  --region us-east-1 \
  --report-definition \
    ReportName=llm-cost-report,\
    TimeUnit=DAILY,\
    Format=Parquet,\
    Compression=Parquet,\
    S3Bucket=aws-cost-exports-{account-id},\
    S3Prefix=cost-data/,\
    S3Region=us-east-1,\
    AdditionalSchemaElements=RESOURCES
```

**Result:** Daily cost files exported to S3

#### 1.3 Set Up Azure Cost Management

```bash
# Create Azure Service Principal for Cost API access
az ad sp create-for-rbac \
  --name llm-cost-monitoring \
  --role "Cost Management Reader" \
  --scopes /subscriptions/{subscription-id}

# Save the output:
# - appId (client_id)
# - password (client_secret)
# - tenant
```

#### 1.4 Create BigQuery Tables

```sql
-- Table for AWS costs
CREATE TABLE `project.multi_cloud_costs.aws_llm_costs` (
  date DATE NOT NULL,
  cloud_provider STRING DEFAULT 'AWS',
  service STRING,
  model STRING,
  cost_usd FLOAT64,
  usage_amount FLOAT64,
  customer_id STRING,
  ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Table for Azure costs
CREATE TABLE `project.multi_cloud_costs.azure_llm_costs` (
  date DATE NOT NULL,
  cloud_provider STRING DEFAULT 'Azure',
  service STRING,
  model STRING,
  cost_usd FLOAT64,
  usage_amount FLOAT64,
  customer_id STRING,
  ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Unified view
CREATE VIEW `project.multi_cloud_costs.unified_costs` AS
-- GCP data
SELECT 
  DATE(usage_start_time) as date,
  'GCP' as cloud_provider,
  service.description as service,
  REGEXP_EXTRACT(sku.description, r'(Gemini|PaLM|Claude)') as model,
  SUM(cost) as cost_usd,
  SUM(usage.amount) as usage_amount,
  (SELECT value FROM UNNEST(labels) WHERE key = 'customer_id') as customer_id
FROM `project.multi_cloud_costs.gcp_billing_export_v1_*`
WHERE service.description IN ('Vertex AI', 'Cloud AI Platform', 'Document AI')
  AND DATE(_TABLE_SUFFIX) >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
GROUP BY date, cloud_provider, service, model, customer_id

UNION ALL

-- AWS data
SELECT date, cloud_provider, service, model, cost_usd, usage_amount, customer_id
FROM `project.multi_cloud_costs.aws_llm_costs`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)

UNION ALL

-- Azure data
SELECT date, cloud_provider, service, model, cost_usd, usage_amount, customer_id
FROM `project.multi_cloud_costs.azure_llm_costs`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY);
```

---

### Week 2: Build ETL Pipelines

#### 2.1 AWS → BigQuery ETL

**File: `aws_to_bigquery/main.py`**

```python
from google.cloud import bigquery
from google.cloud import storage
import pandas as pd
import boto3
from datetime import datetime, timedelta
import os

def aws_to_bigquery(event, context):
    """
    ETL: AWS Cost & Usage Reports → BigQuery
    Triggered daily by Cloud Scheduler
    """
    
    # AWS S3 client
    s3 = boto3.client(
        's3',
        aws_access_key_id=os.environ['AWS_ACCESS_KEY_ID'],
        aws_secret_access_key=os.environ['AWS_SECRET_ACCESS_KEY']
    )
    
    bucket = 'aws-cost-exports-{account-id}'
    yesterday = (datetime.now() - timedelta(days=1)).strftime('%Y%m%d')
    prefix = f'cost-data/{yesterday}/'
    
    # Download parquet files from S3
    response = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)
    
    dfs = []
    for obj in response.get('Contents', []):
        if obj['Key'].endswith('.parquet'):
            local_file = f"/tmp/{obj['Key'].split('/')[-1]}"
            s3.download_file(bucket, obj['Key'], local_file)
            
            # Read parquet
            df = pd.read_parquet(local_file)
            
            # Filter for LLM services
            df_filtered = df[df['line_item_product_code'].isin([
                'AmazonBedrock',
                'AmazonSageMaker'
            ])].copy()
            
            dfs.append(df_filtered)
    
    if not dfs:
        print("No AWS cost data found")
        return
    
    # Combine all files
    df_all = pd.concat(dfs, ignore_index=True)
    
    # Transform to BigQuery schema
    df_transformed = pd.DataFrame({
        'date': pd.to_datetime(df_all['line_item_usage_start_date']).dt.date,
        'cloud_provider': 'AWS',
        'service': df_all['line_item_product_code'].map({
            'AmazonBedrock': 'Bedrock',
            'AmazonSageMaker': 'SageMaker'
        }),
        'model': df_all['line_item_usage_type'].apply(extract_aws_model),
        'cost_usd': df_all['line_item_blended_cost'].astype(float),
        'usage_amount': df_all['line_item_usage_amount'].astype(float),
        'customer_id': df_all.get('resource_tags_user_customer_id', None)
    })
    
    # Load to BigQuery
    client = bigquery.Client()
    table_id = 'project.multi_cloud_costs.aws_llm_costs'
    
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        schema=[
            bigquery.SchemaField('date', 'DATE'),
            bigquery.SchemaField('cloud_provider', 'STRING'),
            bigquery.SchemaField('service', 'STRING'),
            bigquery.SchemaField('model', 'STRING'),
            bigquery.SchemaField('cost_usd', 'FLOAT64'),
            bigquery.SchemaField('usage_amount', 'FLOAT64'),
            bigquery.SchemaField('customer_id', 'STRING'),
        ]
    )
    
    job = client.load_table_from_dataframe(df_transformed, table_id, job_config=job_config)
    job.result()
    
    print(f"✓ Loaded {len(df_transformed)} AWS cost records to BigQuery")

def extract_aws_model(usage_type):
    """Extract model name from AWS usage type"""
    if 'Claude' in usage_type:
        return 'claude-v2'
    elif 'Titan' in usage_type:
        return 'titan'
    elif 'Jurassic' in usage_type:
        return 'jurassic-2'
    return 'unknown'
```

**File: `aws_to_bigquery/requirements.txt`**

```
google-cloud-bigquery==3.13.0
google-cloud-storage==2.10.0
pandas==2.1.0
pyarrow==13.0.0
boto3==1.28.0
```

**Deploy:**

```bash
gcloud functions deploy aws-to-bigquery \
  --runtime python311 \
  --trigger-topic aws-cost-etl \
  --entry-point aws_to_bigquery \
  --memory 512MB \
  --timeout 540s \
  --set-env-vars AWS_ACCESS_KEY_ID=xxx,AWS_SECRET_ACCESS_KEY=xxx

# Create daily schedule
gcloud scheduler jobs create pubsub aws-daily-etl \
  --location us-central1 \
  --schedule="0 3 * * *" \
  --topic=aws-cost-etl \
  --message-body='{"trigger":"daily"}'
```

#### 2.2 Azure → BigQuery ETL

**File: `azure_to_bigquery/main.py`**

```python
from google.cloud import bigquery
from azure.identity import ClientSecretCredential
from azure.mgmt.costmanagement import CostManagementClient
import pandas as pd
from datetime import datetime, timedelta
import os

def azure_to_bigquery(event, context):
    """
    ETL: Azure Cost Management API → BigQuery
    Triggered daily by Cloud Scheduler
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
    
    # Query Azure Cost Management
    query_definition = {
        "type": "Usage",
        "timeframe": "Custom",
        "timePeriod": {
            "from": yesterday,
            "to": yesterday
        },
        "dataset": {
            "granularity": "Daily",
            "aggregation": {
                "totalCost": {"name": "Cost", "function": "Sum"},
                "totalQuantity": {"name": "UsageQuantity", "function": "Sum"}
            },
            "grouping": [
                {"type": "Dimension", "name": "ResourceGroup"},
                {"type": "Dimension", "name": "ServiceName"},
                {"type": "Dimension", "name": "MeterCategory"},
                {"type": "Dimension", "name": "MeterName"}
            ],
            "filter": {
                "dimensions": {
                    "name": "ServiceName",
                    "operator": "In",
                    "values": ["Azure OpenAI", "Cognitive Services"]
                }
            }
        }
    }
    
    result = cost_client.query.usage(scope, query_definition)
    
    # Transform to DataFrame
    rows = []
    for row in result.rows:
        rows.append({
            'date': yesterday,
            'cloud_provider': 'Azure',
            'service': row[1] if len(row) > 1 else 'Unknown',
            'model': extract_azure_model(row[2] if len(row) > 2 else '', row[3] if len(row) > 3 else ''),
            'cost_usd': float(row[4]) if len(row) > 4 else 0,
            'usage_amount': float(row[5]) if len(row) > 5 else 0,
            'customer_id': extract_customer_from_rg(row[0] if len(row) > 0 else '')
        })
    
    df = pd.DataFrame(rows)
    
    if df.empty:
        print("No Azure cost data found")
        return
    
    # Load to BigQuery
    client = bigquery.Client()
    table_id = 'project.multi_cloud_costs.azure_llm_costs'
    
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        schema=[
            bigquery.SchemaField('date', 'DATE'),
            bigquery.SchemaField('cloud_provider', 'STRING'),
            bigquery.SchemaField('service', 'STRING'),
            bigquery.SchemaField('model', 'STRING'),
            bigquery.SchemaField('cost_usd', 'FLOAT64'),
            bigquery.SchemaField('usage_amount', 'FLOAT64'),
            bigquery.SchemaField('customer_id', 'STRING'),
        ]
    )
    
    job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
    job.result()
    
    print(f"✓ Loaded {len(df)} Azure cost records to BigQuery")

def extract_azure_model(meter_category, meter_name):
    """Extract model from Azure meter information"""
    combined = f"{meter_category} {meter_name}"
    
    if 'GPT-4' in combined:
        return 'gpt-4'
    elif 'GPT-3.5' in combined or 'GPT-35' in combined:
        return 'gpt-3.5-turbo'
    elif 'embedding' in combined.lower():
        return 'text-embedding-ada-002'
    return 'unknown'

def extract_customer_from_rg(resource_group):
    """Extract customer ID from resource group name"""
    # Assumes naming: rg-customer-{id}-...
    if resource_group and 'customer' in resource_group:
        parts = resource_group.split('-')
        for i, part in enumerate(parts):
            if part == 'customer' and i + 1 < len(parts):
                return parts[i + 1]
    return None
```

**File: `azure_to_bigquery/requirements.txt`**

```
google-cloud-bigquery==3.13.0
azure-identity==1.14.0
azure-mgmt-costmanagement==4.0.0
pandas==2.1.0
```

**Deploy:**

```bash
gcloud functions deploy azure-to-bigquery \
  --runtime python311 \
  --trigger-topic azure-cost-etl \
  --entry-point azure_to_bigquery \
  --memory 512MB \
  --timeout 540s \
  --set-env-vars \
    AZURE_TENANT_ID=xxx,\
    AZURE_CLIENT_ID=xxx,\
    AZURE_CLIENT_SECRET=xxx,\
    AZURE_SUBSCRIPTION_ID=xxx

# Create daily schedule
gcloud scheduler jobs create pubsub azure-daily-etl \
  --location us-central1 \
  --schedule="0 4 * * *" \
  --topic=azure-cost-etl \
  --message-body='{"trigger":"daily"}'
```

---

### Week 3: Grafana Dashboards

#### 3.1 Deploy Grafana

```bash
# Deploy Grafana on Cloud Run
gcloud run deploy grafana \
  --image grafana/grafana:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 1Gi \
  --set-env-vars GF_SECURITY_ADMIN_PASSWORD=YourPassword123
```

#### 3.2 Configure BigQuery Data Source

**File: `grafana/provisioning/datasources/bigquery.yml`**

```yaml
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

#### 3.3 Dashboard: Multi-Cloud Cost Overview

**File: `grafana/dashboards/cost-overview.json`**

```json
{
  "dashboard": {
    "title": "Multi-Cloud LLM Cost Overview",
    "panels": [
      {
        "id": 1,
        "title": "Total Cost by Cloud (Last 30 Days)",
        "type": "piechart",
        "targets": [
          {
            "rawSql": "SELECT cloud_provider, SUM(cost_usd) as total_cost FROM `project.multi_cloud_costs.unified_costs` WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY) GROUP BY cloud_provider ORDER BY total_cost DESC"
          }
        ]
      },
      {
        "id": 2,
        "title": "Daily Cost Trend",
        "type": "timeseries",
        "targets": [
          {
            "rawSql": "SELECT date, cloud_provider, SUM(cost_usd) as daily_cost FROM `project.multi_cloud_costs.unified_costs` WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY) GROUP BY date, cloud_provider ORDER BY date"
          }
        ]
      },
      {
        "id": 3,
        "title": "Top 10 Models by Cost",
        "type": "table",
        "targets": [
          {
            "rawSql": "SELECT model, cloud_provider, SUM(cost_usd) as total_cost, SUM(usage_amount) as total_usage FROM `project.multi_cloud_costs.unified_costs` WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY) AND model IS NOT NULL GROUP BY model, cloud_provider ORDER BY total_cost DESC LIMIT 10"
          }
        ]
      },
      {
        "id": 4,
        "title": "Cost by Customer",
        "type": "bargauge",
        "targets": [
          {
            "rawSql": "SELECT customer_id, SUM(cost_usd) as customer_cost FROM `project.multi_cloud_costs.unified_costs` WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY) AND customer_id IS NOT NULL GROUP BY customer_id ORDER BY customer_cost DESC LIMIT 20"
          }
        ]
      }
    ],
    "templating": {
      "list": [
        {
          "name": "cloud_provider",
          "type": "query",
          "query": "SELECT DISTINCT cloud_provider FROM `project.multi_cloud_costs.unified_costs` ORDER BY cloud_provider",
          "multi": true,
          "includeAll": true
        }
      ]
    }
  }
}
```

---

## Phase 1: Cost Breakdown

| Component | Monthly Cost | Notes |
|-----------|--------------|-------|
| BigQuery Storage (50GB) | $1.00 | $0.02/GB |
| BigQuery Queries (500GB) | $2.50 | $5/TB |
| AWS S3 (Cost Reports) | $1.00 | Minimal storage |
| Cloud Functions (AWS ETL) | $3.00 | Daily invocations |
| Cloud Functions (Azure ETL) | $3.00 | Daily invocations |
| Cloud Scheduler | $0.10 | 2 jobs |
| Grafana (Cloud Run) | $15-25 | 1 instance |
| **TOTAL** | **$25.60-35.60** | |

**Rounded: $25-35/month**

---

## Phase 2: Cloud-Native Independence

### Architecture Diagram

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
└─────┬──────┘   └─────┬──────┘   └─────┬──────┘
      │                │                │
      ▼                ▼                ▼
┌────────────┐   ┌────────────┐   ┌────────────┐
│    GCP     │   │   Lambda   │   │  Function  │
│  Billing   │   │    ETL     │   │  App ETL   │
│  (Native)  │   │  (Python)  │   │  (Python)  │
└────────────┘   └────────────┘   └────────────┘
```

### Changes from Phase 1

1. **AWS:** Cloud Function → Lambda (writes to Redshift instead of BigQuery)
2. **Azure:** Cloud Function → Function App (writes to Azure SQL instead of BigQuery)
3. **Grafana:** 1 data source → 3 data sources

### Infrastructure Setup

#### Deploy AWS Redshift

```bash
aws redshift create-cluster \
  --cluster-identifier llm-costs \
  --node-type dc2.large \
  --number-of-nodes 1 \
  --master-username admin \
  --master-user-password YourPassword123 \
  --publicly-accessible
```

#### Deploy Azure SQL Database

```bash
az sql server create \
  --name llm-costs-server \
  --resource-group ai-monitoring \
  --location eastus \
  --admin-user sqladmin \
  --admin-password YourPassword123!

az sql db create \
  --resource-group ai-monitoring \
  --server llm-costs-server \
  --name llm_costs \
  --service-objective S0
```

---

## Phase 2: Cost Breakdown

| Component | Monthly Cost | Notes |
|-----------|--------------|-------|
| BigQuery (GCP only) | $2-5 | Smaller dataset |
| Redshift dc2.large | $50-80 | AWS data warehouse |
| Azure SQL S0 | $15-30 | Azure data warehouse |
| Lambda (AWS ETL) | $3-5 | Daily invocations |
| Function App (Azure ETL) | $3-5 | Daily invocations |
| Grafana | $15-25 | 1 instance |
| **TOTAL** | **$88-150** | |

**Rounded: $90-150/month**

---

## Cost Comparison Summary

| Metric | Phase 1 | Phase 2 | Difference |
|--------|---------|---------|------------|
| **Monthly Cost** | $25-35 | $90-150 | +$65-115 |
| **Cloud Independence** | ❌ BigQuery locked | ✅ Native per cloud | Better |
| **Failure Isolation** | ❌ Single point | ✅ Independent | Better |
| **Grafana Data Sources** | 1 | 3 | More complex |
| **Query Language** | BigQuery SQL | 3 SQL dialects | More complex |
| **Setup Time** | 2-3 weeks | 7 weeks | Longer |
| **Enterprise Appeal** | Medium | High | Better |

---

## Implementation Timeline

### Phase 1: MVP (2-3 weeks)

| Week | Tasks | Deliverables |
|------|-------|--------------|
| **Week 1** | Infrastructure Setup | • GCP billing export enabled<br>• AWS CUR to S3<br>• Azure Cost API access<br>• BigQuery tables created |
| **Week 2** | Build ETL Pipelines | • AWS → BigQuery ETL deployed<br>• Azure → BigQuery ETL deployed<br>• Cloud Schedulers configured<br>• Data flowing daily |
| **Week 3** | Grafana Dashboards | • Grafana deployed<br>• BigQuery data source configured<br>• 3-4 dashboards created<br>• Production ready ✓ |

### Phase 2: Migration (7 weeks)

| Week | Tasks | Deliverables |
|------|-------|--------------|
| **Week 1** | AWS Infrastructure | • Redshift cluster deployed<br>• Lambda ETL created<br>• Test AWS queries |
| **Week 2** | Azure Infrastructure | • Azure SQL deployed<br>• Function App ETL created<br>• Test Azure queries |
| **Week 3** | Grafana Multi-Source | • Add Redshift data source<br>• Add Azure SQL data source<br>• Duplicate dashboards |
| **Week 4** | Pilot Migration | • Migrate 5 customers<br>• Monitor for issues |
| **Week 5** | Batch Migration | • Migrate 10 more customers |
| **Week 6** | Complete Migration | • Migrate remaining customers |
| **Week 7** | Cleanup | • Deprecate BigQuery ETL<br>• Update docs<br>• Marketing updates |

---

## Migration Strategy

### When to Migrate to Phase 2

**Trigger Points:**
- ✅ 20+ paying customers
- ✅ $50K+ monthly recurring revenue
- ✅ Enterprise deals requiring cloud independence
- ✅ Customer concerns about vendor lock-in

### Migration Approach

**Gradual, Low-Risk Migration:**

```
Week 4: Migrate 5 pilot customers
  ↓
Week 5: Monitor pilot, migrate 10 more
  ↓
Week 6: Migrate remaining customers
  ↓
Week 7: Deprecate Phase 1 infrastructure
```

**Dual-Write Period:**
- Keep Phase 1 running during migration
- Validate Phase 2 data matches Phase 1
- Gradual customer switchover
- Rollback capability maintained

---

## Decision Matrix

### Choose Phase 1 (All-in-BigQuery) if:

✅ You're launching MVP (first 20 customers)  
✅ Budget is constrained ($25-35/mo target)  
✅ Speed to market is critical (2-3 weeks)  
✅ Okay with GCP dependency temporarily  
✅ Simple architecture preferred  

### Choose Phase 2 (Cloud-Native) if:

✅ You have 20+ customers  
✅ Revenue supports $90-150/mo infrastructure  
✅ Enterprise customers demand independence  
✅ "No vendor lock-in" is sales differentiator  
✅ Budget allows higher operational costs  

---

## Key Learnings

### What We Learned

1. **Prometheus NOT needed** for cost monitoring
   - Prometheus = real-time application metrics
   - Cost monitoring = daily billing data
   - Different use cases entirely

2. **ETL required in both phases**
   - AWS can't export to BigQuery natively
   - Azure can't export to BigQuery natively
   - Same ETL complexity in Phase 1 & 2

3. **Phase 1 is simpler due to single data source**
   - Not because of less ETL (same ETL needed)
   - But because Grafana queries 1 source vs 3

4. **Cost difference is minimal vs customer value**
   - Phase 1 → 2: +$65-115/month
   - Customer saves: $30K-47K/month
   - Infrastructure cost: 0.2% of savings

### Architecture Principles

✅ **Keep it simple** - No unnecessary components  
✅ **Use managed services** - BigQuery, Redshift, Azure SQL  
✅ **SQL-based queries** - Grafana native capability  
✅ **Gradual migration** - Phase 1 → Phase 2 when triggered  

---

## Final Recommendation

### For Your SMB AI Cost Monitoring Product

**Start with Phase 1:**
- Cost: $25-35/month
- Time: 2-3 weeks
- Get first 20 customers
- Prove product-market fit
- Keep architecture simple

**Migrate to Phase 2 when:**
- 20+ paying customers
- Revenue supports infrastructure cost
- Enterprise deals require independence
- Marketing needs "true multi-cloud" story

**Expected Path:**
```
Month 1-2: Build Phase 1 (2-3 weeks)
Month 3-8: Acquire 20 customers
Month 9-10: Migrate to Phase 2 (7 weeks)
Month 11+: Scale with Phase 2
```

---

## Appendix: Quick Reference

### Phase 1 Checklist

- [ ] Enable GCP billing export to BigQuery
- [ ] Enable AWS Cost & Usage Reports to S3
- [ ] Create Azure service principal for Cost API
- [ ] Create BigQuery dataset and tables
- [ ] Deploy AWS → BigQuery Cloud Function
- [ ] Deploy Azure → BigQuery Cloud Function
- [ ] Set up Cloud Scheduler (daily triggers)
- [ ] Deploy Grafana on Cloud Run
- [ ] Configure BigQuery data source
- [ ] Create 3-4 core dashboards
- [ ] Test end-to-end data flow
- [ ] Launch to first customers

### Phase 2 Checklist

- [ ] Deploy Redshift cluster (AWS)
- [ ] Deploy Azure SQL Database (Azure)
- [ ] Migrate AWS ETL to Lambda → Redshift
- [ ] Migrate Azure ETL to Function App → SQL
- [ ] Add Redshift data source to Grafana
- [ ] Add Azure SQL data source to Grafana
- [ ] Duplicate dashboards for 3 sources
- [ ] Migrate 5 pilot customers
- [ ] Monitor and validate
- [ ] Migrate remaining customers
- [ ] Deprecate Phase 1 BigQuery ETL
- [ ] Update documentation and marketing

---

**Document End**

---

**FINAL IMPLEMENTATION GUIDE**

This is your complete implementation guide. The architecture is simple:
- Cloud Billing → ETL → Database → Grafana
- No Prometheus, no exporters, no unnecessary complexity
- Start with Phase 1 ($25-35/mo), migrate to Phase 2 when you have 20+ customers

Good luck building your AI Cost Monitoring platform!
