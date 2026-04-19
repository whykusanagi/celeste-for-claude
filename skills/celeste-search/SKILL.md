---
name: celeste-search
description: Use when you need to find code by concept rather than exact name — MinHash Jaccard + BM25 rank fusion with structural reranking finds related functions even when they don't contain the search term. Requires celeste-cli v1.9.0+ and calls the direct celeste_code_search MCP tool.
---

# Celeste Semantic Search

Search the codebase by concept using Celeste's semantic search. Finds functions related to a concept even if they don't contain the exact search term. Uses MinHash Jaccard + BM25 rank fusion with structural reranking.

**Requires celeste-cli v1.9.0+** — uses the direct `celeste_code_search` MCP tool (no chat-LLM round-trip, no output truncation).

## Instructions

### Step 1: Ensure the index is current

```
Call celeste_index with: { "operation": "update", "workspace": "$CWD" }
```

### Step 2: Search

Call the `celeste_code_search` MCP tool directly:

```
Call celeste_code_search with: { "query": "<USER_QUERY>", "top_k": 10, "workspace": "$CWD" }
```

Replace `<USER_QUERY>` with the user's search terms. The response includes:
- Similarity score (Jaccard %) and BM25 score for each result
- `MatchedTokens` — which query terms actually hit this symbol
- `EdgeCount` — how well-connected the symbol is in the call graph
- `PathFlags` — whether the result is from a test/mock/generated file
- `ConfidenceWarnings` — zero-edge, low-confidence, declaration-only caveats

### Step 3: Read top results

Read the top 3-5 result files yourself (using Read tool) to provide context about what they do. The search result tells you WHERE the relevant code is; reading it tells you WHAT it does.

## Examples

- "authentication session handling" — finds auth middleware, session validators, token managers
- "error recovery retry" — finds retry loops, circuit breakers, fallback handlers
- "database connection pool" — finds pool configs, connection factories, health checks

## How It Works

Celeste's code graph stores enriched shingle tokens for every symbol (from function names, parameter types, body identifiers, package names, and doc comments). At index time, universal + per-language stop words are filtered out so common noise tokens like `get`/`set`/`error`/`string` don't consume MinHash signature slots. At query time, Jaccard similarity and BM25 term-frequency scoring are merged via Reciprocal Rank Fusion (k=60), then a structural reranker adjusts for matched-token-ratio, edge density, and symbol kind.
