# AI Cost Monitoring Platform Architecture v4.2
## Foundation Modules + Domain Layers

**Version 4.2 — 2026-01-01T00:00:00**

---

## Architecture Overview

The AI Cost Monitoring Platform v4.2 introduces a **modular architecture** that separates universal infrastructure concerns (Foundation Modules) from project-specific business logic (Domain Layers). This enables:

- **Independent versioning** of infrastructure modules
- **Mix-and-match** module versions per project
- **Shared improvements** across all Nexus projects
- **Faster project bootstrapping** with proven modules

```
┌─────────────────────────────────────────────────────────────────┐
│                    FOUNDATION MODULES (F-Series)                 │
│                Universal • Pluggable • Versioned                 │
├─────────────────────────────────────────────────────────────────┤
│  F1: IAM        F2: Session     F3: Observability               │
│  v1.2.0         v1.1.0          v1.3.0                          │
│                                                                  │
│  F4: SecOps     F5: Self-Ops    F6: Infrastructure              │
│  v1.0.0         v1.1.0          v1.2.0                          │
│                                                                  │
│  F7: Config Manager                                              │
│  v1.0.0                                                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                    Configuration & Dependency Injection
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    DOMAIN LAYERS (D-Series)                      │
│                    Project-Specific Logic                        │
├─────────────────────────────────────────────────────────────────┤
│  D1: Agent Orchestration    D2: Adaptive UI                     │
│  D3: Domain Engine          D4: MCP + Marketplace               │
│  D5: Learning Governance    D6: Data Layer                      │
│  D7: Domain Core                                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Foundation Modules (F-Series)

### Design Principles

| Principle | Description |
|-----------|-------------|
| **Independently Versioned** | Each module follows semantic versioning (semver) |
| **Configuration-Driven** | Behavior controlled via YAML/JSON config |
| **Interface-First** | Well-defined APIs, events, and hooks |
| **Adapter Pattern** | Cloud-agnostic with provider adapters |
| **Zero Domain Knowledge** | Modules know nothing about trading, knowledge, etc. |

---

## F1: Identity & Access Management (IAM) Module

**Current Version**: 1.2.0  
**Repository**: `ai-cost-monitoring/modules/iam`

### Purpose

Handles all authentication and authorization concerns. The module is domain-agnostic — it manages WHO users are and WHAT they can do, without knowing WHY.

### Configuration Schema

```yaml
# f1-iam-config.yaml
module: iam
version: "1.2.0"

authentication:
  providers:
    oauth2:
      enabled: true
      clients:
        - name: google
          client_id: ${GOOGLE_CLIENT_ID}
          client_secret: ${GOOGLE_CLIENT_SECRET}
          scopes: [openid, email, profile]
        - name: microsoft
          client_id: ${MS_CLIENT_ID}
          client_secret: ${MS_CLIENT_SECRET}
    
    email_password:
      enabled: true
      password_policy:
        min_length: 12
        require_uppercase: true
        require_number: true
        require_special: true
    
    enterprise_sso:
      enabled: false
      protocols: [saml2, oidc]
    
    service_auth:
      enabled: true
      methods:
        - type: mtls
          ca_cert: ${MTLS_CA_CERT}
        - type: api_key
          header: X-API-Key
    
    mfa:
      enabled: true
      methods: [totp, webauthn]
      required_for_trust_levels: [3, 4]

authorization:
  model: 4d_matrix  # ACTION × SKILL × RESOURCE × ZONE
  
  zones:
    - id: paper
      name: Paper Trading
      description: Simulated trading environment
    - id: live
      name: Live Trading
      description: Real trading operations
    - id: admin
      name: Admin
      description: Configuration and management

  trust_levels:
    - level: 1
      name: viewer
      description: Read-only access
      default_zones: [paper]
    - level: 2
      name: operator
      description: Paper trading operations
      default_zones: [paper]
    - level: 3
      name: producer
      description: Live trading operations
      default_zones: [paper, live]
    - level: 4
      name: admin
      description: Full access
      default_zones: [paper, live, admin]
  
  skills: []  # Defined by domain layer
  
  resource_scoping:
    enabled: true
    scopes: [own, workspace, all]

