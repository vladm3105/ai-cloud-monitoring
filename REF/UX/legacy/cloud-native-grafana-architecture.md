# Cloud-Native Grafana Architecture
## Independent Cloud Environments with Native Databases

**Document Version:** 1.0  
**Last Updated:** February 2026  
**Architecture Pattern:** Fully Independent Cloud Environments

---

## Executive Summary

**Each cloud environment is completely independent** with its own native database that Grafana can query directly:

- **GCP:** Billing Export → BigQuery → Grafana
- **AWS:** Cost & Usage Reports → S3 → Redshift → Grafana
- **Azure:** Cost Management API → Azure SQL Database → Grafana

**No shared infrastructure. No cross-cloud dependencies. True multi-cloud independence.**

---

## Complete Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    UNIFIED GRAFANA DASHBOARD                     │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                                                             │ │
│  │  Data Sources (3 independent connections):                 │ │
│  │  • BigQuery (GCP)                                          │ │
│  │  • Redshift (AWS)                                          │ │
│  │  • Azure SQL Database (Azure)                              │ │
│  │                                                             │ │
│  │  Dashboards:                                                │ │
│  │  • Multi-cloud cost overview (unions 3 sources)            │ │
│  │  • Per-cloud deep dive (single source)                     │ │
│  │  • Cross-cloud model comparison                            │ │
│  └────────┬──────────────┬──────────────┬────────────────────┘ │
│           │              │              │                        │
└───────────┼──────────────┼──────────────┼────────────────────────┘
            │              │              │
            │              │              │
            ▼              ▼              ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│               │  │               │  │               │
│ GCP BigQuery  │  │ AWS Redshift  │  │ Azure SQL DB  │
│               │  │               │  │               │
└───────┬───────┘  └───────┬───────┘  └───────┬───────┘
        │                  │                  │
        ▼                  ▼                  ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│ GCP Billing   │  │ AWS Cost &    │  │ Azure Cost    │
