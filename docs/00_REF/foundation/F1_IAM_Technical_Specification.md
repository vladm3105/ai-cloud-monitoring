# F1: Identity & Access Management (IAM) Module
## Technical Specification v1.2.0

**Module**: `ai-cost-monitoring/modules/iam`  
**Version**: 1.2.0  
**Status**: Production Ready  
**Last Updated**: 2026-01-01T00:00:00

---

## 1. Executive Summary

The F1 IAM Module is a foundational security component that handles all authentication and authorization for the AI Cost Monitoring Platform. It implements a **4-Dimensional Authorization Matrix** (ACTION × SKILL × RESOURCE × ZONE) and supports multiple authentication providers with Auth0 as the primary identity provider.

### Key Capabilities

| Capability | Description |
|------------|-------------|
| **Multi-Provider Authentication** | Auth0 (primary), Google, local email/password, mTLS, API keys |
| **4D Authorization Matrix** | Fine-grained access control across four dimensions |
| **Trust Levels** | 4-tier trust system with progressive access rights |
| **MFA Enforcement** | TOTP and WebAuthn for high-trust operations |
| **Domain Agnostic** | Zero knowledge of business logic; fully configuration-driven |

---

## 2. Architecture Overview

### 2.1 Module Position

```
┌─────────────────────────────────────────────────────────────────────┐
│                      FOUNDATION MODULES                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │                     F1: IAM v1.2.0                            │  │
│   │  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐  │  │
│   │  │AUTHENTICATION│ │AUTHORIZATION │ │    USER PROFILE      │  │  │
│   │  │              │ │              │ │                      │  │  │
│   │  │ • Auth0      │ │ • 4D Matrix  │ │ • Core Schema        │  │  │
│   │  │ • Google     │ │ • Trust Lvls │ │ • Custom Fields      │  │  │
│   │  │ • Email/Pass │ │ • Skills     │ │ • Encrypted Storage  │  │  │
│   │  │ • mTLS       │ │ • Zones      │ │                      │  │  │
│   │  │ • API Key    │ │              │ │                      │  │  │
│   │  │ • MFA        │ │              │ │                      │  │  │
│   │  └──────────────┘ └──────────────┘ └──────────────────────┘  │  │
│   └──────────────────────────────────────────────────────────────┘  │
│         │                    │                     │                 │
│         ▼                    ▼                     ▼                 │
│   ┌───────────┐        ┌───────────┐        ┌───────────┐           │
│   │F2 Session │        │F3 Observ. │        │F6 Infra   │           │
│   │(State)    │        │(Events)   │        │(DB/Secret)│           │
│   └───────────┘        └───────────┘        └───────────┘           │
└─────────────────────────────────────────────────────────────────────┘
                                │
                    Consumed by │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        DOMAIN LAYERS                                 │
│   D1: Agents    D2: UI    D3: Engine    D4: MCP    D5: Learning     │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Design Principles

| Principle | Description |
|-----------|-------------|
| **Zero Domain Knowledge** | IAM knows nothing about trading, cloud_accounts, or business logic. Skills like `execute_remediation` are injected via configuration. |
| **Configuration-Driven** | All behavior controlled via YAML. No hardcoded business rules. |
| **Provider Abstraction** | Authentication providers are pluggable. Auth0 is default but swappable. |
| **Event-Driven** | Every authentication and authorization action emits events for audit and observability. |
| **Fail-Secure** | Default deny. All access must be explicitly granted. |

---

## 3. Authentication System

### 3.1 Provider Hierarchy

The authentication system supports multiple providers in a priority hierarchy:

```
┌─────────────────────────────────────────────────────────────────┐
│                    AUTHENTICATION FLOW                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   AUTH0     │    │   GOOGLE    │    │  ENTERPRISE │         │
│  │  (Primary)  │    │ (Optional)  │    │    SSO      │         │
│  │             │    │             │    │  (Future)   │         │
│  │ • Universal │    │ • Social    │    │             │         │
│  │   Login     │    │   Login     │    │ • SAML 2.0  │         │
│  │ • MFA       │    │ • Quick     │    │ • OIDC      │         │
│  │ • SSO       │    │   Access    │    │             │         │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘         │
│         │                  │                  │                 │
│         └────────────┬─────┴──────────────────┘                 │
│                      ▼                                          │
│              ┌───────────────┐                                   │
│              │ TOKEN SERVICE │                                   │
│              │               │                                   │
│              │ • JWT Issue   │                                   │
│              │ • Validation  │                                   │
│              │ • Refresh     │                                   │
│              └───────┬───────┘                                   │
│                      │                                          │
│         ┌────────────┼────────────┐                             │
│         ▼            ▼            ▼                             │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐                     │
│  │EMAIL/PASS │ │   mTLS    │ │  API KEY  │                     │
│  │(Fallback) │ │ (Service) │ │ (Service) │                     │
│  └───────────┘ └───────────┘ └───────────┘                     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Auth0 Integration (Primary Provider)

