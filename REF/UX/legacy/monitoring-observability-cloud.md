# Monitoring & Observability Architecture - Cloud Deployment
## AI Cost Monitoring Platform

**Document Version:** 1.0  
**Last Updated:** February 2026  
**Target Deployment:** GCP Cloud Run / AWS ECS / Azure Container Apps

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Cloud Provider Integration](#cloud-provider-integration)
3. [Observability Stack](#observability-stack)
4. [Data Flow](#data-flow)
5. [Grafana Dashboards](#grafana-dashboards)
6. [Alerting Strategy](#alerting-strategy)
7. [Cost Analysis](#cost-analysis)
8. [Implementation Guide](#implementation-guide)
9. [Operational Runbook](#operational-runbook)

---

## Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    CLOUD DEPLOYMENT STACK                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │              APPLICATION LAYER                          │    │
│  │                                                          │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │    │
│  │  │ MCP Servers  │  │ Cost Monitor │  │ ETL Pipeline │ │    │
│  │  │ (Cloud Run)  │  │    API       │  │   Service    │ │    │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘ │    │
│  │         │                  │                  │         │    │
│  │         └──────────────────┴──────────────────┘         │    │
│  │                            │                            │    │
│  │                    Structured JSON Logs                 │    │
│  │                         to stdout                       │    │
│  └────────────────────────────┬───────────────────────────┘    │
│                                │                                │
│  ┌────────────────────────────┴───────────────────────────┐    │
│  │          CLOUD NATIVE LOGGING LAYER                     │    │
│  │                                                          │    │
│  │  GCP: Cloud Logging                                     │    │
│  │  AWS: CloudWatch Logs                                   │    │
│  │  Azure: Azure Monitor Logs                              │    │
│  │                                                          │    │
│  │  Features:                                              │    │
│  │  • Automatic log collection from containers             │    │
│  │  • Structured JSON parsing                              │    │
│  │  • Log retention (30-90 days)                           │    │
│  │  • Native query language                                │    │
│  └────────────────────────────┬───────────────────────────┘    │
│                                │                                │
│  ┌────────────────────────────┴───────────────────────────┐    │
│  │           METRICS & OBSERVABILITY LAYER                 │    │
│  │                                                          │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │    │
│  │  │  Prometheus  │  │ TimescaleDB  │  │   Grafana    │ │    │
│  │  │  (Metrics)   │  │  (TSDB for   │  │(Dashboards & │ │    │
│  │  │              │  │   LLM costs) │  │   Alerts)    │ │    │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘ │    │
│  │         │                  │                  │         │    │
│  │         └──────────────────┴──────────────────┘         │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                │                                │
│  ┌────────────────────────────┴───────────────────────────┐    │
│  │              DATA SOURCES LAYER                         │    │
│  │                                                          │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │    │
│  │  │ GCP BigQuery │  │ AWS Cost     │  │ Azure Cost   │ │    │
│  │  │    Billing   │  │  Explorer    │  │  Management  │ │    │
│  │  │    Export    │  │     API      │  │     API      │ │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘ │    │
│  │                                                          │    │
│  │  LLM Services:                                          │    │
│  │  • GCP: Vertex AI (Gemini, PaLM), Document AI          │    │
│  │  • AWS: Bedrock (Claude, Titan), SageMaker             │    │
│  │  • Azure: Azure OpenAI, Cognitive Services              │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Design Principles

1. **Cloud-Native First**: Leverage managed logging services instead of self-hosted agents
2. **No Promtail Required**: Use native cloud logging with direct Grafana integration
3. **Minimal Infrastructure**: Reduce operational overhead and cost
4. **Multi-Cloud Support**: Unified observability across GCP, AWS, and Azure

---

## Cloud Provider Integration

### GCP Cloud Run Integration

#### Logging Architecture

```
Cloud Run Service (stdout/stderr)
         ↓
Google Cloud Logging (automatic)
         ↓
Grafana Cloud Logging Data Source
         ↓
Grafana Dashboards
```

#### Configuration

**1. Application Logging (Python Example)**

```python
import json
import sys
from datetime import datetime

class StructuredLogger:
    """Cloud Logging compatible structured logger"""
    
    def __init__(self, service_name: str):
        self.service_name = service_name
    
    def log(self, severity: str, message: str, **kwargs):
        """Write structured JSON log to stdout"""
        log_entry = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "severity": severity,
            "message": message,
            "service": self.service_name,
            **kwargs
        }
        print(json.dumps(log_entry), file=sys.stdout, flush=True)
    
    def info(self, message: str, **kwargs):
        self.log("INFO", message, **kwargs)
    
    def warning(self, message: str, **kwargs):
        self.log("WARNING", message, **kwargs)
    
    def error(self, message: str, **kwargs):
        self.log("ERROR", message, **kwargs)

# Usage
logger = StructuredLogger("cost-monitor-api")

logger.info(
    "Processing LLM cost data",
    customer_id="cust_123",
    provider="gcp",
    model="gemini-pro",
    tokens_used=1500,
    cost_usd=0.045
)
```

**2. Cloud Logging Export to BigQuery (Optional)**

For long-term retention and analysis:

```bash
# Create log sink to BigQuery
gcloud logging sinks create llm-cost-logs \
  bigquery.googleapis.com/projects/YOUR_PROJECT/datasets/logs \
  --log-filter='resource.type="cloud_run_revision" 
                AND jsonPayload.service="cost-monitor-api"'
```

**3. Grafana Data Source Configuration**

```yaml
# grafana-datasources.yml
apiVersion: 1

datasources:
  - name: GCP Cloud Logging
    type: grafana-googlecloud-logging-datasource
    access: proxy
    jsonData:
      authenticationType: gce
      defaultProject: YOUR_PROJECT_ID
    isDefault: false
```

#### Metrics Collection

**Prometheus Exporter on Cloud Run:**

```python
from prometheus_client import Counter, Histogram, Gauge, start_http_server
import time

# Define metrics
llm_requests_total = Counter(
    'llm_requests_total',
    'Total LLM API requests',
    ['provider', 'model', 'customer_id']
)

llm_tokens_total = Counter(
    'llm_tokens_total',
    'Total tokens consumed',
    ['provider', 'model', 'type']  # type: input/output
)

llm_cost_usd = Counter(
    'llm_cost_usd_total',
    'Total LLM cost in USD',
    ['provider', 'model', 'customer_id']
)

llm_latency_seconds = Histogram(
    'llm_latency_seconds',
    'LLM request latency',
    ['provider', 'model']
)

# Start Prometheus HTTP server
start_http_server(8000)  # /metrics endpoint

# Instrument your code
def process_llm_request(provider, model, customer_id, tokens_in, tokens_out, cost):
    llm_requests_total.labels(
        provider=provider,
        model=model,
        customer_id=customer_id
    ).inc()
    
    llm_tokens_total.labels(
        provider=provider,
        model=model,
        type='input'
    ).inc(tokens_in)
    
    llm_tokens_total.labels(
        provider=provider,
        model=model,
        type='output'
    ).inc(tokens_out)
    
    llm_cost_usd.labels(
        provider=provider,
        model=model,
        customer_id=customer_id
    ).inc(cost)
```

**Prometheus Scrape Configuration:**

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'cloud-run-services'
    metrics_path: '/metrics'
    static_configs:
      - targets:
          - 'cost-monitor-api-xxxxx.run.app:8000'
          - 'prometheus-exporter-xxxxx.run.app:8000'
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
```

---

### AWS ECS/Fargate Integration

#### Logging Architecture

```
ECS Task (stdout/stderr)
         ↓
CloudWatch Logs (automatic)
         ↓
Grafana CloudWatch Data Source
         ↓
Grafana Dashboards
```

#### Configuration

**1. ECS Task Definition (JSON)**

```json
{
  "family": "cost-monitor-api",
  "containerDefinitions": [
    {
      "name": "api",
      "image": "cost-monitor-api:latest",
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/cost-monitor",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "api"
        }
      },
      "environment": [
        {
          "name": "LOG_LEVEL",
          "value": "INFO"
        }
      ]
    }
  ]
}
```

**2. CloudWatch Logs Insights Queries**

```sql
-- Query LLM cost data
fields @timestamp, jsonPayload.customer_id, jsonPayload.provider, 
       jsonPayload.model, jsonPayload.cost_usd
| filter jsonPayload.service = "cost-monitor-api"
| filter jsonPayload.event_type = "llm_request"
| stats sum(jsonPayload.cost_usd) as total_cost by jsonPayload.provider
| sort total_cost desc
```

**3. Grafana Data Source**

```yaml
# grafana-datasources.yml
apiVersion: 1

datasources:
  - name: AWS CloudWatch
    type: cloudwatch
    access: proxy
    jsonData:
      authType: default
      defaultRegion: us-east-1
    isDefault: false
```

---

### Azure Container Apps Integration

#### Logging Architecture

```
Container App (stdout/stderr)
         ↓
Azure Monitor Logs (automatic)
         ↓
Grafana Azure Monitor Data Source
         ↓
Grafana Dashboards
```

#### Configuration

**1. Container App Deployment (YAML)**

```yaml
apiVersion: apps/v1
kind: ContainerApp
metadata:
  name: cost-monitor-api
spec:
  containers:
    - name: api
      image: costmonitor.azurecr.io/api:latest
      env:
        - name: LOG_LEVEL
          value: "INFO"
  configuration:
    dapr:
      enabled: false
    logs:
      destination: log-analytics
```

**2. Kusto Query Language (KQL) Queries**

```kql
// Query LLM cost data
ContainerAppConsoleLogs_CL
| where ContainerName_s == "cost-monitor-api"
| extend parsed = parse_json(Log_s)
| where parsed.service == "cost-monitor-api"
| where parsed.event_type == "llm_request"
| summarize total_cost = sum(todouble(parsed.cost_usd)) by tostring(parsed.provider)
| order by total_cost desc
```

**3. Grafana Data Source**

```yaml
# grafana-datasources.yml
apiVersion: 1

datasources:
  - name: Azure Monitor
    type: grafana-azure-monitor-datasource
    access: proxy
    jsonData:
      azureAuthType: msi
      subscriptionId: YOUR_SUBSCRIPTION_ID
    isDefault: false
```

---

## Observability Stack

### Component Overview

| Component | Purpose | Deployment | Cost Estimate |
|-----------|---------|------------|---------------|
| **Prometheus** | Metrics collection & storage | Cloud Run / ECS / Container Apps | $20-40/mo |
| **TimescaleDB** | Time-series database for LLM costs | Cloud SQL / RDS / Azure DB | $30-80/mo |
| **Grafana** | Dashboards & visualization | Cloud Run / ECS / Container Apps | $10-30/mo |
| **Cloud Logging** | Application logs | Native (GCP/AWS/Azure) | $5-20/mo |

**Total Infrastructure Cost: $65-170/month**

### Prometheus Deployment

#### Cloud Run (GCP)

```yaml
# cloudbuild.yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/prometheus', './prometheus']
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/prometheus']
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: gcloud
    args:
      - 'run'
      - 'deploy'
      - 'prometheus'
      - '--image=gcr.io/$PROJECT_ID/prometheus'
      - '--platform=managed'
      - '--region=us-central1'
      - '--memory=1Gi'
      - '--cpu=1'
      - '--port=9090'
      - '--no-allow-unauthenticated'
```

**Dockerfile:**

```dockerfile
FROM prom/prometheus:latest

COPY prometheus.yml /etc/prometheus/prometheus.yml
COPY alerts.yml /etc/prometheus/alerts.yml

EXPOSE 9090

CMD ["--config.file=/etc/prometheus/prometheus.yml", \
     "--storage.tsdb.path=/prometheus", \
     "--storage.tsdb.retention.time=30d"]
```

#### ECS (AWS)

```json
{
  "family": "prometheus",
  "taskRoleArn": "arn:aws:iam::ACCOUNT:role/prometheus-task-role",
  "containerDefinitions": [
    {
      "name": "prometheus",
      "image": "prom/prometheus:latest",
      "memory": 1024,
      "cpu": 512,
      "essential": true,
      "portMappings": [
        {
          "containerPort": 9090,
          "protocol": "tcp"
        }
      ],
      "mountPoints": [
        {
          "sourceVolume": "prometheus-config",
          "containerPath": "/etc/prometheus"
        }
      ]
    }
  ],
  "volumes": [
    {
      "name": "prometheus-config",
      "efsVolumeConfiguration": {
        "fileSystemId": "fs-xxxxx"
      }
    }
  ]
}
```

### TimescaleDB Deployment

#### Cloud SQL (GCP)

```bash
# Create PostgreSQL instance with TimescaleDB extension
gcloud sql instances create llm-costs-db \
  --database-version=POSTGRES_14 \
  --tier=db-f1-micro \
  --region=us-central1 \
  --database-flags=cloudsql.enable_pgaudit=on

# Connect and enable TimescaleDB
gcloud sql connect llm-costs-db --user=postgres

postgres=# CREATE EXTENSION IF NOT EXISTS timescaledb;
postgres=# CREATE DATABASE llm_costs;
postgres=# \c llm_costs
llm_costs=# SELECT create_hypertable('llm_consumption', 'timestamp');
```

#### RDS (AWS)

```bash
# Create RDS PostgreSQL instance
aws rds create-db-instance \
  --db-instance-identifier llm-costs-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 14.7 \
  --master-username postgres \
  --master-user-password YOUR_PASSWORD \
  --allocated-storage 20

# Enable TimescaleDB via RDS extension
aws rds modify-db-parameter-group \
  --db-parameter-group-name default.postgres14 \
  --parameters "ParameterName=shared_preload_libraries,ParameterValue=timescaledb"
```

### Grafana Deployment

#### Cloud Run (GCP)

```bash
# Deploy Grafana to Cloud Run
gcloud run deploy grafana \
  --image=grafana/grafana:latest \
  --platform=managed \
  --region=us-central1 \
  --memory=512Mi \
  --cpu=1 \
  --port=3000 \
  --set-env-vars="GF_SERVER_ROOT_URL=https://grafana-xxxxx.run.app" \
  --set-env-vars="GF_AUTH_ANONYMOUS_ENABLED=false" \
  --allow-unauthenticated
```

**Persistent Configuration via Cloud Storage:**

```yaml
# grafana-deployment.yaml (Cloud Run)
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: grafana
spec:
  template:
    spec:
      containers:
        - image: grafana/grafana:latest
          ports:
            - containerPort: 3000
          env:
            - name: GF_PATHS_PROVISIONING
              value: /etc/grafana/provisioning
          volumeMounts:
            - name: grafana-config
              mountPath: /etc/grafana/provisioning
      volumes:
        - name: grafana-config
          gcsfuse:
            bucket: grafana-config-bucket
            readOnly: true
```

---

## Data Flow

### LLM Cost Data Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                   DATA FLOW ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  STEP 1: Cloud Provider Billing Export                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ GCP BigQuery │  │ AWS Cost     │  │ Azure Cost   │          │
│  │   Billing    │  │  Explorer    │  │  Management  │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                  │                  │                  │
│         └──────────────────┴──────────────────┘                  │
│                            │                                     │
│  STEP 2: ETL Pipeline (Cloud Function / Lambda / Function App)  │
│                            ↓                                     │
│         ┌─────────────────────────────────────┐                 │
│         │   Normalize & Transform Data        │                 │
│         │   • Extract LLM service costs       │                 │
│         │   • Calculate token usage           │                 │
│         │   • Add customer attribution        │                 │
│         │   • Enrich with metadata            │                 │
│         └──────────────┬──────────────────────┘                 │
│                        │                                         │
│  STEP 3: Data Storage                                           │
│                        ↓                                         │
│         ┌─────────────────────────────────────┐                 │
│         │      TimescaleDB / PostgreSQL       │                 │
│         │                                      │                 │
│         │  Table: llm_consumption              │                 │
│         │  • timestamp (hypertable)            │                 │
│         │  • cloud_provider                    │                 │
│         │  • service (Vertex AI, Bedrock)      │                 │
│         │  • model (gemini-pro, claude-v2)     │                 │
│         │  • tokens (input/output/total)       │                 │
│         │  • cost_usd                          │                 │
│         │  • customer_id, project_id           │                 │
│         └──────────────┬──────────────────────┘                 │
│                        │                                         │
│  STEP 4: Metrics Export                                         │
│                        ↓                                         │
│         ┌─────────────────────────────────────┐                 │
│         │    Prometheus Exporter Service      │                 │
│         │                                      │                 │
│         │  Queries TimescaleDB every 15s:     │                 │
│         │  • llm_tokens_total                  │                 │
│         │  • llm_cost_usd_total                │                 │
│         │  • llm_requests_total                │                 │
│         └──────────────┬──────────────────────┘                 │
│                        │                                         │
│  STEP 5: Monitoring & Visualization                             │
│                        ↓                                         │
│         ┌──────────────┴──────────────────────┐                 │
│         │          Prometheus                 │                 │
│         │      (scrapes every 15s)            │                 │
│         └──────────────┬──────────────────────┘                 │
│                        │                                         │
│                        ↓                                         │
│         ┌─────────────────────────────────────┐                 │
│         │           Grafana                   │                 │
│         │   • Cost Overview Dashboard         │                 │
│         │   • Model Comparison Dashboard      │                 │
│         │   • Customer Usage Dashboard        │                 │
│         │   • Anomaly Detection Dashboard     │                 │
│         └─────────────────────────────────────┘                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### ETL Pipeline Implementation

**Cloud Function (GCP):**

```python
import functions_framework
from google.cloud import bigquery
import psycopg2
from datetime import datetime, timedelta

@functions_framework.cloud_event
def process_billing_export(cloud_event):
    """
    Triggered daily to process BigQuery billing export
    and populate TimescaleDB
    """
    # Query BigQuery for yesterday's LLM costs
    client = bigquery.Client()
    
    query = """
    SELECT
      usage_start_time as timestamp,
      'GCP' as cloud_provider,
      service.description as service,
      sku.description as model,
      SUM(usage.amount) as usage_amount,
      SUM(cost) as cost_usd,
      labels.value as customer_id
    FROM `project.billing_export.gcp_billing_export_v1_*`
    WHERE DATE(_TABLE_SUFFIX) = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
      AND service.description IN ('Vertex AI API', 'Cloud AI Platform')
    GROUP BY timestamp, service, sku.description, labels.value
    """
    
    results = client.query(query).result()
    
    # Connect to TimescaleDB
    conn = psycopg2.connect(
        host="llm-costs-db",
        database="llm_costs",
        user="postgres",
        password=os.environ['DB_PASSWORD']
    )
    cur = conn.cursor()
    
    # Insert data
    for row in results:
        cur.execute("""
            INSERT INTO llm_consumption 
            (timestamp, cloud_provider, service, model, usage_amount, cost_usd, customer_id)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (
            row.timestamp,
            row.cloud_provider,
            row.service,
            extract_model_name(row.model),  # Parse SKU to model name
            row.usage_amount,
            row.cost_usd,
            row.customer_id
        ))
    
    conn.commit()
    cur.close()
    conn.close()
    
    print(f"Processed {results.total_rows} billing records")

def extract_model_name(sku_description):
    """Extract model name from SKU description"""
    # Example: "Vertex AI - PaLM 2 Text Bison" -> "palm-2-bison"
    model_mapping = {
        'PaLM 2': 'palm-2',
        'Gemini Pro': 'gemini-pro',
        'Gemini Flash': 'gemini-flash',
        'Document AI': 'document-ai',
    }
    
    for key, value in model_mapping.items():
        if key in sku_description:
            return value
    return 'unknown'
```

**Lambda Function (AWS):**

```python
import boto3
import psycopg2
import os
from datetime import datetime, timedelta

def lambda_handler(event, context):
    """
    Triggered daily to process Cost Explorer data
    and populate TimescaleDB
    """
    ce_client = boto3.client('ce')
    
    # Query Cost Explorer for yesterday's costs
    end_date = datetime.now().date()
    start_date = end_date - timedelta(days=1)
    
    response = ce_client.get_cost_and_usage(
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
        Metrics=['UsageQuantity', 'BlendedCost'],
        GroupBy=[
            {'Type': 'DIMENSION', 'Key': 'SERVICE'},
            {'Type': 'TAG', 'Key': 'Model'},
            {'Type': 'TAG', 'Key': 'CustomerId'}
        ]
    )
    
    # Connect to TimescaleDB
    conn = psycopg2.connect(
        host=os.environ['DB_HOST'],
        database='llm_costs',
        user='postgres',
        password=os.environ['DB_PASSWORD']
    )
    cur = conn.cursor()
    
    # Insert data
    for result in response['ResultsByTime']:
        for group in result['Groups']:
            service = group['Keys'][0]
            model = group['Keys'][1] if len(group['Keys']) > 1 else 'unknown'
            customer_id = group['Keys'][2] if len(group['Keys']) > 2 else None
            
            usage = float(group['Metrics']['UsageQuantity']['Amount'])
            cost = float(group['Metrics']['BlendedCost']['Amount'])
            
            cur.execute("""
                INSERT INTO llm_consumption 
                (timestamp, cloud_provider, service, model, usage_amount, cost_usd, customer_id)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            """, (
                result['TimePeriod']['Start'],
                'AWS',
                service,
                model,
                usage,
                cost,
                customer_id
            ))
    
    conn.commit()
    cur.close()
    conn.close()
    
    return {
        'statusCode': 200,
        'body': 'ETL completed successfully'
    }
```

---

## Grafana Dashboards

### Dashboard 1: LLM Cost Overview

**Purpose:** High-level view of total LLM costs across all cloud providers

**Panels:**

1. **Total Monthly Cost (Stat Panel)**
```promql
sum(increase(llm_cost_usd_total[30d]))
```

2. **Cost by Cloud Provider (Pie Chart)**
```promql
sum by (provider) (increase(llm_cost_usd_total[30d]))
```

3. **Cost Trend (Time Series)**
```promql
sum(rate(llm_cost_usd_total[1h])) by (provider)
```

4. **Top 5 Models by Cost (Bar Gauge)**
```promql
topk(5, sum by (model) (increase(llm_cost_usd_total[30d])))
```

5. **Daily Cost Comparison (Time Series)**
```promql
sum(increase(llm_cost_usd_total[1d])) by (provider)
```

**Variables:**
- `$provider` - Multi-select: GCP, AWS, Azure
- `$timerange` - Time range picker

---

### Dashboard 2: Model Comparison

**Purpose:** Compare costs and usage across different LLM models

**Panels:**

1. **Token Usage by Model (Time Series)**
```promql
sum(rate(llm_tokens_total[5m])) by (model, type)
```

2. **Cost per 1K Tokens (Table)**
```sql
-- TimescaleDB query via Grafana PostgreSQL data source
SELECT 
  model,
  SUM(cost_usd) / (SUM(total_tokens) / 1000) as cost_per_1k_tokens,
  SUM(total_tokens) as total_tokens,
  SUM(cost_usd) as total_cost
FROM llm_consumption
WHERE timestamp > NOW() - INTERVAL '30 days'
GROUP BY model
ORDER BY total_cost DESC
```

3. **Model Usage Distribution (Pie Chart)**
```promql
sum by (model) (increase(llm_requests_total[30d]))
```

4. **Gemini Pro vs Flash (Time Series Comparison)**
```promql
sum(rate(llm_cost_usd_total{model=~"gemini-pro|gemini-flash"}[1h])) by (model)
```

---

### Dashboard 3: Customer Usage & Attribution

**Purpose:** Multi-tenant cost tracking per customer

**Panels:**

1. **Top 10 Customers by Cost (Bar Chart)**
```promql
topk(10, sum by (customer_id) (increase(llm_cost_usd_total[30d])))
```

2. **Customer Cost Breakdown (Table)**
```sql
SELECT 
  customer_id,
  cloud_provider,
  model,
  SUM(cost_usd) as total_cost,
  SUM(total_tokens) as total_tokens,
  COUNT(*) as request_count
FROM llm_consumption
WHERE timestamp > NOW() - INTERVAL '7 days'
GROUP BY customer_id, cloud_provider, model
ORDER BY total_cost DESC
LIMIT 100
```

3. **Cost per Customer Over Time (Time Series)**
```promql
sum(rate(llm_cost_usd_total{customer_id="$customer_id"}[1h])) by (model)
```

**Variables:**
- `$customer_id` - Dropdown populated from database

---

### Dashboard 4: Anomaly Detection

**Purpose:** Identify unusual spending patterns

**Panels:**

1. **Cost Spike Alert (Stat Panel with Threshold)**
```promql
rate(llm_cost_usd_total[1h]) > 100
```

2. **Token Usage Anomaly (Time Series with Prediction)**
```promql
# Using Holt-Winters prediction
predict_linear(llm_tokens_total[1h], 3600) > 1.5 * llm_tokens_total
```

3. **Unexpected Model Usage (Table)**
```sql
-- Detect models being used that aren't expected
SELECT 
  customer_id,
  model,
  SUM(cost_usd) as unexpected_cost
FROM llm_consumption
WHERE timestamp > NOW() - INTERVAL '24 hours'
  AND model NOT IN (
    SELECT DISTINCT model 
    FROM customer_approved_models 
    WHERE customer_id = llm_consumption.customer_id
  )
GROUP BY customer_id, model
HAVING SUM(cost_usd) > 10
```

4. **Hourly Cost Variance (Heatmap)**
```sql
SELECT 
  DATE_TRUNC('hour', timestamp) as hour,
  EXTRACT(DOW FROM timestamp) as day_of_week,
  SUM(cost_usd) as cost
FROM llm_consumption
WHERE timestamp > NOW() - INTERVAL '7 days'
GROUP BY hour, day_of_week
```

---

## Alerting Strategy

### Prometheus Alert Rules

```yaml
# /etc/prometheus/alerts.yml
groups:
  - name: llm_cost_alerts
    interval: 1m
    rules:
      
      # Critical: Hourly cost exceeds $100
      - alert: LLMCostSpike
        expr: rate(llm_cost_usd_total[1h]) > 100
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "LLM costs spiked above $100/hour"
          description: "Current rate: {{ $value | humanize }}/hour"
      
      # Warning: Daily budget 80% consumed
      - alert: DailyBudgetWarning
        expr: |
          (sum(increase(llm_cost_usd_total[1d])) / 500) > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Daily LLM budget 80% consumed"
          description: "Spent {{ $value | humanizePercentage }} of daily budget"
      
      # Warning: Unusual model usage
      - alert: UnexpectedModelUsage
        expr: |
          increase(llm_cost_usd_total{model="gpt-4"}[1h]) > 0
          unless
          increase(llm_cost_usd_total{model="gpt-4"}[7d] offset 7d) > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Unexpected GPT-4 usage detected"
          description: "GPT-4 costs detected, but not used in past week"
      
      # Info: High token usage
      - alert: HighTokenUsage
        expr: rate(llm_tokens_total[5m]) > 10000
        for: 15m
        labels:
          severity: info
        annotations:
          summary: "High token usage rate"
          description: "{{ $value | humanize }} tokens/sec"
      
      # Critical: Customer exceeds quota
      - alert: CustomerQuotaExceeded
        expr: |
          sum by (customer_id) (increase(llm_cost_usd_total[1d])) > 1000
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Customer {{ $labels.customer_id }} exceeded quota"
          description: "Daily cost: ${{ $value | humanize }}"

  - name: infrastructure_alerts
    interval: 1m
    rules:
      
      # Critical: Prometheus scrape failures
      - alert: PrometheusScrapeFailure
        expr: up == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Prometheus cannot scrape {{ $labels.job }}"
      
      # Warning: High memory usage
      - alert: HighMemoryUsage
        expr: |
          (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) > 0.85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Memory usage above 85%"
      
      # Critical: Disk space low
      - alert: DiskSpaceLow
        expr: |
          (1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) > 0.90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Disk usage above 90%"
```

### Alertmanager Configuration

```yaml
# /etc/alertmanager/alertmanager.yml
global:
  resolve_timeout: 5m
  slack_api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'

route:
  group_by: ['alertname', 'cluster']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'slack-notifications'
  
  routes:
    # Critical alerts go to PagerDuty
    - match:
        severity: critical
      receiver: 'pagerduty'
      continue: true
    
    # Warning alerts only to Slack
    - match:
        severity: warning
      receiver: 'slack-notifications'
    
    # Info alerts to email
    - match:
        severity: info
      receiver: 'email-notifications'

receivers:
  - name: 'slack-notifications'
    slack_configs:
      - channel: '#llm-cost-alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
  
  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: 'YOUR_PAGERDUTY_KEY'
        description: '{{ .GroupLabels.alertname }}'
  
  - name: 'email-notifications'
    email_configs:
      - to: 'ops-team@company.com'
        from: 'alertmanager@company.com'
        smarthost: 'smtp.gmail.com:587'
        auth_username: 'alertmanager@company.com'
        auth_password: 'YOUR_PASSWORD'
```

---

## Cost Analysis

### Infrastructure Cost Breakdown (Monthly)

| Component | GCP | AWS | Azure | Notes |
|-----------|-----|-----|-------|-------|
| **Application Hosting** | | | | |
| Container Runtime | Cloud Run: $15-30 | ECS Fargate: $20-40 | Container Apps: $18-35 | Based on 24/7 operation |
| **Observability Stack** | | | | |
| Prometheus | Cloud Run: $10-20 | ECS: $15-25 | Container Apps: $12-22 | 1GB memory, 1 vCPU |
| TimescaleDB | Cloud SQL: $30-80 | RDS: $35-90 | Azure DB: $32-85 | db.t3.micro equivalent |
| Grafana | Cloud Run: $8-15 | ECS: $10-18 | Container Apps: $9-16 | 512MB memory |
| **Logging** | | | | |
| Cloud Logging | $5-15 | CloudWatch: $8-20 | Azure Monitor: $6-18 | ~10GB/month ingestion |
| Log Storage | Included | $3-8 | $4-10 | 30-day retention |
| **Data Transfer** | $2-5 | $3-7 | $2-6 | Minimal egress |
| **Total** | **$70-165** | **$94-208** | **$83-192** | |

### Optimization Opportunities

1. **Use Preemptible/Spot Instances**
   - GCP Cloud Run: Not applicable (serverless)
   - AWS ECS Fargate Spot: ~70% savings on non-critical workloads
   - Azure Container Apps: Consumption plan for variable workloads

2. **Leverage Free Tiers**
   - GCP Cloud Logging: First 50GB/month free
   - AWS CloudWatch: First 5GB free
   - Azure Monitor: First 5GB free

3. **Optimize Prometheus Retention**
   - Reduce from 30 days to 15 days: ~40% storage savings
   - Use remote write to object storage for long-term retention

4. **Right-Size Instances**
   - Monitor actual resource usage via Grafana
   - Downsize if CPU < 30% or Memory < 50% for 7+ days

---

## Implementation Guide

### Phase 1: Foundation (Week 1)

**Goal:** Set up basic monitoring infrastructure

**Tasks:**

1. Deploy TimescaleDB
```bash
# GCP
gcloud sql instances create llm-costs-db \
  --database-version=POSTGRES_14 \
  --tier=db-f1-micro \
  --region=us-central1

# Connect and setup
gcloud sql connect llm-costs-db --user=postgres
CREATE EXTENSION timescaledb;
CREATE DATABASE llm_costs;
\c llm_costs
```

2. Create schema
```sql
CREATE TABLE llm_consumption (
  timestamp TIMESTAMPTZ NOT NULL,
  cloud_provider VARCHAR(10) NOT NULL,
  service VARCHAR(50) NOT NULL,
  model VARCHAR(50) NOT NULL,
  operation VARCHAR(20),
  
  input_tokens BIGINT,
  output_tokens BIGINT,
  total_tokens BIGINT,
  request_count INT DEFAULT 1,
  
  cost_usd DECIMAL(10,4),
  cost_per_1k_tokens DECIMAL(10,6),
  
  customer_id VARCHAR(100),
  project_id VARCHAR(100),
  feature_name VARCHAR(100),
  
  region VARCHAR(50),
  response_time_ms INT,
  
  metadata JSONB
);

SELECT create_hypertable('llm_consumption', 'timestamp');

CREATE INDEX idx_customer ON llm_consumption(customer_id, timestamp DESC);
CREATE INDEX idx_provider ON llm_consumption(cloud_provider, timestamp DESC);
CREATE INDEX idx_model ON llm_consumption(model, timestamp DESC);
```

3. Deploy Prometheus
```bash
# Build and deploy
docker build -t gcr.io/PROJECT/prometheus ./prometheus
docker push gcr.io/PROJECT/prometheus

gcloud run deploy prometheus \
  --image gcr.io/PROJECT/prometheus \
  --platform managed \
  --region us-central1 \
  --memory 1Gi
```

4. Deploy Grafana
```bash
gcloud run deploy grafana \
  --image grafana/grafana:latest \
  --platform managed \
  --region us-central1 \
  --memory 512Mi \
  --set-env-vars GF_SERVER_ROOT_URL=https://grafana-xxxxx.run.app
```

---

### Phase 2: ETL Pipeline (Week 2)

**Goal:** Automate billing data collection

**Tasks:**

1. Create Cloud Function for ETL
```bash
# GCP
gcloud functions deploy process-billing-export \
  --runtime python310 \
  --trigger-topic billing-export-topic \
  --entry-point process_billing_export \
  --memory 512MB
```

2. Schedule daily runs
```bash
# Create Cloud Scheduler job
gcloud scheduler jobs create pubsub daily-etl \
  --schedule "0 2 * * *" \
  --topic billing-export-topic \
  --message-body '{"date": "yesterday"}'
```

3. Test ETL pipeline
```bash
# Trigger manually
gcloud pubsub topics publish billing-export-topic \
  --message '{"date": "2026-02-04"}'
```

---

### Phase 3: Dashboards (Week 3)

**Goal:** Build Grafana dashboards

**Tasks:**

1. Add data sources
```bash
# Import datasource config
kubectl create configmap grafana-datasources \
  --from-file=grafana-datasources.yml

# Restart Grafana
gcloud run services update grafana --region us-central1
```

2. Import dashboards
```bash
# Use Grafana API
curl -X POST http://localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @dashboard-llm-cost-overview.json
```

3. Configure variables
- Set up `$provider`, `$customer_id`, `$model` template variables
- Test all panels with different variable selections

---

### Phase 4: Alerting (Week 4)

**Goal:** Enable proactive monitoring

**Tasks:**

1. Configure Alertmanager
```yaml
# Deploy Alertmanager to Cloud Run
gcloud run deploy alertmanager \
  --image prom/alertmanager:latest \
  --platform managed \
  --region us-central1
```

2. Set up notification channels
- Slack webhook integration
- PagerDuty service key
- Email SMTP configuration

3. Test alerts
```bash
# Trigger test alert
curl -X POST http://prometheus:9090/-/reload

# Verify in Alertmanager UI
curl http://alertmanager:9093/api/v2/alerts
```

---

## Operational Runbook

### Daily Operations

**Morning Checks (9 AM)**

1. Review overnight alerts in Slack
2. Check Grafana "LLM Cost Overview" dashboard
3. Verify ETL pipeline ran successfully
```bash
# Check Cloud Function logs
gcloud functions logs read process-billing-export \
  --limit 50
```

**End of Day (6 PM)**

1. Review daily cost summary
2. Check for any cost anomalies
3. Verify customer quotas not exceeded

---

### Weekly Operations

**Monday Morning**

1. Review weekly cost trends
2. Generate cost report for leadership
3. Check for optimization opportunities
4. Update capacity forecasts

---

### Monthly Operations

**First Business Day**

1. Generate monthly cost breakdown by:
   - Cloud provider
   - Model
   - Customer
   - Feature
2. Reconcile with cloud provider invoices
3. Update cost forecasts
4. Review and adjust alert thresholds

---

### Troubleshooting

**ETL Pipeline Failures**

```bash
# Check function logs
gcloud functions logs read process-billing-export --limit 100

# Common issues:
# 1. Database connection timeout
#    → Check Cloud SQL instance status
#    → Verify VPC connector configuration

# 2. BigQuery quota exceeded
#    → Check quota usage in GCP Console
#    → Request quota increase if needed

# 3. Data parsing errors
#    → Review billing export schema changes
#    → Update SKU mapping logic
```

**Prometheus Scrape Failures**

```bash
# Check Prometheus targets
curl http://prometheus:9090/api/v1/targets

# Verify service health
curl http://cost-monitor-api:8000/metrics

# Common issues:
# 1. Service unreachable
#    → Check Cloud Run service status
#    → Verify firewall rules

# 2. Authentication failures
#    → Verify service account permissions
#    → Check IAM roles
```

**Grafana Dashboard Issues**

```bash
# Check data source connectivity
curl http://grafana:3000/api/datasources

# Test Prometheus queries
curl -G http://prometheus:9090/api/v1/query \
  --data-urlencode 'query=llm_cost_usd_total'

# Common issues:
# 1. No data displayed
#    → Verify time range selection
#    → Check Prometheus data retention

# 2. Query timeouts
#    → Optimize query (add filters)
#    → Increase query timeout in Grafana
```

---

## Appendix

### Environment Variables

```bash
# Application
export LOG_LEVEL=INFO
export ENVIRONMENT=production

# Database
export DB_HOST=llm-costs-db
export DB_NAME=llm_costs
export DB_USER=postgres
export DB_PASSWORD=<secret>

# Prometheus
export PROMETHEUS_URL=http://prometheus:9090
export PROMETHEUS_RETENTION=30d

# Grafana
export GF_SERVER_ROOT_URL=https://grafana.company.com
export GF_AUTH_ANONYMOUS_ENABLED=false
export GF_SECURITY_ADMIN_PASSWORD=<secret>

# Cloud Provider
export GCP_PROJECT_ID=my-project
export AWS_REGION=us-east-1
export AZURE_SUBSCRIPTION_ID=<subscription>
```

### Useful Queries

**BigQuery: Yesterday's LLM Costs**
```sql
SELECT
  service.description,
  sku.description,
  SUM(cost) as total_cost,
  SUM(usage.amount) as usage_amount
FROM `project.billing_export.gcp_billing_export_v1_*`
WHERE DATE(_TABLE_SUFFIX) = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND service.description LIKE '%AI%'
GROUP BY service.description, sku.description
ORDER BY total_cost DESC
```

**TimescaleDB: Top Models This Week**
```sql
SELECT 
  model,
  SUM(cost_usd) as total_cost,
  SUM(total_tokens) as total_tokens,
  COUNT(*) as request_count
FROM llm_consumption
WHERE timestamp > NOW() - INTERVAL '7 days'
GROUP BY model
ORDER BY total_cost DESC
LIMIT 10;
```

**Prometheus: Cost Rate (Last Hour)**
```promql
sum(rate(llm_cost_usd_total[1h])) by (provider, model)
```

---

**Document End**

