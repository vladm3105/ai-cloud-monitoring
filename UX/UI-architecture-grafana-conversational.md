# UI Architecture: Grafana Dashboards + Conversational Widget
## Dual Interface for AI Cost Monitoring Platform

**Document Version:** 1.0  
**Last Updated:** February 2026  
**Use Case:** Multi-cloud LLM cost monitoring with two user interfaces

---

## Executive Summary

Your AI Cost Monitoring platform has **two complementary user interfaces**:

1. **Grafana Dashboards** - Visual analytics, charts, metrics exploration
2. **Conversational Widget** - Natural language queries, quick insights

**Key Insight:** These aren't competitors - they serve different use cases and work together.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Grafana Dashboards](#grafana-dashboards)
3. [Conversational Widget](#conversational-widget)
4. [Integration Strategy](#integration-strategy)
5. [Implementation Guide](#implementation-guide)
6. [Use Case Examples](#use-case-examples)

---

## Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     USER INTERFACE LAYER                     │
│                                                              │
│  ┌────────────────────────┐    ┌─────────────────────────┐ │
│  │  GRAFANA DASHBOARDS    │    │  CONVERSATIONAL WIDGET  │ │
│  │                        │    │                         │ │
│  │  • Visual Analytics    │    │  • Natural Language     │ │
│  │  • Interactive Charts  │    │  • Quick Queries        │ │
│  │  • Custom Panels       │    │  • AI-Powered Insights  │ │
│  │  • Drill-Down Views    │    │  • Chat Interface       │ │
│  └───────────┬────────────┘    └────────────┬────────────┘ │
│              │                               │              │
└──────────────┼───────────────────────────────┼──────────────┘
               │                               │
               │ SQL Queries                   │ API Calls
               ▼                               ▼
┌─────────────────────────────────────────────────────────────┐
│                     BACKEND LAYER                            │
│                                                              │
│  ┌──────────────────┐              ┌────────────────────┐  │
│  │  BigQuery        │              │  Conversational    │  │
│  │  (Direct SQL)    │              │  API Service       │  │
│  │                  │              │                    │  │
│  │  • Cost data     │              │  • Claude/GPT-4    │  │
│  │  • Usage metrics │              │  • Query parsing   │  │
│  │  • Aggregations  │              │  • SQL generation  │  │
│  └────────┬─────────┘              └────────┬───────────┘  │
│           │                                  │              │
│           └──────────────┬───────────────────┘              │
│                          ▼                                  │
│              ┌──────────────────────┐                       │
│              │  BigQuery Database   │                       │
│              │  unified_costs view  │                       │
│              └──────────────────────┘                       │
└─────────────────────────────────────────────────────────────┘
```

### When Users Use Each Interface

| User Need | Interface | Why |
|-----------|-----------|-----|
| **Explore trends** | Grafana | Visual charts over time |
| **Quick question** | Conversational | "How much did we spend yesterday?" |
| **Deep analysis** | Grafana | Drill-down, filters, comparisons |
| **Check status** | Conversational | "Are we over budget this month?" |
| **Build reports** | Grafana | Custom dashboards, export |
| **Get alerts** | Conversational | "Alert me if costs spike" |
| **Compare models** | Grafana | Side-by-side visualizations |
| **Explain spike** | Conversational | "Why did costs jump on Tuesday?" |

---

## Grafana Dashboards

### Overview

**What is Grafana?**
- Open-source analytics and visualization platform
- Connects to BigQuery (or Redshift/Azure SQL in Phase 2)
- Creates interactive dashboards with charts, graphs, tables
- Real-time data refresh

**Your Implementation:**
- Self-hosted on Cloud Run OR Grafana Cloud
- BigQuery data source (Phase 1)
- 4-6 core dashboards
- Multi-tenant support (customer filtering)

### Dashboard Architecture

#### Dashboard 1: Multi-Cloud Cost Overview

**Purpose:** Executive summary of costs across all clouds

**Panels:**

1. **Total Cost This Month** (Stat Panel)
```sql
SELECT SUM(cost_usd) as total_cost
FROM `project.multi_cloud_costs.unified_costs`
WHERE date >= DATE_TRUNC(CURRENT_DATE(), MONTH)
```

2. **Cost by Cloud Provider** (Pie Chart)
```sql
SELECT 
  cloud_provider,
  SUM(cost_usd) as cost
FROM `project.multi_cloud_costs.unified_costs`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY cloud_provider
```

3. **Daily Cost Trend** (Time Series)
```sql
SELECT 
  date,
  cloud_provider,
  SUM(cost_usd) as daily_cost
FROM `project.multi_cloud_costs.unified_costs`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY date, cloud_provider
ORDER BY date
```

4. **Top 10 Customers by Spend** (Bar Gauge)
```sql
SELECT 
  customer_id,
  SUM(cost_usd) as total_spend
FROM `project.multi_cloud_costs.unified_costs`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  AND customer_id IS NOT NULL
GROUP BY customer_id
ORDER BY total_spend DESC
LIMIT 10
```

5. **Budget vs Actual** (Gauge Panel)
```sql
SELECT 
  SUM(cost_usd) as actual,
  10000 as budget,  -- Dynamic from customer settings
  (SUM(cost_usd) / 10000) * 100 as percent_used
FROM `project.multi_cloud_costs.unified_costs`
WHERE date >= DATE_TRUNC(CURRENT_DATE(), MONTH)
```

**Dashboard Variables:**
- `$cloud_provider` - Multi-select (GCP, AWS, Azure, All)
- `$time_range` - Time picker (Last 7 days, 30 days, 90 days, Custom)
- `$customer_id` - Dropdown (for multi-tenant filtering)

---

#### Dashboard 2: Model Performance Analysis

**Purpose:** Compare LLM models across cost, usage, efficiency

**Panels:**

1. **Cost per Model** (Table)
```sql
SELECT 
  model,
  cloud_provider,
  SUM(cost_usd) as total_cost,
  SUM(usage_amount) as total_tokens,
  (SUM(cost_usd) / SUM(usage_amount) * 1000) as cost_per_1k_tokens,
  COUNT(DISTINCT customer_id) as active_customers
FROM `project.multi_cloud_costs.unified_costs`
WHERE date >= $__timeFrom()
  AND date <= $__timeTo()
  AND cloud_provider IN ($cloud_provider)
GROUP BY model, cloud_provider
ORDER BY total_cost DESC
```

2. **Model Cost Trend** (Time Series - Multi-line)
```sql
SELECT 
  date,
  model,
  SUM(cost_usd) as daily_cost
FROM `project.multi_cloud_costs.unified_costs`
WHERE date >= $__timeFrom()
  AND model IN ($model_filter)
GROUP BY date, model
ORDER BY date
```

3. **Input vs Output Tokens** (Stacked Bar Chart)
```sql
SELECT 
  model,
  SUM(CASE WHEN token_type = 'input' THEN cost_usd ELSE 0 END) as input_cost,
  SUM(CASE WHEN token_type = 'output' THEN cost_usd ELSE 0 END) as output_cost
FROM `project.multi_cloud_costs.unified_costs`
WHERE date >= $__timeFrom()
GROUP BY model
ORDER BY (input_cost + output_cost) DESC
```

4. **Model Efficiency Score** (Bar Gauge)
```sql
-- Cost per 1K tokens (lower is better)
SELECT 
  model,
  (SUM(cost_usd) / NULLIF(SUM(usage_amount), 0)) * 1000 as cost_per_1k
FROM `project.multi_cloud_costs.unified_costs`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  AND usage_amount > 0
GROUP BY model
HAVING SUM(usage_amount) > 100000  -- Minimum threshold
ORDER BY cost_per_1k ASC
```

---

#### Dashboard 3: Customer Attribution

**Purpose:** Track costs per customer, project, team

**Panels:**

1. **Customer Spend Heatmap** (Heatmap)
```sql
SELECT 
  customer_id,
  DATE_TRUNC(date, WEEK) as week,
  SUM(cost_usd) as weekly_cost
FROM `project.multi_cloud_costs.unified_costs`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
  AND customer_id IS NOT NULL
GROUP BY customer_id, week
ORDER BY week, customer_id
```

2. **Top Spenders This Month** (Table)
```sql
SELECT 
  customer_id,
  SUM(cost_usd) as mtd_cost,
  SUM(CASE WHEN date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) 
      THEN cost_usd ELSE 0 END) as last_7_days,
  COUNT(DISTINCT date) as active_days,
  ARRAY_AGG(DISTINCT model IGNORE NULLS) as models_used
FROM `project.multi_cloud_costs.unified_costs`
WHERE date >= DATE_TRUNC(CURRENT_DATE(), MONTH)
GROUP BY customer_id
ORDER BY mtd_cost DESC
LIMIT 20
```

3. **Customer Growth** (Time Series)
```sql
SELECT 
  date,
  COUNT(DISTINCT customer_id) as active_customers,
  SUM(cost_usd) as total_revenue
FROM `project.multi_cloud_costs.unified_costs`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
GROUP BY date
ORDER BY date
```

---

#### Dashboard 4: Anomaly Detection & Alerts

**Purpose:** Identify unusual spending patterns

**Panels:**

1. **Cost Anomalies** (Graph with Threshold Lines)
```sql
WITH daily_stats AS (
  SELECT 
    date,
    SUM(cost_usd) as daily_cost
  FROM `project.multi_cloud_costs.unified_costs`
  WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  GROUP BY date
),
moving_avg AS (
  SELECT 
    date,
    daily_cost,
    AVG(daily_cost) OVER (
      ORDER BY date 
      ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) as avg_7day,
    STDDEV(daily_cost) OVER (
      ORDER BY date 
      ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) as stddev_7day
  FROM daily_stats
)
SELECT 
  date,
  daily_cost,
  avg_7day,
  avg_7day + (2 * stddev_7day) as upper_threshold,
  avg_7day - (2 * stddev_7day) as lower_threshold,
  CASE 
    WHEN daily_cost > avg_7day + (2 * stddev_7day) THEN 'High Anomaly'
    WHEN daily_cost < avg_7day - (2 * stddev_7day) THEN 'Low Anomaly'
    ELSE 'Normal'
  END as status
FROM moving_avg
ORDER BY date
```

2. **Unusual Customer Activity** (Table)
```sql
WITH customer_baseline AS (
  SELECT 
    customer_id,
    AVG(daily_cost) as avg_daily,
    STDDEV(daily_cost) as stddev_daily
  FROM (
    SELECT customer_id, date, SUM(cost_usd) as daily_cost
    FROM `project.multi_cloud_costs.unified_costs`
    WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    GROUP BY customer_id, date
  )
  GROUP BY customer_id
),
yesterday_cost AS (
  SELECT 
    customer_id,
    SUM(cost_usd) as cost_yesterday
  FROM `project.multi_cloud_costs.unified_costs`
  WHERE date = CURRENT_DATE() - 1
  GROUP BY customer_id
)
SELECT 
  y.customer_id,
  y.cost_yesterday,
  b.avg_daily,
  ((y.cost_yesterday - b.avg_daily) / b.avg_daily * 100) as percent_change,
  CASE 
    WHEN y.cost_yesterday > b.avg_daily + (2 * b.stddev_daily) THEN '🔴 High Alert'
    WHEN y.cost_yesterday > b.avg_daily + b.stddev_daily THEN '🟡 Warning'
    ELSE '🟢 Normal'
  END as alert_level
FROM yesterday_cost y
JOIN customer_baseline b ON y.customer_id = b.customer_id
WHERE y.cost_yesterday > b.avg_daily + b.stddev_daily
ORDER BY percent_change DESC
```

---

### Grafana Features You'll Use

#### 1. Dashboard Variables

```json
{
  "templating": {
    "list": [
      {
        "name": "cloud_provider",
        "type": "query",
        "query": "SELECT DISTINCT cloud_provider FROM `project.multi_cloud_costs.unified_costs` ORDER BY cloud_provider",
        "multi": true,
        "includeAll": true,
        "current": {"text": "All", "value": "$__all"}
      },
      {
        "name": "customer_id",
        "type": "query",
        "query": "SELECT DISTINCT customer_id FROM `project.multi_cloud_costs.unified_costs` WHERE customer_id IS NOT NULL ORDER BY customer_id",
        "multi": false,
        "includeAll": true
      },
      {
        "name": "model",
        "type": "query",
        "query": "SELECT DISTINCT model FROM `project.multi_cloud_costs.unified_costs` WHERE model IS NOT NULL ORDER BY model",
        "multi": true,
        "includeAll": true
      }
    ]
  }
}
```

#### 2. Alert Rules

**Example: Daily Cost Threshold Alert**

```yaml
apiVersion: 1

groups:
  - name: cost_alerts
    interval: 1h
    rules:
      - uid: daily_cost_spike
        title: Daily Cost Spike
        condition: B
        data:
          - refId: A
            queryType: ''
            model:
              expr: 'SELECT SUM(cost_usd) FROM `project.multi_cloud_costs.unified_costs` WHERE date = CURRENT_DATE()'
          - refId: B
            queryType: ''
            model:
              type: threshold
              conditions:
                - evaluator:
                    params: [1000]  # $1000 threshold
                    type: gt
        noDataState: NoData
        execErrState: Alerting
        for: 5m
        annotations:
          description: 'Daily cost exceeded $1000. Current: {{ $values.A }}'
        labels:
          severity: warning
```

#### 3. Multi-Tenant Support

**Approach 1: Separate Organizations**
```
Grafana Organization per Customer:
- Customer A → Org ID 1 → Filtered queries (WHERE customer_id = 'cust_a')
- Customer B → Org ID 2 → Filtered queries (WHERE customer_id = 'cust_b')
```

**Approach 2: Shared Dashboards with Variables**
```
Single Grafana instance:
- User logs in
- Dashboard variable auto-set based on user: $customer_id
- All queries filtered: WHERE customer_id = $customer_id
```

---

## Conversational Widget

### Overview

**What is it?**
- Chat interface embedded in your product
- Natural language queries about LLM costs
- AI-powered (Claude, GPT-4) to parse questions
- Generates SQL queries dynamically
- Returns conversational answers

**Technologies:**
- Frontend: React widget
- Backend: FastAPI or Next.js API
- AI: Claude 3.5 Sonnet or GPT-4
- Database: Same BigQuery as Grafana

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  CONVERSATIONAL WIDGET                       │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  React Chat Component                                  │ │
│  │                                                         │ │
│  │  User: "How much did Gemini cost last week?"          │ │
│  │  ↓                                                      │ │
│  │  AI: "Gemini cost $1,234.56 last week. That's a       │ │
│  │       15% increase from the previous week."            │ │
│  └────────────────────────┬───────────────────────────────┘ │
│                           │                                  │
│                           │ POST /api/chat                   │
│                           ▼                                  │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Backend API (FastAPI / Next.js)                       │ │
│  │                                                         │ │
│  │  1. Receive natural language query                     │ │
│  │  2. Call Claude/GPT-4 to parse intent                  │ │
│  │  3. Generate SQL query                                 │ │
│  │  4. Execute query on BigQuery                          │ │
│  │  5. Format results as conversational response          │ │
│  └────────────────────────┬───────────────────────────────┘ │
│                           │                                  │
│                           │ Execute SQL                      │
│                           ▼                                  │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  BigQuery (same database as Grafana)                   │ │
│  │  unified_costs view                                    │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Implementation

#### Frontend: React Chat Widget

```tsx
// components/CostChatWidget.tsx
import { useState } from 'react';

interface Message {
  role: 'user' | 'assistant';
  content: string;
  timestamp: Date;
}

export default function CostChatWidget() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);

  const sendMessage = async () => {
    if (!input.trim()) return;

    // Add user message
    const userMessage: Message = {
      role: 'user',
      content: input,
      timestamp: new Date()
    };
    setMessages(prev => [...prev, userMessage]);
    setInput('');
    setLoading(true);

    try {
      // Call backend API
      const response = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: input,
          customer_id: 'cust_123', // From user session
          conversation_history: messages
        })
      });

      const data = await response.json();

      // Add assistant response
      const assistantMessage: Message = {
        role: 'assistant',
        content: data.response,
        timestamp: new Date()
      };
      setMessages(prev => [...prev, assistantMessage]);
    } catch (error) {
      console.error('Chat error:', error);
      setMessages(prev => [...prev, {
        role: 'assistant',
        content: 'Sorry, I encountered an error. Please try again.',
        timestamp: new Date()
      }]);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="chat-widget">
      <div className="messages">
        {messages.map((msg, idx) => (
          <div key={idx} className={`message ${msg.role}`}>
            <div className="content">{msg.content}</div>
            <div className="timestamp">
              {msg.timestamp.toLocaleTimeString()}
            </div>
          </div>
        ))}
        {loading && <div className="loading">Analyzing...</div>}
      </div>

      <div className="input-area">
        <input
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyPress={(e) => e.key === 'Enter' && sendMessage()}
          placeholder="Ask about your LLM costs..."
        />
        <button onClick={sendMessage} disabled={loading}>
          Send
        </button>
      </div>

      {/* Suggested queries */}
      <div className="suggestions">
        <button onClick={() => setInput("How much did we spend yesterday?")}>
          Yesterday's cost
        </button>
        <button onClick={() => setInput("Which model is most expensive?")}>
          Top model
        </button>
        <button onClick={() => setInput("Are we over budget this month?")}>
          Budget status
        </button>
      </div>
    </div>
  );
}
```

#### Backend: FastAPI Chat API

```python
# api/chat.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from anthropic import Anthropic
from google.cloud import bigquery
import json

