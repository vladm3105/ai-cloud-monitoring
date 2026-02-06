# AI Cost Monitoring - Architecture Review & Recommendations

## Executive Summary

This document provides a comprehensive review of the AI Cost Monitoring platform architecture, with specific focus on **performance optimization** and **security hardening**. The review identifies gaps in the current design and provides actionable recommendations.

---

## 1. PERFORMANCE REVIEW

### 1.1 Current Architecture Strengths ✅

| Aspect | Implementation | Status |
|--------|---------------|--------|
| Parallel Cloud Queries | Cloud Agents execute in parallel | ✅ Good |
| Agent Hierarchy | 4-layer design reduces complexity | ✅ Good |
| 1:1 MCP Mapping | Each Cloud Agent owns its MCP | ✅ Good |
| Time-Series DB | TimescaleDB for metrics | ✅ Good |

### 1.2 Performance Gaps & Recommendations 🔴

#### 1.2.1 **Missing: Connection Pooling Strategy**

**Problem:** Each MCP server creates new connections to cloud APIs per request.

**Recommendation:**
```
┌─────────────────────────────────────────────────────────┐
│  MCP Server Connection Pool Configuration               │
├─────────────────────────────────────────────────────────┤
│  AWS MCP:                                               │
│    - boto3 session reuse with credential refresh        │
│    - Max concurrent connections: 50 per tenant          │
│    - Connection timeout: 30s                            │
│    - Retry with exponential backoff: 3 attempts         │
│                                                         │
│  Azure MCP:                                             │
│    - azure.identity.DefaultAzureCredential caching      │
│    - Token refresh before expiry (5 min buffer)         │
│    - Max concurrent connections: 50 per tenant          │
│                                                         │
│  GCP MCP:                                               │
│    - google.auth credentials with auto-refresh          │
│    - Connection pooling via httplib2                    │
│    - Max concurrent connections: 50 per tenant          │
└─────────────────────────────────────────────────────────┘
```

#### 1.2.2 **Missing: Multi-Level Caching Strategy**

**Problem:** No explicit caching layer defined. Cloud API calls are expensive and rate-limited.

**Recommendation:**
```
┌─────────────────────────────────────────────────────────┐
│  3-Tier Caching Architecture                            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  L1: In-Memory Cache (per Cloud Agent)                  │
│      ├── TTL: 60 seconds                                │
│      ├── Use: Hot data (current costs, active alerts)   │
│      └── Implementation: Python lru_cache / cachetools  │
│                                                         │
│  L2: Redis Cache (shared across agents)                 │
│      ├── TTL: 5-15 minutes (configurable per data type) │
│      ├── Use: Cost data, recommendations, resources     │
│      ├── Key pattern: tenant:{id}:cloud:{provider}:*    │
│      └── Invalidation: On data refresh or manual purge  │
│                                                         │
│  L3: TimescaleDB (persistent)                           │
│      ├── TTL: Based on retention policy                 │
│      ├── Use: Historical data, trend analysis           │
│      └── Compression: After 7 days                      │
│                                                         │
│  Cache-Aside Pattern:                                   │
│      1. Check L1 → 2. Check L2 → 3. Query Cloud API     │
│      4. Populate L2 → 5. Populate L1 → 6. Return        │
└─────────────────────────────────────────────────────────┘
```

**Cache TTL by Data Type:**
| Data Type | L1 TTL | L2 TTL | Rationale |
|-----------|--------|--------|-----------|
| Real-time costs | 60s | 5 min | Frequent access, moderate freshness |
| Recommendations | 5 min | 30 min | Changes slowly |
| Resource inventory | 2 min | 15 min | Moderate change rate |
| Historical costs | N/A | 1 hour | Static data |
| Anomalies | 30s | 2 min | Time-sensitive |

#### 1.2.3 **Missing: Rate Limiting & Throttling**

**Problem:** Cloud APIs have strict rate limits. No protection against exceeding them.

