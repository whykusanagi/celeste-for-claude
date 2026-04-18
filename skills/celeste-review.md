# Celeste Code Review

Run Celeste's graph-based code review on the current project. Uses structural analysis of the code graph — not grep — to detect issues that pattern matching alone can't find.

**Requires celeste-cli v1.9.0+** — uses the direct `celeste_code_review` MCP tool (no chat-LLM round-trip, no output truncation).

## Instructions

This is a multi-step workflow. Make separate MCP calls for each step — do NOT use agent mode.

### Step 1: Ensure the index is current

If code has changed since the last index, update first:

```
Call celeste_index with: { "operation": "update", "workspace": "$CWD" }
```

If no index exists yet, use `"operation": "rebuild"` instead. You can check with `"operation": "status"`.

### Step 2: Run the review

Call the `celeste_code_review` MCP tool directly:

```
Call celeste_code_review with: { "kinds": "ALL", "max_results": 50, "workspace": "$CWD" }
```

This returns the raw findings as verbatim JSON — no chat-LLM summarization, no `max_tokens` ceiling. The response is the full `code_review` output exactly as Celeste computed it.

### Step 3: Verify findings

For each STUB or PLACEHOLDER finding, verify it yourself:
- Use Grep to search for the function name across all files — if callers exist, it's a false positive
- Check for build-tag file pairs (e.g., `_windows.go` + `_nonwindows.go`) with Glob
- Go `init()` functions have no callers by design — always false positive for STUB
- Functions assigned to struct fields or passed as callbacks may show zero graph edges but are actively used

### Step 4: Present to user

Report only verified findings. Classify each as:
- **REAL ISSUE** — confirmed by search, no callers, genuinely broken
- **FALSE POSITIVE** — graph missed callers, build tags, callbacks, init()
- **ACCEPTED** — known tech debt (e.g., localhost on single-machine setup)

## Categories Detected

| Category | What it finds | How (structural) |
|---|---|---|
| STUB | Dead or unfinished functions | Zero outgoing call edges + zero body calls |
| LAZY_REDIRECT | Handlers that redirect instead of working | Action-verb names + redirect language + low edges |
| PLACEHOLDER | "Not implemented" functions | Zero edges + placeholder language + short body |
| TODO_FIXME | Unfinished work markers | Impact-scored by incoming edges (callers) |
| EMPTY_HANDLER | Silently swallowed errors | `_ = err` patterns in functions with outgoing calls |
| HARDCODED | Hardcoded URLs, IPs, credentials | localhost/127.0.0.1/credential patterns in body |