user_profile:
  schema:
    required: [user_id, email]
    optional: [name, avatar, timezone, locale]
  
  custom_fields:
    enabled: true
    # Domain layer defines additional fields
  
  storage:
    backend: postgres
    table: users

session_limits:
  max_concurrent_sessions: 3
  session_timeout_minutes: 30
  refresh_token_days: 7
```

### Public Interface

```python
# F1 IAM Module - Public API

class IAMModule:
    """Foundation Module F1: Identity & Access Management"""
    
    # Authentication
    async def authenticate(self, credentials: Credentials) -> AuthResult
    async def verify_token(self, token: str) -> TokenClaims
    async def refresh_token(self, refresh_token: str) -> TokenPair
    async def logout(self, session_id: str) -> None
    
    # Authorization
    async def authorize(self, 
        user_id: str,
        action: str,
        skill: str,
        resource: str,
        zone: str
    ) -> AuthzDecision
    
    async def get_user_permissions(self, user_id: str) -> Permissions
    async def check_trust_level(self, user_id: str, required: int) -> bool
    
    # User Management
    async def get_user(self, user_id: str) -> User
    async def update_user(self, user_id: str, updates: dict) -> User
    async def set_custom_fields(self, user_id: str, fields: dict) -> None
    
    # Events (emitted)
    # - user.authenticated
    # - user.authorization_checked
    # - user.session_created
    # - user.session_expired
    
    # Hooks (extensible)
    # - on_authenticate: Custom auth logic
    # - on_authorize: Custom authz logic
    # - on_user_created: Post-creation actions
```

### Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Dec 2025 | Initial release with OAuth2, basic authz |
| 1.1.0 | Jan 2026 | Added 4D authorization matrix |
| 1.2.0 | Jan 2026 | Added mTLS, WebAuthn, custom fields |

---

## F2: Session & Context Management Module

**Current Version**: 1.1.0  
**Repository**: `ai-cost-monitoring/modules/session`

### Purpose

Manages user sessions, multi-layer memory, workspaces, and context injection. Domain-agnostic — stores and retrieves context without understanding its meaning.

### Configuration Schema

```yaml
# f2-session-config.yaml
module: session
version: "1.1.0"

session:
  backend: database  # memory | database | vertex_ai
  
  backends:
    memory:
      max_size_mb: 100
    
    database:
      connection_string: ${DATABASE_URL}
      table_prefix: sessions_
      pool_size: 10
    
    vertex_ai:
      project: ${GCP_PROJECT}
      location: us-central1
  
  lifecycle:
    timeout_minutes: 30
    max_concurrent: 3
    device_tracking: true
    refresh_on_activity: true

memory:
  layers: []  # Defined by domain layer - see examples below
  
  # Example layer definitions (provided by domain):
  # - name: session
  #   scope: ephemeral
  #   storage: memory
  #   ttl_minutes: 30
  #   max_size_kb: 100
  #
  # - name: workspace
  #   scope: persistent
  #   storage: postgres
  #   table: workspace_memory
  #
  # - name: profile
  #   scope: long_term
  #   storage: external
  #   adapter: a2a_knowledge_platform

workspaces:
  enabled: true
  types: []  # Defined by domain layer
  
  # Example types (provided by domain):
  # - name: watchlist
  #   schema: { symbols: array, alerts: array }
  # - name: strategy
  #   schema: { config: object, results: object }
  
  max_per_user: 50
  sharing:
    enabled: true
    modes: [private, shared, public]

context_injection:
  enabled: true
  targets:
    - agent_prompts
    - ui_components
    - events
  
  enrichment:
    include_user_profile: true
    include_session_memory: true
    include_workspace_context: true
```

### Public Interface

```python
# F2 Session Module - Public API