Auth0 serves as the primary identity provider with the following configuration:

| Setting | Value | Description |
|---------|-------|-------------|
| **Domain** | `ai-cost-monitoring.auth0.com` | Auth0 tenant domain |
| **Protocol** | OIDC/OAuth 2.0 | Authorization Code Flow with PKCE |
| **Scopes** | `openid email profile` | Standard OIDC scopes |
| **Audience** | `https://api.ai-cost-monitoring.com` | API identifier |
| **Token Format** | JWT (RS256) | Asymmetric signing |

**Supported Connections:**
- Username/Password (Auth0 Database)
- Google OAuth 2.0
- Microsoft Azure AD
- GitHub (for developers)
- Enterprise SAML/OIDC (future)

**Auth0 Features Used:**
- Universal Login (hosted login page)
- Multi-factor Authentication
- Anomaly Detection
- Brute Force Protection
- Breached Password Detection

### 3.3 Email/Password Authentication (Fallback)

For environments without Auth0 connectivity, local authentication is available:

**Password Policy:**

| Requirement | Value |
|-------------|-------|
| Minimum Length | 12 characters |
| Uppercase | Required (1+) |
| Lowercase | Required (1+) |
| Numbers | Required (1+) |
| Special Characters | Required (1+) |
| Password History | Last 5 passwords |
| Expiration | 90 days (configurable) |

**Security Measures:**
- Passwords hashed using bcrypt (cost factor 12)
- Timing-attack resistant verification
- Account lockout after 5 failed attempts (15-minute window)
- Email verification required before first login

### 3.4 Service Authentication (Machine-to-Machine)

For service-to-service communication, two methods are supported:

#### 3.4.1 Mutual TLS (mTLS)

| Component | Description |
|-----------|-------------|
| **CA Certificate** | Platform CA stored in Secret Manager |
| **Client Certificates** | Issued per service with CN = service_id |
| **Validation** | Full chain verification + revocation check |
| **Identity Extraction** | Service ID from certificate CN |

**Use Cases:**
- Internal microservice communication
- A2A (Agent-to-Agent) protocol connections
- Database proxy authentication

#### 3.4.2 API Key Authentication

| Component | Description |
|-----------|-------------|
| **Header** | `X-API-Key` |
| **Format** | 64-character random string |
| **Storage** | Hashed in database, plaintext in Secret Manager |
| **Rotation** | Manual or automatic (90-day policy) |

**Use Cases:**
- External integrations (MCP servers)
- CI/CD pipeline access
- Monitoring and health checks

### 3.5 Multi-Factor Authentication (MFA)

MFA is **mandatory** for Trust Levels 3 and 4 (production access).

#### 3.5.1 TOTP (Time-based One-Time Password)

| Setting | Value |
|---------|-------|
| **Algorithm** | SHA-1 (RFC 6238 compatible) |
| **Digits** | 6 |
| **Period** | 30 seconds |
| **Tolerance** | ±1 interval (clock drift) |
| **Issuer** | "Nexus Cost Monitoring Platform" |

**Supported Authenticator Apps:**
- Google Authenticator
- Microsoft Authenticator
- Authy
- 1Password
- Any RFC 6238 compliant app

