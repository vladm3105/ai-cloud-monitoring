# ADR-008: Database Strategy — Firestore MVP, PostgreSQL Multi-Tenant

## Status

Accepted

## Date

2026-02-07T00:00:00

## Context

The original architecture specified PostgreSQL (Neon.tech or Cloud SQL) for all operational data. However, for a single-tenant MVP, this adds:

- $19-50/month infrastructure cost
- Additional complexity (connection pooling, migrations)
- Slower time-to-market

We need to decide the database strategy that balances:
1. MVP simplicity and cost
2. Multi-tenant readiness for future scaling

## Decision

**MVP Phase**: Use Firestore for configuration and BigQuery for cost analytics. No PostgreSQL.

**Multi-Tenant Phase**: Add PostgreSQL (Neon.tech) when tenant isolation becomes necessary.

## Rationale

### Why Firestore for MVP?

| Factor | Firestore | PostgreSQL |
|--------|-----------|------------|
| Monthly cost | $0 (free tier) | $19-50 |
| Scale-to-zero | Yes | Neon only |
| Setup complexity | Low | Medium |
| Serverless | Native | Requires pooler |
| GCP integration | Native | External (Neon) |

### Data Classification

| Data Type | MVP Storage | Multi-Tenant Storage |
|-----------|-------------|----------------------|
| Cost metrics (time-series) | BigQuery | BigQuery |
| Budget thresholds | Firestore | PostgreSQL |
| Cloud account configs | Firestore | PostgreSQL |
| User preferences | Firestore | PostgreSQL |
| Alert history | Firestore | PostgreSQL |
| Audit logs | Cloud Logging | PostgreSQL |
| Tenants/Users | N/A (single) | PostgreSQL (RLS) |

### Why Not PostgreSQL from Day 1?

1. **Cost**: $0 vs $19+/month — significant for validation phase
2. **Complexity**: No migrations, no connection pooling, no ORM
3. **Time-to-market**: Faster MVP launch
4. **Validation**: Prove product value before investing in infrastructure

### Why PostgreSQL for Multi-Tenant?

1. **Row-Level Security (RLS)**: Enforced tenant isolation at database level
2. **Complex queries**: JOINs, transactions, referential integrity
3. **Audit compliance**: Immutable audit tables with constraints
4. **RBAC**: Role-based access control queries
5. **Ecosystem**: ORM support, migration tools, backup/restore

## Implementation

### MVP Data Model (Firestore)

```
firestore/
├── config/settings              # Global config
├── budgets/{budget_id}          # Budget definitions
├── cloud_accounts/{account_id}  # Connected accounts
├── alerts/{alert_id}            # Alert history
└── preferences/ui               # User preferences
```

### Multi-Tenant Data Model (PostgreSQL)

```sql
-- Tenant isolation via RLS
CREATE TABLE tenants (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    plan TEXT DEFAULT 'free'
);

CREATE TABLE users (
    id UUID PRIMARY KEY,
    tenant_id UUID REFERENCES tenants(id),
    email TEXT NOT NULL,
    role TEXT NOT NULL
);

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON users
    USING (tenant_id = current_setting('app.tenant_id')::UUID);
```

### Migration Path

| Step | Action | Effort |
|------|--------|--------|
| 1 | Provision Neon.tech PostgreSQL | 1 hour |
| 2 | Create schema with RLS | 2-4 hours |
| 3 | Write Firestore → PostgreSQL migration script | 4-8 hours |
| 4 | Update application data access layer | 8-16 hours |
| 5 | Test tenant isolation | 4-8 hours |
| 6 | Deprecate Firestore collections | 1 hour |

**Total migration effort**: 2-4 days

## Consequences

### Positive

- ✅ $0 database cost during MVP validation
- ✅ Faster MVP launch (no database setup/migrations)
- ✅ Simpler local development (Firestore emulator)
- ✅ Native GCP integration
- ✅ Clear migration path when multi-tenant is needed

### Negative

- ⚠️ Limited query capabilities (no JOINs in Firestore)
- ⚠️ Migration effort required for multi-tenant
- ⚠️ Two different data access patterns to maintain temporarily
- ⚠️ No referential integrity in MVP

### Mitigations

1. **Abstraction layer**: Implement data access interfaces that can swap backends
2. **Schema design**: Design Firestore structure to mirror future PostgreSQL tables
3. **Early planning**: Document migration scripts before they're needed

## Alternatives Considered

| Option | Cost | Complexity | Multi-tenant Ready | Decision |
|--------|------|------------|-------------------|----------|
| PostgreSQL from Day 1 | $19+/mo | Medium | Yes | Rejected (premature) |
| **Firestore → PostgreSQL** | $0 → $19 | Low → Medium | Deferred | **Accepted** |
| Firestore only | $0 | Low | Limited | Rejected (no RLS) |
| SQLite/Turso | $0 | Low | Limited | Rejected (less GCP native) |

## Related Decisions

- [ADR-002: GCP as First Home Cloud](002-gcp-only-first.md)
- [ADR-003: Use BigQuery, Not TimescaleDB](003-use-bigquery-not-timescaledb.md)
- [MVP_ARCHITECTURE.md](../architecture/MVP_ARCHITECTURE.md)

## Review

Revisit this decision:
- When first paying customer requests multi-tenant features
- When user/tenant management becomes necessary
- When audit/compliance requirements are defined