class SessionModule:
    """Foundation Module F2: Session & Context Management"""
    
    # Session Management
    async def create_session(self, user_id: str, device: DeviceInfo) -> Session
    async def get_session(self, session_id: str) -> Session
    async def refresh_session(self, session_id: str) -> Session
    async def terminate_session(self, session_id: str) -> None
    async def list_user_sessions(self, user_id: str) -> List[Session]
    
    # Memory Operations
    async def get_memory(self, session_id: str, layer: str, key: str) -> Any
    async def set_memory(self, session_id: str, layer: str, key: str, value: Any) -> None
    async def clear_memory(self, session_id: str, layer: str) -> None
    async def get_layer_snapshot(self, session_id: str, layer: str) -> dict
    
    # Workspace Operations
    async def create_workspace(self, user_id: str, type: str, name: str) -> Workspace
    async def get_workspace(self, workspace_id: str) -> Workspace
    async def update_workspace(self, workspace_id: str, data: dict) -> Workspace
    async def switch_workspace(self, session_id: str, workspace_id: str) -> None
    async def list_workspaces(self, user_id: str, type: str = None) -> List[Workspace]
    
    # Context Injection
    async def get_context(self, session_id: str, target: str) -> Context
    async def enrich_context(self, context: Context, data: dict) -> Context
    
    # Events (emitted)
    # - session.created
    # - session.terminated
    # - memory.updated
    # - workspace.switched
    
    # Hooks (extensible)
    # - on_session_created: Custom initialization
    # - on_context_inject: Custom enrichment
```

### Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Dec 2025 | Initial release with basic session management |
| 1.1.0 | Jan 2026 | Added multi-layer memory, workspaces, context injection |

---

## F3: Observability Module

**Current Version**: 1.3.0  
**Repository**: `ai-cost-monitoring/modules/observability`

### Purpose

Provides comprehensive monitoring, logging, tracing, and alerting. Collects domain-specific metrics without understanding their meaning.

### Configuration Schema

```yaml
# f3-observability-config.yaml
module: observability
version: "1.3.0"

logging:
  level: info  # debug | info | warn | error
  format: json
  
  outputs:
    - type: console
      enabled: true
    - type: cloud_logging
      enabled: true
      project: ${GCP_PROJECT}
    - type: file
      enabled: false
      path: /var/log/nexus/app.log

metrics:
  enabled: true
  
  collectors:
    system:
      enabled: true
      metrics: [cpu, memory, disk, network]
      interval_seconds: 60
    
    application:
      enabled: true
      # Domain layer registers custom metrics
    
    llm:
      enabled: true
      metrics:
        - token_usage
        - latency_ms
        - cost_usd
        - model_performance
      per_model: true
  
  exporters:
    - type: prometheus
      port: 9090
    - type: cloud_monitoring
      project: ${GCP_PROJECT}

tracing:
  enabled: true
  sampler: probabilistic
  sample_rate: 0.1  # 10% of requests
  
  exporters:
    - type: opentelemetry
      endpoint: ${OTEL_ENDPOINT}
    - type: cloud_trace
      project: ${GCP_PROJECT}

alerting:
  enabled: true
  
  channels:
    - name: pagerduty
      type: pagerduty
      routing_key: ${PAGERDUTY_KEY}
      severity_mapping:
        critical: P1
        high: P2
        medium: P3
        low: P4
    
    - name: slack
      type: slack
      webhook_url: ${SLACK_WEBHOOK}
      channel: "#alerts"
  
  rules: []  # Defined by domain layer
  
  # Example rules (provided by domain):
  # - name: high_error_rate
  #   condition: error_rate > 0.05
  #   duration: 5m
  #   severity: high
  #   channels: [pagerduty, slack]

dashboards:
  enabled: true
  provider: grafana
  auto_generate: true
  
  templates:
    - system_health
    - llm_performance
    - cost_tracking

data_retention:
  logs_days: 30
  metrics_days: 90
  traces_days: 7
```

### Public Interface

```python
# F3 Observability Module - Public API

class ObservabilityModule:
    """Foundation Module F3: Observability"""
    
    # Logging
    def log(self, level: str, message: str, **context) -> None
    def log_structured(self, event: LogEvent) -> None
    
    # Metrics
    def register_metric(self, name: str, type: MetricType, labels: List[str]) -> Metric
    def record_metric(self, name: str, value: float, labels: dict = None) -> None
    def increment_counter(self, name: str, labels: dict = None) -> None
    def observe_histogram(self, name: str, value: float, labels: dict = None) -> None
    
    # Tracing
    def start_span(self, name: str, parent: Span = None) -> Span
    def end_span(self, span: Span, status: str = "ok") -> None
    def add_span_attribute(self, span: Span, key: str, value: Any) -> None
    
    # Context manager for tracing
    @contextmanager
    def trace(self, name: str) -> Span
    
    # Alerting
    def register_alert_rule(self, rule: AlertRule) -> None
    def trigger_alert(self, name: str, severity: str, message: str) -> None
    def resolve_alert(self, alert_id: str) -> None
    
    # LLM-specific (built-in)
    def track_llm_call(self, model: str, tokens: int, latency_ms: float, cost: float) -> None
    
    # Events (emitted)
    # - alert.triggered
    # - alert.resolved
    # - threshold.exceeded
    
    # Hooks (extensible)
    # - on_alert: Custom alert handling
    # - on_metric_threshold: Custom threshold actions
