# Scenario: Vertex AI (LLM) Cost Threshold Breach

## Overview

This document walks through a real-world scenario where Vertex AI costs spike unexpectedly, triggering the circuit breaker system at multiple threshold levels.

---

## ⚠️ Critical Understanding: Who Does What?

**Google will NOT automatically stop your services!**

| Actor | Responsibility |
|-------|----------------|
| **Google** | Sends Pub/Sub alerts when budget thresholds are exceeded |
| **YOUR Agent** | Receives alerts and executes stop commands |

```
Google Budget API          YOUR Cloud Function         YOUR Circuit Breaker
      │                           │                           │
      │  "Threshold exceeded"     │                           │
      ├──────────────────────────►│                           │
      │   (Pub/Sub message)       │   "What level?"           │
      │                           ├──────────────────────────►│
      │                           │                           │
      │                           │   "CRITICAL - stop!"      │
      │                           │◄────────────────────────── │
      │                           │                           │
      │                           │  endpoint.undeploy_all()  │
      │                           ├──────────────────────────►│ GCP API
      │                           │                           │
      │                           │  YOUR CODE executes this  │
      │                           │  NOT Google automatically │
```

---

## Scenario Setup

**Company Profile:**
- Mid-size fintech company
- Monthly GCP budget: $50,000
- Normal Vertex AI daily spend: ~$200-300/day
- Uses Gemini Pro for customer support chatbot and document processing

**Current Configuration:**

| Threshold Type | Level | Threshold | Action |
|----------------|-------|-----------|--------|
| **Per-Service (Vertex AI)** | WARNING | $500/day | Alert only |
| | ELEVATED | $1,000/day | Alert + escalation |
| | CRITICAL | $2,500/day | Stop non-production endpoints |
| | EMERGENCY | $5,000/day | Stop all endpoints |
| **Overall** | WARNING | $1,000/day | Alert only |
| | ELEVATED | $2,500/day | Alert + escalation |
| | CRITICAL | $5,000/day | Stop high-cost resources |
| | EMERGENCY | $10,000/day | Disable billing |

---

## Timeline of Events

### Day 1: 9:00 AM — The Incident Begins

A developer deploys a new feature that accidentally creates an infinite loop calling the Gemini Pro API for each customer interaction. Instead of 1 API call per interaction, it makes 50 calls.

**Normal behavior:** 1,000 interactions/day × 1 call × $0.0025 = $2.50/day
**Bug behavior:** 1,000 interactions/day × 50 calls × $0.0025 = $125/day (still under threshold)

But it's a Monday morning, and traffic ramps up...

---

### Day 1: 11:30 AM — WARNING Threshold Breached ($500/day)

**Trigger:** Vertex AI daily spend reaches $500

**What happens:**

```
┌─────────────────────────────────────────────────────────────────┐
│  CIRCUIT BREAKER STATE: CLOSED → CLOSED (monitoring)           │
│  ACTION: ALERT_ONLY                                             │
└─────────────────────────────────────────────────────────────────┘

1. Budget API detects threshold breach
2. Pub/Sub message sent to budget-alerts topic
3. Cloud Function receives event
4. Circuit Breaker evaluates: Per-Service Vertex AI WARNING
5. Actions executed:
   ├── Slack notification to #cloud-costs channel
   ├── Email to cost-alerts@company.com
   └── Log entry in audit trail
```

**Slack Message:**
```
⚠️ COST ALERT: Vertex AI WARNING Threshold Breached

Current Vertex AI spend: $512.34 (today)
Threshold: $500/day
Trend: +156% vs 7-day average

Top consumers:
• gemini-pro-endpoint-prod: $380.21
• gemini-pro-endpoint-staging: $132.13

Action: Alert only (monitoring)
Dashboard: https://console.cloud.google.com/billing/...
```

**Team Response:** DevOps sees the alert but assumes it's a temporary spike. No immediate action taken.

---

### Day 1: 2:15 PM — ELEVATED Threshold Breached ($1,000/day)

**Trigger:** Vertex AI daily spend reaches $1,000

Traffic continues to increase. The bug is now costing serious money.

```
┌─────────────────────────────────────────────────────────────────┐
│  CIRCUIT BREAKER STATE: CLOSED → CLOSED (elevated monitoring)  │
│  ACTION: ALERT_ONLY + ESCALATION                                │
└─────────────────────────────────────────────────────────────────┘

1. Budget API detects threshold breach
2. Circuit Breaker evaluates: Per-Service Vertex AI ELEVATED
3. Actions executed:
   ├── Slack notification to #cloud-costs AND #engineering-leads
   ├── Email to cost-alerts@company.com AND cto@company.com
   ├── PagerDuty alert created (P2 severity)
   └── Audit log entry
```

**PagerDuty Alert:**
```
🔶 P2 INCIDENT: Elevated Cloud Costs - Vertex AI

Vertex AI spend: $1,023.45 (today)
Projected end-of-day: $2,800+
Normal daily spend: $250

This requires investigation within 2 hours.

Acknowledge | Resolve | Escalate
```

**Team Response:** CTO sees the PagerDuty alert, asks DevOps to investigate.

