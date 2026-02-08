# F4: Security Operations (SecOps) Module
## Technical Specification v1.0.0

**Module**: `ai-cost-monitoring/modules/secops`  
**Version**: 1.0.0  
**Status**: Production Ready  
**Last Updated**: January 2026

---

## 1. Executive Summary

The F4 Security Operations Module provides runtime security including input validation, compliance enforcement, audit logging, and threat detection for the AI Cost Monitoring Platform. It is **domain-agnostic** — enforcing security controls without understanding business logic, with special attention to LLM-specific threats.

### Key Capabilities

| Capability | Description |
|------------|-------------|
| **Input Validation** | Injection detection, rate limiting, sanitization |
| **Compliance** | OWASP ASVS 5.0 Level 2, OWASP LLM Top 10 2025 |
| **Audit Logging** | Immutable, cryptographically-chained audit trail |
| **Threat Detection** | Brute force, anomaly detection, automated response |
| **LLM Security** | Prompt injection, data leakage, DoS protection |

---

## 2. Architecture Overview

### 2.1 Module Position

```
┌─────────────────────────────────────────────────────────────────────┐
│                      FOUNDATION MODULES                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │                   F4: SecOps v1.0.0                           │  │
│   │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐ │  │
│   │  │VALIDATION│ │COMPLIANCE│ │  AUDIT   │ │     THREAT       │ │  │
│   │  │          │ │          │ │          │ │    DETECTION     │ │  │
│   │  │• Inject  │ │• OWASP   │ │• Events  │ │• Brute Force     │ │  │
│   │  │• Rate    │ │• Checks  │ │• Storage │ │• Anomaly         │ │  │
│   │  │• Sanitize│ │• Reports │ │• Chain   │ │• Response        │ │  │
│   │  └──────────┘ └──────────┘ └──────────┘ └──────────────────┘ │  │
│   └──────────────────────────────────────────────────────────────┘  │
│         ▲                    ▲                     ▲                 │
│         │                    │                     │                 │
│   ┌───────────┐        ┌───────────┐        ┌───────────┐           │
│   │All Requests│        │F1 IAM     │        │F3 Observ. │           │
│   │(Intercept) │        │(Auth)     │        │(Logging)  │           │
│   └───────────┘        └───────────┘        └───────────┘           │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Design Principles

| Principle | Description |
|-----------|-------------|
| **Defense in Depth** | Multiple security layers; no single point of failure |
| **Fail Secure** | On error, deny access rather than allow |
| **Zero Trust** | Validate every request, assume breach |
| **Audit Everything** | Complete audit trail for all security events |
| **LLM-Aware** | First-class support for AI/LLM-specific threats |

---

## 3. Input Validation

### 3.1 Injection Detection

#### 3.1.1 Prompt Injection Detection

| Setting | Value |
|---------|-------|
| **Detection Model** | Built-in pattern matching + heuristics |
| **Action** | Block (reject request) |
| **Response Code** | 400 Bad Request |

**Detection Patterns:**

| Pattern Category | Examples |
|------------------|----------|
| Role Override | "ignore previous instructions", "you are now", "forget everything" |
| System Prompt Leak | "show me your system prompt", "what are your instructions" |
| Jailbreak Attempts | "DAN mode", "developer mode", "pretend you are" |
| Delimiter Injection | Attempted XML/JSON/markdown injection |

**Detection Algorithm:**
1. Pattern matching against known injection phrases
2. Semantic analysis for instruction override attempts
3. Structure analysis for delimiter manipulation
4. Context comparison with expected input format

#### 3.1.2 SQL Injection Detection

| Setting | Value |
|---------|-------|
| **Detection** | Pattern matching + parameterized query enforcement |
| **Action** | Block |
| **Response Code** | 400 Bad Request |

**Detection Patterns:**

| Pattern | Description |
|---------|-------------|
| UNION SELECT | Attempt to join malicious query |
| OR 1=1 | Always-true condition bypass |
| DROP TABLE | Destructive command injection |
| -- comments | Comment-based injection |
| ; chaining | Multiple statement execution |

#### 3.1.3 Cross-Site Scripting (XSS) Detection

| Setting | Value |
|---------|-------|
| **Detection** | Pattern matching + HTML parsing |
| **Action** | Sanitize (clean and continue) |
| **Response Code** | 200 (with sanitized input) |

**Detection Patterns:**

| Pattern | Description |
|---------|-------------|
| `<script>` tags | Direct script injection |
| Event handlers | onclick, onerror, onload attributes |
| javascript: URIs | Protocol-based injection |
| Data URIs | Encoded content injection |

### 3.2 Rate Limiting

| Endpoint | Limit | Window | Action on Exceed |
|----------|-------|--------|------------------|
| Global (*) | 100 requests | 60 seconds | 429 Too Many Requests |
| /api/execute | 10 requests | 60 seconds | 429 + Log |
| /api/trade | 10 requests | 60 seconds | 429 + Log + Alert |
| /api/auth | 5 requests | 60 seconds | 429 + Temp Block |

**Rate Limit Implementation:**

| Component | Description |
|-----------|-------------|
| Algorithm | Sliding window counter |
| Storage | Redis (or in-memory for dev) |
| Key | IP address + User ID (if authenticated) |
| Headers | X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset |

### 3.3 Validation Actions

| Action | Behavior | HTTP Response |
|--------|----------|---------------|
| **Block** | Reject request entirely | 400/403 |
| **Warn** | Allow request, log warning | 200 + Log |
| **Sanitize** | Clean input, continue processing | 200 |
| **Log** | Allow request, create audit entry | 200 + Audit |

---

## 4. Compliance Enforcement

### 4.1 Security Standards

#### 4.1.1 OWASP ASVS 5.0 (Level 2)

| Category | Controls | Status |
|----------|----------|--------|
| V1: Architecture | 14 controls | ✓ Implemented |
| V2: Authentication | 21 controls | ✓ Implemented |
| V3: Session | 16 controls | ✓ Implemented |
| V4: Access Control | 12 controls | ✓ Implemented |
| V5: Validation | 25 controls | ✓ Implemented |
| V6: Cryptography | 8 controls | ✓ Implemented |
| V7: Error Handling | 4 controls | ✓ Implemented |
| V8: Data Protection | 14 controls | ✓ Implemented |
| V9: Communication | 6 controls | ✓ Implemented |
| V10: Malicious Code | 3 controls | ✓ Implemented |
| V11: Business Logic | 8 controls | Domain-injected |
| V12: Files | 6 controls | ✓ Implemented |
| V13: API | 7 controls | ✓ Implemented |
| V14: Configuration | 5 controls | ✓ Implemented |

**Total**: 149 controls, Level 2 compliance target

#### 4.1.2 OWASP LLM Top 10 2025

| ID | Threat | Mitigation Status |
|----|--------|-------------------|
| LLM01 | Prompt Injection | ✓ Pattern detection, input sanitization |
| LLM02 | Insecure Output Handling | ✓ Output filtering, PII redaction |
| LLM03 | Training Data Poisoning | N/A (using external models) |
| LLM04 | Model Denial of Service | ✓ Token limits, rate limiting, cost caps |
| LLM05 | Supply Chain Vulnerabilities | ✓ Model validation, version pinning |
| LLM06 | Sensitive Information Disclosure | ✓ Context boundaries, output filtering |
| LLM07 | Insecure Plugin Design | ✓ MCP sandboxing, permission scoping |
| LLM08 | Excessive Agency | ✓ Trust levels (F1), human-in-loop |
| LLM09 | Overreliance | ✓ Trade confirmation, warnings |
| LLM10 | Model Theft | N/A (using external APIs) |

### 4.2 Compliance Checking

| Check Type | Trigger | Action on Failure |
|------------|---------|-------------------|
| **Startup Check** | Service boot | Block startup if critical |
| **Scheduled Check** | Daily at 00:00 UTC | Generate report |
| **On-Demand Check** | API call | Return status |

### 4.3 Compliance Reporting

| Field | Description |
|-------|-------------|
| **Format** | JSON |
| **Storage** | Cloud Storage |
| **Retention** | 7 years |
| **Contents** | Standard, controls checked, pass/fail, evidence |

**Report Structure:**

```
{
  "timestamp": "ISO8601",
  "standard": "owasp_asvs_5.0",
  "level": 2,
  "total_controls": 149,
  "passed": 147,
  "failed": 2,
  "not_applicable": 0,
  "compliance_percentage": 98.66,
  "findings": [...],
  "evidence": {...}
}
```

---

## 5. Audit Logging

### 5.1 Audited Event Types

#### 5.1.1 Security Events (Built-in)

| Event Type | Description | Severity |
|------------|-------------|----------|
| `auth.login` | User login attempt | Info |
| `auth.logout` | User logout | Info |
| `auth.failed` | Failed authentication | Warning |
| `auth.mfa` | MFA verification | Info |
| `authz.permit` | Access granted | Info |
| `authz.deny` | Access denied | Warning |
| `session.create` | Session created | Info |
| `session.terminate` | Session ended | Info |
| `threat.detected` | Threat identified | Critical |
| `threat.blocked` | Entity blocked | Warning |

#### 5.1.2 Operational Events (Domain-Injected)

| Event Type | Description | Severity |
|------------|-------------|----------|
| `data.read` | Data accessed | Info |
| `data.write` | Data modified | Info |
| `data.delete` | Data removed | Warning |
| `config.change` | Configuration modified | Warning |
| `trade.execute` | Trade executed | Info |
| `trade.cancel` | Trade cancelled | Info |
| `admin.action` | Administrative action | Warning |

### 5.2 Audit Log Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `event_id` | UUID | Yes | Unique event identifier |
| `timestamp` | ISO 8601 | Yes | Event time (UTC) |
| `event_type` | String | Yes | Event category and action |
| `actor_id` | UUID | Yes | User or service ID |
| `actor_type` | Enum | Yes | user, service, system |
| `resource_id` | String | If applicable | Affected resource |
| `resource_type` | String | If applicable | Resource category |
| `action` | String | Yes | Specific action taken |
| `outcome` | Enum | Yes | success, failure, partial |
| `ip_address` | String | Yes | Client IP |
| `user_agent` | String | Yes | Client user agent |
| `session_id` | UUID | If applicable | Session identifier |
| `context` | JSON | Optional | Additional context |
| `previous_hash` | String | Yes | Hash chain reference |
| `hash` | String | Yes | SHA-256 of event |

### 5.3 Audit Storage

| Setting | Value |
|---------|-------|
| **Backend** | BigQuery |
| **Dataset** | audit_logs |
| **Table** | events |
| **Retention** | 2,555 days (7 years) |
| **Partitioning** | By timestamp (daily) |
| **Clustering** | By event_type, actor_id |

### 5.4 Immutability

| Feature | Implementation |
|---------|----------------|
| **Hash Algorithm** | SHA-256 |
| **Chain Method** | Each event includes hash of previous event |
| **Tamper Detection** | Chain validation on read |
| **Integrity Check** | Daily automated verification |

**Hash Chain Structure:**

```
Event N:
  hash = SHA256(event_id + timestamp + event_type + ... + previous_hash)
  previous_hash = hash of Event N-1