```

### Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Dec 2025 | Initial release with logging, basic metrics |
| 1.1.0 | Dec 2025 | Added OpenTelemetry tracing |
| 1.2.0 | Jan 2026 | Added LLM-specific metrics |
| 1.3.0 | Jan 2026 | Added alerting, dashboards, retention policies |

---

## F4: Security Operations Module

**Current Version**: 1.0.0  
**Repository**: `ai-cost-monitoring/modules/secops`

### Purpose

Runtime security including input validation, compliance enforcement, audit logging, and threat detection. Domain-agnostic protection layer.

### Configuration Schema

```yaml
# f4-secops-config.yaml
module: secops
version: "1.0.0"

input_validation:
  enabled: true
  
  prompt_injection:
    enabled: true
    detection_model: built_in  # or: custom, external
    action: block  # block | warn | log
    patterns:
      - "ignore previous instructions"
      - "you are now"
      - "disregard all"
    
  sql_injection:
    enabled: true
    action: block
    
  xss:
    enabled: true
    action: sanitize
    
  rate_limiting:
    enabled: true
    rules:
      - endpoint: "*"
        limit: 100
        window_seconds: 60
      - endpoint: "/api/execute"
        limit: 10
        window_seconds: 60

compliance:
  standards:
    - name: owasp_asvs
      version: "5.0"
      level: 2
    - name: owasp_llm
      version: "2025"
  
  checks:
    run_on_startup: true
    run_on_schedule: "0 0 * * *"  # daily
  
  reporting:
    enabled: true
    format: json
    output: ${COMPLIANCE_REPORTS_PATH}

audit:
  enabled: true
  
  events:
    authentication: true
    authorization: true
    data_access: true
    configuration_change: true
    # Domain layer adds custom event types
  
  storage:
    backend: bigquery  # postgres | bigquery | cloud_storage
    dataset: audit_logs
    retention_days: 2555  # 7 years
  
  immutability:
    enabled: true
    method: cryptographic_hash

threat_detection:
  enabled: true
  
  rules:
    brute_force:
      enabled: true
      threshold: 5
      window_minutes: 5
      action: block_ip
      duration_minutes: 30
    
    anomaly_detection:
      enabled: true
      model: statistical  # statistical | ml
      sensitivity: medium
    
    suspicious_patterns:
      enabled: true
      patterns: []  # Domain layer defines
  
  response:
    auto_block: true
    notify_channels: [pagerduty, slack]
```

### Public Interface

```python
# F4 SecOps Module - Public API

class SecOpsModule:
    """Foundation Module F4: Security Operations"""
    
    # Input Validation
    async def validate_input(self, input: str, context: dict) -> ValidationResult
    async def sanitize_input(self, input: str) -> str
    async def check_rate_limit(self, identifier: str, endpoint: str) -> RateLimitResult
    
    # Compliance
    async def run_compliance_check(self, standard: str = None) -> ComplianceReport
    async def get_compliance_status(self) -> ComplianceStatus
    
    # Audit
    async def log_audit_event(self, event: AuditEvent) -> None
    async def query_audit_log(self, query: AuditQuery) -> List[AuditEvent]
    async def export_audit_log(self, start: datetime, end: datetime) -> str
    
    # Threat Detection
    async def analyze_request(self, request: Request) -> ThreatAnalysis
    async def report_threat(self, threat: Threat) -> None
    async def get_blocked_entities(self) -> List[BlockedEntity]
    async def unblock_entity(self, entity_id: str) -> None
    
    # Domain Integration
    def register_audit_event_type(self, event_type: str, schema: dict) -> None
    def register_threat_pattern(self, pattern: ThreatPattern) -> None
    
    # Events (emitted)
    # - threat.detected
    # - entity.blocked
    # - compliance.violation
    # - audit.event_logged
    
    # Hooks (extensible)
    # - on_threat_detected: Custom response
    # - on_validation_failed: Custom handling
