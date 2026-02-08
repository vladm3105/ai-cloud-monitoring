# F3: Observability Module
## AI Cloud Cost Monitoring - Adapted Specification

**Module**: `ai-cost-monitoring/foundation/observability`
**Version**: 1.0.0
**Status**: Draft
**Source**: Trading Nexus F3 v1.3.0 (adapted)
**Date**: February 2026

---

## 1. Executive Summary

The F3 Observability Module provides logging, metrics, tracing, and alerting for the AI Cloud Cost Monitoring platform. For a FinOps platform, **LLM cost observability is critical** — we must track what we spend on AI to monitor cloud costs.

### Key Capabilities

| Capability | Description |
|------------|-------------|
| **Structured Logging** | JSON logs with correlation IDs to Cloud Logging |
| **Metrics Collection** | System, application, and LLM metrics |
| **Distributed Tracing** | Agent workflow tracing with OpenTelemetry |
| **LLM Analytics** | Token, latency, and cost tracking per request |
| **Grafana Dashboards** | Auto-provisioned dashboards (per ADR-007) |
| **Alerting** | Cloud Monitoring alerts with severity routing |

### Critical for FinOps Platform

A cost monitoring platform must monitor its own costs:
- **LLM token consumption** per query, agent, tenant
- **Agent execution costs** (compute, API calls)
- **MCP server metrics** (latency, error rates)

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                 F3: OBSERVABILITY v1.0.0                         │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌──────────┐  │
│  │ LOGGING │ │ METRICS │ │ TRACING │ │ALERTING │ │   LLM    │  │
│  │         │ │         │ │         │ │         │ │ ANALYTICS│  │
│  │• JSON   │ │• Counter│ │• Spans  │ │• Rules  │ │• Tokens  │  │
│  │• Levels │ │• Gauge  │ │• Context│ │• Channels│ │• Cost    │  │
│  │• Trace  │ │• Histo  │ │• Agent  │ │• Severity│ │• Latency │  │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └────┬─────┘  │
│       │          │          │          │           │           │
│       ▼          ▼          ▼          ▼           ▼           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              CLOUD LOGGING / MONITORING                  │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
            ┌─────────────┐     ┌─────────────┐
            │   GRAFANA   │     │  BIGQUERY   │
            │ Dashboards  │     │ LLM Metrics │
            └─────────────┘     └─────────────┘
```

### Design Principles

| Principle | Description |
|-----------|-------------|
| **Zero Domain Knowledge** | Collects metrics without business interpretation |
| **Correlation First** | trace_id links logs → metrics → traces |
| **Low Overhead** | Async processing, sampling for high-volume |
| **Built-in LLM Support** | First-class token and cost tracking |
| **Cloud-Native** | Leverages Cloud Logging (50 GiB free/month) |

---

## 3. Logging System

### 3.1 Log Levels

| Level | Value | Description | Use Case |
|-------|-------|-------------|----------|
| **ERROR** | 40 | Critical issues | Exceptions, failures |
| **WARN** | 30 | Potential issues | Retries, deprecations |
| **INFO** | 20 | Normal operations | Request handling |
| **DEBUG** | 10 | Detailed diagnostics | Development only |

### 3.2 Structured Log Format

```json
{
  "timestamp": "2026-02-07T15:30:00.000Z",
  "level": "INFO",
  "message": "Cost query completed",
  "trace_id": "abc123def456",
  "span_id": "span789",
  "tenant_id": "tenant-001",
  "user_id": "user-456",
  "module": "cost_agent",
  "context": {
    "query_type": "cost_breakdown",
    "cloud_provider": "gcp",
    "tokens_used": 1250,
    "latency_ms": 2340
  }
}
```

### 3.3 Log Outputs

| Output | Environment | Retention | Cost |
|--------|-------------|-----------|------|
| **Console** | Development | None | Free |
| **Cloud Logging** | Production | 30 days | Free (50 GiB/month) |
| **BigQuery** | Analytics | 1 year | Billing export |

### 3.4 Logging Configuration

```yaml
# f3-observability-config.yaml
logging:
  level: INFO
  format: json

  outputs:
    - type: cloud_logging
      project: ${GCP_PROJECT}
      log_name: ai-cost-monitoring

  correlation:
    enabled: true
    headers:
      - X-Trace-ID
      - X-Request-ID
