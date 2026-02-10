# ADR-010: AgentCard Specification for Agent Discovery

## Status
Accepted

## Date
2026-02-07T00:00:00

## Context

With the adoption of the hybrid agent registration pattern (ADR-009), we need a standardized way for agents to describe themselves. Key requirements:

1. **Self-description** - Agents must declare their capabilities without external configuration
2. **Discovery** - Domain Agents must find Cloud Agents dynamically
3. **Compatibility** - Internal agents and external A2A agents should use the same format
4. **Permission checking** - Routing logic needs to verify RBAC before delegating
5. **Health monitoring** - Standardized health check endpoints for observability

We evaluated:
1. **Custom schema** - Design our own agent descriptor
2. **Google A2A Agent Card** - Adopt the A2A Protocol specification
3. **OpenAPI-style descriptors** - Use API specification patterns
4. **Kubernetes-style labels** - Simple key-value metadata

## Decision

We will implement **AgentCard**, a Pydantic model inspired by Google A2A Agent Cards but simplified for our use case. AgentCard serves as the universal descriptor for all agent types (Cloud, Domain, External).

## Rationale

### Why A2A-Inspired?

Google's A2A Protocol Agent Card is well-designed for agent discovery:
- Declarative capability specification
- Version-aware for compatibility checking
- Extensible metadata structure
- Already proven in production agent systems

### Why Not Full A2A Agent Card?

The full A2A specification includes fields we don't need:
- JSON-LD context (unnecessary for internal use)
- Public URL discovery (we use internal registry)
- OAuth scopes (we use our own RBAC)
- Complex authentication negotiation

### Why Not Simple Key-Value Labels?

Labels lack structure for:
- Listing supported tools
- Specifying required permissions
- Version compatibility checks
- Nested capability definitions

## Specification

### AgentType Enum

```python
from enum import Enum

class AgentType(Enum):
    CLOUD_PROVIDER = "cloud_provider"  # AWS, Azure, GCP, Kubernetes
    DOMAIN = "domain"                   # Cost, Optimization, Remediation, Reporting
    EXTERNAL = "external"               # SlackBot, Compliance Auditor (A2A)
```

### AgentCapability Model

```python
from typing import List, Optional
from pydantic import BaseModel

class AgentCapability(BaseModel):
    """Describes what an agent can do"""

    tools: List[str]
    """List of tool/operation names this agent supports.
    For Cloud Agents: ["get_costs", "get_resources", "get_recommendations",
                       "get_anomalies", "execute_action", "get_idle_resources"]
    For Domain Agents: ["analyze_costs", "find_savings", "generate_report"]
    """

    providers: Optional[List[str]] = None
    """Cloud providers this agent handles (Cloud Agents only).
    Example: ["aws"] or ["gcp", "gcp-billing"]
    """

    permissions_required: List[str]
    """RBAC permissions needed to invoke this agent.
    Example: ["read:costs", "read:resources", "execute:actions"]
    """
```

### AgentCard Model

```python
from typing import Optional
from pydantic import BaseModel, Field

class AgentCard(BaseModel):
    """Universal agent descriptor for discovery and routing"""

    name: str = Field(..., description="Unique agent identifier", examples=["aws", "cost", "slackbot"])

    type: AgentType = Field(..., description="Category of agent")

    version: str = Field(..., description="Semantic version for compatibility", examples=["1.0.0", "2.1.3"])

    capabilities: AgentCapability = Field(..., description="What this agent can do")

    endpoint: Optional[str] = Field(
        None,
        description="A2A endpoint URL (external agents only)",
        examples=["https://slackbot.example.com/a2a"]
    )

    health_check: Optional[str] = Field(
        "/health",
        description="Health check endpoint path",
        examples=["/health", "/api/health"]
    )

    description: Optional[str] = Field(
        None,
        description="Human-readable description of agent purpose"
    )

    metadata: Optional[dict] = Field(
        None,
        description="Additional key-value metadata for extensibility"
    )
```

### Standard AgentCards

#### Cloud Provider Agents