```

### Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Jan 2026 | Initial release with full security stack |

---

## F5: Self-Sustaining Operations Module

**Current Version**: 1.1.0  
**Repository**: `ai-cost-monitoring/modules/self-ops`

### Purpose

Autonomous operations including health monitoring, auto-remediation, incident learning, and AI-assisted development. Enables self-healing and self-improving systems.

### Configuration Schema

```yaml
# f5-self-ops-config.yaml
module: self-ops
version: "1.1.0"

health_monitoring:
  enabled: true
  
  components: []  # Defined by domain layer
  
  # Example components (provided by domain):
  # - name: database
  #   type: postgres
  #   check: connection
  #   interval_seconds: 30
  #   timeout_seconds: 5
  #
  # - name: broker_gateway
  #   type: custom
  #   endpoint: /health
  #   interval_seconds: 10
  
  default_interval_seconds: 60
  
  aggregation:
    method: worst_case  # worst_case | majority | all_healthy
    unhealthy_threshold: 3  # consecutive failures

auto_remediation:
  enabled: true
  
  strategies:
    restart:
      enabled: true
      max_attempts: 3
      backoff_multiplier: 2
      initial_delay_seconds: 5
    
    failover:
      enabled: true
      providers: []  # Domain layer defines
    
    scale:
      enabled: false
      min_instances: 1
      max_instances: 10
  
  playbooks: []  # Defined by domain layer
  
  # Example playbook (provided by domain):
  # - name: broker_reconnect
  #   trigger: broker_gateway.unhealthy
  #   steps:
  #     - action: notify
  #       channel: slack
  #     - action: restart
  #       target: broker_gateway
  #       delay_seconds: 10
  #     - action: verify
  #       timeout_seconds: 30

incident_learning:
  enabled: true
  
  capture:
    logs: true
    metrics: true
    traces: true
    context: true
  
  analysis:
    auto_categorize: true
    root_cause_detection: true
    similar_incident_search: true
  
  storage:
    backend: bigquery
    retention_days: 365

ai_development:  # aidoc-flow integration
  enabled: true
  
  features:
    code_generation: true
    documentation: true
    test_generation: true
    code_review: true
  
  triggers:
    on_pr: true
    on_push: false
    manual: true
  
  repository:
    provider: github
    org: ${GITHUB_ORG}
```

### Public Interface

```python
# F5 Self-Ops Module - Public API

class SelfOpsModule:
    """Foundation Module F5: Self-Sustaining Operations"""
    
    # Health Monitoring
    def register_component(self, component: HealthComponent) -> None
    async def check_health(self, component: str = None) -> HealthStatus
    async def get_health_history(self, component: str, duration: timedelta) -> List[HealthCheck]
    
    # Auto-Remediation
    def register_playbook(self, playbook: Playbook) -> None
    async def execute_playbook(self, playbook_name: str, context: dict = None) -> PlaybookResult
    async def get_remediation_history(self) -> List[RemediationEvent]
    
    # Incident Learning
    async def create_incident(self, incident: Incident) -> str
    async def update_incident(self, incident_id: str, updates: dict) -> None
    async def close_incident(self, incident_id: str, resolution: str) -> None
    async def find_similar_incidents(self, incident: Incident) -> List[Incident]
    async def get_incident_insights(self, incident_id: str) -> IncidentInsights
    
    # AI Development (aidoc-flow)
    async def generate_code(self, spec: CodeSpec) -> GeneratedCode
    async def generate_docs(self, source: str) -> Documentation
    async def generate_tests(self, source: str) -> TestSuite
    async def review_code(self, pr_url: str) -> CodeReview
    
    # Events (emitted)
    # - health.degraded
    # - health.recovered
    # - remediation.started
    # - remediation.completed
    # - incident.created
    # - incident.resolved
    
    # Hooks (extensible)
    # - on_health_change: Custom notifications
    # - on_remediation_failed: Escalation
    # - on_incident_created: Custom workflows
