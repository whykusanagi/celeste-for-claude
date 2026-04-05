# Celeste Project Context

Have Celeste index the current project and set up persistent context for future sessions.

## Instructions

This is a multi-step workflow. Make separate MCP calls.

### Step 1: Index and get status

```json
{
  "prompt": "Index this project's code graph and report stats: total files, symbols, edges, top packages by symbol count.",
  "mode": "chat",
  "workspace": "$CWD"
}
```

### Step 2: Run code review for project overview

```json
{
  "prompt": "Run code_review with kinds=STUB,PLACEHOLDER,TODO_FIXME and max_results=20. Also use code_search to find the main entry points and core packages.",
  "mode": "chat",
  "workspace": "$CWD"
}
```

### Step 3: Save project memories

Based on what you learned from steps 1-2, call celeste to save memories:

```json
{
  "prompt": "save_memory with name='project-overview', type='project', content='<summary of architecture, key packages, entry points, tech stack>'",
  "mode": "chat",
  "workspace": "$CWD"
}
```

### Step 4: Update grimoire

```json
{
  "prompt": "Read the current .grimoire file, then update it with an Architecture section describing the project structure, key packages, and entry points. Use write_file to save.",
  "mode": "chat",
  "workspace": "$CWD"
}
```

## What Gets Created

- **Code graph** (`~/.celeste/projects/<hash>/codegraph.db`) — symbols, edges, MinHash signatures
- **Memories** (`~/.celeste/projects/<hash>/memories/`) — persistent project facts
- **`.grimoire`** (project root) — auto-stamped with git hash, branch, index stats
