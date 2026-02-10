# F7: Configuration Manager Module
## Technical Specification v1.0.0

**Module**: `ai-cost-monitoring/modules/config-manager`
**Version**: 1.0.0
**Status**: Production Ready
**Last Updated**: 2026-01-01T00:00:00

---

## 1. Executive Summary

The F7 Configuration Manager Module provides centralized configuration management for the AI Cost Monitoring Platform. It handles environment-aware loading, schema validation, hot-reload, feature flags, and AI-powered configuration optimization. All Foundation (F1-F6) and Domain (D1-D7) modules depend on F7 for their configuration.

### Key Capabilities

| Capability | Description |
|------------|-------------|
| **Multi-Source Loading** | Environment, secrets, files, defaults with priority ordering |
| **Schema Validation** | YAML schema enforcement with type coercion |
| **Hot Reload** | Graceful configuration updates without restarts |
| **Feature Flags** | Targeted rollouts with percentage and attribute targeting |
| **AI Optimization** | LLM-powered config analysis and recommendations |
| **Version Control** | Configuration snapshots and rollback |
| **Encryption** | Automatic encryption for sensitive values |

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                   ALL MODULES (F1-F6, D1-D7)                         │
│              Request configuration via F7 interfaces                 │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│              F7: CONFIGURATION MANAGER MODULE                        │
│   Validation • Hot Reload • Feature Flags • AI Analysis             │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐ │
│  │   Schema    │  │  Hot Reload │  │   Feature   │  │     AI     │ │
│  │  Validator  │  │   Engine    │  │    Flags    │  │  Analyzer  │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └────────────┘ │
└───────────┬───────────────────┬───────────────────┬─────────────────┘
            │                   │                   │
            ▼                   ▼                   ▼
    ┌───────────────┐   ┌───────────────┐   ┌───────────────┐
    │  Environment  │   │    Secrets    │   │  Config Files │
    │   Variables   │   │    Manager    │   │   (YAML/JSON) │
    └───────────────┘   └───────────────┘   └───────────────┘
