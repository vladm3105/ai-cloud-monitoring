# F2: Session & Context Management Module
## AI Cloud Cost Monitoring - Specification

**Module**: `ai-cost-monitoring/foundation/session`
**Version**: 1.0.0
**Status**: Draft
**Source**: Trading Nexus F2 v1.1.0 (adapted)
**Date**: February 2026

---

## 1. Executive Summary

The F2 Session Module manages conversation context for the AG-UI (Agent-to-UI) conversational interface. Per ADR-007, the platform provides both Grafana dashboards AND natural language queries via CopilotKit — F2 enables the conversational experience.

### Key Capabilities

| Capability | Description |
|------------|-------------|
| **Conversation Context** | Multi-turn conversation history for AG-UI |
| **Agent Execution State** | Track in-flight agent operations |
| **User Preferences** | Timezone, default cloud, display settings |
| **Streaming Management** | SSE connection state for AG-UI protocol |
| **Context Persistence** | Firestore (MVP), Redis (scale) |

### Why F2 is MVP-Critical

From ADR-007:
> "AG-UI: Ad-hoc questions, root cause analysis, complex queries"

Example multi-turn conversation requiring context:
```
User: "What's my AWS spend this month?"
Agent: "Your AWS spend is $12,450..."

User: "What caused the increase?"     ← Requires previous context
Agent: "The $3,200 increase was due to EC2..."

User: "Can you stop those idle instances?"  ← Requires full conversation
Agent: "I found 5 idle instances. Approve to stop?"
```

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                 F2: SESSION MODULE v1.0.0                        │
├─────────────────────────────────────────────────────────────────┤
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐       │
│  │ CONVERSATION  │  │    AGENT      │  │     USER      │       │
│  │   CONTEXT     │  │    STATE      │  │  PREFERENCES  │       │
│  │               │  │               │  │               │       │
│  │ • History     │  │ • In-flight   │  │ • Timezone    │       │
│  │ • References  │  │ • Streaming   │  │ • Defaults    │       │
│  │ • Summaries   │  │ • Progress    │  │ • UI config   │       │
│  └───────────────┘  └───────────────┘  └───────────────┘       │
│           │                 │                 │                 │
│           └────────────────┼────────────────┘                  │
│                            ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              SESSION STORAGE                             │   │
│  │   Firestore (MVP) → Redis (Scale)                       │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
            ┌─────────────┐     ┌─────────────┐
            │   AG-UI     │     │   AGENTS    │
            │   Server    │     │ (Coordinator)│
            └─────────────┘     └─────────────┘
```

---

## 3. Conversation Context

### 3.1 Context Structure

```python
@dataclass
class ConversationContext:
    """Conversation state for AG-UI sessions."""
    conversation_id: str
    tenant_id: str
    user_id: str
    created_at: datetime
    updated_at: datetime

    # Conversation history
    messages: List[Message]  # Last N messages
    summary: Optional[str]   # LLM-generated summary for long convos

    # Reference tracking
    referenced_resources: List[ResourceRef]  # Resources mentioned
    referenced_time_ranges: List[TimeRange]  # Time periods discussed
    referenced_cloud_accounts: List[str]     # Cloud accounts in scope

    # Agent state
    pending_actions: List[PendingAction]  # Awaiting approval
    last_agent: Optional[str]  # Last agent that responded

@dataclass
class Message:
    """Single conversation message."""
    role: str  # user, assistant, system
    content: str
    timestamp: datetime
    agent: Optional[str]  # Which agent generated
    tool_calls: List[ToolCall]  # MCP tools used
    metadata: dict
```

### 3.2 Context Window Management

Long conversations require summarization to fit LLM context windows:

```python
class ContextManager:
    MAX_MESSAGES = 20  # Keep last 20 messages verbatim
    MAX_TOKENS = 8000  # LLM context budget for history

    async def get_context_for_agent(
        self,
        conversation_id: str
    ) -> AgentContext:
        """Build context for agent execution."""
        context = await self.load_context(conversation_id)

        if len(context.messages) > self.MAX_MESSAGES:
            # Summarize older messages
            context.summary = await self.summarize_old_messages(
                context.messages[:-self.MAX_MESSAGES]
            )
            context.messages = context.messages[-self.MAX_MESSAGES:]

        return AgentContext(
            summary=context.summary,
            recent_messages=context.messages,
            referenced_resources=context.referenced_resources,
            pending_actions=context.pending_actions
        )
