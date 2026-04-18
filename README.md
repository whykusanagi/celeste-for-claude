<div align="center">

<img src="https://s3.whykusanagi.xyz/optimized_assets/hypnosis_expression_trans_ghub.png" alt="Celeste - Corrupted AI Assistant" width="250"/>

<sub>Character artwork by [いかわさ (ikawasa23)](https://x.com/ikawasa23)</sub>

# Celeste for Claude Code

**Graph-based code intelligence for Claude Code via MCP**

[![Requires Celeste CLI](https://img.shields.io/badge/requires-celeste--cli%20v1.9.0+-purple)](https://github.com/whykusanagi/celeste-cli)
[![MCP](https://img.shields.io/badge/transport-MCP%20stdio-00d4ff)](https://modelcontextprotocol.io)
[![License](https://img.shields.io/badge/License-MIT-purple)](LICENSE)

</div>

---

Give Claude Code access to [Celeste CLI](https://github.com/whykusanagi/celeste-cli)'s graph-based code intelligence — structural code review, semantic search, dependency analysis, and project context management that goes beyond grep and pattern matching.

**v1.9.0+:** Skills now use Celeste's **direct codegraph MCP tools** (`celeste_index`, `celeste_code_search`, `celeste_code_review`, `celeste_code_graph`, `celeste_code_symbols`) instead of routing through the chat persona. This means no LLM round-trip, no output truncation, and verbatim structured results.

## What You Get

Celeste brings capabilities Claude Code doesn't have natively:

| Capability | What it does | How it works |
|---|---|---|
| **Graph Code Review** | Detect stubs, lazy redirects, error swallowing, placeholders, hardcoded values | Structural analysis via code graph — not grep |
| **Semantic Code Search** | Find functions by concept, not just name | MinHash + BM25 fusion with structural rerank |
| **Dependency Analysis** | Map package connectivity, find isolated code | Cross-file edge resolution (tree-sitter for TS) |
| **Project Memory** | Persist learned context across sessions | Per-project memory store |
| **`.grimoire` Context** | Auto-detected project config with staleness tracking | Git-stamped metadata |

## Prerequisites

Install [Celeste CLI](https://github.com/whykusanagi/celeste-cli):

```bash
go install github.com/whykusanagi/celeste-cli/cmd/celeste@latest
```

Verify:
```bash
celeste version
celeste index status  # in any project directory
```

You'll need an API key configured for Celeste if you use the persona tools (xAI/Grok by default). The direct codegraph tools (`celeste_index`, `celeste_code_search`, etc.) do **not** require an API key — they run entirely locally against the cached graph.

```bash
# Only needed for persona tools (celeste-docs, save_memory, etc.)
celeste config --set-key YOUR_API_KEY
```

## Installation

### 1. Add the MCP Server

Add to your Claude Code MCP config (`~/.claude/claude_desktop_config.json` or via settings):

```json
{
  "mcpServers": {
    "celeste": {
      "command": "celeste",
      "args": ["serve"]
    }
  }
}
```

### 2. Install the Skills

Copy the skill files to your Claude Code commands directory:

```bash
# Clone this repo
git clone https://github.com/whykusanagi/celeste-for-claude.git

# Copy skills
cp celeste-for-claude/skills/*.md ~/.claude/commands/
```

Or install globally:
```bash
cp celeste-for-claude/skills/*.md ~/.claude/commands/
```

## Available Skills

### `/celeste-review` — Graph-Based Code Review

Runs Celeste's structural code review on the current project. Detects 6 categories of issues using the code graph (not grep):

- **STUB** — Functions with zero outgoing calls that aren't constructors/getters
- **LAZY_REDIRECT** — Handlers that say "run X command" instead of doing the work
- **PLACEHOLDER** — "Not implemented" functions with empty bodies
- **TODO_FIXME** — Unfinished work markers, scored by call graph impact
- **EMPTY_HANDLER** — Silently swallowed errors (`_ = err`)
- **HARDCODED** — Localhost URLs, IP addresses, credential values

```
/celeste-review
```

### `/celeste-search` — Semantic Code Search

Search the codebase by concept using MinHash similarity — finds functions related to a concept even if they don't contain the search term.

```
/celeste-search authentication token validation
```

### `/celeste-graph` — Dependency Analysis

Analyze package-level dependencies and find connectivity patterns.

```
/celeste-graph
```

### `/celeste-context` — Project Context Setup

Have Celeste index the project, create/update `.grimoire`, and save memories about the project structure.

```
/celeste-context
```

### `/celeste-docs` — Documentation Writer

Have Celeste review and rewrite stale docs with her personality while preserving technical depth.

```
/celeste-docs
```

## How It Works

```
                    ┌──── Direct codegraph tools (v1.9.0+) ────┐
                    │                                          │
Claude Code ──MCP──▶│  celeste_index        (rebuild/update)   │
                    │  celeste_code_search   (semantic search)  │
                    │  celeste_code_review   (structural scan)  │
                    │  celeste_code_graph    (callers/callees)  │
                    │  celeste_code_symbols  (file/package list)│
                    │                                          │
                    │  → verbatim results, no LLM round-trip   │
                    └──────────────────────────────────────────┘

                    ┌──── Persona tools (file I/O, memories) ──┐
                    │                                          │
Claude Code ──MCP──▶│  celeste { prompt, mode: "chat" }        │──▶ chat LLM
                    │  celeste_content                          │
                    │  celeste_status                           │
                    │                                          │
                    │  → save_memory, write_file, patch_file   │
                    └──────────────────────────────────────────┘
```

The skills in this repo call the **direct codegraph tools** for code intelligence queries (review, search, graph, symbols, index) and fall back to the **persona tool** only when file I/O or memory persistence is needed. Claude stays in control — Celeste provides the graph intelligence and Claude does the verification.

Direct tools return verbatim structured output with no `max_tokens` ceiling and no chat-LLM summarization. Progress notifications stream back during long operations (e.g., `celeste_index rebuild`) when your MCP client supports `progressToken`.

## Why Not Just Use grep?

Celeste's code review uses **structural graph analysis**:

- A function named `handlePayment` with zero outgoing call edges? That's suspicious — the name implies action but the structure shows passivity.
- A function that calls `db.Exec()` but assigns the error to `_`? That's a swallowed error — detected by body analysis combined with edge counting.
- A TODO in a function called by 20 others scores higher than one in dead code — impact-aware prioritization.

grep finds text. Celeste understands structure.

## Configuration

Celeste uses her own config (`~/.celeste/config.json`) for API keys and model settings. She runs independently of Claude Code's configuration.

To change Celeste's model:
```bash
celeste config --set-model grok-4-1-fast   # default
celeste config --set-model claude-sonnet-4-5
```

## License

MIT — Same as [Celeste CLI](https://github.com/whykusanagi/celeste-cli)

---

*Built by [whykusanagi](https://github.com/whykusanagi) — Celeste is an agentic AI development tool with her own persona.*
