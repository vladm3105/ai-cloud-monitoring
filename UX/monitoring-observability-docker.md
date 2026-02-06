# Monitoring & Observability Architecture - Docker Deployment
## AI Cost Monitoring Platform

**Document Version:** 1.0  
**Last Updated:** February 2026  
**Target Deployment:** Docker Compose / Docker Swarm / Local Development

For complete Docker deployment documentation including:
- Full docker-compose.yml configuration
- Loki Docker driver setup (no Promtail needed)
- Volume management and backup strategies
- Container health monitoring
- Local development workflow
- Performance tuning for Docker environment

See the comprehensive cloud deployment document which covers the same monitoring stack principles. The Docker-specific differences are:

**Key Differences from Cloud:**
1. **No Promtail** - Use Loki Docker logging driver instead
2. **Volume Persistence** - All data in Docker volumes
3. **Local Network** - All containers on bridge network
4. **Self-Hosted** - Zero cloud costs, just hardware

**Quick Start:**

docker-compose.yml core services:
- prometheus (metrics collection)
- loki (log aggregation)
- grafana (dashboards)
- timescaledb (LLM cost database)
- alertmanager (notifications)

Application containers configured with Loki logging driver for automatic log shipping.

**Implementation:** Follow the cloud document's architecture and dashboard designs. For Docker-specific configuration, the main changes are:
- Replace Cloud Logging with Loki Docker driver
- Use Docker volumes instead of cloud storage
- Use bridge networking instead of VPC
- Service discovery via container names (not URLs)

