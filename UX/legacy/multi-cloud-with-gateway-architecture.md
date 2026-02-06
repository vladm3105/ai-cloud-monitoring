# Multi-Cloud Monitoring Architecture with MCP Gateway
## AI Cost Monitoring Platform - Enhanced with Intelligent Orchestration

**Document Version:** 2.0  
**Last Updated:** February 2026  
**Key Addition:** MCP Gateway Agent for intelligent cloud routing and orchestration

---

## Architecture Overview with MCP Gateway

```
┌─────────────────────────────────────────────────────────────────────┐
│                    UNIFIED MONITORING LAYER                          │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    Central Grafana                            │  │
│  │            (Single Unified Dashboard)                         │  │
│  └────────────────────────┬─────────────────────────────────────┘  │
│                            │                                          │
│                            ▼                                          │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │               Prometheus Federation                           │  │
│  │         (Metrics aggregation from all clouds)                 │  │
│  └────────────────────────┬─────────────────────────────────────┘  │
│                            │                                          │
└────────────────────────────┼──────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│              ★ MCP GATEWAY AGENT (NEW) ★                             │
│              Intelligent Cloud Orchestration Layer                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Responsibilities:                                                    │
│  • Route queries to appropriate cloud MCP servers                    │
│  • Enforce tenant cloud access policies                              │
│  • Aggregate responses from multiple clouds                          │
│  • Handle MCP server failures (circuit breaker)                      │
│  • Cache frequently accessed data                                    │
│  • Normalize responses across clouds                                 │
│  • Rate limiting per tenant/cloud                                    │
│                                                                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │  Query       │  │  Tenant      │  │  Response    │             │
│  │  Router      │  │  Policy      │  │  Aggregator  │             │
│  │              │  │  Engine      │  │              │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
│                                                                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │  Circuit     │  │  Cache       │  │  Rate        │             │
│  │  Breaker     │  │  Manager     │  │  Limiter     │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
│                                                                       │
└────────┬────────────────────┬────────────────────┬──────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
┌────────────────┐   ┌────────────────┐   ┌────────────────┐
│  GCP MCP       │   │  AWS MCP       │   │  Azure MCP     │
│  Server        │   │  Server        │   │  Server        │
└────────────────┘   └────────────────┘   └────────────────┘
```

---

## MCP Gateway Agent Components

### 1. Query Router

**Purpose:** Determine which cloud MCP server(s) to query based on request

```python
# query_router.py
from typing import List, Dict
import asyncio

class QueryRouter:
    """Routes queries to appropriate cloud MCP servers"""
    
    def __init__(self, cloud_registry_db, tenant_config_db):
        self.cloud_registry = cloud_registry_db
        self.tenant_config = tenant_config_db
    
    async def route_query(self, query: Dict, tenant_id: str) -> List[str]:
        """
        Determine which clouds to query based on:
        - Tenant's enabled clouds
        - Query parameters (cloud_provider filter)
        - Cloud health status
        """
        # Get tenant's enabled clouds
        enabled_clouds = await self.get_enabled_clouds(tenant_id)
        
        # Check if query specifies specific clouds
        if 'cloud_provider' in query:
            requested_clouds = query['cloud_provider'].split(',')
            clouds_to_query = [c for c in requested_clouds if c in enabled_clouds]
        else:
            # Query all enabled clouds
            clouds_to_query = enabled_clouds
        
        # Filter out unhealthy clouds
        healthy_clouds = await self.filter_healthy_clouds(clouds_to_query)
        
        return healthy_clouds
    
    async def get_enabled_clouds(self, tenant_id: str) -> List[str]:
        """Query database for tenant's enabled clouds"""
        result = await self.tenant_config.fetch(
            """
            SELECT cloud_provider 
            FROM tenant_cloud_config 
            WHERE tenant_id = $1 AND is_enabled = true
            """,
            tenant_id
        )
        return [row['cloud_provider'] for row in result]
    
    async def filter_healthy_clouds(self, clouds: List[str]) -> List[str]:
        """Remove clouds that are currently down"""
        healthy = []
        for cloud in clouds:
            is_healthy = await self.check_health(cloud)
            if is_healthy:
                healthy.append(cloud)
        return healthy
    
    async def check_health(self, cloud_provider: str) -> bool:
        """Check if cloud MCP server is healthy"""
        health_url = await self.cloud_registry.get_health_url(cloud_provider)
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(health_url, timeout=2.0)
                return response.status_code == 200
        except:
            return False
```

