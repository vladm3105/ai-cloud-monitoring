---
title: "REQ-07: F7 Configuration Manager Atomic Requirements"
tags:
  - req
  - layer-7-artifact
  - f7-config
  - foundation-module
  - shared-architecture
custom_fields:
  document_type: req
  artifact_type: REQ
  layer: 7
  module_id: F7
  module_name: Configuration Manager
  spec_ready_score: 93
  ctr_ready_score: 92
  schema_version: "1.1"
---

# REQ-07: F7 Configuration Manager Atomic Requirements

**MVP Scope**: This requirement document focuses on essential, SPEC-ready requirements for MVP delivery.

## 1. Document Control

| Item | Details |
|------|---------|
| **Status** | Draft |
| **Version** | 1.0.0 |
| **Date Created** | 2026-02-09 |
| **Last Updated** | 2026-02-09 |
| **Author** | Platform Team |
| **Priority** | P1 (Critical) |
| **Category** | Config |
| **Infrastructure Type** | Database / Cache |
| **Source Document** | SYS-07 Sections 4.1-4.4 |
| **Verification Method** | Integration Test |
| **Assigned Team** | Platform Team |
| **SPEC-Ready Score** | ✅ 93% (Target: ≥90%) |
| **CTR-Ready Score** | ✅ 92% (Target: ≥90%) |
| **Template Version** | 1.1 |

---

## 2. Requirement Description

### 2.1 Statement

**The system SHALL** provide centralized configuration management with multi-source merging (env < file < db < secret), feature flags with tenant isolation, GCP Secret Manager integration, and hot-reload capabilities.

### 2.2 Context

F7 Configuration Manager provides runtime configuration for all platform services. It supports GitOps with YAML files, PostgreSQL for runtime overrides, and Secret Manager for credentials. Feature flags enable gradual rollouts and tenant-specific customization.

### 2.3 Use Case

**Primary Flow**:
1. Service requests configuration key
2. F7 merges sources (env → file → db → secret)
3. Cached value returned if available
4. File watcher triggers hot-reload on change

**Error Flow**:
- When Secret Manager unavailable, system SHALL use cached value
- When config invalid, system SHALL reject with validation error

---

## 3. Functional Specification

### 3.1 Core Functionality

**Required Capabilities**:
- **REQ.07.01.01 Configuration Provider**: Serve merged configuration from multiple sources
- **REQ.07.01.02 Feature Flag Manager**: Evaluate flags with tenant/user context
- **REQ.07.01.03 Secret Manager**: Securely store and retrieve secrets
- **REQ.07.01.04 Hot Reload Watcher**: Detect and propagate configuration changes

### 3.2 Business Rules

**ID Format**: `REQ.07.21.SS` (Validation Rule)

| Rule ID | Condition | Action |
|---------|-----------|--------|
| REQ.07.21.01 | IF source priority conflict | THEN higher priority wins |
| REQ.07.21.02 | IF flag has percentage rule | THEN apply consistent hashing |
| REQ.07.21.03 | IF secret accessed | THEN log access (never value) |
| REQ.07.21.04 | IF file changed | THEN reload after 2s debounce |

### 3.3 Input/Output Specification

**Inputs**:

| Parameter | Type | Required | Validation | Description |
|-----------|------|----------|------------|-------------|
| config_key | string | Yes | Dot notation path | Configuration key |
| namespace | string | Conditional | Tenant namespace | Tenant isolation |
| flag_key | string | Conditional | Valid flag name | Feature flag key |
| user_context | object | Conditional | User/tenant info | Flag evaluation context |

**Outputs**:

| Field | Type | Description |
|-------|------|-------------|
| config_value | any | Configuration value |
| flag_value | any | Evaluated flag value |
| secret_value | string | Decrypted secret |

### 3.4 Interface Protocol

```python
from typing import Protocol, Dict, Any, Optional

class ConfigurationService(Protocol):
    """Interface for F7 configuration operations."""

    async def get_config(
        self,
        key: str,
        namespace: str = "default",
        default: Any = None
    ) -> Any:
        """
        Get configuration value.

        Args:
            key: Configuration key (dot notation)
            namespace: Tenant namespace
            default: Default if not found

        Returns:
            Configuration value
        """
        raise NotImplementedError("method not implemented")

    async def evaluate_flag(
        self,
        flag_key: str,
        context: Dict[str, Any]
    ) -> Any:
        """Evaluate feature flag with context."""
        raise NotImplementedError("method not implemented")

    async def get_secret(
        self,
        secret_key: str,
        version: str = "latest"
    ) -> str:
        """Get secret from Secret Manager."""
        raise NotImplementedError("method not implemented")
```

