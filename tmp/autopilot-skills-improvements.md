# Autopilot Skills Improvement Specification

## Source: Trading Nexus v4.2 Pattern Analysis

**Analysis Date**: 2026-02-09
**Reference Project**: `/opt/data/trading_nexus_v4.2/Nexus_Platform_v4.2/docs/`

---

## Executive Summary

Analysis of the Trading Nexus project documentation reveals significantly more mature patterns across all SDD layers. This document specifies improvements for each autopilot skill based on those patterns.

| Skill | Current Version | Proposed Version | Key Improvements |
|-------|-----------------|------------------|------------------|
| doc-bdd-autopilot | 1.0 | 2.0 | Scenario tagging, SHALL+WITHIN language, threshold references |
| doc-adr-autopilot | 1.0 | 2.0 | Vertical ID alignment, risk thresholds, circuit breaker patterns |
| doc-sys-autopilot | 1.0 | 2.0 | Modular splitting, external dependencies table, traceability matrix |
| doc-ctr-autopilot | 2.0 | - | Already updated with Phase 0 analysis |
| doc-spec-autopilot | 1.0 | 2.0 | 9-layer traceability, REQ-to-implementation bridges, 7-component scoring |
| doc-req-autopilot | 2.0 | - | Already updated with atomic decomposition |

---

## 1. doc-bdd-autopilot Improvements (v1.0 → v2.0)

### 1.1 Scenario Tagging Enhancement

**Current State**: Basic @primary, @negative tags

**Trading Nexus Pattern**: Rich scenario classification with 5 categories:

```gherkin
@primary @scenario-type:success @p0-critical
Scenario: User authenticates successfully

@alternative @scenario-type:optional @p1-high
Scenario: User authenticates with MFA

@fallback @scenario-type:recovery @p1-high
Scenario: System falls back to cached authentication

@data_driven @scenario-type:parameterized @p2-medium
Scenario Outline: Validate user role authorization

@negative @scenario-type:error @p0-critical
Scenario: Authentication fails with invalid credentials
```

**Improvement Required**:
- Add @scenario-type: tag for classification (success/optional/recovery/parameterized/error)
- Add priority tag (@p0-critical, @p1-high, @p2-medium, @p3-low)
- Require all 5 scenario categories per BDD suite

### 1.2 SHALL Language with WITHIN Constraints

**Current State**: Basic Given-When-Then without timing

**Trading Nexus Pattern**: Formal EARS-derived language with timing:

```gherkin
Scenario: API response meets latency threshold
  Given the system is under normal load
  When user submits authentication request
  Then the system SHALL return response WITHIN @threshold:PRD.01.perf.auth.p95_latency
  And the system SHALL log the request WITHIN @threshold:PRD.01.perf.logging.max_delay
```

**Improvement Required**:
- Add SHALL/SHOULD/MAY modal language support
- Add WITHIN timing constraint pattern
- Require @threshold references for all timing assertions

### 1.3 Enhanced Threshold References

**Current State**: Basic numeric values

**Trading Nexus Pattern**: Registry-based threshold format:

```gherkin
@threshold:PRD.NN.category.field.subfield
```

**Examples**:
```gherkin
@threshold:PRD.01.perf.auth.p95_latency       # Performance threshold
@threshold:PRD.01.sla.uptime.target           # SLA threshold
@threshold:PRD.01.limit.rate.per_ip           # Rate limit
@threshold:PRD.01.timeout.circuit_breaker     # Timeout value
```

**Improvement Required**:
- Mandate @threshold:PRD.NN.category.field format
- Add threshold validation against PRD threshold registry
- No hardcoded numeric values in scenarios

### 1.4 New Validation Rules

| Check | Requirement | Error Code |
|-------|-------------|------------|
| Scenario Type Tag | @scenario-type present | BDD-E050 |
| Priority Tag | @pN-level present | BDD-E051 |
| SHALL Language | Modal verbs in Then steps | BDD-E052 |
| WITHIN Constraint | Timing assertions use WITHIN | BDD-E053 |
| Threshold Format | @threshold:PRD.NN.x.y format | BDD-E054 |
| Category Coverage | All 5 categories represented | BDD-E055 |

---

## 2. doc-adr-autopilot Improvements (v1.0 → v2.0)

### 2.1 Vertical ID Alignment with Nested Folders

**Current State**: Flat ADR-01, ADR-02 structure

**Trading Nexus Pattern**: Module-aligned nested structure:

```
docs/05_ADR/
├── ADR-00_Technology_Stack_Foundation.md     # Flat (foundation)
├── ADR-01_iam/                                # Nested folder
│   ├── ADR-01.01_jwt_authentication.md
│   ├── ADR-01.02_4d_authorization.md
│   └── ADR-01.03_mfa_integration.md
├── ADR-02_Session_Memory_Architecture.md      # Flat (single topic)
└── ADR-08_trading_intelligence/               # Nested folder
    ├── ADR-08.01_Agent_Orchestration.md
    ├── ADR-08.02_Risk_Management.md
    └── ADR-08.03_Learning_Governance.md
```

**Improvement Required**:
- Add Phase 1.5: Folder Structure Analysis
- Detect BRD/PRD cardinality (1-to-1 vs 1-to-many)
- Conditionally create nested folders for multi-decision modules
- Generate ADR-NN.00_index.md for nested structures

### 2.2 SYS-Ready Score with Visual Indicators

**Current State**: Score as percentage only

**Trading Nexus Pattern**: Visual status indicators:

```markdown
| **SYS-Ready Score** | ✅ 92% (Target: ≥90%) |
| **SYS-Ready Score** | 🟡 87% (Target: ≥90%) |
| **SYS-Ready Score** | ❌ 75% (Target: ≥90%) |
```

**Improvement Required**:
- Add emoji indicators (✅ ≥90%, 🟡 85-89%, ❌ <85%)
- Display score breakdown by category
- Auto-calculate during generation

### 2.3 Risk Assessment with Quantified Thresholds

**Current State**: Prose-based risk table

**Trading Nexus Pattern**: Dual-table format with parameters:

**Table 1: Risk Assessment**:
```markdown
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Coordinator overload | Medium | High | Queue management, rate limiting |
```

**Table 2: Risk Thresholds** (NEW):
```markdown
| Parameter | Value | Description |
|-----------|-------|-------------|
| `max_concurrent_requests` | 100 | Maximum simultaneous requests |
| `queue_max_size` | 500 | Maximum pending requests |
| `backpressure_threshold` | 80% | Queue utilization trigger |
```

**Improvement Required**:
- Add Section 11.X: Risk Thresholds subsection
- Require quantified parameters for operational risks
- Link thresholds to @threshold registry

### 2.4 Circuit Breaker Pattern Documentation

**Current State**: Not documented

**Trading Nexus Pattern**: Dedicated circuit breaker section:

**Table 1: Circuit Breaker Definitions**:
```markdown
| Circuit Breaker | Trigger | Action | Recovery |
|-----------------|---------|--------|----------|
| CB-01: Daily Loss | > $500 cumulative | Halt all trading | Manual reset next day |
| CB-02: Weekly Loss | > $1,500 cumulative | Halt all trading | Manual reset next week |
```

**Table 2: Circuit Breaker Reset Procedures**:
```markdown
| Circuit Breaker | Authorization Level | Required Documentation | Cooldown Period |
|-----------------|---------------------|------------------------|-----------------|
| CB-01 (Daily Loss) | Operator | Loss review acknowledgment | Until next trading day |
| CB-03 (Max Drawdown) | Admin | Full portfolio review | 24 hours minimum |
```

**Improvement Required**:
- Detect ADRs involving control mechanisms
- Add Section 11.Y: Circuit Breaker Recovery for operational ADRs
- Template reset authorization flows

### 2.5 Event/Query Contract Linkage

**Current State**: No contract references

**Trading Nexus Pattern**: Standardized contract ID schemes:

```markdown
### Implementation Contracts

| Feature | Contract IDs |
|---------|--------------|
| **Events** | EC-001 (Learning Trigger), EC-002 (Model Update) |
| **Queries** | QC-001 (Historical Data), QC-002 (Performance Metrics) |
| **A2A Protocol** | A2A-001 (Agent Communication) |
```

**Improvement Required**:
- Detect A2A/MCP protocol references
- Generate contract ID schemes (EC-NNN, QC-NNN, A2A-NNN)
- Validate referenced contracts exist in CTR layer

### 2.6 MVP/Post-MVP Scope Declaration

**Current State**: Not explicitly separated

**Trading Nexus Pattern**: Explicit scope delineation:

```markdown
### 7.1 MVP Scope (Phase 1)

- Coordinator with basic intent classification
- Risk Agent with position size circuit breaker
- Execution Agent with IB order submission

### 7.2 Post-MVP Scope (Phase 2+)

- Full multi-agent orchestration
- All 7 circuit breakers active
- Machine learning optimization
```

