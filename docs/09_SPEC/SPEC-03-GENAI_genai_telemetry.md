---
title: "SPEC-03-GENAI: Gen-AI Telemetry Implementation"
tags:
  - spec
  - layer-9-artifact
  - f3-observability
  - opentelemetry
  - gen-ai
  - semantic-conventions
  - shared-architecture
custom_fields:
  document_type: spec
  artifact_type: SPEC
  layer: 9
  module_id: F3
  module_name: Observability
  component: genai_telemetry
  task_ready_score: 92
  schema_version: "1.0"
---

# SPEC-03-GENAI: Gen-AI Telemetry Implementation

**Summary**: Implementation specification for OTEL Gen-AI Semantic Conventions in F3 Observability module, including span attributes, metrics, cost extensions, and opt-in event capture.

## 1. Document Control

| Item | Details |
|------|---------|
| **Status** | Draft |
| **Version** | 1.0.0 |
| **Date Created** | 2026-02-10T00:00:00 |
| **Last Updated** | 2026-02-10T00:00:00 |
| **Author** | Coder Agent (Claude) |
| **Priority** | P1 (Critical) |
| **TASKS-Ready Score** | ✅ 92% (Target: ≥90%) |

---

## 2. Traceability

### 2.1 Upstream Sources

| Source | Document ID | Relationship |
|--------|-------------|--------------|
| BRD | BRD-03 | Business requirements for observability |
| PRD | PRD-03 | Product requirements for LLM analytics |
| ADR | ADR-03 | Base observability architecture |
| ADR | ADR-15 | OTEL Gen-AI adoption decision |
| SYS | SYS-03 | System requirements SYS.03.01.20-24 |
| REQ | REQ-03 | Atomic requirements REQ.03.01.20-23 |

### 2.2 Traceability Tags

```markdown
@brd: BRD-03
@prd: PRD-03
@ears: EARS-03
@adr: ADR-03, ADR-15
@sys: SYS-03
@req: REQ-03
```

---

## 3. Component Overview

### 3.1 Purpose

Implement OpenTelemetry Gen-AI Semantic Conventions v1.37+ for all LLM operations, providing:
- Standardized span attributes for LLM requests
- Histogram metrics for token usage and operation duration
- Custom cost tracking extensions
- Opt-in prompt/response event capture with PII filtering

### 3.2 Architecture Position

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  LiteLLM    │  │  Gemini SDK │  │  OpenAI SDK │         │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │
│         │                │                │                  │
│         └────────────────┼────────────────┘                  │
│                          ▼                                   │
│  ┌───────────────────────────────────────────────────────┐  │
│  │           GenAI Instrumentation Layer                  │  │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐      │  │
│  │  │ Span Attrs  │ │  Metrics    │ │   Events    │      │  │
│  │  │ gen_ai.*    │ │ Histograms  │ │ (Opt-In)    │      │  │
│  │  └─────────────┘ └─────────────┘ └─────────────┘      │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │   F3 Telemetry Core   │
              │   (Existing OTEL)     │
              └───────────────────────┘
```

---

## 4. Technical Specification

### 4.1 Span Attribute Implementation

#### 4.1.1 Required Attributes

```python
from opentelemetry import trace
from opentelemetry.trace import SpanKind, Status, StatusCode
from typing import Literal, Optional

# Provider name mapping
PROVIDER_MAP = {
    "vertex_ai": "gcp.vertex_ai",
    "google": "google.generative_ai",
    "openai": "openai",
    "azure": "azure.ai.openai",
    "anthropic": "anthropic",
    "bedrock": "aws.bedrock",
    "cohere": "cohere",
}

# Operation name values
OperationType = Literal["chat", "text_completion", "embeddings", "generate_content"]

def create_genai_span(
    tracer: trace.Tracer,
    operation: OperationType,
    provider: str,
    model: str,
) -> trace.Span:
    """
    Create span with required OTEL Gen-AI attributes.

    Span naming convention: "{operation} {model}"
    Example: "chat gemini-1.5-flash"
    """
    provider_name = PROVIDER_MAP.get(provider, provider)
    span_name = f"{operation} {model}"

    span = tracer.start_span(
        name=span_name,
        kind=SpanKind.CLIENT,
        attributes={
            "gen_ai.operation.name": operation,
            "gen_ai.provider.name": provider_name,
            "gen_ai.request.model": model,
        }
    )
    return span
