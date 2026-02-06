# AI Cost Monitoring Platform - Complete Implementation Guide
## Two-Phase Architecture: Grafana + Cloud Databases

**Document Version:** FINAL v1.0  
**Last Updated:** February 2026  
**Architecture:** Simplified - No Prometheus Required

---

## Executive Summary

**Phase 1: All-in-BigQuery MVP**
- Cost: $25-35/month
- Time: 2-3 weeks
- Components: BigQuery + 2 Cloud Functions + Grafana
- Get first 20 customers

**Phase 2: Cloud-Native Independence**
- Cost: $90-150/month
- Time: 7 weeks migration
- Components: 3 Native Databases + ETL + Grafana
- Better enterprise positioning

**Key Insight:** You do NOT need Prometheus, Exporters, or TimescaleDB for cost monitoring. Simple architecture: Cloud Billing → Database → Grafana.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Phase 1: All-in-BigQuery](#phase-1-all-in-bigquery)
3. [Phase 2: Cloud-Native Independence](#phase-2-cloud-native-independence)
4. [Migration Strategy](#migration-strategy)
5. [Implementation Checklist](#implementation-checklist)

---

## Architecture Overview

### Simple Data Flow

```
Cloud Billing APIs
        ↓
   ETL Pipeline
        ↓
    Database
        ↓
Grafana (SQL Queries)
```

**That's it. No Prometheus. No complex metric exporters.**

### What You're NOT Building

❌ Prometheus (real-time metrics)  
❌ Prometheus Exporters  
❌ TimescaleDB  
❌ MCP Servers  
❌ Orchestrator Agents  

These are for real-time operational monitoring (CPU, memory, requests/sec). Your product is **cost analytics**, which needs historical billing data, not 15-second metrics.

---

## Phase 1: All-in-BigQuery

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        GRAFANA                               │
│              (Single BigQuery Data Source)                   │
│                                                              │
│  Dashboard Queries: Pure SQL                                │
│  SELECT cloud, SUM(cost) FROM unified_costs WHERE ...       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ SQL Queries
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    GOOGLE BIGQUERY                           │
│                                                              │
│  Dataset: multi_cloud_costs                                 │
│                                                              │
│  Tables:                                                     │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ gcp_llm_costs                                         │  │
│  │ • Source: GCP Billing Export (automatic)             │  │
│  │ • Update: Every 4-6 hours                             │  │
│  │ • No ETL required ✅                                  │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ aws_llm_costs                                         │  │
│  │ • Source: Cloud Function ETL                          │  │
│  │ • Update: Daily at 3 AM UTC                           │  │
│  │ • Reads: AWS Cost Explorer → S3                       │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ azure_llm_costs                                       │  │
│  │ • Source: Cloud Function ETL                          │  │
│  │ • Update: Daily at 4 AM UTC                           │  │
│  │ • Reads: Azure Cost Management API                    │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  View: unified_costs (UNION ALL of 3 tables)               │
└───────┬────────────────────┬────────────────────┬───────────┘
        │                    │                    │
        ▼                    ▼                    ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ GCP Billing  │   │ AWS Cost     │   │ Azure Cost   │
│ Export       │   │ Explorer     │   │ Mgmt API     │
│              │   │ → S3 Export  │   │              │
└──────────────┘   └──────┬───────┘   └──────┬───────┘
                          │                   │
                   ┌──────▼─────┐      ┌──────▼─────┐
                   │ Cloud      │      │ Cloud      │
                   │ Function   │      │ Function   │
                   │ (ETL)      │      │ (ETL)      │
                   │ Python 3.11│      │ Python 3.11│
                   └────────────┘      └────────────┘
```

### Component Details

#### 1. GCP → BigQuery (Native - No ETL)

**Setup (5 minutes):**

```bash
# Enable billing export in GCP Console
# Navigation: Billing → Billing Export → BigQuery Export

# Settings:
# ✓ Enable detailed usage cost data
# ✓ Enable pricing data
# Dataset: multi_cloud_costs
# Table prefix: gcp_billing_export

# Done! Data flows automatically every 4-6 hours
```

**Query GCP costs:**

```sql
-- View for GCP LLM costs
CREATE VIEW `project.multi_cloud_costs.gcp_llm_costs` AS
SELECT 
  DATE(usage_start_time) as date,
  'GCP' as cloud_provider,
  service.description as service,
  sku.description as sku_description,
  CASE
    WHEN sku.description LIKE '%Gemini%' THEN 'gemini-pro'
    WHEN sku.description LIKE '%PaLM%' THEN 'palm-2'
    WHEN sku.description LIKE '%Claude%' THEN 'claude-v2'
    ELSE 'unknown'
  END as model,
  CASE
    WHEN sku.description LIKE '%input%' THEN 'input'
    WHEN sku.description LIKE '%output%' THEN 'output'
    ELSE 'other'
  END as token_type,
  SUM(usage.amount) as usage_amount,
  usage.unit as usage_unit,
  SUM(cost) as cost_usd,
  (SELECT value FROM UNNEST(labels) WHERE key = 'customer_id') as customer_id
FROM `project.multi_cloud_costs.gcp_billing_export_v1_*`
WHERE 
  service.description IN (
    'Vertex AI API',
    'Cloud AI Platform',
    'Document AI API',
    'Vision AI'
  )
  AND DATE(_TABLE_SUFFIX) >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
GROUP BY date, cloud_provider, service, sku_description, model, token_type, usage_unit, customer_id;
```

#### 2. AWS → BigQuery (ETL Required)

**Step 1: Enable AWS Cost & Usage Reports**

```bash
# Via AWS Console:
# Billing & Cost Management → Cost & Usage Reports → Create report

# Settings:
# Report name: llm-cost-export
# Time granularity: Daily
# Include: Resource IDs
# Enable report data integration: Amazon Redshift, Amazon QuickSight
# S3 bucket: s3://aws-cost-exports-{account-id}
# Report path prefix: cost-reports/
# Compression: GZIP
# Format: text/csv

# OR via AWS CLI:
aws cur put-report-definition \
  --region us-east-1 \
  --report-definition file://cur-definition.json
```

**cur-definition.json:**
```json
{
  "ReportName": "llm-cost-export",
  "TimeUnit": "DAILY",
  "Format": "textORcsv",
  "Compression": "GZIP",
  "AdditionalSchemaElements": ["RESOURCES"],
  "S3Bucket": "aws-cost-exports-{account-id}",
  "S3Prefix": "cost-reports/",
  "S3Region": "us-east-1",
  "AdditionalArtifacts": ["REDSHIFT", "QUICKSIGHT"],
  "RefreshClosedReports": true,
  "ReportVersioning": "OVERWRITE_REPORT"
}
```

**Step 2: Cloud Function ETL**

```python
# cloud_function_aws_etl.py
"""
AWS Cost Explorer → BigQuery ETL
Triggered daily by Cloud Scheduler
"""

from google.cloud import bigquery
import boto3
import pandas as pd
from datetime import datetime, timedelta
import os

def aws_to_bigquery(event, context):
    """
    ETL pipeline: AWS Cost Explorer → BigQuery
    
    Flow:
    1. Query AWS Cost Explorer API for yesterday's costs
    2. Filter for LLM services (Bedrock, SageMaker)
    3. Transform to BigQuery schema
    4. Load into BigQuery table
    """
    
    # AWS credentials from environment variables
    ce = boto3.client(
        'ce',
        aws_access_key_id=os.environ['AWS_ACCESS_KEY_ID'],
        aws_secret_access_key=os.environ['AWS_SECRET_ACCESS_KEY'],
        region_name='us-east-1'
    )
    
    # Query yesterday's costs
    end_date = datetime.now().date()
    start_date = end_date - timedelta(days=1)
    
    print(f"Fetching AWS costs for {start_date}")
    
    # Cost Explorer query
    response = ce.get_cost_and_usage(
        TimePeriod={
            'Start': start_date.isoformat(),
            'End': end_date.isoformat()
        },
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
            {'Type': 'TAG', 'Key': 'customer_id'},
            {'Type': 'TAG', 'Key': 'project_id'}
        ]
    )
    
    # Transform to DataFrame
    rows = []
    for result in response['ResultsByTime']:
        date = result['TimePeriod']['Start']
        
        for group in result['Groups']:
            usage_type = group['Keys'][0] if len(group['Keys']) > 0 else 'unknown'
            customer_id = group['Keys'][1] if len(group['Keys']) > 1 else None
            project_id = group['Keys'][2] if len(group['Keys']) > 2 else None
            
            cost = float(group['Metrics']['BlendedCost']['Amount'])
            usage = float(group['Metrics']['UsageQuantity']['Amount'])
            
            # Extract model and service from usage_type
            model = extract_model(usage_type)
            service = 'Bedrock' if 'Bedrock' in usage_type else 'SageMaker'
            
            rows.append({
                'date': date,
                'cloud_provider': 'AWS',
                'service': service,
                'sku_description': usage_type,
                'model': model,
                'token_type': extract_token_type(usage_type),
                'usage_amount': usage,
                'usage_unit': 'tokens' if 'Bedrock' in usage_type else 'compute_hours',
                'cost_usd': cost,
                'customer_id': customer_id,
                'project_id': project_id
            })
    
    if not rows:
        print("No AWS cost data found")
        return {'status': 'no_data'}
    
    df = pd.DataFrame(rows)
    print(f"Found {len(df)} cost records")
    
    # Load to BigQuery
    client = bigquery.Client()
    table_id = 'project-id.multi_cloud_costs.aws_llm_costs'
    
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        schema=[
            bigquery.SchemaField('date', 'DATE'),
            bigquery.SchemaField('cloud_provider', 'STRING'),
            bigquery.SchemaField('service', 'STRING'),
            bigquery.SchemaField('sku_description', 'STRING'),
            bigquery.SchemaField('model', 'STRING'),
            bigquery.SchemaField('token_type', 'STRING'),
            bigquery.SchemaField('usage_amount', 'FLOAT64'),
            bigquery.SchemaField('usage_unit', 'STRING'),
            bigquery.SchemaField('cost_usd', 'FLOAT64'),
            bigquery.SchemaField('customer_id', 'STRING'),
            bigquery.SchemaField('project_id', 'STRING'),
        ]
    )
    
    job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
    job.result()  # Wait for completion
    
    print(f"Successfully loaded {len(df)} rows to BigQuery")
    
    return {
        'status': 'success',
        'rows_loaded': len(df),
        'date': start_date.isoformat()
    }

def extract_model(usage_type):
    """Extract model name from AWS usage type"""
    usage_type_lower = usage_type.lower()
    
    if 'claude' in usage_type_lower:
        if 'claude-3' in usage_type_lower:
            return 'claude-3-opus' if 'opus' in usage_type_lower else 'claude-3-sonnet'
        return 'claude-v2'
    elif 'titan' in usage_type_lower:
        return 'titan-text' if 'text' in usage_type_lower else 'titan-embeddings'
    elif 'jurassic' in usage_type_lower:
        return 'jurassic-2'
    elif 'llama' in usage_type_lower:
        return 'llama-2'
    
    return 'unknown'

def extract_token_type(usage_type):
    """Determine if input or output tokens"""
    usage_type_lower = usage_type.lower()
    
    if 'input' in usage_type_lower:
        return 'input'
    elif 'output' in usage_type_lower:
        return 'output'
    
    return 'other'
```

**requirements.txt:**
```
google-cloud-bigquery==3.13.0
boto3==1.34.0
pandas==2.1.4
db-dtypes==1.1.1
```

**Deploy Cloud Function:**

```bash
# Deploy function
gcloud functions deploy aws-to-bigquery \
  --gen2 \
  --runtime python311 \
  --region us-central1 \
  --source . \
  --entry-point aws_to_bigquery \
  --trigger-topic aws-cost-etl \
  --memory 512MB \
  --timeout 540s \
  --set-env-vars \
    AWS_ACCESS_KEY_ID=AKIA...,\
    AWS_SECRET_ACCESS_KEY=xxxxx

# Create Cloud Scheduler job (daily at 3 AM UTC)
gcloud scheduler jobs create pubsub aws-daily-etl \
  --location us-central1 \
  --schedule "0 3 * * *" \
  --topic aws-cost-etl \
  --message-body '{"run":"daily"}' \
  --time-zone "UTC"
```

#### 3. Azure → BigQuery (ETL Required)

**Step 1: Azure Service Principal Setup**

```bash
# Create service principal for Cost Management API
az ad sp create-for-rbac \
  --name llm-cost-monitor \
  --role "Cost Management Reader" \
  --scopes /subscriptions/{subscription-id}

# Output:
# {
#   "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
#   "displayName": "llm-cost-monitor",
#   "password": "xxxxxxxxxxxxxxxxxxxxx",
#   "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
# }

# Save these values for Cloud Function
```

**Step 2: Cloud Function ETL**

```python
# cloud_function_azure_etl.py
"""
Azure Cost Management API → BigQuery ETL
Triggered daily by Cloud Scheduler
"""

from google.cloud import bigquery
from azure.identity import ClientSecretCredential
from azure.mgmt.costmanagement import CostManagementClient
import pandas as pd
from datetime import datetime, timedelta
import os

def azure_to_bigquery(event, context):
    """
    ETL pipeline: Azure Cost Management → BigQuery
    
    Flow:
    1. Query Azure Cost Management API for yesterday
    2. Filter for Azure OpenAI and Cognitive Services
    3. Transform to BigQuery schema
    4. Load into BigQuery table
    """
    
    # Azure credentials
    credential = ClientSecretCredential(
        tenant_id=os.environ['AZURE_TENANT_ID'],
        client_id=os.environ['AZURE_CLIENT_ID'],
        client_secret=os.environ['AZURE_CLIENT_SECRET']
    )
    
    cost_client = CostManagementClient(credential)
    
    # Subscription scope
    subscription_id = os.environ['AZURE_SUBSCRIPTION_ID']
    scope = f"/subscriptions/{subscription_id}"
    
    # Query yesterday's costs
    end_date = datetime.now().date()
    start_date = end_date - timedelta(days=1)
    
    print(f"Fetching Azure costs for {start_date}")
    
    # Cost Management query
    query_definition = {
        "type": "Usage",
        "timeframe": "Custom",
        "timePeriod": {
            "from": start_date.isoformat(),
            "to": end_date.isoformat()
        },
        "dataset": {
            "granularity": "Daily",
            "aggregation": {
                "totalCost": {
                    "name": "Cost",
                    "function": "Sum"
                },
                "totalQuantity": {
                    "name": "UsageQuantity",
                    "function": "Sum"
                }
            },
            "grouping": [
                {"type": "Dimension", "name": "ResourceGroup"},
                {"type": "Dimension", "name": "ServiceName"},
                {"type": "Dimension", "name": "MeterCategory"},
                {"type": "Dimension", "name": "MeterName"},
                {"type": "Tag", "name": "customer_id"},
                {"type": "Tag", "name": "project_id"}
            ],
            "filter": {
                "dimensions": {
                    "name": "ServiceName",
                    "operator": "In",
                    "values": [
                        "Azure OpenAI",
                        "Cognitive Services",
                        "Azure OpenAI Service"
                    ]
                }
            }
        }
    }
    
    result = cost_client.query.usage(scope, query_definition)
    
    # Transform to DataFrame
    rows = []
    for row in result.rows:
        resource_group = row[0] if len(row) > 0 else None
        service_name = row[1] if len(row) > 1 else None
        meter_category = row[2] if len(row) > 2 else None
        meter_name = row[3] if len(row) > 3 else None
        customer_id = row[4] if len(row) > 4 else None
        project_id = row[5] if len(row) > 5 else None
        cost = float(row[6]) if len(row) > 6 else 0
        quantity = float(row[7]) if len(row) > 7 else 0
        
        # Extract model from meter info
        model = extract_azure_model(meter_category, meter_name)
        token_type = extract_azure_token_type(meter_name)
        
        rows.append({
            'date': start_date.isoformat(),
            'cloud_provider': 'Azure',
            'service': service_name,
            'sku_description': meter_name,
            'model': model,
            'token_type': token_type,
            'usage_amount': quantity,
            'usage_unit': extract_usage_unit(meter_name),
            'cost_usd': cost,
            'customer_id': customer_id or extract_customer_from_rg(resource_group),
            'project_id': project_id
        })
    
    if not rows:
        print("No Azure cost data found")
        return {'status': 'no_data'}
    
    df = pd.DataFrame(rows)
    print(f"Found {len(df)} cost records")
    
    # Load to BigQuery
    client = bigquery.Client()
    table_id = 'project-id.multi_cloud_costs.azure_llm_costs'
    
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        schema=[
            bigquery.SchemaField('date', 'DATE'),
            bigquery.SchemaField('cloud_provider', 'STRING'),
            bigquery.SchemaField('service', 'STRING'),
            bigquery.SchemaField('sku_description', 'STRING'),
            bigquery.SchemaField('model', 'STRING'),
            bigquery.SchemaField('token_type', 'STRING'),
            bigquery.SchemaField('usage_amount', 'FLOAT64'),
            bigquery.SchemaField('usage_unit', 'STRING'),
            bigquery.SchemaField('cost_usd', 'FLOAT64'),
            bigquery.SchemaField('customer_id', 'STRING'),
            bigquery.SchemaField('project_id', 'STRING'),
        ]
    )
    
    job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
    job.result()
    
    print(f"Successfully loaded {len(df)} rows to BigQuery")
    
    return {
        'status': 'success',
        'rows_loaded': len(df),
        'date': start_date.isoformat()
    }

def extract_azure_model(meter_category, meter_name):
    """Extract model from Azure meter info"""
    combined = f"{meter_category} {meter_name}".lower()
    
    if 'gpt-4' in combined or 'gpt4' in combined:
        if 'turbo' in combined:
            return 'gpt-4-turbo'
        elif '32k' in combined:
            return 'gpt-4-32k'
        return 'gpt-4'
    elif 'gpt-3.5' in combined or 'gpt-35' in combined:
        if '16k' in combined:
            return 'gpt-3.5-turbo-16k'
        return 'gpt-3.5-turbo'
    elif 'embedding' in combined:
        if 'ada-002' in combined:
            return 'text-embedding-ada-002'
        return 'text-embedding'
    elif 'dall-e' in combined or 'dalle' in combined:
        return 'dall-e-3' if 'dall-e-3' in combined else 'dall-e-2'
    
    return 'unknown'

def extract_azure_token_type(meter_name):
    """Determine token type from meter name"""
    meter_lower = meter_name.lower()
    
    if 'input' in meter_lower or 'prompt' in meter_lower:
        return 'input'
    elif 'output' in meter_lower or 'completion' in meter_lower:
        return 'output'
    
    return 'other'

def extract_usage_unit(meter_name):
    """Extract usage unit"""
    meter_lower = meter_name.lower()
    
    if 'token' in meter_lower:
        return 'tokens'
    elif 'hour' in meter_lower:
        return 'hours'
    elif 'image' in meter_lower:
        return 'images'
    
    return 'units'

def extract_customer_from_rg(resource_group):
    """Extract customer ID from resource group naming convention"""
    if not resource_group:
        return None
    
    # Example: rg-customer-cust001-prod → cust001
    parts = resource_group.lower().split('-')
    
    for i, part in enumerate(parts):
        if part == 'customer' and i + 1 < len(parts):
            return parts[i + 1]
    
    return None
```

**requirements.txt:**
```
google-cloud-bigquery==3.13.0
azure-identity==1.15.0
azure-mgmt-costmanagement==4.0.0
pandas==2.1.4
db-dtypes==1.1.1
```

**Deploy Cloud Function:**

```bash
# Deploy function
gcloud functions deploy azure-to-bigquery \
  --gen2 \
  --runtime python311 \
  --region us-central1 \
  --source . \
  --entry-point azure_to_bigquery \
  --trigger-topic azure-cost-etl \
  --memory 512MB \
  --timeout 540s \
  --set-env-vars \
    AZURE_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx,\
    AZURE_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx,\
    AZURE_CLIENT_SECRET=xxxxx,\
    AZURE_SUBSCRIPTION_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

# Create Cloud Scheduler job (daily at 4 AM UTC)
gcloud scheduler jobs create pubsub azure-daily-etl \
  --location us-central1 \
  --schedule "0 4 * * *" \
  --topic azure-cost-etl \
  --message-body '{"run":"daily"}' \
  --time-zone "UTC"
```

#### 4. Unified BigQuery View

```sql
-- Create unified view combining all clouds
CREATE OR REPLACE VIEW `project.multi_cloud_costs.unified_costs` AS

SELECT 
  date,
  cloud_provider,
  service,
  sku_description,
  model,
  token_type,
  usage_amount,
  usage_unit,
  cost_usd,
  customer_id,
  project_id
FROM `project.multi_cloud_costs.gcp_llm_costs`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)

