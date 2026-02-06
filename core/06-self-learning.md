# AI Cost Monitoring — Self-Learning & Feedback Loop Architecture

## Document Info

| Field | Value |
|-------|-------|
| **Document** | 06 — Self-Learning & Feedback Loop Architecture |
| **Version** | 1.0 |
| **Date** | February 2026 |
| **Status** | Architecture |
| **Audience** | Architects, ML Engineers, Product |

---

## 1. Self-Learning Vision

AI Cost Monitoring should improve with every interaction. Unlike static dashboards, the platform learns from tenant behavior to provide increasingly accurate and relevant insights. This follows the same self-learning pattern proven in Trading Nexus.

### 1.1 What Improves Over Time

| Capability | What Gets Better | Learning Signal |
|------------|-----------------|-----------------|
| Anomaly Detection | Fewer false positives, catches real issues faster | User marks anomalies as false positive or acknowledges them |
| Recommendations | Higher-impact suggestions, better confidence scores | User executes, dismisses, or ignores recommendations |
| Forecasting | More accurate spend predictions | Compare forecasts to actuals monthly |
| Query Routing | Faster, more accurate intent classification | User satisfaction signals, rephrasings, follow-up clarifications |
| Response Quality | Better answers to common questions | Thumbs up/down, query reformulations |
| Alert Thresholds | Smarter notification timing | User response time to alerts, alert dismissal patterns |

### 1.2 Learning Principles

1. **Per-tenant learning** — Each tenant's patterns are unique (different cloud usage, different budgets, different sensitivity). Models adapt to each tenant individually.
2. **No cross-tenant data leakage** — Learning insights from tenant A never influence tenant B.
3. **Human-in-the-loop** — The system learns from human decisions, not from its own outputs.
4. **Transparent** — Users can see why the system made a recommendation and how its accuracy has changed.
5. **Reversible** — Users can reset learned thresholds/preferences to defaults.

---

## 2. Feedback Loop Architecture

### 2.1 Five Feedback Loops

```
┌─────────────────────────────────────────────────────────────┐
│                    SELF-LEARNING LOOPS                        │
│                                                              │
│  Loop 1: Anomaly Accuracy Loop                               │
│    Detect anomaly → User response → Adjust thresholds        │
│                                                              │
│  Loop 2: Recommendation Impact Loop                          │
│    Generate recommendation → User acts → Measure savings     │
│    → Adjust confidence scoring                               │
│                                                              │
│  Loop 3: Forecast Calibration Loop                           │
│    Predict spend → Actual spend arrives → Measure error      │
│    → Retrain model weights                                   │
│                                                              │
│  Loop 4: Query Intelligence Loop                             │
│    User asks question → Agent responds → User feedback       │
│    → Improve routing and response patterns                   │
│                                                              │
│  Loop 5: Alert Optimization Loop                             │
│    Send alert → User response time/action → Adjust           │
│    thresholds and channels                                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Loop Details

### 3.1 Loop 1: Anomaly Accuracy

**Problem:** Default anomaly detection flags too many events (noise) or misses real issues.

**Learning cycle:**

```
Anomaly detected (by Mode 2 or Mode 3)
  → Notification sent to user
    → User response:
       (a) Acknowledges → confirmed real anomaly → signal: threshold is correct
       (b) Marks as false positive → signal: threshold too sensitive
       (c) Ignores for 24+ hours → signal: low priority or false positive
       (d) No anomaly detected but user reports issue → signal: threshold too loose
