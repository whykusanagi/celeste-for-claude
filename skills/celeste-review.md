# Celeste Code Review

Run Celeste's graph-based code review on the current project. This uses structural analysis of the code graph — not grep — to detect issues that pattern matching alone can't find.

## Instructions

Use the `celeste` MCP tool to delegate a code review to Celeste. She will:

1. Index the codebase (builds/updates the code graph automatically)
2. Run her `code_review` tool which analyzes every function's graph structure
3. Report findings grouped by category with scores and reasons

Call the celeste MCP tool with:

```json
{
  "prompt": "Index this project and run code_review with kinds=ALL, max_results=50. Report all findings grouped by category. For each finding, show the file, line, function name, score, and reason. Verify the top 5 highest-scored findings by reading the source.",
  "mode": "agent",
  "workspace": "<current working directory>"
}
```

## Categories Detected

| Category | What it finds | How (structural) |
|---|---|---|
| STUB | Dead or unfinished functions | Zero outgoing call edges + zero body calls |
| LAZY_REDIRECT | Handlers that redirect instead of working | Action-verb names + redirect language + low edges |
| PLACEHOLDER | "Not implemented" functions | Zero edges + placeholder language + short body |
| TODO_FIXME | Unfinished work markers | Impact-scored by incoming edges (callers) |
| EMPTY_HANDLER | Silently swallowed errors | `_ = err` patterns in functions with outgoing calls |
| HARDCODED | Hardcoded URLs, IPs, credentials | localhost/127.0.0.1/credential patterns in body |

## After Review

Present findings to the user organized by severity (highest score first). Suggest fixes for the top issues. If the user asks, Celeste can also fix the issues directly via her agent mode.