**Improvement Required**:
- Add Section 7.1 MVP Scope and 7.2 Post-MVP Scope
- Cross-validate with parent PRD MVP scope
- Flag inconsistencies between ADR and PRD scope

### 2.7 New Validation Rules

| Check | Requirement | Error Code |
|-------|-------------|------------|
| Folder Structure | Nested for multi-decision modules | ADR-E030 |
| Visual Score | Emoji indicator present | ADR-E031 |
| Risk Thresholds | Quantified parameter table | ADR-E032 |
| Circuit Breaker | Recovery table if CB mentioned | ADR-E033 |
| Contract Linkage | EC/QC IDs validated | ADR-E034 |
| MVP Scope | Section 7.1/7.2 present | ADR-E035 |
| Traceability Format | Hierarchical dot notation | ADR-E036 |

---

## 3. doc-sys-autopilot Improvements (v1.0 → v2.0)

### 3.1 Modular vs Monolithic Splitting

**Current State**: Size-based splitting only (>25KB)

**Trading Nexus Pattern**: Content-aware splitting:

| Strategy | Trigger | Structure |
|----------|---------|-----------|
| Monolithic | <20KB total, <5 functional requirements | Single file |
| Modular | >20KB OR >5 functional requirements | Folder with section files |
| Hierarchical | >10 interface specifications | Nested sub-sections |

**Improvement Required**:
- Add content analysis to determine structure
- Count functional requirements, interfaces, quality attributes
- Generate modular structure when complexity warrants

### 3.2 External Dependencies Table

**Current State**: Basic dependency list

**Trading Nexus Pattern**: Comprehensive dependencies with fallback:

```markdown
### External Dependencies

| Dependency | Type | Protocol | Required | Fallback Strategy |
|------------|------|----------|----------|-------------------|
| GCP Identity Platform | Authentication | HTTPS/REST | Yes | Local auth cache |
| Redis | Session Store | TCP | Yes | PostgreSQL fallback |
| PostgreSQL | Persistence | TCP | Yes | None (fatal) |
| Datadog | Observability | HTTPS | No | Local logging |
```

**Improvement Required**:
- Add Fallback Strategy column
- Classify dependencies by criticality (Required/Optional)
- Specify protocol for each dependency

### 3.3 REQ-Ready Scoring Enhancement

**Current State**: 4-category scoring

**Trading Nexus Pattern**: 6-category scoring with weights:

| Category | Weight | Subcriteria |
|----------|--------|-------------|
| Requirements Decomposition | 25% | System boundaries, functional decomposition |
| Quality Attributes | 25% | Performance percentiles, reliability SLAs |
| Interface Specifications | 20% | External APIs, internal interfaces |
| Data Management | 10% | Storage requirements, data flow |
| Testing Requirements | 10% | Test approach, verification methods |
| Traceability | 10% | 5 cumulative tags, threshold references |

**Improvement Required**:
- Expand scoring to 6 categories
- Add Data Management and Testing Requirements
- Calculate subscores during generation

### 3.4 Traceability Matrix Structure

**Current State**: Basic @tag references

**Trading Nexus Pattern**: Structured matrix with validation:

```markdown
### 13. Traceability

#### 13.1 Upstream Sources

| Source Type | Document ID | Element Reference | Relationship |
|-------------|-------------|-------------------|--------------|
| BRD | BRD-01 | BRD.01.01.03 | Business driver |
| PRD | PRD-01 | PRD.01.07.02 | Feature requirement |
| ADR | ADR-01 | ADR.01.10.01 | Architecture decision |

#### 13.2 Downstream Artifacts

| Artifact | Status | Relationship |
|----------|--------|--------------|
| REQ-01 | Generated | Atomic requirements |
| CTR-01 | Pending | API contracts |

#### 13.3 Cross-Link Validation

| Reference | Target Exists | Link Status |
|-----------|---------------|-------------|
| @brd:BRD.01.01.03 | ✅ | Valid |
| @prd:PRD.01.07.02 | ✅ | Valid |
```

**Improvement Required**:
- Add Section 13.2 Downstream Artifacts
- Add Section 13.3 Cross-Link Validation
- Auto-validate all references point to existing documents

### 3.5 New Validation Rules

| Check | Requirement | Error Code |
|-------|-------------|------------|
| Splitting Strategy | Content-aware analysis | SYS-E030 |
| Dependencies Table | Fallback strategy column | SYS-E031 |
| Scoring Categories | 6 categories present | SYS-E032 |
| Downstream Artifacts | Section 13.2 present | SYS-E033 |
| Cross-Link Validation | Section 13.3 with status | SYS-E034 |

