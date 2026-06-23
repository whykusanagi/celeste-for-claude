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

**v1.9.0+:** Skills now use Celeste's **direct codegraph MCP tools** (`celeste_index`, `celeste_code_search`, `celeste_code_review`, `celeste_code_graph`, `celeste_code_symbols`) instead of routing through the chat persona. Results come back verbatim and structured, with no LLM round-trip and no output truncation.

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

Install [Celeste CLI](https://github.com/whykusanagi/celeste-cli) (v1.9.0+). Two options:

```bash
# Quick: installs to ~/go/bin (must be on your PATH)
go install github.com/whykusanagi/celeste-cli/cmd/celeste@latest

# Or from a checkout: installs to ~/.local/bin and code-signs (macOS-safe)
git clone https://github.com/whykusanagi/celeste-cli.git && cd celeste-cli && make install
```

> Whichever you pick, the install directory must be on your `PATH`, and it must
> match the binary your MCP client launches. On macOS, don't `cp` over an existing
> `~/.local/bin/celeste` — that breaks its code signature; use `make install`.

Verify:
```bash
celeste version
celeste index status   # in any project directory
```

You'll need an API key configured only if you use the persona tools (xAI/Grok by
default). The direct codegraph tools (`celeste_index`, `celeste_code_search`, etc.)
run locally and need no key.

```bash
celeste config --set-key YOUR_API_KEY   # only for persona tools
```

## Installation

### Option A — Install the plugin (recommended)

The plugin bundles the skills **and** wires the Celeste MCP server for Claude Code
automatically (no manual config):

```
/plugin marketplace add whykusanagi/celeste-for-claude
/plugin install celeste-for-claude
```

This works in Claude Code because it inherits your shell `PATH`, so the bundled
server entry (`celeste serve`) resolves on its own.

### Option B — Manual MCP registration

Use this if you're not installing the plugin, or you're on Claude **Desktop**.

**Claude Code** (CLI — inherits `PATH`):
```bash
claude mcp add celeste --scope user -- celeste serve
```

**Claude Desktop** (GUI — does **not** inherit your shell `PATH`):
Claude Desktop launches the server without your shell environment, so a bare
`celeste` won't be found — it needs the binary's **absolute** path. Run the
installer, which resolves it for you and merges it into
`~/Library/Application Support/Claude/claude_desktop_config.json`:

```bash
git clone https://github.com/whykusanagi/celeste-for-claude.git
cd celeste-for-claude
./install.sh                 # writes the absolute path; --dry-run to preview
```

It preserves any other MCP servers, backs the file up to `.bak`, and is safe to
**re-run** any time you reinstall or move the binary (it repairs the path). Then
fully quit and reopen Claude Desktop (Cmd-Q) to load it. The resulting entry looks
like:

```json
{
  "mcpServers": {
    "celeste": { "command": "/Users/you/.local/bin/celeste", "args": ["serve"] }
  }
}
```

See [INSTALL.md](INSTALL.md) for per-client detail and troubleshooting.

### Skills without the plugin

If you registered the MCP server manually and want the skills too, copy them into
your skills directory:

```bash
mkdir -p ~/.claude/skills
cp -R celeste-for-claude/skills/* ~/.claude/skills/
```

## Available Skills

### `celeste-review` — Graph-Based Code Review

Runs Celeste's structural code review on the current project. Detects 6 categories of issues using the code graph (not grep):

- **STUB** — Functions with zero outgoing calls that aren't constructors/getters
- **LAZY_REDIRECT** — Handlers that say "run X command" instead of doing the work
- **PLACEHOLDER** — "Not implemented" functions with empty bodies
- **TODO_FIXME** — Unfinished work markers, scored by call graph impact
- **EMPTY_HANDLER** — Silently swallowed errors (`_ = err`)
- **HARDCODED** — Localhost URLs, IP addresses, credential values

**Invoke:** ask Claude to "run a Celeste code review on this project."

### `celeste-search` — Semantic Code Search

Search the codebase by concept using MinHash similarity — finds functions related to a concept even if they don't contain the search term.

**Invoke:** ask Claude to "use Celeste to search for authentication token validation."

### `celeste-graph` — Dependency Analysis

Analyze package-level dependencies and find connectivity patterns.

**Invoke:** ask Claude to "analyze this project's dependencies with Celeste."

### `celeste-context` — Project Context Setup

Have Celeste index the project, create/update `.grimoire`, and save memories about the project structure.

**Invoke:** ask Claude to "set up Celeste project context here."

### `celeste-docs` — Documentation Maintainer

Keep existing markdown docs from drifting. Patches section-by-section to fix stale versions, wrong counts, and dead references — without summarizing away code examples and technical depth.

**Invoke:** ask Claude to "use Celeste to update the docs in this repo."

### `celeste-content` — Content Generator

Generate new prose in Celeste's voice — filling a stub, drafting a README intro, writing a commit message, or producing a social post. Returns styled text for you to place; does not write files itself.

**Invoke:** ask Claude to "draft this in Celeste's voice."

**Docs vs Content:** `celeste-docs` **maintains** existing files surgically. `celeste-content` **generates** new prose for blank spots. Use docs to prevent drift; use content to fill stubs.

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

The skills in this repo call the **direct codegraph tools** for code intelligence queries (review, search, graph, symbols, index) and fall back to the **persona tool** only when file I/O or memory persistence is needed. Celeste provides the graph intelligence; Claude does the verification and stays in control.

Direct tools return verbatim structured output with no `max_tokens` ceiling and no chat-LLM summarization. Progress notifications stream back during long operations (e.g., `celeste_index rebuild`) when your MCP client supports `progressToken`.

## Why Not Just Use grep?

Celeste's code review uses **structural graph analysis**:

- A function named `handlePayment` with zero outgoing call edges? That's suspicious: the name implies action, the structure shows none.
- A function that calls `db.Exec()` but assigns the error to `_`? That's a swallowed error, caught by body analysis combined with edge counting.
- A TODO in a function called by 20 others scores higher than one in dead code (impact-aware prioritization).

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
