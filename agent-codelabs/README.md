# agent-codelabs

Hands-on rebuild of the five AI-agent codelabs from Google's developer track —
from a first ADK agent to a production-style agent that queries BigQuery and
Google Maps through MCP servers.

| # | Track (codelab) | Rebuilt as |
|---|---|---|
| 1 | [Build your first agent with ADK](https://codelabs.developers.google.com/your-first-agent-with-adk) ([goo.gle/4ftubfR](https://goo.gle/4ftubfR)) | `agents/first_agent` — one agent, one live-weather function tool |
| 2 | [Vibecode a frontend for an ADK agent](https://codelabs.developers.google.com/vibecode-frontend-with-antigravity) ([goo.gle/4h5hEQX](https://goo.gle/4h5hEQX)) | `frontend/` — FastAPI bridge + chat web UI over the ADK API server |
| 3 | [Connect agents to external tools & APIs](https://codelabs.developers.google.com/multi-tools-ai-agent-adk) ([goo.gle/3RxsHIp](https://goo.gle/3RxsHIp)) | `agents/multi_tool_agent` — geocoding, forecasts, currency, time |
| 4 | [Set up MCP servers to stream context](https://codelabs.developers.google.com/mcp-toolbox-bigquery-dataset) ([goo.gle/4fcZ3QE](https://goo.gle/4fcZ3QE)) | `mcp_server/` (streamable-HTTP FastMCP server) + `agents/context_agent` (MCP client) |
| 5 | [Location Intelligence agent: BigQuery + Maps via MCP](https://codelabs.developers.google.com/adk-mcp-bigquery-maps) ([goo.gle/4wzoi6D](https://goo.gle/4wzoi6D)) | `agents/location_intel` + `toolbox/tools.yaml` (MCP Toolbox) + Maps MCP server |

The codelabs use **Gemini** as the model (`gemini-2.5-flash` by default here,
via `ADK_MODEL`). Track 2's codelab uses Antigravity (Google's agentic IDE) to
generate the frontend; the equivalent app is committed here as reviewable code.

## Setup

```bash
cd agent-codelabs
pip install -r requirements.txt
cp .env.example agents/.env     # add your GOOGLE_API_KEY (AI Studio) or Vertex settings
```

## Track 1 & 3 — agents with function tools

```bash
make web        # ADK dev UI on http://localhost:8000
```

Pick `first_agent` ("what's the weather in Sydney?") or `multi_tool_agent`
("5-day forecast for Tokyo, and what's 100 USD in AUD?") and watch the tool
calls in the Events tab.

## Track 4 — MCP server + agent that uses it

```bash
make mcp        # terminal 1: MCP server on http://127.0.0.1:8765/mcp
make web        # terminal 2: pick context_agent
```

Ask "can I return a sale item?" — the agent calls `search_knowledge_base` /
`get_article` on the MCP server and answers grounded in the returned context.
Any MCP client (Claude Desktop, an IDE) can connect to the same endpoint.

## Track 2 — web frontend

```bash
make api        # terminal 1: headless ADK API on :8000
make frontend   # terminal 2: chat UI on http://localhost:3000
```

The frontend lists every agent in `agents/`, keeps a session per conversation,
and shows which tools each reply used.

## Track 5 — Location Intelligence (BigQuery + Maps via MCP)

Prereqs: `gcloud auth application-default login`, a billing project for
BigQuery, Node.js (for the Maps MCP server), a Maps Platform API key, and the
[MCP Toolbox binary](https://googleapis.github.io/genai-toolbox/).

```bash
export BIGQUERY_PROJECT=my-gcp-project GOOGLE_MAPS_API_KEY=...
make toolbox    # terminal 1: Toolbox MCP endpoint on :5000/mcp
make web        # terminal 2: pick location_intel
```

Try the codelab scenario: *"Find a promising area in Los Angeles for a
high-end bakery — check what public demographic data is available, query it,
and validate the top candidates against nearby competition."* The agent
explores datasets via Toolbox's BigQuery tools and cross-checks places with
the Maps MCP server.

## Layout

```
agents/               # ADK agent packages (adk web / adk api_server root)
  first_agent/        #   track 1
  multi_tool_agent/   #   track 3
  context_agent/      #   track 4 (MCP client)
  location_intel/     #   track 5 (BigQuery + Maps via MCP)
mcp_server/           # track 4: FastMCP streamable-HTTP context server
frontend/             # track 2: FastAPI + static chat UI
toolbox/tools.yaml    # track 5: MCP Toolbox for Databases config
```