│ Export        │  │ Usage Reports │  │ Management API│
│ (Automatic)   │  │ (S3 → Redshift│  │ (Azure SQL)   │
└───────────────┘  └───────────────┘  └───────────────┘
```

---

## GCP Environment (Native BigQuery)

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GCP ENVIRONMENT                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                  BigQuery                               │ │
│  │                                                          │ │
│  │  Dataset: gcp_billing                                   │ │
│  │  Table: gcp_billing_export_v1_XXXXXX                    │ │
│  │                                                          │ │
│  │  Schema:                                                 │ │
│  │  • billing_account_id                                   │ │
│  │  • service.description (e.g., "Vertex AI API")         │ │
│  │  • sku.description (e.g., "Gemini Pro input")          │ │
│  │  • usage_start_time, usage_end_time                    │ │
│  │  • cost, currency                                       │ │
│  │  • usage.amount, usage.unit                             │ │
│  │  • labels (for customer_id tagging)                     │ │
│  └────────────────────────────────────────────────────────┘ │
│                              ▲                               │
│                              │                               │
│  ┌───────────────────────────┴──────────────────────────┐  │
│  │          GCP Billing Export (Automatic)              │  │
│  │                                                       │  │
│  │  • Configured in GCP Console                         │  │
│  │  • Exports daily to BigQuery                         │  │
│  │  • No ETL needed - native integration                │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                              │
│  Infrastructure: GCP Project                                │
│  Cost: $2-5/month (BigQuery storage + queries)             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Setup

**1. Enable Billing Export to BigQuery:**

```bash
# In GCP Console:
# Billing → Billing Export → BigQuery Export
# ✓ Enable detailed usage cost data
# ✓ Enable pricing data

# Or via gcloud:
gcloud billing accounts export-configs create \
  --billing-account=XXXXXX-XXXXXX-XXXXXX \
  --dataset=gcp_billing \
  --project=your-project-id
```

**2. Query Structure for LLM Costs:**

```sql
-- View for LLM costs
CREATE VIEW `project.gcp_billing.llm_costs` AS
SELECT
  DATE(usage_start_time) as date,
  'GCP' as cloud_provider,
  service.description as service,
  sku.description as sku,
  REGEXP_EXTRACT(sku.description, r'(Gemini|PaLM|Claude)') as model,
  CASE 
    WHEN sku.description LIKE '%input%' THEN 'input'
    WHEN sku.description LIKE '%output%' THEN 'output'
    ELSE 'other'
  END as token_type,
  SUM(usage.amount) as usage_amount,
  usage.unit as usage_unit,
  SUM(cost) as cost_usd,
  (SELECT value FROM UNNEST(labels) WHERE key = 'customer_id') as customer_id
FROM `project.billing_export.gcp_billing_export_v1_*`
WHERE 
  DATE(_TABLE_SUFFIX) >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
  AND service.description IN (
    'Vertex AI API',
    'Cloud AI Platform',
    'Document AI',
    'Vision AI'
  )
GROUP BY date, service, sku, model, token_type, usage_unit, customer_id
```

**3. Grafana Data Source:**

```yaml
# grafana/datasources/bigquery.yml
apiVersion: 1

datasources:
  - name: GCP BigQuery
    type: doitintl-bigquery-datasource
    access: proxy
    jsonData:
      authenticationType: gce
      defaultProject: your-gcp-project
      defaultDataset: gcp_billing
```

---

## AWS Environment (Redshift)

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS ENVIRONMENT                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Amazon Redshift                            │ │
│  │                                                          │ │
│  │  Database: aws_costs                                    │ │
│  │  Schema: llm_costs                                      │ │
│  │  Table: cost_usage_report                               │ │
│  │                                                          │ │
│  │  Columns:                                                │ │
│  │  • line_item_usage_start_date                           │ │
│  │  • line_item_product_code (e.g., "AmazonBedrock")      │ │
│  │  • line_item_operation (e.g., "RunInference")          │ │
│  │  • line_item_usage_type                                 │ │
│  │  • line_item_blended_cost                               │ │
│  │  • line_item_usage_amount                               │ │
│  │  • resource_tags_user_customer_id                       │ │
│  └────────────────┬───────────────────────────────────────┘ │
│                   │                                          │
│                   ▲                                          │
│  ┌────────────────┴───────────────────────────────────────┐ │
│  │           AWS Cost & Usage Reports (CUR)               │ │
│  │                                                         │ │
│  │  Flow:                                                  │ │
│  │  1. CUR → S3 bucket (hourly/daily)                    │ │
│  │  2. Redshift COPY command (scheduled)                  │ │
│  │  3. OR use AWS Data Pipeline                           │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  Infrastructure: AWS Account                                │
│  Cost: $50-100/month (Redshift dc2.large)                  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Setup

**1. Enable Cost & Usage Reports:**

```bash
# Via AWS Console:
# Billing → Cost & Usage Reports → Create report
# ✓ Include resource IDs
# ✓ Enable data integration for Redshift
# ✓ Time granularity: Hourly
# ✓ Compression: GZIP
# S3 bucket: s3://aws-cur-reports-{account-id}/

# Via AWS CLI:
aws cur put-report-definition \
  --region us-east-1 \
  --report-definition \
    ReportName=llm-cost-report,\
    TimeUnit=HOURLY,\
    Format=Parquet,\
    Compression=Parquet,\
    S3Bucket=aws-cur-reports-{account-id},\
    S3Prefix=cur-reports,\
    S3Region=us-east-1,\
    AdditionalSchemaElements=RESOURCES
```

**2. Create Redshift Cluster:**

```bash
aws redshift create-cluster \
  --cluster-identifier llm-costs-cluster \
  --node-type dc2.large \
  --number-of-nodes 1 \
  --master-username admin \
  --master-user-password YourPassword123 \
  --db-name aws_costs \
  --cluster-subnet-group-name default \
  --publicly-accessible
```

**3. Load CUR Data into Redshift:**

**Option A: AWS Data Pipeline (Automated)**

```json
{
  "objects": [
    {
      "id": "CUR_to_Redshift",
      "name": "Load CUR to Redshift",
      "type": "CopyActivity",
      "schedule": {"ref": "DailySchedule"},
      "input": {"ref": "S3_CUR_Data"},
      "output": {"ref": "Redshift_Table"}
    },
    {
      "id": "S3_CUR_Data",
      "type": "S3DataNode",
      "filePath": "s3://aws-cur-reports-{account}/cur-reports/"
    },
    {
      "id": "Redshift_Table",
      "type": "RedshiftDataNode",
      "database": {"ref": "Redshift_Database"},
      "tableName": "cost_usage_report"
    }
  ]
}
```

**Option B: Lambda + Redshift COPY (Custom)**

```python
# lambda_function.py
import boto3
import psycopg2

def lambda_handler(event, context):
    """
    Triggered when new CUR file arrives in S3
    Loads data into Redshift using COPY command
    """
    s3_path = event['Records'][0]['s3']['object']['key']
    
    # Connect to Redshift
    conn = psycopg2.connect(
        host='llm-costs-cluster.xxxxxx.us-east-1.redshift.amazonaws.com',
        port=5439,
        dbname='aws_costs',
        user='admin',
        password='YourPassword123'
    )
    cur = conn.cursor()
    
    # COPY command to load from S3
    copy_command = f"""
    COPY cost_usage_report
    FROM 's3://aws-cur-reports-{account}/{s3_path}'
    IAM_ROLE 'arn:aws:iam::{account}:role/RedshiftCopyRole'
    FORMAT AS PARQUET;
    """
    
    cur.execute(copy_command)
    conn.commit()
    
    return {'statusCode': 200}
```

**4. Create LLM Costs View:**

```sql
-- Redshift view for LLM costs
CREATE VIEW llm_costs AS
SELECT
  DATE(line_item_usage_start_date) as date,
  'AWS' as cloud_provider,
  line_item_product_code as service,
  CASE 
    WHEN line_item_product_code = 'AmazonBedrock' THEN
      SPLIT_PART(line_item_usage_type, ':', 2)
    ELSE 'unknown'
  END as model,
  line_item_usage_amount as usage_amount,
  line_item_blended_cost as cost_usd,
  resource_tags_user_customer_id as customer_id
FROM cost_usage_report
WHERE line_item_product_code IN ('AmazonBedrock', 'AmazonSageMaker')
  AND line_item_usage_start_date >= DATEADD(day, -90, CURRENT_DATE);
```

**5. Grafana Data Source:**

```yaml
# grafana/datasources/redshift.yml
apiVersion: 1

datasources:
  - name: AWS Redshift
    type: postgres
    access: proxy
    url: llm-costs-cluster.xxxxxx.us-east-1.redshift.amazonaws.com:5439
    database: aws_costs
    user: admin
    secureJsonData:
      password: YourPassword123
    jsonData:
      sslmode: require
      postgresVersion: 903
```

---

## Azure Environment (Azure SQL Database)

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   AZURE ENVIRONMENT                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │            Azure SQL Database                           │ │
│  │                                                          │ │
│  │  Database: azure_costs                                  │ │
│  │  Schema: dbo                                            │ │
│  │  Table: llm_costs                                       │ │
│  │                                                          │ │
│  │  Columns:                                                │ │
│  │  • date DATE                                            │ │
│  │  • subscription_id VARCHAR(100)                         │ │
│  │  • resource_group VARCHAR(100)                          │ │
│  │  • service_name VARCHAR(100)                            │ │
│  │  • meter_category VARCHAR(100)                          │ │
│  │  • meter_name VARCHAR(200)                              │ │
│  │  • cost_usd DECIMAL(10,4)                               │ │
│  │  • quantity DECIMAL(20,4)                               │ │
│  │  • customer_id VARCHAR(100)                             │ │
│  └────────────────┬───────────────────────────────────────┘ │
│                   │                                          │
│                   ▲                                          │
│  ┌────────────────┴───────────────────────────────────────┐ │
│  │      Azure Function (Cost Management API ETL)          │ │
│  │                                                         │ │
│  │  Trigger: Timer (daily at 2 AM UTC)                   │ │
│  │                                                         │ │
│  │  Flow:                                                  │ │
│  │  1. Query Cost Management API                          │ │
│  │  2. Filter for Azure OpenAI, Cognitive Services        │ │
│  │  3. Transform to schema                                 │ │
│  │  4. Bulk insert to Azure SQL Database                  │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  Infrastructure: Azure Subscription                         │
│  Cost: $30-60/month (Azure SQL Basic + Function App)       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Setup

**1. Create Azure SQL Database:**

```bash
# Create SQL Server
az sql server create \
  --name llm-costs-sql-server \
  --resource-group ai-cost-monitoring \
  --location eastus \
  --admin-user sqladmin \
  --admin-password YourPassword123!

# Create Database
az sql db create \
  --resource-group ai-cost-monitoring \
  --server llm-costs-sql-server \
  --name azure_costs \
  --service-objective Basic \
  --max-size 2GB

# Configure firewall
az sql server firewall-rule create \
  --resource-group ai-cost-monitoring \
  --server llm-costs-sql-server \
  --name AllowGrafana \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 255.255.255.255
```

**2. Create Table Schema:**

```sql
-- Connect via Azure portal or sqlcmd
CREATE TABLE llm_costs (
    id INT IDENTITY(1,1) PRIMARY KEY,
    date DATE NOT NULL,
    cloud_provider VARCHAR(10) DEFAULT 'Azure',
    subscription_id VARCHAR(100),
    resource_group VARCHAR(100),
    service_name VARCHAR(100),
    meter_category VARCHAR(100),
    meter_name VARCHAR(200),
    model VARCHAR(50),
    cost_usd DECIMAL(10,4),
    quantity DECIMAL(20,4),
    unit VARCHAR(50),
    customer_id VARCHAR(100),
    created_at DATETIME DEFAULT GETDATE()
);

CREATE INDEX idx_date ON llm_costs(date);
CREATE INDEX idx_customer ON llm_costs(customer_id, date);
CREATE INDEX idx_service ON llm_costs(service_name, date);
```

**3. Azure Function for ETL:**

```python
# function_app.py
import azure.functions as func
import pyodbc
from azure.identity import DefaultAzureCredential
from azure.mgmt.costmanagement import CostManagementClient
from datetime import datetime, timedelta

app = func.FunctionApp()

@app.schedule(schedule="0 0 2 * * *", arg_name="myTimer", run_on_startup=False)
def cost_etl_function(myTimer: func.TimerRequest) -> None:
    """
    Runs daily at 2 AM UTC
    Extracts Azure costs and loads into SQL Database
    """
    # Azure Cost Management Client
    credential = DefaultAzureCredential()
    cost_client = CostManagementClient(credential)
    
    # Query yesterday's costs
    yesterday = (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d')
    
    scope = f"/subscriptions/{subscription_id}"
    
    query_definition = {
        "type": "Usage",
        "timeframe": "Custom",
        "time_period": {
            "from": yesterday,
            "to": yesterday
        },
        "dataset": {
            "granularity": "Daily",
            "aggregation": {
                "totalCost": {"name": "Cost", "function": "Sum"}
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
    
    # Execute query
    result = cost_client.query.usage(scope, query_definition)
    
    # Connect to Azure SQL Database
    conn_str = (
        f"DRIVER={{ODBC Driver 18 for SQL Server}};"
        f"SERVER=llm-costs-sql-server.database.windows.net;"
        f"DATABASE=azure_costs;"
        f"UID=sqladmin;"
        f"PWD=YourPassword123!"
    )
    conn = pyodbc.connect(conn_str)
    cursor = conn.cursor()
    
    # Insert data
    for row in result.rows:
        # Extract model from meter name
        model = extract_model_from_meter(row[3])  # meter_name
        
        cursor.execute("""
            INSERT INTO llm_costs 
            (date, subscription_id, resource_group, service_name, 
             meter_category, meter_name, model, cost_usd, customer_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            yesterday,
            subscription_id,
            row[0],  # resource_group
            row[1],  # service_name
            row[2],  # meter_category
            row[3],  # meter_name
            model,
            float(row[4]),  # cost
            extract_customer_id(row[0])  # from resource group tags
        ))
    
    conn.commit()
    cursor.close()
    conn.close()

def extract_model_from_meter(meter_name: str) -> str:
    """Extract model from meter name"""
    if 'GPT-4' in meter_name:
        return 'gpt-4'
    elif 'GPT-3.5' in meter_name:
        return 'gpt-3.5-turbo'
    elif 'text-embedding' in meter_name:
        return 'text-embedding-ada-002'
    return 'unknown'

def extract_customer_id(resource_group: str) -> str:
    """Extract customer ID from resource group name or tags"""
    # Implementation depends on your tagging strategy
    return 'default'
```

**4. Deploy Azure Function:**

```bash
# Create Function App
az functionapp create \
  --resource-group ai-cost-monitoring \
  --consumption-plan-location eastus \
  --runtime python \
  --runtime-version 3.11 \
  --functions-version 4 \
  --name azure-cost-etl-func \
  --storage-account azurecostsstorage

# Deploy function
func azure functionapp publish azure-cost-etl-func
```

**5. Grafana Data Source:**

```yaml
# grafana/datasources/azure-sql.yml
apiVersion: 1

datasources:
  - name: Azure SQL Database
    type: mssql
    access: proxy
    url: llm-costs-sql-server.database.windows.net:1433
    database: azure_costs
    user: sqladmin
    secureJsonData:
      password: YourPassword123!
    jsonData:
      encrypt: true
```

---

## Unified Grafana Configuration

### Multi-Cloud Dashboard

**Dashboard JSON Structure:**

```json
{
  "dashboard": {
    "title": "Multi-Cloud LLM Costs",
    "panels": [
      {
        "id": 1,
        "title": "Total Cost by Cloud",
        "type": "piechart",
        "targets": [
          {
            "datasource": "GCP BigQuery",
            "rawSql": "SELECT 'GCP' as cloud, SUM(cost_usd) as cost FROM `project.gcp_billing.llm_costs` WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)"
          },
          {
            "datasource": "AWS Redshift",
            "rawSql": "SELECT 'AWS' as cloud, SUM(cost_usd) as cost FROM llm_costs WHERE date >= CURRENT_DATE - 30"
          },
          {
            "datasource": "Azure SQL Database",
            "rawSql": "SELECT 'Azure' as cloud, SUM(cost_usd) as cost FROM llm_costs WHERE date >= DATEADD(day, -30, GETDATE())"
          }
        ]
      }
    ]
  }
}
```

**Variables for Multi-Select:**

```json
{
  "templating": {
    "list": [
      {
        "name": "datasource",
        "type": "datasource",
        "query": "postgres,mssql,bigquery",
        "multi": true,
        "includeAll": true,
        "label": "Cloud Provider"
      }
    ]
  }
}
```

---

## Cost Comparison

### Infrastructure Costs (Monthly)

| Cloud | Database | ETL | Total/Month |
|-------|----------|-----|-------------|
| **GCP** | BigQuery: $2-5 | None (native) | $2-5 |
| **AWS** | Redshift dc2.large: $50-80 | Data Pipeline: $10-20 | $60-100 |
| **Azure** | SQL Basic: $5-10 | Function App: $5-10 | $10-20 |
| **Grafana** | Cloud Run: $15-25 | - | $15-25 |
| **TOTAL** | | | **$87-150/month** |

### Comparison with MCP Architecture

| Approach | Monthly Cost | Complexity | Independence |
|----------|--------------|------------|--------------|
| **Cloud-Native DB** | $87-150 | Low | ✅ Full |
| **MCP Servers** | $300-455 | High | ✅ Full |
| **BigQuery Only** | $32-42 | Lowest | ❌ GCP locked |

---

## Benefits of Cloud-Native Approach

✅ **True Independence** - Each cloud uses its own native database  
✅ **No Shared Infrastructure** - No single point of failure  
✅ **Grafana Native Support** - Official data source plugins  
✅ **Cost Effective** - $87-150/month vs $300-455/month (MCP)  
✅ **Familiar Technologies** - SQL databases, not custom MCP protocol  
✅ **Easy Maintenance** - Managed databases, no custom servers  
✅ **Cloud-Specific Optimization** - Use best tool per cloud  

---

## Recommendation

**For independent cloud environments, use Cloud-Native Database approach:**

1. **GCP → BigQuery** (native, $2-5/mo)
2. **AWS → Redshift** (scalable, $60-100/mo)
3. **Azure → Azure SQL** (managed, $10-20/mo)
4. **Grafana** queries all three directly ($15-25/mo)

**Total: $87-150/month**

This is:
- ✅ **65% cheaper** than MCP servers ($300-455/mo)
- ✅ **3x cheaper** than hybrid approach ($180-260/mo)
- ✅ **Truly independent** - no shared infrastructure
- ✅ **Production-ready** - uses managed cloud services
- ✅ **Simple to maintain** - SQL queries, no custom protocols

**When to add MCP servers:**
- You need real-time (15s) updates (vs daily)
- You want conversational AI features
- You need agentic workflows
- Budget supports $300-455/month

For most use cases, **Cloud-Native DB approach is the best choice**.

---

**Document End**