---

### Day 1: 4:45 PM — CRITICAL Threshold Breached ($2,500/day)

**Trigger:** Vertex AI daily spend reaches $2,500

The bug hasn't been found yet. Costs are now 10x normal.

```
┌─────────────────────────────────────────────────────────────────┐
│  CIRCUIT BREAKER STATE: CLOSED → OPEN (tripped)                │
│  ACTION: STOP_RESOURCES (non-production)                        │
└─────────────────────────────────────────────────────────────────┘

WHAT HAPPENS (Step by Step):

1. Google Budget API detects $2,500 threshold breach
2. Google sends Pub/Sub message to budget-alerts topic
   └── ⚠️ This is ALL Google does. Google does NOT stop anything.

3. YOUR Cloud Function receives the Pub/Sub message
4. YOUR Circuit Breaker logic evaluates: "CRITICAL level reached"
5. YOUR CODE decides: "Stop non-production endpoints"
6. YOUR AGENT executes the commands:
   ├── endpoint.undeploy_all()  ← YOUR code calls this API
   ├── send_slack_notification() ← YOUR code sends this
   ├── create_pagerduty_incident() ← YOUR code creates this
   └── log_to_audit_trail() ← YOUR code logs this
```

**Your Cloud Function Code (what YOUR agent runs):**

```python
def circuit_breaker_handler(event, context):
    """YOUR code - triggered by Google's Pub/Sub alert"""
    alert = parse_budget_alert(event)
    
    if alert.amount >= 2500:  # CRITICAL threshold
        # YOUR AGENT executes these - NOT Google!
        stop_staging_endpoints(alert.project_id)
        send_slack_alert(level="CRITICAL", amount=alert.amount)
        create_pagerduty_incident(severity="P1")
        
def stop_staging_endpoints(project_id):
    """YOUR code calls Google's API to undeploy"""
    for endpoint in list_staging_endpoints(project_id):
        endpoint.undeploy_all()  # YOUR AGENT tells Google to stop
```

**Actions Executed (by YOUR agent):**

```yaml
Actions Executed:
  - type: UNDEPLOY_ENDPOINT
    resource: projects/company-prod/locations/us-central1/endpoints/gemini-pro-endpoint-staging
    status: SUCCESS
    previous_state: DEPLOYED
    new_state: UNDEPLOYED
    estimated_savings: $132/day
    
  - type: NOTIFICATION
    channels: [slack, email, pagerduty]
    severity: CRITICAL
    
Circuit Breaker State:
  previous: CLOSED
  current: OPEN
  tripped_at: 2026-02-04T16:45:23Z
  tripped_by: vertex_ai_critical_threshold
  cooldown_expires: 2026-02-04T22:45:23Z (6 hours)
```

**Slack Message:**
```
🚨 CRITICAL COST ALERT: Vertex AI CRITICAL Threshold Breached

AUTOMATIC ACTION TAKEN:
✅ Stopped: gemini-pro-endpoint-staging
⚠️ Production endpoint still running (protected)

Current Vertex AI spend: $2,534.89 (today)
Threshold: $2,500/day
Projected end-of-day: $4,200

Circuit Breaker Status: OPEN (tripped)
Cooldown: Resets in 6 hours or manual reset required

REQUIRED: Investigate immediately!
Runbook: https://wiki.company.com/runbooks/cost-spike
```

**Team Response:** 
- Engineering team scrambles to find the issue
- They identify the infinite loop bug at 5:30 PM
- Hotfix deployed at 6:00 PM

---

### Day 1: 6:30 PM — Production Endpoint Still Running

Even with staging stopped, production is still burning money. After the hotfix, new requests are fixed, but there's a backlog of queued requests still being processed.

**Current State:**
- Vertex AI spend: $3,200 (still climbing from backlog)
- Circuit breaker: OPEN
- Staging: Stopped
- Production: Running (protected)

**Manual Intervention Options:**

```
User: "Show me the circuit breaker status"

Claude Response:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CIRCUIT BREAKER STATUS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

State: OPEN (tripped)
Tripped at: 4:45 PM today
Reason: Vertex AI CRITICAL threshold ($2,500/day)

Current Vertex AI Spend: $3,245.67
Projected EOD: $3,800

Actions Taken:
✅ gemini-pro-endpoint-staging - STOPPED at 4:45 PM

Protected Resources (not stopped):
🛡️ gemini-pro-endpoint-prod - RUNNING (production-protected label)

Options:
1. Wait for cooldown (resets at 10:45 PM)
2. Manual reset (requires approval)
3. Stop production endpoint (requires explicit confirmation)

Would you like to take any action?
```

**User Decision:** Since the bug is fixed, they choose to let the backlog drain rather than stop production.

---

### Day 1: 10:45 PM — Cooldown Expires

```
┌─────────────────────────────────────────────────────────────────┐
│  CIRCUIT BREAKER STATE: OPEN → CLOSED (auto-reset)             │
│  Cooldown period expired, no new threshold breaches            │
└─────────────────────────────────────────────────────────────────┘

Final Day 1 Vertex AI Spend: $3,456.78
Normal Day Spend: ~$250
Excess Cost: ~$3,200
```