**Recommendation:**
```
┌─────────────────────────────────────────────────────────┐
│  Rate Limiting Strategy                                 │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Per-Cloud Rate Limits (requests/second):               │
│  ┌─────────────┬────────────┬─────────────────────────┐ │
│  │ Cloud       │ API Limit  │ Our Limit (80% buffer)  │ │
│  ├─────────────┼────────────┼─────────────────────────┤ │
│  │ AWS CE      │ 5 req/s    │ 4 req/s per tenant      │ │
│  │ Azure CM    │ 30 req/min │ 24 req/min per tenant   │ │
│  │ GCP Billing │ 60 req/min │ 48 req/min per tenant   │ │
│  │ OpenCost    │ 100 req/s  │ 80 req/s per tenant     │ │
│  └─────────────┴────────────┴─────────────────────────┘ │
│                                                         │
│  Implementation: Token Bucket Algorithm                 │
│  - Redis-based distributed rate limiter                 │
│  - Key: ratelimit:tenant:{id}:cloud:{provider}          │
│  - Overflow handling: Queue with priority               │
│                                                         │
│  Per-Tenant Quotas:                                     │
│  - Free tier: 100 queries/hour                          │
│  - Pro tier: 1000 queries/hour                          │
│  - Enterprise: Unlimited (fair use policy)              │
└─────────────────────────────────────────────────────────┘
```

#### 1.2.4 **Missing: Query Optimization for Large Tenants**

**Problem:** Large enterprises may have 1000+ cloud accounts. Current design doesn't handle pagination or streaming.

**Recommendation:**
```
┌─────────────────────────────────────────────────────────┐
│  Large Tenant Query Optimization                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. Pagination Strategy:                                │
│     - Default page size: 100 accounts                   │
│     - Max page size: 500 accounts                       │
│     - Cursor-based pagination (not offset)              │
│                                                         │
│  2. Streaming for Large Results:                        │
│     - Use SSE for results > 1000 items                  │
│     - Progressive rendering in A2UI components          │
│     - "Load more" pattern for tables                    │
│                                                         │
│  3. Background Aggregation:                             │
│     - Pre-compute daily/weekly/monthly rollups          │
│     - Store in materialized views                       │
│     - Refresh via scheduled Celery tasks                │
│                                                         │
│  4. Query Parallelization:                              │
│     - Shard queries by account groups                   │
│     - Parallel execution with asyncio.gather()          │
│     - Merge results in Cloud Agent                      │
└─────────────────────────────────────────────────────────┘
```

#### 1.2.5 **Missing: Agent Response Timeout Strategy**

**Problem:** No defined timeouts. Slow cloud APIs could block entire request chain.

**Recommendation:**
```
┌─────────────────────────────────────────────────────────┐
│  Timeout Hierarchy                                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  User Request (AG-UI Server)                            │
│  └── Total timeout: 60 seconds                          │
│      │                                                  │
│      ├── Coordinator Agent                              │
│      │   └── Timeout: 55 seconds                        │
│      │       │                                          │
│      │       ├── Domain Agent                           │
│      │       │   └── Timeout: 50 seconds                │
│      │       │       │                                  │
│      │       │       └── Cloud Agent (parallel)         │
│      │       │           └── Timeout: 30 seconds each   │
│      │       │               │                          │
│      │       │               └── MCP Server             │
│      │       │                   └── Timeout: 25 sec    │
│      │       │                       │                  │
│      │       │                       └── Cloud API      │
│      │       │                           └── 20 sec     │
│                                                         │
│  Timeout Handling:                                      │
│  - Return partial results if some clouds succeed        │
│  - Mark failed clouds with error status                 │
│  - Log timeout for monitoring/alerting                  │
└─────────────────────────────────────────────────────────┘
```

#### 1.2.6 **Missing: Circuit Breaker Pattern**

**Problem:** If a cloud provider is down, repeated failures waste resources.

**Recommendation:**
```
┌─────────────────────────────────────────────────────────┐
│  Circuit Breaker Configuration (per Cloud Agent)        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  States:                                                │
│  ┌─────────┐    5 failures    ┌─────────┐              │
│  │ CLOSED  │ ───────────────► │  OPEN   │              │
│  │ (normal)│                  │ (fail)  │              │
│  └────┬────┘                  └────┬────┘              │
│       │                            │                    │
│       │         30 sec timeout     │                    │
│       │       ┌─────────────┐      │                    │
│       └────── │ HALF-OPEN   │ ◄────┘                    │
│   success     │  (testing)  │                           │
│               └─────────────┘                           │
│                                                         │
│  Configuration:                                         │
│  - Failure threshold: 5 consecutive failures            │
│  - Recovery timeout: 30 seconds                         │
│  - Half-open max requests: 3                            │
│  - Implementation: pybreaker or custom                  │
│                                                         │
│  Fallback Strategy:                                     │
│  - Return cached data (if available)                    │
│  - Return "service unavailable" status                  │
│  - Alert operations team                                │
└─────────────────────────────────────────────────────────┘
```

