"""Track 2 — a web frontend for ADK agents (goo.gle/4h5hEQX).

The codelab vibecodes this with Antigravity; here it is as reviewable code: a
small FastAPI bridge that serves a chat page and proxies to the ADK API
server's session + run endpoints, so any agent in agents/ gets a browser
front door.

Run the agents API first:   cd agents && adk api_server        # :8000
Then the frontend:          uvicorn app:app --app-dir frontend --port 3000
"""

import os
import uuid

import httpx
from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

ADK_API = os.environ.get("ADK_API_URL", "http://127.0.0.1:8000")
USER_ID = "webui"
STATIC_DIR = os.path.join(os.path.dirname(__file__), "static")

app = FastAPI(title="agent-codelabs frontend")


class ChatRequest(BaseModel):
    app_name: str
    message: str
    session_id: str | None = None


@app.get("/")
def index() -> FileResponse:
    return FileResponse(os.path.join(STATIC_DIR, "index.html"))


@app.get("/api/apps")
async def list_apps() -> list[str]:
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.get(f"{ADK_API}/list-apps")
        resp.raise_for_status()
        return resp.json()


@app.post("/api/chat")
async def chat(req: ChatRequest) -> dict:
    session_id = req.session_id or uuid.uuid4().hex
    async with httpx.AsyncClient(timeout=300) as client:
        if not req.session_id:
            resp = await client.post(
                f"{ADK_API}/apps/{req.app_name}/users/{USER_ID}/sessions/{session_id}",
                json={},
            )
            if resp.status_code not in (200, 409):  # 409 = already exists
                resp.raise_for_status()

        resp = await client.post(
            f"{ADK_API}/run",
            json={
                "app_name": req.app_name,
                "user_id": USER_ID,
                "session_id": session_id,
                "new_message": {"role": "user", "parts": [{"text": req.message}]},
            },
        )
        resp.raise_for_status()
        events = resp.json()

    # Collect the model's final text plus a trace of tool activity.
    reply_parts: list[str] = []
    tool_calls: list[str] = []
    for event in events:
        for part in (event.get("content") or {}).get("parts") or []:
            if part.get("text"):
                reply_parts = [part["text"]]  # keep the latest text
            if part.get("functionCall"):
                tool_calls.append(part["functionCall"].get("name", "?"))

    return {
        "session_id": session_id,
        "reply": "\n".join(reply_parts) or "(no text reply)",
        "tool_calls": tool_calls,
    }


app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
