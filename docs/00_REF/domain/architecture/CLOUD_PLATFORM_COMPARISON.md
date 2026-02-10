# Cloud Platform Comparison: Home Cloud Selection for Multi-Cloud Cost Monitoring

**Document:** CLOUD_PLATFORM_COMPARISON.md
**Version:** 1.0.0
**Date:** 2026-02-07T00:00:00
**Status:** Analysis Complete
**Purpose:** Evaluate GCP, AWS, and Azure as "home cloud" for a multi-cloud cost monitoring platform

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Serverless Compute Options](#2-serverless-compute-options)
3. [Analytics Database Options](#3-analytics-database-options)
4. [Secret Management](#4-secret-management)
5. [Monitoring and Logging](#5-monitoring-and-logging)
6. [Task Queue and Scheduler](#6-task-queue-and-scheduler)
7. [PostgreSQL Options](#7-postgresql-options)
8. [Free Tier Comparison](#8-free-tier-comparison)
9. [Cost Estimation](#9-cost-estimation)
10. [Multi-Cloud Monitoring APIs](#10-multi-cloud-monitoring-apis)
11. [Developer Experience](#11-developer-experience)
12. [Recommendation](#12-recommendation)

---

## 1. Executive Summary

### 1.1 Evaluation Criteria

| Criteria | Weight | GCP | AWS | Azure |
|----------|--------|-----|-----|-------|
| Free tier generosity | 20% | 9/10 | 6/10 | 7/10 |
| Scale-to-zero support | 20% | 10/10 | 6/10 | 8/10 |
| Serverless container pricing | 15% | 9/10 | 7/10 | 8/10 |
| Analytics database value | 15% | 10/10 | 8/10 | 6/10 |
| Developer experience | 10% | 8/10 | 7/10 | 8/10 |
| Multi-cloud API access | 10% | 9/10 | 7/10 | 7/10 |
| Startup-friendly pricing | 10% | 9/10 | 6/10 | 7/10 |
| **Weighted Score** | 100% | **9.0** | **6.7** | **7.3** |

### 1.2 Recommendation Summary

**Primary Recommendation: GCP**

GCP provides the optimal combination of:
- Aggressive scale-to-zero with Cloud Run (true $0 when idle)
- BigQuery free tier (10GB storage + 1TB queries/month perpetually)
- Native billing export to BigQuery (free, no extra ETL needed)
- Cloud Run free tier (2M requests + 180K vCPU-seconds/month)
- Superior cost monitoring APIs for multi-cloud scenarios

### 1.3 Cost Summary

| Deployment Size | GCP | AWS | Azure |
|-----------------|-----|-----|-------|
| MVP (20-30 users) | $45-75/mo | $120-180/mo | $90-140/mo |
| Production (100+ users) | $150-250/mo | $350-500/mo | $280-400/mo |

---

## 2. Serverless Compute Options

### 2.1 Service Comparison

| Feature | GCP Cloud Run | AWS Fargate | Azure Container Apps |
|---------|---------------|-------------|---------------------|
| Scale to zero | Yes (native) | No (min 1 task) | Yes (consumption plan) |
| Cold start time | 500ms-2s | N/A (always running) | 500ms-3s |
| Billing granularity | Per 100ms | Per second | Per second |
| Request-based pricing | Yes | No | Yes |
| Min charge per request | None | N/A | None |

### 2.2 Pricing Comparison

**GCP Cloud Run (us-central1)**

| Resource | Price | Free Tier |
|----------|-------|-----------|
| vCPU-second | $0.00002400 | 180,000/month |
| GiB-second | $0.00000250 | 360,000/month |
| Requests | $0.40/million | 2,000,000/month |

**AWS Fargate (us-east-1)**

| Resource | Price | Free Tier |
|----------|-------|-----------|
| vCPU-second | $0.00001124 | None |
| GB-second | $0.00000124 | None |
| Requests | N/A | N/A |

**Azure Container Apps (East US)**

| Resource | Price | Free Tier |
|----------|-------|-----------|
| vCPU-second | $0.000024 | 180,000/month |
| GiB-second | $0.000003 | 360,000/month |
| Requests | $0.40/million | 2,000,000/month |

### 2.3 Monthly Cost Scenarios

**Scenario: 4 MCP servers, 500K requests/month, average 200ms response**

| Provider | Compute Cost | Request Cost | Total |
|----------|--------------|--------------|-------|
| GCP Cloud Run | $4.80 | $0 (free tier) | $4.80 |
| AWS Fargate (min 1 task 24/7) | $36.00 | N/A | $36.00 |
| Azure Container Apps | $4.80 | $0 (free tier) | $4.80 |

**Analysis**: AWS Fargate lacks scale-to-zero, making it 7.5x more expensive for variable workloads. GCP and Azure Container Apps are equivalent in pricing, but GCP has a more mature ecosystem.

### 2.4 Cold Start Mitigation

| Strategy | GCP | AWS | Azure |
|----------|-----|-----|-------|
| Minimum instances | Yes ($47/mo per instance) | Always on | Yes |
| Startup CPU boost | Yes (free) | N/A | No |
| Pre-warmed instances | Via min instances | Via Provisioned Concurrency | Via Premium plan |
| Typical cold start | 500ms-2s | N/A | 500ms-3s |

---

## 3. Analytics Database Options

### 3.1 Service Comparison

| Feature | GCP BigQuery | AWS Athena | Azure Synapse Serverless |
|---------|--------------|------------|-------------------------|
| Architecture | Serverless columnar | Serverless (S3 + Presto) | Serverless SQL pool |
| Scale to zero | Yes | Yes | Yes |
| Query pricing | $6.25/TB scanned | $5.00/TB scanned | $5.00/TB scanned |
| Storage pricing | $0.02/GB/month | S3 pricing ($0.023/GB) | ADLS pricing (~$0.02/GB) |
| Free tier | 10GB + 1TB queries/mo | None | None |

### 3.2 Free Tier Analysis

| Provider | Storage Free | Queries Free | Monthly Value |
|----------|--------------|--------------|---------------|
| **GCP BigQuery** | **10 GB** | **1 TB** | **~$6.45/mo** |
| AWS Athena | 0 | 0 | $0 |
| Azure Synapse | 0 | 0 | $0 |

**BigQuery free tier advantage**: For a cost monitoring platform with moderate query volume (under 1TB/month), BigQuery effectively costs $0 for analytics.

### 3.3 Cost Monitoring Use Case

**Scenario: Store 6 months of billing data, run 50 queries/day averaging 2GB scanned each**

| Provider | Storage Cost | Query Cost | Total Monthly |
|----------|--------------|------------|---------------|
| GCP BigQuery | $0 (under 10GB) | $0 (under 1TB) | $0 |
| AWS Athena | $1.38 (60GB S3) | $15.00 (3TB) | $16.38 |
| Azure Synapse | $1.20 (60GB ADLS) | $15.00 (3TB) | $16.20 |

### 3.4 Native Billing Export

| Provider | Export Destination | Cost | Setup Complexity |
|----------|-------------------|------|------------------|
| GCP | BigQuery (native) | Free | Low (1 click) |
| AWS | S3 (CUR reports) | S3 storage only | Medium |
| Azure | Storage Account | Storage only | Medium |

**GCP advantage**: Native BigQuery billing export means no ETL pipeline needed. Query your own cloud costs directly in SQL.

---

## 4. Secret Management

### 4.1 Service Comparison

| Feature | GCP Secret Manager | AWS Secrets Manager | Azure Key Vault |
|---------|-------------------|--------------------|-----------------|
| Pricing model | Per secret + access | Per secret + access | Per operation |
| Secret storage | $0.06/secret/month | $0.40/secret/month | $0.03/10K operations |
| API access | $0.03/10K accesses | $0.05/10K accesses | Included in ops |
| Rotation | Manual or custom | Built-in for RDS/Aurora | Built-in for SQL |
| Free tier | 6 secrets always free | $200 credit (new accounts) | Limited free ops |

### 4.2 Cost Scenario

**Scenario: 20 secrets, 100K accesses/month**

| Provider | Storage Cost | Access Cost | Total Monthly |
|----------|--------------|-------------|---------------|
| GCP Secret Manager | $1.20 | $0.30 | $1.50 |
| AWS Secrets Manager | $8.00 | $0.50 | $8.50 |
| Azure Key Vault | $0.30 | ~$0.30 | ~$0.60 |

**Analysis**: Azure Key Vault is cheapest for high-access scenarios. GCP offers best value for moderate usage with 6 free secrets.

---

## 5. Monitoring and Logging

### 5.1 Service Comparison

| Feature | GCP Cloud Monitoring | AWS CloudWatch | Azure Monitor |
|---------|---------------------|----------------|---------------|
| Log ingestion | $0.50/GB | $0.50/GB | $2.30/GB |
| Log storage | $0.01/GB/month | $0.03/GB archived | $0.10/GB (after 31 days) |
| Metrics (custom) | $0.10/metric/month | $0.30/metric/month | Included |
| Alerts | Free (basic) | $0.10/alarm/month | Included |
| Free tier | **50 GB logs/month** | 5 GB logs/month | First 31 days free |

### 5.2 Free Tier Comparison

| Provider | Free Logs | Free Metrics | Free Alerts | Monthly Value |
|----------|-----------|--------------|-------------|---------------|
| **GCP** | **50 GB** | Standard metrics | Basic alerts | **~$25/mo** |
| AWS | 5 GB | Basic metrics | 10 alarms | ~$3/mo |
| Azure | 5 GB (first 31 days) | Standard metrics | Included | ~$2/mo |

### 5.3 Cost Scenario

**Scenario: 20 GB logs/month, 50 custom metrics, 20 alerts**

| Provider | Log Cost | Metric Cost | Alert Cost | Total |
|----------|----------|-------------|------------|-------|
| GCP Cloud Monitoring | $0 (free tier) | $5.00 | $0 | $5.00 |
| AWS CloudWatch | $7.50 | $15.00 | $2.00 | $24.50 |
| Azure Monitor | $46.00 | $0 | $0 | $46.00 |

---

## 6. Task Queue and Scheduler

### 6.1 Service Comparison

| Feature | GCP Cloud Tasks + Scheduler | AWS SQS + EventBridge | Azure Queue + Logic Apps |
|---------|----------------------------|----------------------|-------------------------|
| Queue pricing | $0.40/million tasks | $0.40/million requests | $0.004/10K operations |
| Scheduler pricing | $0.10/job/month | $1.00/million events | $0.000025/action |
| Free tier | 1M tasks + 3 jobs | 1M SQS requests | 4K actions/month |
| HTTP targets | Native | Via Lambda | Via Functions |
| Retry logic | Built-in | Built-in | Built-in |

### 6.2 Cost Scenario

**Scenario: 500K tasks/month, 10 scheduled jobs (hourly triggers)**

| Provider | Queue Cost | Scheduler Cost | Total |
|----------|------------|----------------|-------|
| GCP Cloud Tasks + Scheduler | $0 (free tier) | $1.00 | $1.00 |
| AWS SQS + EventBridge | $0 (free tier) | $7.20 | $7.20 |
| Azure Queue + Logic Apps | $0.20 | $0.18 | $0.38 |

**Analysis**: Azure Logic Apps is cheapest for simple workflows. GCP offers good value with native Cloud Run integration.

---

## 7. PostgreSQL Options

### 7.1 Managed Service Comparison

| Feature | GCP Cloud SQL | AWS RDS | Azure PostgreSQL Flexible |
|---------|--------------|---------|--------------------------|
| Min instance | db-f1-micro ($7/mo) | db.t3.micro ($12/mo) | Burstable B1ms ($12/mo) |
| Scale to zero | No | Aurora Serverless v2 only | No |
| Storage | $0.17/GB/month | $0.115/GB/month | $0.115/GB/month |
| Automated backups | 7 days free | 7 days free | 7 days free |
| Read replicas | $7/mo minimum | $12/mo minimum | $12/mo minimum |

### 7.2 Serverless PostgreSQL Alternatives

| Provider | Service | Scale to Zero | Free Tier | Paid Starting |
|----------|---------|---------------|-----------|---------------|
| **Neon** | Serverless Postgres | **Yes** | **0.5 GB** | **$19/mo** |
| Supabase | Managed Postgres | No | 500 MB | $25/mo |
| PlanetScale | Serverless MySQL | Yes | 5 GB | $29/mo |
| AWS Aurora Serverless | Aurora | Partial | None | ~$50/mo min |

### 7.3 Recommendation

For a cost-monitoring platform requiring PostgreSQL:

| Scenario | Recommended | Monthly Cost |
|----------|-------------|--------------|
| Development/MVP | Neon free tier | $0 |
| Production (low traffic) | Neon Pro | $19/mo |
| Production (high traffic) | GCP Cloud SQL | $50-100/mo |

**Neon advantages**:
- True scale-to-zero (idle databases cost $0)
- Instant branching for dev/test
- Native pgvector support for AI embeddings
- Connection pooling included

---

## 8. Free Tier Comparison

### 8.1 Always-Free Services

| Service Category | GCP | AWS | Azure |
|------------------|-----|-----|-------|
| Serverless Compute | Cloud Run: 2M req/mo | Lambda: 1M req/mo | Functions: 1M req/mo |
| Analytics | BigQuery: 1TB queries/mo | None | None |
| Storage | 5 GB Cloud Storage | 5 GB S3 (12 months) | 5 GB Blob (12 months) |
| Database | None (use Neon) | 750 hrs RDS (12 months) | 750 hrs (12 months) |
| Secrets | 6 secrets | $200 credit (new accts) | Limited |
| Logging | 50 GB/month | 5 GB/month | 5 GB (31 days) |
| CDN | 1 GB/day egress | 1 TB/year (12 months) | None |

### 8.2 Trial Credits

| Provider | Credit Amount | Duration | Auto-charge After |
|----------|---------------|----------|-------------------|
| **GCP** | **$300** | **12 months** | **No** |
| AWS | $200 (new, 2025+) | Flexible | Yes |
| Azure | $200 | 30 days | Yes |

**GCP advantage**: No auto-charge after trial ends. AWS and Azure will charge your card.

### 8.3 Total Free Tier Value (Monthly)

| Category | GCP Value | AWS Value | Azure Value |
|----------|-----------|-----------|-------------|
| Compute | $50 | $20 | $25 |
| Analytics | $6.50 | $0 | $0 |
| Logging | $25 | $2.50 | $2.50 |
| Secrets | $0.36 | $0 | $0 |
| Tasks/Scheduler | $1.50 | $0.40 | $0 |
| **Total Monthly** | **~$83** | **~$23** | **~$28** |

---

## 9. Cost Estimation

### 9.1 MVP Deployment (20-30 Users)

**Workload Assumptions**:
- 4 MCP server containers
- 500K API requests/month
- 10 GB cost data storage
- 100 queries/day (200 GB scanned/month)
- 10 GB logs/month
- 15 secrets
- 5 scheduled jobs

#### GCP Estimated Costs

| Service | Configuration | Monthly Cost |
|---------|---------------|--------------|
| Cloud Run | 4 services, scale-to-zero | $0 (free tier) |
| BigQuery | 10 GB storage, 200 GB queries | $0 (free tier) |
| Cloud SQL | None (use Neon) | $0 |
| Neon PostgreSQL | Pro plan | $19 |
| Secret Manager | 15 secrets | $0.90 |
| Cloud Logging | 10 GB | $0 (free tier) |
| Cloud Tasks/Scheduler | 5 jobs | $0.50 |
| Load Balancer | Serverless NEG | $18 |
| **Total GCP** | | **$38.40** |
| Cloudflare (CDN/DNS) | Free tier | $0 |
| **Grand Total** | | **$38.40** |

#### AWS Estimated Costs

| Service | Configuration | Monthly Cost |
|---------|---------------|--------------|
| Fargate | 4 tasks (min 1 running) | $72 |
| Athena | 200 GB queries | $1.00 |
| S3 | 10 GB storage | $0.23 |
| RDS PostgreSQL | db.t3.micro | $12 |
| Secrets Manager | 15 secrets | $6.00 |
| CloudWatch | 10 GB logs | $5.00 |
| SQS + EventBridge | 5 scheduled tasks | $1.00 |
| ALB | Application LB | $16 |
| **Total AWS** | | **$113.23** |

#### Azure Estimated Costs

| Service | Configuration | Monthly Cost |
|---------|---------------|--------------|
| Container Apps | 4 apps, consumption | $5 |
| Synapse Serverless | 200 GB queries | $1.00 |
| Blob Storage | 10 GB | $0.20 |
| PostgreSQL Flexible | Burstable B1ms | $12 |
| Key Vault | 15 secrets, 50K ops | $0.15 |
| Monitor | 10 GB logs | $23 |
| Queue + Logic Apps | 5 workflows | $0.50 |
| Application Gateway | Basic | $20 |
| **Total Azure** | | **$61.85** |

### 9.2 Production Deployment (100+ Users)

**Workload Assumptions**:
- 4 MCP servers with min 1 instance
- 3M API requests/month
- 50 GB cost data storage
- 500 queries/day (1 TB scanned/month)
- 30 GB logs/month
- 25 secrets
- 20 scheduled jobs (10 tenants)

#### Cost Comparison

| Service Category | GCP | AWS | Azure |
|------------------|-----|-----|-------|
| Compute | $47 | $144 | $50 |
| Analytics DB | $0 (1TB free) | $5 | $5 |
| PostgreSQL | $50 (Cloud SQL) | $50 | $50 |
| Secrets | $2.00 | $10 | $0.30 |
| Logging | $0 (free tier) | $15 | $69 |
| Task Queue | $2.00 | $5 | $2 |
| Load Balancer | $25 | $25 | $30 |
| **Total** | **$126** | **$254** | **$206** |

---

## 10. Multi-Cloud Monitoring APIs

### 10.1 Billing Data Access

| Cloud | Export Method | Destination | Cost | Latency |
|-------|---------------|-------------|------|---------|
| **GCP** | **BigQuery Export** | **BigQuery** | **Free** | **Near real-time** |
| AWS | Cost and Usage Reports | S3 | S3 storage | Daily |
| Azure | Cost Management Export | Storage Account | Storage | Daily |

### 10.2 API Capabilities

| Feature | GCP Cloud Billing API | AWS Cost Explorer API | Azure Cost Management API |
|---------|----------------------|----------------------|--------------------------|
| Programmatic access | Yes | Yes | Yes |
| Cost per API call | Free | $0.01/request | Free |
| Granularity | Hourly | Daily | Daily |
| Forecasting | Yes | Yes | Yes |
| Anomaly detection | Built-in | Built-in | Built-in |
| Free tier | Unlimited | None | Unlimited |

### 10.3 Cross-Cloud Monitoring Architecture

**From GCP as Home Cloud**:

```
GCP BigQuery (Analytics Hub)
    |
    +-- GCP Billing Export (native, free)
    |
    +-- AWS CUR --> S3 --> BigQuery Data Transfer ($0.01/GB)
    |
    +-- Azure Export --> Blob --> BigQuery Data Transfer ($0.01/GB)
```

**Advantage**: GCP BigQuery serves as a unified analytics layer. All billing data can be queried with standard SQL.

### 10.4 Multi-Cloud Monitoring Costs

| Data Source | Ingestion Method | Monthly Cost (50 GB) |
|-------------|------------------|---------------------|
| GCP own billing | Native export | $0 |
| AWS billing data | S3 → BigQuery transfer | $0.50 |
| Azure billing data | Blob → BigQuery transfer | $0.50 |
| Kubernetes costs | Prometheus → BigQuery | $1.00 |
| **Total** | | **$2.00** |

---

## 11. Developer Experience

### 11.1 CLI Tooling Comparison

| Aspect | GCP (gcloud) | AWS (aws-cli) | Azure (az) |
|--------|--------------|---------------|------------|
| Installation | Single SDK | Single CLI | Single CLI |
| Consistency | High (platform feel) | Medium (service-specific) | Medium |
| Local emulators | Excellent (Firestore, Pub/Sub, etc.) | Limited | Limited |
| Documentation | Excellent | Extensive but complex | Good |
| Learning curve | Low | High | Medium |

### 11.2 Local Development

| Feature | GCP | AWS | Azure |
|---------|-----|-----|-------|
| Local container testing | Cloud Run emulator | SAM local | VS Code extension |
| Database emulator | Firestore, Spanner | DynamoDB Local | Cosmos emulator |
| Function emulator | Functions Framework | SAM CLI | Azure Functions Core |
| Cost estimation | Pricing calculator | Pricing calculator | Pricing calculator |

### 11.3 Infrastructure as Code

| Tool | GCP Support | AWS Support | Azure Support |
|------|-------------|-------------|---------------|
| Terraform | Excellent | Excellent | Excellent |
| Pulumi | Excellent | Excellent | Excellent |
| Native IaC | Deployment Manager | CloudFormation | ARM/Bicep |
| CDK support | Yes | Native | Yes |

### 11.4 Developer Experience Score

| Criteria | GCP | AWS | Azure |
|----------|-----|-----|-------|
| CLI usability | 9/10 | 7/10 | 8/10 |
| Documentation quality | 9/10 | 8/10 | 8/10 |
| Local development | 9/10 | 7/10 | 7/10 |
| Learning resources | 8/10 | 9/10 | 8/10 |
| Community support | 7/10 | 9/10 | 8/10 |
| **Average** | **8.4** | **8.0** | **7.8** |

---

## 12. Recommendation

### 12.1 Final Recommendation: GCP as Home Cloud

For a multi-cloud cost monitoring platform, **GCP provides the optimal foundation** based on:

#### Cost Advantages

| Advantage | Monthly Savings vs AWS | Monthly Savings vs Azure |
|-----------|----------------------|-------------------------|
| BigQuery free tier | $16-50/mo | $16-50/mo |
| Cloud Run scale-to-zero | $30-70/mo | $0-10/mo |
| Logging free tier | $10-25/mo | $20-50/mo |
| Native billing export | $5-10/mo | $5-10/mo |
| **Total** | **$61-155/mo** | **$41-120/mo** |

#### Technical Advantages

1. **BigQuery as unified analytics layer**: Query all cloud billing data with SQL
2. **Native GCP billing export**: Zero-cost, real-time billing data
3. **Cloud Run scale-to-zero**: True serverless with no idle costs
4. **50 GB free logging**: Sufficient for MVP and early production
5. **No auto-charge after trial**: Risk-free exploration

#### Recommended Architecture

```
Primary Cloud: GCP (us-central1)
├── Cloud Run (MCP Servers)
├── BigQuery (Cost Analytics)
├── Secret Manager
├── Cloud Logging
└── Cloud Tasks + Scheduler

Database Layer: Neon.tech
├── PostgreSQL + pgvector
└── Scale-to-zero

Edge Layer: Cloudflare
├── DNS
├── CDN
└── WAF

Optional: Azure Static Web Apps
└── Frontend hosting (100 GB/mo free)
```

### 12.2 Migration Path

| Phase | Timeline | Actions |
|-------|----------|---------|
| Phase 1 | Week 1-2 | Deploy core services on GCP Cloud Run |
| Phase 2 | Week 3-4 | Configure BigQuery billing exports for all clouds |
| Phase 3 | Week 5-6 | Implement multi-cloud cost aggregation |
| Phase 4 | Ongoing | Monitor costs, optimize as needed |

### 12.3 Risk Mitigation

| Risk | Mitigation |
|------|------------|
| GCP service changes | Infrastructure as Code (Terraform) for portability |
| BigQuery cost overrun | Set query cost limits, use partitioned tables |
| Vendor lock-in | Use standard containers, avoid proprietary services |
| Cold start latency | Startup CPU boost, min instances for critical paths |

### 12.4 Cost Projections

| Growth Stage | Users | Monthly GCP Cost | Notes |
|--------------|-------|------------------|-------|
| MVP | 20-30 | $40-75 | Mostly free tier |
| Growth | 50-100 | $75-150 | Exceeds some free tiers |
| Scale | 100-500 | $150-400 | Volume discounts apply |
| Enterprise | 500+ | $400-1000 | Committed use discounts |

---

## Sources

### Serverless Compute
- [Comparing Prices: AWS Fargate vs Azure Container Apps vs Google Cloud Run](https://sliplane.io/blog/comparing-prices-aws-fargate-vs-azure-container-apps-vs-google-cloud-run)
- [AWS vs Azure vs Google Cloud: comprehensive comparison for 2026](https://northflank.com/blog/aws-vs-azure-vs-google-cloud)
- [Cloud Run pricing](https://cloud.google.com/run/pricing)
- [AWS Fargate Pricing](https://aws.amazon.com/fargate/pricing/)
- [Azure Container Apps Pricing](https://azure.microsoft.com/en-us/pricing/details/container-apps/)

### Analytics Databases
- [BigQuery vs Azure Synapse: 8 Crucial Differences](https://www.cdata.com/blog/bigquery-vs-azure-synapse)
- [BigQuery VS Athena: Architecture, Data Types, Use Cases](https://hevodata.com/learn/differences-between-bigquery-vs-athena/)
- [BigQuery Pricing Guide 2026](https://airbyte.com/data-engineering-resources/bigquery-pricing)
- [Amazon Athena Pricing](https://aws.amazon.com/athena/pricing/)

### Secret Management
- [AWS Secrets Manager Pricing](https://aws.amazon.com/secrets-manager/pricing/)
- [GCP Secret Manager Pricing](https://cloud.google.com/secret-manager/pricing)
- [Complete Guide to AWS Secrets Manager](https://blog.greeden.me/en/2026/01/30/complete-guide-to-aws-secrets-manager-systematizing-password-api-key-management-with-rotation-and-auditing-compared-with-gcp-secret-manager-azure-key-vault/)

### Monitoring and Logging
- [Monitoring Service Comparison - AWS vs Azure vs GCP](https://medium.com/@richard_64931/monitoring-service-comparison-aws-vs-azure-vs-gcp-part-2-7a9cd52b10f2)
- [AWS CloudWatch vs Azure Monitor vs Google Cloud Operations Suite](https://cloudcomparetool.com/blog/aws-cloudwatch-vs-azure-monitor-vs-google-cloud-operations-suite)

### PostgreSQL
- [PostgreSQL Hosting Options in 2025: Pricing Comparison](https://www.bytebase.com/blog/postgres-hosting-options-pricing-comparison/)
- [Neon Serverless Postgres Pricing 2026](https://vela.simplyblock.io/articles/neon-serverless-postgres-pricing-2026/)
- [Top Managed PostgreSQL Services Compared](https://seenode.com/blog/top-managed-postgresql-services-compared)

### Free Tier Comparison
- [Cloud Free Tier Comparison](https://github.com/cloudcommunity/Cloud-Free-Tier-Comparison)
- [AWS vs Azure vs Google Free Tier Comparison](https://jaychapel.medium.com/aws-vs-azure-vs-google-free-tier-comparison-19b68578e7f)
- [Free Trial and Free Tier Services - Google Cloud](https://cloud.google.com/free)

### Multi-Cloud Cost Management
- [Cloud Cost Management Tools from AWS, Azure and GCP](https://medium.com/cloudplatformengineering/cloud-cost-management-tools-from-aws-azure-and-gcp-af6312f7012f)
- [Best FinOps Tools For Cloud Cost Management 2026](https://cloudchipr.com/blog/best-finops-tools-for-cloud-cost-management)

### Developer Experience
- [Let's compare the CLI experiences offered by AWS, Microsoft Azure, and Google Cloud Platform](https://seroter.com/2020/09/15/lets-compare-the-cli-experiences-offered-by-aws-microsoft-azure-and-google-cloud-platform/)
- [Cloud developer tooling compared: AWS vs. Azure vs. GCP](https://www.pluralsight.com/resources/blog/cloud/cloud-developer-tooling-compared-aws-vs-azure-vs-gcp)
