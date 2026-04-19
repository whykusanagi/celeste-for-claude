---
name: celeste-content
description: Use when you have an empty stub, blank section, or need to generate new prose in Celeste's voice — blog posts, README intros, commit messages, social posts, or filling in a placeholder. Returns styled text for you to insert; does NOT write files. For maintaining or patching existing documentation, use celeste-docs instead.
---

# Celeste Content Generator

Generate new content in Celeste's voice using the `celeste_content` MCP tool. Unlike `celeste-docs` (which patches existing files in-place), this tool just returns styled text — you decide where to put it.

**Requires celeste-cli v1.9.0+** — uses the direct `celeste_content` MCP tool.

## When to use this vs celeste-docs

| Situation | Skill |
|---|---|
| File exists, content is stale — patch a section without losing surrounding text | `celeste-docs` |
| File exists but has a stub / TODO / empty section you need to fill | `celeste-content` + write the result yourself |
| File doesn't exist yet — draft a README, blog post, commit message, social post | `celeste-content` + write the result yourself |
| You want Celeste to edit a file directly with surgical patches | `celeste-docs` (uses patch_file via persona) |
| You just want text back | `celeste-content` |

The distinction: **`celeste-content` generates. `celeste-docs` maintains.**

## Instructions

### Step 1: Identify the gap

Locate the stub, blank section, or new file you need content for. Examples:
- `## Installation\n\nTODO` — a stub heading
- Missing README intro paragraph
- Need a commit message describing a diff
- Need a blog-post-style write-up of a feature

### Step 2: Call `celeste_content`

```
Call celeste_content with: { "prompt": "<WHAT_TO_GENERATE>", "format": "markdown" }
```

- `prompt` (required): Describe what to generate. Include context the tool can't see (e.g., "for a graph-based code review tool called Celeste, which detects stubs and swallowed errors via call-graph analysis").
- `format`: `"markdown"` (default), `"plain"`, or `"html"`. Choose based on the destination file.

**Note:** Unlike the codegraph tools (`celeste_code_search`, `celeste_index`, etc.), `celeste_content` does **not** take a `workspace` parameter — it generates standalone prose, not workspace-specific queries.

If the call errors or returns empty, the persona provider (xAI/Grok by default) is likely misconfigured. Run `celeste_status` to confirm providers are loaded, or re-run `celeste config --set-key <KEY>` on the command line.

The response is the generated text — already styled in Celeste's persona voice.

### Step 3: Insert into destination

Use `Edit` (to fill a stub in an existing file) or `Write` (to create a new file) to place the generated text.

**Do NOT re-ask Celeste to write the file for you** — that would bypass your review. Read the output, judge it, then write.

### Step 4: Verify

- Does the tone match surrounding content (if inserting into an existing file)?
- Are technical facts correct? Celeste's persona tool has a chat LLM behind it — facts can drift. Verify any API names, version numbers, or claims.
- Is the length appropriate for the slot? Ask for a shorter/longer regeneration if needed.

## Example Prompts

**Filling a stub README section:**
```
Generate a markdown "## How It Works" section for celeste-for-claude — a Claude Code MCP plugin that exposes Celeste CLI's graph-based code intelligence. Mention the 5 skills (review, search, graph, context, docs) and that they use direct MCP tools without LLM round-trip. Keep it under 200 words.
```

**Commit message:**
```
Write a conventional-commits style git commit message (format: plain) for a change that restructures the repo to match SkillsMP's path pattern: skills/<name>/SKILL.md plus .claude-plugin/plugin.json.
```

**Blog post draft:**
```
Draft a 500-word markdown blog post about why graph-based code review finds bugs that grep misses — specifically stubs (zero-edge functions) and swallowed errors (_ = err with outgoing calls). Audience: mid-level developers on a team adopting Celeste.
```

## Why Not Just Use Claude?

You can. But `celeste_content` has two advantages:
1. **Persona consistency** — all Celeste-flavored content has the same voice, which matters for docs/social posts under a single brand.
2. **Separation of concerns** — content generation uses Celeste's chat LLM; Claude Code stays clean for orchestration, editing, and verification.

If you want generic content, Claude Code handles it directly.