UNION ALL

SELECT 
  date,
  cloud_provider,
  service,
  sku_description,
  model,
  token_type,
  usage_amount,
  usage_unit,
  cost_usd,
  customer_id,
  project_id
FROM `project.multi_cloud_costs.aws_llm_costs`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)

UNION ALL

SELECT 
  date,
  cloud_provider,
  service,
  sku_description,
  model,
  token_type,
  usage_amount,
  usage_unit,
  cost_usd,
  customer_id,
  project_id
FROM `project.multi_cloud_costs.azure_llm_costs`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY);
```

#### 5. Grafana Setup

**Install BigQuery Data Source Plugin:**

```bash
# For Grafana Cloud - already included

# For self-hosted Grafana:
grafana-cli plugins install doitintl-bigquery-datasource
```

**Configure Data Source:**

```yaml
# grafana/provisioning/datasources/bigquery.yml
apiVersion: 1

datasources:
  - name: Multi-Cloud LLM Costs
    type: doitintl-bigquery-datasource
    access: proxy
    jsonData:
      authenticationType: gce  # Use GCE metadata if running on GCP
      # OR use service account:
      # authenticationType: jwt
      # defaultProject: your-gcp-project-id
    secureJsonData:
      # If using service account:
      # privateKey: |
      #   -----BEGIN PRIVATE KEY-----
      #   ...
      #   -----END PRIVATE KEY-----
    isDefault: true
    editable: false
