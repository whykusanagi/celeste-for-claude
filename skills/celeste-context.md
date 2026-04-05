# Celeste Project Context

Have Celeste analyze the current project and set up persistent context — indexes the code graph, creates/updates the `.grimoire` project config, and saves memories about the project structure for future sessions.

## Instructions

Use the `celeste` MCP tool to set up project context:

```json
{
  "prompt": "Analyze this project thoroughly: 1) Index the code graph. 2) Run code_review to find issues. 3) Update the .grimoire file with architecture details, project structure, build commands, and code review findings. 4) Save memories about key architectural decisions, project patterns, and notable issues you found. Be thorough — this context will persist across sessions.",
  "mode": "agent",
  "workspace": "<current working directory>"
}
```

## What Gets Created

### `.grimoire` (project root)
Auto-stamped with git hash, branch, commit count, and index stats. Contains:
- **Bindings** — language, module path, conventions
- **Architecture** — component structure, data flow
- **Structure** — directory layout, package organization
- **Rituals** — test/lint/commit commands
- **Issues** — code review findings summary
- **Wards** — protected paths

### Memories (`~/.celeste/projects/<hash>/memories/`)
Persistent facts saved via `save_memory` tool:
- Project overview and components
- Git history context
- Code quality issues
- Architectural patterns

### Code Graph (`~/.celeste/projects/<hash>/codegraph.db`)
SQLite database with:
- All symbols (functions, methods, types, interfaces)
- Call edges between symbols
- MinHash signatures for semantic search
- File tracking for incremental updates

## After Setup

The `.grimoire` is checked into git. Memories and the code graph are local (under `~/.celeste/`). Future Celeste sessions in this project will load all three automatically.
