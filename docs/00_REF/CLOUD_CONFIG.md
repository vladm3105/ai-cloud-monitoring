# AI Cloud Cost Monitoring - Cloud Platform Configuration

## Primary Cloud Provider
**Google Cloud Platform (GCP)**

## Architecture Phase
**MVP (Single-Tenant)** — See [MVP_ARCHITECTURE.md](domain/architecture/MVP_ARCHITECTURE.md)

## Configuration

### GCP Project Settings
```yaml
project:
  id: "ai-cost-monitoring"  # Update with your actual GCP project ID
  name: "AI Cloud Cost Monitoring"
  organization_id: ""  # Optional: Your GCP organization ID
  billing_account_id: ""  # Your GCP billing account ID

regions:
  primary: "us-central1"
  secondary: "us-east1"  # For disaster recovery (future)

deployment:
  platform: "cloud-run"
  environment: "development"  # development | staging | production
  tenant_mode: "single"  # MVP: single | Future: multi
```

### Required GCP APIs (MVP)

```bash
# Core APIs required for MVP
run.googleapis.com              # Cloud Run (serverless containers)
cloudbuild.googleapis.com       # Cloud Build (CI/CD)
secretmanager.googleapis.com    # Secret Manager (credentials)
bigquery.googleapis.com         # BigQuery (cost analytics)
firestore.googleapis.com        # Firestore (config storage)
cloudscheduler.googleapis.com   # Cloud Scheduler (cron jobs)
monitoring.googleapis.com       # Cloud Monitoring
logging.googleapis.com          # Cloud Logging

# APIs for cloud cost monitoring
cloudbilling.googleapis.com     # GCP Billing API
cloudresourcemanager.googleapis.com  # Resource Manager

# NOT required for MVP (deferred to multi-tenant):
# sql.googleapis.com            # Cloud SQL (PostgreSQL)
# redis.googleapis.com          # Cloud Memorystore (Redis)
# compute.googleapis.com        # Compute Engine (VPC)
```

### Service Configuration (MVP)

#### cost-monitor (API + Cost Collection)
```yaml
service:
  name: "cost-monitor"
  platform: Cloud Run
  region: us-central1
  runtime: python3.11

resources:
  memory: 512Mi
  cpu: 1

scaling:
  min_instances: 0      # Scale to zero when idle
  max_instances: 3
  concurrency: 40
  timeout: 300s

triggers:
  - type: http          # API requests
  - type: scheduler     # Cloud Scheduler (cost sync)
    schedule: "0 */4 * * *"  # Every 4 hours
```

#### ui-server (Next.js Frontend)
```yaml
service:
  name: "ui-server"
  platform: Cloud Run
  region: us-central1
  runtime: nodejs20

resources:
  memory: 256Mi
  cpu: 0.5

scaling:
  min_instances: 0
  max_instances: 2
  concurrency: 80
  timeout: 60s
```

#### mcp-server (AI Agent Tool Server)
```yaml
service:
  name: "mcp-server"
  platform: Cloud Run
  region: us-central1
  runtime: python3.11

resources:
  memory: 512Mi
  cpu: 1

scaling:
  min_instances: 0
  max_instances: 3
  concurrency: 20
  timeout: 300s
```

### Data Storage (MVP)

#### BigQuery (Cost Analytics)
```yaml
dataset:
  name: "cost_monitoring"
  location: "US"

tables:
  - name: cost_daily
    partitioning: date
    clustering: [provider, account_id]

  - name: cost_hourly
    partitioning: timestamp (DAY)
    clustering: [provider]

# GCP billing export (configure in Cloud Console)
billing_export:
  dataset: "billing_export"
  table: "gcp_billing_export_v1_*"
```

#### Firestore (Configuration)
```yaml
database:
  mode: "native"  # Native mode (not Datastore mode)
  location: "us-central1"

collections:
  - config          # Application settings
  - budgets         # Budget definitions
  - cloud_accounts  # Connected cloud accounts
  - alerts          # Alert history
  - preferences     # User preferences
```

#### Secret Manager
```yaml
secrets:
  # Cloud credentials
  - name: aws-credentials
    description: "AWS IAM credentials for Cost Explorer API"

  - name: azure-credentials
    description: "Azure Service Principal for Cost Management API"

  - name: gcp-service-account
    description: "GCP SA key for cross-project billing access"

  - name: kubernetes-config
    description: "Kubeconfig for K8s cluster access"

  # LLM API
  - name: llm-api-key
    description: "OpenAI/Anthropic API key"

  # Notifications (optional)
  - name: notification-config
    description: "Slack webhook, email SMTP settings"
```

