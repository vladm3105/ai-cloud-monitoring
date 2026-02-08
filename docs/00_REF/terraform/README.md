# Terraform Infrastructure for AI Cloud Cost Monitoring

This directory contains the Terraform infrastructure-as-code for deploying the AI Cloud Cost Monitoring platform on Google Cloud Platform.

## Structure

```
terraform/
├── main.tf              # Main Terraform configuration
├── variables.tf         # Variable declarations
├── outputs.tf           # Output values
├── provider.tf          # GCP provider configuration
├── terraform.tfvars     # Variable values (gitignored)
└── modules/
    ├── cloud-run/       # Cloud Run services module
    ├── networking/      # VPC, Load Balancer module
    └── storage/         # Cloud Storage, databases module
```

## Prerequisites

1. **Terraform** v1.6 or later
2. **gcloud CLI** configured with appropriate project
3. **GCP Project** with billing enabled
4. **Service Account** with necessary permissions

## Quick Start

### 1. Initialize Terraform

```bash
cd terraform
terraform init
```

### 2. Configure Variables

Create a `terraform.tfvars` file:

```hcl
project_id = "your-gcp-project-id"
region     = "us-central1"
environment = "production"

# Database configuration
database_tier = "db-custom-1-3840"
database_password = "your-secure-password"  # Better: use Secret Manager

# Redis configuration
redis_memory_size_gb = 1

# Auth0 configuration
auth0_domain = "your-tenant.us.auth0.com"
auth0_client_id = "your-client-id"
```

### 3. Plan Deployment

```bash
terraform plan
```

Review the planned changes carefully.

### 4. Apply Infrastructure

```bash
terraform apply
```

Type `yes` when prompted to confirm.

### 5. View Outputs

```bash
terraform output
```

This will show:
- Database connection info
- Redis host and port
- Cloud Run service URLs
- Service account email

## Modules

### cloud-run

Deploys Cloud Run services:
- Frontend (Next.js)
- Backend (FastAPI)
- MCP Server (GCP Cost)

### networking

Sets up:
- VPC network
- VPC connector for Cloud Run
- Cloud NAT (optional)
- Load Balancer (optional)

### storage

Provisions:
- Cloud SQL (PostgreSQL)
- Cloud Memorystore (Redis)
- Cloud Storage buckets
- BigQuery dataset

## Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `project_id` | GCP Project ID | - | Yes |
| `region` | Primary GCP region | `us-central1` | No |
| `environment` | Environment name | `production` | No |
| `database_tier` | Cloud SQL tier | `db-custom-1-3840` | No |
| `redis_memory_size_gb` | Redis memory in GB | `1` | No |

## Outputs

| Output | Description |
|--------|-------------|
| `database_connection_name` | Cloud SQL connection name |
| `database_private_ip` | Private IP of Cloud SQL |
| `redis_host` | Redis host address |
| `backend_url` | Backend Cloud Run URL |
| `frontend_url` | Frontend Cloud Run URL |
| `service_account_email` | Service account email |

## State Management

By default, Terraform state is stored locally. For production, use a remote backend:

```hcl
# In provider.tf
terraform {
  backend "gcs" {
    bucket = "your-terraform-state-bucket"
    prefix = "ai-cost-monitoring/state"
  }
}
```

## Best Practices

1. **Never commit `terraform.tfvars`** - Contains sensitive data
2. **Use Secret Manager** - For passwords and API keys
3. **Enable state locking** - Use GCS backend with locking
4. **Tag resources** - Add labels for cost tracking
5. **Use workspaces** - For dev/staging/production environments

## Cost Estimate

Running `terraform plan` will show estimated costs. Typical monthly costs:

- **Development**: ~$50-75/month
- **Production**: ~$200-400/month

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

⚠️ **Warning**: This will delete all data. Make sure you have backups!

## Troubleshooting

### Error: "Error creating database instance"

**Solution**: Ensure you have `sqladmin.googleapis.com` API enabled:
```bash
gcloud services enable sqladmin.googleapis.com
```

### Error: "Quota exceeded"

**Solution**: Request quota increase in GCP Console or deploy fewer resources initially.

### Error: "Invalid service account"

**Solution**: Ensure the service account exists and has necessary permissions.

## Support

For issues or questions:
- Check [GCP-DEPLOYMENT.md](../GCP-DEPLOYMENT.md)
- Review [ADRs](../domain/)
- Open an issue in the repository