```

**Dashboard Queries:**

```sql
-- Panel 1: Total Cost by Cloud (Last 30 Days)
SELECT 
  cloud_provider,
  SUM(cost_usd) as total_cost
FROM `project.multi_cloud_costs.unified_costs`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  AND cloud_provider IN ($cloud_filter)
GROUP BY cloud_provider
ORDER BY total_cost DESC

-- Panel 2: Daily Cost Trend
SELECT 
  date,
  cloud_provider,
  SUM(cost_usd) as daily_cost
FROM `project.multi_cloud_costs.unified_costs`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY date, cloud_provider
ORDER BY date

-- Panel 3: Top 10 Models by Cost
SELECT 
  model,
  cloud_provider,
  SUM(cost_usd) as model_cost,
  SUM(usage_amount) as total_usage
FROM `project.multi_cloud_costs.unified_costs`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  AND model != 'unknown'
GROUP BY model, cloud_provider
ORDER BY model_cost DESC
LIMIT 10

-- Panel 4: Cost by Customer
SELECT 
  COALESCE(customer_id, 'untagged') as customer,
  SUM(cost_usd) as customer_cost,
  COUNT(DISTINCT date) as active_days
FROM `project.multi_cloud_costs.unified_costs`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  AND customer_id IS NOT NULL
GROUP BY customer_id
ORDER BY customer_cost DESC
LIMIT 20