```

### 3.3 Reference Tracking

Track what the conversation is "about" for follow-up questions:

```python
@dataclass
class ResourceRef:
    """A cloud resource referenced in conversation."""
    resource_type: str  # ec2_instance, gcs_bucket, etc.
    resource_id: str
    cloud_provider: str
    first_mentioned: datetime
    context: str  # Why it was mentioned

@dataclass
class TimeRange:
    """A time period discussed in conversation."""
    start: date
    end: date
    description: str  # "this month", "last week", etc.
```

Example tracking:
```
User: "Show me AWS costs for January"
→ TimeRange(start=2026-01-01, end=2026-01-31, description="January 2026")

Agent: "EC2 instance i-abc123 is costing $500/month"
→ ResourceRef(type="ec2_instance", id="i-abc123", provider="aws")

User: "Stop it"  ← Resolves to i-abc123 via context
```

---

## 4. Agent Execution State

### 4.1 In-Flight Operations

Track agent operations for streaming progress and recovery:

```python
@dataclass
class AgentExecution:
    """Tracks an in-flight agent operation."""
    execution_id: str
    conversation_id: str
    agent: str  # coordinator, cost_agent, etc.
    status: str  # pending, running, streaming, completed, failed
    started_at: datetime
    updated_at: datetime

    # Progress tracking
    current_step: str
    steps_completed: List[str]
    progress_percent: int

    # Streaming state
    sse_connection_id: Optional[str]
    tokens_streamed: int

    # Results
    result: Optional[dict]
    error: Optional[str]
```

### 4.2 Pending Actions

Track actions awaiting user approval:

```python
@dataclass
class PendingAction:
    """An action awaiting user approval."""
    action_id: str
    conversation_id: str
    action_type: str  # stop_instance, resize, delete, etc.
    target_resource: ResourceRef
    risk_level: str  # low, medium, high
    created_at: datetime
    expires_at: datetime  # Auto-expire after 1 hour

    # Approval requirements
    required_role: str  # operator, org_admin
    approver_id: Optional[str]
    approved_at: Optional[datetime]

    # Action details
    parameters: dict
    estimated_impact: str  # "Save $50/month"
    rollback_available: bool
```

---

## 5. User Preferences

### 5.1 Preference Schema

```python
@dataclass
class UserPreferences:
    """User-specific settings persisted in session."""
    user_id: str
    tenant_id: str

    # Display preferences
    timezone: str  # e.g., "America/New_York"
    currency: str  # USD, EUR, etc.
    date_format: str  # YYYY-MM-DD, MM/DD/YYYY

    # Default cloud context
    default_cloud_provider: Optional[str]  # gcp, aws, azure
    default_cloud_accounts: List[str]  # Pre-filter queries

    # Notification preferences
    email_notifications: bool
    slack_notifications: bool
    notification_threshold: float  # Alert if cost > threshold

    # UI preferences
    dark_mode: bool
    compact_responses: bool  # Prefer shorter answers
```

### 5.2 Preference Loading

```python
class PreferenceManager:
    async def get_or_create_preferences(
        self,
        user_id: str,
        tenant_id: str
    ) -> UserPreferences:
        """Load user preferences or create defaults."""
        prefs = await self.store.get(f"prefs:{user_id}")
        if not prefs:
            prefs = UserPreferences(
                user_id=user_id,
                tenant_id=tenant_id,
                timezone=await self.infer_timezone(user_id),
                currency="USD",
                date_format="YYYY-MM-DD"
            )
            await self.store.set(f"prefs:{user_id}", prefs)
        return prefs
```

---

## 6. AG-UI Streaming Support

### 6.1 SSE Connection Management

AG-UI uses Server-Sent Events for streaming responses:

```python
@dataclass
class StreamingSession:
    """Active SSE connection for AG-UI streaming."""
    connection_id: str
    conversation_id: str
    user_id: str
    connected_at: datetime
    last_event_at: datetime

    # Connection health
    ping_count: int
    missed_pings: int

    # Streaming state
    current_execution_id: Optional[str]
    events_sent: int
    bytes_sent: int
```

### 6.2 Stream Recovery

Handle reconnection for dropped SSE connections:

```python
class StreamManager:
    async def handle_reconnect(
        self,
        conversation_id: str,
        last_event_id: str
    ) -> AsyncIterator[SSEEvent]:
        """Resume streaming from last event."""
        execution = await self.get_execution(conversation_id)

        if execution.status == "streaming":
            # Resume in-progress stream
            async for event in self.replay_from(last_event_id):
                yield event
        elif execution.status == "completed":
            # Send final result
            yield SSEEvent(
                type="result",
                data=execution.result
            )
