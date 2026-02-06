# Cloud-Native Data Warehouse Architecture
## Independent Cloud Environments with Grafana Integration

**Document Version:** 1.0  
**Last Updated:** February 2026  
**Key Principle:** Each cloud uses its native data warehouse - true independence

---

## Executive Summary

**YES - Each cloud can use its native data warehouse:**

- **GCP:** BigQuery (native billing export)
- **AWS:** Redshift (Cost Explorer → S3 → Redshift)
- **Azure:** Azure SQL Database / Synapse Analytics (Cost Management API → SQL)

**All three are supported by Grafana** with official data source plugins!

This architecture provides:
✅ **True Cloud Independence** - No cross-cloud dependencies
✅ **Native Integration** - Use each cloud's best-in-class tools
✅ **Failure Isolation** - AWS down doesn't affect GCP/Azure
✅ **Cost Optimization** - Each cloud's storage is cheapest in its own region
✅ **No BigQuery Lock-in** - Not dependent on single vendor

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      UNIFIED GRAFANA LAYER                       │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                   Grafana Dashboard                         │ │
│  │                                                              │ │
│  │  Data Sources (3 separate):                                │ │
│  │  • BigQuery Data Source (GCP)                              │ │
│  │  • Redshift Data Source (AWS)                              │ │
│  │  • Azure SQL Data Source (Azure)                           │ │
│  └────────┬─────────────┬──────────────┬─────────────────────┘ │
│           │             │              │                         │
└───────────┼─────────────┼──────────────┼─────────────────────────┘
            │             │              │
            │ SQL Query   │ SQL Query    │ SQL Query
            ▼             ▼              ▼
┌────────────────┐  ┌────────────────┐  ┌────────────────┐
│ GCP            │  │ AWS            │  │ AZURE          │
│ ENVIRONMENT    │  │ ENVIRONMENT    │  │ ENVIRONMENT    │
├────────────────┤  ├────────────────┤  ├────────────────┤
│                │  │                │  │                │
│  BigQuery      │  │  Redshift      │  │  Azure SQL DB  │
│  Dataset:      │  │  Database:     │  │  or Synapse    │
│  gcp_llm_costs │  │  aws_llm_costs │  │  azure_llm_costs│
│                │  │                │  │                │
│  ↑             │  │  ↑             │  │  ↑             │
│  │             │  │  │             │  │  │             │
│  Native        │  │  ETL Pipeline  │  │  ETL Pipeline  │
│  Billing       │  │  (Lambda)      │  │  (Function App)│
│  Export        │  │  ↑             │  │  ↑             │
│                │  │  │             │  │  │             │
│                │  │  Cost Explorer │  │  Cost Mgmt API │
│                │  │  → S3 Export   │  │                │
│                │  │                │  │                │
└────────────────┘  └────────────────┘  └────────────────┘
```

**Key Benefit:** Each cloud environment is completely independent. If AWS is down, GCP and Azure data/dashboards still work perfectly.

---

## GCP Environment (No Changes)

### Architecture

```
GCP Billing Export (Automatic)
         ↓
BigQuery Dataset: gcp_llm_costs
         ↓
Grafana BigQuery Data Source
```

### Setup

**1. Enable Billing Export (Built-in)**

```bash
# BigQuery export is automatic
# Just verify it's enabled in billing settings
```

**2. BigQuery Schema**

```sql
-- GCP billing export creates this automatically
-- No schema creation needed!

-- Query example
SELECT 
  usage_start_time as timestamp,
  service.description as service,
  sku.description as model,
  SUM(cost) as cost_usd,
  SUM(usage.amount) as usage_amount
FROM `project-id.billing_dataset.gcp_billing_export_v1_*`
WHERE service.description IN ('Vertex AI', 'Cloud AI Platform')
  AND DATE(_TABLE_SUFFIX) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY timestamp, service, sku.description
```

### Grafana Configuration

```yaml
# grafana/provisioning/datasources/gcp.yml
apiVersion: 1

datasources:
  - name: GCP Costs (BigQuery)
    type: doitintl-bigquery-datasource
    access: proxy
    jsonData:
      authenticationType: gce  # or jwt for service account
      defaultProject: your-gcp-project
      defaultDataset: billing_dataset
    isDefault: false