#### 1.2.7 **Missing: Database Query Optimization**

**Problem:** Complex multi-tenant queries could be slow without proper indexing.

**Recommendation:**
```sql
-- Essential Indexes for Performance

-- Cost metrics (TimescaleDB hypertable)
CREATE INDEX idx_cost_metrics_tenant_time 
ON cost_metrics (tenant_id, time DESC);

CREATE INDEX idx_cost_metrics_tenant_provider_time 
ON cost_metrics (tenant_id, cloud_provider, time DESC);

-- Recommendations table
CREATE INDEX idx_recommendations_tenant_status 
ON recommendations (tenant_id, status) 
WHERE status = 'pending';

CREATE INDEX idx_recommendations_tenant_savings 
ON recommendations (tenant_id, estimated_savings_monthly DESC);

-- Resources table
CREATE INDEX idx_resources_tenant_provider_type 
ON resources (tenant_id, cloud_provider, resource_type);

CREATE INDEX idx_resources_tenant_idle 
ON resources (tenant_id) 
WHERE is_idle = true;

-- Partitioning Strategy
-- Partition cost_metrics by month for faster queries
SELECT create_hypertable('cost_metrics', 'time', 
  chunk_time_interval => INTERVAL '1 month');

-- Row-Level Security (already planned, ensure indexes support it)
CREATE POLICY tenant_isolation ON cost_metrics
  FOR ALL TO app_user
  USING (tenant_id = current_setting('app.current_tenant')::uuid);
```

---

## 2. SECURITY REVIEW

### 2.1 Current Security Strengths ✅

| Aspect | Implementation | Status |
|--------|---------------|--------|
| Authentication | Auth0 (OAuth 2.0/OIDC) | ✅ Good |
| Secrets Management | OpenBao per-tenant | ✅ Good |
| Multi-Tenant Isolation | RLS, namespacing | ✅ Good |
| RBAC | Role-based permissions | ✅ Good |

### 2.2 Security Gaps & Recommendations 🔴

#### 2.2.1 **Missing: API Gateway Security Layer**

**Problem:** No centralized API security before AG-UI Server.

**Recommendation:**
```
┌─────────────────────────────────────────────────────────┐
│  API Gateway Security Layer                             │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Add API Gateway (Kong / AWS API Gateway / Envoy):      │
│                                                         │
│  ┌─────────┐    ┌─────────────┐    ┌──────────────┐    │
│  │ Client  │───►│ API Gateway │───►│ AG-UI Server │    │
│  └─────────┘    └─────────────┘    └──────────────┘    │
│                       │                                 │
│                       ▼                                 │
│              ┌─────────────────┐                        │
│              │ Security Checks │                        │
│              ├─────────────────┤                        │
│              │ • Rate limiting │                        │
│              │ • DDoS protect  │                        │
│              │ • WAF rules     │                        │
│              │ • IP allowlist  │                        │
│              │ • Request size  │                        │
│              │ • SSL terminate │                        │
│              └─────────────────┘                        │
│                                                         │
│  WAF Rules:                                             │
│  - Block SQL injection patterns                         │
│  - Block XSS attempts                                   │
│  - Block path traversal                                 │
│  - Rate limit by IP: 100 req/min                        │
│  - Rate limit by tenant: 1000 req/min                   │
│  - Max request body: 1MB                                │
│  - Max header size: 8KB                                 │
└─────────────────────────────────────────────────────────┘
```

#### 2.2.2 **Missing: Input Validation & Sanitization**

**Problem:** LLM-generated queries could be manipulated. No explicit input validation layer.

