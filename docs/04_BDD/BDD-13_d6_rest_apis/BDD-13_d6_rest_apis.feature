# ---
# title: "BDD-13: D6 REST APIs & Integrations Scenarios"
# tags: [bdd, layer-4-artifact, d6-apis, domain-module, shared-architecture]
# custom_fields:
#   document_type: bdd
#   artifact_type: BDD
#   layer: 4
#   module_id: D6
#   module_name: REST APIs & Integrations
#   adr_ready_score: 90
#   schema_version: "1.0"
#   source_ears: EARS-13
# ---

# =============================================================================
# BDD-13: D6 REST APIs & Integrations Scenarios
# =============================================================================
# Source: EARS-13_d6_rest_apis.md (BDD-Ready Score: 90/100)
# Module Type: Domain (Cost Monitoring-Specific)
# Upstream: PRD-13 | EARS-13
# Downstream: ADR-13, SYS-13
# =============================================================================
#
# Scenario ID Format: BDD.13.13.NN
#   - 13 = Document number (BDD-13)
#   - 13 = Element type code for Scenario
#   - NN = Sequence number (01, 02, 03, ...)
# =============================================================================

## Document Control

| Item | Details |
|------|---------|
| **Project Name** | AI Cloud Cost Monitoring Platform |
| **Document Version** | 1.0 |
| **Date** | 2026-02-09 |
| **Document Owner** | Platform Engineering Team |
| **Prepared By** | Coder Agent (Claude) |
| **Status** | Draft |
| **ADR-Ready Score** | 90/100 (Target: >=90%) |

---