---

## 4. doc-spec-autopilot Improvements (v1.0 → v2.0)

### 4.1 YAML-Only Pure Schema Format

**Current State**: Basic YAML structure

**Trading Nexus Pattern**: Comprehensive 13-section YAML:

```yaml
# Required sections
metadata:           # Document control, version, status
traceability:       # 9-layer upstream/downstream references
interfaces:         # external_apis, internal_apis, classes
data_models:        # Pydantic models with code examples
validation_rules:   # Input/output validation
error_handling:     # Error catalog with HTTP status
configuration:      # Environment variables, feature flags
performance:        # Latency targets, throughput
behavior:           # Pseudocode for key flows
behavioral_examples: # Real API call examples
architecture:       # Component structure, dependencies
operations:         # SLO, monitoring, runbooks
req_implementations: # REQ-to-implementation mapping
```

**Improvement Required**:
- Mandate all 13 sections
- Add section templates for each
- Validate section completeness

### 4.2 9-Layer Cumulative Traceability

**Current State**: 7-8 layer tags

**Trading Nexus Pattern**: Full 9-layer with nested REQ paths:

```yaml
traceability:
  upstream_sources:
    business_requirements:
      - id: "BRD-01.01.03"
        link: "../01_BRD/BRD-01.md#BRD.01.01.03"
        relationship: "Business driver for authentication"
    product_requirements:
      - id: "PRD-01.07.02"
        link: "../02_PRD/PRD-01.md#PRD.01.07.02"
    atomic_requirements:
      - id: "REQ-01.01.01"
        # CRITICAL: Nested path format
        link: "../07_REQ/SYS-01_iam/REQ-01.01_jwt_authentication.md"
  cumulative_tags:
    brd: ["BRD.01.01.03"]
    prd: ["PRD.01.07.02"]
    ears: ["EARS.01.25.01"]
    bdd: ["BDD.01.14.01"]
    adr: ["ADR-01"]
    sys: ["SYS.01.26.01"]
    req: ["REQ.01.27.01"]
    ctr: ["CTR.01.16.01"]
    threshold: ["perf.auth.p95_latency", "sla.uptime.target"]
```

**Improvement Required**:
- Add 9th layer: threshold references
- Use nested REQ paths (`../07_REQ/SYS-XX_domain/REQ-XX.YY.md`)
- Validate all cross-references

### 4.3 Three-Level Interface Specification

**Current State**: Single interface format

**Trading Nexus Pattern**: Three parallel definitions:

**Level 1: External APIs (REST)**:
```yaml
external_apis:
  - endpoint: "POST /api/v1/auth/login"
    method: "POST"
    auth: "None"
    rate_limit: "5 req/5 min per IP"
    request_schema: { type: object, properties: {...} }
    response_schema: { type: object, properties: {...} }
    latency_target_ms: 500
```

**Level 2: Internal APIs (Service)**:
```yaml
internal_apis:
  - interface: "AuthService.authenticate()"
    signature: "async def authenticate(email: str, password: str) -> TokenPair"
    purpose: |
      1. Fetch user by email from Identity Platform.
      2. Verify password via Argon2id.
```

**Level 3: Classes (OOP)**:
```yaml
classes:
  - name: "IAMService"
    description: "Facade combining auth, token, and authz services"
    constructor:
      params: { config: { type: object, required: true } }
    methods:
      - name: "initialize"
        input: {...}
        output: {...}
```

**Improvement Required**:
- Add three interface levels
- Generate all three for each service
- Validate consistency between levels

### 4.4 Threshold Registry Pattern

**Current State**: Inline values or basic @threshold

**Trading Nexus Pattern**: Centralized registry with usage tracking:

```yaml
performance:
  latency_targets:
    login_p95_ms: "@threshold:perf.auth.p95_latency"

threshold_references:
  registry_document: "PRD-01_thresholds"
  keys_used:
    performance:
      - key: "perf.auth.p95_latency"
        usage: "performance.latency_targets.login"
      - key: "perf.token_validation.p95_latency"
        usage: "performance.latency_targets.token_validation"
    sla:
      - key: "sla.uptime.target"
        usage: "operations.slo.uptime"
```

**Improvement Required**:
- Add threshold_references section
- Track all threshold usage locations
- Validate against PRD threshold registry

### 4.5 REQ-to-Implementation Bridges

**Current State**: No implementation mapping

**Trading Nexus Pattern**: Full implementation detail per REQ:

```yaml
req_implementations:
  - req_id: "REQ-01.01"
    req_link: "../07_REQ/SYS-01_iam/REQ-01.01.md"
    implementation:
      interfaces:
        - class: "AuthService"
          method: "login"
          signature: "async def login(...) -> LoginResult"
      data_models:
        - name: "LoginRequest"
          fields: [...]
      validation_rules:
        - rule: "Rate limit login attempts"
          implementation: "Enforce 5 attempts/5 minutes per IP"
      error_handling:
        - error_code: "INVALID_CREDENTIALS"
          condition: "Email not found or password mismatch"
          http_status: 401
      test_approach:
        unit_tests: ["hash verification rejects wrong password"]
        integration_tests: ["login flow returns token pair"]
```

**Improvement Required**:
- Add req_implementations section
- Map each REQ to full implementation detail
- Enable auto-generation of TASKS from this section

### 4.6 Task-Ready Scoring Formula

**Current State**: Basic percentage

**Trading Nexus Pattern**: 7-component weighted scoring:

| Component | Weight | Criteria |
|-----------|--------|----------|
| Interface Completeness | 25% | All 3 levels defined |
| Data Models | 20% | Pydantic + JSON Schema |
| Validation Rules | 15% | Input/output validation |
| Error Handling | 15% | Error catalog with HTTP status |
| Test Approach | 10% | Unit + integration tests specified |
| Traceability | 10% | All 9 cumulative tags |
| Performance Specs | 5% | Latency targets with thresholds |

**Improvement Required**:
- Calculate 7-component score
- Display component breakdown
- Require ≥90% for TASKS generation

### 4.7 File Splitting Strategy

**Current State**: Not implemented

**Trading Nexus Pattern**: Size-aware splitting:

| Strategy | Trigger | Result |
|----------|---------|--------|
| Single file | <66KB | SPEC-NN.yaml |
| Split | >66KB | SPEC-NN.01.yaml, SPEC-NN.02.yaml |
| Nested folder | >3 splits | SPEC-NN_module/ with sub-files |

**Improvement Required**:
- Add file size monitoring
- Split large SPECs into micro-SPECs
- Generate index file for nested structures

### 4.8 New Validation Rules

| Check | Requirement | Error Code |
|-------|-------------|------------|
| 13 Sections | All required sections present | SPEC-E030 |
| Three Interface Levels | external, internal, classes | SPEC-E031 |
| Threshold Registry | threshold_references section | SPEC-E032 |
| REQ Implementation | req_implementations present | SPEC-E033 |
| Nested REQ Paths | Correct path format | SPEC-E034 |
| 7-Component Score | All components calculated | SPEC-E035 |
| File Size | <66KB or split | SPEC-E036 |

---

## 5. Implementation Priority

### Phase 1: High-Impact Skills (Week 1-2)

| Skill | Priority | Rationale |
|-------|----------|-----------|
| doc-spec-autopilot | P0 | Critical for TASKS generation |
| doc-adr-autopilot | P1 | Foundation for SYS quality |
| doc-bdd-autopilot | P1 | Enables threshold validation |

### Phase 2: Supporting Skills (Week 3)

| Skill | Priority | Rationale |
|-------|----------|-----------|
| doc-sys-autopilot | P2 | Enables REQ quality |

### Phase 3: Already Updated

| Skill | Status |
|-------|--------|
| doc-req-autopilot | v2.0 complete |
| doc-ctr-autopilot | v2.0 complete |

---

## 6. Migration Steps

### For Each Skill Update:

1. **Read current SKILL.md**
2. **Add new configuration options**
3. **Add new phase (if applicable)**
4. **Update section templates**
5. **Add validation rules**
6. **Update version to 2.0**
7. **Update version history**

### Validation After Update:

- [ ] All new patterns documented
- [ ] Configuration options added
- [ ] Validation rules defined with error codes
- [ ] Version incremented
- [ ] Related resources updated

---

## 7. Success Metrics

After implementing all improvements:

| Metric | Before | After | Target |
|--------|--------|-------|--------|
| BDD scenario coverage | 5 categories | 5+ with tags | All @scenario-type |
| ADR folder structure | Flat only | Adaptive | Nested when needed |
| SYS dependency tracking | Basic | With fallback | All dependencies |
| SPEC interface levels | 1 | 3 | All three |
| SPEC threshold tracking | Ad-hoc | Registry | All thresholds |
| Readiness scores | Implicit | Explicit | Component breakdown |

---

*Generated: 2026-02-09*
*Based on: Trading Nexus v4.2 comprehensive analysis*
