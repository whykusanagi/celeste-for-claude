---
name: celeste-docs
description: Use when MAINTAINING existing markdown docs to prevent drift — detects stale versions, wrong counts, dead references, then patches section-by-section via Celeste's persona tool so surrounding content, code examples, and technical depth are preserved. Does NOT rewrite whole files, does NOT generate new content from stubs — for that, use celeste-content instead.
---

# Celeste Documentation Maintainer

Keep existing documentation honest as the code underneath it evolves. This skill scans markdown files for staleness (wrong versions, dead references, summarized-away technical content) and applies surgical per-section patches.

**Key distinction:**
- `celeste-docs` (this skill) — maintains files that already exist, preventing drift and destructive rewrites
- `celeste-content` — generates new prose for stubs, empty sections, or fresh files (does not touch disk itself)

## Instructions

### Step 1: Review for staleness

Call celeste to scan the docs directory:

```json
{
  "prompt": "List all markdown files in docs/ with their modification dates. Read each and identify which have outdated information — wrong version numbers, incorrect feature counts, references to features that no longer exist, or content about unrelated projects. List specific issues per file.",
  "mode": "chat",
  "workspace": "$CWD"
}
```

### Step 2: Update section by section

For each stale file, do NOT ask Celeste to rewrite the whole file. Instead, process individual sections. For each section that needs updating:

```json
{
  "prompt": "Read docs/<FILE>.md. Use patch_file to update the section '## <SECTION>' — fix outdated facts, add a personality line after the heading. Do NOT rewrite the entire file. Do NOT remove code examples or technical details. Only patch the specific text that is wrong.",
  "mode": "chat",
  "workspace": "$CWD"
}
```

### Step 3: Add personality to title

```json
{
  "prompt": "Use patch_file to update only the title and first paragraph of docs/<FILE>.md — add personality. Do not touch anything else.",
  "mode": "chat",
  "workspace": "$CWD"
}
```

### Step 4: Verify

After all patches, verify yourself:
- Line count should be within 10% of original
- All ## headings should still exist
- Code block count should be unchanged
- If a file shrank dramatically, Celeste used write_file instead of patch_file — revert and retry

## Why Section-by-Section?

When given an entire file, Celeste will compress 800 lines to 80 — losing code examples, config guides, and technical depth. By patching one section at a time, each update is surgical and preserves surrounding content.

## Guidelines for Celeste

**Change:** Outdated version numbers, wrong counts, stale references, content about unrelated projects

**Preserve:** Code examples, API docs, config examples, architecture diagrams, security/performance sections

**Personality:** Headers and intros only — not inside code blocks or technical explanations
