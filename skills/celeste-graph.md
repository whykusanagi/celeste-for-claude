# Celeste Dependency Graph

Analyze the codebase's package-level dependency structure using Celeste's code graph.

## Instructions

Call the celeste MCP tool:

```json
{
  "prompt": "Analyze the package dependency structure. Use code_graph to show: 1) Package-level connectivity, 2) Most connected packages (highest edge count), 3) Isolated packages with zero cross-package edges. Also use code_symbols to list symbols in any specific package the user asked about.",
  "mode": "chat",
  "workspace": "$CWD"
}
```

Replace `$CWD` with the current working directory.

If the user asks about a specific package, make a follow-up call:

```json
{
  "prompt": "Use code_symbols to list all symbols in package '<PACKAGE_NAME>' and code_search to find what calls into it.",
  "mode": "chat",
  "workspace": "$CWD"
}
```

## Use Cases

- Understanding unfamiliar codebases
- Finding dead/orphaned packages
- Planning refactoring (what depends on what)
- Identifying tightly coupled packages