```

---

## 7. Storage Backend

### 7.1 Firestore Schema (MVP)

```
sessions/
  {conversation_id}/
    metadata: ConversationContext
    messages/
      {message_id}: Message
    executions/
      {execution_id}: AgentExecution
    pending_actions/
      {action_id}: PendingAction

users/
  {user_id}/
    preferences: UserPreferences
    conversations/
      {conversation_id}: ConversationRef
```

### 7.2 Redis Schema (Scale)

For high-throughput scenarios:

```
# Conversation context (7-day TTL)
session:{conversation_id}:context → JSON(ConversationContext)
session:{conversation_id}:messages → List[JSON(Message)]

# Active executions (1-hour TTL)
execution:{execution_id} → JSON(AgentExecution)

# User preferences (30-day TTL)
prefs:{user_id} → JSON(UserPreferences)

# Streaming connections (5-minute TTL)
stream:{connection_id} → JSON(StreamingSession)
```

### 7.3 Configuration

```yaml
# f2-session-config.yaml
session:
  storage:
    backend: firestore  # firestore, redis
    project: ${GCP_PROJECT}

  conversation:
    max_messages: 100
    context_window: 20
    ttl_days: 7

  execution:
    timeout_seconds: 300
    ttl_hours: 1

  streaming:
    ping_interval_seconds: 30
    max_missed_pings: 3
    reconnect_window_seconds: 60
```

---

## 8. Public Interface

```python
class SessionModule:
    """Foundation Module F2: Session & Context Management"""

    # Conversation management
    async def create_conversation(
        self,
        tenant_id: str,
        user_id: str
    ) -> str:
        """Create new conversation, return conversation_id."""

    async def add_message(
        self,
        conversation_id: str,
        message: Message
    ) -> None:
        """Add message to conversation history."""

    async def get_context(
        self,
        conversation_id: str
    ) -> ConversationContext:
        """Get full conversation context for agent."""

    # Agent execution
    async def start_execution(
        self,
        conversation_id: str,
        agent: str
    ) -> str:
        """Start agent execution, return execution_id."""

    async def update_execution(
        self,
        execution_id: str,
        status: str,
        progress: Optional[int] = None
    ) -> None:
        """Update execution progress."""

    # Pending actions
    async def create_pending_action(
        self,
        conversation_id: str,
        action: PendingAction
    ) -> str:
        """Create action awaiting approval."""

    async def approve_action(
        self,
        action_id: str,
        approver_id: str
    ) -> PendingAction:
        """Approve pending action."""

    # User preferences
    async def get_preferences(
        self,
        user_id: str
    ) -> UserPreferences:
        """Get user preferences."""

    async def update_preferences(
        self,
        user_id: str,
        updates: dict
    ) -> UserPreferences:
        """Update user preferences."""
```

---

## 9. Dependencies

| Module | Dependency Type | Description |
|--------|----------------|-------------|
| **F1 IAM** | Upstream | User identity, tenant context |
| **F7 Config** | Upstream | Session configuration |
| **F3 Observability** | Downstream | Session metrics, conversation logs |
| **AG-UI Server** | Downstream | Conversation management |
| **Agents** | Downstream | Context injection |

---

## 10. Events

| Event | Description |
|-------|-------------|
| `session.conversation.created` | New conversation started |
| `session.message.added` | Message added to conversation |
| `session.execution.started` | Agent execution began |
| `session.execution.completed` | Agent execution finished |
| `session.action.pending` | Action awaiting approval |
| `session.action.approved` | Action was approved |
| `session.action.expired` | Action expired without approval |

---

## 11. MVP Scope

### Included in MVP

- [x] Conversation context persistence (Firestore)
- [x] Message history with summarization
- [x] Reference tracking (resources, time ranges)
- [x] Agent execution state
- [x] Pending action management
- [x] User preferences
- [x] Basic SSE streaming support

### Phase 2 (Scale)

- [ ] Redis backend for high throughput
- [ ] Cross-device session sync
- [ ] Conversation search/history
- [ ] Advanced context compression

---

*Adapted from Trading Nexus F2 v1.1.0 — February 2026*