#### 3.5.2 WebAuthn (Hardware Keys / Biometrics)

| Setting | Value |
|---------|-------|
| **RP ID** | `ai-cost-monitoring.com` |
| **Attestation** | None (privacy-preserving) |
| **User Verification** | Preferred |
| **Resident Keys** | Preferred (passwordless ready) |
| **Algorithms** | ES256, RS256 |

**Supported Authenticators:**
- YubiKey (5 series recommended)
- Google Titan Security Key
- Apple Touch ID / Face ID
- Windows Hello
- Android Biometrics

### 3.6 Token Management

#### 3.6.1 Access Token

| Property | Value |
|----------|-------|
| **Format** | JWT (JSON Web Token) |
| **Algorithm** | RS256 (asymmetric) |
| **Lifetime** | 30 minutes |
| **Issuer** | Auth0 or IAM service |
| **Audience** | Nexus API identifier |

**Token Claims:**

| Claim | Description |
|-------|-------------|
| `sub` | User ID (UUID) |
| `email` | User email address |
| `trust_level` | Current trust level (1-4) |
| `zones` | Authorized zones array |
| `iat` | Issued at timestamp |
| `exp` | Expiration timestamp |
| `jti` | Unique token identifier |

#### 3.6.2 Refresh Token

| Property | Value |
|----------|-------|
| **Format** | Opaque string (128 characters) |
| **Lifetime** | 7 days |
| **Rotation** | Enabled (single use) |
| **Storage** | Database (hashed) |
| **Revocation** | On logout, password change, or security event |

#### 3.6.3 Session Management

| Setting | Value |
|---------|-------|
| **Max Concurrent Sessions** | 3 per user |
| **Session Timeout** | 30 minutes (idle) |
| **Absolute Timeout** | 24 hours |
| **Device Tracking** | Enabled |
| **Refresh on Activity** | Enabled |

---

## 4. Authorization System

### 4.1 4D Authorization Matrix

The authorization model uses a 4-dimensional matrix for fine-grained access control:

```
┌─────────────────────────────────────────────────────────────────────┐
│                    4D AUTHORIZATION MATRIX                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│                         ┌─────────┐                                  │
│                         │  ZONE   │                                  │
│                         │         │                                  │
│                         │ paper   │                                  │
│                         │ live    │                                  │
│                         │ admin   │                                  │
│                         │ system  │                                  │
│                         └────┬────┘                                  │
│                              │                                       │
│     ┌──────────┐        ┌────┴────┐        ┌──────────┐             │
│     │  ACTION  │────────│ AUTHZ   │────────│ RESOURCE │             │
│     │          │        │ DECISION│        │          │             │
│     │ view     │        │         │        │ own      │             │
│     │ create   │        │ ALLOW / │        │ workspace│             │
│     │ update   │        │ DENY    │        │ all      │             │
│     │ delete   │        │         │        │          │             │
│     │ execute  │        └────┬────┘        └──────────┘             │
│     └──────────┘             │                                       │
│                         ┌────┴────┐                                  │
│                         │  SKILL  │                                  │
│                         │         │                                  │
│                         │(domain  │                                  │
│                         │injected)│                                  │
│                         └─────────┘                                  │
│                                                                      │
│  Authorization Query: Can USER perform ACTION on SKILL               │
│                       for RESOURCE in ZONE?                          │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 Dimension Definitions

#### 4.2.1 ACTION Dimension

| Action | Description | Example |
|--------|-------------|---------|
| `view` | Read-only access | View portfolio positions |
| `create` | Create new resources | Create new watchlist |
| `update` | Modify existing resources | Update alert thresholds |
| `delete` | Remove resources | Delete workspace |
| `execute` | Perform operations | Execute trade order |

#### 4.2.2 SKILL Dimension (Domain-Injected)

Skills are defined by the domain layer and injected into IAM via configuration. IAM has no knowledge of what these skills mean.

**Trading Domain Skills:**

| Skill ID | Description | Required Trust |
|----------|-------------|----------------|
| `view_portfolio` | View positions and P&L | 1+ |
| `view_market_data` | Access real-time quotes | 1+ |
| `analyze_earnings` | Run earnings analysis | 2+ |
| `build_strategy` | Create trading policies | 2+ |
| `execute_remediation` | Place live orders | 3+ |
| `manage_risk` | Configure risk parameters | 3+ |
| `configure_system` | System administration | 4 |

#### 4.2.3 RESOURCE Dimension

| Scope | Description | Example |
|-------|-------------|---------|
| `own` | User's own resources only | Own cloud_accounts, own watchlists |
| `workspace` | Shared workspace resources | Team watchlists, shared policies |
| `all` | All resources (admin only) | All user cloud_accounts |

#### 4.2.4 ZONE Dimension

| Zone | Description | Access Level |
|------|-------------|--------------|
| `paper` | Paper trading / sandbox | All users |
| `live` | Live trading with real money | Trust 3+ |
| `admin` | Administrative functions | Trust 4 |
| `system` | Internal system operations | Services only |

### 4.3 Trust Levels

```
┌─────────────────────────────────────────────────────────────────────┐
│                        TRUST LEVEL HIERARCHY                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Level 4: ADMIN ────────────────────────────────────────────────    │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │ • All zones: paper, live, admin                            │     │
│  │ • All skills including configure_system                    │     │
│  │ • Resource scope: all                                      │     │
│  │ • MFA: REQUIRED (WebAuthn preferred)                       │     │
│  └────────────────────────────────────────────────────────────┘     │
│                              │                                       │
│  Level 3: PRODUCER ─────────┴───────────────────────────────────    │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │ • Zones: paper, live                                       │     │
│  │ • Skills: execute_remediation, manage_risk                       │     │
│  │ • Resource scope: own, workspace                           │     │
│  │ • MFA: REQUIRED                                            │     │
│  └────────────────────────────────────────────────────────────┘     │
│                              │                                       │
│  Level 2: OPERATOR ─────────┴───────────────────────────────────    │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │ • Zones: paper                                             │     │
│  │ • Skills: analyze_earnings, build_strategy                 │     │
│  │ • Resource scope: own, workspace                           │     │
│  │ • MFA: Optional                                            │     │
│  └────────────────────────────────────────────────────────────┘     │
│                              │                                       │
│  Level 1: VIEWER ───────────┴───────────────────────────────────    │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │ • Zones: paper (read-only)                                 │     │
│  │ • Skills: view_portfolio, view_market_data                 │     │
│  │ • Resource scope: own                                      │     │
│  │ • MFA: Optional                                            │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.4 Authorization Decision Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                   AUTHORIZATION DECISION FLOW                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Request: authorize(user_id, action, skill, resource, zone)         │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ 1. LOAD USER CONTEXT                                        │    │
│  │    • Trust level                                            │    │
│  │    • Authorized zones                                       │    │
│  │    • MFA status                                             │    │
│  └──────────────────────────┬──────────────────────────────────┘    │
│                             │                                        │
│                             ▼                                        │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ 2. CHECK ZONE ACCESS                                        │    │
│  │    • Is requested zone in user's authorized zones?          │    │
│  │    • DENY if zone not authorized                            │    │
│  └──────────────────────────┬──────────────────────────────────┘    │
│                             │                                        │
│                             ▼                                        │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ 3. CHECK MFA REQUIREMENT                                    │    │
│  │    • If zone is 'live' or 'admin', verify MFA completed     │    │
│  │    • DENY if MFA required but not verified                  │    │
│  └──────────────────────────┬──────────────────────────────────┘    │
│                             │                                        │
│                             ▼                                        │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ 4. CHECK SKILL PERMISSION                                   │    │
│  │    • Load skill definition from configuration               │    │
│  │    • Verify user's trust level >= skill requirement         │    │
│  │    • DENY if insufficient trust level                       │    │
│  └──────────────────────────┬──────────────────────────────────┘    │
│                             │                                        │
│                             ▼                                        │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ 5. CHECK RESOURCE SCOPE                                     │    │
│  │    • Determine resource ownership                           │    │
│  │    • Verify user can access requested scope                 │    │
│  │    • DENY if scope exceeds permissions                      │    │
│  └──────────────────────────┬──────────────────────────────────┘    │
│                             │                                        │
│                             ▼                                        │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ 6. CHECK ACTION PERMISSION                                  │    │
│  │    • Verify action is allowed for skill + trust level       │    │
│  │    • Apply any custom hooks (on_authorize)                  │    │
│  └──────────────────────────┬──────────────────────────────────┘    │
│                             │                                        │
│                             ▼                                        │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ 7. EMIT EVENT & RETURN DECISION                             │    │
│  │    • Emit: user.authorization_checked                       │    │
│  │    • Return: AuthzDecision(allowed, reason, context)        │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 5. User Profile System

