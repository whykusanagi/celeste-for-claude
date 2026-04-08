---
name: celeste-for-claude
description: Graph-based code intelligence skills for Claude Code via MCP — structural code review, semantic search, dependency analysis, project context, and documentation generation powered by Celeste CLI's code graph
when_to_use: When you need code intelligence beyond grep and pattern matching — structural code review that detects stubs/placeholders/swallowed errors via call graph analysis, semantic code search by concept using MinHash similarity, package dependency mapping, project context setup with persistent memory, or documentation review and rewriting
metadata:
  author: whykusanagi
  version: 1.8.4
  license: MIT
  requires: celeste-cli
capabilities:
  - code.review
  - code.search
  - code.analysis
  - docs.generation
---

# Celeste for Claude Code

Graph-based code intelligence for Claude Code via MCP. Gives Claude access to [Celeste CLI](https://github.com/whykusanagi/celeste-cli)'s structural analysis — code review, semantic search, dependency graphs, and project memory that goes beyond grep.

## Prerequisites

Requires [Celeste CLI](https://github.com/whykusanagi/celeste-cli) installed:

```bash
go install github.com/whykusanagi/celeste-cli/cmd/celeste@latest
celeste config --set-key YOUR_API_KEY
```

## MCP Server Setup

Add to your Claude Code MCP config:

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

## Skills Included

### `/celeste-review` — Graph-Based Code Review

Structural code review using the code graph. Detects stubs, lazy redirects, placeholders, TODO/FIXME (impact-scored by callers), swallowed errors, and hardcoded values.

### `/celeste-search` — Semantic Code Search

Find functions by concept using MinHash similarity — matches even when names don't contain the search term.

### `/celeste-graph` — Dependency Analysis

Package-level dependency mapping. Finds most-connected packages, isolated code, and cross-package edges.

### `/celeste-context` — Project Context Setup

Index the project, run initial review, save memories, and set up `.grimoire` for persistent context.

### `/celeste-docs` — Documentation Writer

Review docs for staleness and rewrite section-by-section, preserving technical depth.
