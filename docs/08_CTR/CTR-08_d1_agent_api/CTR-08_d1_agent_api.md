---
title: "CTR-08: D1 Agent Orchestration API Contract"
tags:
  - ctr
  - layer-8-artifact
  - d1-agent-orchestration
  - domain-module
  - shared-architecture
  - api-contract
  - sse-streaming
custom_fields:
  document_type: ctr
  artifact_type: CTR
  layer: 8
  module_id: D1
  module_name: Agent Orchestration
  spec_ready_score: 92
  schema_version: "1.0"
---

# CTR-08: D1 Agent Orchestration API Contract

## Document Control

| Item | Details |
|------|---------|
| **CTR ID** | CTR-08 |
| **Title** | D1 Agent Orchestration API Contract |
| **Status** | Active |
| **Version** | 1.0.0 |
| **Created** | 2026-02-11 |
| **Author** | Platform Architecture Team |
| **Owner** | AI Platform Team |
| **Last Updated** | 2026-02-11 |
| **SPEC-Ready Score** | ✅ 92% (Target: ≥90%) |

---

## 1. Contract Overview

### 1.1 Purpose

This contract defines the AG-UI (Agent-User Interface) streaming API for the D1 Agent Orchestration module, providing real-time conversational AI capabilities using Server-Sent Events (SSE).

### 1.2 Scope

| Aspect | Coverage |
|--------|----------|
| **Chat Interface** | SSE-based streaming responses |
| **Intent Classification** | Query routing and categorization |
| **Tool Execution** | Real-time tool call updates |
| **Conversation Management** | Multi-turn conversation support |

### 1.3 Protocol

**Primary Protocol**: Server-Sent Events (SSE)
**Content-Type**: `text/event-stream`
**Fallback**: JSON response for non-streaming clients

### 1.4 Contract Definition

**OpenAPI Specification**: [CTR-08_d1_agent_api.yaml](CTR-08_d1_agent_api.yaml)

---

## 2. Business Context

### 2.1 Business Need

D1 Agent Orchestration provides the conversational AI interface for cost analysis queries. Users interact with the system through natural language, and the agent orchestrates tool calls to retrieve and analyze cloud cost data.

### 2.2 Source Requirements

| Source | Reference | Description |
|--------|-----------|-------------|
| REQ-08 | Section 4.1 | SSE streaming API contract |
| REQ-08 | Section 4.2 | Event and intent schemas |

---

## 3. Interface Definitions

### 3.1 Chat Endpoints

#### CTR.08.16.01: Chat Stream Endpoint

| Attribute | Value |
|-----------|-------|
| **Path** | `POST /api/v1/chat` |
| **Description** | Initiate streaming chat conversation |
| **Protocol** | SSE (Server-Sent Events) |
| **Authentication** | Bearer token |
| **Rate Limit** | 10 requests/minute per user |

#### CTR.08.16.02: Chat History Endpoint

| Attribute | Value |
|-----------|-------|
| **Path** | `GET /api/v1/chat/{conversation_id}/history` |
| **Description** | Get conversation history |
| **Authentication** | Bearer token |
| **Rate Limit** | 30 requests/minute per user |

#### CTR.08.16.03: Conversation List Endpoint

| Attribute | Value |
|-----------|-------|
| **Path** | `GET /api/v1/conversations` |
| **Description** | List user conversations |
| **Authentication** | Bearer token |
| **Rate Limit** | 30 requests/minute per user |

### 3.2 SSE Event Types

| Event Type | Purpose | Data Format |
|------------|---------|-------------|
| `status` | Processing state updates | `{type: "thinking"|"executing"|"complete"}` |
| `message` | Text content delivery | `{type: "text", content: "..."}` |
| `tool_call` | Tool execution updates | `{type: "tool", name: "...", result: {...}}` |
| `error` | Error notifications | `{type: "error", code: "...", message: "..."}` |

---

## 4. Data Models

### 4.1 Request Models

#### CTR.08.17.01: ChatRequest

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| `message` | string | Yes | 1-4000 chars | User message |
| `session_id` | string | Yes | Non-empty | Session identifier |
| `conversation_id` | string | No | UUID | Existing conversation |

### 4.2 SSE Event Models

#### CTR.08.17.02: StreamEvent

