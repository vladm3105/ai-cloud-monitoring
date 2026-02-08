# ========================================
# Service Account for Cloud Run Services
# ========================================

resource "google_service_account" "cloud_run" {
  account_id   = "ai-cost-monitoring-sa"
  display_name = "AI Cost Monitoring Service Account"
  description  = "Service account for Cloud Run services"
}

# Grant Cloud SQL Client role
resource "google_project_iam_member" "cloud_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

# Grant BigQuery Data Viewer role
resource "google_project_iam_member" "bigquery_viewer" {
  project = var.project_id
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

# Grant Secret Manager Secret Accessor role
resource "google_project_iam_member" "secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

# ========================================
# Cloud SQL Instance (PostgreSQL)
# ========================================

resource "google_sql_database_instance" "main" {
  name             = "ai-cost-monitoring-db"
  database_version = "POSTGRES_16"
  region           = var.region

  settings {
    tier = var.database_tier
    
    ip_configuration {
      ipv4_enabled    = false  # Private IP only
      private_network = google_compute_network.vpc.id
    }

    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
    }

    database_flags {
      name  = "max_connections"
      value = "100"
    }
  }

  deletion_protection = true  # Prevent accidental deletion
}

resource "google_sql_database" "database" {
  name     = var.database_name
  instance = google_sql_database_instance.main.name
}

resource "google_sql_user" "user" {
  name     = var.database_user
  instance = google_sql_database_instance.main.name
  password = var.database_password
}

# ========================================
# Redis Instance
# ========================================

resource "google_redis_instance" "cache" {
  name           = "ai-cost-monitoring-cache"
  tier           = var.redis_tier
  memory_size_gb = var.redis_memory_size_gb
  region         = var.region

  redis_version     = "REDIS_7_0"
  display_name      = "AI Cost Monitoring Cache"
  authorized_network = google_compute_network.vpc.id
}

# ========================================
# VPC Network
# ========================================

resource "google_compute_network" "vpc" {
  name                    = var.vpc_network_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.vpc_network_name}-subnet"
  ip_cidr_range = "10.0.0.0/20"
  region        = var.region
  network       = google_compute_network.vpc.id

  private_ip_google_access = true
}

# VPC Access Connector for Cloud Run
resource "google_vpc_access_connector" "connector" {
  name          = "ai-cost-monitoring-connector"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.8.0.0/28"
}

# ========================================
# BigQuery Dataset for Cost Metrics
# ========================================

resource "google_bigquery_dataset" "cost_data" {
  dataset_id  = "cloud_costs"
  description = "Cloud cost metrics and billing data"
  location    = "US"

  labels = var.labels
}

# ========================================
# Cloud Storage Bucket
# ========================================

resource "google_storage_bucket" "reports" {
  name          = "${var.project_id}-cost-reports"
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  labels = var.labels
}

# ========================================
# Cloud Run Services
# ========================================

# Backend Service
resource "google_cloud_run_service" "backend" {
  name     = "ai-cost-monitoring-backend"
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.cloud_run.email

      containers {
        image = var.backend_image

        env {
          name  = "GCP_PROJECT_ID"
          value = var.project_id
        }

        env {
          name  = "DATABASE_HOST"
          value = google_sql_database_instance.main.private_ip_address
        }

        env {
          name  = "REDIS_HOST"
          value = google_redis_instance.cache.host
        }

        env {
          name  = "ENVIRONMENT"
          value = var.environment
        }

        resources {
          limits = {
            cpu    = "2"
            memory = "1Gi"
          }
        }
      }
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale"         = "1"
        "autoscaling.knative.dev/maxScale"         = "20"
        "run.googleapis.com/vpc-access-connector"  = google_vpc_access_connector.connector.id
        "run.googleapis.com/cloudsql-instances"    = google_sql_database_instance.main.connection_name
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

# Frontend Service
resource "google_cloud_run_service" "frontend" {
  name     = "ai-cost-monitoring-frontend"
  location = var.region

  template {
    spec {
      containers {
        image = var.frontend_image

        env {
          name  = "NEXT_PUBLIC_BACKEND_URL"
          value = google_cloud_run_service.backend.status[0].url
        }

        resources {
          limits = {
            cpu    = "1"
            memory = "512Mi"
          }
        }
      }
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale" = "0"
        "autoscaling.knative.dev/maxScale" = "10"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

# MCP Server
resource "google_cloud_run_service" "mcp_server" {
  name     = "gcp-cost-mcp-server"
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.cloud_run.email

      containers {
        image = var.mcp_server_image

        env {
          name  = "GCP_PROJECT_ID"
          value = var.project_id
        }

        resources {
          limits = {
            cpu    = "1"
            memory = "512Mi"
          }
        }
      }
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale" = "0"
        "autoscaling.knative.dev/maxScale" = "5"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

# ========================================
# IAM Policies for Cloud Run
# ========================================

# Allow public access to frontend
resource "google_cloud_run_service_iam_member" "frontend_public" {
  service  = google_cloud_run_service.frontend.name
  location = google_cloud_run_service.frontend.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Allow public access to backend (should be protected by Auth0)
resource "google_cloud_run_service_iam_member" "backend_public" {
  service  = google_cloud_run_service.backend.name
  location = google_cloud_run_service.backend.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# MCP Server is private - only accessible by backend
resource "google_cloud_run_service_iam_member" "mcp_server_backend" {
  service  = google_cloud_run_service.mcp_server.name
  location = google_cloud_run_service.mcp_server.location
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.cloud_run.email}"
}