```

---

## 4. Metrics System

### 4.1 Metric Types

| Type | Description | Example |
|------|-------------|---------|
| **Counter** | Monotonically increasing | requests_total |
| **Gauge** | Current value | active_sessions |
| **Histogram** | Distribution | request_duration_ms |

### 4.2 Core Metrics

#### System Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `cloudrun_requests_total` | Counter | service, method, status | Request count |
| `cloudrun_request_latency_ms` | Histogram | service, method | Request duration |
| `cloudrun_memory_usage_bytes` | Gauge | service | Memory consumption |

#### Application Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `agent_executions_total` | Counter | agent, tenant | Agent invocations |
| `agent_execution_duration_ms` | Histogram | agent | Execution time |
| `mcp_calls_total` | Counter | server, tool, status | MCP tool calls |
| `mcp_call_latency_ms` | Histogram | server, tool | MCP call duration |

#### LLM Metrics (Critical)

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `llm_tokens_total` | Counter | model, type, tenant | Token consumption |
| `llm_requests_total` | Counter | model, agent, status | LLM API calls |
| `llm_request_latency_ms` | Histogram | model | LLM response time |
| `llm_cost_usd` | Counter | model, tenant | Estimated LLM cost |

### 4.3 Metrics Export

```yaml
# f3-metrics-config.yaml
metrics:
  exporters:
    - type: cloud_monitoring
      project: ${GCP_PROJECT}
      prefix: custom.googleapis.com/ai-cost-monitoring

    - type: prometheus
      port: 9090
      path: /metrics
```

---

## 5. LLM Analytics (Platform-Critical)

### 5.1 Token Tracking

For a cost monitoring platform, tracking LLM costs is essential:

```python
@dataclass
class LLMUsageEvent:
    """Emitted after every LLM call."""
    timestamp: datetime
    trace_id: str
    tenant_id: str
    user_id: str
    agent: str
    model: str  # e.g., "gemini-1.5-flash"
    provider: str  # e.g., "google" via LiteLLM
    input_tokens: int
    output_tokens: int
    latency_ms: int
    estimated_cost_usd: float
```

### 5.2 Cost Estimation

Per ADR-005, we use LiteLLM for multi-provider access:

| Model | Input (per 1K) | Output (per 1K) | Notes |
|-------|----------------|-----------------|-------|
| gemini-1.5-flash | $0.000075 | $0.0003 | Primary model |
| gemini-1.5-pro | $0.00125 | $0.005 | Complex queries |
| gpt-4o | $0.0025 | $0.01 | Fallback |

### 5.3 LLM Usage Dashboard

Grafana dashboard with:

| Panel | Visualization | Query |
|-------|---------------|-------|
| Tokens by Model | Time series | `sum(llm_tokens_total) by (model)` |
| Cost by Tenant | Bar chart | `sum(llm_cost_usd) by (tenant)` |
| Latency P95 | Heatmap | `histogram_quantile(0.95, llm_request_latency_ms)` |
| Error Rate | Stat | `rate(llm_requests_total{status="error"})` |

### 5.4 LiteLLM Integration

```python
# LiteLLM callback for metrics
from litellm import completion
from f3_observability import emit_llm_usage

async def call_llm(prompt: str, context: TenantContext):
    response = await completion(
        model="gemini/gemini-1.5-flash",
        messages=[{"role": "user", "content": prompt}],
        metadata={
            "tenant_id": str(context.tenant_id),
            "trace_id": get_current_trace_id()
        }
    )

    # Emit usage metrics
    emit_llm_usage(LLMUsageEvent(
        trace_id=get_current_trace_id(),
        tenant_id=context.tenant_id,
        model=response.model,
        input_tokens=response.usage.prompt_tokens,
        output_tokens=response.usage.completion_tokens,
        estimated_cost_usd=calculate_cost(response)
    ))

    return response
```

---

## 6. Distributed Tracing

### 6.1 Agent Workflow Tracing

```
┌─────────────────────────────────────────────────────────────┐
│                    TRACE: cost_query_001                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ SPAN: ag_ui_request (15ms)                           │    │
│  └──────────────────┬──────────────────────────────────┘    │
│                     │                                        │
│  ┌──────────────────▼──────────────────────────────────┐    │
│  │ SPAN: coordinator_agent (50ms)                       │    │
│  │   • classify_intent                                  │    │
│  │   • route_to_agent                                   │    │
│  └──────────────────┬──────────────────────────────────┘    │
│                     │                                        │
│  ┌──────────────────▼──────────────────────────────────┐    │
│  │ SPAN: cost_agent (2000ms)                            │    │
│  │   └─ SPAN: llm_call (800ms)                          │    │
│  │   └─ SPAN: mcp_get_costs (1100ms)                    │    │
│  │        └─ SPAN: bigquery_query (950ms)               │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 6.2 OpenTelemetry Configuration

