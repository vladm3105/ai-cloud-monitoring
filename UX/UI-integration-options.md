# UI Integration Options: Grafana + AI Chat
## Three Ways to Combine Them

**Question:** Are Grafana and AI Chat separate widgets, or can they be integrated into one?

**Answer:** You have **three options** - choose based on your product strategy.

---

## Option 1: Separate Interfaces (Most Common)

### Architecture
```
┌─────────────────────────────────────────────────────────────┐
│  Your Application                                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Navigation Tabs:                                           │
│  ┌──────────┬──────────┬──────────┬──────────┬──────────┐  │
│  │Overview  │ Dashboards│ AI Chat  │ Settings │ Help    │  │
│  └──────────┴──────────┴──────────┴──────────┴──────────┘  │
│                                                              │
│  When user clicks "Dashboards":                             │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Embedded Grafana (Full Width)                         │ │
│  │  [Grafana dashboard takes entire content area]         │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  When user clicks "AI Chat":                                │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  AI Chat Interface (Full Width)                        │ │
│  │  [Conversational interface takes entire content area]  │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Pros
✅ Clean separation of concerns  
✅ Grafana gets full screen space for complex dashboards  
✅ AI chat gets full attention when user needs it  
✅ Easier to implement (no integration complexity)  
✅ Users choose their workflow  

### Cons
❌ Users have to switch between tabs  
❌ Less "magic" - feels like two separate tools  

### When to Use
- When Grafana dashboards are complex and need space
- When users will spend extended time in either interface
- When you want clear separation (analysts use Grafana, business users use chat)
- **Recommended for enterprise customers**

---

## Option 2: Side-by-Side Split View (Hybrid)

### Architecture
```
┌─────────────────────────────────────────────────────────────┐
│  Your Application                          [Toggle Layout] │
├─────────────────────────────────────────────────────────────┤
│                                    │                         │
│  Grafana Dashboard (70%)           │  AI Chat (30%)         │
│                                    │                         │
│  ┌──────────────────────────────┐ │ 💬 Ask about costs    │
│  │                              │ │ ───────────────────── │
│  │  [Cost Overview Dashboard]   │ │ You:                  │
│  │                              │ │ "Why did costs spike  │
│  │  [Charts and Graphs]         │ │  yesterday?"          │
│  │                              │ │                        │
│  │  [Tables]                    │ │ AI:                   │
│  │                              │ │ "GPT-4 usage increased│
│  │                              │ │  by 300% due to batch │
│  │                              │ │  processing job..."   │
│  └──────────────────────────────┘ │                        │
│                                    │ [Link to dashboard →] │
│                                    │                        │
│                                    │ ───────────────────── │
│                                    │ Type question... [→]  │
└────────────────────────────────────┴─────────────────────────┘
```

### Pros
✅ Best of both worlds - visual + conversational  
✅ Quick questions without leaving dashboard  
✅ AI can reference what's on screen  
✅ Users stay in one place  
✅ Chat can link to specific dashboard panels  

### Cons
❌ Less screen space for Grafana  
❌ Mobile experience is poor (need to stack)  
❌ More complex to implement  

### When to Use
- When users frequently switch between viewing data and asking questions
- Desktop-focused application
- Power users who want both at once
- **Recommended for SaaS product**

### Implementation Example

```typescript
// App.tsx
import { useState } from 'react';

export default function CostMonitoringApp() {
  const [layout, setLayout] = useState<'split' | 'grafana-only' | 'chat-only'>('split');
  
  return (
    <div className="app-container">
      {/* Header */}
      <header>
        <h1>AI Cost Monitoring</h1>
        <div className="layout-toggle">
          <button onClick={() => setLayout('grafana-only')}>📊 Dashboard Only</button>
          <button onClick={() => setLayout('split')}>📊💬 Split View</button>
          <button onClick={() => setLayout('chat-only')}>💬 Chat Only</button>
        </div>
      </header>
      
      {/* Content */}
      <div className={`content-area layout-${layout}`}>
        {/* Grafana */}
        {(layout === 'split' || layout === 'grafana-only') && (
          <div className={layout === 'split' ? 'w-70' : 'w-100'}>
            <iframe
              src="https://your-grafana.com/d/dashboard-id"
              width="100%"
              height="100%"
            />
          </div>
        )}
        
        {/* AI Chat */}
        {(layout === 'split' || layout === 'chat-only') && (
          <div className={layout === 'split' ? 'w-30' : 'w-100'}>
            <AIChatWidget 
              canLinkToDashboard={layout === 'split'}
              currentDashboard="cost-overview"
            />
          </div>
        )}
      </div>
    </div>
  );
}
```

---

## Option 3: Embedded Chat in Grafana (Tight Integration)

### Architecture
```
┌─────────────────────────────────────────────────────────────┐
│  Grafana Dashboard (Your Custom Theme)                      │
├─────────────────────────────────────────────────────────────┤
│  Filters: [Cloud ▼] [Model ▼] [Time Range ▼]              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Panel 1: Total Cost                                  │  │
│  │  $47,234 this month                                   │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────┐  ┌──────────────────────────┐  │
│  │  Panel 2: Cost Trend   │  │  Panel 3: Top Models     │  │
│  │  [Line Chart]          │  │  [Bar Chart]             │  │
│  └────────────────────────┘  └──────────────────────────┘  │
│                                                              │
│                                              ┌─────────────┐│
│                                              │ 💬 Ask AI   ││
│                                              │ ─────────── ││
│  [More Panels Below]                         │ Question?   ││
│                                              │             ││
│                                              │ [Chat UI]   ││
│                                              │             ││
│                                              └─────────────┘│
└─────────────────────────────────────────────────────────────┘
                                               ↑
                                    Floating Chat Widget
                                    (Collapses when not in use)