**Recommendation:**
```
┌─────────────────────────────────────────────────────────┐
│  Input Validation Strategy                              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. User Input Validation (AG-UI Server):               │
│     ┌─────────────────────────────────────────────────┐ │
│     │ • Max query length: 2000 characters             │ │
│     │ • Allowed characters: alphanumeric + whitespace │ │
│     │ • No code/script injection                      │ │
│     │ • Sanitize HTML entities                        │ │
│     │ • Validate date ranges (max 1 year span)        │ │
│     │ • Validate account IDs against tenant's list    │ │
│     └─────────────────────────────────────────────────┘ │
│                                                         │
│  2. Agent Tool Input Validation:                        │
│     ┌─────────────────────────────────────────────────┐ │
│     │ # Pydantic models for all tool inputs           │ │
│     │ class CostQueryInput(BaseModel):                │ │
│     │     tenant_id: UUID                             │ │
│     │     start_date: date                            │ │
│     │     end_date: date                              │ │
│     │     cloud_provider: Literal["aws","azure","gcp"]│ │
│     │     account_ids: list[str] = Field(max_items=100)│
│     │                                                 │ │
│     │     @validator('end_date')                      │ │
│     │     def validate_date_range(cls, v, values):    │ │
│     │         if v - values['start_date'] > 365 days: │ │
│     │             raise ValueError("Max 1 year")      │ │
│     │         return v                                │ │
│     └─────────────────────────────────────────────────┘ │
│                                                         │
│  3. MCP Tool Output Validation:                         │
│     - Validate response schema before returning         │
│     - Strip sensitive fields (credentials, tokens)      │
│     - Limit response size (max 5MB)                     │
└─────────────────────────────────────────────────────────┘
```

#### 2.2.3 **Missing: Prompt Injection Protection**

**Problem:** Users could attempt to manipulate agent behavior via crafted inputs.

**Recommendation:**
```
┌─────────────────────────────────────────────────────────┐
│  Prompt Injection Defense                               │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. Input Preprocessing:                                │
│     - Detect and flag suspicious patterns:              │
│       • "ignore previous instructions"                  │
│       • "you are now..."                                │
│       • "system prompt:"                                │
│       • Base64 encoded commands                         │
│       • Unicode homoglyph attacks                       │
│                                                         │
│  2. Prompt Structure (Coordinator Agent):               │
│     ┌─────────────────────────────────────────────────┐ │
│     │ SYSTEM: [hardcoded, never from user input]      │ │
│     │ ───────────────────────────────────────────     │ │
│     │ CONTEXT: tenant_id={id}, role={role}            │ │
│     │ ───────────────────────────────────────────     │ │
│     │ USER QUERY (sanitized): {user_input}            │ │
│     │ ───────────────────────────────────────────     │ │
│     │ AVAILABLE TOOLS: [restricted by role]           │ │
│     └─────────────────────────────────────────────────┘ │
│                                                         │
│  3. Output Filtering:                                   │
│     - Never expose system prompts in responses          │
│     - Filter internal IDs, paths, credentials           │
│     - Detect and block data exfiltration attempts       │
│                                                         │
│  4. Behavioral Guardrails:                              │
│     - Agent can only call tools from approved list      │
│     - Tool calls must match declared intent             │
│     - Anomaly detection on tool call patterns           │
└─────────────────────────────────────────────────────────┘
```

#### 2.2.4 **Missing: Audit Logging Enhancement**

**Problem:** Current audit log design lacks detail for security forensics.

**Recommendation:**
```
┌─────────────────────────────────────────────────────────┐
│  Enhanced Audit Log Schema                              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  {                                                      │
│    "event_id": "uuid",                                  │
│    "timestamp": "2026-01-31T15:30:00Z",                 │
│    "event_type": "TOOL_EXECUTION",                      │
│                                                         │
│    // WHO                                               │
│    "actor": {                                           │
│      "user_id": "auth0|user123",                        │
│      "tenant_id": "org_acme_corp",                      │
│      "roles": ["analyst"],                              │
│      "ip_address": "192.168.1.100",                     │
│      "user_agent": "Mozilla/5.0...",                    │
│      "session_id": "sess_abc123"                        │
│    },                                                   │
│                                                         │
│    // WHAT                                              │
│    "action": {                                          │
│      "agent": "cost_agent",                             │
│      "tool": "get_aws_cost_and_usage",                  │
│      "intent": "COST_QUERY",                            │
│      "parameters": {                                    │
│        "start_date": "2026-01-01",                      │
│        "end_date": "2026-01-31",                        │
│        "account_ids": ["123456789012"]                  │
│      }                                                  │
│    },                                                   │
│                                                         │
│    // RESULT                                            │
│    "outcome": {                                         │
│      "status": "success",                               │
│      "duration_ms": 1250,                               │
│      "records_returned": 150,                           │
│      "error_code": null                                 │
│    },                                                   │
│                                                         │
│    // SECURITY FLAGS                                    │
│    "security": {                                        │
│      "permission_used": "read:costs",                   │
│      "data_classification": "confidential",             │
│      "cross_tenant_access": false,                      │
│      "sensitive_data_accessed": false                   │
│    }                                                    │
│  }                                                      │
│                                                         │
│  Retention: 7 years (compliance requirement)            │
│  Storage: Immutable append-only log (S3 + Glacier)      │
│  Real-time: Stream to SIEM (Splunk/Datadog)             │
└─────────────────────────────────────────────────────────┘
```