---

### 2. Tenant Policy Engine

**Purpose:** Enforce tenant-specific cloud access and quotas

```python
# tenant_policy_engine.py
from datetime import datetime, timedelta
from decimal import Decimal

class TenantPolicyEngine:
    """Enforces tenant policies for cloud access"""
    
    def __init__(self, policy_db):
        self.policy_db = policy_db
    
    async def check_cloud_access(self, tenant_id: str, cloud_provider: str) -> bool:
        """Check if tenant has access to specific cloud"""
        policy = await self.policy_db.fetch_one(
            """
            SELECT is_enabled, cost_quota_monthly, alert_threshold
            FROM tenant_cloud_config
            WHERE tenant_id = $1 AND cloud_provider = $2
            """,
            tenant_id, cloud_provider
        )
        
        if not policy or not policy['is_enabled']:
            return False
        
        # Check if tenant exceeded quota
        current_spend = await self.get_current_month_spend(tenant_id, cloud_provider)
        if current_spend >= policy['cost_quota_monthly']:
            return False
        
        return True
    
    async def get_current_month_spend(self, tenant_id: str, cloud_provider: str) -> Decimal:
        """Get tenant's spend for current month on specific cloud"""
        # This would query the appropriate cloud's TimescaleDB
        # via the MCP server
        pass
    
    async def should_alert(self, tenant_id: str, cloud_provider: str) -> bool:
        """Check if tenant has crossed alert threshold"""
        policy = await self.policy_db.fetch_one(
            """
            SELECT cost_quota_monthly, alert_threshold
            FROM tenant_cloud_config
            WHERE tenant_id = $1 AND cloud_provider = $2
            """,
            tenant_id, cloud_provider
        )
        
        current_spend = await self.get_current_month_spend(tenant_id, cloud_provider)
        threshold_amount = policy['cost_quota_monthly'] * policy['alert_threshold']
        
        return current_spend >= threshold_amount
```

---

### 3. Response Aggregator

**Purpose:** Combine responses from multiple cloud MCP servers

```python
# response_aggregator.py
from typing import List, Dict
import asyncio

class ResponseAggregator:
    """Aggregates responses from multiple cloud MCP servers"""
    
    async def aggregate_cost_data(self, responses: List[Dict]) -> Dict:
        """
        Combine cost data from multiple clouds
        
        Input: [
            {"cloud_provider": "gcp", "total_cost": 1000, "by_model": {...}},
            {"cloud_provider": "aws", "total_cost": 1500, "by_model": {...}},
            {"cloud_provider": "azure", "total_cost": 800, "by_model": {...}}
        ]
        
        Output: {
            "total_cost": 3300,
            "by_cloud": {...},
            "by_model_aggregated": {...}
        }
        """
        total_cost = sum(r.get('total_cost', 0) for r in responses)
        
        by_cloud = {
            r['cloud_provider']: r['total_cost'] 
            for r in responses
        }
        
        # Aggregate models across clouds
        all_models = {}
        for response in responses:
            for model, cost in response.get('by_model', {}).items():
                cloud = response['cloud_provider']
                model_key = f"{model}@{cloud}"
                all_models[model_key] = cost
        
        return {
            "total_cost": total_cost,
            "by_cloud": by_cloud,
            "by_model_aggregated": all_models,
            "clouds_queried": [r['cloud_provider'] for r in responses]
        }
    
    async def aggregate_token_usage(self, responses: List[Dict]) -> Dict:
        """Aggregate token usage across clouds"""
        total_tokens = sum(r.get('total_tokens', 0) for r in responses)
        
        by_cloud = {}
        for response in responses:
            cloud = response['cloud_provider']
            by_cloud[cloud] = {
                'input_tokens': response.get('input_tokens', 0),
                'output_tokens': response.get('output_tokens', 0),
                'total_tokens': response.get('total_tokens', 0)
            }
        
        return {
            "total_tokens": total_tokens,
            "by_cloud": by_cloud
        }
```

