# Celeste Project Context

Index the current project and gather structural context for future sessions using Celeste's codegraph and code review tools.

**Requires celeste-cli v1.9.0+** — uses `celeste_index`, `celeste_code_review`, and `celeste_code_search` MCP tools directly.

## Instructions

This is a multi-step workflow. Make separate MCP calls.

### Step 1: Build the index

```
Call celeste_index with: { "operation": "rebuild", "workspace": "$CWD" }
```

This builds the full code graph from scratch — symbols, edges, MinHash signatures, BM25 token stats. The response reports total files, symbols, edges, and elapsed time. Progress notifications stream back if your MCP client supports `progressToken`.

### Step 2: Check index health

```
Call celeste_index with: { "operation": "status", "workspace": "$CWD" }
```

Returns total files, symbols, edges, symbols by kind, files by language, and BM25 corpus stats (num_docs, avg_doc_length).

### Step 3: Run code review for project overview

```
Call celeste_code_review with: { "kinds": "STUB,PLACEHOLDER,TODO_FIXME", "max_results": 20, "workspace": "$CWD" }
```

### Step 4: Find main entry points

```
Call celeste_code_search with: { "query": "main entry point server app handler", "top_k": 10, "workspace": "$CWD" }
```

### Step 5: Save project memories

Based on what you learned from steps 2-4, call the `celeste` persona tool to save memories:

```json
{
  "prompt": "save_memory with name='project-overview', type='project', content='<summary of architecture, key packages, entry points, tech stack>'",
  "mode": "chat",
  "workspace": "$CWD"
}
```

### Step 6: Update grimoire

```json
{
  "prompt": "Read the current .grimoire file, then update it with an Architecture section describing the project structure, key packages, and entry points. Use write_file to save.",
  "mode": "chat",
  "workspace": "$CWD"
}
```

Note: Steps 5-6 still use the `celeste` persona tool because they need `save_memory` and `write_file`, which are not exposed as direct MCP tools. Steps 1-4 use the direct codegraph tools for speed and verbatim results.

## What Gets Created

- **Code graph** (`~/.celeste/projects/<hash>/codegraph.db`) — symbols, edges, MinHash signatures, BM25 token stats
- **Memories** (`~/.celeste/projects/<hash>/memories/`) — persistent project facts
- **`.grimoire`** (project root) — auto-stamped with git hash, branch, index stats