---

## 4. Interface Definition

### 4.1 API Contract

**Endpoint**: `GET /api/v1/config/{key}`

**Response (Success)**:
```json
{
  "key": "api.rate_limit.default",
  "value": 100,
  "source": "database",
  "namespace": "default",
  "cached_at": "2026-02-09T10:30:00Z"
}
```

### 4.2 Data Schema

```python
from pydantic import BaseModel, Field
from datetime import datetime
from typing import Any, Dict, List, Optional

class ConfigEntry(BaseModel):
    """Configuration entry."""
    key: str
    value: Any
    type: str = "string"
    namespace: str = "default"
    environment: str
    version: str
    updated_at: datetime
    updated_by: str

class FeatureFlag(BaseModel):
    """Feature flag definition."""
    key: str
    enabled: bool
    value: Any = None
    rules: List[Dict[str, Any]] = []
    default: Any
```

---

## 5. Error Handling

### 5.1 Error Catalog

| Error Code | HTTP Status | Condition | User Message | System Action |
|------------|-------------|-----------|--------------|---------------|
| CFG_001 | 404 | Config not found | Configuration not found | Return default |
| CFG_002 | 400 | Invalid config key | Invalid key format | Reject |
| CFG_003 | 503 | Secret Manager unavailable | Secrets unavailable | Use cache |
| CFG_004 | 500 | Schema validation failed | Invalid configuration | Reject change |

### 5.2 Recovery Strategy

| Error Type | Retry? | Fallback | Alert |
|------------|--------|----------|-------|
| Config not found | No | Use default | No |
| Secret unavailable | Yes (1x) | Use cached | After failure |
| Schema validation | No | Reject | Log only |

### 5.3 Exception Definitions

```python
class ConfigError(Exception):
    """Base exception for F7 configuration errors."""
    pass

class ConfigNotFoundError(ConfigError):
    """Raised when configuration key not found."""
    pass

class SecretAccessError(ConfigError):
    """Raised when secret access fails."""
    pass

class SchemaValidationError(ConfigError):
    """Raised when config fails schema validation."""
    def __init__(self, key: str, errors: list):
        self.key = key
        self.errors = errors
```

---

## 6. Quality Attributes

**ID Format**: `REQ.07.02.SS` (Quality Attribute)

### 6.1 Performance (REQ.07.02.01)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Config lookup (p95) | < @threshold: PRD.07.perf.config.p95 (1ms) | APM |
| Flag evaluation (p95) | < @threshold: PRD.07.perf.flag.p95 (5ms) | APM |
| Secret retrieval cold (p95) | < @threshold: PRD.07.perf.secret.p95 (50ms) | APM |
| Hot reload (p95) | < @threshold: PRD.07.perf.reload.p95 (5s) | Timer |

### 6.2 Security (REQ.07.02.02)

- [x] Secret encryption: AES-256-GCM
- [x] Access control: F1 IAM namespace isolation
- [x] Audit logging: All config changes logged

### 6.3 Reliability (REQ.07.02.03)

- Service uptime: @threshold: PRD.07.sla.uptime (99.9%)
- Secret rotation: 90-day automatic
- Configuration durability: Version history preserved

---

## 7. Configuration

### 7.1 Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| CONFIG_CACHE_TTL | duration | 60s | Config cache lifetime |
| FLAG_CACHE_TTL | duration | 30s | Flag cache lifetime |
| SECRET_CACHE_TTL | duration | 300s | Secret cache lifetime |
| RELOAD_DEBOUNCE | duration | 2s | File change debounce |

### 7.2 Feature Flags

| Flag | Default | Description |
|------|---------|-------------|
| F7_HOT_RELOAD | true | Enable hot reload |
| F7_SECRET_CACHE | true | Cache secrets |

### 7.3 Configuration Schema

```yaml
f7_config:
  sources:
    priority:
      - environment
      - file
      - database
      - secret
  cache:
    config_ttl: 60
    flag_ttl: 30
    secret_ttl: 300
  hot_reload:
    enabled: true
    debounce_seconds: 2
    watch_paths:
      - "/config"
```

---

