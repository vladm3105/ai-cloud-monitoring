# Service Account
output "service_account_email" {
  description = "Service account email for Cloud Run services"
  value       = google_service_account.cloud_run.email
}

# Database Outputs
output "database_connection_name" {
  description = "Cloud SQL connection name"
  value       = google_sql_database_instance.main.connection_name
}

output "database_private_ip" {
  description = "Private IP address of Cloud SQL instance"
  value       = google_sql_database_instance.main.private_ip_address
}

output "database_public_ip" {
  description = "Public IP address of Cloud SQL instance (if enabled)"
  value       = google_sql_database_instance.main.public_ip_address
}

# Redis Outputs
output "redis_host" {
  description = "Redis instance host"
  value       = google_redis_instance.cache.host
}

output "redis_port" {
  description = "Redis instance port"
  value       = google_redis_instance.cache.port
}

# Cloud Run Service URLs
output "backend_url" {
  description = "Backend Cloud Run service URL"
  value       = google_cloud_run_service.backend.status[0].url
}

output "frontend_url" {
  description = "Frontend Cloud Run service URL"
  value       = google_cloud_run_service.frontend.status[0].url
}

output "mcp_server_url" {
  description = "MCP Server Cloud Run service URL"
  value       = google_cloud_run_service.mcp_server.status[0].url
}

# VPC Connector
output "vpc_connector_name" {
  description = "VPC connector name for Cloud Run"
  value       = google_vpc_access_connector.connector.name
}

# BigQuery Dataset
output "bigquery_dataset_id" {
  description = "BigQuery dataset ID for cost metrics"
  value       = google_bigquery_dataset.cost_data.dataset_id
}

# Instructions
output "next_steps" {
  description = "Next steps after infrastructure deployment"
  value = <<-EOT
  Infrastructure deployed successfully!
  
  Next steps:
  1. Update .env file with the output values
  2. Run database migrations: alembic upgrade head
  3. Deploy application containers to Cloud Run
  4. Configure Auth0 callback URLs with frontend_url
  5. Set up monitoring dashboards
  
  Database Connection: ${google_sql_database_instance.main.connection_name}
  Backend URL: ${google_cloud_run_service.backend.status[0].url}
  Frontend URL: ${google_cloud_run_service.frontend.status[0].url}
  EOT
}