### 5.1 Schema Definition

#### 5.1.1 Core Schema (Required)

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `user_id` | UUID | Primary Key | Unique user identifier |
| `email` | String | Unique, Verified | Primary email address |
| `email_verified` | Boolean | Default: false | Email verification status |
| `created_at` | Timestamp | Auto | Account creation time |
| `updated_at` | Timestamp | Auto | Last modification time |

#### 5.1.2 Core Schema (Optional)

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `name` | String | Max 100 chars | Display name |
| `avatar` | URL | Valid URL | Profile picture URL |
| `timezone` | String | IANA format | User's timezone |
| `locale` | String | BCP 47 | Language preference |

#### 5.1.3 Custom Fields (Domain-Injected)

Custom fields are defined by the domain layer and stored as JSONB:

**Trading Domain Custom Fields:**

| Field | Type | Storage | Description |
|-------|------|---------|-------------|
| `broker_credentials` | Encrypted JSON | Secret Manager | IB Gateway credentials, API keys |
| `risk_tolerance` | Enum | Database | `conservative`, `moderate`, `aggressive` |
| `default_position_size_pct` | Float (1.0-10.0) | Database | Default position size as % of portfolio |
| `trading_preferences` | JSON | Database | UI preferences, default settings |

### 5.2 Storage Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    USER PROFILE STORAGE                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                    PostgreSQL (F6)                          │    │
│  │                                                             │    │
│  │  Table: users                                               │    │
│  │  ├── user_id (PK)                                          │    │
│  │  ├── email (UNIQUE)                                        │    │
│  │  ├── email_verified                                        │    │
│  │  ├── name                                                  │    │
│  │  ├── avatar                                                │    │
│  │  ├── timezone                                              │    │
│  │  ├── locale                                                │    │
│  │  ├── trust_level                                           │    │
│  │  ├── custom_fields (JSONB)  ◄── Non-sensitive fields       │    │
│  │  ├── mfa_enabled                                           │    │
│  │  ├── mfa_methods (JSONB)                                   │    │
│  │  ├── created_at                                            │    │
│  │  └── updated_at                                            │    │
│  │                                                             │    │
│  │  Table: user_sessions                                       │    │
│  │  ├── session_id (PK)                                       │    │
│  │  ├── user_id (FK)                                          │    │
│  │  ├── refresh_token_hash                                    │    │
│  │  ├── device_info                                           │    │
│  │  ├── ip_address                                            │    │
│  │  ├── created_at                                            │    │
│  │  └── expires_at                                            │    │
│  │                                                             │    │
│  │  Table: webauthn_credentials                                │    │
│  │  ├── credential_id (PK)                                    │    │
│  │  ├── user_id (FK)                                          │    │
│  │  ├── public_key                                            │    │
│  │  ├── counter                                               │    │
│  │  └── created_at                                            │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│                              │ Encrypted reference                   │
│                              ▼                                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │               GCP Secret Manager (F6)                       │    │
│  │                                                             │    │
│  │  nexus-user-{user_id}-broker-credentials                   │    │
│  │  ├── ib_username                                           │    │
│  │  ├── ib_password (encrypted)                               │    │
│  │  ├── ib_account_id                                         │    │
│  │  └── api_keys[]                                            │    │
│  │                                                             │    │
│  │  nexus-user-{user_id}-totp-secret                          │    │
│  │  └── base32_secret                                         │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 5.3 Encryption Strategy