```

### Pros
✅ Minimal context switching  
✅ Chat feels like native Grafana feature  
✅ Can ask questions about visible data  
✅ Floating widget doesn't block dashboard  

### Cons
❌ Requires Grafana customization (plugin or app)  
❌ Chat has limited screen space  
❌ More complex integration  

### When to Use
- When Grafana is your primary interface
- Users are Grafana power users
- You want seamless experience
- **Recommended for technical/DevOps teams**

### Implementation (Grafana App Plugin)

```typescript
// Grafana App Plugin: module.ts
import { AppPlugin } from '@grafana/data';
import { AIChatComponent } from './components/AIChat';

export const plugin = new AppPlugin()
  .setRootPage(AIChatComponent)
  .addConfigPage({
    title: 'AI Chat Settings',
    icon: 'comments-alt',
    body: ConfigComponent,
    id: 'ai-chat-config',
  });

// components/AIChat.tsx
import React, { useState } from 'react';
import { useGrafana } from '@grafana/runtime';

export function AIChatComponent() {
  const { dashboard } = useGrafana();
  const [isOpen, setIsOpen] = useState(false);
  
  return (
    <>
      {/* Floating Button */}
      {!isOpen && (
        <button 
          className="ai-chat-trigger"
          onClick={() => setIsOpen(true)}
        >
          💬 Ask AI
        </button>
      )}
      
      {/* Chat Panel */}
      {isOpen && (
        <div className="ai-chat-panel">
          <div className="chat-header">
            <span>AI Cost Assistant</span>
            <button onClick={() => setIsOpen(false)}>✕</button>
          </div>
          
          <div className="chat-messages">
            {/* Messages */}
          </div>
          
          <div className="chat-input">
            <input 
              placeholder={`Ask about "${dashboard.title}"...`}
              onSubmit={handleQuestion}
            />
          </div>
          
          {/* Context-aware suggestions based on current dashboard */}
          <div className="quick-questions">
            <button>Explain this spike</button>
            <button>Top cost driver</button>
            <button>Compare to last week</button>
          </div>
        </div>
      )}
    </>
  );
}
```

---

## Comparison Table

| Feature | Separate Tabs | Split View | Embedded in Grafana |
|---------|---------------|------------|---------------------|
| **Screen Space** | Full for each | 70/30 split | Dashboard primary |
| **Context Switching** | High | Low | Minimal |
| **Implementation** | Easy | Medium | Hard |
| **Grafana Integration** | None | External iframe | Native plugin |
| **Mobile Experience** | Good | Poor | Medium |
| **Best For** | Enterprise | SaaS product | DevOps teams |
| **Development Time** | 1 week | 2-3 weeks | 4-6 weeks |

---

## Recommended Strategy

### Phase 1: Separate Tabs (Start Here)
```
┌──────────┬──────────┬──────────┐
│Dashboards│ AI Chat  │ Settings │
└──────────┴──────────┴──────────┘

Why:
• Fastest to implement
• Test both features independently
• Get user feedback
• Learn usage patterns
```

**Implementation:**
```typescript
// Simple routing
<Routes>
  <Route path="/dashboards" element={<GrafanaEmbed />} />
  <Route path="/chat" element={<AIChatWidget />} />
</Routes>
```

**Timeline:** 1 week  
**Cost:** No extra cost  

---

### Phase 2: Add Split View (After User Feedback)
```
[Toggle: Tabs | Split View]

If users say:
• "I keep switching between dashboard and chat"
• "Can I see both at once?"
• "I want to ask about what I'm seeing"

→ Add split view option
```

**Implementation:**
```typescript
// Add layout toggle
const [viewMode, setViewMode] = useState('tabs');

{viewMode === 'split' ? (
  <SplitView grafana={<GrafanaEmbed />} chat={<AIChatWidget />} />
) : (
  <TabbedView />
)}
```

**Timeline:** 2 weeks  
**Cost:** No extra cost  

---

### Phase 3: Grafana Plugin (Optional - Advanced)
```
Only if:
• Majority of users live in Grafana
• They request tighter integration
• You have Grafana expertise
```

**Timeline:** 4-6 weeks  
**Cost:** Higher development cost  

---

## Real-World Examples

### Example 1: Datadog (Separate Tabs)
```
Navigation:
├─ Dashboards (visual analytics)
├─ Monitors (alerts)
├─ Logs (search)
└─ AI Assistant (chat - separate tool)