```

**Monthly Cost:** ~$2-5 (BigQuery storage + queries)

---

## AWS Environment (Native Redshift)

### Architecture

```
AWS Cost Explorer
         ↓
S3 Export (Daily)
         ↓
Lambda ETL → Redshift
         ↓
Grafana Redshift Data Source
```

### Setup

**1. Enable Cost Explorer S3 Export**

```bash
# Via AWS Console or CLI
aws ce put-report-definition \
  --report-definition \
  ReportName=llm-cost-report \
  S3Bucket=aws-llm-cost-exports \
  S3Prefix=cost-data \
  S3Region=us-east-1 \
  TimeUnit=DAILY \
  Format=Parquet \
  Compression=Parquet \
  AdditionalSchemaElements=RESOURCES

# This exports daily cost data to S3
```

**2. Create Redshift Cluster**

```bash
aws redshift create-cluster \
  --cluster-identifier llm-costs-cluster \
  --node-type dc2.large \
  --number-of-nodes 2 \
  --master-username admin \
  --master-user-password YourPassword123 \
  --cluster-subnet-group-name default
```

**3. Redshift Schema**

```sql
-- Create schema for LLM costs
CREATE SCHEMA llm_costs;

-- Create table matching your data model
CREATE TABLE llm_costs.consumption (
  timestamp TIMESTAMP NOT NULL,
  cloud_provider VARCHAR(10) DEFAULT 'AWS',
  service VARCHAR(50),
  model VARCHAR(50),
  operation VARCHAR(20),
  
  input_tokens BIGINT,
  output_tokens BIGINT,
  total_tokens BIGINT,
  request_count INT,
  
  cost_usd DECIMAL(10,4),
  cost_per_1k_tokens DECIMAL(10,6),
  
  customer_id VARCHAR(100),
  project_id VARCHAR(100),
  region VARCHAR(50),
  
  PRIMARY KEY (timestamp, model, customer_id)
)
DISTSTYLE KEY
DISTKEY (customer_id)
SORTKEY (timestamp);
```

**4. Lambda ETL Pipeline**

```python
import boto3
import psycopg2
import json
from datetime import datetime, timedelta