```

**What adapts:**
- Per-tenant, per-service anomaly sensitivity thresholds
- Baseline calculation window (some tenants are spikier than others)
- Severity classification (what counts as critical vs. low for this tenant)

**Stored data:**

| Field | Description |
|-------|-------------|
| anomaly_id | Reference to the anomaly |
| user_feedback | acknowledged / false_positive / ignored / missed |
| response_time | How quickly user responded |
| threshold_at_detection | What threshold was used |
| actual_impact | Actual cost impact (calculated after the fact) |

**Adaptation schedule:** Weekly recalculation of thresholds based on accumulated feedback. Minimum 10 feedback signals before adjusting (avoid overreacting to small samples).

### 3.2 Loop 2: Recommendation Impact

**Problem:** Not all recommendations are equally valuable. Some are high-confidence but low-impact; others are speculative but could save significantly.

**Learning cycle:**

```
Recommendation generated (by Mode 2)
  → Presented to user
    → User action:
       (a) Executes → measure actual savings after 30 days
       (b) Dismisses with reason → understand why (not applicable, too risky, wrong)
       (c) Ignores → low engagement signal
       (d) Executes but rolls back → recommendation was harmful

  → After 30 days (for executed recommendations):
     → Compare estimated_savings vs. actual_savings
     → Calculate accuracy: actual / estimated
```

**What adapts:**
- Confidence scoring model — which factors predict accurate recommendations
- Priority ranking — recommendations with high execution rates ranked higher
- Recommendation types — stop generating types that are consistently dismissed

**Impact tracking entity:**

| Field | Description |
|-------|-------------|
| recommendation_id | Reference |
| user_action | executed / dismissed / ignored / rolled_back |
| dismiss_reason | not_applicable / too_risky / incorrect / other |
| estimated_savings | What we predicted |
| actual_savings | Measured 30 days later |
| accuracy_ratio | actual / estimated |
| execution_time | How long remediation took |

**Reporting:** Monthly "Savings Report" per tenant showing: total estimated savings, total realized savings, accuracy trend over time.

### 3.3 Loop 3: Forecast Calibration

**Problem:** Spend forecasts drift as cloud usage patterns change.

**Learning cycle:**

```
Forecast generated (Daily at 3 AM by Mode 2)
  → 30 days later: actual cost data available
    → Calculate forecast errors:
       MAPE (Mean Absolute Percentage Error)
       MAE (Mean Absolute Error)
       Bias (consistently over or under predicting?)
    → Feed errors back to Prophet model:
       → Adjust seasonality weights
       → Update trend components
       → Recalibrate changepoint sensitivity
```

**What adapts:**
- Prophet model hyperparameters (per tenant, per service)
- Seasonality detection (weekly, monthly, quarterly patterns)
- Changepoint sensitivity (how quickly the model reacts to trend shifts)
- Confidence interval width (wider if recent predictions were inaccurate)

**Accuracy tracking:**

| Field | Description |
|-------|-------------|
| forecast_date | When forecast was made |
| target_date | What date was being predicted |
| scope | account / service / total |
| predicted_value | Forecasted amount |
| actual_value | Real amount |
| error_pct | Percentage error |
| model_version | Which model version generated this |

**Target:** MAPE < 15% for 30-day forecasts, < 10% for 7-day forecasts.

### 3.4 Loop 4: Query Intelligence

**Problem:** The Coordinator Agent's intent classification and response quality can improve with usage data.

**Learning signals:**

| Signal | What It Means | How to Detect |
|--------|--------------|---------------|
| User gives thumbs up | Response was helpful | Explicit feedback button |
| User gives thumbs down | Response was unhelpful | Explicit feedback button |
| User rephrases same question | Initial response missed the mark | Same topic in next turn |
| User asks follow-up drill-down | Response was good but incomplete | Related topic in next turn |
| User immediately asks new topic | Response was sufficient | Topic change in next turn |
| User clicks suggested action | A2UI component was useful | Component interaction tracking |

**What adapts:**
- Intent classification examples (add successful query→intent mappings to training set)
- Common query patterns per tenant (pre-cache popular query types)
- A2UI component preferences (some tenants prefer tables over charts)

**Storage:** Query interaction logs (anonymized) with feedback signals. Retained for 90 days.

### 3.5 Loop 5: Alert Optimization

**Problem:** Alert fatigue — too many alerts and users stop paying attention.

**Learning cycle:**

```
Alert sent (Mode 3 event)
  → Track user response:
     → Response time (how quickly did they look at it?)
     → Action taken (acknowledged, investigated, dismissed, ignored)
     → Channel effectiveness (did they see it in Slack? Email? PagerDuty?)

  → Adapt:
     → Alerts consistently ignored → reduce severity or suppress
     → Alerts with fast response → this is the right threshold
     → Channel preference → route alerts to the channel user actually reads
