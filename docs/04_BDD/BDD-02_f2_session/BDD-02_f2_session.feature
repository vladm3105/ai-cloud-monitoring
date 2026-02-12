# ---
# title: "BDD-02: F2 Session Management Scenarios"
# tags: [bdd, layer-4-artifact, f2-session, shared-architecture]
# custom_fields:
#   document_type: bdd
#   artifact_type: BDD
#   layer: 4
#   module_id: F2
#   module_name: Session & Context Management
#   adr_ready_score: 92
#   schema_version: "1.0"
#   ears_source: EARS-02
#   scenario_count: 25
# ---

@brd:BRD-02 @prd:PRD-02 @ears:EARS-02
Feature: BDD-02: F2 Session Management
  As a platform component
  I need session and context management capabilities
  So that user state, memory, and workspaces are managed securely and efficiently

  Background:
    Given the system timezone is "America/New_York"
    And the Redis backend is available
    And the PostgreSQL backend is available
    And the F1 IAM service is operational

  # ============================================================================
  # PRIMARY SCENARIOS - Success Path (Event-Driven Requirements)
  # ============================================================================

  @primary @scenario-id:BDD.02.13.01 @ears:EARS.02.25.001
  Scenario: Session creation on successful authentication
    Given a user with user_id "user-12345" has authenticated successfully
    And the device fingerprint is "fp-abc123"
    And the geolocation is "40.7128,-74.0060"
    When the session service creates a new session
    Then a new session_id should be returned
    And the session should be stored in Redis backend
    And the idle timeout should be set to 30 minutes
      # @threshold:BRD.02.timing.session.idle
    And the device fingerprint "fp-abc123" should be tracked
    And the response time should be less than 10 milliseconds
      # @threshold:BRD.02.perf.session.create.p95

  @primary @scenario-id:BDD.02.13.02 @ears:EARS.02.25.002
  Scenario: Session lookup and validation
    Given an active session with session_id "sess-67890" exists
    And the session is not expired
    And the device fingerprint matches "fp-abc123"
    When the session_id "sess-67890" is presented for validation
    Then the session context should be returned
    And the session should be retrieved from Redis
    And the response time should be less than 10 milliseconds
      # @threshold:BRD.02.perf.session.lookup.p95

  @primary @scenario-id:BDD.02.13.03 @ears:EARS.02.25.003
  Scenario: Session refresh on user activity
    Given an active session with session_id "sess-67890" exists
    And the current idle time is 15 minutes
    When user activity is detected on the session
    Then the last_activity timestamp should be updated
    And the idle timeout should be reset to 30 minutes
      # @threshold:BRD.02.timing.session.idle
    And a "session.refreshed" event should be emitted to F3
    And an acknowledgment should be returned within 10 milliseconds
      # @threshold:BRD.02.perf.session.lookup.p95

  @primary @scenario-id:BDD.02.13.04 @ears:EARS.02.25.004
  Scenario: Session termination on user logout
    Given an active session with session_id "sess-67890" exists
    And the session has memory data stored
    When the user initiates logout
    Then the session should be invalidated
    And the session memory tier should be cleared
    And a "session.terminated" event should be emitted to F3
    And a confirmation should be returned within 50 milliseconds

  @primary @scenario-id:BDD.02.13.05 @ears:EARS.02.25.005
  Scenario: Session termination by administrator
    Given a user "user-12345" has 3 active sessions across devices
    And an administrator requests session termination for "user-12345"
    When the session service processes the admin revoke request
    Then all sessions for "user-12345" should be invalidated
    And a "session.admin_revoked" event should be emitted to F3
    And a confirmation should be returned within 1000 milliseconds
      # @threshold:BRD.02.perf.admin.revoke.p95

  @primary @scenario-id:BDD.02.13.06 @ears:EARS.02.25.006
  Scenario: Memory get operation from session layer
    Given an active session with session_id "sess-67890" exists
    And the session has memory data with key "user_preferences"
    And the caller owns the session
    When a memory read is requested for key "user_preferences"
    Then the memory value should be returned from Redis
    And the response time should be less than 5 milliseconds
      # @threshold:BRD.02.perf.memory.get.p95

  @primary @scenario-id:BDD.02.13.07 @ears:EARS.02.25.007
  Scenario: Memory set operation to session layer
    Given an active session with session_id "sess-67890" exists
    And the memory data size is 50KB
    When a memory write is requested for key "analysis_cache"
    Then the data should be validated against the 100KB limit
      # @threshold:BRD.02.limit.session.memory
    And the data should be stored in Redis with session TTL
    And a "memory.updated" event should be emitted to F3
    And an acknowledgment should be returned within 5 milliseconds
      # @threshold:BRD.02.perf.memory.set.p95

  @primary @scenario-id:BDD.02.13.08 @ears:EARS.02.25.010
  Scenario: Workspace creation
    Given a user "user-12345" has 10 existing workspaces
    When workspace creation is requested with name "Cost Analysis Q1"
    Then the workspace count should be validated against 50 limit
      # @threshold:BRD.02.limit.workspace.max_per_user
    And a workspace record should be created in PostgreSQL
    And default settings should be initialized
    And a "workspace.created" event should be emitted to F3
    And a workspace_id should be returned within 100 milliseconds

  @primary @scenario-id:BDD.02.13.09 @ears:EARS.02.25.011
  Scenario: Workspace switch
    Given a user "user-12345" has access to workspace "ws-54321"
    And the active session references workspace "ws-11111"
    When workspace switch to "ws-54321" is requested
    Then user access to target workspace should be validated
    And workspace data should be loaded from PostgreSQL
    And session active_workspace reference should be updated
    And a "workspace.switched" event should be emitted to F3
    And workspace data should be returned within 50 milliseconds
      # @threshold:BRD.02.perf.workspace.switch.p95

  @primary @scenario-id:BDD.02.13.10 @ears:EARS.02.25.013
  Scenario: Context assembly for agent target
    Given an active session for user "user-12345"
    And the user has profile data in F1 IAM
    And the session has memory data in Redis
    And the workspace has data in PostgreSQL
    When context is requested for agent target
    Then user profile should be fetched from F1 IAM
    And session memory should be retrieved from Redis
    And workspace memory should be retrieved from PostgreSQL
    And enriched context object should be assembled
    And context should be returned within 50 milliseconds
      # @threshold:BRD.02.perf.context.assembly.p95

  # ============================================================================
  # ALTERNATIVE SCENARIOS - Alternative Paths
  # ============================================================================

  @alternative @scenario-id:BDD.02.13.11 @ears:EARS.02.25.012
  Scenario: Workspace sharing mode change
    Given a user "user-12345" owns workspace "ws-54321"
    And the workspace sharing mode is "private"
    When workspace sharing to "shared" mode is requested for users "user-67890,user-11111"
    Then owner permissions should be validated
    And sharing mode should be updated to "shared"
    And access permissions should be created for target users
    And a "workspace.shared" event should be emitted to F3
    And a confirmation should be returned within 100 milliseconds

  @alternative @scenario-id:BDD.02.13.12 @ears:EARS.02.25.008
  Scenario: Memory promotion from session to workspace
    Given an active session with memory data "analysis_results"
    And a workspace "ws-54321" exists for the user
    When memory promotion from session to workspace is requested
    Then workspace existence should be validated
    And data should be copied to PostgreSQL workspace storage
    And data tier metadata should be updated
    And a "memory.promoted" event should be emitted to F3
    And a confirmation should be returned within 100 milliseconds

  @alternative @scenario-id:BDD.02.13.13 @ears:EARS.02.25.009
  Scenario: Memory promotion from workspace to profile
    Given a workspace with memory data "learning_preferences"
    And the user has A2A platform access
    When memory promotion to profile is requested
    Then A2A access should be validated
    And data should be sent to A2A Knowledge Platform
    And promotion status should be updated
    And a "memory.promoted_profile" event should be emitted to F3
    And a confirmation should be returned within 500 milliseconds

  @alternative @scenario-id:BDD.02.13.14 @ears:EARS.02.25.014
  Scenario: Context assembly for UI target
    Given an active session for user "user-12345"
    And the session has state data
    And the workspace "ws-54321" is active
    And the user has preferences configured
    When context is requested for UI target
    Then session state should be retrieved
    And active workspace data should be retrieved
    And user preferences should be retrieved
    And UI context object should be assembled
    And context should be returned within 50 milliseconds
      # @threshold:BRD.02.perf.context.assembly.p95

  # ============================================================================
  # NEGATIVE SCENARIOS - Error Conditions (Unwanted Behavior)
  # ============================================================================

  @negative @scenario-id:BDD.02.13.15 @ears:EARS.02.25.201
  Scenario: Session expiration on idle timeout
    Given an active session with session_id "sess-67890"
    And the session has been idle for 30 minutes
      # @threshold:BRD.02.timing.session.idle
    When the session is accessed
    Then the session should transition to EXPIRED state
    And the session memory tier should be cleared
    And a "session.expired" event should be emitted to F3
    And a "Session expired" message should be returned
    And the user should be redirected to login

  @negative @scenario-id:BDD.02.13.16 @ears:EARS.02.25.203
  Scenario: Workspace not found error
    Given a user "user-12345" requests workspace "ws-nonexistent"
    And the workspace does not exist
    When the workspace service processes the request
    Then a 404 Not Found response should be returned
    And the error should be logged to F3 with context
    And the error code should be included in response
    And no other workspace existence should be revealed

  @negative @scenario-id:BDD.02.13.17 @ears:EARS.02.25.205
  Scenario: Memory size limit exceeded
    Given an active session with 95KB of memory used
    And a memory write of 10KB is attempted
    When the memory service processes the write
    Then the write should be rejected with 400 Bad Request
    And a "Memory limit reached" message should be returned
    And a suggestion to promote to workspace tier should be included
    And a "memory.limit_exceeded" event should be emitted to F3

  @negative @scenario-id:BDD.02.13.18 @ears:EARS.02.25.207
  Scenario: Device anomaly detection response
    Given an active session with device fingerprint "fp-abc123"
    And the session geolocation is "40.7128,-74.0060"
    When a request arrives with fingerprint "fp-xyz789" from "51.5074,-0.1278"
    Then the session should be flagged for security review
    And re-authentication may be required based on severity
    And a "security.device_anomaly" event should be emitted to F3
    And anomaly details should be logged for audit

  # ============================================================================
  # EDGE CASE SCENARIOS - Boundary Conditions
  # ============================================================================

  @edge_case @scenario-id:BDD.02.13.19 @ears:EARS.02.25.104
  Scenario: Concurrent session limit enforcement
    Given a user "user-12345" has 3 active sessions
      # @threshold:BRD.02.limit.session.concurrent
    And a new authentication attempt occurs
    When session creation is requested
    Then the new session should be rejected
    And an option to terminate oldest session should be offered
    And a limit enforcement event should be logged

  @edge_case @scenario-id:BDD.02.13.20 @ears:EARS.02.25.105
  Scenario: Workspace count limit enforcement
    Given a user "user-12345" has 50 workspaces
      # @threshold:BRD.02.limit.workspace.max_per_user
    When workspace creation is requested
    Then the new workspace should be rejected
    And a suggestion to archive old workspaces should be provided
    And a limit enforcement event should be logged

  @edge_case @scenario-id:BDD.02.13.21 @ears:EARS.02.25.021
  Scenario: Memory expiration alerts
    Given an active session with 25 minutes idle time
    When the session approaches expiration at 5 minutes remaining
    Then a warning should be sent at 5 minutes before timeout
    And a final warning should be sent at 1 minute before timeout
    And an option to extend session should be included
    And a "memory.expiration_warning" event should be emitted to F3

  # ============================================================================
  # DATA-DRIVEN SCENARIOS - Parameterized Tests
  # ============================================================================

  @data_driven @scenario-id:BDD.02.13.22 @ears:EARS.02.25.001
  Scenario Outline: Session creation with various device types
    Given a user has authenticated successfully
    And the device type is "<device_type>"
    And the device fingerprint is "<fingerprint>"
    When the session service creates a new session
    Then a session should be created with device_id
    And the device fingerprint "<fingerprint>" should be tracked
    And a "device.tracked" event should be emitted

    Examples:
      | device_type | fingerprint      |
      | desktop     | fp-desktop-001   |
      | mobile      | fp-mobile-002    |
      | tablet      | fp-tablet-003    |
      | api_client  | fp-api-004       |

  @data_driven @scenario-id:BDD.02.13.23 @ears:EARS.02.25.012
  Scenario Outline: Workspace sharing modes
    Given a user owns workspace "ws-54321"
    When workspace sharing mode is changed to "<sharing_mode>"
    Then the workspace should have "<access_level>" access
    And "<event_type>" event should be emitted

    Examples:
      | sharing_mode | access_level | event_type       |
      | private      | owner_only   | workspace.shared |
      | shared       | invited      | workspace.shared |
      | public       | read_all     | workspace.shared |

  # ============================================================================
  # INTEGRATION SCENARIOS - External System Integration
  # ============================================================================

  @integration @scenario-id:BDD.02.13.24 @ears:EARS.02.25.206
  Scenario: F1 IAM unavailability during context assembly
    Given an active session for user "user-12345"
    And the F1 IAM service is unavailable
    And a cached user profile exists with 3 minute age
    When context is requested for agent target
    Then the cached user profile should be used (5min TTL)
    And partial context should be assembled
    And a "context.iam_unavailable" event should be emitted to F3
    And the response should be flagged as potentially stale

  @integration @scenario-id:BDD.02.13.25 @ears:EARS.02.25.017
  Scenario: Event emission to F3 Observability
    Given a session lifecycle event "session.created" occurs
    And the event has correlation_id "corr-12345"
    When the event service processes the event
    Then the event payload should be formatted correctly
    And the event should be published to F3 via message queue
    And the event should include type and correlation IDs
    And delivery should be confirmed within 10 milliseconds
      # @threshold:BRD.02.perf.event.emission.p95

  # ============================================================================
  # QUALITY ATTRIBUTE SCENARIOS - Performance/Security
  # ============================================================================

  @quality_attribute @performance @scenario-id:BDD.02.13.26
  Scenario: Session service performance under load
    Given the session service is handling concurrent requests
    When 500 session creation requests are processed per second
      # @threshold:EARS.02.05.02
    Then session creation p95 latency should be less than 10 milliseconds
      # @threshold:BRD.02.perf.session.create.p95
    And session lookup p95 latency should be less than 10 milliseconds
      # @threshold:BRD.02.perf.session.lookup.p95
    And memory get p95 latency should be less than 5 milliseconds
      # @threshold:BRD.02.perf.memory.get.p95

  @quality_attribute @security @scenario-id:BDD.02.13.27 @ears:EARS.02.25.401
  Scenario: Session token security
    Given a new session is being created
    When the session service generates a token
    Then the token should be UUID v4 format
    And the token should use cryptographic randomness
    And the token should be hashed before storage
    And the raw token should never appear in logs

  @quality_attribute @security @scenario-id:BDD.02.13.28 @ears:EARS.02.25.402
  Scenario: Memory encryption at rest
    Given memory data is being stored in Redis
    When the memory service persists the data
    Then the data should be encrypted with AES-256-GCM
    And encryption keys should be managed via F6 Infrastructure
    And key rotation should comply with requirements

  @quality_attribute @security @scenario-id:BDD.02.13.29 @ears:EARS.02.25.403
  Scenario: Workspace data isolation
    Given user "user-12345" owns workspace "ws-54321"
    And user "user-67890" attempts to access "ws-54321"
    When the workspace service validates access
    Then user isolation should be enforced
    And the access should be denied for "user-67890"
    And no data should cross tenant boundaries

  # ============================================================================
  # FAILURE RECOVERY SCENARIOS - Circuit Breaker/Resilience
  # ============================================================================

  @failure_recovery @scenario-id:BDD.02.13.30 @ears:EARS.02.25.202
  Scenario: Redis unavailability fallback
    Given the Redis service becomes unavailable
    And session operations are in progress
    When the storage service detects Redis failure
    Then PostgreSQL fallback should be activated within 5 seconds
    And session operations should be routed to PostgreSQL backend
    And a "storage.failover" event should be emitted to F3
    And Redis should resume when available

  @failure_recovery @scenario-id:BDD.02.13.31 @ears:EARS.02.25.204
  Scenario: Context assembly timeout handling
    Given context assembly is in progress
    And the context service experiences slow components
    When context assembly exceeds 50 milliseconds timeout
    Then partial context with available data should be returned
    And a "context.timeout_warning" event should be emitted to F3
    And a degradation indicator should be included in response
    And slow component details should be logged

  @failure_recovery @scenario-id:BDD.02.13.32 @ears:EARS.02.25.208
  Scenario: Workspace load failure with retry
    Given a workspace load request is in progress
    And the PostgreSQL connection is intermittent
    When the workspace service encounters a load failure
    Then retry should occur up to 3 times with exponential backoff
    And on final failure "Workspace unavailable" message should be returned
    And a "workspace.load_failed" event should be emitted to F3
    And failure details should be logged

  @failure_recovery @scenario-id:BDD.02.13.33 @ears:EARS.02.25.209
  Scenario: Memory promotion failure recovery
    Given memory promotion from session to workspace is in progress
    And the PostgreSQL write fails
    When the memory service handles the failure
    Then retry should occur with exponential backoff (3 attempts)
    And a "Save failed, retrying" message should be returned
    And a "memory.promotion_failed" event should be emitted to F3
    And original data should be preserved in source tier

  @failure_recovery @scenario-id:BDD.02.13.34 @ears:EARS.02.25.210
  Scenario: Session state recovery during Redis failover
    Given a Redis failover event occurs
    And session state is potentially lost
    When the session service detects state loss
    Then recovery should be attempted from PostgreSQL replica
    And the user should be notified of potential state loss
    And a "session.state_loss" event should be emitted to F3
    And graceful degradation mode should be triggered

  # ============================================================================
  # ADDITIONAL COVERAGE SCENARIOS
  # ============================================================================

  @primary @scenario-id:BDD.02.13.35 @ears:EARS.02.25.022
  Scenario: Administrator retrieves active session list
    Given an administrator requests the active session list
    And filter by user "user-12345" is specified
    When the session service retrieves active sessions
    Then all active sessions should be returned
    And each session should include device, user, and timestamp
    And sessions should be filtered by the specified user
    And the response should be returned within 100 milliseconds

  @primary @scenario-id:BDD.02.13.36 @ears:EARS.02.25.023
  Scenario: Service retrieves session via API
    Given a service "cost-analyzer" has valid authentication
    And session "sess-67890" exists
    When the service requests session via API with session_id "sess-67890"
    Then service authentication should be validated
    And session context should be retrieved
    And service-level access controls should be applied
    And session context should be returned within 10 milliseconds
      # @threshold:BRD.02.perf.session.lookup.p95

  @primary @scenario-id:BDD.02.13.37 @ears:EARS.02.25.020
  Scenario: Extensibility hook execution on lifecycle event
    Given hooks "audit_hook" and "analytics_hook" are registered for "session.created"
    And a session creation event triggers the hooks
    When the hook service executes registered hooks
    Then hooks should be executed in order
    And event context should be passed to each hook
    And hook results should be collected
    And each hook should complete within 10 milliseconds
      # @threshold:BRD.02.perf.hook.execution.p95
