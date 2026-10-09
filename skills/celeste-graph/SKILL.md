---
name: celeste-graph
description: Use when you need to trace callers, callees, references, or package connectivity in a codebase — structural dependency analysis via Celeste's code graph. Requires celeste-cli v2.0.0+ and calls the direct celeste_code_graph and celeste_code_symbols MCP tools.
---

# Celeste Dependency Graph

Analyze the codebase's structural relationships with Celeste's code graph: callers, callees, references and package contents.

**Requires celeste-cli v2.0.0+** — uses the direct `celeste_code_graph` and `celeste_code_symbols` MCP tools.

## Instructions

### Step 1: Make sure the index is current

```
Call celeste_index with: { "operation": "update", "workspace": "<PROJECT_ROOT>" }
```

### Step 2: Query the graph

```
Call celeste_code_graph with: { "symbol": "<SYMBOL>", "direction": "both", "depth": 1, "workspace": "<PROJECT_ROOT>" }
```

**Parameters:**
- `symbol` (required) — a name or a qualified name. If you only know the concept, run `celeste_code_search` first and use the result's name; use its `file:line` to pick the right one if several share the name.
- `direction` — `"callers"`, `"callees"` or `"both"` (default).
- `depth` — hops to walk (default 1, max 3). Start at 1; use 2 or 3 to see how a change propagates.
- `workspace` — absolute project root (see Workspace below).

**Qualified names** pick one symbol:
- Go: `(tui.AppModel).update`, `(*acp.session).update`, `AppModel.update`, `pkg.Func`, or a full import path.
- Other languages: `Foo.add`, `Foo::add`, `core.add` (file stem), `file.Pt.x`.

**Reading the answer:**

```
## price (function) — shop/cart.go:11
  func price(n int) int

  Called by:
    <- Checkout (calls) shop/cart.go:6
    <- main (calls) main.go:5 [hop 2, via Checkout]
```

- Each edge line is `<-` (caller) or `->` (callee), the symbol, the edge kind, and `file:line`. Entries past the first hop end with `[hop N, via X]`. Past the first hop each direction stops after 200 entries and says so; lower `depth` if it does.
- Edge kinds: `calls` in every language. `references` (a function taken as a value) and `implements` (interface method to implementing method) exist only for Go. Go methods that satisfy interfaces show an `Implements:` line.
- `(approximate: this file did not type-check …)` under a symbol: its Go edges were resolved by name and may be incomplete.
- Several symbols with one name (`4 symbols are named 'update':`): up to 8 are shown with edges, each headed by its qualified name. More than 8, or several partial matches, come back as a candidate list without edges. Call again with one of the printed qualified names.
- `Symbol '<name>' not found in the code graph.` is a normal answer, not an error. Try a qualified name or search first.

### Step 3: List symbols in a file or package

```
Call celeste_code_symbols with: { "file": "<relative/path/to/file.go>", "workspace": "<PROJECT_ROOT>" }
Call celeste_code_symbols with: { "package": "<package_name>", "workspace": "<PROJECT_ROOT>" }
```

Pass `file` or `package`. The answer groups symbols by kind with their line numbers and signatures.

## Use Cases

- Understanding unfamiliar code: start from an entry point and trace outward.
- Planning a refactor: see what depends on a symbol before moving it.
- Spotting tight coupling: functions that call across many packages.
- Dead code: don't hunt it here. Run `celeste_code_review` with `"kinds": "STUB"` and read each finding's `reason` (see the celeste-review skill). Use the graph only to confirm a finding's callers.

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