```

---

## 6. Threat Detection

### 6.1 Detection Rules

#### 6.1.1 Brute Force Detection

| Setting | Value |
|---------|-------|
| **Threshold** | 5 failed attempts |
| **Window** | 5 minutes |
| **Action** | Block IP |
| **Block Duration** | 30 minutes |
| **Targets** | Login, MFA, API key validation |

#### 6.1.2 Anomaly Detection

| Setting | Value |
|---------|-------|
| **Model** | Statistical (Z-score based) |
| **Sensitivity** | Medium (2 standard deviations) |
| **Baseline** | 7-day rolling average |
| **Metrics Monitored** | Request rate, geographic location, access patterns |

**Detected Anomalies:**

| Anomaly | Description | Response |
|---------|-------------|----------|
| Unusual Access Time | Login outside normal hours | Alert |
| Geographic Anomaly | Access from unusual location | Alert + MFA prompt |
| Request Spike | Abnormal request volume | Rate limit + Alert |
| New Device | Unrecognized device | Alert + MFA prompt |

#### 6.1.3 Suspicious Pattern Detection

| Pattern | Description | Action |
|---------|-------------|--------|
| Credential Stuffing | Multiple accounts, same IP | Block IP |
| Account Enumeration | Sequential user ID probing | Block IP + Alert |
| Parameter Tampering | Modified hidden fields | Block request |
| Path Traversal | ../../../etc/passwd attempts | Block + Alert |

### 6.2 Automated Response

| Response | Trigger | Duration |
|----------|---------|----------|
| **Block IP** | Brute force, credential stuffing | 30 minutes |
| **Lock Account** | Multiple failed MFA | Until manual unlock |
| **Force Re-auth** | Anomaly detected | Immediate |
| **Alert** | Any threat | Immediate (PagerDuty + Slack) |

### 6.3 Blocked Entities Management

| Operation | Description |
|-----------|-------------|
| **List Blocked** | View all currently blocked IPs/users |
| **Manual Block** | Administratively block entity |
| **Manual Unblock** | Remove block before expiration |
| **Auto-Expire** | Blocks automatically removed after duration |

---

## 7. LLM Security

### 7.1 OWASP LLM Top 10 Mitigations

#### 7.1.1 LLM01: Prompt Injection

| Defense Layer | Implementation |
|---------------|----------------|
| **Input** | Pattern matching for known injection phrases |
| **Processing** | Context isolation between user and system prompts |
| **Output** | Response validation for instruction leakage |

#### 7.1.2 LLM02: Insecure Output Handling

| Defense Layer | Implementation |
|---------------|----------------|
| **PII Redaction** | Detect and mask sensitive data in responses |
| **Output Filtering** | Remove potentially harmful content |
| **Context Boundaries** | Prevent cross-session data leakage |

#### 7.1.3 LLM04: Model Denial of Service

| Defense Layer | Implementation |
|---------------|----------------|
| **Token Limits** | Max input/output tokens per request |
| **Rate Limiting** | Requests per minute per user |
| **Cost Caps** | Daily/monthly spending limits |
| **Timeout** | Maximum response wait time |

#### 7.1.4 LLM06: Sensitive Information Disclosure

| Defense Layer | Implementation |
|---------------|----------------|
| **Training Data** | No sensitive data in prompts |
| **Output Scanning** | Detect credentials, PII in responses |
| **Context Isolation** | Separate user contexts |

#### 7.1.5 LLM07: Insecure Plugin Design (MCP)

| Defense Layer | Implementation |
|---------------|----------------|
| **Sandboxing** | MCP servers run in isolated containers |
| **Permission Scoping** | Minimum required permissions |
| **Output Validation** | Validate all MCP server responses |
| **Audit** | Log all MCP interactions |

### 7.2 Defense-in-Depth Strategy

```
┌─────────────────────────────────────────────────────────────────────┐
│                    LLM SECURITY LAYERS                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  INPUT LAYER                                                         │
│  ├─ Prompt injection detection                                       │
│  ├─ Input sanitization                                               │
│  ├─ Rate limiting                                                    │
│  └─ Token limits                                                     │
│                                                                      │
│  PROCESSING LAYER                                                    │
│  ├─ Context isolation                                                │
│  ├─ System prompt protection                                         │
│  ├─ Cost monitoring                                                  │
│  └─ Timeout enforcement                                              │
│                                                                      │
│  OUTPUT LAYER                                                        │
│  ├─ PII redaction                                                    │
│  ├─ Response filtering                                               │
│  ├─ Instruction leak detection                                       │
│  └─ Audit logging                                                    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 8. Request Security Flow