---

### 4. Circuit Breaker

**Purpose:** Handle MCP server failures gracefully

```python
# circuit_breaker.py
from enum import Enum
from datetime import datetime, timedelta
from typing import Optional

class CircuitState(Enum):
    CLOSED = "closed"       # Normal operation
    OPEN = "open"           # Too many failures, stop trying
    HALF_OPEN = "half_open" # Testing if service recovered

class CircuitBreaker:
    """Circuit breaker for cloud MCP servers"""
    
    def __init__(self, failure_threshold: int = 5, timeout_seconds: int = 60):
        self.failure_threshold = failure_threshold
        self.timeout = timedelta(seconds=timeout_seconds)
        
        # Track state per cloud
        self.states = {}  # {cloud_provider: CircuitState}
        self.failure_counts = {}  # {cloud_provider: int}
        self.last_failure_time = {}  # {cloud_provider: datetime}
    
    async def call(self, cloud_provider: str, func, *args, **kwargs):
        """Execute function with circuit breaker protection"""
        state = self.get_state(cloud_provider)
        
        if state == CircuitState.OPEN:
            # Check if timeout elapsed
            if self.should_attempt_reset(cloud_provider):
                self.states[cloud_provider] = CircuitState.HALF_OPEN
            else:
                raise Exception(f"Circuit breaker OPEN for {cloud_provider}")
        
        try:
            result = await func(*args, **kwargs)
            self.record_success(cloud_provider)
            return result
        except Exception as e:
            self.record_failure(cloud_provider)
            raise
    
    def get_state(self, cloud_provider: str) -> CircuitState:
        """Get current circuit state for cloud"""
        return self.states.get(cloud_provider, CircuitState.CLOSED)
    
    def record_success(self, cloud_provider: str):
        """Record successful call"""
        self.failure_counts[cloud_provider] = 0
        self.states[cloud_provider] = CircuitState.CLOSED
    
    def record_failure(self, cloud_provider: str):
        """Record failed call"""
        count = self.failure_counts.get(cloud_provider, 0) + 1
        self.failure_counts[cloud_provider] = count
        self.last_failure_time[cloud_provider] = datetime.now()
        
        if count >= self.failure_threshold:
            self.states[cloud_provider] = CircuitState.OPEN
    
    def should_attempt_reset(self, cloud_provider: str) -> bool:
        """Check if enough time passed to try again"""
        last_failure = self.last_failure_time.get(cloud_provider)
        if not last_failure:
            return True
        return datetime.now() - last_failure > self.timeout
```

---

### 5. Cache Manager

**Purpose:** Cache frequently accessed data to reduce load on MCP servers

