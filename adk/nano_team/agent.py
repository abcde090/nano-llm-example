"""A small multi-agent team (Google ADK) backed by the self-hosted nano LLM.

The model is served by the Ollama deployment in this repo, which exposes an
OpenAI-compatible API — ADK reaches it through LiteLLM. Point OLLAMA_API_BASE
at the service:

  - locally:      http://localhost:11434/v1   (run `make chat` first)
  - in-cluster:   http://ollama:11434/v1      (k8s/adk.yaml sets this)

Note on model size: qwen2.5:0.5b understands tool/agent-transfer calls but is
tiny — routing works for simple, clearly phrased requests. For noticeably
better agent behaviour set NANO_LLM_MODEL=qwen2.5:1.5b (and seed that model
into the bucket / bump pod resources accordingly).
"""

import os

from google.adk.agents import Agent
from google.adk.models.lite_llm import LiteLlm

OLLAMA_API_BASE = os.environ.get("OLLAMA_API_BASE", "http://localhost:11434/v1")
MODEL_NAME = os.environ.get("NANO_LLM_MODEL", "qwen2.5:0.5b")


def nano_model() -> LiteLlm:
    # Each agent gets its own client instance; "openai/" tells LiteLLM to
    # speak the OpenAI protocol against our api_base. The key is unused but
    # required by the client.
    return LiteLlm(model=f"openai/{MODEL_NAME}", api_base=OLLAMA_API_BASE, api_key="unused")


def calculate(expression: str) -> str:
    """Evaluate a basic arithmetic expression, e.g. '2 * (3 + 4)'.

    Args:
        expression: arithmetic using digits and + - * / ( ) . % only.

    Returns:
        The numeric result as a string, or an error message.
    """
    allowed = set("0123456789+-*/(). %")
    if not expression or (set(expression) - allowed):
        return "error: only digits and + - * / ( ) . % are allowed"
    try:
        return str(eval(expression, {"__builtins__": {}}, {}))  # noqa: S307 - input is character-whitelisted
    except Exception as exc:
        return f"error: {exc}"


researcher = Agent(
    name="researcher",
    model=nano_model(),
    description="Answers factual questions concisely from general knowledge.",
    instruction=(
        "You are the research specialist. Answer the user's factual question "
        "in at most three short sentences. If you are unsure, say so plainly."
    ),
)

writer = Agent(
    name="writer",
    model=nano_model(),
    description="Drafts or rewrites short pieces of text (emails, summaries, blurbs).",
    instruction=(
        "You are the writing specialist. Produce the requested text directly, "
        "with no preamble. Keep it short and clear."
    ),
)

root_agent = Agent(
    name="coordinator",
    model=nano_model(),
    description="Front door: routes requests to the right specialist.",
    instruction=(
        "You coordinate a small team. Decide what the user needs:\n"
        "- factual question -> transfer to the researcher agent\n"
        "- writing or rewriting text -> transfer to the writer agent\n"
        "- arithmetic -> call the calculate tool\n"
        "- anything else -> answer briefly yourself.\n"
        "Never invent tool results."
    ),
    tools=[calculate],
    sub_agents=[researcher, writer],
)
