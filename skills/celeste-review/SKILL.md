---
name: celeste-review
description: Use when you need structural code review that finds uncalled stubs, lazy redirects, placeholders, swallowed errors, TODOs, and hardcoded values via call-graph analysis instead of grep — requires celeste-cli v2.0.0+ and calls the direct celeste_code_review MCP tool for verbatim results
---

# Celeste Code Review

Run Celeste's graph-based code review on the current project. It combines the call graph with each function's body, so it finds issues that pattern matching alone can't.

**Requires celeste-cli v2.0.0+** — uses the direct `celeste_code_review` MCP tool (no chat-LLM round-trip, no output truncation).

## Instructions

This is a multi-step workflow. Make a separate MCP call for each step. Do NOT use agent mode.

### Step 1: Make sure the index is current

```
Call celeste_index with: { "operation": "update", "workspace": "<PROJECT_ROOT>" }
```

`update` re-parses changed files, and builds the whole index when there is none. Use `"operation": "rebuild"` only for an index built by celeste 1.x (rebuild it once to pick up the 2.0 languages) or when an error tells you to. Querying a workspace with no index returns `isError`; it never means "no findings".

### Step 2: Run the review

```
Call celeste_code_review with: { "kinds": "ALL", "max_results": 50, "workspace": "<PROJECT_ROOT>" }
```

**Parameters:**
- `kinds` — comma-separated, case-insensitive: `ALL` (default), `LAZY_REDIRECT`, `STUB`, `PLACEHOLDER`, `TODO_FIXME`, `EMPTY_HANDLER`, `HARDCODED`. An unknown kind returns `isError` with the valid list; fix the kind, don't report a clean pass.
- `max_results` — cap per category (default 30). Raise it on large codebases. For a broad dead-code sweep, use `"kinds": "STUB"` with `max_results` 100 or more.
- `include_tests` — default `false`. Set `true` only to audit test code itself.
- `workspace` — absolute project root (see Workspace below).

**Output.** The text is verbatim:

```
Found 4 issues across 3 categories:

## STUB (2)

[
  {
    "kind": "STUB",
    "name": "legacyExport",
    "file": "main.go",
    "line": 9,
    "func_kind": "function",
    "outgoing_edges": 0,
    "incoming_edges": 0,
    "score": 5,
    "reason": "body holds only a TODO/FIXME comment and no callers (likely dead code)",
    "signature": "func legacyExport()"
  },
  {
    "kind": "STUB",
    "name": "Refund",
    "file": "shop/cart.go",
    "line": 21,
    ...
    "score": 3,
    "reason": "body only raises \"not implemented\" and no callers; exported API of a library package, not dead code",
    "signature": "func Refund(id string) error"
  }
]

## PLACEHOLDER (1)
...

Verify each finding by reading the source before classifying.
```

Each finding has `kind`, `name`, `file`, `line`, `func_kind`, `outgoing_edges`, `incoming_edges`, `score`, `reason`, and optionally `signature` and `snippet`. A clean result is exactly `No issues detected. Codebase looks clean.`

### Step 3: Verify findings

Classify each STUB by its `reason`:

- **`… and no callers (likely dead code)`** (score 5): nothing reaches it, as far as the graph knows. Read the body, then confirm.
- **`… and no callers; <how>, not dead code`** (score 3): something reaches it without a call edge. `<how>` names it: a program entry point, a test function, reached through an interface, implements a trait or an interface or abstract method, overrides a base-class method, registered by a decorator, a constructor, a build-constrained file, or exported API of a library package. Report it as unfinished work, not as dead code.
- **`(approximate: file did not type-check, edges may be missing)`** appended: a Go file whose call edges were resolved by name. Treat its "no callers" with caution.

Grep for callers only for "likely dead code" findings in non-Go files or approximate Go files; for type-checked Go the graph is reliable. Look for calls through callbacks, struct fields or reflection.

For other kinds, read the source. A LAZY_REDIRECT that does real work and only mentions a command in a help or error string is a false positive.

### Step 4: Present to user

Report only verified findings. Classify each as:
- **REAL ISSUE** — confirmed: unfinished or dead, and it matters
- **FALSE POSITIVE** — the source shows real work, or a caller the graph missed
- **ACCEPTED** — known tech debt (e.g., localhost on a single-machine setup)

## Categories Detected

| Category | What it finds |
|---|---|
| STUB | A function with **no callers and a stub body**: empty, only a TODO/FIXME comment, or only raises "not implemented". One-liners, literal returns (`return nil`), functions with callers, interface/abstract declarations and empty constructors are never STUBs. |
| LAZY_REDIRECT | A function whose name implies work, with at most two outgoing calls, that redirects instead (e.g. tells the user to run a CLI) |
| PLACEHOLDER | Short bodies with zero edges and placeholder language like "not implemented" |
| TODO_FIXME | TODO/FIXME markers inside function bodies, scored by the function's callers |
| EMPTY_HANDLER | Swallowed errors (`_ = err`) in functions that call error-returning functions |
| HARDCODED | Hardcoded localhost URLs, IP addresses or credential values |

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
