FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY nano_team ./nano_team

EXPOSE 8000

# REST API over the agents in /app (POST /run, session endpoints, /list-apps).
# Swap for ["adk", "web", ...] if you want the dev UI in-cluster instead.
CMD ["adk", "api_server", "--host", "0.0.0.0", "--port", "8000"]