```

### Design Principles

| Principle | Description |
|-----------|-------------|
| **Single Source of Truth** | All configuration flows through F7 |
| **Fail-Safe Defaults** | Valid defaults for all configuration values |
| **Schema-First** | All configs validated against YAML schemas |
| **Zero Downtime** | Hot-reload without service interruption |
| **Security by Default** | Automatic encryption for sensitive keys |

---

## 3. Configuration Sources

### 3.1 Source Priority

| Priority | Source | Description |
|----------|--------|-------------|
| 1 | Environment Variables | Highest priority, deployment-specific |
| 2 | Secret Manager | Sensitive values from GCP Secret Manager |
| 3 | Configuration Files | YAML files per environment |
| 4 | Defaults | Built-in fallback values |

### 3.2 Environment Variables

| Setting | Value |
|---------|-------|
| **Prefix** | NEXUS_ |
| **Transform** | lowercase_underscore |
| **Example** | NEXUS_DB_HOST → db.host |

### 3.3 Configuration Files

| Setting | Value |
|---------|-------|
| **Format** | YAML (primary), JSON (supported) |
| **Paths** | ./config/${ENV}.yaml, ./config/base.yaml |
| **Merge** | Deep merge with environment override |
| **Watch** | File system monitoring enabled |

### 3.4 Secret Manager Integration

| Setting | Value |
|---------|-------|
| **Backend** | GCP Secret Manager |
| **Prefix** | nexus- |
| **Cache TTL** | 300 seconds |
| **Rotation** | Automatic detection |

---

## 4. Schema Validation

### 4.1 Validation Features

| Feature | Description |
|---------|-------------|
| **Type Checking** | Validate against expected types |
| **Required Fields** | Enforce mandatory configuration |
| **Pattern Matching** | Regex validation for strings |
| **Range Validation** | Min/max for numeric values |
| **Enum Validation** | Allowed values enforcement |
| **Cross-References** | Validate references between configs |

### 4.2 Type Coercion Rules

| Pattern | Target Type | Example |
|---------|-------------|---------|
| `*_port` | integer | db_port: "5432" → 5432 |
| `*_enabled` | boolean | cache_enabled: "true" → true |
| `*_timeout_*` | duration | request_timeout_seconds: "30" → 30s |
| `*_size_*` | bytes | cache_size_mb: "100" → 104857600 |

### 4.3 Validation Modes

| Mode | Behavior |
|------|----------|
| **Strict** | Fail on unknown keys (production) |
| **Permissive** | Warn on unknown keys (development) |
| **Dry-Run** | Validate without applying |

---

## 5. Hot Reload

### 5.1 Reload Strategies

| Strategy | Description | Use Case |
|----------|-------------|----------|
| **Graceful** | Drain connections, apply, resume | Production (default) |
| **Immediate** | Apply without drain | Non-critical configs |
| **Scheduled** | Apply at specified time | Maintenance windows |

### 5.2 Graceful Reload Process

| Step | Duration | Description |
|------|----------|-------------|
| 1 | 0s | Validate new configuration |
| 2 | 0-5s | Stop accepting new requests |
| 3 | 0-30s | Drain in-flight requests |
| 4 | <1s | Apply new configuration |
| 5 | 0s | Resume accepting requests |

### 5.3 Excluded Keys

| Key Pattern | Reason |
|-------------|--------|
| `database.connection_string` | Requires restart |
| `infrastructure.provider` | Architectural change |
| `iam.oauth2.clients` | Security-critical |

### 5.4 Watch Configuration

| Setting | Value |
|---------|-------|
| **Watch Interval** | 5 seconds |
| **Debounce** | 2 seconds |
| **Retry on Failure** | 3 attempts |

---

## 6. Feature Flags

### 6.1 Flag Configuration

| Setting | Value |
|---------|-------|
| **Backend** | PostgreSQL (via D6) |
| **Cache TTL** | 60 seconds |
| **Default on Error** | false |

### 6.2 Targeting Attributes

| Attribute | Description |
|-----------|-------------|
| `user_id` | Individual user targeting |
| `workspace_id` | Workspace-level targeting |
| `trust_level` | Permission-based targeting |
| `environment` | paper/live/admin zone |

### 6.3 Rollout Strategies

| Strategy | Description | Example |
|----------|-------------|---------|
| **Percentage** | Random sample of users | 10% rollout |
| **User List** | Specific user IDs | Beta testers |
| **Attribute Match** | Based on user attributes | trust_level >= 3 |

### 6.4 Flag Definition Schema

```yaml
feature_flags:
  new_trading_ui:
    enabled: true
    description: "New trading interface"
    targeting:
      strategy: percentage
      percentage: 25
      attributes:
        trust_level: [3, 4]  # Only producers and admins
    fallback: false