```

#### 4.1.2 Response Attributes

```python
def set_genai_response_attributes(
    span: trace.Span,
    response_model: str,
    response_id: str,
    input_tokens: int,
    output_tokens: int,
    finish_reasons: list[str],
) -> None:
    """Set span attributes from LLM response."""
    span.set_attribute("gen_ai.response.model", response_model)
    span.set_attribute("gen_ai.response.id", response_id)
    span.set_attribute("gen_ai.usage.input_tokens", input_tokens)
    span.set_attribute("gen_ai.usage.output_tokens", output_tokens)
    span.set_attribute("gen_ai.response.finish_reasons", finish_reasons)
```

#### 4.1.3 Cost Extension Attributes

```python
from dataclasses import dataclass

@dataclass
class ModelPricing:
    """Pricing per 1K tokens in USD."""
    input_price: float
    output_price: float

# Model pricing configuration (loaded from F7 Config)
MODEL_PRICING = {
    "gemini-1.5-flash": ModelPricing(0.000075, 0.0003),
    "gemini-1.5-pro": ModelPricing(0.00125, 0.005),
    "gpt-4o": ModelPricing(0.0025, 0.01),
    "gpt-4o-mini": ModelPricing(0.00015, 0.0006),
    "claude-3-5-sonnet": ModelPricing(0.003, 0.015),
}

def set_genai_cost_attributes(
    span: trace.Span,
    model: str,
    input_tokens: int,
    output_tokens: int,
) -> float:
    """
    Calculate and set custom cost extension attributes.

    Returns total cost in USD.
    """
    pricing = MODEL_PRICING.get(model)
    if not pricing:
        return 0.0

    input_cost = (input_tokens / 1000) * pricing.input_price
    output_cost = (output_tokens / 1000) * pricing.output_price
    total_cost = input_cost + output_cost

    span.set_attribute("gen_ai.cost.input_usd", input_cost)
    span.set_attribute("gen_ai.cost.output_usd", output_cost)
    span.set_attribute("gen_ai.cost.total_usd", total_cost)

    return total_cost
```

### 4.2 Metrics Implementation

#### 4.2.1 Metric Definitions

```python
from opentelemetry import metrics
from opentelemetry.metrics import Histogram

# Token usage histogram
# Unit: {token}
# Buckets: [1, 4, 16, 64, 256, 1024, 4096, 16384, 65536, 262144, 1048576]
token_usage_histogram: Histogram = meter.create_histogram(
    name="gen_ai.client.token.usage",
    unit="{token}",
    description="Token consumption by type (input/output)",
)

# Operation duration histogram
# Unit: seconds
# Buckets: [0.01, 0.02, 0.04, 0.08, 0.16, 0.32, 0.64, 1.28, 2.56, 5.12, 10.24, 20.48, 40.96, 81.92]
operation_duration_histogram: Histogram = meter.create_histogram(
    name="gen_ai.client.operation.duration",
    unit="s",
    description="GenAI operation latency",
)
```

#### 4.2.2 Metric Recording

```python
def record_genai_metrics(
    operation: str,
    provider: str,
    model: str,
    input_tokens: int,
    output_tokens: int,
    duration_seconds: float,
    error_type: Optional[str] = None,
) -> None:
    """Record Gen-AI metrics per OTEL specification."""

    base_attributes = {
        "gen_ai.operation.name": operation,
        "gen_ai.provider.name": provider,
        "gen_ai.request.model": model,
    }

    # Record input tokens
    token_usage_histogram.record(
        input_tokens,
        attributes={
            **base_attributes,
            "gen_ai.token.type": "input",
        }
    )

    # Record output tokens
    token_usage_histogram.record(
        output_tokens,
        attributes={
            **base_attributes,
            "gen_ai.token.type": "output",
        }
    )

    # Record operation duration
    duration_attributes = {**base_attributes}
    if error_type:
        duration_attributes["error.type"] = error_type

    operation_duration_histogram.record(
        duration_seconds,
        attributes=duration_attributes
    )
```

### 4.3 Event Capture Implementation (Opt-In)

#### 4.3.1 Configuration Schema

```yaml
# F7 Config schema for Gen-AI events
gen_ai_events:
  enabled: false  # Default: disabled (opt-in only)
  capture_input: true
  capture_output: true
  max_content_length: 10000  # Truncate after this length
  pii_filtering:
    enabled: true  # MUST remain true when events enabled
    patterns:
      credit_card: '\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b'
      ssn: '\b\d{3}-\d{2}-\d{4}\b'
      email: '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'
      api_key: '\b(sk-|api[_-]?key)[a-zA-Z0-9]{20,}\b'
      phone: '\b\d{3}[-.]?\d{3}[-.]?\d{4}\b'
    replacement: '[REDACTED]'
```

#### 4.3.2 PII Filter Implementation

```python
import re
from typing import Dict, Any