-- Panel 5: Input vs Output Token Costs
SELECT 
  model,
  token_type,
  SUM(cost_usd) as token_cost,
  SUM(usage_amount) as token_count
FROM `project.multi_cloud_costs.unified_costs`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  AND token_type IN ('input', 'output')
GROUP BY model, token_type
ORDER BY model, token_type
```

**Dashboard Variables:**

```json
{
  "templating": {
    "list": [
      {
        "name": "cloud_filter",
        "label": "Cloud Provider",
        "type": "query",
        "datasource": "Multi-Cloud LLM Costs",
        "query": "SELECT DISTINCT cloud_provider FROM `project.multi_cloud_costs.unified_costs` ORDER BY cloud_provider",
        "multi": true,
        "includeAll": true,
        "current": {
          "text": "All",
          "value": "$__all"
        }
      },
      {
        "name": "customer_filter",
        "label": "Customer",
        "type": "query",
        "datasource": "Multi-Cloud LLM Costs",
        "query": "SELECT DISTINCT customer_id FROM `project.multi_cloud_costs.unified_costs` WHERE customer_id IS NOT NULL ORDER BY customer_id",
        "multi": false,
        "includeAll": true
      },
      {
        "name": "model_filter",
        "label": "Model",
        "type": "query",
        "datasource": "Multi-Cloud LLM Costs",
        "query": "SELECT DISTINCT model FROM `project.multi_cloud_costs.unified_costs` WHERE model != 'unknown' ORDER BY model",
        "multi": true,
        "includeAll": true
      }
    ]
  }
}
```

### Phase 1 Cost Breakdown

| Component | Monthly Cost |
|-----------|--------------|
| BigQuery Storage (50GB) | $1 |
| BigQuery Queries (~500GB scanned/month) | $2.50 |
| AWS Cost & Usage Reports (S3) | $1 |
| Cloud Function: AWS ETL (daily) | $2-3 |
| Cloud Function: Azure ETL (daily) | $2-3 |
| Cloud Scheduler (2 jobs) | $0.20 |
| Grafana (Cloud Run, 512MB) | $15-25 |
| **TOTAL** | **$23.70-35.70** |

**Rounded: $25-35/month**

### Phase 1 Timeline

| Week | Tasks | Hours |
|------|-------|-------|
| **Week 1** | Infrastructure Setup | 8-12h |
| | • Enable GCP Billing Export | 0.5h |
| | • Enable AWS Cost & Usage Reports | 1h |
| | • Set up Azure service principal | 1h |
| | • Create BigQuery dataset & tables | 1h |
| | • Configure Cloud Scheduler | 0.5h |
| **Week 2** | Build ETL Pipelines | 16-20h |
| | • Develop AWS Cloud Function | 6-8h |
| | • Develop Azure Cloud Function | 6-8h |
| | • Test end-to-end data flow | 4h |
| **Week 3** | Grafana Dashboards | 12-16h |
| | • Configure BigQuery data source | 1h |
| | • Build 4-5 core dashboards | 8-10h |
| | • Set up variables and filters | 2h |
| | • Test with live data | 2h |
| **Total** | **2-3 weeks** | **36-48 hours** |

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
│            │   │            │   │            │
│ Native     │   │ dc2.large  │   │ S0 tier    │
└─────▲──────┘   └─────▲──────┘   └─────▲──────┘
      │                │                │
      │                │                │
┌─────┴──────┐   ┌─────┴──────┐   ┌─────┴──────┐
│ GCP Billing│   │ Lambda ETL │   │ Function   │
│ Export     │   │ (Python)   │   │ App ETL    │
└────────────┘   └────────────┘   └────────────┘
```