```python
# AWS Cloud Agent
AgentCard(
    name="aws",
    type=AgentType.CLOUD_PROVIDER,
    version="1.0.0",
    capabilities=AgentCapability(
        tools=["get_costs", "get_resources", "get_recommendations",
               "get_anomalies", "execute_action", "get_idle_resources"],
        providers=["aws"],
        permissions_required=["read:costs", "read:resources"]
    ),
    description="AWS cost monitoring and optimization agent",
    health_check="/health"
)

# Azure Cloud Agent
AgentCard(
    name="azure",
    type=AgentType.CLOUD_PROVIDER,
    version="1.0.0",
    capabilities=AgentCapability(
        tools=["get_costs", "get_resources", "get_recommendations",
               "get_anomalies", "execute_action", "get_idle_resources"],
        providers=["azure"],
        permissions_required=["read:costs", "read:resources"]
    ),
    description="Azure cost monitoring and optimization agent"
)

# GCP Cloud Agent
AgentCard(
    name="gcp",
    type=AgentType.CLOUD_PROVIDER,
    version="1.0.0",
    capabilities=AgentCapability(
        tools=["get_costs", "get_resources", "get_recommendations",
               "get_anomalies", "execute_action", "get_idle_resources"],
        providers=["gcp"],
        permissions_required=["read:costs", "read:resources"]
    ),
    description="GCP cost monitoring and optimization agent"
)

# Kubernetes Agent
AgentCard(
    name="kubernetes",
    type=AgentType.CLOUD_PROVIDER,
    version="1.0.0",
    capabilities=AgentCapability(
        tools=["get_costs", "get_resources", "get_recommendations",
               "get_anomalies", "execute_action", "get_idle_resources",
               "get_namespace_costs"],  # K8s-specific tool
        providers=["kubernetes"],
        permissions_required=["read:costs", "read:resources"]
    ),
    description="Kubernetes cost monitoring via OpenCost"
)
```

#### Domain Agents

```python
# Cost Agent
AgentCard(
    name="cost",
    type=AgentType.DOMAIN,
    version="1.0.0",
    capabilities=AgentCapability(
        tools=["analyze_costs", "compare_costs", "investigate_anomaly"],
        permissions_required=["read:costs"]
    ),
    description="Multi-cloud cost analysis and anomaly investigation"
)

# Optimization Agent
AgentCard(
    name="optimization",
    type=AgentType.DOMAIN,
    version="1.0.0",
    capabilities=AgentCapability(
        tools=["find_idle_resources", "get_savings_opportunities",
               "analyze_rightsizing"],
        permissions_required=["read:costs", "read:resources"]
    ),
    description="Cross-cloud optimization recommendations"
)

# Remediation Agent
AgentCard(
    name="remediation",
    type=AgentType.DOMAIN,
    version="1.0.0",
    capabilities=AgentCapability(
        tools=["execute_recommendation", "schedule_action", "rollback_action"],
        permissions_required=["read:costs", "execute:actions"]
    ),
    description="Execute optimization actions with approval workflows"
)
```

#### External Agents (A2A)

```python
# SlackBot Agent
AgentCard(
    name="slackbot",
    type=AgentType.EXTERNAL,
    version="2.0.0",
    capabilities=AgentCapability(
        tools=["query_costs", "send_notification"],
        permissions_required=["read:costs"]
    ),
    endpoint="https://slackbot.internal/a2a",
    description="Slack integration for cost queries and alerts"
)

# Compliance Auditor
AgentCard(
    name="compliance-auditor",
    type=AgentType.EXTERNAL,
    version="1.0.0",
    capabilities=AgentCapability(
        tools=["audit_policies", "check_compliance"],
        permissions_required=["read:costs", "read:policies"]
    ),
    endpoint="https://auditor.internal/a2a",
    description="Nightly compliance and policy violation scanner"
)
```

### Usage Patterns

#### Self-Registration

```python
class AWSCloudAgent(BaseCloudAgent):
    CARD = AgentCard(name="aws", ...)

    def __init__(self, mcp_server):
        self.mcp = mcp_server
        AgentRegistry.register(self.CARD, self)
```

#### Discovery by Type

```python
# Find all cloud provider agents
cloud_agents = AgentRegistry.discover(agent_type=AgentType.CLOUD_PROVIDER)

# Find all domain agents
domain_agents = AgentRegistry.discover(agent_type=AgentType.DOMAIN)
```