```

**What adapts:**
- Alert threshold per tenant (e.g., budget alert at 70% vs. 80% vs. 90%)
- Alert routing (Slack for info, PagerDuty for critical)
- Alert grouping (batch multiple small alerts into a daily digest)
- Time-of-day preferences (no non-critical alerts between 10 PM - 7 AM)

---

## 4. Learning Data Architecture

### 4.1 Feedback Store

A dedicated set of tables for learning signals, separate from operational data:

| Table | Purpose | Retention |
|-------|---------|-----------|
| anomaly_feedback | User responses to anomaly detections | 1 year |
| recommendation_outcomes | Execution results and savings tracking | 2 years |
| forecast_accuracy | Prediction vs. actual comparisons | 2 years |
| query_interactions | Query feedback and routing results | 90 days |
| alert_responses | User engagement with alerts | 1 year |

### 4.2 Learning Pipeline Schedule

| Job | Frequency | What It Does |
|-----|-----------|--------------|
| Anomaly threshold recalculation | Weekly (Sunday 1 AM) | Adjust per-tenant anomaly sensitivity |
| Recommendation scoring update | Monthly (1st of month) | Recalculate confidence model |
| Forecast model retraining | Monthly (1st of month) | Retrain Prophet with new actuals |
| Query pattern analysis | Weekly | Update popular query cache |
| Alert threshold optimization | Bi-weekly | Adjust per-tenant alert rules |

All learning jobs run per-tenant in isolation.

---

## 5. Self-Learning Guardrails

| Guardrail | Purpose |
|-----------|---------|
| Minimum feedback count before adapting | Prevent overreacting to 1-2 signals (minimum: 10) |
| Maximum threshold adjustment per cycle | No more than 20% change in any direction per cycle |
| Fallback to defaults | If model accuracy degrades, auto-revert to defaults |
| Human override | Tenant admin can lock any threshold to a manual value |
| Audit trail | Every model update logged with before/after values |
| A/B testing | New models tested on 10% of queries before full rollout |

---

## 6. Tenant-Facing Learning Dashboard

A transparency page where org_admins can see how the system is learning:

| Widget | Shows |
|--------|-------|
| Anomaly accuracy trend | False positive rate over time (should decrease) |
| Recommendation accuracy | Estimated vs. actual savings over time |
| Forecast accuracy | MAPE trend over time (should decrease) |
| Alert engagement | Response rate and time trends |
| Current thresholds | Active thresholds with "reset to default" option |

---

## Developer Notes

> **DEV-SL-001:** Self-learning is a Phase 6+ feature. The feedback collection infrastructure (tables, signals) should be built in Phase 4-5, but the actual learning algorithms can wait until there's enough data to be meaningful (typically 2-3 months of tenant usage).

> **DEV-SL-002:** Start with simple heuristic-based learning (moving averages, percentile-based thresholds) before investing in ML models. Simple approaches often outperform complex ones when data is limited.

> **DEV-SL-003:** The thumbs up/down UI should be present on every agent response from day one. Even before the learning pipeline is built, collecting this data is valuable.

> **DEV-SL-004:** Forecast model retraining should be idempotent and reproducible. Store model artifacts with version numbers. If a new model performs worse than the previous one (measured on holdout data), auto-rollback.

> **DEV-SL-005:** Cross-tenant learning aggregates (anonymized) could be valuable in the future — e.g., "tenants with similar AWS usage patterns typically save X% from rightsizing." This requires careful privacy design and explicit tenant opt-in. Defer to post-launch.

> **DEV-SL-006:** The recommendation impact loop (Loop 2) is the highest-value learning feature for customer retention. Being able to show "you've saved $47,000 this quarter based on our recommendations" is a powerful metric for renewals.
