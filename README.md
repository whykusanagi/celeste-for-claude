<div align="center">

<img src="https://s3.whykusanagi.xyz/optimized_assets/hypnosis_expression_trans_ghub.png" alt="Celeste - Corrupted AI Assistant" width="250"/>

<sub>Character artwork by [いかわさ (ikawasa23)](https://x.com/ikawasa23)</sub>

# Celeste for Claude Code

**Graph-based code intelligence for Claude Code via MCP**

[![Requires Celeste CLI](https://img.shields.io/badge/requires-celeste--cli%20v2.0.0+-purple)](https://github.com/whykusanagi/celeste-cli)
[![MCP](https://img.shields.io/badge/transport-MCP%20stdio-00d4ff)](https://modelcontextprotocol.io)
[![License](https://img.shields.io/badge/License-MIT-purple)](LICENSE)

</div>

---

Give Claude Code access to [Celeste CLI](https://github.com/whykusanagi/celeste-cli)'s graph-based code intelligence — structural code review, semantic search, dependency analysis, and project context management that goes beyond grep and pattern matching.

Since celeste v1.9.0, the skills use Celeste's **direct codegraph MCP tools** (`celeste_index`, `celeste_code_search`, `celeste_code_review`, `celeste_code_graph`, `celeste_code_symbols`) instead of routing through the chat persona. Results come back verbatim and structured, with no LLM round-trip and no output truncation.

## What You Get

Celeste brings capabilities Claude Code doesn't have natively:

| Capability | What it does | How it works |
|---|---|---|
| **Graph Code Review** | Detect stubs, lazy redirects, error swallowing, placeholders, hardcoded values | Structural analysis via code graph — not grep |
| **Semantic Code Search** | Find functions by concept, not just name | MinHash + BM25 fusion with structural rerank |
| **Dependency Analysis** | Map package connectivity, find isolated code | Cross-file edge resolution: go/ast for Go; tree-sitter for TypeScript/JavaScript, PHP, Python, Rust, Java, C/C++ and Ruby in release binaries |
| **Project Memory** | Persist learned context across sessions | Per-project memory store |
| **`.grimoire` Context** | Project config with staleness tracking, created by `celeste init` | Git-stamped metadata |

> An index built by celeste 1.x skipped Java, C, C++ and Ruby files, and a 1.x
> release binary parsed the other non-Go languages with regex. Rebuild it once
> after upgrading:
> `celeste index rebuild` in the project, or `celeste_index` with
> `operation: "rebuild"`.

## Versions

Pick the companion release that matches your celeste-cli:

| Companion | For celeste-cli | Install celeste-cli | Add the plugin marketplace |
|---|---|---|---|
| **v2.0.0** (current) | 2.0.0 or later | `go install github.com/whykusanagi/celeste-cli/v2/cmd/celeste@latest`, or a signed binary from [Releases](https://github.com/whykusanagi/celeste-cli/releases) | `/plugin marketplace add whykusanagi/celeste-for-claude` |
| v1.11.0 | 1.9.0 up to the last 1.x | `go install github.com/whykusanagi/celeste-cli/cmd/celeste@latest` (the path without `/v2` installs the newest 1.x) | `/plugin marketplace add https://github.com/whykusanagi/celeste-for-claude.git#v1.11.0` |

Then run `/plugin install celeste-for-claude` for either one. To use the skills
without the plugin on 1.x, clone the tag instead:
`git clone --branch v1.11.0 https://github.com/whykusanagi/celeste-for-claude.git`.

The rest of this README covers v2.0.0. Upgrading celeste from 1.x? Read
celeste-cli's [MIGRATING-2.0.md](https://github.com/whykusanagi/celeste-cli/blob/main/MIGRATING-2.0.md)
and back up `~/.celeste` first.

## Prerequisites

Install [Celeste CLI](https://github.com/whykusanagi/celeste-cli) **v2.0.0 or
later**. 2.0 moved the Go module to `/v2`, so the install path changed.

**Recommended — `go install` (Go 1.26+).** It installs to `~/go/bin`, which must
be on your `PATH`:

```bash
go install github.com/whykusanagi/celeste-cli/v2/cmd/celeste@latest
```

**No Go?** Download a signed binary from the
[Releases page](https://github.com/whykusanagi/celeste-cli/releases) and verify it
as described in celeste-cli's
[VERIFY.md](https://github.com/whykusanagi/celeste-cli/blob/main/VERIFY.md).

> The old path without `/v2` (`go install …/celeste-cli/cmd/celeste@latest`) still
> installs the last **1.x** release, never 2.0.

**For contributors (public persona).** `make install` from a checkout installs to
`~/.local/bin` and code-signs the binary (macOS-safe). A checkout build runs the
short public persona and never upgrades itself to the official binary, so use it
only if you work on celeste-cli:

```bash
git clone https://github.com/whykusanagi/celeste-cli.git && cd celeste-cli && make install
```

> Whichever you pick, the install directory must be on your `PATH`, and it must
> match the binary your MCP client launches. On macOS, don't `cp` over an existing
> `~/.local/bin/celeste` — that breaks its code signature.

Verify:
```bash
celeste version          # Celeste CLI 2.x.y ...
celeste update           # a `go install` build: swaps in the official signed binary
celeste persona verify   # exits 0 ("official persona: ...") on an official build
celeste index status     # in any project directory
```

A `go install` build swaps itself for the official signed release binary of the
same version the first time it runs a command; `celeste update` does it
explicitly. Set `CELESTE_NO_AUTO_UPGRADE=1` to keep the binary `go install`
built. Only official binaries run Celeste's full persona: on any other build
`celeste persona verify` exits 1 and names the reason, and the persona-voiced
tools (`celeste`, `celeste_content`) use the public persona. The codegraph tools
work the same on every build. `celeste serve` never replaces itself mid-run, so
run `celeste update` once before wiring the MCP server.

You'll need an API key configured only if you use the persona tools (Sakana
`fugu` by default). The direct codegraph tools (`celeste_index`,
`celeste_code_search`, etc.) run locally and need no key.

```bash
celeste config --set-key YOUR_SAKANA_KEY   # only for persona tools
```

See [Configuration](#configuration) to use another provider.

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
`celeste` won't be found — it needs the binary's **absolute** path. Celeste
installs itself: `celeste mcp install --client claude-desktop` self-locates the
binary and merges an entry into
`~/Library/Application Support/Claude/claude_desktop_config.json`.

```bash
celeste mcp install --client claude-desktop             # Claude Desktop only
celeste mcp install --client claude-desktop --dry-run   # preview without writing
```

> Pass `--client claude-desktop`. A bare `celeste mcp install` defaults to
> `--client all` and writes the config of every installed client: Claude
> Desktop, Claude Code (`~/.claude.json`), Cursor and celeste's own
> `~/.celeste/mcp.json`. With the plugin installed, the Claude Code entry
> duplicates the plugin's server.

It preserves any other MCP servers, backs the file up to `.bak`, writes it
readable by you only (0600), never writes through a symlink, and is safe to
**re-run** any time you reinstall or move the binary (it repairs the path). Then
fully quit and reopen Claude Desktop (Cmd-Q) to load it. The resulting entry
looks like:

```json
{
  "mcpServers": {
    "celeste": { "command": "/Users/you/.local/bin/celeste", "args": ["serve"] }
  }
}
```

> This repo's `./install.sh` does the same for Claude Desktop and also refuses a
> celeste older than 2.0. `celeste mcp install` supersedes it:
> ```bash
> git clone https://github.com/whykusanagi/celeste-for-claude.git
> cd celeste-for-claude && ./install.sh   # --dry-run to preview
> ```

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

- **STUB** — A function with **no callers and a stub body**: empty, TODO-only, or only raising "not implemented". One-liners, functions that return a literal, and functions with callers are never STUBs. The `reason` says "likely dead code" unless the function is reached another way (an entry point, a test, an interface or trait implementation, an override, a decorator, a build-constrained file, or a library's exported API), which it names instead
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

Have Celeste index the project, save memories about the project structure, and update `.grimoire` if the project has one (`celeste init` creates it; celeste 2.0 no longer creates it on its own).

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

A fresh install points at Sakana (`https://api.sakana.ai/v1`, model `fugu`), so
you only need a key. To change the model:
```bash
celeste config --set-model fugu-ultra   # default is fugu
```

A config still set to the retired `grok-4-1-fast` is moved to a supported Grok
model automatically when it loads.

To use another provider, create a profile for it, set its key, and make it the
default (providers: `openai`, `grok`, `venice`, `sakana`, `digitalocean`):
```bash
celeste config --init grok
celeste -config grok config --set-key YOUR_XAI_KEY
celeste -config grok config --set-default
```

`CELESTE_API_KEY` and `CELESTE_API_ENDPOINT` override the config file's key and
URL for `celeste serve` (and the CLI) for that run only; they are never written
to the config. An old export of either in your shell profile wins over the
config file, so unset it if the MCP server talks to the wrong provider.
`celeste_status` reports the `provider` and `model` the server is using.

### What the `celeste` tool loads

The persona tool (`celeste`, MCP chat) runs on celeste's full tool loop, but
only with your **home-level** MCP servers (`~/.celeste/mcp.json`,
`~/.claude/mcp.json`, `~/.cursor/mcp.json`); a repository's `.mcp.json` starts
only in celeste's interactive chat. A repository's hooks (`.celeste/hooks.json`
or `.grimoire` hooks) are skipped in MCP chat until you approve them from that
repository with `celeste hooks trust` (`celeste hooks list` shows their status).

### Editors other than Claude

celeste 2.0 also ships `celeste acp`, an Agent Client Protocol agent for Zed and
JetBrains IDEs. This plugin doesn't use it; see celeste-cli's
[docs/ACP.md](https://github.com/whykusanagi/celeste-cli/blob/main/docs/ACP.md).

## License

MIT — Same as [Celeste CLI](https://github.com/whykusanagi/celeste-cli)

---

*Built by [whykusanagi](https://github.com/whykusanagi) — Celeste is an agentic AI development tool with her own persona.*
