# AI Cost Monitoring - Cloud Deployment Architecture
## Grafana + Prometheus + Loki Stack

**Document Version:** 1.0  
**Last Updated:** February 2026  
**Target Deployment:** GCP Cloud Run, AWS ECS/Fargate, Azure Container Instances

---

## Executive Summary

This document provides the complete architecture for deploying the AI Cost Monitoring observability stack on cloud platforms (GCP, AWS, Azure). The stack uses:
- **Grafana** for visualization
- **Prometheus** for metrics storage
- **Loki** for log aggregation  
- **TimescaleDB** for historical cost data
- **Cloud-native log forwarding** (no Promtail needed on serverless)

**Key Decision:** Use native cloud logging services with serverless functions to forward to Loki, rather than deploying Promtail agents.

**Total Infrastructure Cost:** $80-200/month depending on cloud provider and configuration

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Component Stack](#2-component-stack)
3. [GCP Deployment](#3-gcp-deployment)
4. [AWS Deployment](#4-aws-deployment)
5. [Azure Deployment](#5-azure-deployment)
6. [Log Collection Strategy](#6-log-collection-strategy)
7. [Configuration Files](#7-configuration-files)
8. [Dashboard Structure](#8-dashboard-structure)
9. [Alerting Rules](#9-alerting-rules)
10. [Cost Estimates](#10-cost-estimates)

---

## 1. Architecture Overview

### Three-Layer Observability Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    LAYER 3: VISUALIZATION                            │
│                         Grafana Dashboards                           │
│  • Multi-Cloud LLM Costs  • Token Usage  • System Health            │
└──────────────────┬──────────────────────────────────────────────────┘
                   │
┌──────────────────┴───────────────────────────────────────────────────┐
│                LAYER 2: STORAGE & AGGREGATION                        │
│                                                                       │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │   Prometheus     │  │      Loki        │  │  TimescaleDB     │  │
│  │   (Metrics)      │  │     (Logs)       │  │  (Cost Data)     │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘  │
└──────────────────┬────────────────┬──────────────────┬──────────────┘
                   │                │                  │
┌──────────────────┴────────────────┴──────────────────┴──────────────┐
│                    LAYER 1: DATA COLLECTION                          │
│                                                                       │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │ Prometheus       │  │ Cloud Logging    │  │  ETL Pipeline    │  │
│  │ /metrics         │  │ → Serverless Fn  │  │  (Billing APIs)  │  │
│  │ Exporters        │  │ → Loki           │  │                  │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘  │
└───────────────────────────────────────────────────────────────────────┘
```

### Data Flow Summary

| Data Type | Source | Collection Method | Storage | Queried By |
|-----------|--------|-------------------|---------|------------|
| **Metrics** | App /metrics endpoints | Prometheus scrapes every 15s | Prometheus TSDB | Grafana (PromQL) |
| **Logs** | App stdout/stderr | Cloud Logging → Function → Loki | Loki (compressed chunks) | Grafana (LogQL) |
| **Cost Data** | Cloud billing APIs | ETL pipeline (daily/hourly) | TimescaleDB | Grafana (SQL) + MCP Agent |

---

## 2. Component Stack

### Core Components

| Component | Version | Purpose | Deployment | Port | Storage Needs |
|-----------|---------|---------|-----------|------|---------------|
| **Grafana** | 10.x+ | Dashboards & visualization | Cloud Run/Fargate/ACI | 3000 | ~500MB |
| **Prometheus** | 2.48+ | Metrics TSDB | VM/EC2/GCE | 9090 | ~10GB (15 days) |
| **Loki** | 2.9+ | Log aggregation | VM/EC2/GCE | 3100 | ~20GB (30 days) |
| **TimescaleDB** | 2.13+ | Historical cost data | Managed PostgreSQL | 5432 | ~50GB (2 years) |

### Supporting Components

| Component | When Used | Purpose |
|-----------|-----------|---------|
| **Cloud Function/Lambda** | GCP/AWS/Azure | Forward logs from native logging to Loki |
| **Pub/Sub/EventBridge** | GCP/AWS/Azure | Event routing for log forwarding |
| **Alertmanager** | Optional | Alert routing to Slack/PagerDuty |

### Why No Promtail on Cloud Platforms

| Platform | Why No Promtail | Alternative |
|----------|-----------------|-------------|
| **Cloud Run** | Ephemeral, no persistent disk | Cloud Logging → Cloud Function → Loki |
| **ECS Fargate** | Serverless, no SSH access | CloudWatch → Lambda → Loki |
| **Azure ACI** | Container instances are stateless | Log Analytics → Azure Function → Loki |

**Promtail is only needed for VM/bare metal deployments where you tail log files directly.**

---

## 3. GCP Deployment

### 3.1 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        GCP PROJECT                               │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Cloud Run Services                          │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │   │
│  │  │ Cost Monitor │  │   Grafana    │  │  Prometheus  │  │   │
│  │  │ MCP Server   │  │              │  │   Exporter   │  │   │
│  │  │ Logs→stdout  │  │ Port 3000    │  │ /metrics     │  │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │   │
│  └─────────┬───────────────┬──────────────────┬───────────┘   │
│            │               │                  │               │
│            ↓               ↓                  ↓               │
│  ┌──────────────────────────────────────────────────────┐     │
│  │         Cloud Logging (automatic capture)            │     │
│  └────────────────────────┬─────────────────────────────┘     │
│                           │                                   │
│                           ↓                                   │
│  ┌──────────────────────────────────────────────────────┐     │
│  │    Log Router Sink → Pub/Sub: logs-to-loki          │     │
│  └────────────────────────┬─────────────────────────────┘     │
│                           │                                   │
│                           ↓                                   │
│  ┌──────────────────────────────────────────────────────┐     │
│  │  Cloud Function: forward-logs-to-loki                │     │
│  │  • Triggered by Pub/Sub                              │     │
│  │  • Reformats for Loki                                │     │
│  │  • POST to Loki HTTP API                             │     │
│  └────────────────────────┬─────────────────────────────┘     │
│                           │                                   │
└───────────────────────────┼───────────────────────────────────┘
                            │
                            ↓
                ┌───────────────────────┐
                │  Loki on GCE VM       │
                │  Port 3100            │
                └───────────────────────┘
```

### 3.2 Deployment Steps

**Step 1: Deploy Monitoring Stack**

```bash
# Set project
gcloud config set project YOUR_PROJECT_ID

# Deploy Grafana (Cloud Run)
gcloud run deploy grafana \
  --image=grafana/grafana:latest \
  --platform=managed \
  --region=us-central1 \
  --memory=1Gi \
  --cpu=1 \
  --port=3000 \
  --allow-unauthenticated \
  --set-env-vars=GF_SERVER_ROOT_URL=https://grafana-xyz.run.app

# Create Prometheus VM
gcloud compute instances create prometheus \
  --machine-type=e2-medium \
  --zone=us-central1-a \
  --image-family=ubuntu-2004-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=50GB \
  --tags=prometheus-server

# Create Loki VM
gcloud compute instances create loki \
  --machine-type=e2-medium \
  --zone=us-central1-a \
  --image-family=ubuntu-2004-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=100GB \
  --tags=loki-server

# Create Cloud SQL (TimescaleDB)
gcloud sql instances create cost-monitoring-db \
  --database-version=POSTGRES_14 \
  --tier=db-f1-micro \
  --region=us-central1 \
  --storage-size=50GB

# Enable TimescaleDB extension
gcloud sql databases create cost_monitoring --instance=cost-monitoring-db
```

**Step 2: Set Up Log Forwarding**

```bash
# Create Pub/Sub topic
gcloud pubsub topics create logs-to-loki

# Create log sink
gcloud logging sinks create cloud-run-to-loki \
  pubsub.googleapis.com/projects/YOUR_PROJECT/topics/logs-to-loki \
  --log-filter='resource.type="cloud_run_revision" AND resource.labels.service_name=~"cost-monitor.*"'

# Deploy Cloud Function
cd cloud-function-log-forwarder
gcloud functions deploy forward-logs-to-loki \
  --runtime=python311 \
  --trigger-topic=logs-to-loki \
  --entry-point=forward_to_loki \
  --memory=256MB \
  --timeout=60s \
  --set-env-vars=LOKI_URL=http://LOKI_INTERNAL_IP:3100
```

**Step 3: Install Prometheus & Loki on VMs**

```bash
# SSH to Prometheus VM
gcloud compute ssh prometheus --zone=us-central1-a

# Install Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v2.48.0/prometheus-2.48.0.linux-amd64.tar.gz
tar xvf prometheus-2.48.0.linux-amd64.tar.gz
sudo mv prometheus-2.48.0.linux-amd64 /opt/prometheus
sudo useradd --no-create-home --shell /bin/false prometheus
sudo chown -R prometheus:prometheus /opt/prometheus

# Create systemd service
sudo tee /etc/systemd/system/prometheus.service << EOL
[Unit]
Description=Prometheus
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/opt/prometheus/prometheus \
  --config.file=/opt/prometheus/prometheus.yml \
  --storage.tsdb.path=/opt/prometheus/data \
  --web.listen-address=:9090

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl enable prometheus
sudo systemctl start prometheus

# Similar steps for Loki on the Loki VM...
```

### 3.3 Cloud Function Code (Python)

```python
# main.py
import base64
import json
import requests
import os
from datetime import datetime

LOKI_URL = os.environ.get('LOKI_URL')

def forward_to_loki(event, context):
    """Forward Cloud Logging to Loki"""
    
    # Decode Pub/Sub message
    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
    log_entry = json.loads(pubsub_message)
    
    # Extract fields
    timestamp = log_entry.get('timestamp', datetime.utcnow().isoformat())
    severity = log_entry.get('severity', 'INFO')
    message = log_entry.get('textPayload') or json.dumps(log_entry.get('jsonPayload', {}))
    
    # Extract labels from resource
    resource = log_entry.get('resource', {})
    labels = resource.get('labels', {})
    
    # Convert timestamp to nanoseconds
    dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
    timestamp_ns = str(int(dt.timestamp() * 1e9))
    
    # Format for Loki
    loki_payload = {
        "streams": [{
            "stream": {
                "job": "cloud_run",
                "service": labels.get('service_name', 'unknown'),
                "revision": labels.get('revision_name', 'unknown'),
                "severity": severity.lower(),
                "project": labels.get('project_id', 'unknown')
            },
            "values": [[timestamp_ns, message]]
        }]
    }
    
    # Send to Loki
    try:
        response = requests.post(f"{LOKI_URL}/loki/api/v1/push", json=loki_payload)
        response.raise_for_status()
        print(f"✓ Forwarded {severity} log to Loki")
    except Exception as e:
        print(f"✗ Error forwarding to Loki: {e}")

# requirements.txt
# requests==2.31.0
```

### 3.4 GCP-Specific Configuration

**prometheus.yml additions for GCP:**
```yaml
scrape_configs:
  # GCP Cloud Run services
  - job_name: 'gcp-cloud-run'
    static_configs:
      - targets:
        - 'cost-monitor-xyz-uc.a.run.app:443'
        - 'prometheus-exporter-xyz-uc.a.run.app:443'
    scheme: https
    metrics_path: '/metrics'
```

### 3.5 GCP Cost Estimate

| Component | Service | Configuration | Monthly Cost |
|-----------|---------|---------------|--------------|
| Grafana | Cloud Run | 1 vCPU, 1GB RAM, always-on | $15 |
| Prometheus | GCE e2-medium | 2 vCPU, 4GB RAM, 50GB SSD | $35 |
| Loki | GCE e2-medium | 2 vCPU, 4GB RAM, 100GB SSD | $45 |
| TimescaleDB | Cloud SQL | db-f1-micro, 50GB | $30 |
| Cloud Function | Gen 2 | 1M invocations/mo | $5 |
| Pub/Sub | Messaging | 100GB/mo | $2 |
| Load Balancer | Cloud Load Balancing | 1 forwarding rule | $18 |
| Network Egress | Data transfer | 100GB/mo | $12 |
| **TOTAL** | | | **$162/mo** |

---

## 4. AWS Deployment

### 4.1 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS ACCOUNT                               │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              ECS Fargate Tasks                           │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │   │
│  │  │ Cost Monitor │  │   Grafana    │  │  Prometheus  │  │   │
│  │  │ Task         │  │   Task       │  │   Exporter   │  │   │
│  │  │ Logs→stdout  │  │ Port 3000    │  │ /metrics     │  │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │   │
│  └─────────┬───────────────┬──────────────────┬───────────┘   │
│            │               │                  │               │
│            ↓               ↓                  ↓               │
│  ┌──────────────────────────────────────────────────────┐     │
│  │         CloudWatch Logs (automatic)                  │     │
│  │  Log Groups: /ecs/cost-monitor, /ecs/grafana        │     │
│  └────────────────────────┬─────────────────────────────┘     │
│                           │                                   │
│                           ↓                                   │
│  ┌──────────────────────────────────────────────────────┐     │
│  │  CloudWatch Logs Subscription Filter                │     │
│  │  Pattern: "" (all logs)                              │     │
│  └────────────────────────┬─────────────────────────────┘     │
│                           │                                   │
│                           ↓                                   │
│  ┌──────────────────────────────────────────────────────┐     │
│  │  Lambda: forward-logs-to-loki                        │     │
│  │  • Triggered by CloudWatch                           │     │
│  │  • Decompresses logs                                 │     │
│  │  • POST to Loki                                      │     │
│  └────────────────────────┬─────────────────────────────┘     │
│                           │                                   │
└───────────────────────────┼───────────────────────────────────┘
                            │
                            ↓
                ┌───────────────────────┐
                │  Loki on EC2          │
                │  Port 3100            │
                └───────────────────────┘
```

### 4.2 Deployment Steps

```bash
# Create ECS Cluster
aws ecs create-cluster --cluster-name monitoring-cluster

# Create task definitions (see task-definitions directory)
aws ecs register-task-definition --cli-input-json file://grafana-task.json
aws ecs register-task-definition --cli-input-json file://prometheus-exporter-task.json

# Launch EC2 for Prometheus
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t3.medium \
  --block-device-mappings 'DeviceName=/dev/sda1,Ebs={VolumeSize=50}' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=prometheus}]'

# Launch EC2 for Loki
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t3.medium \
  --block-device-mappings 'DeviceName=/dev/sda1,Ebs={VolumeSize=100}' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=loki}]'

# Create RDS PostgreSQL
aws rds create-db-instance \
  --db-instance-identifier cost-monitoring-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --master-username admin \
  --master-user-password YOUR_PASSWORD \
  --allocated-storage 50

# Create Lambda function
aws lambda create-function \
  --function-name forward-logs-to-loki \
  --runtime python3.11 \
  --role arn:aws:iam::ACCOUNT:role/lambda-execution-role \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://function.zip \
  --environment Variables={LOKI_URL=http://LOKI_INTERNAL_IP:3100}

# Create CloudWatch Logs subscription
aws logs put-subscription-filter \
  --log-group-name /ecs/cost-monitor \
  --filter-name forward-to-loki \
  --filter-pattern "" \
  --destination-arn arn:aws:lambda:REGION:ACCOUNT:function:forward-logs-to-loki
```

### 4.3 Lambda Function Code (Python)

```python
# lambda_function.py
import json
import gzip
import base64
import requests
import os
from datetime import datetime

LOKI_URL = os.environ.get('LOKI_URL')

def lambda_handler(event, context):
    """Forward CloudWatch Logs to Loki"""
    
    # Decode and decompress CloudWatch Logs data
    compressed_data = base64.b64decode(event['awslogs']['data'])
    log_data = json.loads(gzip.decompress(compressed_data))
    
    log_group = log_data['logGroup']
    log_stream = log_data['logStream']
    log_events = log_data['logEvents']
    
    # Format for Loki
    streams = []
    for log_event in log_events:
        timestamp_ns = str(log_event['timestamp'] * 1_000_000)  # ms → ns
        message = log_event['message']
        
        stream = {
            "stream": {
                "job": "ecs",
                "log_group": log_group.split('/')[-1],
                "log_stream": log_stream,
                "environment": "production"
            },
            "values": [[timestamp_ns, message]]
        }
        streams.append(stream)
    
    # Send to Loki
    loki_payload = {"streams": streams}
    
    try:
        response = requests.post(f"{LOKI_URL}/loki/api/v1/push", json=loki_payload, timeout=5)
        response.raise_for_status()
        print(f"✓ Forwarded {len(log_events)} logs to Loki")
        return {'statusCode': 200}
    except Exception as e:
        print(f"✗ Error: {e}")
        return {'statusCode': 500, 'body': str(e)}

# requirements.txt
# requests==2.31.0
```

### 4.4 AWS Cost Estimate

| Component | Service | Configuration | Monthly Cost |
|-----------|---------|---------------|--------------|
| Grafana | Fargate | 0.5 vCPU, 1GB RAM | $20 |
| Prometheus | EC2 t3.medium | 2 vCPU, 4GB RAM, 50GB EBS | $40 |
| Loki | EC2 t3.medium | 2 vCPU, 4GB RAM, 100GB EBS | $50 |
| TimescaleDB | RDS PostgreSQL | db.t3.micro, 50GB | $35 |
| Lambda | Compute | 1M invocations/mo, 256MB | $5 |
| CloudWatch Logs | Log ingestion | 10GB/mo | $5 |
| ALB | Load balancer | 1 ALB | $18 |
| Data Transfer | Egress | 100GB/mo | $9 |
| **TOTAL** | | | **$182/mo** |

---

## 5. Azure Deployment

### 5.1 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     AZURE SUBSCRIPTION                           │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │           Azure Container Instances                      │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │   │
│  │  │ Cost Monitor │  │   Grafana    │  │  Prometheus  │  │   │
│  │  │ Container    │  │   Container  │  │   Exporter   │  │   │
│  │  │ Logs→stdout  │  │ Port 3000    │  │ /metrics     │  │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │   │
│  └─────────┬───────────────┬──────────────────┬───────────┘   │
│            │               │                  │               │
│            ↓               ↓                  ↓               │
│  ┌──────────────────────────────────────────────────────┐     │
│  │         Azure Monitor (Log Analytics)                │     │
│  │  Workspace: monitoring-workspace                     │     │
│  └────────────────────────┬─────────────────────────────┘     │
│                           │                                   │
│                           ↓                                   │
│  ┌──────────────────────────────────────────────────────┐     │
│  │  Event Grid Topic: container-logs                    │     │
│  └────────────────────────┬─────────────────────────────┘     │
│                           │                                   │
│                           ↓                                   │
│  ┌──────────────────────────────────────────────────────┐     │
│  │  Azure Function: ForwardLogsToLoki                   │     │
│  │  • Event Grid trigger                                │     │
│  │  • Reformats logs                                    │     │
│  │  • POST to Loki                                      │     │
│  └────────────────────────┬─────────────────────────────┘     │
│                           │                                   │
└───────────────────────────┼───────────────────────────────────┘
                            │
                            ↓
                ┌───────────────────────┐
                │  Loki on Azure VM     │
                │  Port 3100            │
                └───────────────────────┘
```

### 5.2 Deployment Steps

```bash
# Create Resource Group
az group create --name monitoring-rg --location eastus

# Deploy Grafana
az container create \
  --resource-group monitoring-rg \
  --name grafana \
  --image grafana/grafana:latest \
  --cpu 1 --memory 1.5 \
  --ports 3000 \
  --ip-address Public \
  --environment-variables GF_SERVER_ROOT_URL=http://PUBLIC_IP:3000

# Create VMs for Prometheus and Loki
az vm create \
  --resource-group monitoring-rg \
  --name prometheus-vm \
  --image UbuntuLTS \
  --size Standard_B2s \
  --data-disk-sizes-gb 50

az vm create \
  --resource-group monitoring-rg \
  --name loki-vm \
  --image UbuntuLTS \
  --size Standard_B2s \
  --data-disk-sizes-gb 100

# Create Azure Database for PostgreSQL
az postgres flexible-server create \
  --resource-group monitoring-rg \
  --name cost-monitoring-db \
  --location eastus \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --storage-size 32

# Create Log Analytics Workspace
az monitor log-analytics workspace create \
  --resource-group monitoring-rg \
  --workspace-name monitoring-workspace

# Create Azure Function
az functionapp create \
  --resource-group monitoring-rg \
  --name forward-logs-function \
  --storage-account monitoringstorage \
  --consumption-plan-location eastus \
  --runtime dotnet \
  --functions-version 4
```

### 5.3 Azure Function Code (C#)

```csharp
// ForwardLogsToLoki.cs
using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.EventGrid;
using Microsoft.Azure.EventGrid.Models;
using Microsoft.Extensions.Logging;

public static class ForwardLogsToLoki
{
    private static readonly HttpClient httpClient = new HttpClient();
    private static readonly string lokiUrl = Environment.GetEnvironmentVariable("LOKI_URL");

    [FunctionName("ForwardLogsToLoki")]
    public static async void Run(
        [EventGridTrigger] EventGridEvent eventGridEvent,
        ILogger log)
    {
        var logData = JsonSerializer.Deserialize<LogAnalyticsData>(
            eventGridEvent.Data.ToString()
        );
        
        var lokiPayload = new
        {
            streams = new[] {
                new {
                    stream = new {
                        job = "azure_container",
                        container = logData.ContainerName,
                        resource_group = logData.ResourceGroup,
                        severity = logData.Severity
                    },
                    values = new[] {
                        new[] { 
                            (DateTimeOffset.Parse(logData.Timestamp)
                                .ToUnixTimeMilliseconds() * 1_000_000).ToString(),
                            logData.Message 
                        }
                    }
                }
            }
        };

        var content = new StringContent(
            JsonSerializer.Serialize(lokiPayload),
            Encoding.UTF8,
            "application/json"
        );

        try
        {
            var response = await httpClient.PostAsync(
                $"{lokiUrl}/loki/api/v1/push", 
                content
            );
            response.EnsureSuccessStatusCode();
            log.LogInformation($"✓ Forwarded log: {logData.Severity}");
        }
        catch (Exception ex)
        {
            log.LogError($"✗ Error: {ex.Message}");
        }
    }
}

public class LogAnalyticsData
{
    public string Timestamp { get; set; }
    public string ContainerName { get; set; }
    public string ResourceGroup { get; set; }
    public string Severity { get; set; }
    public string Message { get; set; }
}
```

### 5.4 Azure Cost Estimate

| Component | Service | Configuration | Monthly Cost |
|-----------|---------|---------------|--------------|
| Grafana | Container Instance | 1 vCPU, 1.5GB RAM | $35 |
| Prometheus | VM Standard_B2s | 2 vCPU, 4GB RAM, 50GB | $40 |
| Loki | VM Standard_B2s | 2 vCPU, 4GB RAM, 100GB | $50 |
| TimescaleDB | Azure Database PostgreSQL | Basic tier, 50GB | $40 |
| Azure Function | Consumption plan | 1M executions/mo | $5 |
| Log Analytics | Monitor | 10GB ingestion/mo | $5 |
| App Gateway | Basic tier | 1 instance | $20 |
| Bandwidth | Outbound | 100GB/mo | $8 |
| **TOTAL** | | | **$203/mo** |

---

## 6. Log Collection Strategy

### 6.1 Decision Matrix

| Deployment Type | Log Collection | Promtail? | Why |
|-----------------|----------------|-----------|-----|
| **Cloud Run (GCP)** | Cloud Logging → Pub/Sub → Function → Loki | ❌ No | Serverless, no persistent disk |
| **Fargate (AWS)** | CloudWatch → Lambda → Loki | ❌ No | Serverless, no SSH access |
| **ACI (Azure)** | Log Analytics → Event Grid → Function → Loki | ❌ No | Stateless containers |
| **GKE/EKS/AKS** | Fluent Bit DaemonSet → Loki | ⚠️ Alternative | Kubernetes log collection |
| **VMs (GCE/EC2/Azure)** | Promtail agent → Loki | ✅ Yes | Direct file tailing |

### 6.2 Recommended Approach by Platform

**Serverless Containers (Cloud Run, Fargate, ACI):**
```
Application writes JSON to stdout
       ↓
Native cloud logging captures automatically
       ↓
Event trigger (Pub/Sub, CloudWatch subscription, Event Grid)
       ↓
Serverless function reformats and forwards
       ↓
Loki receives via HTTP API
```

**Kubernetes (GKE, EKS, AKS):**
```
Pods write to stdout
       ↓
Kubernetes captures to /var/log/pods
       ↓
Fluent Bit DaemonSet (or Promtail DaemonSet)
       ↓
Loki receives logs
```

**Virtual Machines:**
```
Application writes to log files
       ↓
Promtail agent tails files
       ↓
Promtail pushes to Loki
```

### 6.3 Structured Logging Format

All applications should log in JSON format:

```json
{
  "timestamp": "2026-02-05T18:30:45.123Z",
  "level": "info",
  "service": "cost-monitor",
  "message": "Processing LLM cost data",
  "provider": "gcp",
  "model": "gemini-pro",
  "tokens": {
    "input": 1200,
    "output": 800
  },
  "cost_usd": 0.045,
  "customer_id": "cust_abc123",
  "request_id": "req_xyz789"
}
```

This enables rich querying in Loki:
```logql
{job="cloud_run"} | json | cost_usd > 1.0
{job="cloud_run"} | json | customer_id="cust_abc123"
```

---

## 7. Configuration Files

### 7.1 Prometheus Configuration

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'production'
    environment: 'cloud'

# Alert rules
rule_files:
  - '/etc/prometheus/alerts/*.yml'

# Scrape targets
scrape_configs:
  # Self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Cost Monitor MCP Server
  - job_name: 'cost-monitor'
    metrics_path: '/metrics'
    static_configs:
      - targets: ['cost-monitor-service:8080']
        labels:
          service: 'cost-monitor'
          cloud: 'multi'

  # Prometheus Exporter (ETL pipeline)
  - job_name: 'prometheus-exporter'
    metrics_path: '/metrics'
    static_configs:
      - targets: ['prometheus-exporter:9100']
        labels:
          service: 'exporter'
```

### 7.2 Loki Configuration

```yaml
# loki-config.yaml
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2024-01-01
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

limits_config:
  retention_period: 720h  # 30 days
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  max_query_series: 10000

chunk_store_config:
  max_look_back_period: 720h

table_manager:
  retention_deletes_enabled: true
  retention_period: 720h
```

### 7.3 Grafana Data Sources

```yaml
# datasources.yml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    jsonData:
      timeInterval: '15s'

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    jsonData:
      maxLines: 1000

  - name: TimescaleDB
    type: postgres
    access: proxy
    url: timescaledb:5432
    database: cost_monitoring
    user: grafana
    secureJsonData:
      password: ${TIMESCALE_PASSWORD}
    jsonData:
      timescaledb: true
```

---

## 8. Dashboard Structure

### 8.1 Dashboard: Multi-Cloud LLM Costs

**Panels:**

1. **Total Cost (Current Month)** - Stat
   - Query: `SELECT SUM(cost_usd) FROM llm_consumption WHERE date >= date_trunc('month', CURRENT_DATE)`

2. **Cost by Provider** - Pie Chart
   - Query: `SELECT cloud_provider, SUM(cost_usd) FROM llm_consumption GROUP BY cloud_provider`

3. **Cost Trend (30 Days)** - Time Series
   - PromQL: `sum(increase(llm_cost_usd_total[1d])) by (provider)`

4. **Token Usage by Model** - Time Series
   - PromQL: `sum(rate(llm_tokens_total[5m])) by (model, type)`

5. **Top 10 Models by Cost** - Bar Gauge
   - Query: `SELECT model, SUM(cost_usd) FROM llm_consumption WHERE date >= CURRENT_DATE - 30 GROUP BY model ORDER BY 2 DESC LIMIT 10`

### 8.2 Dashboard: System Health

**Panels:**

1. **Service Uptime** - Status History
   - PromQL: `up{job=~"cost-monitor|prometheus-exporter"}`

2. **Request Rate** - Time Series
   - PromQL: `rate(llm_requests_total[5m])`

3. **Response Latency (p95)** - Time Series
   - PromQL: `histogram_quantile(0.95, rate(llm_latency_seconds_bucket[5m]))`

4. **Error Rate** - Time Series
   - PromQL: `rate(llm_requests_total{status="error"}[5m])`

### 8.3 Dashboard: Application Logs

**Panels:**

1. **Recent Errors** - Logs
   - LogQL: `{job="cloud_run"} |= "ERROR" | json`

2. **Log Volume by Severity** - Bar Chart
   - LogQL: `sum by (severity) (rate({job="cloud_run"}[5m]))`

3. **Slow Queries** - Table
   - LogQL: `{job="cloud_run"} | json | latency_ms > 1000`

---

## 9. Alerting Rules

### 9.1 Cost Alerts

```yaml
# alerts/cost-alerts.yml
groups:
  - name: llm_cost_alerts
    interval: 1m
    rules:
      - alert: LLMCostSpike
        expr: rate(llm_cost_usd_total[1h]) > 100
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "LLM costs above $100/hour"

      - alert: DailyBudgetExceeded
        expr: sum(increase(llm_cost_usd_total[1d])) > 2000
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Daily budget ($2000) exceeded"
```

### 9.2 System Alerts

```yaml
# alerts/system-alerts.yml
groups:
  - name: system_health
    interval: 30s
    rules:
      - alert: ServiceDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.job }} is down"

      - alert: HighErrorRate
        expr: rate(llm_requests_total{status="error"}[5m]) > 0.05
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Error rate above 5%"
```

---

## 10. Cost Estimates

### 10.1 Monthly Infrastructure Costs

| Cloud | Optimized | Standard | High-Availability |
|-------|-----------|----------|-------------------|
| **GCP** | $90 | $162 | $300 |
| **AWS** | $95 | $182 | $350 |
| **Azure** | $110 | $203 | $380 |

### 10.2 Cost Optimization Strategies

| Strategy | Savings | Trade-off |
|----------|---------|-----------|
| Use spot/preemptible VMs | 60-80% | Can be terminated |
| Reduce retention (15→7 days) | 40% | Less history |
| Single VM deployment | 50% | Less resilient |
| Managed Grafana Cloud | Varies | $49-299/mo but no ops |

---

**Next Document:** Docker-based deployment architecture →
