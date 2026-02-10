# F7: Configuration Manager Module
## AI Cloud Cost Monitoring - Adapted Specification

**Module**: `ai-cost-monitoring/foundation/config`
**Version**: 1.0.0
**Status**: Draft
**Source**: Trading Nexus F7 v1.0.0 (adapted)
**Date**: 2026-02-10T15:00:00

---

## 1. Executive Summary

The F7 Configuration Manager Module provides centralized configuration management for the AI Cloud Cost Monitoring platform. It handles environment-aware loading, secret management, and schema validation. Simplified from Trading Nexus to match cloud-native patterns.

### Key Capabilities

| Capability | Description |
|------------|-------------|
| **Multi-Source Loading** | Environment → Secrets → Files → Defaults |
| **Schema Validation** | Pydantic models for type safety |
| **Secret Integration** | GCP Secret Manager (per ADR) |
| **Environment Awareness** | dev, staging, production configs |
| **Feature Flags** | Simple on/off via environment variables |

### Simplifications from Trading Nexus

| Feature | Trading Nexus | Cloud Cost Monitoring |
|---------|---------------|----------------------|
| **Hot Reload** | File watch + PubSub | Not needed (Cloud Run cold starts fast) |
| **AI Optimization** | LLM config analysis | Removed (over-engineering) |
| **Version Control** | Config snapshots | Git-based |
| **Feature Flags** | Complex targeting | Simple environment variables |

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                 F7: CONFIGURATION v1.0.0                         │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   SCHEMA    │  │   LOADER    │  │  FEATURES   │             │
│  │ VALIDATION  │  │             │  │   FLAGS     │             │
│  │             │  │ • Env vars  │  │             │             │
│  │ • Pydantic  │  │ • Secrets   │  │ • On/Off    │             │
│  │ • Types     │  │ • Files     │  │ • Per-env   │             │
│  │ • Defaults  │  │ • Defaults  │  │             │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────────────────────────────────────────────────────┘
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│  F1 IAM     │      │  F3 Observ  │      │  F6 Infra   │
│  Config     │      │  Config     │      │  Config     │
└─────────────┘      └─────────────┘      └─────────────┘
```

---

## 3. Configuration Sources

### 3.1 Source Priority (Highest to Lowest)

| Priority | Source | Description |
|----------|--------|-------------|
| **1** | Environment Variables | Deployment-specific, highest priority |
| **2** | Secret Manager | Sensitive values (API keys, credentials) |
| **3** | Configuration Files | YAML files per environment |
| **4** | Defaults | Built-in fallback values |

### 3.2 Environment Variables

```bash
# Prefix: COST_MONITOR_
# Transform: COST_MONITOR_DB_HOST → db.host

export COST_MONITOR_ENV=production
export COST_MONITOR_GCP_PROJECT=my-project
export COST_MONITOR_LOG_LEVEL=INFO
export COST_MONITOR_FEATURE_AZURE=false
```

### 3.3 Secret Manager Integration

```yaml
# Secrets loaded at startup
secrets:
  - name: AUTH0_CLIENT_SECRET
    secret_id: auth0-client-secret
  - name: LITELLM_API_KEY
    secret_id: litellm-api-key
  - name: OPENAI_API_KEY
    secret_id: openai-api-key
```

### 3.4 Configuration Files

```
config/
├── base.yaml           # Shared defaults
├── development.yaml    # Local dev overrides
├── staging.yaml        # Staging environment
└── production.yaml     # Production settings
```

---

## 4. Schema Validation

### 4.1 Pydantic Configuration Models

```python
from pydantic import BaseSettings, Field
from typing import Optional, List

class AppConfig(BaseSettings):
    """Root application configuration."""
    env: str = Field("development", env="COST_MONITOR_ENV")
    gcp_project: str = Field(..., env="COST_MONITOR_GCP_PROJECT")
    log_level: str = Field("INFO", env="COST_MONITOR_LOG_LEVEL")

    # Sub-configurations
    iam: IAMConfig
    observability: ObservabilityConfig
    infrastructure: InfrastructureConfig

    class Config:
        env_prefix = "COST_MONITOR_"
        env_file = ".env"

class IAMConfig(BaseSettings):
    """F1 IAM configuration."""
    auth_mode: str = Field("gcp_iam")  # gcp_iam, auth0
    auth0_domain: Optional[str] = None
    auth0_audience: str = "finops-platform"
    session_timeout_minutes: int = 30

class ObservabilityConfig(BaseSettings):
    """F3 Observability configuration."""
    log_level: str = "INFO"
    metrics_enabled: bool = True
    tracing_enabled: bool = True
    tracing_sample_rate: float = 0.1

class InfrastructureConfig(BaseSettings):
    """F6 Infrastructure configuration."""
    bigquery_dataset: str = "billing_export"
    firestore_collection_prefix: str = "tenants"
    secret_manager_project: Optional[str] = None
```

### 4.2 Validation at Startup

```python
from f7_config import load_config

# Raises ValidationError if config is invalid
config = load_config()

# Type-safe access
print(config.gcp_project)  # IDE autocomplete works
print(config.iam.auth_mode)
```

---

## 5. Environment Configuration

### 5.1 Development Environment

```yaml
# config/development.yaml
env: development