```python
# cache_manager.py
from typing import Optional, Dict
import asyncio
import hashlib
import json

class CacheManager:
    """Redis-based cache for MCP server responses"""
    
    def __init__(self, redis_client):
        self.redis = redis_client
        self.default_ttl = 300  # 5 minutes
    
    def generate_cache_key(self, tenant_id: str, query: Dict) -> str:
        """Generate deterministic cache key"""
        query_str = json.dumps(query, sort_keys=True)
        query_hash = hashlib.md5(query_str.encode()).hexdigest()
        return f"mcp_cache:{tenant_id}:{query_hash}"
    
    async def get(self, tenant_id: str, query: Dict) -> Optional[Dict]:
        """Get cached response"""
        cache_key = self.generate_cache_key(tenant_id, query)
        cached = await self.redis.get(cache_key)
        
        if cached:
            return json.loads(cached)
        return None
    
    async def set(self, tenant_id: str, query: Dict, response: Dict, ttl: int = None):
        """Cache response"""
        cache_key = self.generate_cache_key(tenant_id, query)
        response_str = json.dumps(response)
        
        await self.redis.setex(
            cache_key,
            ttl or self.default_ttl,
            response_str
        )
    
    async def invalidate_tenant(self, tenant_id: str):
        """Invalidate all cache for tenant"""
        pattern = f"mcp_cache:{tenant_id}:*"
        keys = await self.redis.keys(pattern)
        if keys:
            await self.redis.delete(*keys)
    
    async def invalidate_cloud(self, tenant_id: str, cloud_provider: str):
        """Invalidate cache for specific cloud"""
        # This is simplified - in production you'd need better key structure
        await self.invalidate_tenant(tenant_id)
```

---

### 6. Rate Limiter

**Purpose:** Prevent abuse and ensure fair usage

```python
# rate_limiter.py
from datetime import datetime, timedelta
from typing import Optional

class RateLimiter:
    """Token bucket rate limiter per tenant/cloud"""
    
    def __init__(self, redis_client):
        self.redis = redis_client
    
    async def check_limit(
        self, 
        tenant_id: str, 
        cloud_provider: str,
        max_requests: int = 100,
        window_seconds: int = 60
    ) -> bool:
        """
        Check if request should be allowed
        
        Returns True if allowed, False if rate limit exceeded
        """
        key = f"rate_limit:{tenant_id}:{cloud_provider}"
        
        # Increment counter
        count = await self.redis.incr(key)
        
        # Set expiry on first request
        if count == 1:
            await self.redis.expire(key, window_seconds)
        
        return count <= max_requests
    
    async def get_remaining(
        self,
        tenant_id: str,
        cloud_provider: str,
        max_requests: int = 100
    ) -> int:
        """Get remaining requests in current window"""
        key = f"rate_limit:{tenant_id}:{cloud_provider}"
        count = await self.redis.get(key)
        
        if not count:
            return max_requests
        
        return max(0, max_requests - int(count))
```

---

## Complete MCP Gateway API