```

### Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Dec 2025 | Initial release with health monitoring, basic remediation |
| 1.1.0 | Jan 2026 | Added incident learning, aidoc-flow integration |

---

## F6: Infrastructure Module

**Current Version**: 1.2.0  
**Repository**: `ai-cost-monitoring/modules/infrastructure`

### Purpose

Cloud-agnostic infrastructure abstraction. Manages compute, storage, networking, and AI services through provider adapters.

### Configuration Schema

```yaml
# f6-infrastructure-config.yaml
module: infrastructure
version: "1.2.0"

provider: gcp  # gcp | aws | azure | hybrid

gcp:
  project: ${GCP_PROJECT}
  region: us-central1
  
  compute:
    type: cloud_run
    settings:
      min_instances: 1
      max_instances: 10
      cpu: 2
      memory: 4Gi
      timeout_seconds: 300
      concurrency: 80
  
  database:
    type: cloud_sql
    settings:
      tier: db-custom-2-4096
      storage_gb: 50
      ha_enabled: true
      backup_enabled: true
      backup_retention_days: 7
  
  ai:
    type: vertex_ai
    settings:
      default_model: gemini-1.5-pro
      fallback_model: gemini-1.5-flash
      quota_project: ${GCP_PROJECT}
  
  messaging:
    type: pubsub
    topics: []  # Domain layer defines
  
  storage:
    type: cloud_storage
    buckets: []  # Domain layer defines
  
  secrets:
    type: secret_manager
    prefix: nexus-

networking:
  vpc:
    enabled: true
    cidr: 10.0.0.0/16
  
  load_balancer:
    type: global
    ssl: true
    certificate: managed
  
  dns:
    zone: ${DNS_ZONE}
    domain: ${DOMAIN}

cost_management:
  budget:
    monthly_limit_usd: 200
    alert_thresholds: [50, 75, 90, 100]
  
  optimization:
    auto_scaling: true
    spot_instances: false
    committed_use: false

# Provider-specific adapters
adapters:
  aws:
    region: us-east-1
    # AWS-specific mappings...
  
  azure:
    location: eastus
    # Azure-specific mappings...
```

### Public Interface

```python
# F6 Infrastructure Module - Public API

class InfrastructureModule:
    """Foundation Module F6: Infrastructure"""
    
    # Compute
    async def deploy_service(self, service: ServiceSpec) -> Deployment
    async def scale_service(self, service_name: str, instances: int) -> None
    async def get_service_status(self, service_name: str) -> ServiceStatus
    
    # Database
    async def get_connection(self, database: str = "default") -> Connection
    async def execute_migration(self, migration: Migration) -> MigrationResult
    
    # AI Services
    async def get_ai_client(self, model: str = None) -> AIClient
    async def list_available_models(self) -> List[Model]
    
    # Messaging
    async def publish(self, topic: str, message: dict) -> None
    async def subscribe(self, topic: str, handler: Callable) -> Subscription
    
    # Storage
    async def upload_file(self, bucket: str, path: str, data: bytes) -> str
    async def download_file(self, bucket: str, path: str) -> bytes
    async def list_files(self, bucket: str, prefix: str = "") -> List[str]
    
    # Secrets
    async def get_secret(self, name: str) -> str
    async def set_secret(self, name: str, value: str) -> None
    
    # Cost
    async def get_current_cost(self) -> CostReport
    async def get_cost_forecast(self) -> CostForecast
    
    # Events (emitted)
    # - deployment.started
    # - deployment.completed
    # - cost.threshold_exceeded
    # - service.scaled
    
    # Hooks (extensible)
    # - on_deploy: Custom deployment steps
    # - on_cost_alert: Custom notifications