### 8.1 Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    REQUEST SECURITY FLOW                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐       │
│  │ Request │───►│Rate Limit│───►│Validation│───►│ Threat   │       │
│  │  In     │    │  Check   │    │          │    │ Analysis │       │
│  └─────────┘    └────┬─────┘    └────┬─────┘    └────┬─────┘       │
│                      │               │               │              │
│                      ▼               ▼               ▼              │
│                 429 if over    400 if fail    403 if threat        │
│                                                      │              │
│                                                      ▼              │
│  ┌─────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐       │
│  │ Process │◄───│  Audit   │◄───│ F1 IAM   │◄───┤  Pass    │       │
│  │ Request │    │   Log    │    │  Auth    │    └──────────┘       │
│  └─────────┘    └──────────┘    └────┬─────┘                       │
│                                      │                              │
│                                      ▼                              │
│                                 401 if unauth                       │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 8.2 Decision Points

| Check Point | Pass Condition | Fail Response |
|-------------|----------------|---------------|
| Rate Limit | Under limit | 429 Too Many Requests |
| Input Validation | No injection detected | 400 Bad Request |
| Threat Analysis | No threat detected | 403 Forbidden |
| Authentication | Valid credentials | 401 Unauthorized |
| Authorization | Permitted action | 403 Forbidden |

