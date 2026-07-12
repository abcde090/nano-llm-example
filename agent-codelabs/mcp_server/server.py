"""Track 4 — an MCP server that streams context to models (goo.gle/4fcZ3QE).

A minimal Model Context Protocol server built with the official Python SDK's
FastMCP API, exposing a tiny internal knowledge base as MCP *tools* and a
*resource*. Runs over the streamable-HTTP transport so any MCP client — the
ADK agent in agents/context_agent, Claude, an IDE — can connect to
http://localhost:8765/mcp and pull context on demand.

Run:  python mcp_server/server.py
"""

import json
import pathlib

from mcp.server.fastmcp import FastMCP

KB_PATH = pathlib.Path(__file__).parent / "knowledge_base.json"
KB = json.loads(KB_PATH.read_text())

mcp = FastMCP("context-server", host="127.0.0.1", port=8765, stateless_http=True)


@mcp.tool()
def search_knowledge_base(query: str) -> list[dict]:
    """Search internal knowledge-base articles by keyword.

    Args:
        query: Free-text keywords, e.g. "returns policy".

    Returns:
        Up to 3 matching articles with slug, title and summary.
    """
    words = {w for w in query.lower().split() if len(w) > 2}
    scored = []
    for article in KB["articles"]:
        haystack = f"{article['title']} {article['body']}".lower()
        score = sum(1 for w in words if w in haystack)
        if score:
            scored.append((score, article))
    scored.sort(key=lambda pair: pair[0], reverse=True)
    return [
        {"slug": a["slug"], "title": a["title"], "summary": a["body"][:200]}
        for _, a in scored[:3]
    ]


@mcp.tool()
def get_article(slug: str) -> dict:
    """Fetch the full text of a knowledge-base article by its slug.

    Args:
        slug: Article slug returned by search_knowledge_base.

    Returns:
        The full article, or an error message for unknown slugs.
    """
    for article in KB["articles"]:
        if article["slug"] == slug:
            return article
    return {"error": f"no article with slug '{slug}'"}


@mcp.resource("kb://glossary")
def glossary() -> str:
    """Company glossary as a readable MCP resource."""
    lines = [f"- **{term}**: {definition}" for term, definition in KB["glossary"].items()]
    return "\n".join(lines)


if __name__ == "__main__":
    mcp.run(transport="streamable-http")
