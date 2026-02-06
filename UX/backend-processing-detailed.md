# Backend Processing: Detailed Explanation
## How Dynamic Chart Generation Works Behind the Scenes

**Document Version:** 1.0  
**Last Updated:** February 2026  
**Purpose:** Deep dive into the backend processing layer

---

## Executive Summary

**What is the Backend?**
The backend is the **server-side application** that sits between your frontend (user interface) and your data sources. It receives user queries, communicates with LLMs, executes database queries, and returns formatted data to the frontend.

**Three Critical Steps:**
1. **Step 4A: Execute SQL** - Query your BigQuery database
2. **Step 4B: Prepare Chart** - Transform data for visualization
3. **Step 4C: Return to Frontend** - Send configuration + data

---

## Table of Contents

1. [What is a Backend?](#what-is-a-backend)
2. [Backend Architecture](#backend-architecture)
3. [Step 4A: Execute SQL](#step-4a-execute-sql)
4. [Step 4B: Prepare Chart](#step-4b-prepare-chart)
5. [Step 4C: Return to Frontend](#step-4c-return-to-frontend)
6. [Technology Stack](#technology-stack)
7. [Complete Implementation](#complete-implementation)

---

## What is a Backend?

### Simple Explanation

```
┌─────────────────────────────────────────────────────────────┐
│                    YOUR APPLICATION                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  FRONTEND (What user sees)                                  │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  - React/Next.js                                        │ │
│  │  - Charts (Recharts)                                    │ │
│  │  - User inputs                                          │ │
│  │  - Runs in browser                                      │ │
│  └────────────────────────────────────────────────────────┘ │
│                          ↕                                   │
│                     API Calls                                │
│                          ↕                                   │
│  BACKEND (Hidden from user)                                 │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  - FastAPI/Express.js                                   │ │
│  │  - LLM communication (OpenAI/Gemini)                    │ │
│  │  - Database queries (BigQuery)                          │ │
│  │  - Data processing                                      │ │
│  │  - Runs on server (not browser)                         │ │
│  └────────────────────────────────────────────────────────┘ │
│                          ↕                                   │
│  DATA SOURCES                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  - BigQuery database                                    │ │
│  │  - OpenAI/Gemini API                                    │ │
│  │  - Your cost data                                       │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Why Do You Need a Backend?

**Security:**
- ❌ NEVER put API keys in frontend (users can see them!)
- ✅ Backend keeps secrets secure

**Processing Power:**
- ❌ Frontend runs in browser (limited resources)
- ✅ Backend runs on powerful servers

**Database Access:**
- ❌ Frontend can't directly query BigQuery
- ✅ Backend has database credentials

**Business Logic:**
- ✅ Backend validates queries
- ✅ Backend enforces permissions
- ✅ Backend handles complex processing

---

## Backend Architecture

### Technology Choices

**Option 1: Python Backend (FastAPI) - Recommended**

```python
# Why FastAPI?
✅ Easy to learn
✅ Fast performance
✅ Auto-generated API docs
✅ Great for data/ML work
✅ Built-in async support
```

**Option 2: Node.js Backend (Express.js)**

```javascript
// Why Express.js?
✅ JavaScript everywhere (frontend + backend)
✅ Huge ecosystem (npm packages)
✅ Great for real-time features
✅ Easy deployment
```

**Option 3: Next.js API Routes (Simplest)**

```typescript
// Why Next.js API Routes?
✅ Frontend + Backend in one project
✅ No separate deployment
✅ Serverless by default
✅ Easy for small projects
```

### Our Recommendation

**Start with Next.js API Routes** (simplest), then migrate to FastAPI if you need more power.

---

## Step 4A: Execute SQL on BigQuery

### What Happens

```
┌─────────────────────────────────────────────────────────────┐
│              STEP 4A: EXECUTE SQL ON BIGQUERY                │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Input: LLM-generated SQL query                             │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ "SELECT date, model, SUM(cost_usd) as cost             │ │
│  │  FROM unified_costs                                     │ │
│  │  WHERE date >= DATE_SUB(CURRENT_DATE(), 30)            │ │
│  │  GROUP BY date, model"                                  │ │
│  └────────────────────────────────────────────────────────┘ │
│                          ↓                                   │
│  Your Backend:                                              │
│  1. ✅ Validate SQL (prevent SQL injection)                │
│  2. ✅ Add customer filter (WHERE customer_id = ...)       │
│  3. ✅ Execute on BigQuery                                 │
│  4. ✅ Handle errors                                       │
│                          ↓                                   │
│  Output: Raw data rows                                      │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ [                                                       │ │
│  │   {date: "2026-01-15", model: "gpt-4", cost: 234.56},  │ │
│  │   {date: "2026-01-16", model: "gpt-4", cost: 245.67},  │ │
│  │   ...                                                   │ │
│  │ ]                                                       │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Tools Used

**1. Google Cloud BigQuery Client**

```python
# Install
pip install google-cloud-bigquery

# Usage
from google.cloud import bigquery

client = bigquery.Client(project="your-project-id")

# Execute query
query = """
    SELECT date, model, SUM(cost_usd) as cost
    FROM `project.dataset.unified_costs`
    WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    GROUP BY date, model
"""

results = client.query(query).result()
rows = [dict(row) for row in results]
```

**2. SQL Validation Library**

```python
# Install
pip install sqlparse

# Usage - Validate SQL before execution
import sqlparse

def validate_sql(sql_query: str) -> bool:
    """Ensure SQL is safe to execute"""
    
    # Parse SQL
    parsed = sqlparse.parse(sql_query)
    
    # Check for dangerous operations
    dangerous_keywords = ['DROP', 'DELETE', 'UPDATE', 'INSERT', 'ALTER']
    
    sql_upper = sql_query.upper()
    for keyword in dangerous_keywords:
        if keyword in sql_upper:
            raise ValueError(f"Dangerous SQL keyword detected: {keyword}")
    
    return True
```

**3. Customer Isolation (Multi-tenant Security)**

```python
def add_customer_filter(sql: str, customer_id: str) -> str:
    """
    CRITICAL: Add customer_id filter to EVERY query
    Prevents customers from seeing each other's data
    """
    
    # If query already has WHERE, add AND
    if 'WHERE' in sql.upper():
        sql = sql.replace('WHERE', f'WHERE customer_id = "{customer_id}" AND', 1)
    else:
        # Add WHERE before GROUP BY or ORDER BY
        if 'GROUP BY' in sql.upper():
            sql = sql.replace('GROUP BY', f'WHERE customer_id = "{customer_id}" GROUP BY', 1)
        elif 'ORDER BY' in sql.upper():
            sql = sql.replace('ORDER BY', f'WHERE customer_id = "{customer_id}" ORDER BY', 1)
        else:
            sql += f' WHERE customer_id = "{customer_id}"'
    
    return sql
```

### Complete Step 4A Code

```python
# backend/database/bigquery_executor.py

from google.cloud import bigquery
from typing import List, Dict
import sqlparse

class BigQueryExecutor:
    """
    Handles all BigQuery operations safely
    """
    
    def __init__(self, project_id: str):
        self.client = bigquery.Client(project=project_id)
    
    def execute_chart_query(
        self, 
        llm_generated_sql: str,
        customer_id: str
    ) -> List[Dict]:
        """
        Step 4A: Execute SQL on BigQuery with safety checks
        
        Args:
            llm_generated_sql: SQL from GPT-4/Gemini
            customer_id: Current user's customer ID
            
        Returns:
            List of data rows
        """
        
        # 1. Validate SQL syntax
        self._validate_sql(llm_generated_sql)
        
        # 2. Add customer filter (CRITICAL for multi-tenant security)
        safe_sql = self._add_customer_filter(llm_generated_sql, customer_id)
        
        # 3. Execute query
        try:
            query_job = self.client.query(safe_sql)
            results = query_job.result()
            
            # 4. Convert to list of dictionaries
            rows = [dict(row) for row in results]
            
            return rows
            
        except Exception as e:
            # Log error and return empty result
            print(f"BigQuery error: {e}")
            return []
    
    def _validate_sql(self, sql: str):
        """Prevent SQL injection"""
        dangerous = ['DROP', 'DELETE', 'UPDATE', 'INSERT', 'ALTER', 'CREATE']
        sql_upper = sql.upper()
        
        for keyword in dangerous:
            if keyword in sql_upper:
                raise ValueError(f"SQL contains dangerous keyword: {keyword}")
    
    def _add_customer_filter(self, sql: str, customer_id: str) -> str:
        """Add customer isolation"""
        if 'WHERE' in sql.upper():
            sql = sql.replace('WHERE', f'WHERE customer_id = "{customer_id}" AND', 1)
        else:
            sql += f' WHERE customer_id = "{customer_id}"'
        
        return sql


# Usage in API endpoint
executor = BigQueryExecutor(project_id="your-project")

sql_from_llm = "SELECT date, SUM(cost_usd) FROM unified_costs GROUP BY date"
customer_id = "cust_123"  # From user session

data = executor.execute_chart_query(sql_from_llm, customer_id)
```

---

## Step 4B: Prepare Chart Component

### What Happens

```
┌─────────────────────────────────────────────────────────────┐
│           STEP 4B: PREPARE CHART COMPONENT                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Input 1: LLM chart configuration                           │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ {                                                       │ │
│  │   "chartType": "LineChart",                            │ │
│  │   "chartConfig": {                                     │ │
│  │     "xAxis": { "dataKey": "date" },                   │ │
│  │     "lines": [{ "dataKey": "cost", "stroke": "#..." }]│ │
│  │   }                                                    │ │
│  │ }                                                      │ │
│  └────────────────────────────────────────────────────────┘ │
│                          +                                   │
│  Input 2: Data from BigQuery (Step 4A)                     │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ [                                                       │ │
│  │   {date: "2026-01-15", cost: 234.56},                 │ │
│  │   {date: "2026-01-16", cost: 245.67}                  │ │
│  │ ]                                                       │ │
│  └────────────────────────────────────────────────────────┘ │
│                          ↓                                   │
│  Your Backend:                                              │
│  1. ✅ Validate chart config                               │
│  2. ✅ Transform data if needed                            │
│  3. ✅ Add chart metadata (title, colors)                  │
│  4. ✅ Format for Recharts                                 │
│                          ↓                                   │
│  Output: Complete chart package                             │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ {                                                       │ │
│  │   "chartType": "LineChart",                            │ │
│  │   "config": { ... },                                   │ │
│  │   "data": [ ... ],                                     │ │
│  │   "metadata": {                                        │ │
│  │     "title": "Cost Trends",                            │ │
│  │     "generatedAt": "2026-02-06T10:30:00Z"             │ │
│  │   }                                                    │ │
│  │ }                                                       │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Tools Used

**1. Pydantic (Data Validation)**

```python
# Install
pip install pydantic

# Usage - Define chart schema
from pydantic import BaseModel, Field
from typing import List, Dict, Literal

class ChartConfig(BaseModel):
    """Validates LLM-generated chart config"""
    
    chartType: Literal["LineChart", "BarChart", "PieChart", "AreaChart"]
    chartConfig: Dict
    title: str = Field(default="Chart")
    
    class Config:
        # Ensure all fields are present
        extra = "forbid"

# Validate
try:
    config = ChartConfig(**llm_response)
except ValidationError as e:
    print(f"Invalid chart config: {e}")
```

**2. Pandas (Data Transformation)**

```python
# Install
pip install pandas

# Usage - Transform data
import pandas as pd
from datetime import datetime

def transform_data_for_chart(rows: List[Dict]) -> List[Dict]:
    """Transform BigQuery rows for Recharts"""
    
    df = pd.DataFrame(rows)
    
    # Convert date strings to formatted dates
    if 'date' in df.columns:
        df['date'] = pd.to_datetime(df['date']).dt.strftime('%Y-%m-%d')
    
    # Round numbers for display
    numeric_cols = df.select_dtypes(include=['float64']).columns
    df[numeric_cols] = df[numeric_cols].round(2)
    
    # Convert back to list of dicts
    return df.to_dict('records')
```

### Complete Step 4B Code

```python
# backend/chart/chart_preparer.py

from pydantic import BaseModel, ValidationError
from typing import List, Dict, Literal
import pandas as pd
from datetime import datetime

class ChartResponse(BaseModel):
    """Final response sent to frontend"""
    chartType: Literal["LineChart", "BarChart", "PieChart", "AreaChart"]
    config: Dict
    data: List[Dict]
    metadata: Dict

class ChartPreparer:
    """
    Handles Step 4B: Transform data for visualization
    """
    
    def prepare_chart(
        self,
        llm_config: Dict,
        bigquery_data: List[Dict]
    ) -> ChartResponse:
        """
        Prepare chart for frontend rendering
        
        Args:
            llm_config: Configuration from GPT-4/Gemini
            bigquery_data: Rows from BigQuery
            
        Returns:
            Complete chart package ready for Recharts
        """
        
        # 1. Validate LLM config
        validated_config = self._validate_config(llm_config)
        
        # 2. Transform data
        transformed_data = self._transform_data(bigquery_data)
        
        # 3. Add metadata
        metadata = {
            "title": validated_config.get("title", "Chart"),
            "generatedAt": datetime.utcnow().isoformat(),
            "dataPoints": len(transformed_data),
            "llmProvider": "gpt-4o"  # Track which LLM was used
        }
        
        # 4. Build complete response
        return ChartResponse(
            chartType=validated_config["chartType"],
            config=validated_config["chartConfig"],
            data=transformed_data,
            metadata=metadata
        )
    
    def _validate_config(self, config: Dict) -> Dict:
        """Ensure config is safe and complete"""
        
        # Required fields
        if "chartType" not in config:
            raise ValueError("Missing chartType")
        
        if config["chartType"] not in ["LineChart", "BarChart", "PieChart", "AreaChart"]:
            raise ValueError(f"Invalid chartType: {config['chartType']}")
        
        if "chartConfig" not in config:
            raise ValueError("Missing chartConfig")
        
        return config
    
    def _transform_data(self, data: List[Dict]) -> List[Dict]:
        """Format data for Recharts"""
        
        if not data:
            return []
        
        df = pd.DataFrame(data)
        
        # Format dates
        if 'date' in df.columns:
            df['date'] = pd.to_datetime(df['date']).dt.strftime('%b %d')
        
        # Round numbers
        numeric_cols = df.select_dtypes(include=['float64', 'float32']).columns
        for col in numeric_cols:
            df[col] = df[col].round(2)
        
        # Handle nulls
        df = df.fillna(0)
        
        return df.to_dict('records')


# Usage in API endpoint
preparer = ChartPreparer()

chart_package = preparer.prepare_chart(
    llm_config=config_from_gpt4,
    bigquery_data=data_from_bigquery
)
```

---

## Step 4C: Return to Frontend

### What Happens

```
┌─────────────────────────────────────────────────────────────┐
│              STEP 4C: RETURN TO FRONTEND                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Backend API sends HTTP response                            │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ HTTP/1.1 200 OK                                        │ │
│  │ Content-Type: application/json                         │ │
│  │                                                         │ │
│  │ {                                                       │ │
│  │   "chartType": "LineChart",                            │ │
│  │   "config": { ... },                                   │ │
│  │   "data": [ ... ],                                     │ │
│  │   "metadata": { ... }                                  │ │
│  │ }                                                       │ │
│  └────────────────────────────────────────────────────────┘ │
│                          ↓                                   │
│  Frontend receives and renders                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ React Component:                                        │ │
│  │                                                         │ │
│  │ const { chartType, config, data } = response;          │ │
│  │                                                         │ │
│  │ return (                                                │ │
│  │   <LineChart data={data}>                              │ │
│  │     <XAxis dataKey={config.xAxis.dataKey} />          │ │
│  │     <Line dataKey={config.lines[0].dataKey} />        │ │
│  │   </LineChart>                                         │ │
│  │ )                                                       │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Tools Used

**1. FastAPI Response Models**

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

# Allow frontend to call backend (CORS)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],  # Your frontend URL
    allow_methods=["POST"],
    allow_headers=["*"],
)

@app.post("/api/chart/generate")
async def generate_chart(request: ChartRequest):
    """
    Step 4C: Return chart to frontend
    """
    
    # ... Steps 4A and 4B happen here ...
    
    return {
        "chartType": "LineChart",
        "config": chart_config,
        "data": chart_data,
        "metadata": {
            "generatedAt": datetime.utcnow().isoformat(),
            "processingTime": "2.3s"
        }
    }
```

**2. Error Handling**

```python
from fastapi import HTTPException

@app.post("/api/chart/generate")
async def generate_chart(request: ChartRequest):
    try:
        # Steps 4A, 4B
        data = executor.execute_query(...)
        chart = preparer.prepare_chart(...)
        
        return chart
        
    except ValueError as e:
        # Invalid input
        raise HTTPException(status_code=400, detail=str(e))
        
    except Exception as e:
        # Server error
        raise HTTPException(status_code=500, detail="Chart generation failed")
```

**3. Response Caching (Optional)**

```python
from functools import lru_cache
import hashlib

class ChartCache:
    """Cache chart responses to save costs"""
    
    def __init__(self):
        self.cache = {}
    
    def get_cache_key(self, query: str, customer_id: str) -> str:
        """Generate cache key"""
        combined = f"{query}:{customer_id}"
        return hashlib.md5(combined.encode()).hexdigest()
    
    def get(self, key: str):
        """Get from cache"""
        return self.cache.get(key)
    
    def set(self, key: str, value: dict, ttl: int = 300):
        """Cache for 5 minutes"""
        self.cache[key] = {
            "value": value,
            "expires_at": datetime.utcnow() + timedelta(seconds=ttl)
        }

# Usage
cache = ChartCache()

@app.post("/api/chart/generate")
async def generate_chart(request: ChartRequest):
    # Check cache
    cache_key = cache.get_cache_key(request.query, request.customer_id)
    cached = cache.get(cache_key)
    
    if cached:
        return cached["value"]
    
    # Generate chart (Steps 4A, 4B)
    chart = ...
    
    # Cache result
    cache.set(cache_key, chart)
    
    return chart
```

---

## Technology Stack

### Complete Backend Stack

```
┌─────────────────────────────────────────────────────────────┐
│                    BACKEND TECHNOLOGY STACK                  │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Web Framework (Choose One):                                │
│  ├─ FastAPI (Python) ⭐ Recommended                        │
│  ├─ Express.js (Node.js)                                   │
│  └─ Next.js API Routes (TypeScript) - Simplest            │
│                                                              │
│  LLM Integration:                                           │
│  ├─ OpenAI Python SDK (pip install openai)                │
│  ├─ Google Generative AI (pip install google-generativeai)│
│  └─ Anthropic SDK (if using Claude)                       │
│                                                              │
│  Database Access:                                           │
│  ├─ google-cloud-bigquery (Python)                        │
│  ├─ @google-cloud/bigquery (Node.js)                      │
│  └─ Connection pooling for performance                     │
│                                                              │
│  Data Processing:                                           │
│  ├─ Pandas (Python) - Data transformation                 │
│  ├─ Pydantic (Python) - Validation                        │
│  └─ lodash (Node.js) - Data manipulation                  │
│                                                              │
│  Security:                                                  │
│  ├─ python-dotenv - Environment variables                 │
│  ├─ CORS middleware - Frontend access                     │
│  └─ SQL validation - Prevent injection                     │
│                                                              │
│  Deployment:                                                │
│  ├─ Google Cloud Run - Serverless                         │
│  ├─ Vercel - For Next.js                                  │
│  └─ AWS Lambda - Serverless alternative                    │
└─────────────────────────────────────────────────────────────┘
```

### Installation Commands

**Python Backend (FastAPI):**
```bash
pip install fastapi uvicorn
pip install google-cloud-bigquery
pip install openai google-generativeai
pip install pandas pydantic
pip install python-dotenv
```

**Node.js Backend (Express.js):**
```bash
npm install express cors
npm install @google-cloud/bigquery
npm install openai @google/generative-ai
npm install dotenv
```

**Next.js (API Routes):**
```bash
npx create-next-app@latest my-app
npm install @google-cloud/bigquery
npm install openai
```

---

## Complete Implementation

### Full Backend API (FastAPI Example)

```python
# backend/main.py

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Literal
from openai import OpenAI
from google.cloud import bigquery
import os

# Initialize
app = FastAPI()
openai_client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
bq_client = bigquery.Client()

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_methods=["POST"],
    allow_headers=["*"],
)

# Request/Response Models
class ChartRequest(BaseModel):
    query: str
    customer_id: str

class ChartResponse(BaseModel):
    chartType: Literal["LineChart", "BarChart", "PieChart", "AreaChart"]
    config: dict
    data: list
    metadata: dict


@app.post("/api/chart/generate", response_model=ChartResponse)
async def generate_chart(request: ChartRequest):
    """
    Complete backend processing:
    - Call LLM (Step 2)
    - Execute SQL (Step 4A)
    - Prepare chart (Step 4B)
    - Return to frontend (Step 4C)
    """
    
    try:
        # ====== STEP 2: LLM generates config ======
        llm_response = openai_client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {
                    "role": "system",
                    "content": """Generate Recharts config JSON.
                    Available columns: date, cloud_provider, model, cost_usd, usage_amount
                    Return JSON only."""
                },
                {
                    "role": "user",
                    "content": f"Generate chart for: {request.query}"
                }
            ],
            response_format={"type": "json_object"}
        )
        
        import json
        llm_config = json.loads(llm_response.choices[0].message.content)
        
        # ====== STEP 4A: Execute SQL on BigQuery ======
        sql = llm_config["sqlQuery"]
        
        # Add customer filter (CRITICAL!)
        safe_sql = sql.replace(
            "FROM unified_costs",
            f"FROM unified_costs WHERE customer_id = '{request.customer_id}'"
        )
        
        # Execute
        query_job = bq_client.query(safe_sql)
        results = query_job.result()
        data = [dict(row) for row in results]
        
        # ====== STEP 4B: Prepare chart ======
        # Transform data (format dates, round numbers)
        import pandas as pd
        df = pd.DataFrame(data)
        if 'date' in df.columns:
            df['date'] = pd.to_datetime(df['date']).dt.strftime('%Y-%m-%d')
        numeric_cols = df.select_dtypes(include=['float64']).columns
        df[numeric_cols] = df[numeric_cols].round(2)
        transformed_data = df.to_dict('records')
        
        # ====== STEP 4C: Return to frontend ======
        return ChartResponse(
            chartType=llm_config["chartType"],
            config=llm_config["chartConfig"],
            data=transformed_data,
            metadata={
                "title": llm_config.get("title", "Chart"),
                "generatedAt": "2026-02-06T10:30:00Z",
                "dataPoints": len(transformed_data)
            }
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# Run server
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

### Deploy Backend

```bash
# Local development
uvicorn main:app --reload

# Production (Google Cloud Run)
gcloud run deploy chart-backend \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

---

## Summary

### Backend Processing Flow

```
User Query
    ↓
Backend API Endpoint (/api/chart/generate)
    ↓
┌─────────────────────────────────────────┐
│ STEP 4A: Execute SQL on BigQuery       │
│ Tool: google-cloud-bigquery             │
│ Action: Query database, get rows       │
└─────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────┐
│ STEP 4B: Prepare Chart Component       │
│ Tools: Pandas, Pydantic                 │
│ Action: Transform data, validate config │
└─────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────┐
│ STEP 4C: Return to Frontend            │
│ Tool: FastAPI response                  │
│ Action: Send JSON to React              │
└─────────────────────────────────────────┘
    ↓
Frontend renders chart with Recharts
```

### Key Technologies

| Step | Tool | Purpose |
|------|------|---------|
| **Framework** | FastAPI / Express.js | HTTP server |
| **LLM** | OpenAI SDK / Gemini SDK | Generate configs |
| **Database** | google-cloud-bigquery | Execute SQL |
| **Validation** | Pydantic | Ensure safe data |
| **Transform** | Pandas | Format data |
| **Deploy** | Cloud Run / Vercel | Host backend |

### Total Cost

**Infrastructure:**
- Cloud Run: $5-15/month (scales to zero)
- BigQuery: Already covered ($3.50/month)

**APIs:**
- OpenAI: $0.005 per chart
- Gemini: $0.002 per chart

**Total:** $5-20/month infrastructure + API usage

---

**Document End**