iam:
  auth_mode: gcp_iam
  allowed_domains:
    - localhost

observability:
  log_level: DEBUG
  tracing_sample_rate: 1.0  # 100% tracing in dev

infrastructure:
  bigquery_dataset: billing_export_dev
  firestore_collection_prefix: dev_tenants
```

### 5.2 Production Environment

```yaml
# config/production.yaml
env: production

iam:
  auth_mode: auth0
  auth0_domain: ${AUTH0_DOMAIN}
  mfa_required: true

observability:
  log_level: INFO
  tracing_sample_rate: 0.1  # 10% sampling

infrastructure:
  bigquery_dataset: billing_export
  firestore_collection_prefix: tenants
```

---

## 6. Feature Flags

### 6.1 Simple Environment-Based Flags

```python
class FeatureFlags(BaseSettings):
    """Feature toggles via environment variables."""

    # Cloud provider support
    enable_gcp: bool = True
    enable_aws: bool = False  # Phase 2
    enable_azure: bool = False  # Phase 2
    enable_kubernetes: bool = False  # Phase 2

    # UI features
    enable_ag_ui: bool = False  # Phase 3
    enable_grafana: bool = True  # ADR-007

    # Experimental
    enable_auto_remediation: bool = False

    class Config:
        env_prefix = "COST_MONITOR_FEATURE_"
```

### 6.2 Usage

```python
from f7_config import get_features

features = get_features()

if features.enable_aws:
    aws_mcp = load_aws_mcp_server()

if features.enable_ag_ui:
    start_ag_ui_server()
```

---

## 7. LLM Configuration

### 7.1 LiteLLM Settings (per ADR-005)

```yaml
# config/llm.yaml
llm:
  provider: litellm
  default_model: gemini/gemini-1.5-flash

  models:
    - name: gemini-flash
      model: gemini/gemini-1.5-flash
      max_tokens: 8192
      temperature: 0.1

    - name: gemini-pro
      model: gemini/gemini-1.5-pro
      max_tokens: 32768
      temperature: 0.1

    - name: gpt-4o
      model: gpt-4o
      max_tokens: 4096
      temperature: 0.1

  fallback_order:
    - gemini-flash
    - gpt-4o

  rate_limits:
    requests_per_minute: 60
    tokens_per_minute: 100000
```

---

## 8. MCP Server Configuration

### 8.1 Server Registry

```yaml
# config/mcp-servers.yaml
mcp_servers:
  - name: gcp-mcp
    enabled: true
    endpoint: ${GCP_MCP_URL}
    tools:
      - get_costs
      - get_resources
      - get_recommendations
      - execute_remediation

  - name: aws-mcp
    enabled: ${FEATURE_AWS}
    endpoint: ${AWS_MCP_URL}
    tools:
      - get_costs
      - get_resources
      - get_recommendations

  - name: azure-mcp
    enabled: ${FEATURE_AZURE}
    endpoint: ${AZURE_MCP_URL}
    tools:
      - get_costs
      - get_resources
```

---

## 9. Public Interface

```python
class ConfigManager:
    """Foundation Module F7: Configuration Manager"""

    def load_config(self) -> AppConfig:
        """Load and validate configuration from all sources."""

    def get_secret(self, name: str) -> str:
        """Get secret value from Secret Manager."""

    def get_features(self) -> FeatureFlags:
        """Get current feature flag state."""

    def get_llm_config(self) -> LLMConfig:
        """Get LLM configuration."""

    def get_mcp_servers(self) -> List[MCPServerConfig]:
        """Get enabled MCP server configurations."""

    def reload(self) -> None:
        """Reload configuration (for development)."""
```

---

## 10. Environment Variable Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `COST_MONITOR_ENV` | Yes | development | Environment name |
| `COST_MONITOR_GCP_PROJECT` | Yes | - | GCP project ID |
| `COST_MONITOR_LOG_LEVEL` | No | INFO | Log level |
| `COST_MONITOR_AUTH_MODE` | No | gcp_iam | Auth mode |
| `AUTH0_DOMAIN` | Conditional | - | Auth0 domain (if auth0 mode) |
| `AUTH0_CLIENT_ID` | Conditional | - | Auth0 client ID |
| `LITELLM_API_KEY` | Yes | - | LiteLLM API key |
| `COST_MONITOR_FEATURE_AWS` | No | false | Enable AWS |
| `COST_MONITOR_FEATURE_AZURE` | No | false | Enable Azure |

---

## 11. Dependencies

| Module | Dependency Type | Description |
|--------|----------------|-------------|
| **All Modules** | Downstream | F7 provides config to all |
| **F6 Infrastructure** | Upstream | Secret Manager access |

---

## 12. MVP Scope

### Included in MVP

- [x] Environment variable loading
- [x] Secret Manager integration
- [x] Pydantic schema validation
- [x] YAML configuration files
- [x] Simple feature flags
- [x] LLM configuration

### Deferred

- [ ] Hot reload (not needed for Cloud Run)
- [ ] Complex feature flag targeting
- [ ] Configuration UI
- [ ] AI-powered config analysis

---

*Adapted from Trading Nexus F7 v1.0.0 — February 2026*
