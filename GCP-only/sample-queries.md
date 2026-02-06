# GCP Cost Monitoring Agent — Sample Queries & Use Cases

## Overview

This document provides concrete examples of natural language queries that the Cost Monitoring Agent can handle, along with the MCP tools used and expected responses. Use this to:

- **Validate architecture** - Ensure your design supports real use cases
- **Test implementation** - Reference queries for integration tests
- **Train users** - Show what's possible with the agent

---

## Query Categories

| Category | Example Count | Complexity |
|----------|---------------|------------|
| [Cost Queries](#cost-queries) | 8 | Low |
| [Budget & Alerts](#budget--alerts) | 5 | Medium |
| [Optimization](#optimization--recommendations) | 6 | Medium |
| [Anomaly Detection](#anomaly-detection) | 4 | High |
| [Resource Management](#resource-management) | 5 | High |
| [Multi-Step Workflows](#multi-step-workflows) | 4 | High |

---

## Cost Queries

### Q1: Basic Cost Summary

**User Query:**
```
"How much did I spend on GCP last month?"
```

**MCP Tool Call:**
```python
get_cost_summary(
    days=30,
    group_by="day"
)
```

**Expected Response:**
```
📊 Your GCP spend for the last 30 days is $12,450.67

Daily breakdown:
• Jan 5 - Jan 11: $2,100/week (avg $300/day)
• Jan 12 - Jan 18: $3,200/week (avg $457/day) ⬆️ 52% increase
• Jan 19 - Jan 25: $2,950/week (avg $421/day)
• Jan 26 - Feb 1: $2,800/week (avg $400/day)

📈 Trending: Spending increased by 15% compared to previous month.

[See detailed breakdown] [Find savings opportunities]
```

---

### Q2: Service Breakdown

**User Query:**
```
"Which GCP services am I spending the most on?"
```

**MCP Tool Call:**
```python
get_cost_summary(
    days=30,
    group_by="service"
)
```

**Expected Response:**
```
📊 Top GCP services by cost (last 30 days):

1. Compute Engine ········· $6,200 (50%)
   ├─ Instances: $4,800 (39%)
   ├─ Persistent Disks: $900 (7%)
   └─ Network egress: $500 (4%)

2. BigQuery ·············· $3,100 (25%)
   ├─ Query processing: $2,400
   └─ Storage: $700

3. Cloud Storage ·········· $1,500 (12%)

4. Cloud SQL ·············· $980 (8%)

5. Other services ········· $670 (5%)

💡 Compute Engine is your largest cost driver. Run optimization scan?
```

---

### Q3: Project-Specific Costs

**User Query:**
```
"Show me costs for the prod-api project"
```

**MCP Tool Call:**
```python
scan_organization() # to find project
get_cost_summary(
    project_id="prod-api",
    days=30,
    group_by="service"
)
```

**Expected Response:**
```
📊 Cost Summary for prod-api (last 30 days):

Total: $4,250.00

Top Services:
• Cloud Run: $2,100 (49%)
• Cloud SQL: $1,200 (28%)
• Cloud Load Balancing: $580 (14%)
• Cloud Storage: $370 (9%)

This project accounts for 34% of your total GCP spend.

[Compare to last month] [View resource details]
```

---

### Q4: Time Comparison

**User Query:**
```
"Compare this month's spending to last month"
```

**MCP Tool Call:**
```python
get_cost_summary(days=30, group_by="month")  # current month
get_cost_summary(days=60, group_by="month")  # include previous month
```

**Expected Response:**
```
📊 Month-over-Month Comparison:

January 2026: $12,450 ⬆️
December 2025: $10,800
───────────────────────
Change: +$1,650 (+15.3%)

Breakdown of increase:
• Compute Engine: +$800 (new VM instances in prod)
• BigQuery: +$600 (large data pipeline added)
• Cloud Storage: +$250 (increased backup retention)

⚠️ If this trend continues, February will exceed budget by 20%.

[See anomalies] [Get recommendations]
```

---

### Q5: Specific Date Range

**User Query:**
```
"What did I spend between January 10 and January 20?"
```

**MCP Tool Call:**
```python
get_cost_summary(
    start_date="2026-01-10",
    end_date="2026-01-20",
    group_by="day"
)
```

**Expected Response:**
```
📊 Spend from Jan 10 - Jan 20, 2026:

Total: $4,580.00
Daily average: $416.36

Highest day: Jan 15 ($685) 🔴 65% above average
Lowest day: Jan 19 ($340)

Services during this period:
• Compute Engine: $2,300
• BigQuery: $1,400
• Cloud Storage: $550
• Cloud SQL: $330
```

---

### Q6: Regional Costs

**User Query:**
```
"How much am I spending in us-central1 vs europe-west1?"
```

**MCP Tool Call:**
```python
get_cost_summary(
    days=30,
    group_by="region"
)
```

**Expected Response:**
```
📊 Cost by Region (last 30 days):

🇺🇸 us-central1 ·········· $8,200 (66%)
  • Compute Engine: $4,500
  • Cloud SQL: $2,100
  • BigQuery: $1,600

🇪🇺 europe-west1 ········· $2,900 (23%)
  • Compute Engine: $1,800
  • Cloud Storage: $800
  • Cloud SQL: $300

🇦🇸 asia-southeast1 ······ $1,350 (11%)
  • Compute Engine: $950
  • Cloud Run: $400

💡 Tip: europe-west1 is 12% cheaper than us-central1 for Compute Engine.
```

---

### Q7: Cost Forecast

**User Query:**
```
"What will I spend by the end of the month at this rate?"
```

**MCP Tool Call:**
```python
get_cost_summary(days=30)  # historical data
# Calculate daily average and project
```

**Expected Response:**
```
📈 Forecast for February 2026:

Current spend (Feb 1-4): $1,680
Daily average: $420
Days remaining: 24

Projected month-end total: $11,760

Your budget: $10,000
Expected overage: $1,760 (17.6% over) ⚠️

Confidence: HIGH (based on 30-day trend)

Recommendation: Review idle resources or rightsize VMs to stay within budget.

[Get optimization suggestions] [Adjust budget]
```

---

### Q8: Tag-Based Costs

**User Query:**
```
"Show me costs for resources tagged with team=ml-research"
```

**MCP Tool Call:**
```python
get_cost_summary(
    days=30,
    filter_tags={"team": "ml-research"}
)
```

**Expected Response:**
```
📊 Costs for team=ml-research (last 30 days):

Total: $8,450

Resources:
• 12 Compute instances (8x with GPUs): $6,200
• 3 Cloud SQL databases: $1,400
• Cloud Storage (ml-datasets bucket): $850

Projects using this team tag:
• ml-training-prod (3 instances)
• ml-experiments-dev (9 instances)

⚠️ This team accounts for 68% of total GCP spend.

[Breakdown by project] [Find savings]
```

---

## Budget & Alerts

### Q9: Budget Status

**User Query:**
```
"Am I close to my budget limit?"
```

**MCP Tool Call:**
```python
get_budget_status()
```

**Expected Response:**
```
💰 Budget Status:

Organization Budget ($10,000/month)
━━━━━━━━━━━━━━━━━━━ 87% used
Current spend: $8,700
Remaining: $1,300
Days left in month: 6

⚠️ WARNING: At current rate ($420/day), you'll exceed budget by ~$820.

Alert thresholds:
✅ 50% - Triggered Jan 15
✅ 80% - Triggered Jan 28
⏳ 100% - Projects to trigger Feb 3

[View recommendations] [Adjust budget] [Set up circuit breaker]
```

---

### Q10: Create Budget

**User Query:**
```
"Set a $5,000 monthly budget for the ml-training project"
```

**MCP Tool Call:**
```python
create_budget(
    name="ML Training Budget",
    amount_usd=5000,
    scope_type="project",
    scope_value="ml-training-prod",
    alert_thresholds=[0.5, 0.8, 1.0]
)
```

**Expected Response:**
```
✅ Budget created successfully!

Budget: ML Training Budget
Amount: $5,000/month
Scope: ml-training-prod project

Alert thresholds:
• 50% ($2,500) → Email notification
• 80% ($4,000) → Email + Pub/Sub
• 100% ($5,000) → Critical alert + Pub/Sub

Current spend this month: $3,200 (64%)

Your budget is already at 64%. You'll receive an 80% alert soon.

[Modify thresholds] [View budget details]
```

---

### Q11: Budget Alerts History

**User Query:**
```
"Show me all budget alerts from last week"
```

**MCP Tool Call:**
```python
get_budget_status()
# Filter alerts by date range
```

**Expected Response:**
```
🔔 Budget Alerts (Last 7 days):

Jan 28, 10:34 AM - Organization Budget (80% threshold)
├─ Current: $8,000 of $10,000
└─ Recipients: admin@company.com, finance@company.com

Jan 29, 2:15 PM - ML Training Budget (100% threshold) 🔴
├─ Current: $5,100 of $5,000
├─ Overage: $100 (2%)
└─ Action: Circuit breaker triggered (no new resources)

Jan 30, 9:00 AM - Dev Environment Budget (50% threshold)
├─ Current: $1,250 of $2,500
└─ Status: On track

[Configure alert channels] [View all budgets]
```

---

### Q12: Update Budget

**User Query:**
```
"Increase the organization budget to $15,000"
```

**MCP Tool Call:**
```python
create_budget(
    name="Organization Budget",
    amount_usd=15000,
    scope_type="organization",
    scope_value=org_id
)
```

**Expected Response:**
```
✅ Budget updated!

Organization Budget
Previous: $10,000/month
New: $15,000/month
Change: +$5,000 (+50%)

Current utilization:
$8,700 of $15,000 (58%)

Thresholds updated:
• 50% = $7,500 (already passed)
• 80% = $12,000
• 100% = $15,000

With current spend rate, you'll use 78% of new budget by month-end.

Approval logged by: user@company.com
```

---

### Q13: Forecasted Budget Alert

**User Query:**
```
"Will I exceed my budget this month?"
```

**MCP Tool Call:**
```python
get_budget_status()
get_cost_summary(days=30)  # for forecasting
```

**Expected Response:**
```
📊 Budget Forecast:

Budget: $10,000/month
Current spend (28 days): $8,700
Projected month-end: $10,850

⚠️ YES - You're projected to exceed budget by $850 (8.5%)

Trigger date: Feb 3 (in 3 days)

What's driving this:
• Compute Engine instances running 24/7 ($420/day)
• BigQuery queries increased 40% this week

Recommendations to stay under budget:
1. Stop 8 idle dev VMs → Save $380/month
2. Downsize 4 over-provisioned instances → Save $520/month

[Apply recommendations] [Increase budget]
```

---

## Optimization & Recommendations

### Q14: Find Idle Resources

**User Query:**
```
"Show me all idle VMs"
```

**MCP Tool Call:**
```python
get_recommendations(
    recommendation_type="idle_vm"
)
```

**Expected Response:**
```
💡 Idle VM Recommendations:

Found 12 idle instances (CPU < 1% for 8+ days):

High Priority (stop immediately):
1. ml-experiment-vm-7 (n1-highmem-32, us-central1)
   • Idle: 15 days
   • Monthly cost: $680
   • Action: Stop or delete

2. dev-test-instance (n1-standard-8, europe-west1)
   • Idle: 12 days
   • Monthly cost: $245
   • Action: Stop

3. backup-processor (n1-standard-4, us-east1)
   • Idle: 20 days
   • Monthly cost: $150
   • Action: Delete (abandoned)

Medium Priority (review usage):
4-8. [5 more instances]

Total potential savings: $1,840/month

[Stop all] [Select specific] [Dismiss]
```

---

### Q15: Rightsizing Recommendations

**User Query:**
```
"Can I reduce my instance costs?"
```

**MCP Tool Call:**
```python
get_recommendations(
    recommendation_type="rightsizing"
)
```

**Expected Response:**
```
💡 Rightsizing Recommendations:

Found 8 over-provisioned instances:

1. api-server-prod-1 (n1-standard-16 → n1-standard-8)
   • Current: $440/month
   • Recommended: $220/month
   • Savings: $220/month (50%)
   • Avg CPU: 18%
   • Avg Memory: 35%

2. database-replica-2 (n1-highmem-8 → n1-highmem-4)
   • Savings: $180/month (46%)
   • Avg CPU: 12%
   • Avg Memory: 41%

3. batch-processor-1 (n1-standard-32 → n1-standard-16)
   • Savings: $380/month (50%)
   • Avg CPU: 22%
   • Avg Memory: 28%

Total potential savings: $1,240/month

⚠️ Rightsizing requires brief downtime. Schedule during maintenance window?

[Apply all] [Select specific] [Schedule for later]
```

---

### Q16: Commitment Recommendations

**User Query:**
```
"Should I buy committed use discounts?"
```

**MCP Tool Call:**
```python
get_recommendations(
    recommendation_type="commitment"
)
```

**Expected Response:**
```
💡 Committed Use Discount (CUD) Analysis:

Your stable workload qualifies for CUDs!

1-Year Commitment Recommendation:
• Commit to: 32 vCPUs in us-central1
• Current on-demand cost: $680/month
• With CUD (37% discount): $428/month
• Annual savings: $3,024
• Upfront cost: $0 (monthly billing available)

3-Year Commitment Recommendation:
• Commit to: 32 vCPUs in us-central1
• Current on-demand cost: $680/month
• With CUD (55% discount): $306/month
• Annual savings: $4,488
• Total 3-year savings: $13,464

Based on 6-month usage analysis, these workloads are stable:
• api-server-prod (4 vCPUs)
• database-main (16 vCPUs)
• cache-cluster (8 vCPUs)
• web-frontend (4 vCPUs)

⚠️ Commitment is binding. Review your growth plans before purchasing.

[Purchase 1-year CUD] [Purchase 3-year CUD] [Learn more]
```

---

### Q17: All Recommendations

**User Query:**
```
"What are all the ways I can save money?"
```

**MCP Tool Call:**
```python
get_recommendations()  # all types
```

**Expected Response:**
```
💰 Cost Optimization Opportunities:

Total potential savings: $4,280/month ($51,360/year)

Quick Wins (High confidence, low effort):
1. Stop 12 idle VMs → $1,840/month ⭐
2. Delete 8 unattached disks → $120/month
3. Release 3 unused static IPs → $22/month

Medium Effort:
4. Rightsize 8 over-provisioned instances → $1,240/month
5. Move infrequent data to Coldline storage → $340/month

Long-term Commitments:
6. Purchase 1-year CUDs → $252/month savings
7. Reserve Cloud SQL instances → $180/month savings

Optimization by category:
• Compute: $3,200/month (75%)
• Storage: $460/month (11%)
• Networking: $140/month (3%)
• Other: $480/month (11%)

[Apply quick wins] [See detailed plan] [Schedule review]
```

---

### Q18: Project-Specific Recommendations

**User Query:**
```
"Find savings opportunities in the ml-training project"
```

**MCP Tool Call:**
```python
get_recommendations(
    project_id="ml-training-prod"
)
```

**Expected Response:**
```
💡 Optimization for ml-training-prod:

Potential savings: $2,680/month ($32,160/year)

Recommendations:
1. Use Preemptible VMs for training jobs
   • Current: 8× n1-highmem-8 on-demand
   • Recommended: 8× n1-highmem-8 preemptible
   • Savings: $1,920/month (80% discount)
   • Risk: Jobs may be preempted (implement checkpointing)

2. Stop dev GPUs after hours
   • 4× instances with NVIDIA T4 run 24/7
   • Estimated idle time: 65% (nights + weekends)
   • Savings: $660/month
   • Action: Schedule stop at 6 PM, start at 8 AM

3. Delete old model artifacts
   • 4.2 TB in Cloud Storage (Standard class)
   • Last accessed: >90 days ago
   • Move to Nearline: Save $84/month
   • Delete unused: Save $16/month

[Apply recommendations] [Schedule GPU shutdown]
```

---

### Q19: Savings Validation

**User Query:**
```
"Did my optimizations from last month actually save money?"
```

**MCP Tool Call:**
```python
# Query remediation_actions history
# Compare cost before/after
get_cost_summary(days=60, group_by="month")
```

**Expected Response:**
```
📊 Optimization Impact Report:

Changes made in January:
• Stopped 8 idle VMs (Jan 10)
• Rightsized 4 instances (Jan 15)
• Purchased 1-year CUD (Jan 20)

Results:
Before optimizations (Dec 2025): $10,800/month
After optimizations (Jan 2026): $9,200/month
Actual savings: $1,600/month (14.8% reduction)

Projected savings: $1,840/month
Achieved: 87% of projected savings

Why slightly lower than projected:
• New ML workload added (+$400/month)
• Increased BigQuery usage (+$200/month)
• Partial month effect for CUD

✅ Optimizations are working! You're on track to save $19,200 this year.

[View next recommendations] [Monthly report]
```

---

## Anomaly Detection

### Q20: Spike Investigation

**User Query:**
```
"Why did my bill spike on January 15th?"
```

**MCP Tool Call:**
```python
detect_anomalies(
    date="2026-01-15"
)
get_cost_summary(
    start_date="2026-01-15",
    end_date="2026-01-15",
    group_by="service"
)
```

**Expected Response:**
```
🔍 Cost Spike Analysis for January 15, 2026:

Spending: $825 (165% of daily average)
Expected: $312
Deviation: +$513 (+164%)
Severity: CRITICAL

Root Cause:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. BigQuery - Unexpected large query 🔴
   • Cost: $480 (vs. $45 typical)
   • User: data-pipeline@company.iam
   • Query: Full table scan on 5TB dataset
   • Time: 2:34 AM - 4:12 AM
   • Action: Query ran without LIMIT clause

2. Compute Engine - New GPU instances
   • Cost: $218
   • 4× n1-standard-8 with NVIDIA V100
   • Created: Jan 15 at 8:00 AM
   • Project: ml-experiments-dev
   • Still running: YES ⚠️

Timeline:
• 2:34 AM: BigQuery query starts
• 4:12 AM: Query completes ($480 charged)
• 8:00 AM: 4 GPU instances created
• 9:00 AM: Budget alert triggered (80%)

Recommendations:
1. Add query cost limits to BigQuery
2. Stop GPU instances in ml-experiments-dev
3. Review data pipeline for optimization

[Stop GPU instances] [Contact data team] [Set query limits]
```

---

### Q21: Unusual Spending Pattern

**User Query:**
```
"Is my spending normal this week?"
```

**MCP Tool Call:**
```python
detect_anomalies(
    sensitivity="medium"
)
```

**Expected Response:**
```
🔍 Anomaly Detection (Last 7 days):

Overall: ⚠️ ELEVATED spending detected

Anomalies found:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. SUSTAINED INCREASE - Compute Engine
   • Average daily cost: $428 (was $280)
   • Increase: +53% sustained
   • Duration: 7 days
   • Likely cause: New production deployment
   • Severity: MEDIUM

2. NEW SERVICE - Cloud Dataflow
   • First appearance: Jan 28
   • Daily cost: $185
   • Project: data-pipeline-prod
   • Severity: INFO
   • Note: Verify this is intentional

3. SPIKE - Cloud Storage egress
   • Jan 30: $95 (vs. $8 typical)
   • Deviation: +1,087%
   • Likely cause: Large data export
   • Severity: HIGH (one-time spike)

Current week: $3,240
Expected range: $2,100 - $2,400
Status: 35% above normal

[Investigate Compute increase] [Review Dataflow job] [Dismiss]
```

---

### Q22: Service-Specific Anomaly

**User Query:**
```
"Has my BigQuery spending been unusual lately?"
```

**MCP Tool Call:**
```python
detect_anomalies(
    service="bigquery.googleapis.com"
)
```

**Expected Response:**
```
🔍 BigQuery Anomaly Analysis:

Baseline (30-day average): $95/day
Recent 7-day average: $220/day
Change: +$125/day (+132%) ⚠️

Detected issues:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Query Volume Increase
   • Queries/day: 1,240 (was 580)
   • Average query cost: $0.18
   • Top user: analytics-service@company.iam
   • Pattern: Hourly job running since Jan 25

2. Large Table Scan
   • Job ID: bquxjob_5d8f3a1...
   • Date: Jan 28
   • Cost: $480 (single query)
   • Data processed: 4.8 TB
   • Issue: Missing WHERE clause → full table scan

3. Storage Growth
   • Current: 12.4 TB
   • Growth: +2.1 TB this week
   • Cost increase: +$42/month
   • Largest tables: analytics_events_*, logs_*

Recommendations:
1. Partition analytics_events table by date
2. Add query cost alerts (threshold: $50/query)
3. Enable automated table expiration for logs
4. Review analytics-service query optimization

Projected impact: Save $180/day

[Apply partitioning] [Set query limits] [Analyze queries]
```

---

### Q23: Check for Waste

**User Query:**
```
"Am I wasting money on anything?"
```

**MCP Tool Call:**
```python
detect_anomalies(
    anomaly_type="waste"
)
get_recommendations()
```

**Expected Response:**
```
🔍 Waste Detection Report:

Found $2,485/month in wasteful spending:

High-Impact Waste:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Idle Resources - $1,840/month 🔴
   • 12 VMs with <1% CPU utilization
   • Average idle time: 18 days
   • Action: Stop or delete

2. Over-Provisioned Instances - $420/month
   • 6 instances using <25% of capacity
   • Action: Downsize

3. Unattached Storage - $120/month
   • 18 persistent disks not attached to any VM
   • Total: 4.2 TB
   • Likely orphaned after VM deletion

Low-Impact Waste:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
4. Unused Static IPs - $22/month
   • 3 IP addresses reserved but not assigned

5. Duplicate Data - $65/month
   • Same backups in multiple regions
   • Identified: database snapshots

6. Inefficient Storage Class - $18/month
   • Cold data in Standard storage
   • Should be in Coldline/Archive

Total waste: 20% of your GCP bill

Quick action: Stop idle VMs now → Save $1,840/month instantly

[Fix all waste] [Review each item] [Schedule cleanup]
```

---

## Resource Management

### Q24: Stop Idle Resources

**User Query:**
```
"Stop all idle development VMs"
```

**MCP Tool Call:**
```python
scan_organization(include_services=True)
get_recommendations(type="idle_vm")
# Filter by label: environment=dev
stop_resource(resource_type="vm", filter={"idle": true, "env": "dev"})
```

**Expected Response:**
```
🔧 Stopping Idle Development VMs...

Found 6 idle VMs with label environment=dev:

Preparing to stop:
1. dev-test-1 (n1-standard-4, us-central1-a)
2. dev-web-server (n1-standard-2, us-east1-b)
3. dev-api-instance (n1-standard-8, europe-west1-c)
4. dev-ml-training (n1-highmem-16, us-central1-b)
5. dev-database-clone (n1-standard-4, us-west1-a)
6. dev-experiment-vm (n1-standard-2, asia-southeast1-a)

Estimated monthly savings: $1,140

⚠️ WARNING: This will stop all 6 VMs immediately.
• Running processes will be terminated
• SSH sessions will be disconnected
• You can restart them anytime

Do you want to proceed?

[Yes, stop all] [Select specific VMs] [Cancel]

--- After approval ---

✅ Stopped 6 VMs successfully!

Results:
• dev-test-1: STOPPED ✅
• dev-web-server: STOPPED ✅
• dev-api-instance: STOPPED ✅
• dev-ml-training: STOPPED ✅
• dev-database-clone: STOPPED ✅
• dev-experiment-vm: STOPPED ✅

Monthly savings: $1,140
Action logged in audit trail.

[View stopped VMs] [Schedule auto-start]
```

---

### Q25: Schedule Resource Operations

**User Query:**
```
"Stop all dev VMs every day at 6 PM and start them at 8 AM"
```

**MCP Tool Call:**
```python
# This would require integration with Cloud Scheduler
# MCP tool would create the schedule
configure_resource_schedule(
    resource_filter={"label:environment": "dev"},
    stop_time="18:00",
    start_time="08:00",
    timezone="America/New_York"
)
```

**Expected Response:**
```
✅ Resource Schedule Created!

Schedule: Dev VMs Auto-Shutdown
Resources: All VMs with label environment=dev (6 VMs)
Timezone: America/New_York (EST)

Actions:
• Stop: 6:00 PM daily
• Start: 8:00 AM daily (Mon-Fri only)
• Weekends: VMs remain stopped

Affected instances:
1. dev-test-1
2. dev-web-server
3. dev-api-instance
4. dev-ml-training
5. dev-database-clone
6. dev-experiment-vm

Expected savings:
• Per day: $63 saved (14 hours stopped)
• Per month: ~$1,380 (weekdays) + full weekends

Next scheduled actions:
• Stop: Today at 6:00 PM
• Start: Tomorrow at 8:00 AM

[Modify schedule] [Pause schedule] [View logs]
```

---

### Q26: Resource Inventory

**User Query:**
```
"What Compute Engine instances do I have running?"
```

**MCP Tool Call:**
```python
scan_organization(
    include_services=True,
    filter_service="compute.googleapis.com"
)
```

**Expected Response:**
```
🖥️ Compute Engine Inventory:

Total instances: 28
Running: 24 | Stopped: 4

By Project:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
prod-api (8 instances)
├─ api-server-prod-1 (n1-standard-16) Running
├─ api-server-prod-2 (n1-standard-16) Running
├─ cache-redis-1 (n1-highmem-4) Running
└─ [...5 more]

ml-training-prod (12 instances)
├─ gpu-training-1 (n1-standard-8 + V100) Running
├─ gpu-training-2 (n1-standard-8 + V100) Running
└─ [...10 more]

dev-environment (4 instances)
├─ dev-test-1 (n1-standard-4) Stopped
└─ [...3 more]

web-frontend (4 instances)
├─ web-server-1 (n1-standard-4) Running
└─ [...3 more]

By Region:
• us-central1: 16 instances
• europe-west1: 8 instances
• asia-southeast1: 4 instances

Monthly cost: $6,200

[View idle instances] [Filter by label] [Export list]
```

---

### Q27: Delete Resources

**User Query:**
```
"Delete all unattached disks older than 30 days"
```

**MCP Tool Call:**
```python
scan_organization()
# Find unattached disks
delete_resource(
    resource_type="disk",
    filter={"attached": false, "age_days": ">30"}
)
```

**Expected Response:**
```
🗑️ Delete Unattached Disks

Found 18 unattached persistent disks (>30 days old):

Total size: 4.2 TB
Monthly cost: $120

Disks to delete:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. backup-disk-old (500 GB, 45 days old) - $15/month
2. temp-snapshot-disk (200 GB, 38 days old) - $6/month
3. abandoned-data-1 (1 TB, 120 days old) - $30/month
4. old-ml-dataset (800 GB, 65 days old) - $24/month
[...14 more]

⚠️ DANGER: Deletion is permanent and cannot be undone!

Snapshots:
• 8 disks have snapshots (safe to delete)
• 10 disks have NO snapshots ⚠️

Do you want to:
1. Delete all 18 disks
2. Create snapshots first, then delete
3. Delete only disks with existing snapshots
4. Cancel

Recommended: Option 2 (snapshots first)

[Create snapshots + delete] [Delete only] [Cancel]

--- After approval ---

✅ Operation complete!

Created snapshots: 10 disks
Deleted disks: 18 disks
Freed space: 4.2 TB
Monthly savings: $120

Snapshots will be retained for 30 days (auto-expire).
```

---

### Q28: Circuit Breaker Status

**User Query:**
```
"What's the status of my cost protection?"
```

**MCP Tool Call:**
```python
get_circuit_breaker_status()
```

**Expected Response:**
```
🛡️ Circuit Breaker Status:

Enabled: YES ✅
Mode: ACTIVE (not dry-run)
Last updated: Jan 20, 2026

Thresholds:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Level 1: WARNING ($1,000/day)
├─ Status: CLOSED (normal)
├─ Current: $420/day (42%)
└─ Action: Alert only

Level 2: ELEVATED ($2,500/day)
├─ Status: CLOSED (normal)
└─ Action: Alert + escalation

Level 3: CRITICAL ($5,000/day)
├─ Status: CLOSED (normal)
└─ Action: Stop high-cost resources

Level 4: EMERGENCY ($10,000/day)
├─ Status: CLOSED (normal)
└─ Action: Disable billing ⚠️

Recent Events:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Jan 15: WARNING threshold triggered (spike day)
• Jan 15: Automatic reset after 4 hours
• No CRITICAL events in last 30 days

Protected Resources:
• 28 Compute instances monitored
• 4 Vertex AI endpoints monitored
• 12 Cloud SQL instances monitored

[Configure thresholds] [Test circuit breaker] [View logs]
```

---

## Multi-Step Workflows

### Q29: Complete Cost Investigation

**User Query:**
```
"Our bill doubled last month. Help me understand why and fix it."
```

**MCP Tool Sequence:**
```python
# Step 1: Compare months
get_cost_summary(days=60, group_by="month")

# Step 2: Detect anomalies
detect_anomalies(sensitivity="high")

# Step 3: Find top changes
get_cost_summary(days=30, group_by="service")
get_cost_summary(days=60, days_offset=30, group_by="service")

# Step 4: Get recommendations
get_recommendations()
```

**Expected Response:**
```
🔍 Complete Cost Investigation

Problem: Bill doubled from $10,800 → $21,600 (+100%)

Root Cause Analysis:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. New ML Training Workload (+$8,200)
   • 12 GPU instances (8× V100) added mid-month
   • Project: ml-training-prod
   • Started: Jan 10
   • Running 24/7: YES
   • This accounts for 76% of increase

2. BigQuery Increase (+$1,800)
   • New analytics pipeline
   • 10x query volume
   • Large table scans without partitioning

3. Cloud Storage Egress (+$600)
   • Data export to external analytics tool
   • 12 TB transferred

Solutions:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Quick Wins ($3,200/month):
✅ Use Preemptible VMs for ML training → Save $6,560/month (80% discount)
✅ Stop GPUs nights & weekends → Save $2,680/month (65% idle time)
✅ Partition BigQuery tables → Save $900/month

Medium-term ($1,800/month):
• Purchase 1-year GPU CUD → Save $1,200/month
• Optimize data export schedule → Save $400/month
• Implement ML job auto-shutdown → Save $200/month

Action Plan:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. TODAY: Stop idle GPU instances
2. THIS WEEK: Switch to preemptible VMs
3. THIS WEEK: Partition BigQuery tables
4. NEXT MONTH: Purchase CUD commitments

Expected result: Reduce bill from $21,600 → $16,400 (24% reduction)

[Apply quick wins] [Schedule implementations] [Detailed report]
```

---

### Q30: Optimization Sprint

**User Query:**
```
"I need to reduce my GCP bill by 30% this month. What should I do?"
```

**MCP Tool Sequence:**
```python
get_cost_summary(days=30)
get_recommendations()
detect_anomalies()
# Calculate savings scenarios
```

**Expected Response:**
```
💰 30% Cost Reduction Plan

Current spend: $12,450/month
Target reduction: 30% = $3,735/month
Target spend: $8,715/month

Savings Plan (Ranked by ROI):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PHASE 1: Immediate (0-2 days) - $2,240/month
✅ Stop 12 idle VMs → $1,840
   Risk: NONE | Effort: 5 min | Approval: Not needed
  
✅ Delete unattached disks → $120
   Risk: LOW | Effort: 10 min | Approval: Not needed

✅ Release unused IPs → $22
   Risk: NONE | Effort: 5 min | Approval: Not needed

✅ Stop oversized dev instances → $258
   Risk: LOW (dev only) | Effort: 10 min | Approval: Needed

PHASE 2: This Week (3-7 days) - $1,240/month
✅ Rightsize 8 production instances → $1,240
   Risk: MEDIUM (brief downtime) | Effort: 2 hours
   Approval: Production change request

PHASE 3: End of Month (8-30 days) - $252/month
✅ Purchase CUD commitments → $252
   Risk: LOW (binding commitment) | Effort: 1 hour
   Approval: Finance team

Total Savings: $3,732/month ✅ MEETS 30% GOAL!

Implementation Timeline:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Week 1:
• Day 1: Phase 1 (immediate wins)
• Day 3: Submit production change request
• Day 5: Execute Phase 2 (rightsizing)

Week 2-4:
• Review CUD analysis with finance
• Purchase commitments by month-end

Expected Results:
• Feb 1: -18% (Phase 1 complete)
• Feb 7: -28% (Phase 2 complete)
• Mar 1: -30% (Phase 3 complete)

Risk Level: LOW
• 60% of savings are zero-risk (idle resources)
• 33% require minor changes (rightsizing)
• 7% require commitment (reversible)

[Execute Phase 1] [Review detailed plan] [Schedule approvals]
```

---

### Q31: New Project Setup

**User Query:**
```
"I'm starting a new project. Help me set up cost monitoring."
```

**MCP Tool Sequence:**
```python
scan_organization()  # Find new project
create_budget()
configure_circuit_breaker()
# Set up alerts
```

**Expected Response:**
```
🚀 New Project Cost Monitoring Setup

Detected new project: mobile-app-backend

Step 1: Budget Configuration
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Recommended monthly budget: $2,000
(Based on similar project: web-api-prod)

Alert thresholds:
• 50% ($1,000) → Email
• 80% ($1,600) → Email + Slack
• 100% ($2,000) → Circuit breaker

Step 2: Circuit Breaker
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Recommended thresholds:
• WARNING: $100/day → Alert only
• CRITICAL: $500/day → Stop dev resources
• EMERGENCY: $1,000/day → Block new resources

Step 3: Resource Tagging Policy
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Enforce tags:
• environment (required): prod/dev/staging
• team (required): mobile, backend, etc.
• cost-center (optional)

Step 4: Optimization Schedule
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Auto-stop dev resources:
• Weeknights: 6 PM - 8 AM (save 58%)
• Weekends: Full stop (save 100%)

Estimated monthly savings: $680

Do you want to apply this configuration?

[Apply recommended setup] [Customize settings] [Skip]

--- After approval ---

✅ Project monitoring configured!

Created:
• Budget: $2,000/month with 3 alert thresholds
• Circuit breaker: 3-level protection
• Tagging policy: Enforced on new resources
• Auto-stop schedule: Dev resources only

Next steps:
1. Share this config with your team
2. Monitor actual spend for 2 weeks
3. Adjust budget based on real usage

[View dashboard] [Invite team] [Documentation]
```

---

### Q32: Monthly Cost Review

**User Query:**
```
"Generate a monthly cost review for the executive team"
```

**MCP Tool Sequence:**
```python
get_cost_summary(days=30, group_by="month")
get_cost_summary(days=60, group_by="month")  # comparison
detect_anomalies()
get_recommendations()
# Generate executive summary
```

**Expected Response:**
```
📊 Executive Cost Review - January 2026

SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total Spend: $12,450
Previous Month: $10,800
Change: +$1,650 (+15.3%)

Annual Run Rate: $149,400
vs. Budget: 7.2% over target

TOP INSIGHTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ GOOD: Rightsize optimizations saving $1,240/month
⚠️ CONCERN: ML training costs up 280%
🔴 ISSUE: 12 idle VMs wasting $1,840/month (15% of bill)

SPENDING BREAKDOWN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Compute Engine ···· $6,200 (50%)
2. BigQuery ·········· $3,100 (25%)
3. Cloud Storage ····· $1,500 (12%)
4. Cloud SQL ········· $980 (8%)
5. Other ············· $670 (5%)

TOP COST DRIVERS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. ML Training GPUs: $3,200/month
   • 12 instances (8× V100 GPUs)
   • Utilization: 35% (high waste)
   • Recommendation: Use preemptible → Save $2,560/month

2. BigQuery Analytics: $3,100/month
   • Query costs increased 40% this month
   • Cause: New analytics pipeline without optimization
   • Recommendation: Partition tables → Save $900/month

3. Production API: $2,100/month
   • Stable workload (good CUD candidate)
   • Recommendation: 1-year commitment → Save $252/month

OPTIMIZATION OPPORTUNITIES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Immediate (this week):
• Stop idle resources → Save $1,840/month ⭐
• Rightsize instances → Save $1,240/month

Short-term (this month):
• Switch ML to preemptible → Save $2,560/month
• Optimize BigQuery → Save $900/month

Long-term (next quarter):
• Purchase CUDs → Save $252/month

Total Opportunity: $6,792/month ($81,504/year)
Reduction potential: 55% of current spend

FORECAST
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
February projection: $13,200 (+6% vs. Jan)
Without optimization: Will exceed annual budget by $28,000

With recommended optimizations: $6,408/month
Savings vs. current: 49%

RECOMMENDATIONS FOR EXECUTIVES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. APPROVE: Immediate idle resource cleanup
   Impact: $1,840/month savings, zero risk

2. REVIEW: ML training GPU usage
   Question: Is 35% utilization acceptable?
   Impact: Potential $2,560/month savings

3. INVEST: 1-year GPU commitments
   Trade-off: Lock-in vs. 37% discount
   Impact: $252/month savings

[Download PDF report] [Schedule review meeting] [Apply optimizations]
```

---

## Summary

This document provides 32 sample queries across 6 categories. Use them to:

1. **Validate your MCP tool design** - Ensure all tools support these scenarios
2. **Write integration tests** - Each query maps to specific tool calls
3. **Train your conversational agent** - Use as intent classification examples
4. **Demo the product** - Show realistic user interactions
5. **Document capabilities** - Share with potential users

**Next Steps:**
- Implement MCP tools to handle these queries
- Build intent classifier trained on these examples
- Create automated tests for each scenario
- Add more queries based on real user feedback