def lambda_handler(event, context):
    """
    Lambda function to ETL from Cost Explorer to Redshift
    Triggered daily by EventBridge
    """
    
    # 1. Query Cost Explorer
    ce = boto3.client('ce')
    
    end_date = datetime.now().date()
    start_date = end_date - timedelta(days=1)
    
    response = ce.get_cost_and_usage(
        TimePeriod={
            'Start': start_date.isoformat(),
            'End': end_date.isoformat()
        },
        Granularity='HOURLY',
        Filter={
            'Dimensions': {
                'Key': 'SERVICE',
                'Values': ['Amazon Bedrock', 'Amazon SageMaker']
            }
        },
        Metrics=['UsageQuantity', 'BlendedCost'],
        GroupBy=[
            {'Type': 'DIMENSION', 'Key': 'USAGE_TYPE'},
            {'Type': 'TAG', 'Key': 'Model'},
            {'Type': 'TAG', 'Key': 'CustomerId'}
        ]
    )
    
    # 2. Connect to Redshift
    conn = psycopg2.connect(
        host=os.environ['REDSHIFT_HOST'],
        port=5439,
        dbname='llm_costs',
        user=os.environ['REDSHIFT_USER'],
        password=os.environ['REDSHIFT_PASSWORD']
    )
    cur = conn.cursor()
    
    # 3. Parse and insert data
    for result in response['ResultsByTime']:
        timestamp = result['TimePeriod']['Start']
        
        for group in result['Groups']:
            usage_type = group['Keys'][0]
            model = extract_model(group['Keys'][1]) if len(group['Keys']) > 1 else 'unknown'
            customer_id = group['Keys'][2] if len(group['Keys']) > 2 else None
            
            usage = float(group['Metrics']['UsageQuantity']['Amount'])
            cost = float(group['Metrics']['BlendedCost']['Amount'])
            
            # Infer tokens from usage (Bedrock specific)
            tokens = usage * 1000 if 'Bedrock' in usage_type else 0
            
            cur.execute("""
                INSERT INTO llm_costs.consumption 
                (timestamp, cloud_provider, service, model, total_tokens, 
                 cost_usd, customer_id, request_count)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                timestamp, 'AWS', 
                'Bedrock' if 'Bedrock' in usage_type else 'SageMaker',
                model, tokens, cost, customer_id, 1
            ))
    
    conn.commit()
    cur.close()
    conn.close()
    
    return {
        'statusCode': 200,
        'body': json.dumps('ETL completed successfully')
    }

def extract_model(usage_type):
    """Extract model name from usage type"""
    if 'Claude' in usage_type:
        return 'claude-v2'
    elif 'Titan' in usage_type:
        return 'titan'
    return 'unknown'
```

**5. Grafana Configuration**

```yaml
# grafana/provisioning/datasources/aws.yml
apiVersion: 1

datasources:
  - name: AWS Costs (Redshift)
    type: postgres  # Redshift uses PostgreSQL driver
    access: proxy
    url: llm-costs-cluster.xxxxx.us-east-1.redshift.amazonaws.com:5439
    database: llm_costs
    user: admin
    secureJsonData:
      password: YourPassword123
    jsonData:
      sslmode: require
      postgresVersion: 1000  # Redshift version
    isDefault: false
```

**Monthly Cost:** ~$50-80 (Redshift dc2.large × 2 nodes)

---

## Azure Environment (Native Azure SQL)

### Architecture

```
Azure Cost Management API
         ↓
Function App (ETL)
         ↓
Azure SQL Database
         ↓
Grafana MS SQL Data Source
```

### Setup

**1. Create Azure SQL Database**

```bash
# Create resource group
az group create \
  --name llm-costs-rg \
  --location eastus

# Create SQL server
az sql server create \
  --name llm-costs-server \
  --resource-group llm-costs-rg \
  --location eastus \
  --admin-user sqladmin \
  --admin-password YourPassword123!

# Create database
az sql db create \
  --resource-group llm-costs-rg \
  --server llm-costs-server \
  --name llm_costs \
  --service-objective S0  # Standard tier
```

**2. SQL Schema**

```sql
-- Create table for LLM costs
CREATE TABLE llm_consumption (
  timestamp DATETIME2 NOT NULL,
  cloud_provider VARCHAR(10) DEFAULT 'Azure',
  service VARCHAR(50),
  model VARCHAR(50),
  operation VARCHAR(20),
  
  input_tokens BIGINT,
  output_tokens BIGINT,
  total_tokens BIGINT,
  request_count INT,
  
  cost_usd DECIMAL(10,4),
  cost_per_1k_tokens DECIMAL(10,6),
  
  customer_id VARCHAR(100),
  project_id VARCHAR(100),
  region VARCHAR(50),
  
  CONSTRAINT PK_llm_consumption PRIMARY KEY CLUSTERED 
  (timestamp, model, customer_id)
);

-- Create indexes
CREATE NONCLUSTERED INDEX IX_customer 
ON llm_consumption(customer_id, timestamp DESC);

CREATE NONCLUSTERED INDEX IX_model 
ON llm_consumption(model, timestamp DESC);
```

**3. Function App ETL**

```python
import azure.functions as func
import pyodbc
import os
from azure.mgmt.costmanagement import CostManagementClient
from azure.identity import DefaultAzureCredential
from datetime import datetime, timedelta

def main(mytimer: func.TimerRequest) -> None:
    """
    Azure Function triggered daily to ETL cost data
    """
    
    # 1. Query Azure Cost Management
    credential = DefaultAzureCredential()
    cost_client = CostManagementClient(credential)
    
    scope = f"/subscriptions/{os.environ['AZURE_SUBSCRIPTION_ID']}"
    
    end_date = datetime.now().date()
    start_date = end_date - timedelta(days=1)
    
    query = {
        "type": "Usage",
        "timeframe": "Custom",
        "timePeriod": {
            "from": start_date.isoformat(),
            "to": end_date.isoformat()
        },
        "dataset": {
            "granularity": "Daily",
            "aggregation": {
                "totalCost": {"name": "Cost", "function": "Sum"},
                "totalUsage": {"name": "UsageQuantity", "function": "Sum"}
            },
            "grouping": [
                {"type": "Dimension", "name": "ServiceName"},
                {"type": "Dimension", "name": "MeterCategory"},
                {"type": "Tag", "name": "Model"},
                {"type": "Tag", "name": "CustomerId"}
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
    
    result = cost_client.query.usage(scope, query)
    
    # 2. Connect to Azure SQL
    conn_str = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={os.environ['SQL_SERVER']}.database.windows.net;"
        f"DATABASE=llm_costs;"
        f"UID={os.environ['SQL_USER']};"
        f"PWD={os.environ['SQL_PASSWORD']}"
    )
    
    conn = pyodbc.connect(conn_str)
    cursor = conn.cursor()
    
    # 3. Insert data
    for row in result.rows:
        timestamp = row[0]  # Date column
        service = row[1]
        meter_category = row[2]
        model = extract_model(meter_category, row[3] if len(row) > 3 else None)
        customer_id = row[4] if len(row) > 4 else None
        usage = float(row[-2])
        cost = float(row[-1])
        
        # Infer tokens from usage
        tokens = usage * 1000  # Azure OpenAI usage in thousands
        
        cursor.execute("""
            INSERT INTO llm_consumption 
            (timestamp, cloud_provider, service, model, total_tokens, 
             cost_usd, customer_id, request_count)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            timestamp, 'Azure', service, model, 
            tokens, cost, customer_id, 1
        ))
    
    conn.commit()
    cursor.close()
    conn.close()
    
    return