### Cost Estimates

#### MVP Monthly Costs (Single-Tenant)
| Service | Free Tier | Expected Usage | Cost |
|---------|-----------|----------------|------|
| Cloud Run | 2M requests | ~500K requests | $0 |
| BigQuery | 10GB + 1TB queries | ~5GB, ~100GB | $0 |
| Firestore | 1GB, 50K reads/day | ~100MB, ~10K | $0 |
| Secret Manager | 6 secrets | 5 secrets | $0 |
| Cloud Logging | 50GB/month | ~5GB | $0 |
| Cloud Scheduler | 3 jobs | 2 jobs | $0 |
| **Total** | | | **$0-5** |

#### Multi-Tenant Monthly Costs (Future)
| Service | Usage | Cost |
|---------|-------|------|
| Cloud Run | 5M requests | $20-50 |
| BigQuery | 100GB, 5TB queries | $10-30 |
| Neon.tech PostgreSQL | Pro plan | $19 |
| Secret Manager | 50 secrets | $3-5 |
| Cloud Logging | 20GB | $0 |
| **Total** | | **$60-120** |

### Networking (MVP - Simplified)

#### No VPC Required for MVP
- Cloud Run services use default networking
- All connections over public internet with TLS
- Firestore/BigQuery accessed via Google APIs

#### Edge (Optional but Recommended)
```yaml
cloudflare:
  plan: "free"
  features:
    - dns
    - cdn
    - waf
    - ddos_protection
```

### Monitoring & Logging

#### Cloud Monitoring
```yaml
dashboards:
  - name: "Cost Monitor Overview"
    widgets:
      - cloud_run_request_count
      - cloud_run_latency_p99
      - bigquery_query_count
      - firestore_read_count

alerts:
  - name: "High Error Rate"
    condition: "error_rate > 5%"
    duration: "5m"
    notification: email

  - name: "Budget Threshold"
    condition: "monthly_spend > budget * 0.8"
    notification: [email, slack]
```

#### Cloud Logging
```yaml
retention:
  default: 30 days
  audit: 90 days  # Future: 7 years for compliance

log_sinks:
  - name: "errors-to-bigquery"
    filter: "severity >= ERROR"
    destination: bigquery (future)
```

---

## Enable APIs Script (MVP)

```bash
#!/bin/bash
# Enable required GCP APIs for MVP

PROJECT_ID="${1:-your-project-id}"

gcloud config set project $PROJECT_ID

echo "Enabling MVP APIs for project: $PROJECT_ID"

# Core services
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable secretmanager.googleapis.com
gcloud services enable bigquery.googleapis.com
gcloud services enable firestore.googleapis.com
gcloud services enable cloudscheduler.googleapis.com
gcloud services enable monitoring.googleapis.com
gcloud services enable logging.googleapis.com

# Billing/resource APIs
gcloud services enable cloudbilling.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com

echo "MVP APIs enabled successfully!"
echo ""
echo "NOT enabled (multi-tenant phase):"
echo "  - sql.googleapis.com (Cloud SQL)"
echo "  - redis.googleapis.com (Memorystore)"
echo "  - compute.googleapis.com (VPC)"
```

---

## Quick Start

1. **Update project ID** in this file
2. **Run enable APIs script**: `./scripts/enable-apis.sh your-project-id`
3. **Configure Firestore**: Create database in Native mode
4. **Set up BigQuery**: Create `cost_monitoring` dataset
5. **Configure billing export**: Enable in Cloud Console
6. **Deploy services**: Follow [GCP-DEPLOYMENT.md](GCP-DEPLOYMENT.md)

---

## Related Documents

- [MVP_ARCHITECTURE.md](domain/architecture/MVP_ARCHITECTURE.md) - Full MVP architecture
- [ADR-008: Database Strategy](domain/architecture/adr/008-database-strategy-mvp.md) - Firestore vs PostgreSQL
- [GCP-DEPLOYMENT.md](GCP-DEPLOYMENT.md) - Deployment guide
- [.env.example](.env.example) - Environment variables template