app = FastAPI()
anthropic = Anthropic(api_key="your-api-key")
bq_client = bigquery.Client()

class ChatRequest(BaseModel):
    message: str
    customer_id: str
    conversation_history: list = []

class ChatResponse(BaseModel):
    response: str
    sql_query: str = None
    data: dict = None

@app.post("/api/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """
    Process natural language query about LLM costs
    
    Flow:
    1. Parse user intent with Claude
    2. Generate SQL query
    3. Execute on BigQuery
    4. Format response conversationally
    """
    
    # Step 1: Parse intent and generate SQL
    system_prompt = f"""You are an AI assistant for an LLM cost monitoring platform.

Database schema:
- Table: project.multi_cloud_costs.unified_costs
- Columns:
  - date (DATE)
  - cloud_provider (STRING: GCP, AWS, Azure)
  - service (STRING)
  - model (STRING: gemini-pro, claude-v2, gpt-4, etc.)
  - cost_usd (FLOAT64)
  - usage_amount (FLOAT64) - token count
  - customer_id (STRING)

Current customer: {request.customer_id}
Current date: {datetime.now().strftime('%Y-%m-%d')}

Your task:
1. Parse the user's question
2. Generate a BigQuery SQL query (always filter by customer_id = '{request.customer_id}')
3. Return a JSON response with:
   - "sql": the SQL query
   - "explanation": brief explanation of what the query does

Only query data for customer_id = '{request.customer_id}'. Never show other customers' data.
"""

    try:
        # Call Claude to generate SQL
        message = anthropic.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=1000,
            system=system_prompt,
            messages=[
                {"role": "user", "content": request.message}
            ]
        )
        
        # Parse Claude's response
        response_text = message.content[0].text
        
        # Extract JSON (Claude returns JSON with sql and explanation)
        import re
        json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
        if json_match:
            parsed = json.loads(json_match.group())
            sql_query = parsed.get('sql', '')
            explanation = parsed.get('explanation', '')
        else:
            raise ValueError("Could not parse SQL from Claude response")
        
        # Step 2: Execute SQL on BigQuery
        query_job = bq_client.query(sql_query)
        results = query_job.result()
        
        # Convert to list of dicts
        data = [dict(row) for row in results]
        
        # Step 3: Format conversational response
        format_prompt = f"""Given this data from a BigQuery query:

SQL Query: {sql_query}
Results: {json.dumps(data, default=str)}

User's original question: {request.message}

Provide a conversational, concise answer to the user's question based on the data.
- Use natural language
- Include specific numbers
- Add context if relevant (e.g., "That's a 15% increase from last week")
- Keep it brief (2-3 sentences max)
- If no data, say so clearly
"""

        format_message = anthropic.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=500,
            messages=[
                {"role": "user", "content": format_prompt}
            ]
        )
        
        conversational_response = format_message.content[0].text
        
        return ChatResponse(
            response=conversational_response,
            sql_query=sql_query,
            data={"rows": data}
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# Example: Quick stats endpoint
@app.get("/api/quick-stats")
async def quick_stats(customer_id: str):
    """Get quick cost stats for dashboard badge"""
    
    query = f"""
    SELECT 
      SUM(CASE WHEN date = CURRENT_DATE() THEN cost_usd ELSE 0 END) as cost_today,
      SUM(CASE WHEN date >= DATE_TRUNC(CURRENT_DATE(), MONTH) THEN cost_usd ELSE 0 END) as cost_mtd,
      SUM(CASE WHEN date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) THEN cost_usd ELSE 0 END) as cost_7d
    FROM `project.multi_cloud_costs.unified_costs`
    WHERE customer_id = '{customer_id}'
    """
    
    results = bq_client.query(query).result()
    row = next(results)
    
    return {
        "today": float(row.cost_today or 0),
        "month_to_date": float(row.cost_mtd or 0),
        "last_7_days": float(row.cost_7d or 0)
    }
```

### Example Queries the Widget Can Handle

**Question:** "How much did we spend yesterday?"

**AI Process:**
1. Parse: date = yesterday, metric = total cost
2. SQL: `SELECT SUM(cost_usd) FROM unified_costs WHERE date = CURRENT_DATE() - 1 AND customer_id = 'cust_123'`
3. Execute: Returns $245.67
4. Response: "You spent $245.67 yesterday on LLM costs."

---

**Question:** "Which model is most expensive this week?"

**AI Process:**
1. Parse: time = last 7 days, metric = cost by model, sort = descending
2. SQL: 
```sql
SELECT model, SUM(cost_usd) as cost 
FROM unified_costs 
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) 
  AND customer_id = 'cust_123'
GROUP BY model 
ORDER BY cost DESC 
LIMIT 1
```
3. Execute: Returns {model: "gpt-4", cost: 856.34}
4. Response: "GPT-4 was your most expensive model this week at $856.34, accounting for 45% of your total spend."

---

**Question:** "Am I over budget this month?"

**AI Process:**
1. Parse: time = month-to-date, compare to budget
2. SQL:
```sql
SELECT 
  SUM(cost_usd) as actual,
  (SELECT budget FROM customer_settings WHERE customer_id = 'cust_123') as budget
FROM unified_costs 
WHERE date >= DATE_TRUNC(CURRENT_DATE(), MONTH)
  AND customer_id = 'cust_123'
```
3. Execute: Returns {actual: 1234.56, budget: 1500}
4. Response: "You've spent $1,234.56 this month against your $1,500 budget. That's 82% of your budget with 12 days remaining."

---

**Question:** "Why did costs spike on Tuesday?"

**AI Process:**
1. Parse: date = last Tuesday, drill-down analysis
2. SQL (multiple queries):
```sql
-- Query 1: What was the spike?
SELECT SUM(cost_usd) FROM unified_costs 
WHERE date = DATE_SUB(CURRENT_DATE(), INTERVAL 5 DAY) -- Last Tuesday

-- Query 2: Break down by model
SELECT model, SUM(cost_usd) as cost
FROM unified_costs 
WHERE date = DATE_SUB(CURRENT_DATE(), INTERVAL 5 DAY)
GROUP BY model
ORDER BY cost DESC

-- Query 3: Compare to average
SELECT AVG(daily_cost) FROM (
  SELECT date, SUM(cost_usd) as daily_cost
  FROM unified_costs
  WHERE date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY) AND CURRENT_DATE()
  GROUP BY date
)
```
3. Execute: Returns spike was $456 vs $200 avg, GPT-4 was $350 of it
4. Response: "Tuesday's costs were $456, which is 2.3x your daily average of $200. The spike was primarily driven by GPT-4 ($350), which was 4x higher than usual. This aligns with your batch processing job that ran that day."

---

## Integration Strategy

### How Both UIs Work Together

#### Scenario 1: Executive Using Both

**Morning Routine:**
1. **Conversational Widget:** "How much did we spend yesterday?"
   - Quick answer: "$1,234"
   
2. **If anomaly detected:**
   - Widget: "That's 50% higher than usual. Would you like to see details?"
   - User clicks "View Dashboard"
   - Opens Grafana → Anomaly Detection dashboard
   - Sees visual breakdown by model, customer, time

#### Scenario 2: Finance Team Deep Dive

**Monthly Close:**
1. **Grafana:** Open "Multi-Cloud Cost Overview"
   - View total spend, trend charts
   - Identify top spending customers
   - Export data for reports

2. **Conversational Widget** (for quick checks):
   - "Which customers are over budget?"
   - "What's the year-over-year growth?"
   - Fast answers without building new queries

#### Scenario 3: Customer Success

**Customer Call:**
1. **Conversational Widget:** "What did customer Acme Inc spend last month?"
   - Instant answer: "$5,678"

2. **Follow-up in Grafana:**
   - Filter dashboard: `customer_id = acme_inc`
   - Show trend chart during screenshare
   - Discuss optimization opportunities

### Linking Between UIs

**Widget → Grafana:**
```tsx
// In conversational widget response
<a href={`/grafana/d/overview?var-customer_id=${customerId}&from=${startDate}&to=${endDate}`}>
  View detailed dashboard →
</a>
```

**Grafana → Widget:**
```
Add panel in Grafana with custom HTML/text:
"💬 Ask questions: [Open Chat Widget]"
```

---

## Implementation Guide

### Phase 1: Grafana Only (Week 3 of MVP)

**Timeline:** 1 week  
**Cost:** Included in $25-35/month

**Steps:**
1. Deploy Grafana (Cloud Run or Grafana Cloud)
2. Configure BigQuery data source
3. Create 3-4 core dashboards
4. Set up basic alerts
5. Launch to first customers

**Deliverables:**
- Multi-Cloud Cost Overview dashboard
- Model Performance dashboard
- Customer Attribution dashboard
- 2-3 alert rules

---

### Phase 2: Add Conversational Widget (After 10 customers)

**Timeline:** 2 weeks  
**Cost:** +$50-100/month (Claude API usage)

**Steps:**

**Week 1:**
1. Build FastAPI chat endpoint
2. Integrate Claude API
3. Test SQL generation with sample queries
4. Deploy API (Cloud Run)

**Week 2:**
1. Build React chat widget
2. Embed in product
3. Add suggested queries
4. User testing with 3-5 customers
5. Launch to all customers

**Deliverables:**
- Chat widget component
- Backend API
- 10-15 tested query patterns
- Analytics on widget usage

---

### Cost Breakdown

| Component | Setup Cost | Monthly Cost |
|-----------|------------|--------------|
| **Grafana** | | |
| Grafana (self-hosted) | 4 hours | $15-25 |
| Dashboard development | 16-20 hours | Included |
| Alert setup | 2 hours | Included |
| **Conversational Widget** | | |
| Backend API development | 12-16 hours | $5-10 (Cloud Run) |
| Frontend widget | 8-12 hours | Included |
| Claude API usage | - | $30-80 (est. 10K queries/mo) |
| Testing & refinement | 8 hours | - |
| **TOTAL** | **50-60 hours** | **$50-115/month** |

**Note:** Development hours are one-time. Monthly cost is operational.

---

## Use Case Examples

### Use Case 1: Daily Operations

**Persona:** Engineering Manager

**Morning Routine:**
1. Open product dashboard
2. Check conversational widget: "How much did we spend yesterday?"
3. Widget shows: "$456 (15% over daily budget)"
4. Click "View Details" → Opens Grafana
5. See spike in GPT-4 usage
6. Investigate in logs

**Why Both UIs:**
- Widget: Fast status check
- Grafana: Visual analysis of spike

---

### Use Case 2: Monthly Reporting

**Persona:** Finance Team

**Month-End Process:**
1. **Grafana:**
   - Open Multi-Cloud Cost Overview
   - Set time range: This month
   - Export table of costs by customer
   - Take screenshots of trend charts
   - Add to monthly report

2. **Conversational Widget:**
   - "What's the month-over-month growth?"
   - "Which customers grew the most?"
   - Fast answers for executive summary

**Why Both UIs:**
- Grafana: Visual reports, exports
- Widget: Quick calculations, comparisons

---

### Use Case 3: Customer Success

**Persona:** Account Manager

**Customer Call:**
1. **Before call (Conversational Widget):**
   - "What did Acme Inc spend last month?"
   - "Which models do they use most?"
   - "Are they over budget?"
   - Quick facts loaded in 30 seconds

2. **During call (Grafana):**
   - Share screen with Grafana dashboard
   - Filter: `customer_id = acme_inc`
   - Walk through cost trends
   - Discuss optimization opportunities

**Why Both UIs:**
- Widget: Fast prep before call
- Grafana: Visual presentation during call

---

## Recommended Reading Order

### For Product Managers:
1. Architecture Overview (this section)
2. Use Case Examples
3. Integration Strategy

### For Developers:
1. Grafana Implementation
2. Conversational Widget Implementation
3. Integration Guide

### For Finance/Operations:
1. Grafana Dashboards section
2. Dashboard examples
3. Use Case Examples

---

## Summary

### Grafana Dashboards
**Best for:**
- Visual analysis
- Trend exploration
- Custom reports
- Team collaboration
- Scheduled alerts

**Limitations:**
- Requires dashboard creation
- SQL knowledge helpful
- Not conversational

---

### Conversational Widget
**Best for:**
- Quick questions
- Status checks
- Natural language
- Non-technical users
- Mobile-friendly

**Limitations:**
- Less visual
- Limited to trained queries
- AI costs ($30-80/mo)

---

### Together They Provide:
✅ Fast answers (Widget) + Deep analysis (Grafana)  
✅ Non-technical (Widget) + Technical (Grafana)  
✅ Mobile (Widget) + Desktop (Grafana)  
✅ Conversational (Widget) + Visual (Grafana)  

**Recommended:** Start with Grafana (Phase 1), add Widget after 10 customers (Phase 2).

---

**Document End**