**Slack Notification:**
```
✅ Circuit Breaker Reset: Vertex AI

State: OPEN → CLOSED
Reset type: Automatic (cooldown expired)

Daily Summary:
• Total Vertex AI spend: $3,456.78
• Normal expected: ~$250
• Excess cost: $3,206.78
• Root cause: Infinite loop bug (FIXED)

Staging endpoint remains stopped. 
To redeploy, use: gcloud ai endpoints deploy-model ...
```

---

## What-If: Emergency Threshold ($5,000/day)

If the bug hadn't been found and costs continued to climb:

### Hypothetical: 8:00 PM — EMERGENCY Threshold Breached ($5,000/day)

```
┌─────────────────────────────────────────────────────────────────┐
│  CIRCUIT BREAKER STATE: OPEN → OPEN (escalated)                │
│  ACTION: STOP_ALL_ENDPOINTS                                     │
└─────────────────────────────────────────────────────────────────┘

AUTOMATIC ACTIONS (No approval required at EMERGENCY level):

1. STOP all Vertex AI endpoints:
   ├── gemini-pro-endpoint-prod: STOPPED ⚠️
   └── gemini-pro-endpoint-staging: Already STOPPED

2. DISABLE Vertex AI API (optional, configurable):
   └── aiplatform.googleapis.com: DISABLED

3. All-hands notification:
   ├── CEO, CTO, CFO notified
   ├── PagerDuty: P0 incident
   └── Automatic incident created in ServiceNow
```

**Impact:**
- Customer-facing chatbot goes offline
- Document processing halts
- Company loses some customer interactions

**Recovery:**
- Requires manual reset by authorized personnel
- API must be re-enabled
- Endpoints must be redeployed
- Post-incident review mandatory

---

## Summary: Circuit Breaker Response Flow

```
                    Normal Operations
                          │
                          ▼
              ┌───────────────────────┐
              │    $500/day WARNING   │
              │    Alert only         │
              └───────────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │   $1,000/day ELEVATED │
              │   Alert + Escalation  │
              │   PagerDuty P2        │
              └───────────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │  $2,500/day CRITICAL  │
              │  Circuit Breaker OPEN │
              │  Stop non-prod        │
              │  PagerDuty P1         │
              └───────────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │  $5,000/day EMERGENCY │
              │  Stop ALL endpoints   │
              │  Disable API          │
              │  PagerDuty P0         │
              └───────────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │ Overall $10K EMERGENCY│
              │ DISABLE BILLING       │
              │ Nuclear option        │
              └───────────────────────┘
```

---

## Key Takeaways

1. **Gradual Escalation:** The system gives multiple warnings before taking drastic action
2. **Production Protection:** Critical resources can be labeled as protected
3. **Automatic + Manual:** Non-prod stopped automatically; prod requires explicit action
4. **Audit Trail:** Every action is logged for post-incident review
5. **Cooldown Periods:** Prevents rapid state changes and allows investigation time
6. **Multiple Notification Channels:** Slack, email, PagerDuty ensure someone sees the alert

---

## Configuration Used

```yaml
# circuit_breaker_config.yaml
circuit_breaker:
  enabled: true
  dry_run: false
  
  per_service_thresholds:
    - service: aiplatform.googleapis.com
      display_name: "Vertex AI"
      thresholds:
        - level: WARNING
          amount_usd: 500
          action: ALERT_ONLY
          notify: [slack, email]
        - level: ELEVATED
          amount_usd: 1000
          action: ALERT_ONLY
          notify: [slack, email, pagerduty]
          pagerduty_severity: P2
        - level: CRITICAL
          amount_usd: 2500
          action: STOP_RESOURCES
          scope: non_production
          notify: [slack, email, pagerduty]
          pagerduty_severity: P1
        - level: EMERGENCY
          amount_usd: 5000
          action: STOP_ALL
          notify: [slack, email, pagerduty, executive]
          pagerduty_severity: P0
          
  protected_resources:
    - label: "environment=production"
    - label: "critical=true"
    
  cooldown_hours: 6
  require_approval_for_reset: false
  audit_logging: true
```

---

## MCP Conversation Example

```
User: "Why is my GCP bill so high today?"

Claude: I'll check your current costs and any anomalies.

[Calling get_cost_summary()]
[Calling detect_anomalies()]

I found a significant issue:

📊 Today's Spend: $3,456.78
📈 Normal Daily: ~$1,200
🚨 Anomaly Detected: Vertex AI (+1,200% vs average)

The circuit breaker tripped at 4:45 PM due to Vertex AI costs 
exceeding $2,500/day. Here's what happened:

• Staging endpoint was automatically stopped
• Production endpoint is still running (protected)
• Root cause appears to be a spike in Gemini Pro API calls

Current Status:
• Circuit Breaker: OPEN (will auto-reset at 10:45 PM)
• Vertex AI spend: $3,245.67

Would you like me to:
1. Show detailed breakdown by endpoint?
2. Check recent deployments that might have caused this?
3. Show the audit log of circuit breaker actions?
```

---

*Document Version: 1.0 | February 2026*