## 8. Testing Requirements

### 8.1 Unit Tests

| Test Case | Input | Expected Output | Coverage |
|-----------|-------|-----------------|----------|
| **[Logic] Source Merge** | Multi-source config | Highest priority wins | REQ.07.01.01 |
| **[Logic] Flag Eval** | User context | Correct flag value | REQ.07.01.02 |
| **[Logic] Hot Reload** | File change | Config updated | REQ.07.01.04 |
| **[Validation] Invalid Key** | `..invalid` | Rejection error | REQ.07.01.01 |
| **[Edge] Secret Cache** | SM unavailable | Cached value | REQ.07.01.03 |

### 8.2 Integration Tests

- [ ] Multi-source configuration merging
- [ ] Feature flag evaluation with rules
- [ ] Secret Manager integration
- [ ] Hot reload file watching

### 8.3 BDD Scenarios

**Feature**: Configuration Management
**File**: `04_BDD/BDD-07_f7_config/BDD-07.01_config.feature`

| Scenario | Priority | Status |
|----------|----------|--------|
| Configuration retrieved from merged sources | P1 | Pending |
| Feature flag evaluated with context | P1 | Pending |
| Secret retrieved securely | P1 | Pending |
| Hot reload updates configuration | P1 | Pending |

---

## 9. Acceptance Criteria

**ID Format**: `REQ.07.06.SS` (Acceptance Criteria)

### 9.1 Functional Acceptance

| Criteria ID | Criterion | Measurable Outcome | Status |
|-------------|-----------|-------------------|--------|
| REQ.07.06.01 | Config lookup works | Value returned < 1ms | [ ] |
| REQ.07.06.02 | Flag evaluation works | Correct value | [ ] |
| REQ.07.06.03 | Secret retrieval works | Secret returned | [ ] |
| REQ.07.06.04 | Hot reload works | Config updated < 5s | [ ] |
| REQ.07.06.05 | Audit logging works | Changes logged | [ ] |

### 9.2 Quality Acceptance

| Criteria ID | Criterion | Target | Status |
|-------------|-----------|--------|--------|
| REQ.07.06.06 | Lookup latency | @threshold: REQ.07.02.01 (p95 < 1ms) | [ ] |
| REQ.07.06.07 | Availability | 99.9% | [ ] |
| REQ.07.06.08 | Secret rotation | 90-day configured | [ ] |

---

## 10. Traceability

### 10.1 Upstream Sources

| Source Type | Document ID | Element Reference | Relationship |
|-------------|-------------|-------------------|--------------|
| BRD | BRD-07 | BRD.07.07.02 | Primary business need |
| PRD | PRD-07 | PRD.07.08.01 | Product requirement |
| EARS | EARS-07 | EARS.07.01.01-04 | Formal requirements |
| BDD | BDD-07 | BDD.07.01.01 | Acceptance test |
| ADR | ADR-07 | — | Architecture decision |
| SYS | SYS-07 | SYS.07.01.01-04 | System requirement |

### 10.2 Downstream Artifacts

| Artifact | Status | Relationship |
|----------|--------|--------------|
| SPEC-07 | TBD | Technical specification |
| TASKS-07 | TBD | Implementation tasks |

### 10.3 Traceability Tags

```markdown
@brd: BRD-07
@prd: PRD-07
@ears: EARS-07
@bdd: BDD-07
@adr: ADR-07
@sys: SYS-07
```

### 10.4 Cross-Links

```markdown
@depends: REQ-06 (F6 Secret Manager)
@discoverability: All REQ modules (config consumers)
```

---

## 11. Implementation Notes

### 11.1 Technical Approach

Use Python dynaconf for multi-source configuration. Implement feature flags with PostgreSQL storage and consistent hashing for percentage rules. Use watchdog for file system monitoring with debounced reload.

### 11.2 Code Location

- **Primary**: `src/foundation/f7_config/`
- **Tests**: `tests/foundation/test_f7_config/`

### 11.3 Dependencies

| Package/Service | Version | Purpose |
|-----------------|---------|---------|
| dynaconf | 3.2+ | Configuration management |
| watchdog | 4.0+ | File system events |
| google-cloud-secret-manager | 2.18+ | Secret storage |
| asyncpg | 0.29+ | PostgreSQL driver |

---

**Document Version**: 1.0.0
**Template Version**: 1.1 (MVP)
**Last Updated**: 2026-02-09