```

---

## 7. AI-Powered Features

### 7.1 AI Capabilities

| Capability | Description |
|------------|-------------|
| **Schema Validation** | Natural language to YAML schema |
| **Cross-Ref Validation** | Detect inconsistent references |
| **Security Checks** | Identify insecure configurations |
| **Impact Analysis** | Predict effect of config changes |
| **Optimization Suggestions** | Performance tuning recommendations |
| **Debug Root Cause** | Analyze config-related failures |

### 7.2 NL → YAML Generation

| Feature | Description |
|---------|-------------|
| **Input** | Natural language description |
| **Output** | Valid YAML configuration |
| **Validation** | Auto-validate generated config |
| **Model** | Gemini 1.5 Pro via F6 |

### 7.3 Environment Drift Detection

| Check | Frequency |
|-------|-----------|
| **File vs Running** | On reload |
| **Env vs Secret Manager** | Hourly |
| **Cross-Environment** | Daily |

---

## 8. Version Control

### 8.1 Snapshot Features

| Feature | Description |
|---------|-------------|
| **Auto-Snapshot** | Before every reload |
| **Manual Snapshot** | On-demand snapshots |
| **Retention** | 30 days / 100 snapshots |
| **Diff View** | Compare any two snapshots |

### 8.2 Rollback Capabilities

| Type | Description |
|------|-------------|
| **Immediate** | Rollback to previous version |
| **Selective** | Rollback specific keys only |
| **Point-in-Time** | Rollback to any snapshot |

### 8.3 Change Audit

| Field | Description |
|-------|-------------|
| **timestamp** | When change occurred |
| **user_id** | Who made the change |
| **old_value** | Previous value (encrypted if sensitive) |
| **new_value** | New value (encrypted if sensitive) |
| **source** | reload/manual/api |

---

## 9. Encryption

### 9.1 Encryption Settings

| Setting | Value |
|---------|-------|
| **Algorithm** | AES-256-GCM |
| **Key Source** | GCP Secret Manager |
| **Key Rotation** | 90 days |

### 9.2 Auto-Encrypted Keys

| Pattern | Description |
|---------|-------------|
| `*.password` | Database passwords |
| `*.secret` | API secrets |
| `*.api_key` | External API keys |
| `*.private_key` | Private keys |
| `*.token` | Authentication tokens |

### 9.3 Encryption at Rest

| Storage | Encryption |
|---------|------------|
| **Config Files** | Encrypted values in YAML |
| **Database** | Column-level encryption |
| **Logs** | Sensitive values redacted |

---

## 10. Public API Interface

### 10.1 Configuration Access Methods

| Method | Parameters | Returns |
|--------|------------|---------|
| `get` | key, default? | Any |
| `get_required` | key | Any (raises if missing) |
| `get_section` | prefix | dict |
| `get_all` | - | dict |

### 10.2 Type-Safe Getters

| Method | Parameters | Returns |
|--------|------------|---------|
| `get_str` | key, default? | str |
| `get_int` | key, default? | int |
| `get_float` | key, default? | float |
| `get_bool` | key, default? | bool |
| `get_list` | key, default? | list |
| `get_dict` | key, default? | dict |
| `get_duration` | key, default? | timedelta |

### 10.3 Configuration Update Methods

| Method | Parameters | Returns |
|--------|------------|---------|
| `set` | key, value | void |
| `set_many` | updates: dict | void |
| `delete` | key | void |

### 10.4 Hot Reload Methods

| Method | Parameters | Returns |
|--------|------------|---------|
| `reload` | strategy? | ReloadResult |
| `on_reload` | callback | void |
| `watch` | key_pattern, callback | void |

### 10.5 Feature Flag Methods

| Method | Parameters | Returns |
|--------|------------|---------|
| `is_enabled` | flag, context? | bool |
| `get_flag_value` | flag, context? | Any |
| `set_flag` | flag, enabled, targeting? | void |
| `create_flag` | definition | void |
| `list_flags` | - | FeatureFlag[] |

### 10.6 Validation Methods

| Method | Parameters | Returns |
|--------|------------|---------|
| `validate` | config? | ValidationResult |
| `get_schema` | - | dict |

### 10.7 Secret Methods

| Method | Parameters | Returns |
|--------|------------|---------|
| `get_secret` | name | str |
| `set_secret` | name, value | void |
| `rotate_secret` | name | str |

### 10.8 Version Control Methods

| Method | Parameters | Returns |
|--------|------------|---------|
| `snapshot` | name? | SnapshotId |
| `rollback` | snapshot_id | void |
| `diff` | from_id, to_id | ConfigDiff |
| `list_snapshots` | limit? | Snapshot[] |

---

## 11. Events Emitted

| Event | Trigger |
|-------|---------|
| `config.loaded` | Initial configuration load |
| `config.reloaded` | Hot-reload completed |
| `config.key_changed` | Specific key value changed |
| `config.validation_failed` | Schema validation error |
| `flag.evaluated` | Feature flag check |
| `flag.changed` | Feature flag definition updated |
| `secret.accessed` | Secret value retrieved |
| `secret.rotated` | Secret rotation completed |
| `snapshot.created` | Configuration snapshot saved |
| `rollback.completed` | Rollback operation finished |

---

## 12. Hooks

| Hook | Trigger | Use Case |
|------|---------|----------|
| `on_load` | Configuration loading | Custom transformation |
| `on_validate` | Before validation | Custom validation rules |
| `on_reload` | Before/after reload | Custom reload logic |
| `on_flag_evaluate` | Flag evaluation | Custom targeting |

---

## 13. Integrations

### Foundation Modules

| Module | Integration |
|--------|-------------|
| **F1 IAM** | Zone and skill configurations |
| **F2 Session** | Memory layer configurations |
| **F3 Observability** | Logging and metrics settings |
| **F4 SecOps** | Security rule configurations |
| **F5 Self-Ops** | Health check and playbook configs |
| **F6 Infrastructure** | Cloud provider configurations |

### Domain Layers

| Layer | Integration |
|-------|-------------|
| **D1 Agent Orchestration** | Agent and skill configurations |
| **D2 Adaptive UI** | Component and theme settings |
| **D3 Trading Engine** | Strategy and risk parameters |
| **D4 MCP Marketplace** | Server configurations |
| **D5 Learning Governance** | Learning rule settings |
| **D6 Data Layer** | Database and cache configs |
| **D7 Domain Core** | Capability configurations |

---

## 14. Configuration Reference

```yaml
# f7-config-manager-config.yaml
module: config-manager
version: "1.0.0"

