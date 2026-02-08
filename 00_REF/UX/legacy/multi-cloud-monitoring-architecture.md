# Multi-Cloud Monitoring Architecture
## AI Cost Monitoring Platform - Unified Dashboard Across GCP, AWS, Azure

**Document Version:** 1.0  
**Last Updated:** February 2026  
**Architecture Pattern:** Federated Multi-Cloud with Unified Observability

---

## Executive Summary

This architecture enables a **single unified Grafana dashboard** to monitor LLM costs across GCP, AWS, and Azure by querying each cloud's dedicated MCP server. Each cloud environment operates independently with its own MCP server, while a central monitoring layer aggregates metrics and provides unified visualization.

**Key Features:**
- ✅ Each cloud has dedicated MCP server (GCP MCP, AWS MCP, Azure MCP)
- ✅ Unified Grafana dashboard queries all MCP servers
- ✅ Dynamic cloud enable/disable per customer/tenant
- ✅ Independent cloud deployments (failure isolation)
- ✅ Centralized alerting and reporting
- ✅ Multi-tenant support with cloud selection

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Cloud-Specific Deployments](#cloud-specific-deployments)
3. [Unified Monitoring Layer](#unified-monitoring-layer)
4. [MCP Server Integration](#mcp-server-integration)
5. [Multi-Tenant Cloud Selection](#multi-tenant-cloud-selection)
6. [Dashboard Configuration](#dashboard-configuration)
7. [Data Flow](#data-flow)
8. [Implementation Guide](#implementation-guide)

---

## Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    UNIFIED MONITORING LAYER                          │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    Central Grafana                            │  │
│  │            (Single Unified Dashboard)                         │  │
│  │                                                                │  │
│  │  • Multi-cloud cost overview                                  │  │
│  │  • Cross-cloud model comparison                               │  │
│  │  • Tenant cloud selection                                     │  │
│  │  • Unified alerting                                           │  │
│  └────────────┬─────────────┬─────────────┬─────────────────────┘  │
│               │             │             │                          │
│               ▼             ▼             ▼                          │
│  ┌────────────────┐ ┌──────────────┐ ┌──────────────┐             │
│  │   GCP Data     │ │  AWS Data    │ │ Azure Data   │             │
│  │    Source      │ │   Source     │ │   Source     │             │
│  └────────┬───────┘ └──────┬───────┘ └──────┬───────┘             │
│           │                 │                 │                      │
└───────────┼─────────────────┼─────────────────┼──────────────────────┘
            │                 │                 │
            ▼                 ▼                 ▼
┌───────────────────────────────────────────────────────────────────────┐
│                     CLOUD ENVIRONMENTS                                 │
├────────────────────┬──────────────────────┬────────────────────────────┤
│                    │                      │                            │
│  GCP ENVIRONMENT   │  AWS ENVIRONMENT     │  AZURE ENVIRONMENT         │
│                    │                      │                            │
│ ┌────────────────┐ │ ┌────────────────┐  │ ┌────────────────┐        │
│ │  GCP MCP       │ │ │  AWS MCP       │  │ │  Azure MCP     │        │
│ │  Server        │ │ │  Server        │  │ │  Server        │        │
│ │                │ │ │                │  │ │                │        │
│ │  (Cloud Run)   │ │ │  (ECS Fargate) │  │ │ (Container App)│        │
│ └────────┬───────┘ │ └────────┬───────┘  │ └────────┬───────┘        │
│          │         │          │           │          │                │
│          ▼         │          ▼           │          ▼                │
│ ┌────────────────┐ │ ┌────────────────┐  │ ┌────────────────┐        │
│ │ Prometheus     │ │ │ Prometheus     │  │ │ Prometheus     │        │
│ │ Exporter       │ │ │ Exporter       │  │ │ Exporter       │        │
│ └────────┬───────┘ │ └────────┬───────┘  │ └────────┬───────┘        │
│          │         │          │           │          │                │
│          ▼         │          ▼           │          ▼                │
│ ┌────────────────┐ │ ┌────────────────┐  │ ┌────────────────┐        │
│ │ TimescaleDB    │ │ │ TimescaleDB    │  │ │ TimescaleDB    │        │
│ │                │ │ │                │  │ │                │        │
│ │ (Cloud SQL)    │ │ │ (RDS)          │  │ │ (Azure DB)     │        │
│ └────────┬───────┘ │ └────────┬───────┘  │ └────────┬───────┘        │
│          │         │          │           │          │                │
│          ▼         │          ▼           │          ▼                │
│ ┌────────────────┐ │ ┌────────────────┐  │ ┌────────────────┐        │
│ │ GCP Services   │ │ │ AWS Services   │  │ │ Azure Services │        │
│ │                │ │ │                │  │ │                │        │
│ │ • Vertex AI    │ │ │ • Bedrock      │  │ │ • Azure OpenAI │        │
│ │ • Gemini       │ │ │ • Claude       │  │ │ • GPT-4        │        │
│ │ • Document AI  │ │ │ • SageMaker    │  │ │ • Cognitive Svc│        │
│ └────────────────┘ │ └────────────────┘  │ └────────────────┘        │
│                    │                      │                            │
└────────────────────┴──────────────────────┴────────────────────────────┘
```

---

## Cloud-Specific Deployments

Each cloud environment is **completely independent** with its own infrastructure stack. This provides:
- Failure isolation (GCP down doesn't affect AWS monitoring)
- Cloud-specific optimizations
- Independent scaling
- Separate cost attribution

### GCP Environment Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                      GCP MONITORING STACK                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Region: us-central1                                            │
│  Project: ai-cost-monitoring-gcp                                │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  GCP MCP Server (Cloud Run)                              │  │
│  │                                                           │  │
│  │  Endpoints:                                               │  │
│  │  • GET  /metrics/costs/daily                             │  │
│  │  • GET  /metrics/costs/hourly                            │  │
│  │  • GET  /metrics/tokens/{model}                          │  │
│  │  • GET  /metrics/customers/{customer_id}                 │  │
│  │  • GET  /health                                           │  │
│  │                                                           │  │
│  │  Prometheus Metrics Exposed:                             │  │
│  │  • gcp_llm_cost_usd_total                                │  │
│  │  • gcp_llm_tokens_total{model,type}                      │  │
│  │  • gcp_llm_requests_total{model,customer}                │  │
│  │  • gcp_vertex_ai_cost{service}                           │  │
│  └──────────────────┬───────────────────────────────────────┘  │
│                     │                                            │
│                     ▼                                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Prometheus Exporter (Cloud Run)                         │  │
│  │                                                           │  │
│  │  Queries TimescaleDB every 15s                           │  │
│  │  Converts DB data → Prometheus metrics                   │  │
│  └──────────────────┬───────────────────────────────────────┘  │
│                     │                                            │
│                     ▼                                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  TimescaleDB (Cloud SQL PostgreSQL 14)                   │  │
│  │                                                           │  │
│  │  Database: gcp_llm_costs                                 │  │
│  │  Table: llm_consumption                                  │  │
│  │  • Hypertable on timestamp                               │  │
│  │  • 30-day retention                                      │  │
│  │  • Automatic compression after 7 days                    │  │
│  └──────────────────┬───────────────────────────────────────┘  │
│                     │                                            │
│                     ▼                                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  ETL Pipeline (Cloud Function)                           │  │
│  │                                                           │  │
│  │  Trigger: Cloud Scheduler (daily 2 AM UTC)               │  │
│  │  Source: BigQuery Billing Export                         │  │
│  │  Processing:                                             │  │
│  │  • Extract Vertex AI costs                               │  │
│  │  • Parse model usage (Gemini, PaLM)                      │  │
│  │  • Calculate token counts                                │  │
│  │  • Write to TimescaleDB                                  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Infrastructure Cost: $70-100/month                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Deployment Commands:**

```bash
# Deploy GCP MCP Server
gcloud run deploy gcp-mcp-server \
  --image gcr.io/ai-cost-monitoring-gcp/mcp-server:latest \
  --region us-central1 \
  --memory 1Gi \
  --set-env-vars DB_HOST=gcp-llm-costs-db \
  --allow-unauthenticated

# Deploy Prometheus Exporter
gcloud run deploy gcp-prometheus-exporter \
  --image gcr.io/ai-cost-monitoring-gcp/prometheus-exporter:latest \
  --region us-central1 \
  --memory 512Mi \
  --set-env-vars DB_HOST=gcp-llm-costs-db \
  --port 8000

# Deploy ETL Function
gcloud functions deploy gcp-etl-pipeline \
  --runtime python310 \
  --trigger-topic gcp-billing-export \
  --entry-point process_gcp_billing \
  --memory 512MB \
  --set-env-vars DB_HOST=gcp-llm-costs-db
```

---

### AWS Environment Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                      AWS MONITORING STACK                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Region: us-east-1                                              │
│  Account: 123456789012                                          │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  AWS MCP Server (ECS Fargate)                            │  │
│  │                                                           │  │
│  │  Endpoints:                                               │  │
│  │  • GET  /metrics/costs/daily                             │  │
│  │  • GET  /metrics/costs/hourly                            │  │
│  │  • GET  /metrics/tokens/{model}                          │  │
│  │  • GET  /metrics/customers/{customer_id}                 │  │
│  │  • GET  /health                                           │  │
│  │                                                           │  │
│  │  Prometheus Metrics Exposed:                             │  │
│  │  • aws_llm_cost_usd_total                                │  │
│  │  • aws_llm_tokens_total{model,type}                      │  │
│  │  • aws_llm_requests_total{model,customer}                │  │
│  │  • aws_bedrock_cost{service}                             │  │
│  └──────────────────┬───────────────────────────────────────┘  │
│                     │                                            │
│                     ▼                                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Prometheus Exporter (ECS Fargate)                       │  │
│  │                                                           │  │
│  │  Queries TimescaleDB every 15s                           │  │
│  │  Converts DB data → Prometheus metrics                   │  │
│  └──────────────────┬───────────────────────────────────────┘  │
│                     │                                            │
│                     ▼                                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  TimescaleDB (RDS PostgreSQL 14)                         │  │
│  │                                                           │  │
│  │  Database: aws_llm_costs                                 │  │
│  │  Instance: db.t3.micro                                   │  │
│  │  • Hypertable on timestamp                               │  │
│  │  • 30-day retention                                      │  │
│  │  • Automatic backups                                     │  │
│  └──────────────────┬───────────────────────────────────────┘  │
│                     │                                            │
│                     ▼                                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  ETL Pipeline (Lambda Function)                          │  │
│  │                                                           │  │
│  │  Trigger: EventBridge (daily 2 AM UTC)                   │  │
│  │  Source: AWS Cost Explorer API                           │  │
│  │  Processing:                                             │  │
│  │  • Extract Bedrock costs                                 │  │
│  │  • Parse model usage (Claude, Titan)                     │  │
│  │  • Calculate token counts                                │  │
│  │  • Write to TimescaleDB                                  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Infrastructure Cost: $90-130/month                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Deployment (Terraform):**

```hcl
# AWS MCP Server
resource "aws_ecs_service" "aws_mcp_server" {
  name            = "aws-mcp-server"
  cluster         = aws_ecs_cluster.monitoring.id
  task_definition = aws_ecs_task_definition.mcp_server.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnets
    security_groups = [aws_security_group.mcp_server.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.mcp_server.arn
    container_name   = "mcp-server"
    container_port   = 8000
  }
}

# Lambda ETL Function
resource "aws_lambda_function" "aws_etl" {
  function_name = "aws-llm-cost-etl"
  role          = aws_iam_role.lambda_etl.arn
  handler       = "index.handler"
  runtime       = "python3.10"
  timeout       = 300
  memory_size   = 512

  environment {
    variables = {
      DB_HOST = aws_db_instance.timescaledb.endpoint
    }
  }
}
```

---

### Azure Environment Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                     AZURE MONITORING STACK                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Region: eastus                                                 │
│  Subscription: ai-cost-monitoring-azure                         │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Azure MCP Server (Container App)                        │  │
│  │                                                           │  │
│  │  Endpoints:                                               │  │
│  │  • GET  /metrics/costs/daily                             │  │
│  │  • GET  /metrics/costs/hourly                            │  │
│  │  • GET  /metrics/tokens/{model}                          │  │
│  │  • GET  /metrics/customers/{customer_id}                 │  │
│  │  • GET  /health                                           │  │
│  │                                                           │  │
│  │  Prometheus Metrics Exposed:                             │  │
│  │  • azure_llm_cost_usd_total                              │  │
│  │  • azure_llm_tokens_total{model,type}                    │  │
│  │  • azure_llm_requests_total{model,customer}              │  │
│  │  • azure_openai_cost{service}                            │  │
│  └──────────────────┬───────────────────────────────────────┘  │
│                     │                                            │
│                     ▼                                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Prometheus Exporter (Container App)                     │  │
│  │                                                           │  │
│  │  Queries TimescaleDB every 15s                           │  │
│  │  Converts DB data → Prometheus metrics                   │  │
│  └──────────────────┬───────────────────────────────────────┘  │
│                     │                                            │
│                     ▼                                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  TimescaleDB (Azure Database for PostgreSQL)            │  │
│  │                                                           │  │
│  │  Database: azure_llm_costs                               │  │
│  │  Tier: Basic                                             │  │
│  │  • Hypertable on timestamp                               │  │
│  │  • 30-day retention                                      │  │
│  │  • Geo-redundant backups                                 │  │
│  └──────────────────┬───────────────────────────────────────┘  │
│                     │                                            │
│                     ▼                                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  ETL Pipeline (Function App)                             │  │
│  │                                                           │  │
│  │  Trigger: Timer Trigger (daily 2 AM UTC)                 │  │
│  │  Source: Azure Cost Management API                       │  │
│  │  Processing:                                             │  │
│  │  • Extract Azure OpenAI costs                            │  │
│  │  • Parse model usage (GPT-4, GPT-3.5)                    │  │
│  │  • Calculate token counts                                │  │
│  │  • Write to TimescaleDB                                  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Infrastructure Cost: $80-120/month                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Unified Monitoring Layer

The **central monitoring layer** runs in a single location (recommend: same region as your primary cloud) and aggregates data from all cloud MCP servers.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│              UNIFIED MONITORING LAYER                            │
│              (Deployed on Primary Cloud - e.g., GCP)            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │             Grafana (Cloud Run)                          │  │
│  │                                                           │  │
│  │  Data Sources:                                            │  │
│  │  • Prometheus (GCP) - gcp-prometheus-exporter:8000       │  │
│  │  • Prometheus (AWS) - aws-prometheus-exporter:8000       │  │
│  │  • Prometheus (Azure) - azure-prometheus-exporter:8000   │  │
│  │                                                           │  │
│  │  Dashboards:                                              │  │
│  │  • Multi-Cloud Cost Overview                             │  │
│  │  • Per-Cloud Deep Dive                                   │  │
│  │  • Cross-Cloud Model Comparison                          │  │
│  │  • Tenant Cloud Selection                                │  │
│  └──────────────────┬───────────────────────────────────────┘  │
│                     │                                            │
│                     ▼                                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │         Central Prometheus (Aggregator)                  │  │
│  │                                                           │  │
│  │  Federation Configuration:                                │  │
│  │  • Scrapes GCP Prometheus Exporter                       │  │
│  │  • Scrapes AWS Prometheus Exporter                       │  │
│  │  • Scrapes Azure Prometheus Exporter                     │  │
│  │  • Relabels metrics with cloud_provider label            │  │
│  │  • 30-day retention                                      │  │
│  └──────────────────┬───────────────────────────────────────┘  │
│                     │                                            │
│                     ▼                                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Cloud Registry Database                      │  │
│  │              (PostgreSQL)                                 │  │
│  │                                                           │  │
│  │  Tables:                                                  │  │
│  │  • cloud_environments                                     │  │
│  │  • tenant_cloud_config                                    │  │
│  │  • mcp_server_endpoints                                  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Infrastructure Cost: $50-80/month                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Central Prometheus Federation Config

```yaml
# prometheus.yml (Central Prometheus)
global:
  scrape_interval: 15s
  external_labels:
    cluster: 'unified-monitoring'

scrape_configs:
  # GCP Prometheus Exporter
  - job_name: 'gcp-llm-costs'
    static_configs:
      - targets: ['gcp-prometheus-exporter-xxxxx.run.app:8000']
    relabel_configs:
      - target_label: cloud_provider
        replacement: 'gcp'
    metric_relabel_configs:
      - source_labels: [__name__]
        regex: 'gcp_llm_(.*)'
        target_label: __name__
        replacement: 'llm_${1}'
  
  # AWS Prometheus Exporter
  - job_name: 'aws-llm-costs'
    static_configs:
      - targets: ['aws-mcp-server.us-east-1.elb.amazonaws.com:8000']
    relabel_configs:
      - target_label: cloud_provider
        replacement: 'aws'
    metric_relabel_configs:
      - source_labels: [__name__]
        regex: 'aws_llm_(.*)'
        target_label: __name__
        replacement: 'llm_${1}'
  
  # Azure Prometheus Exporter
  - job_name: 'azure-llm-costs'
    static_configs:
      - targets: ['azure-mcp-server.azurecontainerapps.io:8000']
    relabel_configs:
      - target_label: cloud_provider
        replacement: 'azure'
    metric_relabel_configs:
      - source_labels: [__name__]
        regex: 'azure_llm_(.*)'
        target_label: __name__
        replacement: 'llm_${1}'
```

### Cloud Registry Database Schema

```sql
-- Cloud environments registry
CREATE TABLE cloud_environments (
  id SERIAL PRIMARY KEY,
  cloud_provider VARCHAR(20) NOT NULL UNIQUE, -- 'gcp', 'aws', 'azure'
  mcp_server_url VARCHAR(255) NOT NULL,
  prometheus_endpoint VARCHAR(255) NOT NULL,
  health_check_url VARCHAR(255) NOT NULL,
  is_enabled BOOLEAN DEFAULT true,
  last_health_check TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tenant cloud configuration (multi-tenant support)
CREATE TABLE tenant_cloud_config (
  id SERIAL PRIMARY KEY,
  tenant_id VARCHAR(100) NOT NULL,
  cloud_provider VARCHAR(20) NOT NULL,
  is_enabled BOOLEAN DEFAULT true,
  cost_quota_monthly DECIMAL(10,2),
  alert_threshold DECIMAL(10,2),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(tenant_id, cloud_provider),
  FOREIGN KEY (cloud_provider) REFERENCES cloud_environments(cloud_provider)
);

-- MCP server endpoints catalog
CREATE TABLE mcp_server_endpoints (
  id SERIAL PRIMARY KEY,
  cloud_provider VARCHAR(20) NOT NULL,
  endpoint_path VARCHAR(255) NOT NULL,
  method VARCHAR(10) NOT NULL,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  
  FOREIGN KEY (cloud_provider) REFERENCES cloud_environments(cloud_provider)
);

-- Insert cloud environments
INSERT INTO cloud_environments (cloud_provider, mcp_server_url, prometheus_endpoint, health_check_url)
VALUES
  ('gcp', 'https://gcp-mcp-server-xxxxx.run.app', 'https://gcp-prometheus-exporter-xxxxx.run.app:8000/metrics', 'https://gcp-mcp-server-xxxxx.run.app/health'),
  ('aws', 'https://aws-mcp-server.us-east-1.elb.amazonaws.com', 'https://aws-mcp-server.us-east-1.elb.amazonaws.com:8000/metrics', 'https://aws-mcp-server.us-east-1.elb.amazonaws.com/health'),
  ('azure', 'https://azure-mcp-server.azurecontainerapps.io', 'https://azure-mcp-server.azurecontainerapps.io:8000/metrics', 'https://azure-mcp-server.azurecontainerapps.io/health');
```

---

## MCP Server Integration

Each MCP server exposes **standardized endpoints** for Grafana to query. This ensures consistency across clouds.

### Standardized MCP Server API

```
┌─────────────────────────────────────────────────────────────────┐
│                  MCP SERVER API CONTRACT                         │
│                  (Same for GCP, AWS, Azure)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Base URL: https://{cloud}-mcp-server.{domain}                 │
│                                                                  │
│  ENDPOINTS:                                                      │
│                                                                  │
│  1. GET /metrics/costs/daily                                    │
│     Query params: ?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD   │
│     Returns: Daily cost aggregates                              │
│                                                                  │
│  2. GET /metrics/costs/hourly                                   │
│     Query params: ?start_time=ISO8601&end_time=ISO8601         │
│     Returns: Hourly cost data                                   │
│                                                                  │
│  3. GET /metrics/tokens/{model}                                 │
│     Path param: model (e.g., gemini-pro, claude-v2)            │
│     Returns: Token usage for specific model                     │
│                                                                  │
│  4. GET /metrics/customers/{customer_id}                        │
│     Path param: customer_id                                     │
│     Returns: All metrics for specific customer                  │
│                                                                  │
│  5. GET /metrics/models/compare                                 │
│     Query params: ?models=model1,model2,model3                 │
│     Returns: Comparative metrics                                │
│                                                                  │
│  6. GET /health                                                 │
│     Returns: Health status + database connection                │
│                                                                  │
│  7. GET /metrics (Prometheus format)                            │
│     Returns: Prometheus-formatted metrics                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Example Response Formats

**GET /metrics/costs/daily**
```json
{
  "cloud_provider": "gcp",
  "data": [
    {
      "date": "2026-02-04",
      "total_cost": 1234.56,
      "by_service": {
        "vertex_ai": 800.00,
        "document_ai": 234.56,
        "vision_ai": 200.00
      },
      "by_model": {
        "gemini-pro": 500.00,
        "gemini-flash": 300.00,
        "palm-2": 234.56
      }
    }
  ]
}
```

**GET /metrics (Prometheus format)**
```
# HELP llm_cost_usd_total Total LLM cost in USD
# TYPE llm_cost_usd_total counter
llm_cost_usd_total{cloud_provider="gcp",model="gemini-pro",customer="cust_001"} 1234.56
llm_cost_usd_total{cloud_provider="gcp",model="gemini-flash",customer="cust_001"} 567.89

# HELP llm_tokens_total Total tokens consumed
# TYPE llm_tokens_total counter
llm_tokens_total{cloud_provider="gcp",model="gemini-pro",type="input"} 1500000
llm_tokens_total{cloud_provider="gcp",model="gemini-pro",type="output"} 500000

# HELP llm_requests_total Total LLM requests
# TYPE llm_requests_total counter
llm_requests_total{cloud_provider="gcp",model="gemini-pro"} 15000
```

---

## Multi-Tenant Cloud Selection

Allow tenants to enable/disable specific cloud providers based on their usage.

### Tenant Cloud Configuration API

```python
# FastAPI endpoint for tenant cloud management
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import psycopg2

app = FastAPI()

class TenantCloudConfig(BaseModel):
    tenant_id: str
    cloud_provider: str
    is_enabled: bool
    cost_quota_monthly: float
    alert_threshold: float

@app.get("/tenants/{tenant_id}/clouds")
async def get_tenant_clouds(tenant_id: str):
    """Get enabled clouds for a tenant"""
    conn = get_db_connection()
    cur = conn.cursor()
    
    cur.execute("""
        SELECT 
            tcc.cloud_provider,
            tcc.is_enabled,
            tcc.cost_quota_monthly,
            ce.mcp_server_url,
            ce.is_enabled as cloud_available
        FROM tenant_cloud_config tcc
        JOIN cloud_environments ce ON tcc.cloud_provider = ce.cloud_provider
        WHERE tcc.tenant_id = %s
    """, (tenant_id,))
    
    clouds = []
    for row in cur.fetchall():
        clouds.append({
            "cloud_provider": row[0],
            "is_enabled": row[1] and row[4],  # Both tenant and cloud must be enabled
            "cost_quota_monthly": row[2],
            "mcp_server_url": row[3]
        })
    
    return {"tenant_id": tenant_id, "clouds": clouds}

@app.post("/tenants/{tenant_id}/clouds/{cloud_provider}/enable")
async def enable_cloud(tenant_id: str, cloud_provider: str):
    """Enable a cloud provider for a tenant"""
    conn = get_db_connection()
    cur = conn.cursor()
    
    cur.execute("""
        UPDATE tenant_cloud_config
        SET is_enabled = true, updated_at = NOW()
        WHERE tenant_id = %s AND cloud_provider = %s
    """, (tenant_id, cloud_provider))
    
    conn.commit()
    return {"status": "enabled", "tenant_id": tenant_id, "cloud_provider": cloud_provider}

@app.post("/tenants/{tenant_id}/clouds/{cloud_provider}/disable")
async def disable_cloud(tenant_id: str, cloud_provider: str):
    """Disable a cloud provider for a tenant"""
    conn = get_db_connection()
    cur = conn.cursor()
    
    cur.execute("""
        UPDATE tenant_cloud_config
        SET is_enabled = false, updated_at = NOW()
        WHERE tenant_id = %s AND cloud_provider = %s
    """, (tenant_id, cloud_provider))
    
    conn.commit()
    return {"status": "disabled", "tenant_id": tenant_id, "cloud_provider": cloud_provider}
```

### Grafana Dashboard Variable Configuration

```json
{
  "templating": {
    "list": [
      {
        "name": "tenant_id",
        "type": "query",
        "datasource": "PostgreSQL",
        "query": "SELECT DISTINCT tenant_id FROM tenant_cloud_config ORDER BY tenant_id",
        "refresh": 1,
        "includeAll": false
      },
      {
        "name": "enabled_clouds",
        "type": "query",
        "datasource": "PostgreSQL",
        "query": "SELECT cloud_provider FROM tenant_cloud_config WHERE tenant_id = '$tenant_id' AND is_enabled = true",
        "refresh": 1,
        "multi": true,
        "includeAll": true
      }
    ]
  }
}
```

---

## Dashboard Configuration

### Multi-Cloud Cost Overview Dashboard

**Purpose:** Single pane of glass for all cloud LLM costs

**Panels:**

1. **Total Cost Across All Clouds (Stat)**
```promql
sum(llm_cost_usd_total{cloud_provider=~"$enabled_clouds"})
```

2. **Cost by Cloud Provider (Pie Chart)**
```promql
sum by (cloud_provider) (
  increase(llm_cost_usd_total{cloud_provider=~"$enabled_clouds"}[30d])
)
```

3. **Cost Trend by Cloud (Time Series)**
```promql
sum by (cloud_provider) (
  rate(llm_cost_usd_total{cloud_provider=~"$enabled_clouds"}[1h])
)
```

4. **Top Models Across Clouds (Bar Chart)**
```promql
topk(10, 
  sum by (model, cloud_provider) (
    increase(llm_cost_usd_total{cloud_provider=~"$enabled_clouds"}[30d])
  )
)
```

5. **Cost Distribution Heatmap**
```promql
sum by (cloud_provider, model) (
  increase(llm_cost_usd_total{cloud_provider=~"$enabled_clouds"}[7d])
)
```

**Variables:**
- `$tenant_id` - Select tenant
- `$enabled_clouds` - Auto-populated based on tenant's enabled clouds
- `$timerange` - Time range selector

---

### Per-Cloud Deep Dive Dashboard

**Purpose:** Detailed metrics for a specific cloud provider

**Panels:**

1. **Cloud Selector (Dropdown)**
Variable: `$cloud_provider` (gcp|aws|azure)

2. **Cloud-Specific Metrics**
```promql
# GCP: Vertex AI service breakdown
sum by (service) (
  increase(llm_cost_usd_total{cloud_provider="gcp"}[30d])
)

# AWS: Bedrock model breakdown  
sum by (model) (
  increase(llm_cost_usd_total{cloud_provider="aws"}[30d])
)

# Azure: Azure OpenAI deployment breakdown
sum by (deployment) (
  increase(llm_cost_usd_total{cloud_provider="azure"}[30d])
)
```

3. **Token Usage by Model**
```promql
sum by (model, type) (
  rate(llm_tokens_total{cloud_provider="$cloud_provider"}[5m])
)
```

4. **Cost per 1K Tokens (Table)**
```sql
-- Query via PostgreSQL data source
SELECT 
  model,
  SUM(cost_usd) / (SUM(total_tokens) / 1000) as cost_per_1k_tokens,
  SUM(total_tokens) as total_tokens
FROM llm_consumption
WHERE cloud_provider = '$cloud_provider'
  AND timestamp > NOW() - INTERVAL '30 days'
GROUP BY model
ORDER BY cost_per_1k_tokens DESC
```

---

### Cross-Cloud Model Comparison Dashboard

**Purpose:** Compare same models across different clouds

**Example: Compare GPT-4 across Azure vs Claude across AWS**

**Panels:**

1. **Model Cost Comparison (Bar Chart)**
```promql
sum by (cloud_provider, model) (
  increase(llm_cost_usd_total{
    cloud_provider=~"$enabled_clouds",
    model=~"gpt-4|claude-v2|gemini-pro"
  }[30d])
)
```

2. **Cost per 1K Tokens Comparison (Table)**
```sql
SELECT 
  cloud_provider,
  model,
  SUM(cost_usd) / (SUM(total_tokens) / 1000) as cost_per_1k_tokens
FROM llm_consumption
WHERE model IN ('gpt-4', 'claude-v2', 'gemini-pro')
  AND timestamp > NOW() - INTERVAL '30 days'
GROUP BY cloud_provider, model
ORDER BY cost_per_1k_tokens ASC
```

3. **Latency Comparison (if available)**
```promql
histogram_quantile(0.95,
  sum by (cloud_provider, model, le) (
    rate(llm_latency_seconds_bucket{
      cloud_provider=~"$enabled_clouds"
    }[5m])
  )
)
```

---

## Data Flow

### Complete Multi-Cloud Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    DATA FLOW - MULTI-CLOUD                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  STEP 1: Cloud Billing Data Generation                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ GCP BigQuery │  │ AWS Cost     │  │ Azure Cost   │          │
│  │   Billing    │  │  Explorer    │  │  Management  │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                  │                  │                  │
│         ▼                  ▼                  ▼                  │
│  STEP 2: ETL Processing (Per Cloud)                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ GCP Cloud    │  │ AWS Lambda   │  │ Azure        │          │
│  │ Function     │  │              │  │ Function App │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                  │                  │                  │
│         ▼                  ▼                  ▼                  │
│  STEP 3: Cloud-Specific Databases                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ GCP          │  │ AWS          │  │ Azure        │          │
│  │ TimescaleDB  │  │ TimescaleDB  │  │ TimescaleDB  │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                  │                  │                  │
│         ▼                  ▼                  ▼                  │
│  STEP 4: Prometheus Exporters (Per Cloud)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ GCP Prom     │  │ AWS Prom     │  │ Azure Prom   │          │
│  │ Exporter     │  │ Exporter     │  │ Exporter     │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                  │                  │                  │
│         │ /metrics         │ /metrics         │ /metrics         │
│         │                  │                  │                  │
│         └──────────────────┴──────────────────┘                  │
│                            │                                     │
│                            ▼                                     │
│  STEP 5: Central Prometheus (Federation)                        │
│         ┌─────────────────────────────────────┐                 │
│         │   Scrapes all 3 Prometheus          │                 │
│         │   Exporters every 15s               │                 │
│         │   • Adds cloud_provider label       │                 │
│         │   • Normalizes metric names         │                 │
│         │   • 30-day retention                │                 │
│         └──────────────┬──────────────────────┘                 │
│                        │                                         │
│                        ▼                                         │
│  STEP 6: Unified Grafana Dashboards                             │
│         ┌─────────────────────────────────────┐                 │
│         │   Queries Central Prometheus        │                 │
│         │   • Filter by cloud_provider        │                 │
│         │   • Aggregate across clouds         │                 │
│         │   • Customer-specific views         │                 │
│         └─────────────────────────────────────┘                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Guide

### Phase 1: Deploy Cloud Environments (Weeks 1-3)

**Week 1: GCP Environment**

```bash
# 1. Create GCP project
gcloud projects create ai-cost-monitoring-gcp

# 2. Deploy TimescaleDB
gcloud sql instances create gcp-llm-costs-db \
  --database-version=POSTGRES_14 \
  --tier=db-f1-micro \
  --region=us-central1

# 3. Deploy MCP Server
gcloud run deploy gcp-mcp-server \
  --image gcr.io/ai-cost-monitoring-gcp/mcp-server:latest \
  --region us-central1

# 4. Deploy Prometheus Exporter
gcloud run deploy gcp-prometheus-exporter \
  --image gcr.io/ai-cost-monitoring-gcp/prometheus-exporter:latest \
  --region us-central1

# 5. Deploy ETL Function
gcloud functions deploy gcp-etl-pipeline \
  --runtime python310 \
  --trigger-topic gcp-billing-export
```

**Week 2: AWS Environment**

```bash
# Use Terraform for AWS deployment
cd terraform/aws
terraform init
terraform plan -out=aws.plan
terraform apply aws.plan
```

**Week 3: Azure Environment**

```bash
# Use Azure CLI
az group create --name ai-cost-monitoring-rg --location eastus
az containerapp create --name azure-mcp-server ...
az postgres flexible-server create --name azure-llm-costs-db ...
```

---

### Phase 2: Deploy Unified Monitoring (Week 4)

**1. Deploy Central Prometheus**

```bash
gcloud run deploy central-prometheus \
  --image gcr.io/ai-cost-monitoring-gcp/prometheus-federated:latest \
  --region us-central1 \
  --memory 2Gi
```

**2. Deploy Grafana**

```bash
gcloud run deploy unified-grafana \
  --image grafana/grafana:latest \
  --region us-central1 \
  --memory 1Gi
```

**3. Configure Cloud Registry Database**

```bash
# Create database
gcloud sql databases create cloud_registry \
  --instance=unified-monitoring-db

# Run schema
psql -h <db-host> -U postgres -d cloud_registry -f schema.sql

# Insert cloud environments
psql -h <db-host> -U postgres -d cloud_registry -f insert_clouds.sql
```

---

### Phase 3: Import Dashboards (Week 5)

```bash
# Import multi-cloud dashboards
for dashboard in dashboards/*.json; do
  curl -X POST http://grafana:3000/api/dashboards/db \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $GRAFANA_API_KEY" \
    -d @$dashboard
done
```

---

### Phase 4: Testing & Validation (Week 6)

**1. Verify all MCP servers are healthy**

```bash
curl https://gcp-mcp-server.run.app/health
curl https://aws-mcp-server.elb.amazonaws.com/health
curl https://azure-mcp-server.azurecontainerapps.io/health
```

**2. Verify Prometheus scraping**

```bash
# Check targets
curl http://central-prometheus:9090/api/v1/targets
```

**3. Test tenant cloud enable/disable**

```bash
# Disable Azure for tenant
curl -X POST http://unified-api/tenants/cust_001/clouds/azure/disable

# Verify dashboard only shows GCP + AWS data
```

---

## Cost Summary

| Component | GCP | AWS | Azure | Unified | Total/Month |
|-----------|-----|-----|-------|---------|-------------|
| MCP Server | $15-25 | $20-30 | $18-28 | - | $53-83 |
| Prometheus Exporter | $10-15 | $12-18 | $11-16 | - | $33-49 |
| TimescaleDB | $30-50 | $35-55 | $32-52 | - | $97-157 |
| ETL Pipeline | $5-10 | $8-12 | $6-10 | - | $19-32 |
| **Per-Cloud Total** | $70-100 | $90-130 | $80-120 | - | $240-350 |
| Central Prometheus | - | - | - | $20-30 | $20-30 |
| Grafana | - | - | - | $10-20 | $10-20 |
| Cloud Registry DB | - | - | - | $20-30 | $20-30 |
| **Grand Total** | | | | | **$290-430/month** |

---

**Document End**