### When to Migrate to Phase 2

**Trigger Points:**
- ✅ 20+ paying customers
- ✅ $20K+ monthly recurring revenue
- ✅ Enterprise prospects requesting "no vendor lock-in"
- ✅ Customer asking about cloud independence
- ✅ Revenue supports $150-200/month infrastructure

### Migration Strategy

**Week 1-2: Deploy AWS Infrastructure**

```bash
# Create Redshift cluster
aws redshift create-cluster \
  --cluster-identifier llm-costs-cluster \
  --node-type dc2.large \
  --number-of-nodes 1 \
  --master-username admin \
  --master-user-password 'YourSecurePassword123!' \
  --db-name llm_costs \
  --cluster-subnet-group-name default \
  --vpc-security-group-ids sg-xxxxxxxxx \
  --publicly-accessible

# Wait for cluster to become available
aws redshift describe-clusters \
  --cluster-identifier llm-costs-cluster \
  --query 'Clusters[0].ClusterStatus'
```

**Create Redshift Schema:**

```sql
-- Connect via psql or Redshift Query Editor
CREATE SCHEMA llm_costs;

CREATE TABLE llm_costs.consumption (
  date DATE NOT NULL,
  cloud_provider VARCHAR(10) DEFAULT 'AWS',
  service VARCHAR(50),
  sku_description VARCHAR(500),
  model VARCHAR(50),
  token_type VARCHAR(10),
  usage_amount DECIMAL(20,4),
  usage_unit VARCHAR(20),
  cost_usd DECIMAL(10,4),
  customer_id VARCHAR(100),
  project_id VARCHAR(100),
  PRIMARY KEY (date, model, customer_id)
)
DISTSTYLE KEY
DISTKEY (customer_id)
SORTKEY (date);

CREATE INDEX idx_customer ON llm_costs.consumption(customer_id, date);
CREATE INDEX idx_model ON llm_costs.consumption(model, date);
```