def extract_model(meter_category, tag_model):
    """Extract model name"""
    if tag_model:
        return tag_model
    if 'GPT-4' in meter_category:
        return 'gpt-4'
    elif 'GPT-3.5' in meter_category:
        return 'gpt-35-turbo'
    return 'unknown'
```

**4. Grafana Configuration**

```yaml
# grafana/provisioning/datasources/azure.yml
apiVersion: 1

datasources:
  - name: Azure Costs (SQL)
    type: mssql  # Microsoft SQL Server
    access: proxy
    url: llm-costs-server.database.windows.net:1433
    database: llm_costs
    user: sqladmin
    secureJsonData:
      password: YourPassword123!
    jsonData:
      sslmode: require
      encrypt: true
    isDefault: false
```

**Monthly Cost:** ~$15-30 (Azure SQL S0 tier)

---

## Unified Grafana Dashboard

### Multi-Cloud Query Strategy

**Dashboard with 3 Data Sources:**

```json
{
  "panels": [
    {
      "title": "Total Cost Across All Clouds",
      "targets": [
        {
          "datasource": "GCP Costs (BigQuery)",
          "rawSql": "SELECT SUM(cost) as gcp_cost FROM `project.billing.gcp_billing_export_v1_*` WHERE service.description LIKE '%AI%' AND DATE(_TABLE_SUFFIX) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)"
        },
        {
          "datasource": "AWS Costs (Redshift)",
          "rawSql": "SELECT SUM(cost_usd) as aws_cost FROM llm_costs.consumption WHERE timestamp >= CURRENT_DATE - 30"
        },
        {
          "datasource": "Azure Costs (SQL)",
          "rawSql": "SELECT SUM(cost_usd) as azure_cost FROM llm_consumption WHERE timestamp >= DATEADD(day, -30, GETDATE())"
        }
      ],
      "type": "stat"
    }
  ]
}
```

### Cross-Cloud Comparison Panel

Since you can't JOIN across data sources, use **transformations**:

```json
{
  "title": "Cost by Cloud Provider",
  "targets": [
    {
      "refId": "GCP",
      "datasource": "GCP Costs (BigQuery)",
      "rawSql": "SELECT 'GCP' as cloud, SUM(cost) as total FROM `project.billing.gcp_billing_export_v1_*` WHERE DATE(_TABLE_SUFFIX) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)"
    },
    {
      "refId": "AWS",
      "datasource": "AWS Costs (Redshift)",
      "rawSql": "SELECT 'AWS' as cloud, SUM(cost_usd) as total FROM llm_costs.consumption WHERE timestamp >= CURRENT_DATE - 30"
    },
    {
      "refId": "Azure",
      "datasource": "Azure Costs (SQL)",
      "rawSql": "SELECT 'Azure' as cloud, SUM(cost_usd) as total FROM llm_consumption WHERE timestamp >= DATEADD(day, -30, GETDATE())"
    }
  ],
  "transformations": [
    {
      "id": "merge"
    }
  ],
  "type": "piechart"
}
```

---

## Cost Comparison

### Option A: All-in-BigQuery (Previous Recommendation)

| Component | Monthly Cost |
|-----------|--------------|
| BigQuery (all clouds) | $5-10 |
| ETL (AWS/Azure → BigQuery) | $10-15 |
| Grafana | $15-25 |
| **TOTAL** | **$30-50** |

**Cons:** GCP lock-in, all eggs in one basket

---

### Option B: Cloud-Native Warehouses (NEW - Recommended!)

| Component | Monthly Cost |
|-----------|--------------|
| BigQuery (GCP only) | $2-5 |
| Redshift (AWS) | $50-80 |
| Azure SQL (Azure) | $15-30 |
| ETL Functions | $10-15 |
| Grafana | $15-25 |
| **TOTAL** | **$92-155** |

**Pros:** 
- ✅ True cloud independence
- ✅ No single point of failure
- ✅ Each cloud optimized
- ✅ Better for enterprise customers

**Cons:**
- ⚠️ Higher cost ($92-155 vs $30-50)
- ⚠️ More complex (3 data sources vs 1)

---

## Decision Matrix

### Choose **All-in-BigQuery** if:

✅ Minimizing cost is critical ($30-50/mo)
✅ MVP/startup phase
✅ Okay with GCP dependency
✅ Single data source simplicity preferred
✅ Most customers use GCP primarily

---

### Choose **Cloud-Native Warehouses** if:

✅ True cloud independence required
✅ Enterprise customers demand it
✅ Want AWS Redshift analytics capabilities
✅ Budget allows $92-155/month
✅ Multi-cloud is core differentiator
✅ Failure isolation is important

---

## Hybrid Recommendation

**Start with BigQuery (Phase 1):**
- All clouds → BigQuery
- Cost: $30-50/month
- Fast MVP (2-3 weeks)

**Migrate to Native (Phase 2) when:**
- You have 20+ customers
- Enterprise deals require cloud independence
- Revenue supports $150-200/month infrastructure

**Migration is easy:**
1. Deploy Redshift + Azure SQL
2. Add Grafana data sources
3. Duplicate panels with new queries
4. Switch customers gradually
5. Deprecate BigQuery ETL

---

## Grafana Configuration Summary

```yaml
# Complete datasources configuration
apiVersion: 1

datasources:
  # GCP
  - name: GCP-BigQuery
    type: doitintl-bigquery-datasource
    access: proxy
    jsonData:
      defaultProject: your-gcp-project
  
  # AWS
  - name: AWS-Redshift
    type: postgres
    access: proxy
    url: cluster.region.redshift.amazonaws.com:5439
    database: llm_costs
    user: admin
    secureJsonData:
      password: ${REDSHIFT_PASSWORD}
  
  # Azure
  - name: Azure-SQL
    type: mssql
    access: proxy
    url: server.database.windows.net:1433
    database: llm_costs
    user: sqladmin
    secureJsonData:
      password: ${AZURE_SQL_PASSWORD}
```

---

## Final Recommendation for Your SMB Product

**Phase 1 (MVP):** All-in-BigQuery
- Cost: $30-50/month
- Time: 2-3 weeks
- Good enough for first 20 customers

**Phase 2 (Scale):** Migrate to Cloud-Native
- Cost: $92-155/month
- When: 20+ customers, enterprise deals
- Benefit: True independence, better positioning

The $62-105/month increase is **tiny** compared to the customer value ($30K-$47K/month savings), but gives you much better enterprise positioning.

---

**Document End**
