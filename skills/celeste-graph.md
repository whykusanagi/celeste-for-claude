# Celeste Dependency Graph

Analyze the codebase's dependency structure using Celeste's code graph. Shows package-level connectivity, identifies isolated code, and maps call chains.

## Instructions

Use the `celeste` MCP tool to run dependency analysis:

```json
{
  "prompt": "Use code_graph to analyze the package dependency structure. Show: 1) Package-level connectivity (which packages call which), 2) Most connected packages (highest edge count), 3) Isolated packages with zero cross-package edges, 4) The overall graph stats. If the user asked about a specific package or symbol, use code_symbols to list its contents and code_search to find related code.",
  "mode": "agent",
  "workspace": "<current working directory>"
}
```

## What It Shows

- **Package connectivity map** — which packages depend on which
- **Hub packages** — most connected (highest incoming + outgoing edges)
- **Leaf packages** — isolated code with minimal connections
- **Symbol breakdown** — functions, methods, structs, interfaces per package
- **Edge analysis** — call chains, implementation relationships

## Use Cases

- Understanding unfamiliar codebases
- Finding dead/orphaned packages
- Planning refactoring (what depends on what)
- Identifying tightly coupled packages