```

### Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Dec 2025 | Initial release with GCP support |
| 1.1.0 | Jan 2026 | Added cost management, basic AWS adapter |
| 1.2.0 | Jan 2026 | Added AI services abstraction, Azure adapter |

---

## F7: Configuration Manager Module

**Current Version**: 1.0.0
**Repository**: `ai-cost-monitoring/modules/config-manager`

### Purpose

Centralized configuration management with environment-aware loading, validation, hot-reload, and feature flags. Domain-agnostic — manages configuration lifecycle without understanding the configuration semantics.

### Configuration Schema

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
    format: yaml  # yaml | json | toml
    watch: true
    reload_on_change: true

  environment:
    enabled: true
    prefix: NEXUS_
    transform: lowercase_underscore  # NEXUS_DB_HOST -> db.host

  secrets:
    enabled: true
    backend: secret_manager  # secret_manager | vault | env
    prefix: nexus-
    cache_ttl_seconds: 300

validation:
  enabled: true
  schema_path: ./config/schema.yaml
  strict_mode: true  # Fail on unknown keys

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

  strategies:
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

  backend: database  # memory | database | launchdarkly

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
    strategies:
      - percentage
      - user_list
      - attribute_match

defaults:
  # Domain layer provides default values
  merge_strategy: deep  # deep | shallow | replace

encryption:
  enabled: true
  algorithm: aes-256-gcm
  key_source: secret_manager
  encrypted_keys:
    - "*.password"
    - "*.secret"
    - "*.api_key"
    - "*.private_key"
```

### Public Interface

```python
# F7 Configuration Manager Module - Public API

class ConfigManagerModule:
    """Foundation Module F7: Configuration Manager"""

    # Configuration Access
    def get(self, key: str, default: Any = None) -> Any
    def get_required(self, key: str) -> Any  # Raises if missing
    def get_section(self, prefix: str) -> dict
    def get_all(self) -> dict

    # Type-safe Getters
    def get_str(self, key: str, default: str = None) -> str
    def get_int(self, key: str, default: int = None) -> int
    def get_float(self, key: str, default: float = None) -> float
    def get_bool(self, key: str, default: bool = None) -> bool
    def get_list(self, key: str, default: list = None) -> list
    def get_dict(self, key: str, default: dict = None) -> dict
    def get_duration(self, key: str, default: timedelta = None) -> timedelta

    # Configuration Updates
    async def set(self, key: str, value: Any) -> None
    async def set_many(self, updates: dict) -> None
    async def delete(self, key: str) -> None

    # Hot Reload
    async def reload(self, strategy: str = "graceful") -> ReloadResult
    def on_reload(self, callback: Callable[[dict], None]) -> None
    def watch(self, key_pattern: str, callback: Callable[[str, Any, Any], None]) -> None

    # Feature Flags
    def is_enabled(self, flag: str, context: dict = None) -> bool
    def get_flag_value(self, flag: str, context: dict = None) -> Any
    async def set_flag(self, flag: str, enabled: bool, targeting: dict = None) -> None
    async def create_flag(self, flag: FlagDefinition) -> None
    async def list_flags(self) -> List[FeatureFlag]

    # Validation
    def validate(self, config: dict = None) -> ValidationResult
    def get_schema(self) -> dict

    # Secrets
    async def get_secret(self, name: str) -> str
    async def set_secret(self, name: str, value: str) -> None
    async def rotate_secret(self, name: str) -> str

    # Events (emitted)
    # - config.loaded
    # - config.reloaded
    # - config.key_changed
    # - config.validation_failed
    # - flag.evaluated
    # - flag.changed

    # Hooks (extensible)
    # - on_load: Custom config transformation
    # - on_validate: Custom validation rules
    # - on_reload: Pre/post reload actions
```

### Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Jan 2026 | Initial release with config loading, validation, hot-reload, feature flags |

---

## Domain Layers (D-Series)

Domain layers contain project-specific business logic. They depend on Foundation Modules but are not reusable across different project types.

### D1: Agent & A2A Orchestration

**Project-Specific**: Defines agents, skills, and external integrations for the domain.

**For Cost Monitoring Platform**:
- 7 Trading Agents (Coordinator, Earnings, Options, Risk, Execution, Portfolio, Data)
- 32 Skills total
- A2A Gateway for Knowledge Platform integration

### D2: Adaptive UI (A2UI)

**Project-Specific**: Defines UI components and dynamic generation rules for the domain.

**Framework**: Based on Google's A2UI (Adaptive AI UI) framework for context-aware, LLM-powered interfaces.

**For Cost Monitoring Platform**:
- Chat, Dashboard (4), Trading (5), Analysis (5)
- Dynamic widgets: EarningsCountdown, IVOpportunity, BiasWarning, etc.

### D3: Domain Engine

**Project-Specific**: Core business logic engine.

