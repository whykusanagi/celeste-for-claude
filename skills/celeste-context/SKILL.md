---
name: celeste-context
description: Use when setting up a new project with Celeste — builds the code graph index, runs an initial structural review, finds entry points, saves persistent project memories, and updates the project's .grimoire context file if it has one. Requires celeste-cli v2.0.0+.
---

# Celeste Project Context

Index the current project and gather structural context for future sessions with Celeste's code graph and code review tools.

**Requires celeste-cli v2.0.0+** — uses `celeste_status`, `celeste_index`, `celeste_code_review` and `celeste_code_search` MCP tools directly.

## Instructions

This is a multi-step workflow. Make separate MCP calls.

### Step 0: Pre-flight check

```
Call celeste_status with: {}
```

Call it with `{}`. It takes no `workspace`; its optional `run_id` and `cancel` report on or cancel a background agent run, and you don't need them here. It returns `server`, `version`, `commit`, `uptime`, `health`, `provider`, `model`, `workspace`, `transport`, `grimoire`, `project`, `session_cost`, `completions`, `oracle` and `rules`. Check:

- `health` is `ok`, not `degraded` (the latest completion failed), and `model` is set (Sakana `fugu` by default). If either fails, the persona steps (5 and 6) will fail. Fix it on the command line, not via MCP:

  ```bash
  celeste config --init <provider>   # create a config profile for a provider
  celeste config --set-key <key>     # set its API key
  ```

  Config lives in `~/.celeste/`. Steps 1-4 need no API key, so run them anyway and skip 5 and 6.
- `commit` starts with the commit that `celeste version` prints in brackets. If not, the MCP server is an older binary still running; ask the user to restart their MCP client.
- `project.indexed` decides Step 1. `project` and `grimoire` describe the directory the server was launched in (`workspace`). If that isn't the project root, check the index with `celeste_index` `status` and the project's `workspace` instead.

### Step 1: Build or refresh the index

```
Call celeste_index with: { "operation": "update", "workspace": "<PROJECT_ROOT>" }
```

`update` builds the whole index when there is none, and otherwise re-parses only changed files. Use `"operation": "rebuild"` instead the first time after upgrading from celeste 1.x, so the new 2.0 languages (Java, C/C++, Ruby) get indexed, or when an error tells you to. The response reports files, symbols, edges and elapsed time.

### Step 2: Check index health

```
Call celeste_index with: { "operation": "status", "workspace": "<PROJECT_ROOT>" }
```

Returns total files, symbols and edges, symbols by kind, files by language, and BM25 corpus stats (`num_docs`, `avg_doc_length`).

### Step 3: Run code review for a project overview

```
Call celeste_code_review with: { "kinds": "STUB,PLACEHOLDER,TODO_FIXME", "max_results": 20, "workspace": "<PROJECT_ROOT>" }
```

Read STUB findings by their `reason`, as the celeste-review skill describes: only "likely dead code" means dead.

### Step 4: Find main entry points

```
Call celeste_code_search with: { "query": "main entry point server app handler", "top_k": 10, "workspace": "<PROJECT_ROOT>" }
```

### Step 5: Save project memories

From what Steps 2-4 showed, call the `celeste` persona tool to save a memory:

```json
{
  "prompt": "save_memory with name='project-overview', type='project', content='<summary of architecture, key packages, entry points, tech stack>'",
  "mode": "chat",
  "workspace": "<PROJECT_ROOT>"
}
```

The user can manage memories on the command line with `celeste memories` (list), `celeste remember "<text>"` and `celeste forget <name>`.

### Step 6: Update the grimoire (only if there is one)

Celeste 2.0 no longer creates `.grimoire` by itself. Run this step only if the project root has a `.grimoire`, or the user asks for one. If there is none, offer `celeste init` in the project root (`celeste init --agents` also writes an `AGENTS.md`); it never overwrites an existing file. Celeste also reads `AGENTS.md` and `CLAUDE.md` (from the git root down) as project context, so a project with those may not need a grimoire.

Read and write in the same prompt:

```json
{
  "prompt": "Read the current .grimoire file, then update it with an Architecture section describing the project structure, key packages, and entry points. Use write_file to save.",
  "mode": "chat",
  "workspace": "<PROJECT_ROOT>"
}
```

Steps 5-6 use the `celeste` persona tool because `save_memory` and `write_file` aren't direct MCP tools. Steps 1-4 use the direct code graph tools for speed and verbatim results.

## What Gets Created

- **Code graph** (`~/.celeste/projects/<hash>/codegraph.db`) — symbols, edges, MinHash signatures, BM25 token stats
- **Memories** (`~/.celeste/projects/<hash>/memories/`) — persistent project facts
- **`.grimoire`** (project root) — only when it already exists or `celeste init` writes it; this skill never creates one

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
