# F2: Session & Context Management Module
## Technical Specification v1.1.0

**Module**: `ai-cost-monitoring/modules/session`  
**Version**: 1.1.0  
**Status**: Production Ready  
**Last Updated**: 2026-01-01T00:00:00

---

## 1. Executive Summary

The F2 Session & Context Management Module provides stateful session handling, multi-layer memory architecture, workspace management, and context injection for the AI Cost Monitoring Platform. It is **domain-agnostic** — storing and retrieving context without understanding its meaning.

### Key Capabilities

| Capability | Description |
|------------|-------------|
| **Session Management** | Lifecycle handling with device tracking and concurrent limits |
| **Multi-Layer Memory** | Three-tier memory (Session → Workspace → Profile) with promotion |
| **Workspaces** | Domain-defined workspace types with sharing capabilities |
| **Context Injection** | Automatic context enrichment for agents, UI, and events |
| **Domain Agnostic** | Zero knowledge of trading logic; all types injected via config |

---

## 2. Architecture Overview

### 2.1 Module Position

```
┌─────────────────────────────────────────────────────────────────────┐
│                      FOUNDATION MODULES                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │                   F2: Session v1.1.0                          │  │
│   │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌───────────┐  │  │
│   │  │  SESSION   │ │  MEMORY    │ │ WORKSPACE  │ │  CONTEXT  │  │  │
│   │  │            │ │            │ │            │ │           │  │  │
│   │  │• Lifecycle │ │• 3 Layers  │ │• Types     │ │• Assembly │  │  │
│   │  │• Device    │ │• Promotion │ │• Sharing   │ │• Injection│  │  │
│   │  │• Timeout   │ │• Snapshot  │ │• Binding   │ │• Targets  │  │  │
│   │  └────────────┘ └────────────┘ └────────────┘ └───────────┘  │  │
│   └──────────────────────────────────────────────────────────────┘  │
│         │                    │                     │                 │
│         ▼                    ▼                     ▼                 │
│   ┌───────────┐        ┌───────────┐        ┌───────────┐           │
│   │ F1 IAM    │        │F3 Observ. │        │F6 Infra   │           │
│   │(User)     │        │(Events)   │        │(DB/Cache) │           │
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
| **Zero Domain Knowledge** | F2 knows nothing about trading, watchlists, or policies. Workspace types and memory schemas are injected via configuration. |
| **Three-Tier Memory** | Ephemeral (session) → Persistent (workspace) → Long-term (profile) with explicit promotion |
| **Context-First** | All domain consumers receive enriched context automatically |
| **Event-Driven** | Every state change emits events for observability and audit |
| **Fail-Safe** | Session loss doesn't lose persistent data; graceful degradation |

---

## 3. Session Management

### 3.1 Session Lifecycle

```
┌─────────────────────────────────────────────────────────────────────┐
│                     SESSION LIFECYCLE                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐      │
│  │  CREATE  │───►│  ACTIVE  │───►│ REFRESH  │───►│TERMINATE │      │
│  │          │    │          │    │          │    │          │      │
│  │ Auth OK  │    │ In Use   │    │ Extended │    │ Cleanup  │      │
│  └──────────┘    └────┬─────┘    └──────────┘    └──────────┘      │
│                       │                                             │
│                       ▼                                             │
│                 ┌──────────┐                                        │
│                 │ EXPIRED  │                                        │
│                 │          │                                        │
│                 │ Timeout  │                                        │
│                 └──────────┘                                        │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.2 Session States

| State | Description | Transitions |
|-------|-------------|-------------|
| **CREATE** | New session after successful F1 authentication | → ACTIVE |
| **ACTIVE** | Session in use, receiving requests | → REFRESH, EXPIRED, TERMINATE |
| **REFRESH** | Session extended due to activity | → ACTIVE |
| **EXPIRED** | Session timed out (idle or absolute) | → TERMINATE |
| **TERMINATE** | Session ended, cleanup initiated | (final) |

### 3.3 Session Configuration

| Setting | Value | Description |
|---------|-------|-------------|
| **Idle Timeout** | 30 minutes | Time without activity before expiration |
| **Absolute Timeout** | 24 hours | Maximum session duration regardless of activity |
| **Max Concurrent** | 3 per user | Maximum simultaneous sessions per user |
| **Refresh on Activity** | Enabled | Extend idle timeout on each request |
| **Device Tracking** | Enabled | Track browser/device fingerprint |