class PIIFilter:
    """Filter PII from prompts and responses."""

    DEFAULT_PATTERNS = {
        "credit_card": r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b',
        "ssn": r'\b\d{3}-\d{2}-\d{4}\b',
        "email": r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
        "api_key": r'\b(sk-|api[_-]?key)[a-zA-Z0-9]{20,}\b',
        "phone": r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b',
    }

    def __init__(
        self,
        patterns: Dict[str, str] = None,
        replacement: str = "[REDACTED]"
    ):
        self.patterns = patterns or self.DEFAULT_PATTERNS
        self.replacement = replacement
        self._compiled = {
            name: re.compile(pattern, re.IGNORECASE)
            for name, pattern in self.patterns.items()
        }

    def filter(self, text: str) -> str:
        """Remove PII from text."""
        result = text
        for name, pattern in self._compiled.items():
            result = pattern.sub(f"{self.replacement}:{name}", result)
        return result

    def filter_dict(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Recursively filter PII from dictionary."""
        result = {}
        for key, value in data.items():
            if isinstance(value, str):
                result[key] = self.filter(value)
            elif isinstance(value, dict):
                result[key] = self.filter_dict(value)
            elif isinstance(value, list):
                result[key] = [
                    self.filter(v) if isinstance(v, str)
                    else self.filter_dict(v) if isinstance(v, dict)
                    else v
                    for v in value
                ]
            else:
                result[key] = value
        return result
```

#### 4.3.3 Event Emission

```python
from opentelemetry.sdk.trace import Event
import json

def emit_genai_event(
    span: trace.Span,
    input_messages: list[dict] = None,
    output_messages: list[dict] = None,
    config: dict = None,
) -> None:
    """
    Emit gen_ai.client.inference.operation.details event.

    Only called when gen_ai_events.enabled = true in config.
    PII filtering is mandatory.
    """
    config = config or {}
    if not config.get("gen_ai_events", {}).get("enabled", False):
        return

    pii_filter = PIIFilter()
    event_body = {}

    if input_messages and config.get("gen_ai_events", {}).get("capture_input", True):
        filtered_input = pii_filter.filter_dict({"messages": input_messages})
        event_body["gen_ai.input.messages"] = json.dumps(filtered_input["messages"])

    if output_messages and config.get("gen_ai_events", {}).get("capture_output", True):
        filtered_output = pii_filter.filter_dict({"messages": output_messages})
        event_body["gen_ai.output.messages"] = json.dumps(filtered_output["messages"])

    if event_body:
        span.add_event(
            name="gen_ai.client.inference.operation.details",
            attributes=event_body
        )
```

### 4.4 LiteLLM Integration

```python
from litellm import completion
from litellm.integrations.custom_logger import CustomLogger
import time

class GenAITelemetryCallback(CustomLogger):
    """LiteLLM callback for OTEL Gen-AI instrumentation."""

    def __init__(self, tracer: trace.Tracer, meter: metrics.Meter, config: dict):
        self.tracer = tracer
        self.meter = meter
        self.config = config
        self._active_spans = {}

    def log_pre_api_call(self, model, messages, kwargs):
        """Called before LLM API request."""
        operation = self._get_operation_type(kwargs)
        provider = self._get_provider(model)

        span = create_genai_span(
            tracer=self.tracer,
            operation=operation,
            provider=provider,
            model=model,
        )

        call_id = kwargs.get("litellm_call_id")
        self._active_spans[call_id] = {
            "span": span,
            "start_time": time.time(),
            "messages": messages,
        }

    def log_success_event(self, kwargs, response_obj, start_time, end_time):
        """Called on successful LLM response."""
        call_id = kwargs.get("litellm_call_id")
        span_data = self._active_spans.pop(call_id, None)
        if not span_data:
            return

        span = span_data["span"]
        duration = end_time - start_time

        # Extract response data
        model = response_obj.model
        input_tokens = response_obj.usage.prompt_tokens
        output_tokens = response_obj.usage.completion_tokens

        # Set response attributes
        set_genai_response_attributes(
            span=span,
            response_model=model,
            response_id=response_obj.id,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            finish_reasons=[c.finish_reason for c in response_obj.choices],
        )

        # Set cost attributes
        set_genai_cost_attributes(
            span=span,
            model=model,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
        )

        # Record metrics
        record_genai_metrics(
            operation=span.attributes.get("gen_ai.operation.name"),
            provider=span.attributes.get("gen_ai.provider.name"),
            model=model,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            duration_seconds=duration,
        )

        # Emit event (if enabled)
        emit_genai_event(
            span=span,
            input_messages=span_data.get("messages"),
            output_messages=[
                {"role": "assistant", "content": c.message.content}
                for c in response_obj.choices
            ],
            config=self.config,
        )

        span.set_status(Status(StatusCode.OK))
        span.end()

    def log_failure_event(self, kwargs, response_obj, start_time, end_time):
        """Called on LLM error."""
        call_id = kwargs.get("litellm_call_id")
        span_data = self._active_spans.pop(call_id, None)
        if not span_data:
            return

        span = span_data["span"]
        duration = end_time - start_time
        error_type = type(response_obj).__name__ if response_obj else "Unknown"

        # Record error metrics
        record_genai_metrics(
            operation=span.attributes.get("gen_ai.operation.name"),
            provider=span.attributes.get("gen_ai.provider.name"),
            model=kwargs.get("model", "unknown"),
            input_tokens=0,
            output_tokens=0,
            duration_seconds=duration,
            error_type=error_type,
        )

        span.set_attribute("error.type", error_type)
        span.set_status(Status(StatusCode.ERROR, str(response_obj)))
        span.end()

    def _get_operation_type(self, kwargs) -> str:
        """Determine operation type from request."""
        if kwargs.get("aembedding"):
            return "embeddings"
        return "chat"

    def _get_provider(self, model: str) -> str:
        """Extract provider from model string."""
        if "/" in model:
            return model.split("/")[0]
        if model.startswith("gpt"):
            return "openai"
        if model.startswith("claude"):
            return "anthropic"
        if model.startswith("gemini"):
            return "gcp.vertex_ai"
        return "unknown"
```

---

## 5. Configuration

### 5.1 Feature Flags

| Flag | Default | Description |
|------|---------|-------------|
| `F3_GENAI_ENABLED` | true | Enable Gen-AI instrumentation |
| `F3_GENAI_EVENTS_ENABLED` | false | Enable prompt/response capture |
| `F3_GENAI_PII_FILTERING` | true | Enable PII filtering (cannot disable when events enabled) |

### 5.2 Environment Variables

```bash
# Gen-AI instrumentation
OTEL_SEMCONV_STABILITY_OPT_IN=gen_ai_latest_experimental

# Model pricing (override defaults)
GENAI_PRICING_CONFIG=/etc/f3/genai_pricing.yaml
```

---

## 6. Testing Requirements

### 6.1 Unit Tests

| Test Case | Input | Expected Output |
|-----------|-------|-----------------|
| Span attributes set | Chat request | All required attributes present |
| Token metrics recorded | Response with tokens | Histogram updated |
| Cost calculated | 1000 input, 500 output tokens | Correct USD amount |
| PII filtered | Email in prompt | [REDACTED]:email |

### 6.2 Integration Tests

- [ ] LiteLLM callback integration
- [ ] Metrics exported to Prometheus
- [ ] Spans exported to Cloud Trace
- [ ] Events captured when enabled

### 6.3 BDD Scenario

```gherkin
Feature: Gen-AI Telemetry

Scenario: LLM request generates compliant span
  Given an LLM request to "gcp.vertex_ai" with model "gemini-1.5-flash"
  When the request completes with 100 input and 50 output tokens
  Then the span MUST have attribute "gen_ai.operation.name" = "chat"
  And the span MUST have attribute "gen_ai.provider.name" = "gcp.vertex_ai"
  And the span MUST have attribute "gen_ai.usage.input_tokens" = 100
  And the span SHOULD have attribute "gen_ai.cost.total_usd" > 0

Scenario: PII is filtered from events
  Given gen_ai_events.enabled = true
  And a prompt containing "user@example.com"
  When the event is captured
  Then the event body MUST contain "[REDACTED]:email"
  And the event body MUST NOT contain "user@example.com"
```

---

## 7. Implementation Notes

### 7.1 Code Location

- **Primary**: `src/foundation/f3_observability/genai/`
- **Tests**: `tests/foundation/test_f3_observability/test_genai/`

### 7.2 Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| opentelemetry-api | >=1.20.0 | OTEL API |
| opentelemetry-sdk | >=1.20.0 | OTEL SDK |
| opentelemetry-semantic-conventions | >=0.42b0 | Gen-AI conventions |
| litellm | >=1.20.0 | LLM proxy |

### 7.3 Migration Path

1. Deploy with `F3_GENAI_ENABLED=true` (default)
2. Existing `llm.*` attributes deprecated but still emitted
3. After 30 days, remove legacy attributes
4. Update Grafana dashboards to use `gen_ai.*` queries

---

## 8. Change History

| Date | Version | Change | Author |
|------|---------|--------|--------|
| 2026-02-10T00:00:00 | 1.0.0 | Initial specification | Coder Agent |

---

*SPEC-03-GENAI: Gen-AI Telemetry Implementation v1.0.0 — AI Cloud Cost Monitoring Platform v4.2 — February 2026*