```python
# mcp_gateway.py
from fastapi import FastAPI, HTTPException, Depends
from typing import List, Dict, Optional
import httpx
import asyncio

app = FastAPI(title="MCP Gateway Agent")

class MCPGateway:
    """Main gateway orchestrating all cloud MCP servers"""
    
    def __init__(self):
        self.query_router = QueryRouter(cloud_registry_db, tenant_config_db)
        self.policy_engine = TenantPolicyEngine(policy_db)
        self.aggregator = ResponseAggregator()
        self.circuit_breaker = CircuitBreaker()
        self.cache = CacheManager(redis_client)
        self.rate_limiter = RateLimiter(redis_client)
    
    async def query_costs(
        self,
        tenant_id: str,
        query: Dict
    ) -> Dict:
        """
        Main entry point for cost queries
        
        1. Check cache
        2. Route to appropriate clouds
        3. Query each cloud MCP server (with circuit breaker)
        4. Aggregate responses
        5. Cache result
        6. Return to caller
        """
        # Check cache first
        cached = await self.cache.get(tenant_id, query)
        if cached:
            return {"source": "cache", "data": cached}
        
        # Determine which clouds to query
        clouds_to_query = await self.query_router.route_query(query, tenant_id)
        
        if not clouds_to_query:
            raise HTTPException(
                status_code=403,
                detail="No enabled clouds for this tenant"
            )
        
        # Check rate limits
        for cloud in clouds_to_query:
            if not await self.rate_limiter.check_limit(tenant_id, cloud):
                raise HTTPException(
                    status_code=429,
                    detail=f"Rate limit exceeded for {cloud}"
                )
        
        # Query each cloud in parallel
        tasks = []
        for cloud in clouds_to_query:
            task = self.query_cloud_with_circuit_breaker(cloud, query)
            tasks.append(task)
        
        # Gather results (continues even if some fail)
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Filter out exceptions
        successful_results = [
            r for r in results 
            if not isinstance(r, Exception)
        ]
        
        if not successful_results:
            raise HTTPException(
                status_code=503,
                detail="All cloud MCP servers failed"
            )
        
        # Aggregate responses
        aggregated = await self.aggregator.aggregate_cost_data(successful_results)
        
        # Cache result
        await self.cache.set(tenant_id, query, aggregated, ttl=300)
        
        return {
            "source": "live",
            "data": aggregated,
            "clouds_failed": len(results) - len(successful_results)
        }
    
    async def query_cloud_with_circuit_breaker(
        self,
        cloud_provider: str,
        query: Dict
    ) -> Dict:
        """Query specific cloud with circuit breaker protection"""
        async def query_cloud():
            mcp_url = await self.get_mcp_url(cloud_provider)
            endpoint = f"{mcp_url}/metrics/costs/daily"
            
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    endpoint,
                    params=query,
                    timeout=5.0
                )
                response.raise_for_status()
                return response.json()
        
        return await self.circuit_breaker.call(
            cloud_provider,
            query_cloud
        )
    
    async def get_mcp_url(self, cloud_provider: str) -> str:
        """Get MCP server URL for cloud"""
        # Query cloud_registry database
        pass

# FastAPI endpoints

@app.get("/api/v1/costs/daily")
async def get_daily_costs(
    tenant_id: str,
    start_date: str,
    end_date: str,
    cloud_provider: Optional[str] = None
):
    """Get daily costs across enabled clouds"""
    gateway = MCPGateway()
    
    query = {
        "start_date": start_date,
        "end_date": end_date,
        "cloud_provider": cloud_provider
    }
    
    result = await gateway.query_costs(tenant_id, query)
    return result

@app.get("/api/v1/costs/by-model")
async def get_costs_by_model(
    tenant_id: str,
    model: str,
    cloud_provider: Optional[str] = None
):
    """Get costs for specific model across clouds"""
    gateway = MCPGateway()
    
    query = {
        "model": model,
        "cloud_provider": cloud_provider
    }
    
    result = await gateway.query_costs(tenant_id, query)
    return result

@app.post("/api/v1/clouds/{cloud_provider}/enable")
async def enable_cloud(tenant_id: str, cloud_provider: str):
    """Enable a cloud for tenant"""
    gateway = MCPGateway()
    
    # Update database
    await update_tenant_cloud_config(tenant_id, cloud_provider, enabled=True)
    
    # Invalidate cache
    await gateway.cache.invalidate_tenant(tenant_id)
    
    return {"status": "enabled"}

@app.post("/api/v1/clouds/{cloud_provider}/disable")
async def disable_cloud(tenant_id: str, cloud_provider: str):
    """Disable a cloud for tenant"""
    gateway = MCPGateway()
    
    # Update database
    await update_tenant_cloud_config(tenant_id, cloud_provider, enabled=False)
    
    # Invalidate cache
    await gateway.cache.invalidate_tenant(tenant_id)
    
    return {"status": "disabled"}

@app.get("/api/v1/health")
async def health_check():
    """Gateway health check"""
    gateway = MCPGateway()
    
    # Check health of all cloud MCP servers
    clouds = ['gcp', 'aws', 'azure']
    health_status = {}
    
    for cloud in clouds:
        is_healthy = await gateway.query_router.check_health(cloud)
        circuit_state = gateway.circuit_breaker.get_state(cloud)
        
        health_status[cloud] = {
            "healthy": is_healthy,
            "circuit_state": circuit_state.value
        }
    
    return {
        "gateway": "healthy",
        "clouds": health_status
    }
```