| Field | Type | Description |
|-------|------|-------------|
| `type` | enum | Event type: text, tool_call, status |
| `content` | string | Text content (for text events) |
| `tool_name` | string | Tool name (for tool_call events) |
| `tool_result` | object | Tool execution result |
| `status` | enum | Status: thinking, executing, complete |

#### CTR.08.17.03: IntentResult

| Field | Type | Description |
|-------|------|-------------|
| `category` | enum | cost_query, cost_forecast, optimization, general |
| `confidence` | float | 0.0-1.0 confidence score |
| `entities` | object | Extracted entities (dates, services, etc.) |
| `suggested_tools` | array | Tools to execute |

### 4.3 Response Models

#### CTR.08.17.04: ConversationSummary

| Field | Type | Description |
|-------|------|-------------|
| `conversation_id` | string | Conversation identifier |
| `title` | string | Auto-generated title |
| `created_at` | datetime | Creation timestamp |
| `last_message_at` | datetime | Last message timestamp |
| `message_count` | integer | Number of messages |

---

## 5. Error Handling

### 5.1 SSE Error Events

Errors during streaming are delivered as SSE events:

```text
event: error
data: {"type": "error", "code": "AGENT_001", "message": "Intent classification failed"}
```

### 5.2 Error Catalog

#### CTR.08.20.01: Agent Errors

| Error Code | Condition | Message | Recovery |
|------------|-----------|---------|----------|
| AGENT_001 | Intent failed | Unable to understand query | Retry with clearer phrasing |
| AGENT_002 | Tool timeout | Tool execution timed out | Auto-retry (1x) |
| AGENT_003 | Context overflow | Conversation too long | Start new conversation |
| AGENT_004 | Stream interrupted | Connection lost | Client reconnect |

---

## 6. Usage Examples

### 6.1 Initiate Chat Stream

**Request**:
```http
POST /api/v1/chat HTTP/1.1
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
Accept: text/event-stream
Content-Type: application/json

{
  "message": "What were my top cloud costs last month?",
  "session_id": "sess_abc123",
  "conversation_id": "conv_xyz789"
}
```

**Response** (SSE Stream):
```text
event: status
data: {"type": "thinking", "content": "Analyzing your query..."}

event: message
data: {"type": "text", "content": "I'll analyze your GCP billing data for last month."}

event: tool_call
data: {"type": "tool", "name": "cost_query", "status": "executing"}

event: tool_call
data: {"type": "tool", "name": "cost_query", "result": {"total": 45678.90, "top_service": "Compute Engine"}}

event: message
data: {"type": "text", "content": "Based on your billing data, your top costs last month were:\n\n1. **Compute Engine**: $23,456.78 (51%)\n2. **BigQuery**: $12,345.67 (27%)\n3. **Cloud Storage**: $5,678.90 (12%)"}

event: status
data: {"type": "complete"}
```

### 6.2 Get Conversation History

**Request**:
```http
GET /api/v1/chat/conv_xyz789/history HTTP/1.1
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response** (200 OK):
```json
{
  "conversation_id": "conv_xyz789",
  "messages": [
    {
      "role": "user",
      "content": "What were my top cloud costs last month?",
      "timestamp": "2026-02-11T10:30:00Z"
    },
    {
      "role": "assistant",
      "content": "Based on your billing data, your top costs last month were...",
      "timestamp": "2026-02-11T10:30:05Z",
      "tool_calls": [
        {"name": "cost_query", "result": {"total": 45678.90}}
      ]
    }
  ]
}
```

---

## 7. Security Considerations

### 7.1 Authentication

All endpoints require valid JWT bearer token.

### 7.2 Rate Limiting

| Endpoint | Limit | Window |
|----------|-------|--------|
| `/api/v1/chat` | 10 | per minute |
| `/api/v1/chat/*/history` | 30 | per minute |
| `/api/v1/conversations` | 30 | per minute |

### 7.3 SSE Connection

- Max connection duration: 5 minutes
- Heartbeat: every 30 seconds
- Auto-reconnect supported via `Last-Event-ID`

---

## 8. Traceability

### 8.1 Cumulative Tags

```markdown
@brd: BRD.08.01.01
@prd: PRD.08.07.01
@ears: EARS.08.25.01
@bdd: BDD.08.14.01
@adr: ADR-08
@sys: SYS.08.26.01
@req: REQ.08.01.01
```

---

**Document Version**: 1.0.0
**SPEC-Ready Score**: 92%
**Last Updated**: 2026-02-11T19:00:00