### 3.4 Session Data Schema

| Field | Type | Description |
|-------|------|-------------|
| `session_id` | UUID | Primary key, unique session identifier |
| `user_id` | UUID | Foreign key to F1 IAM users table |
| `device_info` | JSONB | Browser fingerprint, OS, platform |
| `ip_address` | String | Client IP address |
| `user_agent` | String | Browser user agent string |
| `created_at` | Timestamp | Session creation time |
| `last_activity` | Timestamp | Last request timestamp |
| `expires_at` | Timestamp | Calculated expiration time |
| `active_workspace_id` | UUID | Currently bound workspace (nullable) |
| `metadata` | JSONB | Additional session metadata |

### 3.5 Device Tracking

Device tracking provides security and user experience features:

**Tracked Information:**

| Field | Source | Purpose |
|-------|--------|---------|
| Browser Fingerprint | Canvas, WebGL, fonts | Identify returning devices |
| Operating System | User-Agent parsing | Device categorization |
| Platform | Navigator.platform | Desktop/Mobile/Tablet |
| Screen Resolution | window.screen | Device identification |
| Timezone | Intl.DateTimeFormat | Anomaly detection |
| IP Geolocation | MaxMind GeoIP2 | Location tracking |

**Security Features:**

| Feature | Trigger | Action |
|---------|---------|--------|
| **New Device Alert** | Unknown fingerprint | Notify user, log event |
| **Impossible Travel** | Location change too fast | Alert F4 SecOps |
| **Concurrent Limit** | >3 sessions | Terminate oldest session |
| **IP Change** | Different IP same session | Re-verify if suspicious |

### 3.6 Storage Backends

F2 supports multiple storage backends for different environments:

| Backend | Use Case | Configuration |
|---------|----------|---------------|
| **Memory** | Development/Testing | In-process, max 100MB, lost on restart |
| **PostgreSQL** | Production (default) | Persistent, pooled connections, F6 managed |
| **Vertex AI** | AI Context (future) | For LLM conversation context |

---

## 4. Multi-Layer Memory System

### 4.1 Memory Architecture

The memory system implements a three-tier architecture with explicit promotion between layers:

```
┌─────────────────────────────────────────────────────────────────────┐
│                    MEMORY LAYER ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────┐                                                │
│  │  SESSION LAYER  │  Ephemeral • 30 min TTL • 100KB max            │
│  │                 │  Current conversation, active analysis          │
│  │  Storage: RAM   │                                                │
│  └────────┬────────┘                                                │
│           │ promote()                                               │
│           ▼                                                         │
│  ┌─────────────────┐                                                │
│  │ WORKSPACE LAYER │  Persistent • Unlimited TTL • 10MB/workspace   │
│  │                 │  Watchlists, policies, saved analyses         │
│  │  Storage: PG    │                                                │
│  └────────┬────────┘                                                │
│           │ promote()                                               │
│           ▼                                                         │
│  ┌─────────────────┐                                                │
│  │  PROFILE LAYER  │  Long-term • Permanent • External storage      │
│  │                 │  Trading patterns, learned preferences          │
│  │  Storage: A2A   │                                                │
│  └─────────────────┘                                                │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 Layer Definitions

#### 4.2.1 Session Layer (Ephemeral)

| Property | Value |
|----------|-------|
| **Scope** | Single session, lost on session end |
| **TTL** | 30 minutes (matches session timeout) |
| **Max Size** | 100KB per session |
| **Storage** | In-memory (Redis future) |
| **Use Cases** | Current conversation context, active analysis state, temporary calculations |

#### 4.2.2 Workspace Layer (Persistent)

| Property | Value |
|----------|-------|
| **Scope** | Workspace-specific, survives sessions |
| **TTL** | Unlimited (until deleted) |
| **Max Size** | 10MB per workspace |
| **Storage** | PostgreSQL (JSONB) |
| **Use Cases** | Watchlists, policies, saved analyses, alerts |

#### 4.2.3 Profile Layer (Long-Term)

| Property | Value |
|----------|-------|
| **Scope** | User-wide, cross-workspace |
| **TTL** | Permanent |
| **Max Size** | Unlimited (external storage) |
| **Storage** | A2A Knowledge Platform (external) |
| **Use Cases** | Trading patterns, learned preferences, historical insights |

### 4.3 Memory Operations

| Operation | Parameters | Description |
|-----------|------------|-------------|
| `get` | session_id, layer, key | Retrieve value from specified layer |
| `set` | session_id, layer, key, value | Store value in specified layer |
| `delete` | session_id, layer, key | Remove specific key from layer |
| `clear` | session_id, layer | Clear entire layer |
| `snapshot` | session_id, layer | Get complete layer as dictionary |
| `promote` | session_id, key, source_layer, target_layer | Move data to higher layer |

### 4.4 Memory Promotion Flow

Users can explicitly promote valuable insights up the memory hierarchy:

| Source | Target | Trigger | Example |
|--------|--------|---------|---------|
| Session | Workspace | User saves analysis | "Save to watchlist" |
| Workspace | Profile | User confirms learning | "Remember this approach" |

---

## 5. Workspace System

### 5.1 Workspace Concept

Workspaces are persistent, typed containers for user work:
- Persist across sessions
- Have domain-defined schemas
- Support sharing between users
- Bind to sessions for context injection

### 5.2 Workspace Types (Domain-Injected)

**Trading Domain Workspace Types:**

| Type | Schema | Description |
|------|--------|-------------|
| **watchlist** | symbols[], alerts[], notes | Stock watchlist with price alerts |
| **strategy** | config{}, backtest{}, live_status | Trading strategy definition |
| **analysis** | ticker, data{}, predictions{} | Earnings/technical analysis |
| **portfolio** | positions[], risk_params{}, zone | Portfolio configuration |

### 5.3 Workspace Schema

| Field | Type | Description |
|-------|------|-------------|
| `workspace_id` | UUID | Primary key |
| `user_id` | UUID | Owner (FK to F1 IAM) |
| `type` | String | Domain-defined type |
| `name` | String | User-friendly name |
| `data` | JSONB | Type-specific data |
| `sharing` | Enum | private, shared, public |
| `shared_with` | UUID[] | User IDs with access |
| `created_at` | Timestamp | Creation time |
| `updated_at` | Timestamp | Last modification |

### 5.4 Workspace Limits

| Limit | Value |
|-------|-------|
| Max per User | 50 |
| Max Size | 10MB |
| Name Length | 100 chars |
| Shared With | 20 users |

### 5.5 Workspace Sharing

| Mode | Description | Permissions |
|------|-------------|-------------|
| **Private** | Only owner can access | Full CRUD |
| **Shared** | Specific users can access | Owner: CRUD, Others: Read + Update |
| **Public** | All users can access | Owner: CRUD, Others: Read only |

---

## 6. Context Injection System

### 6.1 Context Assembly

Context is assembled from multiple sources:

| Section | Contents | Source |
|---------|----------|--------|
| **user** | user_id, email, trust_level, permissions | F1 IAM |
| **session** | session_id, device, started_at | Session data |
| **memory** | session layer snapshot | Session memory |
| **workspace** | workspace_id, type, name, data | Active workspace |
| **environment** | timestamp, market_status, zone | System |

### 6.2 Injection Targets

| Target | Data Included | Purpose |
|--------|---------------|---------|
| **D1 Agent Prompts** | User profile, session memory, workspace | Enriched system prompts |
| **D2 UI Components** | Permissions, workspace, preferences | Permission-based rendering |
| **F3 Events** | session_id, user_id, workspace_id | Event metadata |

### 6.3 Context Operations

| Operation | Parameters | Description |
|-----------|------------|-------------|
| `get_context` | session_id, target | Get context for specific target |
| `get_full_context` | session_id | Get complete assembled context |
| `enrich_context` | context, data | Add custom data |
| `inject_context` | target, context | Push to target system |

---

## 7. Event System

### 7.1 Events Emitted

#### Session Events

| Event | Trigger | Payload |
|-------|---------|---------|
| `session.created` | New session | session_id, user_id, device_info |
| `session.refreshed` | Timeout extended | session_id, new_expires_at |
| `session.terminated` | Session ended | session_id, reason |

#### Memory Events

| Event | Trigger | Payload |
|-------|---------|---------|
| `memory.updated` | Value changed | session_id, layer, key |
| `memory.promoted` | Data moved up | session_id, key, from_layer, to_layer |
| `memory.cleared` | Layer cleared | session_id, layer |

#### Workspace Events

| Event | Trigger | Payload |
|-------|---------|---------|
| `workspace.created` | New workspace | workspace_id, user_id, type |
| `workspace.switched` | Active changed | session_id, old_workspace, new_workspace |
| `workspace.shared` | Sharing changed | workspace_id, sharing_mode |

#### Context Events

| Event | Trigger | Payload |
|-------|---------|---------|
| `context.assembled` | Context built | session_id, target |
| `context.injected` | Context pushed | session_id, target |

---

## 8. Public API Interface

### 8.1 Session Methods

| Method | Parameters | Returns |
|--------|------------|---------|
| `create_session` | user_id, device_info | Session |
| `get_session` | session_id | Session |
| `refresh_session` | session_id | Session |
| `terminate_session` | session_id | void |
| `list_user_sessions` | user_id | Session[] |

### 8.2 Memory Methods

| Method | Parameters | Returns |
|--------|------------|---------|
| `get_memory` | session_id, layer, key | any |
| `set_memory` | session_id, layer, key, value | void |
| `clear_memory` | session_id, layer | void |
| `get_layer_snapshot` | session_id, layer | dict |
| `promote_memory` | session_id, key, from, to | void |

### 8.3 Workspace Methods

| Method | Parameters | Returns |
|--------|------------|---------|
| `create_workspace` | user_id, type, name | Workspace |
| `get_workspace` | workspace_id | Workspace |
| `update_workspace` | workspace_id, data | Workspace |
| `delete_workspace` | workspace_id | void |
| `switch_workspace` | session_id, workspace_id | void |
| `list_workspaces` | user_id, type? | Workspace[] |

### 8.4 Context Methods

| Method | Parameters | Returns |
|--------|------------|---------|
| `get_context` | session_id, target | Context |
| `get_full_context` | session_id | Context |
| `enrich_context` | context, data | Context |

### 8.5 Extensibility Hooks

| Hook | Trigger | Use Case |
|------|---------|----------|
| `on_session_created` | After session creation | Initialize defaults |
| `on_session_terminated` | Before cleanup | Save important data |
| `on_workspace_switched` | After workspace change | Load resources |
| `on_context_inject` | Before injection | Add custom fields |

---

## 9. Integration Points

### 9.1 Foundation Dependencies

| Module | Integration | Purpose |
|--------|-------------|---------|
| **F1 IAM** | User profile, permissions | Context enrichment |
| **F3 Observability** | Event emission | Logging, metrics |
| **F4 SecOps** | Device anomaly alerts | Security |
| **F6 Infrastructure** | Database, cache | Storage |

### 9.2 Domain Consumers

| Layer | Usage |
|-------|-------|
| **D1 Agents** | Context injection |
| **D2 UI** | Session state, workspace |
| **D3 Engine** | Trading context |
| **D4 MCP** | Server session binding |

---

## 10. Security Considerations

### 10.1 Data Protection

| Data Type | Protection |
|-----------|------------|
| Session tokens | Cryptographically random, hashed |
| Memory data | Encrypted at rest |
| Workspace data | User-isolated |

### 10.2 Access Control

| Resource | Control |
|----------|---------|
| Session | Own sessions only |
| Memory | Layer-specific isolation |
| Workspace | Owner + shared users |

---

## 11. Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Dec 2025 | Initial release |
| 1.1.0 | Jan 2026 | Multi-layer memory, workspaces, context injection |

---

## 12. Future Roadmap

| Feature | Version | Description |
|---------|---------|-------------|
| Redis backend | 1.2.0 | High-performance session storage |
| Vertex AI context | 1.2.0 | LLM conversation context |
| Workspace templates | 1.3.0 | Pre-built workspace configurations |
| Cross-device sync | 1.3.0 | Real-time session sync |
| Memory search | 1.4.0 | Full-text search in profile layer |

---

*F2 Session Technical Specification v1.1.0 — AI Cost Monitoring Platform v4.2 — January 2026*