---

## 9. Public API Interface

### 9.1 Input Validation Methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `validate_input` | input, context | ValidationResult | Validate input for injections |
| `sanitize_input` | input | string | Clean and return safe input |
| `check_rate_limit` | identifier, endpoint | RateLimitResult | Check rate limit status |

### 9.2 Compliance Methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `run_compliance_check` | standard? | ComplianceReport | Run compliance scan |
| `get_compliance_status` | - | ComplianceStatus | Get current compliance status |

### 9.3 Audit Methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `log_audit_event` | event | void | Log audit event |
| `query_audit_log` | query | AuditEvent[] | Search audit logs |
| `export_audit_log` | start, end | string (URL) | Export logs to file |

### 9.4 Threat Detection Methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `analyze_request` | request | ThreatAnalysis | Analyze request for threats |
| `report_threat` | threat | void | Report detected threat |
| `get_blocked_entities` | - | BlockedEntity[] | List blocked entities |
| `unblock_entity` | entity_id | void | Remove entity block |

### 9.5 Domain Integration Methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `register_audit_event_type` | type, schema | void | Register custom audit event |
| `register_threat_pattern` | pattern | void | Register custom threat pattern |

### 9.6 Extensibility Hooks

| Hook | Trigger | Use Case |
|------|---------|----------|
| `on_threat_detected` | Threat identified | Custom response, escalation |
| `on_validation_failed` | Input validation fails | Custom handling, logging |
| `on_compliance_violation` | Check fails | Custom notification |
| `on_audit_event` | Event logged | Custom processing |

