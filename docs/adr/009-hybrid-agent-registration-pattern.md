# ADR-009: Hybrid Agent Registration Pattern for Cloud Provider Extensibility

## Status
Accepted

## Date
2026-02-07

## Context

The platform needs to support multiple cloud providers (AWS, Azure, GCP, Kubernetes) with the ability to add new providers easily. We evaluated two approaches:

1. **Full A2A (Agent-to-Agent) Protocol** - Domain Agents communicate with Cloud Agents via Google A2A Protocol, making Cloud Agents fully independent discoverable services
2. **Direct Communication with Registry** - Domain Agents call Cloud Agents directly but use a registry pattern for dynamic discovery

Key requirements:
- Adding a new cloud provider should require minimal code changes
- No hardcoded routing logic in Domain Agents or Coordinator
- Maintain low latency for internal agent communication
- Support external A2A agents (SlackBot, Compliance Auditor) per existing design
- Enable independent deployment of Cloud Agents

## Decision

We will use a **Hybrid Agent Registration Pattern**:

1. **Internal agents (Cloud, Domain)** - Use direct communication with dynamic discovery via `AgentRegistry`
2. **External agents (A2A)** - Use A2A Protocol with same registration pattern via `a2a_agents` table

Both internal and external agents share the same `AgentCard` descriptor format, enabling unified discovery and capability querying.

## Rationale

### Why Not Full A2A for Internal Agents?

| Concern | Full A2A | Hybrid (Chosen) |
|---------|----------|-----------------|
| Latency | 20-50ms per call (protocol overhead) | 1-5ms (direct calls) |
| Operational complexity | N+1 services to manage | Single deployment unit possible |
| Debugging | Distributed tracing required | Simpler stack traces |
| MVP timeline | Adds complexity | Faster to implement |

Full A2A is designed for **cross-organization, cross-network** agent communication. For internal platform components, it adds overhead without proportional benefit.

### Why A2A-Inspired Registration?

The A2A Protocol's `AgentCard` concept is well-designed for agent discovery:
- Declares agent capabilities (tools, permissions)
- Enables runtime discovery
- Supports health checks
- Version-aware

We adopt this pattern for internal agents without the A2A transport layer.

### When Full A2A Would Be Appropriate

- Cloud Agent runs in customer VPC (on-premises Kubernetes agent)
- Third-party vendors provide Cloud Agents
- Process-level isolation required for compliance
- Cloud Agents shared across multiple platforms

## Consequences

### Positive

- **Easy provider addition** - Deploy new Cloud Agent, it self-registers on startup
- **No routing code changes** - Domain Agents discover providers via registry
- **Low latency** - Direct in-process or RPC calls, no A2A overhead
- **Unified pattern** - Same `AgentCard` format for internal and external agents
- **Capability discovery** - Query registry for "what can this platform monitor?"
- **Independent deployment** - Each agent can be containerized separately if needed

### Negative

- **Two communication patterns** - Direct (internal) vs A2A (external)
- **Registry dependency** - Agents must register on startup
- **Not fully decoupled** - Internal agents share process/deployment (by design)

### Neutral

- Need to maintain `AgentRegistry` as core infrastructure
- External A2A agents still use `a2a_agents` table for persistence

## Implementation

### AgentCard Schema

```python
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel

class AgentType(Enum):
    CLOUD_PROVIDER = "cloud_provider"  # AWS, Azure, GCP, K8s
    DOMAIN = "domain"                   # Cost, Optimization, Remediation
    EXTERNAL = "external"               # SlackBot, Auditor (A2A)

class AgentCapability(BaseModel):
    """Describes what an agent can do"""
    tools: List[str]                        # ["get_costs", "get_resources", ...]
    providers: Optional[List[str]] = None   # For cloud agents: ["aws"]
    permissions_required: List[str]         # ["read:costs", "execute:actions"]

class AgentCard(BaseModel):
    """Unified agent descriptor (A2A-inspired)"""
    name: str
    type: AgentType
    version: str
    capabilities: AgentCapability
    endpoint: Optional[str] = None      # For A2A external agents only
    health_check: Optional[str] = None
```

### AgentRegistry