```yaml
# f3-tracing-config.yaml
tracing:
  enabled: true
  exporter: cloud_trace
  project: ${GCP_PROJECT}

  sampling:
    strategy: probabilistic
    rate: 0.1  # 10% of requests in production

  propagation:
    - tracecontext
    - baggage
```

### 6.3 Span Attributes

| Attribute | Description |
|-----------|-------------|
| `tenant.id` | Tenant identifier |
| `agent.name` | Agent that created span |
| `mcp.server` | MCP server name |
| `mcp.tool` | MCP tool invoked |
| `llm.model` | LLM model used |
| `llm.tokens` | Token count |

---

## 7. Alerting

### 7.1 Alert Severity Levels

| Severity | Response Time | Channel | Examples |
|----------|---------------|---------|----------|
| **P1 Critical** | 5 min | PagerDuty | Service down, auth failures |
| **P2 High** | 30 min | Slack #alerts | Error rate spike |
| **P3 Medium** | 4 hours | Email | Cost anomaly |
| **P4 Low** | Next day | Dashboard | Deprecation warning |

### 7.2 Alert Rules

```yaml
# f3-alerting-config.yaml
alerting:
  rules:
    - name: high_error_rate
      condition: rate(agent_executions_total{status="error"}[5m]) > 0.05
      severity: P2
      message: "Agent error rate exceeded 5%"

    - name: llm_cost_spike
      condition: increase(llm_cost_usd[1h]) > 10
      severity: P3
      message: "LLM costs increased by $10+ in last hour"

    - name: mcp_latency_high
      condition: histogram_quantile(0.95, mcp_call_latency_ms[5m]) > 5000
      severity: P2
      message: "MCP call P95 latency > 5s"
```

---

## 8. Grafana Dashboards

Per ADR-007, Grafana is the primary dashboard:

### 8.1 Auto-Provisioned Dashboards

| Dashboard | Metrics | Purpose |
|-----------|---------|---------|
| **Platform Overview** | Requests, errors, latency | System health |
| **Agent Performance** | Executions, duration, success rate | Agent monitoring |
| **LLM Costs** | Tokens, cost, latency by model | Cost visibility |
| **MCP Servers** | Calls, errors, latency per tool | Integration health |
| **Tenant Usage** | Queries, costs per tenant | Usage tracking |

### 8.2 BigQuery Data Source

```yaml
# grafana-datasources.yaml
datasources:
  - name: BigQuery - Costs
    type: grafana-bigquery-datasource
    jsonData:
      authenticationType: gce
      defaultProject: ${GCP_PROJECT}

  - name: Cloud Monitoring
    type: stackdriver
    jsonData:
      authenticationType: gce
```

---

## 9. Public Interface

```python
class ObservabilityModule:
    """Foundation Module F3: Observability"""

    # Logging
    def log(self, level: str, message: str, **context) -> None:
        """Emit structured log with correlation."""

    # Metrics
    def increment(self, metric: str, value: int = 1, **labels) -> None:
        """Increment counter metric."""

    def gauge(self, metric: str, value: float, **labels) -> None:
        """Set gauge metric."""

    def histogram(self, metric: str, value: float, **labels) -> None:
        """Record histogram observation."""

    # Tracing
    def start_span(self, name: str, **attributes) -> Span:
        """Start new span in current trace."""

    def get_current_trace_id(self) -> str:
        """Get current trace ID for correlation."""

    # LLM Analytics
    def emit_llm_usage(self, event: LLMUsageEvent) -> None:
        """Record LLM usage for cost tracking."""
```

---

## 10. Dependencies

| Module | Dependency Type | Description |
|--------|----------------|-------------|
| **F7 Config** | Upstream | Logging levels, alert thresholds |
| **F1 IAM** | Upstream | tenant_id for correlation |
| **All Agents** | Downstream | Instrumentation |

---

## 11. MVP Scope

### Included in MVP

- [x] Structured JSON logging to Cloud Logging
- [x] Core metrics (requests, latency, errors)
- [x] LLM token and cost tracking
- [x] Basic Grafana dashboards
- [x] P1/P2 alerting

### Deferred

- [ ] Custom dashboard builder
- [ ] Log-based metrics
- [ ] Advanced anomaly detection
- [ ] Multi-region aggregation

---

*Adapted from Trading Nexus F3 v1.3.0 — February 2026*