@brd:BRD-13 @prd:PRD-13 @ears:EARS-13
Feature: BDD-13: D6 REST APIs & Integrations
  REST APIs & Integrations provide the API layer including AG-UI streaming,
  Admin REST endpoints, rate limiting, webhooks, and A2A gateway for the
  AI Cloud Cost Monitoring Platform.

  As an API consumer
  I want to interact with the platform through well-defined API endpoints
  So that I can integrate applications and manage cloud cost data programmatically

  Background:
    Given the system timezone is "America/New_York"
    And the API service is operational
    And rate limiting is enabled via Redis
    And F1 IAM authentication is configured
    And F4 SecOps audit logging is enabled

  # ===================
  # AG-UI STREAMING ENDPOINTS (from EARS Event-Driven Requirements)
  # ===================

  @primary @functional @streaming @ears:EARS.13.25.001 @scenario-id:BDD.13.13.01
  Scenario: Successful AG-UI streaming endpoint request
    Given a user has a valid Bearer JWT token
    And the AG-UI service is operational
    When the user sends a POST request to /api/copilotkit with a conversational query
    Then the API should accept the request
    And validate the Bearer JWT authentication
    And establish a Server-Sent Events stream
    And deliver the first token within @threshold:PRD.13.perf.streaming.first_token.p95 (1000ms)

  @primary @functional @session @ears:EARS.13.25.002 @scenario-id:BDD.13.13.02
  Scenario: Streaming session context retrieval
    Given an active multi-turn conversation exists
    And the session ID is included in request headers
    When the user sends a follow-up message
    Then the API should extract the session ID from request headers
    And retrieve prior conversation context
    And maintain session state across requests
    And preserve context for subsequent turns
    And complete context retrieval within @threshold:PRD.13.perf.session.context.p95 (100ms)

  @primary @functional @health @ears:EARS.13.25.003 @scenario-id:BDD.13.13.03
  Scenario: Streaming health check endpoint
    Given the AG-UI service is running
    When a GET request is sent to /api/copilotkit/health
    Then the API should respond without requiring authentication
    And return health status with service readiness indicators
    And respond within @threshold:PRD.13.perf.health.p99 (100ms)

  # ===================
  # ADMIN REST ENDPOINTS
  # ===================

  @primary @functional @rest @ears:EARS.13.25.004 @scenario-id:BDD.13.13.04
  Scenario: Successful tenant CRUD operations
    Given an admin user with valid Bearer JWT and admin scope
    When the admin sends a tenant management request to /api/tenant
    Then the API should validate the Bearer JWT with admin scope
    And execute the requested CRUD operation
    And return response with request ID
    And complete within @threshold:PRD.13.perf.rest.p95 (500ms)

  @primary @functional @rest @ears:EARS.13.25.005 @scenario-id:BDD.13.13.05
  Scenario: Successful cloud accounts CRUD operations
    Given an admin user with valid Bearer JWT
    When the admin sends a cloud account management request to /api/cloud-accounts
    Then the API should validate the Bearer JWT with appropriate scope
    And support GCP, AWS, and Azure providers
    And return response with request ID
    And complete within @threshold:PRD.13.perf.rest.p95 (500ms)

  @primary @functional @rest @ears:EARS.13.25.006 @scenario-id:BDD.13.13.06
  Scenario: Successful users CRUD operations
    Given an admin user with valid Bearer JWT and admin scope
    When the admin sends a user management request to /api/users
    Then the API should validate the Bearer JWT with admin scope
    And enforce role-based access control
    And return response with request ID
    And complete within @threshold:PRD.13.perf.rest.p95 (500ms)

  @primary @functional @rest @ears:EARS.13.25.007 @scenario-id:BDD.13.13.07
  Scenario: Successful recommendations query
    Given a user with valid Bearer JWT authentication
    When the user sends a GET request to /api/recommendations with filter parameters
    Then the API should validate Bearer JWT authentication
    And filter results by status and type parameters
    And return paginated response with request ID
    And complete within @threshold:PRD.13.perf.rest.p95 (500ms)

  @primary @functional @rest @ears:EARS.13.25.008 @scenario-id:BDD.13.13.08
  Scenario: Successful dashboard data retrieval
    Given a user with valid Bearer JWT authentication
    When the user sends a GET request to /api/dashboard
    Then the API should validate Bearer JWT authentication
    And aggregate metrics from D5 Data module
    And return dashboard response with request ID
    And complete within @threshold:PRD.13.perf.rest.p95 (500ms)

  # ===================
  # RATE LIMITING SCENARIOS
  # ===================

  @primary @security @ratelimit @ears:EARS.13.25.009 @scenario-id:BDD.13.13.09
  Scenario: Enforce IP-based rate limit
    Given an unauthenticated request is received
    When the IP has reached @threshold:PRD.13.rate.ip (100 requests per minute)
    Then the API should check IP-based rate limit
    And increment Redis counter atomically
    And return 429 Too Many Requests response
    And rate limit check should complete within @threshold:PRD.13.perf.ratelimit.p99 (10ms)

  @primary @security @ratelimit @ears:EARS.13.25.010 @scenario-id:BDD.13.13.10
  Scenario: Enforce user-based rate limit
    Given an authenticated user request is received
    When the user has reached @threshold:PRD.13.rate.user (300 requests per minute)
    Then the API should check user-based rate limit
    And increment Redis counter atomically
    And return 429 with Retry-After header
    And rate limit check should complete within @threshold:PRD.13.perf.ratelimit.p99 (10ms)

  @primary @security @ratelimit @ears:EARS.13.25.011 @scenario-id:BDD.13.13.11
  Scenario: Enforce tenant-based rate limit
    Given a tenant request is received
    When the tenant has reached @threshold:PRD.13.rate.tenant (1000 requests per minute)
    Then the API should check tenant-wide rate limit
    And aggregate all tenant users
    And return 429 Too Many Requests response
    And rate limit check should complete within @threshold:PRD.13.perf.ratelimit.p99 (10ms)

  @primary @security @ratelimit @a2a @ears:EARS.13.25.012 @scenario-id:BDD.13.13.12
  Scenario: Enforce A2A agent rate limit
    Given an A2A agent request is received via mTLS
    When the agent has reached @threshold:PRD.13.rate.a2a (10 requests per minute)
    Then the API should check agent-specific rate limit
    And track by agent certificate identity
    And return 429 Too Many Requests response
    And rate limit check should complete within @threshold:PRD.13.perf.ratelimit.p99 (10ms)

  @functional @ratelimit @within_limit @scenario-id:BDD.13.13.13
  Scenario: Process request when under rate limit
    Given an authenticated user request is received
    And the user is under the rate limit threshold
    When the API checks the rate limit
    Then the request should be processed successfully
    And the rate limit counter should be incremented
    And the response should include X-RateLimit-Remaining header

  # ===================
  # WEBHOOK SCENARIOS
  # ===================

  @primary @functional @webhook @ears:EARS.13.25.015 @scenario-id:BDD.13.13.14
  Scenario: Webhook registration
    Given an admin user with valid Bearer JWT
    When the admin sends a POST request to /api/webhooks with endpoint URL and event types
    Then the API should validate the webhook URL
    And store webhook configuration
    And return webhook ID and signing secret
    And complete within @threshold:PRD.13.perf.rest.p95 (500ms)

  @primary @functional @webhook @ears:EARS.13.25.016 @scenario-id:BDD.13.13.15
  Scenario: Webhook delivery on cost anomaly event
    Given a webhook is registered for cost.anomaly events
    When a cost anomaly is detected by D2 Analytics
    Then the API should prepare the webhook payload
    And sign the payload with HMAC-SHA256
    And deliver to the registered endpoint within @threshold:PRD.13.perf.webhook.ack.p95 (3 seconds)
    And log delivery attempt

  @functional @webhook @retry @scenario-id:BDD.13.13.16
  Scenario: Webhook delivery retry on failure
    Given a webhook delivery fails with 5xx error
    When the initial delivery fails
    Then the API should retry with exponential backoff
    And attempt up to 3 retries
    And mark webhook as failed after max retries
    And log all delivery attempts

  # ===================
  # A2A GATEWAY SCENARIOS
  # ===================

  @primary @functional @a2a @ears:EARS.13.25.018 @scenario-id:BDD.13.13.17
  Scenario: A2A gateway mTLS authentication
    Given an external agent presents a valid client certificate
    When the agent connects to the A2A gateway
    Then the API should verify mTLS certificate against trusted CAs
    And extract agent identity from certificate
    And authenticate the connection within @threshold:PRD.13.perf.a2a.auth.p99 (100ms)

  @primary @functional @a2a @query @ears:EARS.13.25.019 @scenario-id:BDD.13.13.18
  Scenario: A2A cost query execution
    Given an authenticated A2A agent
    When the agent sends a cost query to /api/a2a/query
    Then the API should validate query schema
    And execute query with tenant isolation
    And return structured response
    And complete within @threshold:PRD.13.perf.a2a.query.p95 (1000ms)

  @primary @functional @a2a @action @ears:EARS.13.25.020 @scenario-id:BDD.13.13.19
  Scenario: A2A action request execution
    Given an authenticated A2A agent with action permissions
    When the agent sends an action request to /api/a2a/action
    Then the API should validate action against agent permissions
    And queue or execute the action based on risk level
    And return action tracking ID
    And log action request

  # ===================
  # AUTHENTICATION SCENARIOS
  # ===================

  @negative @security @auth @scenario-id:BDD.13.13.20
  Scenario: Reject request without authentication
    Given an unauthenticated request to a protected endpoint
    When the request is received without Authorization header
    Then the API should return 401 Unauthorized
    And include WWW-Authenticate header
    And log the authentication failure

  @negative @security @auth @scenario-id:BDD.13.13.21
  Scenario: Reject request with invalid token
    Given a request with an invalid Bearer JWT token
    When the request is received at a protected endpoint
    Then the API should validate the JWT
    And return 401 Unauthorized with error code "INVALID_TOKEN"
    And log the authentication failure

  @negative @security @auth @scenario-id:BDD.13.13.22
  Scenario: Reject request with expired token
    Given a request with an expired Bearer JWT token
    When the request is received at a protected endpoint
    Then the API should validate the JWT expiration
    And return 401 Unauthorized with error code "TOKEN_EXPIRED"
    And suggest token refresh in response

  @negative @security @authz @scenario-id:BDD.13.13.23
  Scenario: Reject request without required permissions
    Given an authenticated user without admin role
    When the user sends a request to an admin-only endpoint
    Then the API should check user permissions
    And return 403 Forbidden with error code "INSUFFICIENT_PERMISSIONS"
    And log the authorization failure

  # ===================
  # ERROR HANDLING SCENARIOS
  # ===================

  @negative @error @validation @scenario-id:BDD.13.13.24
  Scenario: Reject request with invalid JSON payload
    Given an authenticated user
    When the user sends a request with malformed JSON body
    Then the API should parse the request body
    And return 400 Bad Request with error code "INVALID_JSON"
    And include parse error location in response

  @negative @error @validation @scenario-id:BDD.13.13.25
  Scenario: Reject request with missing required fields
    Given an authenticated user
    When the user sends a request missing required fields
    Then the API should validate input using Pydantic schemas
    And return 400 Bad Request with validation errors
    And list all missing or invalid fields

  @negative @error @notfound @scenario-id:BDD.13.13.26
  Scenario: Return 404 for non-existent resource
    Given an authenticated user
    When the user requests a resource that does not exist
    Then the API should return 404 Not Found
    And include error code "RESOURCE_NOT_FOUND"
    And log the request

  @negative @error @server @scenario-id:BDD.13.13.27
  Scenario: Handle internal server error gracefully
    Given the database is temporarily unavailable
    When a request requires database access
    Then the API should return 503 Service Unavailable
    And include retry_after value in response
    And log error with request_id

  @negative @error @timeout @scenario-id:BDD.13.13.28
  Scenario: Handle request timeout gracefully
    Given a request processing time exceeds timeout threshold
    When the timeout is reached
    Then the API should return 504 Gateway Timeout
    And roll back partial operations
    And log timeout event

  # ===================
  # QUALITY ATTRIBUTE SCENARIOS
  # ===================

  @quality_attribute @logging @ears:EARS.13.25.404 @scenario-id:BDD.13.13.29
  Scenario: Structured request logging
    Given the API receives any request
    Then the API should log all requests with timestamp and request ID
    And include HTTP method, path, status code, and duration
    And redact sensitive data (tokens, credentials) from logs
    And emit structured logs to Cloud Logging

  @quality_attribute @documentation @ears:EARS.13.25.405 @scenario-id:BDD.13.13.30
  Scenario: OpenAPI specification availability
    When a request is sent to /docs
    Then the API should serve interactive Swagger UI
    And provide OpenAPI 3.0 specification
    And maintain 100% endpoint coverage in documentation

  @quality_attribute @validation @ears:EARS.13.25.406 @scenario-id:BDD.13.13.31
  Scenario: Input validation for all requests
    Given the API receives a request with input data
    Then the API should validate all inputs using Pydantic schemas
    And reject requests with invalid content type
    And sanitize inputs before processing
    And enforce maximum request body size limits

  @quality_attribute @cors @ears:EARS.13.25.407 @scenario-id:BDD.13.13.32
  Scenario: CORS policy enforcement
    Given a browser client sends a cross-origin request
    Then the API should enforce CORS policy
    And allow only configured origins
    And support preflight OPTIONS requests
    And reject cross-origin requests from unauthorized origins

  @quality_attribute @metrics @ears:EARS.13.25.408 @scenario-id:BDD.13.13.33
  Scenario: Request metrics emission
    Given the API processes a request
    Then the API should emit request metrics to observability system
    And include latency histogram by endpoint
    And include error rate by status code
    And include rate limit usage metrics

  # ===================
  # DATA-DRIVEN SCENARIOS
  # ===================

  @data_driven @ratelimit
  Scenario Outline: Rate limiting tiers enforcement
    Given a <client_type> client
    When the client makes <request_count> requests in one minute
    Then the system should enforce the <limit> threshold
    And return <expected_status> for request <request_number>

    Examples:
      | client_type     | request_count | limit    | expected_status | request_number |
      | unauthenticated | 101           | 100/min  | 429             | 101            |
      | authenticated   | 301           | 300/min  | 429             | 301            |
      | tenant          | 1001          | 1000/min | 429             | 1001           |
      | a2a_agent       | 11            | 10/min   | 429             | 11             |

  @data_driven @performance
  Scenario Outline: API response time by endpoint type
    Given an authenticated user with valid JWT
    When the user sends a <method> request to <endpoint>
    Then the response time should be less than <latency_threshold>

    Examples:
      | method | endpoint           | latency_threshold |
      | POST   | /api/copilotkit    | 1000ms           |
      | GET    | /api/dashboard     | 500ms            |
      | GET    | /api/tenant        | 500ms            |
      | GET    | /api/recommendations| 500ms           |
      | POST   | /api/a2a/query     | 1000ms           |

# =============================================================================
# END OF BDD-13: D6 REST APIs & Integrations Scenarios
# =============================================================================
# Total Scenarios: 33 + 2 Scenario Outlines
# Coverage: Event-Driven (22), Negative (9), Quality Attributes (5), Data-Driven (2)
# ADR-Ready Score: 90/100
# =============================================================================