```python
class AgentRegistry:
    """Unified registry for all agent types"""

    _agents: Dict[str, AgentCard] = {}
    _instances: Dict[str, BaseAgent] = {}

    @classmethod
    def register(cls, card: AgentCard, instance: BaseAgent = None):
        """Register agent with its card and optional instance"""
        cls._agents[card.name] = card
        if instance:
            cls._instances[card.name] = instance

    @classmethod
    def discover(cls,
                 agent_type: AgentType = None,
                 capability: str = None) -> List[AgentCard]:
        """Discover agents by type or capability"""
        results = list(cls._agents.values())
        if agent_type:
            results = [a for a in results if a.type == agent_type]
        if capability:
            results = [a for a in results if capability in a.capabilities.tools]
        return results

    @classmethod
    def get_cloud_agents(cls) -> List[BaseCloudAgent]:
        """Get all registered cloud provider agents"""
        cards = cls.discover(agent_type=AgentType.CLOUD_PROVIDER)
        return [cls._instances[c.name] for c in cards if c.name in cls._instances]

    @classmethod
    def get_agent(cls, name: str) -> Optional[BaseAgent]:
        """Get specific agent instance by name"""
        return cls._instances.get(name)
```

### Self-Registering Cloud Agent

```python
class AWSCloudAgent(BaseCloudAgent):
    """AWS Cloud Agent - self-registers on instantiation"""

    CARD = AgentCard(
        name="aws",
        type=AgentType.CLOUD_PROVIDER,
        version="1.0.0",
        capabilities=AgentCapability(
            tools=["get_costs", "get_resources", "get_recommendations",
                   "get_anomalies", "execute_action", "get_idle_resources"],
            providers=["aws"],
            permissions_required=["read:costs", "read:resources"]
        )
    )

    def __init__(self, mcp_server: AWSMCPServer):
        super().__init__()
        self.mcp = mcp_server
        AgentRegistry.register(self.CARD, self)
```

### Domain Agent Using Registry

```python
class CostAgent:
    """Cost Agent - discovers Cloud Agents dynamically"""

    async def get_multi_cloud_costs(self, tenant_context, params):
        # Discover all cloud agents at runtime
        cloud_agents = AgentRegistry.get_cloud_agents()

        # Filter to tenant's connected providers
        tenant_providers = {a.provider for a in tenant_context.cloud_accounts}
        active_agents = [
            a for a in cloud_agents
            if a.CARD.capabilities.providers[0] in tenant_providers
        ]

        # Fan out to all active cloud agents (parallel)
        tasks = [agent.get_costs(tenant_context, params) for agent in active_agents]
        results = await asyncio.gather(*tasks, return_exceptions=True)

        return self._aggregate_costs(results)
```

### Adding a New Cloud Provider

Steps to add Oracle Cloud support:

1. **Create MCP Server** (`src/mcp_servers/oracle_mcp.py`)
   ```python
   @cloud_provider("oracle", port=8090)
   class OracleMCPServer(BaseMCPServer):
       # Implement 6 required tools
   ```

2. **Create Cloud Agent** (`src/agents/cloud/oracle_agent.py`)
   ```python
   class OracleCloudAgent(BaseCloudAgent):
       CARD = AgentCard(name="oracle", ...)
       # Self-registers on init
   ```

3. **Deploy** - Agent self-registers, Domain Agents discover it automatically

4. **No changes required** to:
   - Coordinator Agent
   - Domain Agents (Cost, Optimization, etc.)
   - Routing logic

## Alternatives Considered

| Alternative | Pros | Cons | Decision |
|-------------|------|------|----------|
| Hardcoded routing | Simple | Code changes for each provider | Rejected |
| Full A2A internal | Maximum decoupling | Latency, complexity | Rejected |
| Plugin system | Very flexible | Over-engineered for need | Rejected |
| **Hybrid registry** | **Balance of flexibility/simplicity** | **Two patterns** | **Accepted** |

## Related Decisions

- [ADR-001: Use MCP Servers](001-use-mcp-servers.md) - MCP is the tool layer, registry is discovery layer
- [ADR-004: Cloud Run Deployment](004-cloud-run-not-kubernetes.md) - Where agents run

## References

- [Google A2A Protocol](https://google.github.io/a2a/)
- [Agent Card Specification](https://google.github.io/a2a/specification/)
- [core/03-agent-routing-spec.md](../../core/03-agent-routing-spec.md) - Agent architecture

## Review

This decision should be reviewed if:
- Need to run Cloud Agents in customer networks (consider full A2A)
- Third-party vendors want to provide Cloud Agents
- Latency of direct calls becomes problematic (unlikely)
- A2A Protocol matures with better internal-agent support
