---
name: smart
description: One-stop entry. Auto-routes any request to the right Yukti specialist — code changes go through the explore→plan→confirm→implement→review pipeline (Haiku/Opus/Sonnet/Opus); analysis questions are answered directly on Sonnet. Saves ~50-60% cost vs always-Opus on code work and answers questions roughly as fast as plain chat.
context: fork
agent: front-door
---

User request:

$ARGUMENTS

Follow your system prompt. Emit the required status line as your very first token, classify the request, and either route to the right subagent (smart-orchestrator / planner / reviewer / explorer) or answer directly. **Never refuse** — every request gets a useful response.