#### Discovery by Capability

```python
# Find agents that support cost queries
cost_capable = AgentRegistry.discover(capability="get_costs")

# Find agents that can execute actions
action_capable = AgentRegistry.discover(capability="execute_action")
```

#### Permission Verification

```python
def can_user_invoke(user_permissions: List[str], agent: AgentCard) -> bool:
    required = agent.capabilities.permissions_required
    return all(perm in user_permissions for perm in required)

# Usage
if can_user_invoke(user.permissions, aws_agent.CARD):
    result = await aws_agent.get_costs(...)
else:
    raise PermissionDenied("Missing required permissions")
```

#### Version Compatibility

```python
from packaging import version

def is_compatible(agent_card: AgentCard, min_version: str) -> bool:
    return version.parse(agent_card.version) >= version.parse(min_version)

# Usage
if is_compatible(gcp_agent.CARD, "1.0.0"):
    # Use new API
else:
    # Fall back to legacy API
```

## Consequences

### Positive

- **Self-documenting agents** - Each agent declares exactly what it can do
- **Dynamic discovery** - No hardcoded lists; new agents auto-discovered
- **Permission checking** - RBAC verification before routing
- **Version awareness** - Graceful handling of agent upgrades
- **A2A compatibility** - External agents use same pattern
- **Extensible** - `metadata` field for future needs

### Negative

- **Overhead** - Each agent must define a card (minimal)
- **Schema evolution** - Changes to AgentCard affect all agents
- **Consistency burden** - Teams must keep cards updated

### Neutral

- Cards are defined in code, not configuration
- No runtime card modification (cards are immutable after init)

## Implementation Notes

### File Location

```
src/
├── core/
│   ├── agent_card.py      # AgentCard, AgentType, AgentCapability
│   └── agent_registry.py  # AgentRegistry singleton
├── agents/
│   ├── base.py            # BaseAgent with CARD class attribute
│   ├── cloud/
│   │   ├── aws_agent.py   # AWS CARD + implementation
│   │   ├── azure_agent.py
│   │   └── ...
│   └── domain/
│       ├── cost_agent.py
│       └── ...
```

### Validation

AgentCard validation happens at registration:

```python
class AgentRegistry:
    @classmethod
    def register(cls, card: AgentCard, instance: BaseAgent):
        # Validate card
        if not card.name:
            raise ValueError("AgentCard.name is required")
        if card.type == AgentType.CLOUD_PROVIDER and not card.capabilities.providers:
            raise ValueError("Cloud agents must specify providers")
        if card.type == AgentType.EXTERNAL and not card.endpoint:
            raise ValueError("External agents must specify endpoint")

        # Register
        cls._agents[card.name] = card
        cls._instances[card.name] = instance
```

### Serialization

AgentCards can be serialized for API responses:

```python
# GET /api/agents
@app.get("/api/agents")
def list_agents():
    cards = AgentRegistry.discover()
    return [card.model_dump() for card in cards]
```

## Alternatives Considered

| Alternative | Pros | Cons | Decision |
|-------------|------|------|----------|
| Full A2A Agent Card | Standard spec | Too complex for internal use | Rejected |
| Simple key-value labels | Very simple | No structure for tools/permissions | Rejected |
| OpenAPI-style descriptors | Well-known | Designed for APIs, not agents | Rejected |
| **AgentCard (A2A-inspired)** | **Right balance** | **Custom schema** | **Accepted** |

## Related Decisions

- [ADR-009: Hybrid Agent Registration Pattern](009-hybrid-agent-registration-pattern.md) - Uses AgentCard for registration
- [ADR-001: Use MCP Servers](001-use-mcp-servers.md) - MCP tools listed in AgentCard.capabilities

## References

- [Google A2A Protocol - Agent Card](https://google.github.io/a2a/specification/#agent-card)
- [Pydantic Documentation](https://docs.pydantic.dev/)
- [Semantic Versioning](https://semver.org/)

## Review

This decision should be reviewed if:
- Google A2A Protocol becomes a widely-adopted standard we should fully adopt
- AgentCard schema becomes too rigid for new requirements
- We need runtime card modification (currently immutable)
