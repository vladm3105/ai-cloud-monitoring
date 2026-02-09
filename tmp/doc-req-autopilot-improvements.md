# doc-req-autopilot Skill Improvement Specification

## Source: Trading Nexus REQ Layer Analysis

**Analysis Date**: 2026-02-09
**Reference Project**: `/opt/data/trading_nexus_v4.2/Nexus_Platform_v4.2/docs/07_REQ/REQ-01_f1_iam/`

---

## Executive Summary

The Trading Nexus project demonstrates a significantly more mature REQ layer compared to Cost Monitoring:

| Metric | Trading Nexus | Cost Monitoring | Gap |
|--------|---------------|-----------------|-----|
| REQ Files | 12 atomic files | 1 consolidated file | -11 files |
| Total Size | ~200KB | ~18KB | -182KB |
| Decomposition | Per capability | Monolithic | Missing pattern |
| Unit Tests | Detailed tables | Basic | Missing format |
| Cross-Links | @discoverability tags | Minimal | Missing pattern |
| Error Catalogs | HTTP status + codes | Basic | Missing depth |

---

## Key Improvements Identified

### 1. Atomic Decomposition Pattern (NEW)

**Current State**: The skill generates a single consolidated REQ document per SYS.

**Trading Nexus Pattern**: Each SYS capability is decomposed into separate atomic REQ files:

```
REQ-01_f1_iam/
├── REQ-01.01_jwt_authentication.md      # SYS.01.01.01
├── REQ-01.02_token_refresh_mechanism.md # SYS.01.01.02
├── REQ-01.03_token_revocation.md        # SYS.01.01.03
├── REQ-01.04_session_binding.md         # SYS.01.01.04
├── REQ-01.05_rbac_enforcement.md        # SYS.01.02.01
├── REQ-01.06_4d_authorization_matrix.md # SYS.01.01.03
├── REQ-01.07_permission_inheritance.md  # SYS.01.02.02
├── REQ-01.08_context_aware_access.md    # SYS.01.02.03
├── REQ-01.09_mfa_integration.md         # SYS.01.01.05
├── REQ-01.10_api_key_management.md      # SYS.01.03.01
├── REQ-01.11_audit_logging.md           # SYS.01.02.04
└── REQ-01.12_compliance_reporting.md    # SYS.01.02.05
```

**Improvement Required**:
- Add **Phase 1.5: Capability Decomposition** that splits SYS requirements into atomic REQ files
- Each REQ file maps to one SYS functional requirement (SYS.NN.MM.SS)
- File naming: `REQ-{module}.{sequence}_{capability_slug}.md`

### 2. Enhanced Unit Test Specification Format (NEW)

**Current State**: Basic test tables without categorization.

**Trading Nexus Pattern**: Rich unit test tables with:

| Test Case | Input | Expected Output | Coverage |
|-----------|-------|-----------------|----------|
| **[Logic] Valid login** | Valid email/password | 200 with tokens | Happy path |
| **[Logic] Invalid email format** | "not-an-email" | 400 INVALID_EMAIL | Validation |
| **[State] Locked account** | Locked user | 403 ACCOUNT_LOCKED | Account state |
| **[Edge] GCP Down** | Mock unavailable | 503 SERVICE_UNAVAILABLE | Resilience |

**Categories**:
- `[Logic]` - Core business logic tests
- `[Validation]` - Input validation tests
- `[State]` - State machine/transition tests
- `[Edge]` - Edge case and boundary tests
- `[Security]` - Security-specific tests

**Improvement Required**:
- Update Section 8 (Testing Requirements) template with category prefixes
- Require minimum coverage across all 5 categories
- Add coverage mapping to requirement IDs

### 3. Cross-Links and Discoverability Section (NEW)

**Current State**: Basic `@depends` and `@discoverability` tags.

**Trading Nexus Pattern**: Rich cross-linking with context:

```markdown
### 10.5 Cross-Links

@depends: REQ-01.02, REQ-01.04
@discoverability: REQ-01.11 (JWT issuance events must align with audit logging)
```

For REQ-01.06 (4D Authorization Matrix):
```markdown
@discoverability: REQ-01.05 (role policies feed the matrix);
                  REQ-01.07 (inheritance inputs drive matrix entries);
                  REQ-01.08 (context dimensions align with matrix factors);
                  REQ-01.11 (authz decisions must be audit-covered);
                  REQ-01.12 (matrix outputs support compliance evidence)
```