#### 2.2.5 **Missing: Credential Rotation & Least Privilege**

**Problem:** OpenBao stores credentials, but no rotation policy or least privilege enforcement.

**Recommendation:**
```
┌─────────────────────────────────────────────────────────┐
│  Credential Management Policy                           │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. Automatic Rotation Schedule:                        │
│     ┌──────────────┬────────────────┬────────────────┐  │
│     │ Credential   │ Rotation       │ Method         │  │
│     ├──────────────┼────────────────┼────────────────┤  │
│     │ AWS IAM Keys │ 90 days        │ OpenBao auto   │  │
│     │ Azure SP     │ 90 days        │ OpenBao auto   │  │
│     │ GCP SA Keys  │ 90 days        │ OpenBao auto   │  │
│     │ K8s Tokens   │ 24 hours       │ Short-lived    │  │
│     │ API Keys     │ 30 days        │ Manual + alert │  │
│     └──────────────┴────────────────┴────────────────┘  │
│                                                         │
│  2. Least Privilege IAM Policies:                       │
│                                                         │
│     AWS (example):                                      │
│     {                                                   │
│       "Effect": "Allow",                                │
│       "Action": [                                       │
│         "ce:GetCostAndUsage",      // Cost Explorer    │
│         "ce:GetCostForecast",                          │
│         "ce:GetAnomalies",                             │
│         "compute-optimizer:Get*",  // Read-only        │
│         "cloudwatch:GetMetricData" // Metrics only     │
│       ],                                                │
│       "Resource": "*",                                  │
│       "Condition": {                                    │
│         "StringEquals": {                               │
│           "aws:RequestedRegion": ["us-east-1","eu-*"]  │
│         }                                               │
│       }                                                 │
│     }                                                   │
│                                                         │
│     // DENY dangerous actions                           │
│     {                                                   │
│       "Effect": "Deny",                                 │
│       "Action": [                                       │
│         "ec2:TerminateInstances",                       │
│         "rds:DeleteDBInstance",                         │
│         "s3:DeleteBucket"                               │
│       ],                                                │
│       "Resource": "*"                                   │
│     }                                                   │
│                                                         │
│  3. Dynamic Credentials (preferred over static):        │
│     - AWS: Use AssumeRole with external ID              │
│     - Azure: Use Managed Identity where possible        │
│     - GCP: Use Workload Identity Federation             │
└─────────────────────────────────────────────────────────┘
```

#### 2.2.6 **Missing: Network Security**

**Problem:** No explicit network segmentation or encryption in transit between components.

