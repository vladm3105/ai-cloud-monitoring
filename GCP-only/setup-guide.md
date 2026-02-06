# GCP Cost Monitoring Agent — Setup Guide

## Overview

This guide walks you through setting up the GCP infrastructure required to run the Cost Monitoring Agent. By the end, you'll have:

- ✅ Billing export flowing to BigQuery
- ✅ Service account with appropriate permissions
- ✅ Budget alerts configured
- ✅ MCP server ready to deploy
- ✅ All APIs enabled

**Estimated time:** 45-60 minutes

---

## Prerequisites

Before starting, ensure you have:

| Requirement | Why |
|-------------|-----|
| **GCP Organization** | Required for organization-wide cost monitoring |
| **Billing Account** with Owner role | To enable billing export and create budgets |
| **Project creation permissions** | To create the monitoring project |
| **gcloud CLI installed** | For command-line setup steps |

### Check GCP Organization Access

```bash
# Login to GCP
gcloud auth login

# List organizations you have access to
gcloud organizations list

# Set your organization ID (replace with your actual org ID)
export ORG_ID="123456789012"
export BILLING_ACCOUNT_ID="ABCDEF-123456-GHIJKL"
```

If you don't see an organization, you'll need to [create one](https://cloud.google.com/resource-manager/docs/creating-managing-organization) first.

---

## Step 1: Create Monitoring Project

This project will host the MCP server and store configuration.

```bash
# Set project details
export PROJECT_ID="gcp-cost-monitoring"
export PROJECT_NAME="GCP Cost Monitoring"
export REGION="us-central1"

# Create project
gcloud projects create $PROJECT_ID \
  --name="$PROJECT_NAME" \
  --organization=$ORG_ID

# Link billing account
gcloud billing projects link $PROJECT_ID \
  --billing-account=$BILLING_ACCOUNT_ID

# Set as default project
gcloud config set project $PROJECT_ID
```

---

## Step 2: Enable Required APIs

```bash
# Enable all required GCP APIs
gcloud services enable \
  cloudresourcemanager.googleapis.com \
  serviceusage.googleapis.com \
  cloudbilling.googleapis.com \
  bigquery.googleapis.com \
  recommender.googleapis.com \
  cloudasset.googleapis.com \
  compute.googleapis.com \
  pubsub.googleapis.com \
  run.googleapis.com \
  cloudscheduler.googleapis.com \
  cloudfunctions.googleapis.com

# Verify APIs are enabled
gcloud services list --enabled
```

**Note:** API enablement can take 1-2 minutes.

---

## Step 3: Set Up BigQuery Billing Export

This is the **most critical step** — all cost data comes from here.

### 3.1 Create BigQuery Dataset

```bash
# Create dataset for billing data
bq --location=US mk \
  --dataset \
  --description="GCP Billing Export Data" \
  ${PROJECT_ID}:billing_export
```

### 3.2 Enable Billing Export (via Console)

> ⚠️ **This step must be done in the GCP Console** — there's no gcloud command for it.

1. Go to **Billing** → **Billing Export** in [Google Cloud Console](https://console.cloud.google.com/billing)
2. Select your billing account
3. Click **"Configure Export"** under BigQuery Export
4. Set:
   - **Project**: `gcp-cost-monitoring`
   - **Dataset**: `billing_export`
   - **Table name prefix**: Leave default (will be `gcp_billing_export_v1_<billing_id>`)
5. Click **Save**

### 3.3 Verify Billing Export

```bash
# List tables in billing dataset (may take 24-48 hours for first data)
bq ls ${PROJECT_ID}:billing_export

# Query sample data (run after 24 hours)
bq query --use_legacy_sql=false "
  SELECT 
    DATE(usage_start_time) as date,
    service.description as service,
    SUM(cost) as total_cost
  FROM \`${PROJECT_ID}.billing_export.gcp_billing_export_v1_*\`
  WHERE DATE(usage_start_time) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  GROUP BY date, service
  ORDER BY date DESC, total_cost DESC
  LIMIT 20
"
```

---

## Step 4: Create Service Account

The MCP server uses this service account to access GCP APIs.

```bash
# Create service account
gcloud iam service-accounts create gcp-cost-agent \
  --display-name="GCP Cost Monitoring Agent" \
  --description="Service account for cost monitoring MCP server"

export SA_EMAIL="gcp-cost-agent@${PROJECT_ID}.iam.gserviceaccount.com"
```

### 4.1 Grant Organization-Level Permissions

```bash
# Organization viewer permissions
gcloud organizations add-iam-policy-binding $ORG_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/browser"

gcloud organizations add-iam-policy-binding $ORG_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/resourcemanager.folderViewer"

gcloud organizations add-iam-policy-binding $ORG_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/resourcemanager.organizationViewer"

gcloud organizations add-iam-policy-binding $ORG_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/serviceusage.serviceUsageViewer"

gcloud organizations add-iam-policy-binding $ORG_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/cloudasset.viewer"

gcloud organizations add-iam-policy-binding $ORG_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/recommender.computeViewer"
```

### 4.2 Grant Billing Account Permissions

```bash
# Billing viewer
gcloud billing accounts add-iam-policy-binding $BILLING_ACCOUNT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/billing.viewer"

# Budget permissions
gcloud billing accounts add-iam-policy-binding $BILLING_ACCOUNT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/billing.budgetsViewer"

gcloud billing accounts add-iam-policy-binding $BILLING_ACCOUNT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/billing.budgetsEditor"
```

### 4.3 Grant Project-Level Permissions

```bash
# BigQuery access
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/bigquery.dataViewer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/bigquery.jobUser"

# Compute instance control (for stop/start actions)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/compute.instanceAdmin.v1"
```

### 4.4 Generate Service Account Key

```bash
# Create key (store securely!)
gcloud iam service-accounts keys create ~/gcp-cost-agent-key.json \
  --iam-account=$SA_EMAIL

echo "✅ Service account key saved to: ~/gcp-cost-agent-key.json"
echo "⚠️  Keep this file secure — it grants access to your GCP resources"
```

---

## Step 5: Create Budget with Pub/Sub Alerts

### 5.1 Create Pub/Sub Topic

```bash
# Create topic for budget alerts
gcloud pubsub topics create budget-alerts

# Grant Budget Service permission to publish
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

gcloud pubsub topics add-iam-policy-binding budget-alerts \
  --member="serviceAccount:billingbudgets.googleapis.com@bq-budgets.iam.gserviceaccount.com" \
  --role="roles/pubsub.publisher"
```

### 5.2 Create Budget (via gcloud)

Create a budget configuration file:

```bash
cat > budget.json <<EOF
{
  "displayName": "Monthly Budget - \$5000",
  "budgetFilter": {
    "projects": ["projects/${PROJECT_NUMBER}"]
  },
  "amount": {
    "specifiedAmount": {
      "currencyCode": "USD",
      "units": "5000"
    }
  },
  "thresholdRules": [
    {
      "thresholdPercent": 0.5,
      "spendBasis": "CURRENT_SPEND"
    },
    {
      "thresholdPercent": 0.8,
      "spendBasis": "CURRENT_SPEND"
    },
    {
      "thresholdPercent": 0.8,
      "spendBasis": "FORECASTED_SPEND"
    },
    {
      "thresholdPercent": 1.0,
      "spendBasis": "CURRENT_SPEND"
    }
  ],
  "notificationsRule": {
    "pubsubTopic": "projects/${PROJECT_ID}/topics/budget-alerts",
    "schemaVersion": "1.0"
  }
}
EOF

# Create budget using REST API (gcloud doesn't support budgets yet)
curl -X POST \
  "https://billingbudgets.googleapis.com/v1/billingAccounts/${BILLING_ACCOUNT_ID}/budgets" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d @budget.json
```

---

## Step 6: Set Up Asset Inventory Feed (Optional)

For real-time resource creation alerts:

```bash
# Create Pub/Sub topic for asset changes
gcloud pubsub topics create asset-changes

# Create feed for VM creations
gcloud asset feeds create vm-creation-feed \
  --organization=$ORG_ID \
  --asset-types="compute.googleapis.com/Instance" \
  --content-type="resource" \
  --pubsub-topic="projects/${PROJECT_ID}/topics/asset-changes"
```

---

## Step 7: Deploy MCP Server to Cloud Run

Once you have the MCP server code ready:

```bash
# Build container (assumes Dockerfile exists)
gcloud builds submit --tag gcr.io/${PROJECT_ID}/gcp-cost-mcp-server

# Deploy to Cloud Run
gcloud run deploy gcp-cost-mcp-server \
  --image gcr.io/${PROJECT_ID}/gcp-cost-mcp-server \
  --platform managed \
  --region $REGION \
  --service-account $SA_EMAIL \
  --set-env-vars "GCP_ORGANIZATION_ID=${ORG_ID},GCP_BILLING_ACCOUNT_ID=${BILLING_ACCOUNT_ID},BIGQUERY_PROJECT=${PROJECT_ID},BIGQUERY_DATASET=billing_export" \
  --allow-unauthenticated \
  --max-instances 10 \
  --memory 512Mi \
  --timeout 60s

# Get service URL
export MCP_SERVER_URL=$(gcloud run services describe gcp-cost-mcp-server --region $REGION --format="value(status.url)")
echo "MCP Server URL: $MCP_SERVER_URL"
```

---

## Step 8: Test the Setup

### 8.1 Test BigQuery Access

```python
from google.cloud import bigquery
from google.oauth2 import service_account

# Load service account
credentials = service_account.Credentials.from_service_account_file(
    '~/gcp-cost-agent-key.json'
)

client = bigquery.Client(credentials=credentials, project='gcp-cost-monitoring')

# Query billing data
query = """
  SELECT 
    DATE(usage_start_time) as date,
    SUM(cost) as total_cost
  FROM `gcp-cost-monitoring.billing_export.gcp_billing_export_v1_*`
  WHERE DATE(usage_start_time) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  GROUP BY date
  ORDER BY date DESC
"""

results = client.query(query)
for row in results:
    print(f"{row.date}: ${row.total_cost:.2f}")
```

### 8.2 Test Budget API

```python
from google.cloud import billing_budgets_v1

client = billing_budgets_v1.BudgetServiceClient(credentials=credentials)

# List budgets
parent = f"billingAccounts/{billing_account_id}"
budgets = client.list_budgets(parent=parent)

for budget in budgets:
    print(f"Budget: {budget.display_name}, Amount: ${budget.amount.specified_amount.units}")
```

### 8.3 Test Recommender API

```python
from google.cloud import recommender_v1

client = recommender_v1.RecommenderClient(credentials=credentials)

# Get idle VM recommendations
parent = f"projects/{project_id}/locations/us-central1/recommenders/google.compute.instance.IdleResourceRecommender"
recommendations = client.list_recommendations(parent=parent)

for rec in recommendations:
    print(f"Recommendation: {rec.description}")
```

---

## Environment Variables Summary

Create a `.env` file for local development:

```bash
# GCP Configuration
GCP_ORGANIZATION_ID=123456789012
GCP_BILLING_ACCOUNT_ID=ABCDEF-123456-GHIJKL
GOOGLE_APPLICATION_CREDENTIALS=/path/to/gcp-cost-agent-key.json

# BigQuery
BIGQUERY_PROJECT=gcp-cost-monitoring
BIGQUERY_DATASET=billing_export
BIGQUERY_TABLE_PREFIX=gcp_billing_export_v1_

# Pub/Sub
PUBSUB_PROJECT=gcp-cost-monitoring
PUBSUB_BUDGET_TOPIC=budget-alerts
PUBSUB_ASSET_TOPIC=asset-changes

# MCP Server
MCP_SERVER_PORT=8080
```

---

## Troubleshooting

### Billing Export Not Working

**Problem:** No data in BigQuery after 24 hours

**Solutions:**
- Verify billing export is enabled in Console
- Check dataset permissions (Billing Account needs `bigquery.dataEditor` on dataset)
- Confirm you have actual GCP spend (minimum $0.01)

### Permission Denied Errors

**Problem:** `403 Forbidden` when querying APIs

**Solutions:**
- Verify service account has all required roles
- Wait 1-2 minutes after granting roles (propagation delay)
- Check if APIs are enabled in the project

### Budget Alerts Not Firing

**Problem:** Pub/Sub topic not receiving messages

**Solutions:**
- Verify Billing Budgets service account has `pubsub.publisher` role
- Check budget thresholds are actually exceeded
- Test Pub/Sub topic manually: `gcloud pubsub topics publish budget-alerts --message "test"`

---

## Next Steps

Now that your GCP environment is configured:

1. ✅ **Implement MCP Server** - Build the Python FastMCP server with tools
2. ✅ **Add Conversational Agent** - LangChain or Google ADK integration
3. ✅ **Build UI** - CLI, web interface, or Slack bot
4. ✅ **Test with Real Data** - Run queries against your actual billing data

---

## Security Checklist

Before going to production:

- [ ] Service account key stored securely (not in git)
- [ ] Least-privilege IAM roles verified
- [ ] Audit logging enabled on all API calls
- [ ] MCP server requires authentication
- [ ] Budget alerts monitored
- [ ] Credential rotation policy defined

---

**Setup Complete!** 🎉

You should now have:
- ✅ Billing data flowing to BigQuery
- ✅ Service account with proper permissions
- ✅ Budget alerts configured
- ✅ All required APIs enabled

Start building your MCP server!