sources:
  priority: [environment, secrets, files, defaults]

  files:
    enabled: true
    paths:
      - ./config/${ENV}.yaml
      - ./config/base.yaml
    format: yaml
    watch: true
    reload_on_change: true

  environment:
    enabled: true
    prefix: NEXUS_
    transform: lowercase_underscore

  secrets:
    enabled: true
    backend: secret_manager
    prefix: nexus-
    cache_ttl_seconds: 300

validation:
  enabled: true
  schema_path: ./config/schema.yaml
  strict_mode: true

  type_coercion:
    enabled: true
    rules:
      - pattern: "*_port"
        type: integer
      - pattern: "*_enabled"
        type: boolean
      - pattern: "*_timeout_*"
        type: duration

hot_reload:
  enabled: true
  watch_interval_seconds: 5

  policies:
    graceful:
      enabled: true
      drain_timeout_seconds: 30
    immediate:
      enabled: false

  excluded_keys:
    - database.connection_string
    - infrastructure.provider

  notifications:
    emit_events: true
    channels: [observability]

feature_flags:
  enabled: true
  backend: database

  evaluation:
    cache_ttl_seconds: 60
    default_on_error: false

  targeting:
    enabled: true
    attributes:
      - user_id
      - workspace_id
      - trust_level
      - environment

  rollout:
    enabled: true
    policies:
      - percentage
      - user_list
      - attribute_match

version_control:
  snapshots:
    enabled: true
    auto_snapshot_on_reload: true
    retention_days: 30
    max_snapshots: 100

  rollback:
    enabled: true
    require_confirmation: true

encryption:
  enabled: true
  algorithm: aes-256-gcm
  key_source: secret_manager
  key_rotation_days: 90
  encrypted_keys:
    - "*.password"
    - "*.secret"
    - "*.api_key"
    - "*.private_key"
    - "*.token"

ai_features:
  enabled: true
  model: gemini-1.5-pro

  capabilities:
    schema_validation: true
    cross_ref_validation: true
    security_checks: true
    impact_analysis: true
    optimization_suggestions: true
    nl_to_yaml: true
    debug_root_cause: true
    env_drift_detection: true

defaults:
  merge_strategy: deep
```

---

## 15. Error Handling

### 15.1 Error Categories

| Category | Severity | Action |
|----------|----------|--------|
| **Schema Violation** | Critical | Reject configuration |
| **Missing Required** | Critical | Reject configuration |
| **Type Mismatch** | Warning | Attempt coercion |
| **Unknown Key** | Warning | Log and ignore (strict: reject) |
| **Secret Unavailable** | Critical | Use cached or fail |

### 15.2 Fallback Behavior

| Scenario | Fallback |
|----------|----------|
| **File unreadable** | Use last known good |
| **Secret unavailable** | Use cached value |
| **Validation failed** | Keep current config |
| **Reload timeout** | Abort and log |

---

## 16. Performance

### 16.1 Performance Metrics

| Metric | Target |
|--------|--------|
| **Config lookup** | < 1ms |
| **Flag evaluation** | < 5ms |
| **Full reload** | < 5s |
| **Validation** | < 100ms |

### 16.2 Caching Strategy

| Cache | TTL | Invalidation |
|-------|-----|--------------|
| **Config values** | Until reload | On reload |
| **Feature flags** | 60s | On flag change |
| **Secrets** | 300s | On rotation |
| **Schemas** | Until restart | Manual |

---

## 17. Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Jan 2026 | Initial release with config loading, validation, hot-reload, feature flags, AI features, version control |

---

*F7 Configuration Manager Module — Technical Specification v1.0.0 — January 2026*
