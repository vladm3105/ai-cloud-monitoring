# ---
# title: "BDD-07: F7 Configuration Manager Feature Scenarios"
# tags:
#   - bdd
#   - foundation-module
#   - f7-config
#   - layer-4-artifact
#   - shared-architecture
# custom_fields:
#   document_type: bdd
#   artifact_type: BDD
#   layer: 4
#   module_id: F7
#   module_name: Configuration Manager
#   architecture_approaches: [ai-agent-based, traditional]
#   priority: shared
#   development_status: draft
#   adr_ready_score: 90
#   schema_version: "1.0"
# ---

@brd:BRD-07 @prd:PRD-07 @ears:EARS-07
Feature: F7 Configuration Manager
  As a system administrator
  I want configuration management with hot-reload, feature flags, and secret handling
  So that the platform can adapt to operational changes without downtime

  Background:
    Given the system timezone is "America/New_York"
    And the configuration service is initialized
    And PostgreSQL database is available for state persistence
    And GCP Secret Manager is accessible

  # =============================================================================
  # PRIMARY SUCCESS PATH SCENARIOS (@primary)
  # =============================================================================

  @primary @scenario-id:BDD.07.13.01
  Scenario: Multi-source configuration loading with priority resolution
    # @ears: EARS.07.25.001
    # @threshold: PRD.07.perf.config_lookup.p95 = 1ms
    Given the following configuration sources exist:
      | Source      | Key           | Value           |
      | Environment | COSTMON_PORT  | 9000            |
      | Secrets     | db.password   | secret123       |
      | File        | app.port      | 8080            |
      | Defaults    | app.port      | 3000            |
    When the configuration value for "app.port" is requested
    Then the resolved value should be "8080" from "File" source
    And the configuration lookup should complete within 1 milliseconds

  @primary @scenario-id:BDD.07.13.02
  Scenario: Environment variable resolution with type coercion
    # @ears: EARS.07.25.002
    # @threshold: PRD.07.perf.env_lookup.p95 = 0.5ms
    Given the environment variable "COSTMON_DB_PORT" is set to "5432"
    And the environment variable "COSTMON_DEBUG_ENABLED" is set to "true"
    And the environment variable "COSTMON_REQUEST_TIMEOUT_MS" is set to "5000"
    When the configuration path "db.port" is requested
    Then the value should be coerced to integer 5432
    When the configuration path "debug.enabled" is requested
    Then the value should be coerced to boolean true
    And environment variable lookups should complete within 0.5 milliseconds

  @primary @scenario-id:BDD.07.13.03
  Scenario: Secret retrieval from GCP Secret Manager
    # @ears: EARS.07.25.003
    # @threshold: PRD.07.perf.secret_retrieval.p95 = 50ms
    # @threshold: PRD.07.sec.secret_cache_ttl = 300s
    Given a secret "database.password" exists in GCP Secret Manager
    And the secret is encrypted with AES-256-GCM
    When the configuration key "database.password" is requested
    Then the secret should be retrieved and decrypted
    And the secret should be cached with TTL of 300 seconds
    And the retrieval should complete within 50 milliseconds

  @primary @scenario-id:BDD.07.13.04
  Scenario: Configuration file change detection and loading
    # @ears: EARS.07.25.004
    # @threshold: PRD.07.cfg.debounce = 2s
    # @threshold: PRD.07.perf.file_read.p95 = 100ms
    Given a configuration file "config.yaml" is being watched
    And the file watcher is active with 5 second polling interval
    When the configuration file is modified
    Then file events should be debounced for 2 seconds
    And the YAML configuration should be read
    And the configuration should be merged using deep merge strategy
    And the file read should complete within 100 milliseconds

  @primary @scenario-id:BDD.07.13.05
  Scenario: Schema validation for new configuration
    # @ears: EARS.07.25.005
    # @threshold: PRD.07.perf.schema_validation.p95 = 100ms
    Given a new configuration is loaded from file
    And a YAML schema definition exists for validation
    When schema validation is performed
    Then the configuration should be validated against the schema
    And type coercion rules should be applied
    And validation should complete within 100 milliseconds

  @primary @scenario-id:BDD.07.13.06
  Scenario: Hot reload initiation with request draining
    # @ears: EARS.07.25.006
    # @threshold: PRD.07.cfg.drain_timeout = 30s
    # @threshold: PRD.07.perf.hot_reload.p95 = 5s
    Given a valid configuration change is detected
    And there are 5 in-flight configuration requests
    When hot reload is initiated
    Then a snapshot of current configuration should be created
    And the service should stop accepting new requests
    And in-flight requests should be drained within 30 seconds
    And the hot reload should complete within 5 seconds

  @primary @scenario-id:BDD.07.13.07
  Scenario: Hot reload callback notification
    # @ears: EARS.07.25.007
    # @threshold: PRD.07.cfg.callback_timeout = 5s
    Given the following reload listeners are registered:
      | Listener ID | Component       |
      | listener-1  | F1 IAM Service  |
      | listener-2  | F2 Session Mgr  |
      | listener-3  | F3 Observability|
    And the configuration keys "auth.timeout" and "session.ttl" have changed
    When new configuration is applied successfully
    Then on_reload callbacks should be invoked for all registered listeners
    And each callback should receive the list of changed_keys
    And callback acknowledgments should be received within 5 seconds

  @primary @scenario-id:BDD.07.13.08
  Scenario: Configuration snapshot creation
    # @ears: EARS.07.25.011
    # @threshold: PRD.07.perf.snapshot_creation.p95 = 100ms
    Given a hot-reload operation is initiated
    When the configuration snapshot is created
    Then a unique snapshot ID with timestamp should be generated
    And the snapshot should be persisted to PostgreSQL
    And snapshot history should be maintained
    And snapshot creation should complete within 100 milliseconds

  @primary @scenario-id:BDD.07.13.09
  Scenario: Configuration rollback to previous snapshot
    # @ears: EARS.07.25.012
    # @threshold: PRD.07.perf.rollback.p95 = 30s
    Given the following configuration snapshots exist:
      | Snapshot ID                          | Created At           |
      | snap-2026-02-09T10:00:00-001         | 2026-02-09 10:00:00  |
      | snap-2026-02-09T11:00:00-002         | 2026-02-09 11:00:00  |
    When rollback is requested for snapshot "snap-2026-02-09T10:00:00-001"
    Then the snapshot should be retrieved from PostgreSQL
    And snapshot integrity should be validated
    And the snapshot should be applied as current configuration
    And on_reload callbacks should be invoked
    And a rollback event should be emitted to F3 Observability
    And rollback should complete within 30 seconds

  # =============================================================================
  # ALTERNATIVE PATH SCENARIOS (@alternative)
  # =============================================================================

  @alternative @scenario-id:BDD.07.13.10
  Scenario: Configuration diff between snapshots
    # @ears: EARS.07.25.013
    Given two configuration snapshots exist with IDs "snap-001" and "snap-002"
    And snapshot "snap-001" has key "app.timeout" with value "30"
    And snapshot "snap-002" has key "app.timeout" with value "60"
    And snapshot "snap-002" has new key "app.retries" with value "3"
    When diff is requested between "snap-001" and "snap-002"
    Then both snapshots should be retrieved
    And key-by-key differences should be computed
    And changes should be classified as:
      | Key           | Classification |
      | app.timeout   | modified       |
      | app.retries   | added          |
    And the diff should complete within 200 milliseconds

  @alternative @scenario-id:BDD.07.13.11
  Scenario: Configuration dry-run validation
    # @ears: EARS.07.25.014
    Given a proposed configuration change exists
    When dry-run validation is requested
    Then the configuration should be validated against schema
    And dependency compatibility should be checked
    And feature flag impacts should be simulated
    And a validation report should be returned
    And no configuration changes should be applied
    And dry-run should complete within 500 milliseconds

  @alternative @scenario-id:BDD.07.13.12
  Scenario: External feature flag service synchronization
    # @ears: EARS.07.25.016
    Given external flag service integration is enabled for "LaunchDarkly"
    And the following external flags exist:
      | Flag Key         | Enabled |
      | new-dashboard    | true    |
      | beta-analytics   | false   |
    When the sync cycle runs
    Then external flags should be polled
    And external flags should be merged with local flags
    And results should be cached with configurable TTL
    And a sync event should be emitted to F3 Observability
    And sync should complete within 1 second

  # =============================================================================
  # NEGATIVE ERROR CONDITION SCENARIOS (@negative)
  # =============================================================================

  @negative @scenario-id:BDD.07.13.13
  Scenario: Schema validation failure preserves current configuration
    # @ears: EARS.07.25.201
    Given a valid configuration is currently active
    And a new configuration file is loaded with invalid schema
    When schema validation fails
    Then the configuration change should be rejected
    And the current valid configuration should be preserved
    And validation errors should be logged with detailed path information
    And a "config.validation_failed" event should be emitted to F3 Observability
    And an error response should be returned to the requester

  @negative @scenario-id:BDD.07.13.14
  Scenario: Secret Manager unavailability with fallback to cache
    # @ears: EARS.07.25.202
    # @threshold: PRD.07.sec.secret_cache_ttl = 300s
    Given a secret "api.key" is cached with TTL of 300 seconds
    And 120 seconds have elapsed since caching
    When GCP Secret Manager becomes unavailable
    And the secret "api.key" is requested
    Then the cached secret value should be returned
    And a warning should be logged to F3 Observability
    And retry with exponential backoff should be attempted (max 3 attempts)
    And if all retries fail, a "secret.retrieval_failed" event should be emitted

  @negative @scenario-id:BDD.07.13.15
  Scenario: Configuration file unreadable
    # @ears: EARS.07.25.203
    Given a valid configuration is currently cached
    And the configuration file becomes unreadable due to permission error
    When the file watcher detects a change attempt
    Then the last known good configuration should be preserved
    And an error should be logged with file path and reason
    And a "config.file_error" event should be emitted to F3 Observability
    And cached configuration should continue to be served

  @negative @scenario-id:BDD.07.13.16
  Scenario: Hot reload timeout triggers auto-rollback
    # @ears: EARS.07.25.204
    # @threshold: PRD.07.cfg.drain_timeout = 30s
    Given a hot reload operation is in progress
    And in-flight requests are being drained
    When the drain timeout of 30 seconds is exceeded
    Then the reload operation should be aborted
    And auto-rollback to previous snapshot should occur
    And a "config.reload_timeout" event should be emitted to F3 Observability
    And normal operation should resume with previous configuration

  @negative @scenario-id:BDD.07.13.17
  Scenario: Snapshot retrieval failure during rollback
    # @ears: EARS.07.25.206
    Given a rollback is requested for snapshot "corrupted-snap-001"
    When snapshot retrieval fails due to database error
    Then the rollback operation should be aborted
    And current configuration should be preserved
    And an error should be logged with snapshot_id
    And a "config.rollback_failed" event should be emitted to F3 Observability
    And an error should be returned to the requester

  @negative @scenario-id:BDD.07.13.18
  Scenario: PostgreSQL unavailability for feature flags
    # @ears: EARS.07.25.209
    Given feature flags are cached in memory
    When PostgreSQL becomes unavailable
    And a feature flag evaluation is requested
    Then in-memory cached flags should be used
    And a warning should be logged to F3 Observability
    And connection retry with exponential backoff should be initiated
    And a "db.connection_failed" event should be emitted

  # =============================================================================
  # EDGE CASE SCENARIOS (@edge_case)
  # =============================================================================

  @edge_case @scenario-id:BDD.07.13.19
  Scenario: Callback notification timeout for single listener
    # @ears: EARS.07.25.211
    # @threshold: PRD.07.cfg.callback_timeout = 5s
    Given the following reload listeners are registered:
      | Listener ID | Component       |
      | listener-1  | F1 IAM Service  |
      | listener-2  | Slow Service    |
      | listener-3  | F3 Observability|
    When new configuration is applied and callbacks are invoked
    And "listener-2" exceeds the 5 second callback timeout
    Then callback timeout should be logged with listener ID
    And other listeners should continue to be notified
    And a "config.callback_timeout" event should be emitted to F3 Observability
    And the timeout should be included in reload summary

  @edge_case @scenario-id:BDD.07.13.20
  Scenario: Snapshot retention limit enforcement
    # @ears: EARS.07.25.104
    # @threshold: PRD.07.cfg.snapshot_retention_count = 100
    # @threshold: PRD.07.cfg.snapshot_retention_days = 30
    Given 100 configuration snapshots exist in PostgreSQL
    And 5 snapshots are older than 30 days
    When a new snapshot is created
    Then the retention limit of 100 snapshots should be enforced
    And snapshots older than 30 days should be purged automatically
    And the oldest snapshot should be removed to maintain the count

  @edge_case @scenario-id:BDD.07.13.21
  Scenario: Secret cache TTL expiration and proactive refresh
    # @ears: EARS.07.25.103
    # @threshold: PRD.07.sec.secret_cache_ttl = 300s
    Given a secret "database.password" is cached
    And 280 seconds have elapsed since caching (near TTL expiration)
    When the secret cache maintenance cycle runs
    Then proactive refresh should be initiated before expiration
    And if refresh succeeds, the TTL should be reset
    And if refresh fails, the failure should be handled gracefully

  @edge_case @scenario-id:BDD.07.13.22
  Scenario: Encryption key nearing rotation threshold
    # @ears: EARS.07.25.107
    # @threshold: PRD.07.sec.key_rotation = 90 days
    Given an encryption key is active and 85 days old
    When the key age check is performed
    Then the key age should be tracked against 90 day rotation interval
    And key versioning should support decryption of older values
    And secure key references should be maintained

  # =============================================================================
  # DATA-DRIVEN SCENARIOS (@data_driven)
  # =============================================================================

  @data_driven @scenario-id:BDD.07.13.23
  Scenario Outline: Feature flag evaluation with percentage strategy
    # @ears: EARS.07.25.008
    # @threshold: PRD.07.perf.flag_evaluation.p95 = 5ms
    Given a feature flag "<flag_key>" exists with percentage strategy
    And the percentage threshold is <threshold>
    When is_enabled("<flag_key>", context) is called with user_id "<user_id>"
    Then the user_id should be hashed
    And the hash should be compared against threshold <threshold>
    And the result should be <expected_result>
    And evaluation should complete within 5 milliseconds

    Examples:
      | flag_key         | threshold | user_id   | expected_result |
      | new-feature      | 50        | user-001  | true            |
      | new-feature      | 50        | user-999  | false           |
      | beta-rollout     | 10        | user-050  | false           |
      | beta-rollout     | 100       | user-any  | true            |
      | disabled-feature | 0         | user-001  | false           |

  @data_driven @scenario-id:BDD.07.13.24
  Scenario Outline: Feature flag evaluation with user list strategy
    # @ears: EARS.07.25.009
    # @threshold: PRD.07.perf.flag_evaluation.p95 = 5ms
    Given a feature flag "<flag_key>" exists with user_list strategy
    And the enabled_users list contains "<enabled_users>"
    When is_enabled("<flag_key>", context) is called with user_id "<user_id>"
    Then the flag configuration should be retrieved
    And membership in enabled_users should be checked
    And the result should be <expected_result>
    And the result should be cached

    Examples:
      | flag_key      | enabled_users          | user_id   | expected_result |
      | admin-feature | admin-1,admin-2        | admin-1   | true            |
      | admin-feature | admin-1,admin-2        | user-001  | false           |
      | vip-access    | vip-100,vip-200,vip-300| vip-200   | true            |
      | empty-list    |                        | any-user  | false           |

  @data_driven @scenario-id:BDD.07.13.25
  Scenario Outline: Feature flag evaluation with attribute strategy
    # @ears: EARS.07.25.010
    # @threshold: PRD.07.perf.flag_evaluation.p95 = 5ms
    Given a feature flag "<flag_key>" exists with attribute strategy
    And the attribute rule requires <attribute> equals "<required_value>"
    When is_enabled("<flag_key>", context) is called with <attribute> "<actual_value>"
    Then attribute rules should be evaluated against context
    And rule precedence should be applied
    And the result should be <expected_result>

    Examples:
      | flag_key        | attribute     | required_value | actual_value | expected_result |
      | enterprise-only | trust_level   | enterprise     | enterprise   | true            |
      | enterprise-only | trust_level   | enterprise     | standard     | false           |
      | region-locked   | region        | us-east        | us-east      | true            |
      | region-locked   | region        | us-east        | eu-west      | false           |
      | workspace-beta  | workspace_id  | ws-beta-001    | ws-beta-001  | true            |

  @data_driven @scenario-id:BDD.07.13.26
  Scenario Outline: Type coercion based on suffix patterns
    # @ears: EARS.07.25.002
    Given an environment variable "<env_var>" with value "<string_value>"
    When the configuration value is requested
    Then the value should be coerced to type <expected_type>
    And the coerced value should be <expected_value>

    Examples:
      | env_var                    | string_value | expected_type | expected_value |
      | COSTMON_SERVER_PORT        | 8080         | integer       | 8080           |
      | COSTMON_DEBUG_ENABLED      | true         | boolean       | true           |
      | COSTMON_CACHE_ENABLED      | false        | boolean       | false          |
      | COSTMON_REQUEST_TIMEOUT_MS | 5000         | integer       | 5000           |
      | COSTMON_API_KEY            | abc123       | string        | abc123         |

  # =============================================================================
  # INTEGRATION SCENARIOS (@integration)
  # =============================================================================

  @integration @scenario-id:BDD.07.13.27
  Scenario: Configuration change notification to F1 IAM Service
    # @ears: EARS.07.25.007
    Given F1 IAM Service is registered as a reload listener
    And the configuration key "auth.session_timeout" changes from "30" to "60"
    When the hot reload completes successfully
    Then F1 IAM Service should receive on_reload callback
    And the changed_keys list should include "auth.session_timeout"
    And F1 IAM Service should acknowledge within 5 seconds

  @integration @scenario-id:BDD.07.13.28
  Scenario: Audit event emission to F3 Observability
    # @ears: EARS.07.25.401
    Given a configuration change is made by user "admin-001"
    And the changed keys are "app.timeout" and "app.retries"
    When the configuration is applied
    Then an audit log should be created with:
      | Field       | Value                    |
      | timestamp   | current timestamp        |
      | user_id     | admin-001                |
      | action      | config_update            |
      | changed_keys| app.timeout, app.retries |
      | result      | success                  |
    And the audit log should be encrypted at rest
    And an event should be emitted to F3 Observability

  @integration @scenario-id:BDD.07.13.29
  Scenario: Configuration drift detection across environments
    # @ears: EARS.07.25.017
    Given the following environment configurations exist:
      | Environment | Key         | Value |
      | production  | app.timeout | 30    |
      | staging     | app.timeout | 60    |
      | production  | app.retries | 3     |
      | staging     | app.retries | 3     |
    When drift detection scan is triggered
    Then configurations should be compared across environments
    And differences should be identified between intended and actual state
    And a drift report should be generated showing:
      | Key         | Production | Staging | Drift |
      | app.timeout | 30         | 60      | yes   |
      | app.retries | 3          | 3       | no    |
    And if drift exceeds threshold, an alert should be emitted
    And detection should complete within 5 seconds per environment

  @integration @scenario-id:BDD.07.13.30
  Scenario: Health check endpoint verification
    # @ears: EARS.07.25.405
    When the health check endpoint is invoked
    Then file watcher status should be verified as active
    And PostgreSQL connectivity should be verified
    And Secret Manager connectivity should be verified
    And service status should be returned with component details:
      | Component       | Status  |
      | file_watcher    | healthy |
      | postgresql      | healthy |
      | secret_manager  | healthy |

  # =============================================================================
  # QUALITY ATTRIBUTE SCENARIOS (@quality_attribute)
  # =============================================================================

  @quality_attribute @performance @scenario-id:BDD.07.13.31
  Scenario: Configuration lookup performance under load
    # @ears: EARS.07.02.01
    # @threshold: PRD.07.perf.config_lookup.p95 = 1ms
    Given the configuration cache is populated with 1000 keys
    When 10000 concurrent configuration lookups are performed
    Then the p95 latency should be less than 1 millisecond
    And no lookup should fail due to timeout

  @quality_attribute @performance @scenario-id:BDD.07.13.32
  Scenario: Feature flag evaluation throughput
    # @ears: EARS.07.05.02
    Given feature flags are cached in memory
    When 10000 flag evaluations are performed per second
    Then all evaluations should complete successfully
    And p95 latency should remain under 5 milliseconds

  @quality_attribute @security @scenario-id:BDD.07.13.33
  Scenario: Sensitive value redaction in logs
    # @ears: EARS.07.25.402
    Given a configuration contains the following keys:
      | Key                     | Value           |
      | database.password       | secret123       |
      | api.secret              | api-secret-xyz  |
      | auth.api_key            | key-abc-123     |
      | encryption.private_key  | -----BEGIN...   |
      | service.token           | tok-xyz-789     |
      | db.connection_string    | postgres://...  |
    When configuration is logged for debugging
    Then all sensitive values should be replaced with "[REDACTED]"
    And patterns *.password, *.secret, *.api_key, *.private_key, *.token, *.credentials, *.connection_string should be detected
    And no plaintext sensitive values should appear in logs

  @quality_attribute @security @scenario-id:BDD.07.13.34
  Scenario: Encryption key rotation scheduling
    # @ears: EARS.07.25.015
    # @threshold: PRD.07.sec.key_rotation = 90 days
    Given the current encryption key is 90 days old
    When the key rotation interval is reached
    Then key rotation should be triggered via GCP Secret Manager
    And sensitive values should be re-encrypted with new key
    And encryption key references should be updated
    And a rotation event should be emitted to F3 Observability
    And rotation should complete within 60 seconds

  @quality_attribute @reliability @scenario-id:BDD.07.13.35
  Scenario: Service availability maintenance
    # @ears: EARS.07.04.01
    Given the configuration service is running
    When monitoring uptime over a 30 day period
    Then service availability should be at least 99.9%
    And recovery from failures should occur within 5 minutes

  # =============================================================================
  # FAILURE RECOVERY SCENARIOS (@failure_recovery)
  # =============================================================================

  @failure_recovery @scenario-id:BDD.07.13.36
  Scenario: Feature flag evaluation error returns safe default
    # @ears: EARS.07.25.205
    Given a feature flag "unstable-feature" is configured
    When flag evaluation encounters an unexpected error
    Then a default false value should be returned
    And the error should be logged with flag_key and context
    And a "flag.evaluation_error" event should be emitted to F3 Observability
    And error details should not be exposed to the caller

  @failure_recovery @scenario-id:BDD.07.13.37
  Scenario: Feature flag misconfiguration rejection
    # @ears: EARS.07.25.207
    Given a feature flag update is submitted with invalid targeting rules
    When the flag configuration is validated
    Then the flag configuration update should be rejected
    And current flag state should be preserved
    And a validation error should be logged with rule details
    And a "flag.config_invalid" event should be emitted to F3 Observability

  @failure_recovery @scenario-id:BDD.07.13.38
  Scenario: Encryption key rotation failure recovery
    # @ears: EARS.07.25.210
    Given encryption key rotation is initiated
    When the rotation fails due to GCP Secret Manager error
    Then the current encryption key should be preserved
    And an error should be logged with rotation attempt details
    And a "security.key_rotation_failed" event should be emitted to F3 Observability
    And a retry should be scheduled

  @failure_recovery @scenario-id:BDD.07.13.39
  Scenario: Configuration drift alert triggering
    # @ears: EARS.07.25.208
    Given configuration drift detection is enabled
    When drift is detected between production and staging environments
    Then drift details should be logged
    And a "config.drift_detected" event should be emitted with affected keys
    And an alert should be triggered via F3 Observability
    And drift should be included in the status report

  @failure_recovery @scenario-id:BDD.07.13.40
  Scenario: Hot reload draining state request rejection
    # @ears: EARS.07.25.105
    # @threshold: PRD.07.cfg.drain_timeout = 30s
    Given configuration reload is in DRAINING state
    When a new configuration request arrives
    Then the request should be rejected with appropriate error
    And the service should continue waiting for in-flight requests to complete
    And transition to APPLYING state should occur when drain completes
    And if drain timeout is reached, transition back to STABLE should occur

  # =============================================================================
  # METRICS EMISSION SCENARIOS (@metrics)
  # =============================================================================

  @metrics @scenario-id:BDD.07.13.41
  Scenario: Metrics emission to F3 Observability
    # @ears: EARS.07.25.406
    Given the configuration service is operational
    When configuration operations are performed
    Then the following metrics should be emitted to F3 Observability:
      | Metric Name                        | Type      |
      | config_lookups_total               | counter   |
      | flag_evaluations_total             | counter   |
      | hot_reload_duration_seconds        | histogram |
      | secret_retrieval_duration_seconds  | histogram |

  # =============================================================================
  # IMMUTABILITY SCENARIOS (@immutability)
  # =============================================================================

  @immutability @scenario-id:BDD.07.13.42
  Scenario: Configuration value immutability after load
    # @ears: EARS.07.25.407
    Given configuration values are loaded and cached
    When an attempt is made to modify a cached value in-place
    Then the modification should be prevented
    And a full reload cycle should be required for changes
    And configuration integrity should be maintained

  # =============================================================================
  # INPUT VALIDATION SCENARIOS (@validation)
  # =============================================================================

  @validation @scenario-id:BDD.07.13.43
  Scenario: Malformed YAML configuration rejection
    # @ears: EARS.07.25.404
    Given a configuration update is submitted with malformed YAML
    When input validation is performed
    Then the configuration should be validated against schema
    And the malformed YAML should be rejected with 400 Bad Request
    And inputs should be sanitized before processing
    And validation failures should be logged with request context
