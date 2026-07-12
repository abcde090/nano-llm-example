# Run each codelab track. Install deps once:  make install
.PHONY: install web api mcp frontend toolbox

install:
	pip install -r requirements.txt

# ADK dev UI over every agent in agents/ (tracks 1, 3, 4, 5) — :8000
web:
	cd agents && adk web

# Headless agents API (needed by the frontend) — :8000
api:
	cd agents && adk api_server

# Track 4: the MCP context server — :8765/mcp
mcp:
	python mcp_server/server.py

# Track 2: browser chat frontend — :3000 (run `make api` first)
frontend:
	uvicorn app:app --app-dir frontend --port 3000

# Track 5: MCP Toolbox for Databases (install: googleapis.github.io/genai-toolbox)
toolbox:
	toolbox --tools-file toolbox/tools.yaml
