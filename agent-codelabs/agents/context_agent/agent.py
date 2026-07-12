"""Track 4 (client side) — an ADK agent that pulls context from an MCP server.

Pairs with mcp_server/server.py: start that first (python mcp_server/server.py),
then run this agent — MCPToolset connects over streamable HTTP, discovers the
server's tools, and exposes them to the model like any other tool.
"""

import os

from google.adk.agents import Agent
from google.adk.tools.mcp_tool.mcp_session_manager import StreamableHTTPConnectionParams
from google.adk.tools.mcp_tool.mcp_toolset import MCPToolset

MODEL = os.environ.get("ADK_MODEL", "gemini-2.5-flash")
MCP_URL = os.environ.get("CONTEXT_MCP_URL", "http://127.0.0.1:8765/mcp")

root_agent = Agent(
    name="support_agent",
    model=MODEL,
    description="Customer-support agent grounded in the company knowledge base.",
    instruction=(
        "You are a customer support agent. Ground every policy answer in the "
        "knowledge base: search_knowledge_base first, then get_article for "
        "the full text before answering. Quote the relevant policy briefly "
        "and cite the article title. If the knowledge base has no answer, "
        "say so — never invent policy."
    ),
    tools=[
        MCPToolset(
            connection_params=StreamableHTTPConnectionParams(url=MCP_URL),
        )
    ],
)