**Recommendation:**
```
┌─────────────────────────────────────────────────────────┐
│  Network Security Architecture                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │                   PUBLIC ZONE                    │    │
│  │  ┌─────────────┐    ┌─────────────┐             │    │
│  │  │ CloudFlare  │───►│ API Gateway │             │    │
│  │  │ (WAF+DDoS)  │    │ (Kong/Envoy)│             │    │
│  │  └─────────────┘    └──────┬──────┘             │    │
│  └────────────────────────────┼─────────────────────┘    │
│                               │ mTLS                     │
│  ┌────────────────────────────▼─────────────────────┐    │
│  │                 APPLICATION ZONE                  │    │
│  │  ┌─────────────┐    ┌─────────────┐              │    │
│  │  │ AG-UI Server│◄──►│   Agents    │              │    │
│  │  └──────┬──────┘    └──────┬──────┘              │    │
│  │         │                  │                      │    │
│  │         │    ┌─────────────┴──────────┐          │    │
│  │         │    │      MCP Servers       │          │    │
│  │         │    └────────────────────────┘          │    │
│  └─────────┼────────────────────────────────────────┘    │
│            │ mTLS                                         │
│  ┌─────────▼────────────────────────────────────────┐    │
│  │                   DATA ZONE                       │    │
│  │  ┌──────────┐  ┌───────┐  ┌─────────┐           │    │
│  │  │PostgreSQL│  │ Redis │  │ OpenBao │           │    │
│  │  │(encrypted)│  │(TLS)  │  │ (TLS)   │           │    │
│  │  └──────────┘  └───────┘  └─────────┘           │    │
│  └──────────────────────────────────────────────────┘    │
│                                                          │
│  Encryption Requirements:                                │
│  - All internal communication: mTLS                      │
│  - Database: TLS 1.3 + encryption at rest (AES-256)      │
│  - Redis: TLS + AUTH                                     │
│  - OpenBao: TLS + auto-unseal with cloud KMS             │
│  - Cloud API calls: HTTPS only                           │
└──────────────────────────────────────────────────────────┘
```

#### 2.2.7 **Missing: Security Monitoring & Alerting**

**Problem:** No security event detection or alerting defined.

**Recommendation:**
```
┌─────────────────────────────────────────────────────────┐
│  Security Monitoring Rules                              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Real-time Alerts (PagerDuty/Slack):                    │
│  ┌─────────────────────────────────────────────────────┐│
│  │ CRITICAL:                                           ││
│  │ • Failed auth attempts > 10/min from same IP        ││
│  │ • Cross-tenant data access attempt                  ││
│  │ • Credential rotation failure                       ││
│  │ • OpenBao seal event                                ││
│  │ • Admin role assignment                             ││
│  │ • Remediation action on production resource         ││
│  │                                                     ││
│  │ HIGH:                                               ││
│  │ • Unusual query patterns (anomaly detection)        ││
│  │ • API rate limit exceeded                           ││
│  │ • Failed MCP authentication                         ││
│  │ • New IP address for existing user                  ││
│  │                                                     ││
│  │ MEDIUM:                                             ││
│  │ • Permission denied events > 5/hour                 ││
│  │ • Large data export (> 10K records)                 ││
│  │ • Off-hours admin activity                          ││
│  └─────────────────────────────────────────────────────┘│
│                                                         │
│  Security Dashboards:                                   │
│  • Auth failures by tenant/user/IP                      │
│  • Permission usage heatmap                             │
│  • Credential age and rotation status                   │
│  • Cross-tenant access attempts (should be zero)        │
│  • Agent tool call anomalies                            │
└─────────────────────────────────────────────────────────┘
```

#### 2.2.8 **Missing: A2A Security Hardening**

**Problem:** A2A Gateway allows external agents but security controls are undefined.

**Recommendation:**
```
┌─────────────────────────────────────────────────────────┐
│  A2A Security Model                                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. Agent Registration & Approval:                      │
│     - External agents must be pre-registered            │
│     - Manual approval by tenant admin                   │
│     - Agent capabilities whitelist                      │
│                                                         │
│  2. Authentication:                                     │
│     ┌─────────────────────────────────────────────────┐ │
│     │ Option A: mTLS (preferred for internal agents)  │ │
│     │ - Each agent has unique certificate             │ │
│     │ - Certificate pinning                           │ │
│     │ - Short-lived certs (30 days)                   │ │
│     │                                                 │ │
│     │ Option B: API Key + HMAC (external agents)      │ │
│     │ - API key identifies agent                      │ │
│     │ - HMAC signature on request body                │ │
│     │ - Timestamp to prevent replay attacks           │ │
│     └─────────────────────────────────────────────────┘ │
│                                                         │
│  3. Authorization:                                      │
│     - Scoped permissions per agent:                     │
│       • SlackBot: read:costs, read:recommendations      │
│       • ComplianceAuditor: read:policies, read:audit    │
│       • Advisor: read:costs, read:recommendations       │
│     - No external agent gets write/execute permissions  │
│                                                         │
│  4. Tenant Context Preservation:                        │
│     - External agents cannot specify tenant_id          │
│     - Tenant determined by agent registration           │
│     - Cross-tenant queries always denied                │
│                                                         │
│  5. Rate Limiting:                                      │
│     - Per-agent rate limits (stricter than users)       │
│     - Default: 10 req/min per external agent            │
└─────────────────────────────────────────────────────────┘
```