**Modify AWS ETL → Redshift:**

```python
# lambda_function.py (replaces Cloud Function)
import psycopg2
import boto3
from datetime import datetime, timedelta

def lambda_handler(event, context):
    """
    AWS Cost Explorer → Redshift ETL
    Triggered daily by EventBridge
    """
    
    # Query Cost Explorer (same as before)
    ce = boto3.client('ce')
    
    end_date = datetime.now().date()
    start_date = end_date - timedelta(days=1)
    
    response = ce.get_cost_and_usage(
        # ... same query as Cloud Function ...
    )
    
    # Connect to Redshift
    conn = psycopg2.connect(
        host=os.environ['REDSHIFT_HOST'],
        port=5439,
        dbname='llm_costs',
        user=os.environ['REDSHIFT_USER'],
        password=os.environ['REDSHIFT_PASSWORD']
    )
    cur = conn.cursor()
    
    # Insert data
    for result in response['ResultsByTime']:
        for group in result['Groups']:
            # Extract data (same as before)
            # ...
            
            cur.execute("""
                INSERT INTO llm_costs.consumption 
                (date, cloud_provider, service, model, cost_usd, customer_id)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (date, model, customer_id) DO UPDATE
                SET cost_usd = EXCLUDED.cost_usd
            """, (date, 'AWS', service, model, cost, customer_id))
    
    conn.commit()
    cur.close()
    conn.close()
    
    return {'statusCode': 200}
```

