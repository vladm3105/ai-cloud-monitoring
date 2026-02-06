variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region for resources"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name (production, staging, development)"
  type        = string
  default     = "production"
}

# Database Variables
variable "database_tier" {
  description = "Cloud SQL instance tier"
  type        = string
  default     = "db-custom-1-3840"  # 1 vCPU, 3.75 GB RAM
}

variable "database_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "ai_cost_monitoring"
}

variable "database_user" {
  description = "PostgreSQL user name"
  type        = string
  default     = "postgres"
}

variable "database_password" {
  description = "PostgreSQL password (use Secret Manager in production)"
  type        = string
  sensitive   = true
}

# Redis Variables
variable "redis_memory_size_gb" {
  description = "Redis memory size in GB"
  type        = number
  default     = 1
}

variable "redis_tier" {
  description = "Redis tier (BASIC or STANDARD_HA)"
  type        = string
  default     = "BASIC"
}

# Auth0 Variables
variable "auth0_domain" {
  description = "Auth0 domain"
  type        = string
}

variable "auth0_client_id" {
  description = "Auth0 client ID"
  type        = string
  sensitive   = true
}

variable "auth0_client_secret" {
  description = "Auth0 client secret"
  type        = string
  sensitive   = true
}

# Cloud Run Variables
variable "backend_image" {
  description = "Backend container image"
  type        = string
  default     = "gcr.io/PROJECT_ID/backend:latest"
}

variable "frontend_image" {
  description = "Frontend container image"
  type        = string
  default     = "gcr.io/PROJECT_ID/frontend:latest"
}

variable "mcp_server_image" {
  description = "MCP server container image"
  type        = string
  default     = "gcr.io/PROJECT_ID/gcp-mcp-server:latest"
}

# Networking Variables
variable "vpc_network_name" {
  description = "VPC network name"
  type        = string
  default     = "ai-cost-monitoring-vpc"
}

# Labels
variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default = {
    project     = "ai-cost-monitoring"
    managed-by  = "terraform"
  }
}
