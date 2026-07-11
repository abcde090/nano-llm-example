#!/usr/bin/env bash
# End-to-end smoke test: port-forward the Ollama service and verify a real
# chat completion comes back through the OpenAI-compatible API.
set -euo pipefail

NS=nano-llm
PORT="${PORT:-11434}"
MODEL="${MODEL:-qwen2.5:0.5b}"

echo "==> port-forwarding svc/ollama to localhost:${PORT}"
kubectl -n "$NS" port-forward svc/ollama "${PORT}:11434" >/dev/null 2>&1 &
PF_PID=$!
trap 'kill "$PF_PID" 2>/dev/null || true' EXIT

echo "==> waiting for the API to answer"
for i in $(seq 1 30); do
  if curl -sf "http://localhost:${PORT}/api/tags" >/dev/null 2>&1; then
    break
  fi
  [ "$i" -eq 30 ] && { echo "ERROR: API never became reachable"; exit 1; }
  sleep 2
done

echo "==> requesting a completion from ${MODEL}"
RESP=$(curl -sf "http://localhost:${PORT}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d "{\"model\": \"${MODEL}\", \"messages\": [{\"role\": \"user\", \"content\": \"Reply with one short sentence: what are you?\"}], \"max_tokens\": 60}")

CONTENT=$(printf '%s' "$RESP" | python3 -c \
  'import json,sys; print(json.load(sys.stdin)["choices"][0]["message"]["content"])')

if [ -z "$CONTENT" ]; then
  echo "ERROR: empty completion. Full response:"
  printf '%s\n' "$RESP"
  exit 1
fi

echo "==> model replied: ${CONTENT}"
echo "SMOKE TEST PASSED"