---

## Updated Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│            UNIFIED MONITORING LAYER                          │
│                                                               │
│  ┌────────────┐  ┌─────────────┐  ┌────────────┐           │
│  │  Grafana   │  │ Prometheus  │  │  Registry  │           │
│  │ Dashboards │  │ Federation  │  │     DB     │           │
│  └──────┬─────┘  └──────┬──────┘  └──────┬─────┘           │
│         │               │                 │                  │
│         └───────────────┴─────────────────┘                  │
│                         │                                     │
└─────────────────────────┼─────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│         ★★★ MCP GATEWAY AGENT ★★★                           │
│                                                               │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐   │
│  │ Query  │ │ Policy │ │Response│ │Circuit │ │ Cache  │   │
│  │ Router │ │ Engine │ │Aggreg. │ │Breaker │ │Manager │   │
│  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘   │
│                                                               │
│  Features:                                                    │
│  • Intelligent routing based on tenant config               │
│  • Response aggregation from multiple clouds                │
│  • Failure handling (circuit breaker)                       │
│  • Caching (5 min TTL)                                      │
│  • Rate limiting (100 req/min per cloud)                    │
│  • Tenant policy enforcement                                │
│                                                               │
└────┬─────────────────┬─────────────────┬─────────────────────┘
     │                 │                 │
     ▼                 ▼                 ▼
┌─────────┐      ┌─────────┐      ┌─────────┐
│   GCP   │      │   AWS   │      │  Azure  │
│   MCP   │      │   MCP   │      │   MCP   │
└─────────┘      └─────────┘      └─────────┘
```

---

## Benefits of MCP Gateway Agent

| Benefit | Description |
|---------|-------------|
| **Intelligent Routing** | Queries only enabled & healthy clouds |
| **Failure Resilience** | Circuit breaker prevents cascading failures |
| **Performance** | Caching reduces load on MCP servers |
| **Security** | Enforces tenant policies and rate limits |
| **Aggregation** | Single query returns data from all clouds |
| **Abstraction** | Grafana doesn't need to know about 3 clouds |

---

## When to Use MCP Gateway vs Direct Queries

### Use MCP Gateway For:
- ✅ User-facing dashboard queries (Grafana)
- ✅ Multi-cloud aggregated views
- ✅ Tenant-specific queries with access control
- ✅ Complex queries requiring orchestration
- ✅ API endpoints for external consumers

### Use Direct Prometheus Scraping For:
- ✅ Time-series metrics collection (15s intervals)
- ✅ Alerting on raw metrics
- ✅ Historical data retention
- ✅ Low-latency metric queries

### Hybrid Approach (Recommended):
- **Prometheus** scrapes each cloud's exporter directly for metrics
- **Grafana** queries **both**:
  - Prometheus for time-series charts
  - MCP Gateway for on-demand aggregated queries

---

## Deployment

**Deploy MCP Gateway:**

```bash
# GCP Cloud Run
gcloud run deploy mcp-gateway \
  --image gcr.io/ai-cost-monitoring/mcp-gateway:latest \
  --region us-central1 \
  --memory 1Gi \
  --set-env-vars REDIS_URL=redis://... \
  --set-env-vars DB_URL=postgresql://...

# Environment variables needed:
# - REDIS_URL (for caching and rate limiting)
# - DB_URL (for cloud registry and tenant config)
# - GCP_MCP_URL, AWS_MCP_URL, AZURE_MCP_URL
```

**Infrastructure Cost:**
- MCP Gateway: $15-25/month (Cloud Run)
- Redis: $10-20/month (for cache & rate limiting)
- **Total addition: $25-45/month**

**Updated Total Cost: $315-475/month**

---

**Document End**