---

## 10. Events Emitted

| Event | Trigger | Payload |
|-------|---------|---------|
| `threat.detected` | Threat identified | threat_type, severity, details |
| `entity.blocked` | Entity blocked | entity_type, entity_id, duration |
| `entity.unblocked` | Block removed | entity_type, entity_id, reason |
| `compliance.violation` | Check failed | standard, control, details |
| `audit.event_logged` | Audit event created | event_id, event_type |
| `validation.failed` | Input validation failed | input_type, reason |
| `rate_limit.exceeded` | Rate limit hit | identifier, endpoint, limit |

---

## 11. Integration Points

### 11.1 Foundation Module Integration

| Module | Integration | Purpose |
|--------|-------------|---------|
| **F1 IAM** | Bidirectional | Auth events, user context |
| **F2 Session** | Receives data | Session validation |
| **F3 Observability** | Sends events | Security logging, metrics |
| **F5 Self-Ops** | Sends alerts | Automated response |
| **F6 Infrastructure** | Uses services | BigQuery, Firewall |

### 11.2 Domain Layer Integration

All domain layers (D1-D7) pass through F4 for:
- Input validation
- Rate limiting
- Audit logging
- Threat analysis

---

## 12. Configuration Reference

```yaml
# f4-secops-config.yaml
module: secops
version: "1.0.0"

input_validation:
  enabled: true
  
  prompt_injection:
    enabled: true
    detection_model: built_in
    action: block
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
    run_on_schedule: "0 0 * * *"
  
  reporting:
    enabled: true
    format: json
    output: gs://nexus-compliance-reports/

audit:
  enabled: true
  
  events:
    authentication: true
    authorization: true
    data_access: true
    configuration_change: true
  
  storage:
    backend: bigquery
    dataset: audit_logs
    retention_days: 2555
  
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
      model: statistical
      sensitivity: medium
  
  response:
    auto_block: true
    notify_channels: [pagerduty, slack]
```

---

## 13. Security Considerations

### 13.1 Module Security

| Aspect | Implementation |
|--------|----------------|
| Access to Config | Admin only, audited |
| API Authentication | F1 IAM required |
| Log Protection | Encrypted at rest |
| Secret Management | F6 Secret Manager |

### 13.2 Operational Security

| Aspect | Implementation |
|--------|----------------|
| Updates | Signed packages only |
| Dependencies | Regular vulnerability scanning |
| Incident Response | Automated + manual procedures |
| Backup | Audit logs backed up daily |

---

## 14. Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Jan 2026 | Initial release with full security stack |

---

## 15. Roadmap

| Feature | Version | Description |
|---------|---------|-------------|
| ML Anomaly Detection | 1.1.0 | Machine learning-based detection |
| SIEM Integration | 1.1.0 | Export to external SIEM |
| WAF Integration | 1.2.0 | Cloud Armor integration |
| Automated Pen Testing | 1.2.0 | Scheduled security scans |
| Threat Intelligence | 1.3.0 | External threat feed integration |

---

*F4 SecOps Technical Specification v1.0.0 — AI Cost Monitoring Platform v4.2 — January 2026*
