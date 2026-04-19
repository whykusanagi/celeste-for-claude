---
name: celeste-graph
description: Use when you need to trace callers, callees, references, or package connectivity in a codebase — structural dependency analysis via Celeste's code graph. Requires celeste-cli v1.9.0+ and calls the direct celeste_code_graph and celeste_code_symbols MCP tools.
---

# Celeste Dependency Graph

Analyze the codebase's structural relationships using Celeste's code graph — callers, callees, references, and package connectivity.

**Requires celeste-cli v1.9.0+** — uses the direct `celeste_code_graph` and `celeste_code_symbols` MCP tools.

## Instructions

### Step 1: Ensure the index is current

```
Call celeste_index with: { "operation": "update", "workspace": "$CWD" }
```

### Step 2: Query the graph

To analyze a specific symbol's callers and callees:

```
Call celeste_code_graph with: { "symbol": "<SYMBOL_NAME>", "direction": "both", "depth": 1, "workspace": "$CWD" }
```

**Parameters:**
- `symbol` (required) — symbol name. If you only know the concept, run `celeste_code_search` first and use a result's `Symbol` field.
- `direction` — `"callers"` (who calls this), `"callees"` (what this calls), or `"both"` (default).
- `depth` — number of hops to traverse (default 1, **max 3**). Use `depth: 2` or `3` for transitive reach when tracing how a change propagates. Deeper traversals return more results; start shallow.
- `workspace` — absolute path to the project root.

### Step 3: List symbols in a file or package

To see what's in a specific file:

```
Call celeste_code_symbols with: { "file": "<relative/path/to/file.go>", "workspace": "$CWD" }
```

Or by package:

```
Call celeste_code_symbols with: { "package": "<package_name>", "workspace": "$CWD" }
```

### Step 4: Cross-reference with search

If you need to find a symbol by concept first:

```
Call celeste_code_search with: { "query": "<concept>", "top_k": 5, "workspace": "$CWD" }
```

Then use `celeste_code_graph` on the top result's symbol name to trace its connections.

## Use Cases

- Understanding unfamiliar codebases — start from an entry point and trace outward
- Finding dead/orphaned functions — symbols with zero callers and zero callees
- Planning refactoring — what depends on what before you move things around
- Identifying tightly coupled modules — functions that call across many packages