Why: Each tool is complex enough to need full screen
```

### Example 2: Tableau (Embedded Chat)
```
Dashboard with "Ask Data" button
→ Opens chat overlay
→ Chat understands current visualization
→ Can modify dashboard based on questions

Why: Tight integration with data visualization
```

### Example 3: Your Product (Recommended: Hybrid)
```
Start: Separate tabs
↓
Add: Split view toggle
↓
Later: Maybe Grafana plugin if users demand it
```

---

## Technical Implementation Guide

### Option A: Separate Tabs (Recommended Start)

```typescript
// app/layout.tsx
export default function Layout({ children }) {
  return (
    <div className="app">
      <Sidebar>
        <NavLink href="/overview">Overview</NavLink>
        <NavLink href="/dashboards">📊 Dashboards</NavLink>
        <NavLink href="/chat">💬 AI Chat</NavLink>
        <NavLink href="/settings">Settings</NavLink>
      </Sidebar>
      
      <main>{children}</main>
    </div>
  );
}

// app/dashboards/page.tsx
export default function DashboardsPage() {
  return (
    <iframe
      src={process.env.GRAFANA_URL}
      width="100%"
      height="100%"
      frameBorder="0"
    />
  );
}

// app/chat/page.tsx
export default function ChatPage() {
  return <AIChatWidget fullScreen />;
}
```

**Deployment:**
- Grafana: Separate subdomain (grafana.yourapp.com)
- Chat: Built into your Next.js app
- No integration needed

---

### Option B: Split View

```typescript
// components/SplitViewLayout.tsx
export function SplitViewLayout() {
  const [sizes, setSizes] = useState([70, 30]); // Grafana: 70%, Chat: 30%
  
  return (
    <SplitPane
      split="vertical"
      sizes={sizes}
      onChange={setSizes}
      minSize={[400, 300]}
    >
      {/* Left: Grafana */}
      <div className="grafana-pane">
        <iframe src={grafanaUrl} width="100%" height="100%" />
      </div>
      
      {/* Right: Chat */}
      <div className="chat-pane">
        <AIChatWidget 
          onDashboardLink={(panelId) => {
            // Highlight panel in Grafana
            window.postMessage({ 
              type: 'highlight-panel', 
              panelId 
            }, grafanaUrl);
          }}
        />
      </div>
    </SplitPane>
  );
}
```

**Deployment:**
- Need iframe communication between Grafana and chat
- Use postMessage API for cross-frame communication
- More complex but better UX

---

### Option C: Grafana Plugin

```typescript
// Grafana plugin structure
grafana-ai-chat-plugin/
├── src/
│   ├── module.ts              // Plugin entry
│   ├── components/
│   │   ├── ChatPanel.tsx      // Floating chat
│   │   └── ChatButton.tsx     // Trigger button
│   └── api/
│       └── chatClient.ts      // API to your backend
├── plugin.json                // Grafana plugin config
└── package.json

// src/components/ChatPanel.tsx
export function ChatPanel() {
  const context = useGrafanaContext(); // Get current dashboard
  
  return (
    <div className="chat-overlay">
      <ChatMessages />
      <ChatInput 
        context={{
          dashboard: context.dashboard.title,
          timeRange: context.timeRange,
          variables: context.variables
        }}
      />
    </div>
  );
}
```

**Deployment:**
- Build Grafana plugin
- Install in Grafana instance
- Most integrated, but complex

---

## My Recommendation

### For Your AI Cost Monitoring Platform:

**Start with Option 1 (Separate Tabs):**
- Week 1-2: Build Grafana dashboards
- Week 3: Add AI chat as separate tab
- Week 4: Launch to first customers
- Get feedback

**Evolve to Option 2 (Split View) if users want it:**
- After 10-20 customers
- If they say "I want both at once"
- Add toggle between tabs and split view
- 2 weeks additional development

**Skip Option 3 (Grafana Plugin) unless:**
- 100+ customers
- Strong demand for tight integration
- You have Grafana plugin expertise

---

## Summary

**Question:** One widget or two?

**Answer:** **Your choice!** Three options:

1. **Separate** - Two different screens (easiest, start here)
2. **Side-by-side** - Both visible at once (better UX, more complex)
3. **Embedded** - Chat inside Grafana (tightest integration, hardest)

**Recommended Path:**
```
Month 1-3: Separate tabs → Launch quickly
Month 4-6: Add split view → Better UX based on feedback
Month 7+: Maybe Grafana plugin → If users demand it
```

You don't have to choose permanently - **start simple, evolve based on user needs!**

---

**Document End**
