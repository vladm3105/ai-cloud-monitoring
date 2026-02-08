# AI Cost Monitoring - Docker Deployment Architecture
## Grafana + Prometheus + Loki + Promtail Stack

**Document Version:** 1.0  
**Last Updated:** February 2026  
**Target Deployment:** Docker Compose, Docker Swarm, Self-Hosted VMs

---

## Executive Summary

This document provides the complete architecture for deploying the AI Cost Monitoring observability stack using Docker. This deployment model is ideal for:
- Local development environments
- Self-hosted production on VMs or bare metal
- On-premise data centers
- Situations where full control and no cloud dependencies are required

**Stack Components:**
- **Grafana** - Visualization
- **Prometheus** - Metrics
- **Loki** - Logs
- **Promtail** - Log collection (optional, but recommended)
- **TimescaleDB** - Historical cost data

**Total Infrastructure Cost:** $50-80/month (VM hosting) or $0 (on-premise)

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Component Stack](#2-component-stack)
3. [Docker Compose Deployment](#3-docker-compose-deployment)
4. [Promtail Configuration](#4-promtail-configuration)
5. [Volume Management](#5-volume-management)
6. [Configuration Files](#6-configuration-files)
7. [Dashboard Structure](#7-dashboard-structure)
8. [Alerting Rules](#8-alerting-rules)
9. [Production Deployment](#9-production-deployment)
10. [Maintenance & Operations](#10-maintenance--operations)

---

## 1. Architecture Overview

### Docker-Based Observability Stack

```
┌─────────────────────────────────────────────────────────────────────┐
│                          HOST SERVER                                 │
│                    (Docker Engine Installed)                         │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                   Docker Compose Stack                       │   │
│  │                                                              │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │   │
│  │  │  Grafana    │  │ Prometheus  │  │    Loki     │         │   │
│  │  │  :3000      │  │   :9090     │  │   :3100     │         │   │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │   │
│  │         │                │                │                 │   │
│  │         └────────────────┼────────────────┘                 │   │
│  │                          │                                  │   │
│  │  ┌─────────────┐  ┌──────┴──────┐  ┌─────────────┐         │   │
│  │  │ TimescaleDB │  │  Promtail   │  │ Cost Monitor│         │   │
│  │  │   :5432     │  │  (sidecar)  │  │     App     │         │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘         │   │
│  │                                                              │   │
│  │  All connected via Docker network: monitoring-network       │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    Docker Volumes                            │   │
│  │                                                              │   │
│  │  prometheus-data    → /prometheus  (metrics, 15 days)        │   │
│  │  loki-data          → /loki        (logs, 30 days)           │   │
│  │  grafana-data       → /var/lib/grafana (dashboards, users)   │   │
│  │  timescaledb-data   → /var/lib/postgresql (cost data, 2yr)   │   │
│  │  app-logs           → /var/log     (application logs)        │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

### Data Flow

```
Cost Monitor App
    ├─ Exposes /metrics → Prometheus scrapes every 15s
    └─ Writes logs to /var/log/app/*.log → Promtail tails → Loki

ETL Pipeline
    ├─ Pulls from cloud billing APIs → TimescaleDB
    └─ Exports metrics → Prometheus

Grafana
    ├─ Queries Prometheus (metrics)
    ├─ Queries Loki (logs)
    └─ Queries TimescaleDB (historical cost data)
```

---

## 2. Component Stack

### Core Services

| Service | Image | Purpose | Port | Resources |
|---------|-------|---------|------|-----------|
| **Grafana** | grafana/grafana:latest | Dashboards | 3000 | 512MB RAM |
| **Prometheus** | prom/prometheus:latest | Metrics TSDB | 9090 | 1GB RAM, 10GB disk |
| **Loki** | grafana/loki:latest | Log aggregation | 3100 | 1GB RAM, 20GB disk |
| **Promtail** | grafana/promtail:latest | Log shipper | - | 128MB RAM |
| **TimescaleDB** | timescale/timescaledb:latest-pg14 | Cost data | 5432 | 512MB RAM, 50GB disk |

### When to Use Promtail

| Scenario | Use Promtail? | Why |
|----------|---------------|-----|
| **Docker Compose** | ⚠️ Optional | Can use Loki Docker driver OR Promtail |
| **Multiple hosts** | ✅ Yes | Need agent on each host to collect logs |
| **File-based logs** | ✅ Yes | Only way to tail log files |
| **Kubernetes** | ⚠️ Alternative | Use Fluent Bit DaemonSet instead (lighter) |
| **Development** | ❌ No | Loki Docker driver is simpler |

**Recommendation:** Use Promtail for production Docker deployments, skip it for local development.

---

## 3. Docker Compose Deployment

### 3.1 Full Stack (Development)

**docker-compose.yml:**
```yaml
version: '3.8'

networks:
  monitoring:
    driver: bridge

volumes:
  prometheus-data:
  loki-data:
  grafana-data:
  timescaledb-data:

services:
  # ============================================================
  # GRAFANA - Visualization
  # ============================================================
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SERVER_ROOT_URL=http://localhost:3000
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/var/lib/grafana/dashboards
    networks:
      - monitoring
    depends_on:
      - prometheus
      - loki
      - timescaledb
    restart: unless-stopped

  # ============================================================
  # PROMETHEUS - Metrics Storage
  # ============================================================
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=15d'
      - '--web.enable-lifecycle'
    volumes:
      - prometheus-data:/prometheus
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./prometheus/alerts:/etc/prometheus/alerts:ro
    networks:
      - monitoring
    restart: unless-stopped

  # ============================================================
  # LOKI - Log Aggregation
  # ============================================================
  loki:
    image: grafana/loki:latest
    container_name: loki
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    volumes:
      - loki-data:/loki
      - ./loki/loki-config.yaml:/etc/loki/local-config.yaml:ro
    networks:
      - monitoring
    restart: unless-stopped

  # ============================================================
  # PROMTAIL - Log Shipper (Optional)
  # ============================================================
  promtail:
    image: grafana/promtail:latest
    container_name: promtail
    command: -config.file=/etc/promtail/config.yml
    volumes:
      - ./promtail/promtail-config.yml:/etc/promtail/config.yml:ro
      - /var/log:/var/log:ro  # Host logs
      - /var/lib/docker/containers:/var/lib/docker/containers:ro  # Container logs
    networks:
      - monitoring
    depends_on:
      - loki
    restart: unless-stopped

  # ============================================================
  # TIMESCALEDB - Historical Cost Data
  # ============================================================
  timescaledb:
    image: timescale/timescaledb:latest-pg14
    container_name: timescaledb
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=cost_monitoring
    volumes:
      - timescaledb-data:/var/lib/postgresql/data
      - ./timescaledb/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    networks:
      - monitoring
    restart: unless-stopped

  # ============================================================
  # COST MONITOR APP - Your Application
  # ============================================================
  cost-monitor:
    build: ./app
    container_name: cost-monitor
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=postgresql://postgres:postgres@timescaledb:5432/cost_monitoring
      - PROMETHEUS_PORT=8080
    volumes:
      - ./app/logs:/var/log/app  # For Promtail to tail
    logging:
      # Option 1: Use Loki Docker driver (no Promtail needed)
      driver: loki
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-batch-size: "400"
        labels: "service=cost-monitor,environment=production"
    networks:
      - monitoring
    depends_on:
      - timescaledb
      - prometheus
    restart: unless-stopped
```

### 3.2 Simplified Stack (Without Promtail)

If using Loki Docker logging driver, remove the `promtail` service and use this logging configuration:

```yaml
services:
  cost-monitor:
    # ... other config
    logging:
      driver: loki
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-batch-size: "400"
        labels: "service=cost-monitor,environment=production"
        max-size: "10m"
        max-file: "3"
```

### 3.3 Deployment Commands

```bash
# Clone repository
git clone https://github.com/your-org/ai-cost-monitoring.git
cd ai-cost-monitoring/monitoring

# Create required directories
mkdir -p grafana/provisioning/datasources
mkdir -p grafana/provisioning/dashboards
mkdir -p grafana/dashboards
mkdir -p prometheus/alerts
mkdir -p loki
mkdir -p promtail
mkdir -p timescaledb

# Start the stack
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f

# Stop the stack
docker-compose down

# Stop and remove volumes (⚠️ DELETES ALL DATA)
docker-compose down -v
```

---

## 4. Promtail Configuration

### 4.1 When to Use Promtail

**Use Promtail if:**
- ✅ Apps write logs to files (not stdout)
- ✅ Multiple hosts need log collection
- ✅ Need to tail system logs (/var/log/syslog, etc.)
- ✅ Want centralized log collection from multiple containers

**Skip Promtail if:**
- ❌ Using Docker logging drivers (Loki driver)
- ❌ Apps log to stdout only
- ❌ Single-host development environment

### 4.2 Promtail Configuration File

**promtail/promtail-config.yml:**
```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  # Scrape application logs from files
  - job_name: app-logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: cost-monitor
          __path__: /var/log/app/*.log

  # Scrape Docker container logs
  - job_name: docker-logs
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        regex: '/(.*)'
        target_label: 'container'
      - source_labels: ['__meta_docker_container_log_stream']
        target_label: 'stream'
      - source_labels: ['__meta_docker_container_label_com_docker_compose_service']
        target_label: 'service'

  # Scrape system logs (optional)
  - job_name: system-logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: system
          __path__: /var/log/syslog
```

### 4.3 Promtail as Sidecar

For file-based logs from your app, run Promtail as a sidecar:

```yaml
services:
  cost-monitor:
    # ... app config
    volumes:
      - app-logs:/var/log/app

  promtail:
    image: grafana/promtail:latest
    command: -config.file=/etc/promtail/config.yml
    volumes:
      - app-logs:/var/log/app:ro
      - ./promtail/promtail-config.yml:/etc/promtail/config.yml:ro
    networks:
      - monitoring
    depends_on:
      - loki
```

---

## 5. Volume Management

### 5.1 Docker Volumes

| Volume | Purpose | Typical Size | Backup Priority |
|--------|---------|--------------|-----------------|
| `prometheus-data` | Metrics (15 days) | 10-20GB | Medium |
| `loki-data` | Logs (30 days) | 20-50GB | Medium |
| `grafana-data` | Dashboards, users | 500MB | **High** |
| `timescaledb-data` | Historical cost (2 years) | 50-100GB | **High** |
| `app-logs` | Application logs | 1-5GB | Low |

### 5.2 Backup Strategy

**Critical Data (Daily Backups):**
```bash
#!/bin/bash
# backup-monitoring.sh

BACKUP_DIR="/backup/monitoring/$(date +%Y-%m-%d)"
mkdir -p $BACKUP_DIR

# Backup Grafana dashboards and config
docker run --rm -v grafana-data:/data -v $BACKUP_DIR:/backup \
  alpine tar czf /backup/grafana-backup.tar.gz -C /data .

# Backup TimescaleDB
docker exec timescaledb pg_dump -U postgres cost_monitoring | \
  gzip > $BACKUP_DIR/timescaledb-backup.sql.gz

# Backup Prometheus data (optional, can be regenerated)
docker run --rm -v prometheus-data:/data -v $BACKUP_DIR:/backup \
  alpine tar czf /backup/prometheus-backup.tar.gz -C /data .

echo "Backup completed: $BACKUP_DIR"
```

**Restore:**
```bash
#!/bin/bash
# restore-monitoring.sh

BACKUP_DIR="/backup/monitoring/2026-02-05"

# Restore Grafana
docker run --rm -v grafana-data:/data -v $BACKUP_DIR:/backup \
  alpine tar xzf /backup/grafana-backup.tar.gz -C /data

# Restore TimescaleDB
gunzip < $BACKUP_DIR/timescaledb-backup.sql.gz | \
  docker exec -i timescaledb psql -U postgres cost_monitoring

echo "Restore completed"
```

### 5.3 Volume Cleanup

```bash
# Remove old Prometheus data (keep last 15 days)
docker exec prometheus promtool tsdb delete --time-range=15d /prometheus

# Remove old Loki chunks (keep last 30 days)
# This happens automatically based on loki-config.yaml retention settings

# Check disk usage
docker system df -v
```

---

## 6. Configuration Files

### 6.1 Prometheus Configuration

**prometheus/prometheus.yml:**
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

# Alert rules
rule_files:
  - '/etc/prometheus/alerts/*.yml'

# Scrape targets
scrape_configs:
  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Cost Monitor app
  - job_name: 'cost-monitor'
    static_configs:
      - targets: ['cost-monitor:8080']
        labels:
          service: 'cost-monitor'
          environment: 'production'

  # Docker container metrics (cAdvisor)
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  # Node exporter (host metrics)
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
```

### 6.2 Loki Configuration

**loki/loki-config.yaml:**
```yaml
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

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/boltdb-shipper-active
    cache_location: /loki/boltdb-shipper-cache
    cache_ttl: 24h
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks

compactor:
  working_directory: /loki/boltdb-shipper-compactor
  shared_store: filesystem

limits_config:
  retention_period: 720h  # 30 days
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  max_query_series: 10000
  max_query_parallelism: 32

chunk_store_config:
  max_look_back_period: 720h

table_manager:
  retention_deletes_enabled: true
  retention_period: 720h
```

### 6.3 Grafana Provisioning

**grafana/provisioning/datasources/datasources.yml:**
```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    jsonData:
      timeInterval: '15s'
    editable: false

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    jsonData:
      maxLines: 1000
    editable: false

  - name: TimescaleDB
    type: postgres
    access: proxy
    url: timescaledb:5432
    database: cost_monitoring
    user: postgres
    secureJsonData:
      password: postgres
    jsonData:
      sslmode: 'disable'
      postgresVersion: 1400
      timescaledb: true
    editable: false
```

**grafana/provisioning/dashboards/dashboards.yml:**
```yaml
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
```

### 6.4 TimescaleDB Initialization

**timescaledb/init.sql:**
```sql
-- Enable TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Create unified cost consumption table
CREATE TABLE IF NOT EXISTS llm_consumption (
  timestamp TIMESTAMPTZ NOT NULL,
  cloud_provider VARCHAR(10),
  service VARCHAR(50),
  model VARCHAR(50),
  operation VARCHAR(20),
  
  -- Metrics
  input_tokens BIGINT,
  output_tokens BIGINT,
  total_tokens BIGINT,
  request_count INT,
  
  -- Cost
  cost_usd DECIMAL(10,4),
  cost_per_1k_tokens DECIMAL(10,6),
  
  -- Attribution
  project_id VARCHAR(100),
  customer_id VARCHAR(100),
  feature_name VARCHAR(100),
  
  -- Metadata
  region VARCHAR(50),
  response_time_ms INT
);

-- Convert to hypertable (time-series optimization)
SELECT create_hypertable('llm_consumption', 'timestamp', 
  chunk_time_interval => INTERVAL '1 day');

-- Create indexes
CREATE INDEX idx_provider_model ON llm_consumption (cloud_provider, model, timestamp DESC);
CREATE INDEX idx_customer ON llm_consumption (customer_id, timestamp DESC);
CREATE INDEX idx_project ON llm_consumption (project_id, timestamp DESC);

-- Create continuous aggregates for daily rollups
CREATE MATERIALIZED VIEW llm_consumption_daily
WITH (timescaledb.continuous) AS
SELECT 
  time_bucket('1 day', timestamp) AS day,
  cloud_provider,
  model,
  customer_id,
  SUM(total_tokens) AS total_tokens,
  SUM(cost_usd) AS total_cost,
  COUNT(*) AS request_count
FROM llm_consumption
GROUP BY day, cloud_provider, model, customer_id;

-- Retention policy (keep 2 years, then drop old chunks)
SELECT add_retention_policy('llm_consumption', INTERVAL '2 years');

-- Grant permissions
GRANT ALL ON llm_consumption TO postgres;
GRANT SELECT ON llm_consumption_daily TO postgres;
```

---

## 7. Dashboard Structure

(Same as cloud deployment - see cloud document Section 8)

---

## 8. Alerting Rules

**prometheus/alerts/cost-alerts.yml:**
```yaml
groups:
  - name: llm_cost_alerts
    interval: 1m
    rules:
      - alert: LLMCostSpike
        expr: rate(llm_cost_usd_total[1h]) > 100
        for: 10m
        labels:
          severity: warning
          category: cost
        annotations:
          summary: "LLM costs exceeding $100/hour"
          description: "Provider {{ $labels.provider }} costs are {{ $value }}/hour"

      - alert: DailyBudgetExceeded
        expr: sum(increase(llm_cost_usd_total[1d])) > 2000
        for: 5m
        labels:
          severity: critical
          category: cost
        annotations:
          summary: "Daily budget of $2000 exceeded"
```

**prometheus/alerts/system-alerts.yml:**
```yaml
groups:
  - name: docker_health
    interval: 30s
    rules:
      - alert: ContainerDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Container {{ $labels.job }} is down"

      - alert: HighMemoryUsage
        expr: (container_memory_usage_bytes / container_spec_memory_limit_bytes) > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} memory usage >90%"

      - alert: DiskSpacelow
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) < 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Disk space below 10% on {{ $labels.device }}"
```

---

## 9. Production Deployment

### 9.1 Production docker-compose.yml

Add these for production:

```yaml
services:
  # Add cAdvisor for container metrics
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    ports:
      - "8081:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    privileged: true
    networks:
      - monitoring
    restart: unless-stopped

  # Add Node Exporter for host metrics
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    networks:
      - monitoring
    restart: unless-stopped

  # Add Alertmanager for alert routing
  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
    networks:
      - monitoring
    restart: unless-stopped
```

### 9.2 Alertmanager Configuration

**alertmanager/alertmanager.yml:**
```yaml
global:
  resolve_timeout: 5m
  slack_api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'

route:
  group_by: ['alertname', 'severity']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'slack-notifications'
  routes:
    - match:
        severity: critical
      receiver: 'slack-critical'
      continue: true

receivers:
  - name: 'slack-notifications'
    slack_configs:
      - channel: '#monitoring'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'

  - name: 'slack-critical'
    slack_configs:
      - channel: '#alerts-critical'
        title: '🚨 CRITICAL: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname']
```

### 9.3 Production Checklist

- [ ] Set strong passwords (Grafana, TimescaleDB)
- [ ] Enable HTTPS (reverse proxy: nginx, Traefik)
- [ ] Configure backup automation
- [ ] Set up external monitoring (uptime check)
- [ ] Configure log rotation
- [ ] Set resource limits in docker-compose.yml
- [ ] Enable Docker security scanning
- [ ] Set up firewall rules
- [ ] Configure alerting (Slack, PagerDuty)
- [ ] Document recovery procedures

---

## 10. Maintenance & Operations

### 10.1 Routine Tasks

**Daily:**
```bash
# Check service health
docker-compose ps

# Check disk usage
df -h
docker system df
```

**Weekly:**
```bash
# Rotate logs
docker-compose logs --tail=0 --follow > /dev/null

# Check for updates
docker-compose pull
docker-compose up -d

# Verify backups
ls -lh /backup/monitoring/
```

**Monthly:**
```bash
# Clean old Docker images
docker image prune -a

# Vacuum TimescaleDB
docker exec timescaledb psql -U postgres -c "VACUUM ANALYZE;"

# Review retention policies
docker exec prometheus promtool tsdb stats /prometheus
```

### 10.2 Troubleshooting

**Container won't start:**
```bash
# Check logs
docker-compose logs <service-name>

# Check resource usage
docker stats

# Restart single service
docker-compose restart <service-name>
```

**Prometheus disk full:**
```bash
# Reduce retention
docker exec prometheus promtool tsdb delete --time-range=7d /prometheus

# Or edit prometheus.yml:
# --storage.tsdb.retention.time=7d
```

**Loki disk full:**
```bash
# Reduce retention in loki-config.yaml
retention_period: 336h  # 14 days instead of 30

# Restart Loki
docker-compose restart loki
```

### 10.3 Monitoring the Monitoring

Add these Prometheus queries to monitor the stack itself:

```promql
# Prometheus storage size
prometheus_tsdb_storage_blocks_bytes

# Loki ingestion rate
sum(rate(loki_distributor_bytes_received_total[1m]))

# Grafana request rate
sum(rate(grafana_api_response_status_total[1m]))

# Container memory usage
container_memory_usage_bytes{name=~"prometheus|loki|grafana"}
```

---

## Quick Start Commands

```bash
# 1. Clone and setup
git clone https://github.com/your-org/ai-cost-monitoring.git
cd ai-cost-monitoring/monitoring

# 2. Create directories
mkdir -p grafana/provisioning/{datasources,dashboards}
mkdir -p grafana/dashboards prometheus/alerts loki promtail timescaledb

# 3. Copy config files (provided in this document)
# ... copy prometheus.yml, loki-config.yaml, etc.

# 4. Start stack
docker-compose up -d

# 5. Access services
open http://localhost:3000  # Grafana (admin/admin)
open http://localhost:9090  # Prometheus
open http://localhost:3100  # Loki

# 6. Check logs
docker-compose logs -f

# 7. Stop stack
docker-compose down
```

---

**Document Maintenance:**
- Review quarterly as Docker and component versions update
- Update resource estimates based on actual usage
- Add lessons learned from incidents
- Keep troubleshooting section current

---

**Related Documents:**
- [Cloud Monitoring Architecture](./cloud-monitoring-architecture.md) - For GCP/AWS/Azure deployments
- [Dashboard Templates](./dashboards/) - Pre-built Grafana dashboards
- [Alert Rules](./alerts/) - Complete alert rule library