**Week 3-4: Deploy Azure Infrastructure**

```bash
# Create Azure SQL Database
az sql server create \
  --name llm-costs-server \
  --resource-group llm-costs-rg \
  --location eastus \
  --admin-user sqladmin \
  --admin-password 'YourSecurePassword123!'

az sql db create \
  --resource-group llm-costs-rg \
  --server llm-costs-server \
  --name llm_costs \
  --service-objective S0 \
  --max-size 10GB

# Configure firewall
az sql server firewall-rule create \
  --resource-group llm-costs-rg \
  --server llm-costs-server \
  --name AllowGrafana \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 255.255.255.255
```

**Create Azure SQL Schema:**

```sql
CREATE TABLE llm_consumption (
  date DATE NOT NULL,
  cloud_provider VARCHAR(10) DEFAULT 'Azure',
  service VARCHAR(50),
  sku_description VARCHAR(500),
  model VARCHAR(50),
  token_type VARCHAR(10),
  usage_amount DECIMAL(20,4),
  usage_unit VARCHAR(20),
  cost_usd DECIMAL(10,4),
  customer_id VARCHAR(100),
  project_id VARCHAR(100),
  CONSTRAINT PK_llm_consumption PRIMARY KEY (date, model, customer_id)
);

CREATE NONCLUSTERED INDEX IX_customer 
ON llm_consumption(customer_id, date DESC);

CREATE NONCLUSTERED INDEX IX_model 
ON llm_consumption(model, date DESC);
```

**Week 5-6: Update Grafana**

```yaml
# Add new data sources
apiVersion: 1

datasources:
  # Keep GCP BigQuery
  - name: GCP Costs
    type: doitintl-bigquery-datasource
    access: proxy
    jsonData:
      authenticationType: gce
      defaultProject: your-gcp-project
      defaultDataset: multi_cloud_costs
  
  # Add AWS Redshift
  - name: AWS Costs
    type: postgres
    access: proxy
    url: llm-costs-cluster.xxxxx.us-east-1.redshift.amazonaws.com:5439
    database: llm_costs
    user: admin
    secureJsonData:
      password: YourSecurePassword123!
    jsonData:
      sslmode: require
      postgresVersion: 1000
  
  # Add Azure SQL
  - name: Azure Costs
    type: mssql
    access: proxy
    url: llm-costs-server.database.windows.net:1433
    database: llm_costs
    user: sqladmin
    secureJsonData:
      password: YourSecurePassword123!
    jsonData:
      encrypt: true
```

**Week 7: Customer Migration & Cleanup**

1. Test dashboards with all 3 data sources
2. Migrate 5 pilot customers
3. Migrate remaining customers
4. Deprecate BigQuery ETL for AWS/Azure
5. Update marketing: "True multi-cloud independence"

### Phase 2 Cost Breakdown

| Component | Monthly Cost |
|-----------|--------------|
| BigQuery (GCP only) | $2-5 |
| Redshift dc2.large (AWS) | $50-80 |
| Azure SQL S0 (Azure) | $15-30 |
| Lambda (AWS ETL) | $3-5 |
| Function App (Azure ETL) | $3-5 |
| Grafana (Cloud Run) | $15-25 |
| **TOTAL** | **$88-150** |

**Rounded: $90-150/month**

---

## Implementation Checklist

### Phase 1 Setup (Weeks 1-3)

**Week 1: Infrastructure**
- [ ] Enable GCP Billing Export to BigQuery
  - [ ] Billing → Billing Export → BigQuery Export
  - [ ] Select dataset: multi_cloud_costs
  - [ ] Verify data flowing (4-6 hours delay)
- [ ] Enable AWS Cost & Usage Reports
  - [ ] Create S3 bucket: aws-cost-exports-{account}
  - [ ] Configure daily reports with resource IDs
  - [ ] Wait 24 hours for first report
- [ ] Set up Azure Service Principal
  - [ ] Create app registration
  - [ ] Assign Cost Management Reader role
  - [ ] Save tenant/client IDs and secret
- [ ] Create BigQuery tables
  - [ ] Create aws_llm_costs table
  - [ ] Create azure_llm_costs table
  - [ ] Create unified_costs view

**Week 2: ETL Pipelines**
- [ ] Build AWS Cloud Function
  - [ ] Write Python code (see above)
  - [ ] Add requirements.txt
  - [ ] Deploy to GCP
  - [ ] Configure AWS credentials
  - [ ] Test manually
- [ ] Build Azure Cloud Function
  - [ ] Write Python code (see above)
  - [ ] Add requirements.txt
  - [ ] Deploy to GCP
  - [ ] Configure Azure credentials
  - [ ] Test manually
- [ ] Set up Cloud Scheduler
  - [ ] Create aws-daily-etl job (3 AM UTC)
  - [ ] Create azure-daily-etl job (4 AM UTC)
  - [ ] Test scheduled execution
- [ ] Verify end-to-end data flow
  - [ ] Check BigQuery for AWS data
  - [ ] Check BigQuery for Azure data
  - [ ] Query unified_costs view

