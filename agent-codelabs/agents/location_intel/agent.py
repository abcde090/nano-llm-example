"""Track 5 — production-style Location Intelligence agent (goo.gle/4wzoi6D).

Bridges enterprise data in BigQuery with real-world location context from
Google Maps, both via MCP:

  - BigQuery: MCP Toolbox for Databases (../..//toolbox/tools.yaml), a
    Google-maintained MCP server. Start it first:
        toolbox --tools-file toolbox/tools.yaml     # serves :5000/mcp
  - Google Maps: the reference MCP server, spawned on demand over stdio
    (needs Node + GOOGLE_MAPS_API_KEY).

The codelab scenario: find the optimal location for a new high-end bakery —
query customer/demographic data in BigQuery, then validate candidate areas
against Maps (geocoding, nearby competitors).
"""

import os

from google.adk.agents import Agent
from google.adk.tools.mcp_tool.mcp_session_manager import (
    StdioConnectionParams,
    StreamableHTTPConnectionParams,
)
from google.adk.tools.mcp_tool.mcp_toolset import MCPToolset
from mcp import StdioServerParameters

MODEL = os.environ.get("ADK_MODEL", "gemini-2.5-flash")
TOOLBOX_URL = os.environ.get("TOOLBOX_MCP_URL", "http://127.0.0.1:5000/mcp")

bigquery_tools = MCPToolset(
    connection_params=StreamableHTTPConnectionParams(url=TOOLBOX_URL),
)

maps_tools = MCPToolset(
    connection_params=StdioConnectionParams(
        server_params=StdioServerParameters(
            command="npx",
            args=["-y", "@modelcontextprotocol/server-google-maps"],
            env={"GOOGLE_MAPS_API_KEY": os.environ.get("GOOGLE_MAPS_API_KEY", "")},
        ),
    ),
)

root_agent = Agent(
    name="location_analyst",
    model=MODEL,
    description="Location-intelligence analyst combining BigQuery data with Google Maps.",
    instruction=(
        "You are a location intelligence analyst helping choose sites for "
        "new retail locations (e.g. a high-end bakery).\n"
        "Method:\n"
        "1. Explore what data exists: list BigQuery datasets/tables before "
        "querying; inspect table schemas with the table-info tool.\n"
        "2. Query BigQuery (standard SQL) for demographic or business data "
        "relevant to the question. Prefer aggregates; always LIMIT results.\n"
        "3. Use the Maps tools to geocode candidate areas and check nearby "
        "competitors or amenities.\n"
        "4. Recommend, with the evidence: cite the query results and Maps "
        "findings that support the recommendation.\n"
        "Never fabricate data — if a table or place lookup fails, say so."
    ),
    tools=[bigquery_tools, maps_tools],
)