**For Cost Monitoring Platform** (Trading Engine):
- LLM Ensemble (4-model voting)
- Analysis Engine (8-phase earnings)
- Strategy Engine (options strategies)
- Risk Engine (7 circuit breakers)
- Execution Engine (order management)

### D4: MCP + Marketplace

**Project-Specific**: Data connectors relevant to the domain.

**For Cost Monitoring Platform**:
- Core: ib-trading, postgres, browser, context7, files
- Marketplace: Polygon, Yahoo, SEC EDGAR, etc.

### D5: Learning Governance & Delegation

**Project-Specific**: Learning rules and delegation contracts.

**For Cost Monitoring Platform**:
- Trade analysis, bias detection, signal effectiveness
- A2A delegation to Knowledge Platform

### D6: Data Layer

**Project-Specific**: Domain data models and storage.

**For Cost Monitoring Platform**:
- Hot: positions, orders, forecasts, circuit breakers
- Cold: historical trades, patterns, ML models (via A2A)

### D7: Domain Core

**Project-Specific**: Core capabilities definition.

**For Cost Monitoring Platform** (6 Capabilities):
- EXTENDS, COLLABORATES, ADAPTS, GROWS, DEVELOPS, HEALS

---

## Module Versioning & Compatibility

### Version Matrix Example

| Project | F1 IAM | F2 Session | F3 Observ | F4 SecOps | F5 SelfOps | F6 Infra | F7 Config |
|---------|--------|------------|-----------|-----------|------------|----------|-----------|
| Cost Monitoring Platform v4.2 | 1.2.0 | 1.1.0 | 1.3.0 | 1.0.0 | 1.1.0 | 1.2.0 | 1.0.0 |
| Knowledge Platform v3.5 | 1.1.0 | 1.0.0 | 1.3.0 | 1.0.0 | 1.0.0 | 1.1.0 | 1.0.0 |
| Future Project | 1.2.0 | 1.1.0 | 1.3.0 | 1.0.0 | 1.1.0 | 1.2.0 | 1.0.0 |

### Compatibility Rules

1. **Major version** (X.0.0): Breaking changes, requires migration
2. **Minor version** (0.X.0): New features, backward compatible
3. **Patch version** (0.0.X): Bug fixes, fully compatible

### Upgrade Path

```yaml
# project-dependencies.yaml
foundation_modules:
  iam:
    version: ">=1.1.0,<2.0.0"
    # Allows 1.1.0, 1.2.0, etc. but not 2.0.0
  
  session:
    version: "~1.1.0"
    # Allows 1.1.x patches only
  
  observability:
    version: "1.3.0"
    # Exact version
```

---

## Project Bootstrap Example

```yaml
# ai-cost-monitoring-v4.2.yaml
project:
  name: ai-cost-monitoring
  version: "4.2"
  type: trading_platform

foundation:
  iam: "1.2.0"
  session: "1.1.0"
  observability: "1.3.0"
  secops: "1.0.0"
  self-ops: "1.1.0"
  infrastructure: "1.2.0"
  config-manager: "1.0.0"

domain:
  layers:
    - agent_orchestration
    - adaptive_ui
    - trading_engine
    - mcp_marketplace
    - learning_governance
    - data_layer
    - trading_core

configuration:
  foundation:
    include:
      - ./config/f1-iam.yaml
      - ./config/f2-session.yaml
      - ./config/f3-observability.yaml
      - ./config/f4-secops.yaml
      - ./config/f5-self-ops.yaml
      - ./config/f6-infrastructure.yaml
      - ./config/f7-config-manager.yaml
  
  domain:
    include:
      - ./config/trading-engine.yaml
      - ./config/agents.yaml
      - ./config/mcp-servers.yaml
```

---

## Summary

The Foundation Modules + Domain Layers architecture provides:

| Benefit | Description |
|---------|-------------|
| **Flexibility** | Mix different module versions per project |
| **Reusability** | Same modules power multiple projects |
| **Independence** | Upgrade modules independently |
| **Consistency** | Unified security, observability, operations |
| **Speed** | New projects start with proven infrastructure |
| **Quality** | Modules battle-tested across projects |

---

*AI Cost Monitoring Platform v4.2 — Foundation Modules + Domain Layers — January 2026*