**Improvement Required**:
- Add Section 10.5 Cross-Links as mandatory section
- Require explanatory context for each cross-link
- Validate cross-links point to existing REQ files

### 4. Enhanced Error Catalog Format (NEW)

**Current State**: Basic error table.

**Trading Nexus Pattern**: Comprehensive error catalog with:

| Error Code | HTTP Status | Condition | User Message | System Action |
|------------|-------------|-----------|--------------|---------------|
| INVALID_REQUEST | 400 | Malformed request body | "Invalid request format" | Log, return error |
| INVALID_EMAIL | 400 | Email format invalid | "Invalid email format" | Log, return error |
| RATE_LIMITED | 429 | Too many attempts | "Too many attempts. Try again in 15 minutes" | Log, block IP |
| SERVICE_UNAVAILABLE | 503 | GCP Identity Platform down | "Service temporarily unavailable" | Log, alert, fallback |

**Plus Recovery Strategy**:

| Error Type | Retry? | Fallback | Alert |
|------------|--------|----------|-------|
| Validation error | No | Return error | No |
| Auth failure | No | Increment counter | After 3 failures |
| Rate limit | No | Block 15 min | Yes |
| GCP unavailable | Yes (3x) | Cached sessions | After retries |

**Improvement Required**:
- Mandate both Error Catalog table AND Recovery Strategy table
- Add System Action column to error catalog
- Add Alert column to recovery strategy

### 5. Implementation Notes Enhancement (NEW)

**Current State**: Generic technical approach.

**Trading Nexus Pattern**: Specific code paths and file locations:

```markdown
### 11.1 Technical Approach

Implement authentication service using FastAPI with async GCP Identity Platform client.
Use PyJWT for token generation with RS256 signing. Store rate limiting counters in Redis
with TTL-based expiration. Configure refresh token as HTTP-only, Secure, SameSite=Strict cookie.

### 11.2 Code Implementation Paths

- **Primary**: `src/foundation/f1_iam/auth/jwt_auth.py`
- **Tests**: `tests/foundation/f1_iam/test_jwt_auth.py`
- **Integration**: `tests/integration/test_auth_endpoints.py`

### 11.3 Dependencies

| Package/Service | Version | Purpose |
|-----------------|---------|---------|
| PyJWT | 2.8+ | JWT generation and validation |
| cryptography | 41+ | RS256 key management |
| google-cloud-identity | latest | GCP Identity Platform client |
| redis | 5+ | Rate limiting storage |
| pydantic | 2.5+ | Request/response validation |
```

**Improvement Required**:
- Add Section 11.2 Code Implementation Paths (mandatory)
- Add Section 11.3 Dependencies table (mandatory)
- Require specific file path predictions

### 6. Acceptance Criteria Depth (ENHANCE)

**Current State**: 5-8 acceptance criteria.

**Trading Nexus Pattern**: 15+ acceptance criteria split into:

**9.1 Functional Acceptance** (10 criteria):
- Specific measurable outcomes for each function
- Status checkbox for tracking

**9.2 Quality Acceptance** (5 criteria):
- Latency targets
- Throughput targets
- Error rate targets
- Security scan results
- Test coverage thresholds

**Improvement Required**:
- Mandate minimum 15 acceptance criteria total
- Split into 9.1 Functional (10+) and 9.2 Quality (5+) subsections
- Add Status column with checkbox

---

## SKILL.md Updates Required

### New Configuration Options

```yaml
req_autopilot:
  decomposition:
    strategy: atomic      # NEW: atomic | monolithic | auto
    min_files: 3          # NEW: Minimum files for atomic decomposition
    max_file_size_kb: 50  # NEW: Trigger split if exceeds

  validation:
    min_acceptance_criteria: 15      # NEW: Minimum AC count
    require_cross_links: true        # NEW: Mandate Section 10.5
    require_error_catalog: true      # NEW: Full error table
    require_recovery_strategy: true  # NEW: Recovery table
    require_test_categories: true    # NEW: [Logic]/[Validation]/etc

  output:
    structure: atomic     # atomic | monolithic (default: atomic)
    create_index: true    # NEW: Generate REQ-NN.00_index.md
```

### New Phase: Capability Decomposition

Insert between Phase 1 and Phase 2:

```markdown
### Phase 1.5: Capability Decomposition

Decompose SYS functional requirements into atomic REQ files.

**Decomposition Rules**:
1. Each SYS.NN.MM.SS functional requirement maps to one REQ-NN.MM file
2. Files are named: `REQ-{module}.{seq}_{slug}.md`
3. Create index file: `REQ-NN.00_index.md` listing all atomic REQs
4. Each file is self-contained with all 12 sections
5. Cross-links reference sibling REQ files

**Output Example**:
```
docs/07_REQ/REQ-01_f1_iam/
├── REQ-01.00_index.md
├── REQ-01.01_jwt_authentication.md
├── REQ-01.02_token_refresh.md
└── ...
```
```

### Enhanced Section Templates

Update Phase 3 to include enhanced templates:

**Section 8: Testing Requirements** (enhanced):
```markdown
### 8.1 Unit Tests

| Test Case | Input | Expected Output | Coverage |
|-----------|-------|-----------------|----------|
| **[Logic] Core Function** | Valid input | Expected result | REQ.NN.01.SS |
| **[Validation] Invalid Input** | Bad data | Error response | REQ.NN.21.SS |
| **[State] State Transition** | State change | New state | REQ.NN.27.SS |
| **[Edge] Boundary** | Edge case | Handled gracefully | REQ.NN.06.SS |
| **[Security] Auth Check** | No token | 401 Unauthorized | REQ.NN.02.SS |
```

**Section 10.5: Cross-Links** (new mandatory):
```markdown
### 10.5 Cross-Links

@depends: REQ-NN.XX (direct dependency description)
@discoverability: REQ-NN.YY (interaction context); REQ-NN.ZZ (shared resource)
```

**Section 11: Implementation Notes** (enhanced):
```markdown
### 11.1 Technical Approach
[Specific technical approach with named patterns and libraries]

### 11.2 Code Implementation Paths
- **Primary**: `src/{layer}/{module}/{capability}.py`
- **Tests**: `tests/{layer}/{module}/test_{capability}.py`
- **Integration**: `tests/integration/test_{capability}_endpoints.py`

### 11.3 Dependencies
| Package/Service | Version | Purpose |
|-----------------|---------|---------|
| [package] | [version]+ | [specific purpose] |
```

---

## Validation Rule Updates

### doc-req-validator Enhancements

Add new validation checks:

| Check | Requirement | Error Code |
|-------|-------------|------------|
| Unit Test Categories | All 5 categories present | REQ-E025 |
| Cross-Links Section | Section 10.5 exists | REQ-E026 |
| Error Catalog Depth | ≥5 error codes documented | REQ-E027 |
| Recovery Strategy | Recovery table present | REQ-E028 |
| Code Paths | Section 11.2 present | REQ-E029 |
| Acceptance Criteria Count | ≥15 total | REQ-E030 |
| AC Split | 9.1 Functional + 9.2 Quality | REQ-E031 |
| Atomic Decomposition | ≥3 files if strategy=atomic | REQ-E032 |

---

## Migration Path

### Phase 1: Skill Update
1. Update SKILL.md with new configuration options
2. Add Phase 1.5 Capability Decomposition
3. Update section templates

### Phase 2: Template Update
1. Update REQ-MVP-TEMPLATE.md with enhanced sections
2. Add REQ-INDEX-TEMPLATE.md for atomic output

### Phase 3: Validator Update
1. Add new validation checks to doc-req-validator
2. Update scoring weights for enhanced sections

### Phase 4: Generate Atomic REQs
1. Run autopilot on existing SYS-01
2. Decompose into 12+ atomic REQ files
3. Validate cross-links and discoverability

---

## Success Metrics

After implementation:

| Metric | Before | After | Target |
|--------|--------|-------|--------|
| REQ Files per Module | 1 | 10-15 | ≥10 |
| Size per REQ | 18KB | 15-25KB | 15-30KB |
| Acceptance Criteria | 8 | 15-20 | ≥15 |
| Test Categories | 2 | 5 | 5 |
| Cross-Links | 0 | 5-10 | ≥5 |
| Error Codes | 5 | 10-15 | ≥10 |
| SPEC-Ready Score | 92% | 95%+ | ≥95% |

---

*Generated: 2026-02-09*
*Based on: Trading Nexus REQ-01_f1_iam analysis*