| Data Type | Encryption | Key Management |
|-----------|------------|----------------|
| Passwords | bcrypt (cost 12) | N/A (one-way hash) |
| TOTP Secrets | AES-256-GCM | Secret Manager |
| Broker Credentials | AES-256-GCM | Secret Manager |
| API Keys | SHA-256 hash | Database (hashed only) |
| Refresh Tokens | SHA-256 hash | Database (hashed only) |

---

## 6. Event System

### 6.1 Events Emitted

All IAM operations emit events to F3 Observability for audit and monitoring:

#### 6.1.1 Authentication Events

| Event | Trigger | Payload |
|-------|---------|---------|
| `user.authenticated` | Successful login | user_id, method, ip, device |
| `user.authentication_failed` | Failed login attempt | email, method, ip, reason |
| `user.mfa_verified` | MFA challenge passed | user_id, mfa_method |
| `user.mfa_failed` | MFA challenge failed | user_id, mfa_method, reason |
| `user.token_refreshed` | Token refresh | user_id, session_id |
| `user.logout` | User logout | user_id, session_id |
| `user.session_created` | New session started | user_id, session_id, device |
| `user.session_expired` | Session timeout | user_id, session_id, reason |

#### 6.1.2 Authorization Events

| Event | Trigger | Payload |
|-------|---------|---------|
| `user.authorization_checked` | Any authz check | user_id, action, skill, resource, zone, decision |
| `user.permission_denied` | Access denied | user_id, action, skill, resource, zone, reason |
| `user.zone_elevated` | Zone access granted | user_id, zone, granted_by |
| `user.trust_level_changed` | Trust level modified | user_id, old_level, new_level, changed_by |

#### 6.1.3 Profile Events

| Event | Trigger | Payload |
|-------|---------|---------|
| `user.profile_created` | New user registration | user_id, email, method |
| `user.profile_updated` | Profile modification | user_id, fields_changed |
| `user.custom_field_changed` | Custom field update | user_id, field_name |
| `user.credentials_rotated` | Broker creds updated | user_id, credential_type |
| `user.mfa_enrolled` | MFA setup completed | user_id, mfa_method |
| `user.mfa_removed` | MFA disabled | user_id, mfa_method, removed_by |

### 6.2 Event Routing