**Week 3: Grafana Dashboards**
- [ ] Install Grafana
  - [ ] Deploy on Cloud Run OR
  - [ ] Use Grafana Cloud
- [ ] Configure BigQuery data source
  - [ ] Test connection
  - [ ] Verify query permissions
- [ ] Build core dashboards
  - [ ] Dashboard 1: Multi-Cloud Overview
  - [ ] Dashboard 2: Cost Trends
  - [ ] Dashboard 3: Model Comparison
  - [ ] Dashboard 4: Customer Attribution
  - [ ] Dashboard 5: Anomaly Detection
- [ ] Configure variables
  - [ ] Cloud provider filter
  - [ ] Customer filter
  - [ ] Model filter
  - [ ] Time range picker
- [ ] Test with live data
  - [ ] Verify all panels load
  - [ ] Test variable filters
  - [ ] Check query performance

### Phase 2 Migration (Weeks 1-7)

**Weeks 1-2: AWS Infrastructure**
- [ ] Deploy Redshift cluster
  - [ ] Create dc2.large cluster
  - [ ] Configure VPC and security groups
  - [ ] Create database and schema
  - [ ] Test connectivity from Lambda
- [ ] Modify AWS ETL
  - [ ] Update Lambda code → Redshift
  - [ ] Deploy Lambda function
  - [ ] Test daily execution
  - [ ] Verify data in Redshift

**Weeks 3-4: Azure Infrastructure**
- [ ] Deploy Azure SQL Database
  - [ ] Create SQL server
  - [ ] Create database (S0 tier)
  - [ ] Create schema and tables
  - [ ] Configure firewall rules
- [ ] Modify Azure ETL
  - [ ] Update Function App code → Azure SQL
  - [ ] Deploy Function App
  - [ ] Test daily execution
  - [ ] Verify data in Azure SQL

**Week 5: Grafana Multi-Source**
- [ ] Add Redshift data source
  - [ ] Configure connection
  - [ ] Test queries
- [ ] Add Azure SQL data source
  - [ ] Configure connection
  - [ ] Test queries
- [ ] Update dashboards
  - [ ] Modify queries for 3 sources
  - [ ] Test all panels

**Weeks 6-7: Customer Migration**
- [ ] Week 6: Migrate 5 pilot customers
  - [ ] Test dashboards
  - [ ] Gather feedback
  - [ ] Fix issues
- [ ] Week 7: Migrate remaining customers
  - [ ] Batch migration
  - [ ] Monitor for issues
  - [ ] Deprecate BigQuery ETL

---

## Appendix: Common Queries

### Cost Analysis Queries

**Total Cost This Month:**
```sql
SELECT 
  SUM(cost_usd) as total_cost
FROM `project.multi_cloud_costs.unified_costs`
WHERE date >= DATE_TRUNC(CURRENT_DATE(), MONTH)
```

**Cost by Model (Last 7 Days):**
```sql
SELECT 
  model,
  cloud_provider,
  SUM(cost_usd) as cost,
  SUM(usage_amount) as usage
FROM `project.multi_cloud_costs.unified_costs`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  AND model != 'unknown'
GROUP BY model, cloud_provider
ORDER BY cost DESC
```

**Cost per 1K Tokens:**
```sql
SELECT 
  model,
  cloud_provider,
  SUM(cost_usd) / (SUM(usage_amount) / 1000) as cost_per_1k_tokens,
  SUM(cost_usd) as total_cost
FROM `project.multi_cloud_costs.unified_costs`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  AND usage_unit = 'tokens'
  AND usage_amount > 0
GROUP BY model, cloud_provider
HAVING SUM(usage_amount) > 1000
ORDER BY cost_per_1k_tokens DESC
```

**Customer Spend Ranking:**
```sql
SELECT 
  customer_id,
  SUM(cost_usd) as total_spend,
  COUNT(DISTINCT date) as active_days,
  SUM(cost_usd) / COUNT(DISTINCT date) as avg_daily_spend
FROM `project.multi_cloud_costs.unified_costs`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  AND customer_id IS NOT NULL
GROUP BY customer_id
ORDER BY total_spend DESC
LIMIT 20
```

**Hourly Cost Pattern (if using hourly granularity):**
```sql
SELECT 
  EXTRACT(HOUR FROM usage_start_time) as hour,
  AVG(cost) as avg_cost,
  SUM(cost) as total_cost
FROM `project.multi_cloud_costs.gcp_billing_export_v1_*`
WHERE DATE(_TABLE_SUFFIX) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
GROUP BY hour
ORDER BY hour
```

---

## Summary

**Phase 1: All-in-BigQuery**
- Cost: $25-35/month
- Time: 2-3 weeks (36-48 hours)
- Components: BigQuery + 2 Cloud Functions + Grafana
- Best for: MVP, first 20 customers, fast time-to-market

**Phase 2: Cloud-Native Independence**
- Cost: $90-150/month
- Time: 7 weeks migration
- Components: 3 Native Databases + ETL + Grafana
- Best for: Enterprise positioning, 20+ customers, no vendor lock-in

**Key Simplification:**
NO Prometheus, NO Exporters, NO TimescaleDB needed for cost monitoring.

Just: **Cloud Billing → Database → Grafana**

---

**Document End**