---

## 3. ADDITIONAL RECOMMENDATIONS

### 3.1 Observability Enhancements

```
┌─────────────────────────────────────────────────────────┐
│  Observability Stack                                    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Metrics (Prometheus + Grafana):                        │
│  • Agent response times (p50, p95, p99)                 │
│  • MCP call latencies by cloud provider                 │
│  • Cache hit/miss ratios                                │
│  • Error rates by component                             │
│  • Active users/tenants                                 │
│                                                         │
│  Tracing (OpenTelemetry + Jaeger):                      │
│  • End-to-end request tracing                           │
│  • Trace ID propagation through all layers              │
│  • Span annotations for debugging                       │
│                                                         │
│  Logging (ELK / Loki):                                  │
│  • Structured JSON logs                                 │
│  • Correlation IDs                                      │
│  • Log levels: DEBUG (dev), INFO (prod)                 │
│                                                         │
│  Dashboards:                                            │
│  • System health overview                               │
│  • Per-tenant usage metrics                             │
│  • Agent performance comparison                         │
│  • Cloud provider availability                          │
└─────────────────────────────────────────────────────────┘
```

### 3.2 Disaster Recovery

```
┌─────────────────────────────────────────────────────────┐
│  Disaster Recovery Plan                                 │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  RPO (Recovery Point Objective): 1 hour                 │
│  RTO (Recovery Time Objective): 4 hours                 │
│                                                         │
│  Backup Strategy:                                       │
│  • PostgreSQL: Continuous WAL archiving to S3           │
│  • TimescaleDB: Daily snapshots + continuous backup     │
│  • Redis: AOF persistence + hourly RDB snapshots        │
│  • OpenBao: Auto-unseal keys in separate region         │
│                                                         │
│  Multi-Region Deployment (future):                      │
│  • Active-passive in separate cloud regions             │
│  • DNS failover with health checks                      │
│  • Data replication lag < 5 minutes                     │
└─────────────────────────────────────────────────────────┘
```

---

## 4. IMPLEMENTATION PRIORITY

### Phase 1: Critical (Before Launch)
| Item | Category | Effort | Impact |
|------|----------|--------|--------|
| API Gateway + WAF | Security | 2 weeks | Critical |
| Input Validation | Security | 1 week | Critical |
| Multi-Level Caching | Performance | 2 weeks | High |
| Rate Limiting | Both | 1 week | High |
| Circuit Breaker | Performance | 1 week | High |

### Phase 2: High Priority (Month 1-2)
| Item | Category | Effort | Impact |
|------|----------|--------|--------|
| Enhanced Audit Logging | Security | 2 weeks | High |
| Network Segmentation | Security | 2 weeks | High |
| Query Optimization | Performance | 2 weeks | Medium |
| Prompt Injection Defense | Security | 1 week | High |

### Phase 3: Medium Priority (Month 3-4)
| Item | Category | Effort | Impact |
|------|----------|--------|--------|
| A2A Security Hardening | Security | 2 weeks | Medium |
| Security Monitoring | Security | 2 weeks | Medium |
| Observability Stack | Operations | 3 weeks | Medium |
| Credential Rotation | Security | 1 week | Medium |

---

## 5. SUMMARY

### Performance Improvements Needed:
1. ✅ Connection pooling for cloud APIs
2. ✅ 3-tier caching (L1 memory, L2 Redis, L3 DB)
3. ✅ Rate limiting with token bucket algorithm
4. ✅ Timeout hierarchy with partial result handling
5. ✅ Circuit breaker pattern for cloud API resilience
6. ✅ Database query optimization and indexing
7. ✅ Large tenant query optimization (pagination, streaming)

### Security Improvements Needed:
1. ✅ API Gateway with WAF and DDoS protection
2. ✅ Input validation and sanitization
3. ✅ Prompt injection defense
4. ✅ Enhanced audit logging for forensics
5. ✅ Credential rotation and least privilege IAM
6. ✅ Network security with mTLS
7. ✅ Security monitoring and alerting
8. ✅ A2A Gateway security hardening

---

**Document Version:** 1.0  
**Project:** AI Cost Monitoring  
**Date:** January 2026  
**Author:** Architecture Review Team
