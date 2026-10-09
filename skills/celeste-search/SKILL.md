---
name: celeste-search
description: Use when you need to find code by concept rather than exact name — MinHash Jaccard + BM25 rank fusion with structural reranking finds related functions even when they don't contain the search term. Requires celeste-cli v2.0.0+ and calls the direct celeste_code_search MCP tool.
---

# Celeste Semantic Search

Search the codebase by concept with Celeste's semantic search. It finds functions related to a concept even when they don't contain the exact search term.

**Requires celeste-cli v2.0.0+** — uses the direct `celeste_code_search` MCP tool (no chat-LLM round-trip, no output truncation).

## Instructions

### Step 1: Make sure the index is current

```
Call celeste_index with: { "operation": "update", "workspace": "<PROJECT_ROOT>" }
```

### Step 2: Search

```
Call celeste_code_search with: { "query": "<USER_QUERY>", "top_k": 10, "workspace": "<PROJECT_ROOT>" }
```

- `query` (required) — the user's concept, in plain words.
- `top_k` — how many results (default 10, capped at 100). A value below 1, or one that isn't a whole number, falls back to 10.
- Send only `query`, `top_k` and `workspace`. Don't pass `mode`: a keyword mode exists but isn't in the tool schema yet, so don't rely on it.

**Output.** The text is verbatim:

```
Found 5 symbols matching 'workspace path validation':

Each result shows similarity %, edge count, and any confidence warnings.
...

1. Execute (method) — cmd/celeste/tools/builtin/write_file.go:76 [8% match, edges=46]
   func (*WriteFileTool) Execute(ctx context.Context, input map[string]any, ...) (tools.ToolResult, error)
   ⚠ low confidence (jaccard < 0.10)
...
5. redactWalk (function) — cmd/celeste/jev/paths.go:162 [20% match, edges=4]
   func redactWalk(v any, workspace string) any
```

Each result is `N. name (kind) — file:line [NN% match, edges=E]`, then the signature (if any), then a `⚠` line of warnings separated by `; ` (if any). There is no BM25 score, matched-token list or path-flag field in the output. No results is `No symbols found matching the query.`

How to weigh a result:
- No warnings and `edges` > 0: a strong match.
- `demoted: test path` / `mock path` / `vendored code` / `generated code` / `declaration-only file`: ranked below production code on purpose.
- `low confidence (jaccard < 0.10)`: maybe relevant; read before trusting.
- `zero edges — may be dead code or parser limitation`: on a non-Go result this is often a parser limit, not dead code.
- `approximate call graph: Go file did not type-check`: its edge count may be off.

### Step 3: Read the top results

Read the top 3-5 result files yourself (Read tool). The search says WHERE the code is; reading it says WHAT it does. To trace a result's callers, pass its name or `file:line` to the celeste-graph skill.

## Examples

- "authentication session handling" — finds auth middleware, session validators, token managers
- "error recovery retry" — finds retry loops, circuit breakers, fallback handlers
- "database connection pool" — finds pool configs, connection factories, health checks

## How It Works

Each symbol is indexed as shingle tokens from its name, parameter types, body identifiers, package and doc comment, with stop words removed. A query ranks symbols by MinHash Jaccard similarity and by BM25, fuses the two rankings with Reciprocal Rank Fusion (k=60), then a structural reranker adjusts for matched-token ratio, edge density and symbol kind.

## Workspace

Pass `workspace` as the absolute path of the project root (for example `git rev-parse --show-toplevel`). Never pass `$CWD` or a relative path. celeste accepts a workspace only if:

- it is under your home directory, or is the directory the server was launched in;
- it is not in `.ssh`, `.gnupg`, `.aws`, `.config/gcloud` or `.kube` (matched case-insensitively on macOS and Windows);
- it is an existing directory.

A result that starts `workspace rejected` means choose another path. Do not retry the same one.

## Reading results

Every celeste failure comes back as a tool result with `isError: true`, never as a JSON-RPC error. Check `isError` first, and never report an `isError` result as a clean or empty answer.

- `No code graph index for …`: build it with `celeste_index` `update` (an empty index gets a full build), then query again.
- `… is being built; try again when the build finishes`: another indexer is building it. Wait, then query again. Do not start a rebuild.
- `… did not finish; run celeste_index (operation update) …`: run `update`, then query again.
- A first line `Note: … results may be incomplete …`: the index is being updated, or its last update did not finish. Use the answer, but tell the user the results may be incomplete. Run `update` when the note says to.
- `celeste_index` `update` with a `skipped` field: another celeste process is indexing this workspace, and the stats are the index as it is now. Do not loop on `update`.
- The first `update` after upgrading from celeste 1.x can take as long as a full build.
