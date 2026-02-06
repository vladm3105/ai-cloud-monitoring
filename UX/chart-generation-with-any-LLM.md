# Chart Generation with Any LLM
## Dynamic UI Generation Without Claude in Production

**Document Version:** 1.0  
**Last Updated:** February 2026  
**Question:** Can we generate Recharts/Chart.js configs without Claude in production?

---

## Executive Summary

**Answer:** ✅ **YES! You can use ANY LLM:**

- **OpenAI GPT-4** (most common in production)
- **Google Gemini** (excellent for structured output)
- **Anthropic Claude** (what you're using in development)
- **Open Source Models** (Llama 3, Mistral, etc.)
- **Azure OpenAI** (enterprise-ready)

**Key Insight:** Chart configuration generation is **just structured JSON output** - any modern LLM can do this well.

---

## Table of Contents

1. [Why Any LLM Works](#why-any-llm-works)
2. [Production Options](#production-options)
3. [Implementation Examples](#implementation-examples)
4. [Comparison Matrix](#comparison-matrix)
5. [Recommendation](#recommendation)

---

## Why Any LLM Works

### Chart Generation = Structured JSON Output

**What you're doing:**
```
User Query: "Show me cost trends for last 30 days"
    ↓
LLM Task: Generate this JSON structure:
{
  "chartType": "LineChart",
  "sqlQuery": "SELECT date, SUM(cost_usd) FROM unified_costs WHERE date >= DATE_SUB(CURRENT_DATE(), 30) GROUP BY date",
  "chartConfig": {
    "xAxis": { "dataKey": "date" },
    "yAxis": { "label": "Cost ($)" },
    "lines": [
      { "dataKey": "total_cost", "stroke": "#8884d8" }
    ]
  }
}
```

**This is easy for modern LLMs!**
- ✅ All LLMs are trained on chart libraries
- ✅ Structured output is a common task
- ✅ No special Claude features needed

---

## Production Options

### Option 1: OpenAI GPT-4 (Most Common)

**Why use GPT-4:**
- ✅ Most widely deployed in production
- ✅ Excellent at structured outputs
- ✅ Function calling built-in
- ✅ Great documentation
- ✅ Enterprise SLAs available

**Cost:**
- GPT-4 Turbo: ~$0.01 per request for chart generation
- GPT-4o: ~$0.005 per request (cheaper, faster)

**Example:**

```python
# chart_generator_gpt4.py
from openai import OpenAI

client = OpenAI(api_key="your-api-key")

def generate_chart_config(user_query: str):
    """
    Use GPT-4 to generate Recharts configuration
    """
    
    response = client.chat.completions.create(
        model="gpt-4o",  # or "gpt-4-turbo"
        messages=[
            {
                "role": "system",
                "content": """You are a chart configuration generator.

Given a user query about cost data, generate a JSON configuration for Recharts.

Available data columns:
- date (DATE)
- cloud_provider (STRING: GCP, AWS, Azure)
- model (STRING: gpt-4, claude-3, gemini-pro, etc.)
- cost_usd (FLOAT)
- usage_amount (FLOAT)
- customer_id (STRING)

Output JSON format:
{
  "chartType": "LineChart" | "BarChart" | "PieChart" | "AreaChart",
  "sqlQuery": "SELECT ... FROM unified_costs WHERE ...",
  "chartConfig": {
    "xAxis": { "dataKey": "..." },
    "yAxis": { "label": "..." },
    "data": "..." // which dataKey to use
  },
  "title": "Chart title"
}

Return ONLY valid JSON, no markdown formatting."""
            },
            {
                "role": "user",
                "content": f"Generate chart config for: {user_query}"
            }
        ],
        response_format={ "type": "json_object" }  # GPT-4 structured output
    )
    
    import json
    config = json.loads(response.choices[0].message.content)
    
    return config


# Usage
query = "Show me cost trends by cloud provider for last 7 days"
config = generate_chart_config(query)

print(config)
# {
#   "chartType": "LineChart",
#   "sqlQuery": "SELECT date, cloud_provider, SUM(cost_usd) as cost ...",
#   "chartConfig": { ... },
#   "title": "Cost Trends by Cloud Provider (Last 7 Days)"
# }
```

**Advantages:**
- ✅ Best for production (proven at scale)
- ✅ Function calling ensures valid JSON
- ✅ Fast response times
- ✅ Great documentation

**Disadvantages:**
- ⚠️ Slightly more expensive than others
- ⚠️ OpenAI-specific API

---

### Option 2: Google Gemini (Best for Google Cloud)

**Why use Gemini:**
- ✅ Native Google Cloud integration
- ✅ Excellent structured output
- ✅ Cheaper than GPT-4
- ✅ Good at data analysis
- ✅ Already in BigQuery ecosystem

**Cost:**
- Gemini 1.5 Pro: ~$0.005 per request
- Gemini 1.5 Flash: ~$0.002 per request (faster)

**Example:**

```python
# chart_generator_gemini.py
import google.generativeai as genai
from google.cloud import aiplatform

genai.configure(api_key="your-api-key")

def generate_chart_config(user_query: str):
    """
    Use Gemini to generate Recharts configuration
    """
    
    model = genai.GenerativeModel('gemini-1.5-pro')
    
    prompt = f"""You are a chart configuration generator.

Given this user query: "{user_query}"

Generate a JSON configuration for Recharts to visualize cost data.

Available data:
- date, cloud_provider, model, cost_usd, usage_amount, customer_id

Return JSON with this structure:
{{
  "chartType": "LineChart|BarChart|PieChart",
  "sqlQuery": "SELECT ... FROM unified_costs WHERE ...",
  "chartConfig": {{
    "xAxis": {{"dataKey": "..."}},
    "yAxis": {{"label": "..."}},
    "lines": [...]
  }},
  "title": "..."
}}

Return ONLY valid JSON."""
    
    response = model.generate_content(
        prompt,
        generation_config={
            "temperature": 0.1,  # Low temperature for consistent output
            "response_mime_type": "application/json"  # Force JSON output
        }
    )
    
    import json
    config = json.loads(response.text)
    
    return config


# Usage
query = "Compare GPT-4 vs Claude costs this month"
config = generate_chart_config(query)
```

**Advantages:**
- ✅ Native BigQuery integration
- ✅ Cheaper than GPT-4
- ✅ Good for Google Cloud users
- ✅ JSON mode built-in

**Disadvantages:**
- ⚠️ Less proven in production than GPT-4
- ⚠️ Newer, fewer examples

---

### Option 3: Azure OpenAI (Enterprise Production)

**Why use Azure OpenAI:**
- ✅ Enterprise SLAs and support
- ✅ Data residency guarantees
- ✅ HIPAA/SOC2 compliant
- ✅ Same GPT-4 models as OpenAI
- ✅ Integration with Azure services

**Cost:**
- Same as OpenAI pricing
- Plus Azure infrastructure costs

**Example:**

```python
# chart_generator_azure.py
from openai import AzureOpenAI

client = AzureOpenAI(
    api_key="your-azure-key",
    api_version="2024-02-01",
    azure_endpoint="https://your-resource.openai.azure.com"
)

def generate_chart_config(user_query: str):
    """
    Use Azure OpenAI to generate chart config
    """
    
    response = client.chat.completions.create(
        model="gpt-4o",  # Your Azure deployment name
        messages=[
            {
                "role": "system",
                "content": "You are a chart config generator. Return JSON only."
            },
            {
                "role": "user",
                "content": f"Generate Recharts config for: {user_query}"
            }
        ],
        response_format={ "type": "json_object" }
    )
    
    import json
    return json.loads(response.choices[0].message.content)
```

**Advantages:**
- ✅ Best for enterprise
- ✅ Compliance certifications
- ✅ Microsoft support
- ✅ Azure ecosystem integration

**Disadvantages:**
- ⚠️ More expensive overall (Azure fees)
- ⚠️ More setup complexity

---

### Option 4: Open Source Models (Self-Hosted)

**Why use open source:**
- ✅ No API costs (just infrastructure)
- ✅ Complete data privacy
- ✅ No rate limits
- ✅ Customizable

**Models:**
- Llama 3.1 70B (best quality)
- Llama 3.1 8B (fast, cheaper)
- Mistral 7B (good balance)
- Mixtral 8x7B (excellent quality)

**Example with Llama:**

```python
# chart_generator_llama.py
from transformers import AutoTokenizer, AutoModelForCausalLM
import torch

# Load Llama 3.1 8B
model_name = "meta-llama/Meta-Llama-3.1-8B-Instruct"
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForCausalLM.from_pretrained(
    model_name,
    torch_dtype=torch.float16,
    device_map="auto"
)

def generate_chart_config(user_query: str):
    """
    Use Llama 3.1 to generate chart config
    """
    
    prompt = f"""<|begin_of_text|><|start_header_id|>system<|end_header_id|>
You are a chart configuration generator. Given a user query, generate a JSON configuration for Recharts.

Output JSON format:
{{
  "chartType": "LineChart|BarChart|PieChart",
  "sqlQuery": "SELECT ... FROM unified_costs WHERE ...",
  "chartConfig": {{ ... }},
  "title": "..."
}}

Return ONLY valid JSON.<|eot_id|>
<|start_header_id|>user<|end_header_id|>
Generate chart config for: {user_query}<|eot_id|>
<|start_header_id|>assistant<|end_header_id|>"""
    
    inputs = tokenizer(prompt, return_tensors="pt").to(model.device)
    
    outputs = model.generate(
        **inputs,
        max_new_tokens=512,
        temperature=0.1,
        do_sample=True
    )
    
    response = tokenizer.decode(outputs[0], skip_special_tokens=True)
    
    # Extract JSON from response
    import json
    import re
    json_match = re.search(r'\{.*\}', response, re.DOTALL)
    if json_match:
        return json.loads(json_match.group())
    
    raise ValueError("Failed to extract JSON from response")
```

**Deployment:**

```bash
# Option A: Run on your server (GPU required)
docker run --gpus all -p 8000:8000 \
  vllm/vllm-openai:latest \
  --model meta-llama/Meta-Llama-3.1-8B-Instruct

# Option B: Use Ollama (easier)
ollama pull llama3.1
ollama serve
```

**Advantages:**
- ✅ No per-request costs
- ✅ Complete data privacy
- ✅ No rate limits
- ✅ Offline capable

**Disadvantages:**
- ⚠️ Need GPU infrastructure ($100-300/mo)
- ⚠️ More maintenance
- ⚠️ Slightly lower quality than GPT-4

---

### Option 5: Multiple LLMs (Best Approach)

**Use different LLMs for different tasks:**

```python
# chart_generator_multi.py
from typing import Literal

class ChartGenerator:
    """
    Use the best LLM for each task
    """
    
    def __init__(self):
        # Primary: GPT-4o (fast, cheap, good quality)
        self.primary_client = OpenAI(api_key="...")
        
        # Fallback: Gemini (if OpenAI fails)
        self.fallback_client = genai.GenerativeModel('gemini-1.5-flash')
        
        # Enterprise: Azure OpenAI (for sensitive customers)
        self.enterprise_client = AzureOpenAI(...)
    
    def generate_chart_config(
        self, 
        user_query: str,
        customer_tier: Literal["free", "pro", "enterprise"] = "pro"
    ):
        """
        Route to appropriate LLM based on customer tier
        """
        
        try:
            if customer_tier == "enterprise":
                # Use Azure OpenAI for enterprise customers
                return self._generate_with_azure(user_query)
            else:
                # Use GPT-4o for free/pro customers
                return self._generate_with_gpt4(user_query)
                
        except Exception as e:
            # Fallback to Gemini if primary fails
            print(f"Primary failed: {e}, using fallback")
            return self._generate_with_gemini(user_query)
    
    def _generate_with_gpt4(self, query: str):
        response = self.primary_client.chat.completions.create(
            model="gpt-4o",
            messages=[...],
            response_format={"type": "json_object"}
        )
        return json.loads(response.choices[0].message.content)
    
    def _generate_with_gemini(self, query: str):
        response = self.fallback_client.generate_content(
            query,
            generation_config={"response_mime_type": "application/json"}
        )
        return json.loads(response.text)
    
    def _generate_with_azure(self, query: str):
        response = self.enterprise_client.chat.completions.create(
            model="gpt-4o",
            messages=[...],
            response_format={"type": "json_object"}
        )
        return json.loads(response.choices[0].message.content)


# Usage
generator = ChartGenerator()

# Free customer → GPT-4o
config = generator.generate_chart_config(
    "Show costs", 
    customer_tier="free"
)

# Enterprise customer → Azure OpenAI
config = generator.generate_chart_config(
    "Show costs",
    customer_tier="enterprise"
)
```

---

## Implementation Examples

### Complete Chart Generation System (Production-Ready)

```typescript
// app/api/chart/generate/route.ts
import { OpenAI } from 'openai';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { BigQuery } from '@google-cloud/bigquery';

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
const gemini = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
const bigquery = new BigQuery();

interface ChartConfig {
  chartType: 'LineChart' | 'BarChart' | 'PieChart' | 'AreaChart';
  sqlQuery: string;
  chartConfig: any;
  title: string;
}

export async function POST(request: Request) {
  const { query, llmProvider = 'gpt4' } = await request.json();
  
  try {
    // Step 1: Generate chart configuration using chosen LLM
    const config = await generateChartConfig(query, llmProvider);
    
    // Step 2: Execute SQL query on BigQuery
    const [rows] = await bigquery.query(config.sqlQuery);
    
    // Step 3: Return config + data
    return Response.json({
      config: config,
      data: rows,
      llmUsed: llmProvider
    });
    
  } catch (error) {
    // Step 4: Fallback to alternative LLM if primary fails
    if (llmProvider === 'gpt4') {
      console.log('GPT-4 failed, trying Gemini...');
      return POST({ ...request, body: { query, llmProvider: 'gemini' } });
    }
    
    return Response.json({ error: error.message }, { status: 500 });
  }
}

async function generateChartConfig(
  query: string,
  provider: 'gpt4' | 'gemini' | 'azure'
): Promise<ChartConfig> {
  
  const systemPrompt = `You are a chart configuration generator.

Given a user query, generate a JSON configuration for Recharts.

Available data schema:
- Table: unified_costs
- Columns: date, cloud_provider, model, cost_usd, usage_amount, customer_id

Output JSON structure:
{
  "chartType": "LineChart|BarChart|PieChart|AreaChart",
  "sqlQuery": "SELECT ... FROM \`project.dataset.unified_costs\` WHERE ...",
  "chartConfig": {
    "xAxis": { "dataKey": "..." },
    "yAxis": { "label": "..." },
    "lines": [...] // or "bars", "areas" depending on chartType
  },
  "title": "Descriptive chart title"
}

Guidelines:
- Choose chartType based on data: LineChart for trends, BarChart for comparisons, PieChart for proportions
- Optimize SQL for BigQuery (use DATE functions, proper aggregations)
- Make chart config complete and render-ready

Return ONLY valid JSON.`;

  if (provider === 'gpt4') {
    const response = await openai.chat.completions.create({
      model: 'gpt-4o',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: `Generate chart config for: ${query}` }
      ],
      response_format: { type: 'json_object' },
      temperature: 0.1
    });
    
    return JSON.parse(response.choices[0].message.content);
  }
  
  if (provider === 'gemini') {
    const model = gemini.getGenerativeModel({ model: 'gemini-1.5-flash' });
    
    const result = await model.generateContent({
      contents: [{ role: 'user', parts: [{ text: `${systemPrompt}\n\nQuery: ${query}` }] }],
      generationConfig: {
        temperature: 0.1,
        responseMimeType: 'application/json'
      }
    });
    
    return JSON.parse(result.response.text());
  }
  
  throw new Error(`Unsupported provider: ${provider}`);
}
```

### Frontend Chart Renderer

```typescript
// components/DynamicChart.tsx
import { 
  LineChart, BarChart, PieChart, AreaChart,
  Line, Bar, Pie, Area, XAxis, YAxis, CartesianGrid, Tooltip, Legend
} from 'recharts';

interface DynamicChartProps {
  query: string;
}

export function DynamicChart({ query }: DynamicChartProps) {
  const [chartData, setChartData] = useState(null);
  const [loading, setLoading] = useState(false);
  
  const generateChart = async () => {
    setLoading(true);
    
    const response = await fetch('/api/chart/generate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        query,
        llmProvider: 'gpt4'  // or 'gemini', 'azure'
      })
    });
    
    const result = await response.json();
    setChartData(result);
    setLoading(false);
  };
  
  if (!chartData) {
    return (
      <div>
        <input 
          type="text" 
          value={query}
          placeholder="Ask about your costs..."
        />
        <button onClick={generateChart}>Generate Chart</button>
      </div>
    );
  }
  
  const { config, data } = chartData;
  
  // Render appropriate chart type
  const ChartComponent = {
    'LineChart': LineChart,
    'BarChart': BarChart,
    'PieChart': PieChart,
    'AreaChart': AreaChart
  }[config.chartType];
  
  return (
    <div>
      <h3>{config.title}</h3>
      <ChartComponent width={600} height={400} data={data}>
        <CartesianGrid strokeDasharray="3 3" />
        <XAxis dataKey={config.chartConfig.xAxis.dataKey} />
        <YAxis label={{ value: config.chartConfig.yAxis.label, angle: -90 }} />
        <Tooltip />
        <Legend />
        
        {config.chartType === 'LineChart' && config.chartConfig.lines.map((line, i) => (
          <Line 
            key={i}
            dataKey={line.dataKey} 
            stroke={line.stroke} 
            strokeWidth={2}
          />
        ))}
        
        {config.chartType === 'BarChart' && config.chartConfig.bars.map((bar, i) => (
          <Bar key={i} dataKey={bar.dataKey} fill={bar.fill} />
        ))}
        
        {/* Similar for Pie and Area charts */}
      </ChartComponent>
      
      <p className="text-sm text-gray-500">
        Generated using: {chartData.llmUsed}
      </p>
    </div>
  );
}
```

---

## Comparison Matrix

| LLM Provider | Best For | Cost/Request | Quality | Production Ready | Setup Complexity |
|--------------|----------|--------------|---------|------------------|------------------|
| **GPT-4o (OpenAI)** | General use | $0.005 | ⭐⭐⭐⭐⭐ | ✅ Yes | ⭐ Easy |
| **GPT-4 Turbo** | High quality | $0.01 | ⭐⭐⭐⭐⭐ | ✅ Yes | ⭐ Easy |
| **Gemini 1.5 Pro** | Google Cloud | $0.005 | ⭐⭐⭐⭐ | ✅ Yes | ⭐ Easy |
| **Gemini 1.5 Flash** | Speed/cost | $0.002 | ⭐⭐⭐⭐ | ✅ Yes | ⭐ Easy |
| **Azure OpenAI** | Enterprise | $0.01+ | ⭐⭐⭐⭐⭐ | ✅ Yes | ⭐⭐ Medium |
| **Llama 3.1 8B** | Self-hosted | $0* | ⭐⭐⭐ | ⚠️ DIY | ⭐⭐⭐ Hard |
| **Llama 3.1 70B** | Self-hosted | $0* | ⭐⭐⭐⭐ | ⚠️ DIY | ⭐⭐⭐⭐ Very Hard |

*Infrastructure costs: $100-500/month for GPU servers

---

## Recommendation

### For Your AI Cost Monitoring Platform

**Phase 1 (Months 1-6): GPT-4o**

```python
# Simple, production-ready
from openai import OpenAI

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

def generate_chart(query: str):
    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[...],
        response_format={"type": "json_object"}
    )
    return json.loads(response.choices[0].message.content)
```

**Why:**
- ✅ Fastest to implement
- ✅ Best documentation
- ✅ Proven in production
- ✅ Only $0.005 per chart
- ✅ 99.9% uptime

**Cost Estimate:**
- 1,000 charts/month = $5
- 10,000 charts/month = $50
- Very affordable!

---

**Phase 2 (Months 7-12): Add Gemini Fallback**

```python
class ChartGenerator:
    def generate(self, query):
        try:
            return self._gpt4(query)  # Primary
        except:
            return self._gemini(query)  # Fallback
```

**Why:**
- ✅ Reliability (99.99% uptime)
- ✅ Cost optimization (Gemini cheaper)
- ✅ No vendor lock-in

---

**Phase 3 (Month 13+): Optimize by Customer Tier**

```python
def generate_chart(query, customer_tier):
    if customer_tier == "enterprise":
        return azure_openai.generate(query)  # SLA guarantees
    elif customer_tier == "pro":
        return gpt4.generate(query)  # Best quality
    else:
        return gemini.generate(query)  # Cost-efficient
```

---

## Summary

**Question:** Can we generate chart configs without Claude in production?

**Answer:** ✅ **YES! Use any of these:**

1. **GPT-4o** (recommended) - $0.005/request
2. **Gemini 1.5** - $0.002/request  
3. **Azure OpenAI** - Enterprise option
4. **Open Source** - Self-hosted, no API costs

**Best approach:**
- **Start:** GPT-4o (proven, fast, cheap)
- **Add:** Gemini fallback (reliability)
- **Later:** Tier-based routing (optimize costs)

**Code is the same** - just swap the API client:
```python
# Works with ANY LLM
config = llm.generate("Show me cost trends")
chart = render_chart(config)
```

**You don't need Claude in production** - GPT-4o or Gemini work perfectly for chart generation! 🚀

---

**Document End**