```
┌─────────────────────────────────────────────────────────────────────┐
│                      EVENT ROUTING                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  F1 IAM ──► Event Bus (F6 Pub/Sub)                                  │
│                    │                                                 │
│         ┌─────────┼─────────┬─────────────────┐                     │
│         ▼         ▼         ▼                 ▼                     │
│  ┌───────────┐ ┌─────────┐ ┌─────────────┐ ┌─────────────┐         │
│  │    F3     │ │   F4    │ │     F5      │ │     D5      │         │
│  │Observ.   │ │ SecOps  │ │  Self-Ops   │ │  Learning   │         │
│  │          │ │         │ │             │ │             │         │
│  │• Metrics │ │• Audit  │ │• Anomaly    │ │• User       │         │
│  │• Logs    │ │• Compli.│ │  Detection  │ │  Patterns   │         │
│  │• Traces  │ │• Alerts │ │• Auto-lock  │ │             │         │
│  └───────────┘ └─────────┘ └─────────────┘ └─────────────┘         │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 7. Public API Interface

### 7.1 Authentication Methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `authenticate` | credentials: Credentials | AuthResult | Authenticate user with any provider |
| `verify_token` | token: string | TokenClaims | Verify and decode JWT |
| `refresh_token` | refresh_token: string | TokenPair | Exchange refresh token for new tokens |
| `logout` | session_id: string | void | Terminate session and revoke tokens |
| `verify_mfa` | user_id: string, code: string, method: MFAMethod | MFAResult | Verify MFA challenge |
| `enroll_mfa` | user_id: string, method: MFAMethod | EnrollmentData | Start MFA enrollment |
| `complete_mfa_enrollment` | user_id: string, verification: any | void | Complete MFA setup |

### 7.2 Authorization Methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `authorize` | user_id, action, skill, resource, zone | AuthzDecision | Check if action is permitted |
| `get_user_permissions` | user_id: string | Permissions | Get all user permissions |
| `check_trust_level` | user_id: string, required: int | boolean | Check if user meets trust level |
| `get_authorized_zones` | user_id: string | Zone[] | Get user's authorized zones |
| `elevate_zone` | user_id: string, zone: string, duration: int | void | Temporarily grant zone access |

### 7.3 User Profile Methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `get_user` | user_id: string | User | Get user profile |
| `update_user` | user_id: string, updates: dict | User | Update profile fields |
| `set_custom_fields` | user_id: string, fields: dict | void | Update custom fields |
| `get_custom_field` | user_id: string, field: string | any | Get single custom field |
| `validate_profile` | user_id: string | ValidationResult | Validate profile completeness |
| `delete_user` | user_id: string | void | Delete user and all data (GDPR) |

### 7.4 Extensibility Hooks

| Hook | Trigger | Use Case |
|------|---------|----------|
| `on_authenticate` | After successful authentication | Add custom claims, sync external systems |
| `on_authorize` | During authorization check | Custom business rules, rate limiting |
| `on_user_created` | After new user registration | Initialize defaults, send welcome email |
| `on_profile_updated` | After profile modification | Sync risk settings to D3 Engine |
| `on_credentials_changed` | After credential update | Reconnect IB Gateway, validate connection |
| `on_trust_level_changed` | After trust level modification | Notify user, update session |

---

## 8. Configuration Reference

### 8.1 Complete Configuration Schema

```yaml
# f1-iam-config.yaml
module: iam
version: "1.2.0"

authentication:
  providers:
    auth0:
      enabled: true
      domain: ${AUTH0_DOMAIN}
      client_id: ${AUTH0_CLIENT_ID}
      client_secret: ${AUTH0_CLIENT_SECRET}
      audience: ${AUTH0_AUDIENCE}
      scopes: [openid, email, profile]
      connections:
        - database
        - google-oauth2
    
    google:
      enabled: false  # Use Auth0 federation instead
      client_id: ${GOOGLE_CLIENT_ID}
      client_secret: ${GOOGLE_CLIENT_SECRET}
    
    email_password:
      enabled: true  # Fallback only
      password_policy:
        min_length: 12
        require_uppercase: true
        require_lowercase: true
        require_number: true
        require_special: true
        password_history: 5
        expiration_days: 90
    
    service_auth:
      enabled: true
      methods:
        - type: mtls
          ca_cert: ${MTLS_CA_CERT}
          verify_crl: true
        - type: api_key
          header: X-API-Key
          rotation_days: 90
    
    mfa:
      enabled: true
      methods: [totp, webauthn]
      required_for_trust_levels: [3, 4]
      totp:
        issuer: "Nexus Cost Monitoring Platform"
        digits: 6
        period: 30
      webauthn:
        rp_id: ai-cost-monitoring.com
        rp_name: "Nexus Cost Monitoring Platform"
        attestation: none
        user_verification: preferred

authorization:
  model: 4d_matrix
  
  zones:
    - id: paper
      name: Paper Trading
      description: Simulated trading environment
    - id: live
      name: Live Trading
      description: Real money trading
      requires_mfa: true
    - id: admin
      name: Administration
      description: System configuration
      requires_mfa: true
    - id: system
      name: System
      description: Internal operations
      service_only: true
  
  trust_levels:
    - level: 1
      name: viewer
      description: Read-only access
      default_zones: [paper]
      allowed_scopes: [own]
    - level: 2
      name: operator
      description: Paper trading operations
      default_zones: [paper]
      allowed_scopes: [own, workspace]
    - level: 3
      name: producer
      description: Live trading operations
      default_zones: [paper, live]
      allowed_scopes: [own, workspace]
      requires_mfa: true
    - level: 4
      name: admin
      description: Full administrative access
      default_zones: [paper, live, admin]
      allowed_scopes: [own, workspace, all]
      requires_mfa: true
  
  skills: []  # Injected by domain layer
  
  resource_scoping:
    enabled: true
    scopes: [own, workspace, all]

user_profile:
  schema:
    required: [user_id, email]
    optional: [name, avatar, timezone, locale]
  
  custom_fields:
    enabled: true
    # Domain layer defines fields
  
  storage:
    backend: postgres
    table: users
    connection_pool: 10

tokens:
  access:
    algorithm: RS256
    lifetime_minutes: 30
    issuer: ${TOKEN_ISSUER}
  refresh:
    lifetime_days: 7
    rotation: true
    
session:
  max_concurrent: 3
  timeout_minutes: 30
  absolute_timeout_hours: 24
  device_tracking: true
  refresh_on_activity: true

security:
  rate_limiting:
    login_attempts: 5
    lockout_minutes: 15
  
  anomaly_detection:
    enabled: true
    alert_on:
      - impossible_travel
      - new_device
      - unusual_time
```

---

## 9. Integration Points

### 9.1 Foundation Module Dependencies

| Module | Integration | Purpose |
|--------|-------------|---------|
| **F2 Session** | Bidirectional | Session state, context injection |
| **F3 Observability** | Event emission | Logging, metrics, tracing |
| **F4 SecOps** | Event emission | Audit trail, compliance |
| **F5 Self-Ops** | Event emission | Anomaly detection, auto-remediation |
| **F6 Infrastructure** | Service consumption | Database, Secret Manager, Pub/Sub |

### 9.2 Domain Layer Consumers

| Layer | Usage | Integration Pattern |
|-------|-------|---------------------|
| **D1 Agents** | Skill authorization, user context | Direct API call |
| **D2 UI** | Login flows, permission-based rendering | REST API |
| **D3 Engine** | Trade authorization, zone checking | Direct API call |
| **D4 MCP** | Server access control, API key management | Direct API call |
| **D5 Learning** | User pattern analysis | Event subscription |

---

## 10. Security Considerations

### 10.1 Threat Model

| Threat | Mitigation |
|--------|------------|
| Credential stuffing | Rate limiting, Auth0 anomaly detection |
| Session hijacking | Short token lifetime, refresh rotation |
| Privilege escalation | 4D matrix, MFA for high-trust |
| Insider threat | Audit logging, least privilege |
| Token theft | HTTPS only, secure storage, short TTL |

### 10.2 Compliance

| Standard | Implementation |
|----------|----------------|
| **GDPR** | Data export, deletion API, consent tracking |
| **SOC 2** | Audit logging, access controls, encryption |
| **PCI DSS** | No card storage (broker handles), MFA |

### 10.3 Security Best Practices

1. **Never log sensitive data** — passwords, tokens, secrets excluded from logs
2. **Always use parameterized queries** — SQL injection prevention
3. **Validate all inputs** — injection, XSS prevention
4. **Encrypt data at rest and in transit** — TLS 1.3, AES-256
5. **Implement proper error handling** — no information leakage
6. **Regular security audits** — penetration testing, code review

---

## 11. Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Dec 2025 | Initial release: OAuth2, basic authorization |
| 1.1.0 | Jan 2026 | Added 4D authorization matrix, trust levels |
| 1.2.0 | Jan 2026 | Added Auth0 as primary provider, mTLS, WebAuthn, custom fields |

---

## 12. Future Roadmap

| Feature | Target Version | Description |
|---------|----------------|-------------|
| SAML 2.0 SSO | 1.3.0 | Enterprise SSO support |
| Passwordless | 1.3.0 | WebAuthn-only authentication |
| Fine-grained permissions | 1.4.0 | Per-resource permission overrides |
| Delegated administration | 1.4.0 | Workspace-level admin roles |
| Biometric binding | 1.5.0 | Device-bound credentials |

---

*F1 IAM Technical Specification v1.2.0 — AI Cost Monitoring Platform v4.2 — January 2026*
