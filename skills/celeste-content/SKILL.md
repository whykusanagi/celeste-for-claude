---
name: celeste-content
description: Use when you have an empty stub, blank section, or need to generate new prose — blog posts, social posts and README intros in Celeste's voice, or plain commit messages, or filling in a placeholder. Returns text for you to insert; does NOT write files. In celeste 2.0 commit messages and file content come back plain by design. For maintaining or patching existing documentation, use celeste-docs instead.
---

# Celeste Content Generator

Generate new content in Celeste's voice using the `celeste_content` MCP tool. Unlike `celeste-docs` (which patches existing files in-place), this tool just returns text — you decide where to put it. Prose addressed to readers comes back in her voice; commit messages and file content come back plain (see "Plain by design").

**Requires celeste-cli v2.0.0+** — uses the direct `celeste_content` MCP tool.

## When to use this vs celeste-docs

| Situation | Skill |
|---|---|
| File exists, content is stale — patch a section without losing surrounding text | `celeste-docs` |
| File exists but has a stub / TODO / empty section you need to fill | `celeste-content` + write the result yourself |
| File doesn't exist yet — draft a README, blog post, commit message, social post | `celeste-content` + write the result yourself |
| You want Celeste to edit a file directly with surgical patches | `celeste-docs` (ranged read_file, then patch_file) |
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

**Note:** Unlike the codegraph tools (`celeste_code_search`, `celeste_index`, etc.), `celeste_content` does **not** take a `workspace` parameter. The only project context it adds is the `.grimoire` of the directory the MCP server was started in, not your current project's. If project-specific facts matter, put them in the prompt.

If the call errors or returns empty, the provider is likely misconfigured. The default model is Sakana's `fugu`. Run `celeste_status` and check `health`: `"degraded"` means the latest completion failed, and `completions.last_error` says why. To fix a key, run `celeste config --set-key <KEY>` on the command line.

The response is the generated text, styled in Celeste's persona voice. Text that is itself file content or a commit message comes back plain (see "Plain by design" below).

### Step 3: Insert into the destination

Use `Edit` (to fill a stub in an existing file) or `Write` (to create a new file) to place the generated text.

**Do NOT re-ask Celeste to write the file for you** — that would bypass your review. Read the output, judge it, then write.

### Step 4: Verify

- Does the tone match surrounding content (if inserting into an existing file)?
- Are technical facts correct? Celeste's persona tool has a chat LLM behind it — facts can drift. Verify any API names, version numbers, or claims.
- Is the length appropriate for the slot? Ask for a shorter/longer regeneration if needed.

## Example Prompts

**Filling a stub README section:**
```
Generate a markdown "## How It Works" section for celeste-for-claude, a Claude Code MCP plugin that exposes Celeste CLI's graph-based code intelligence. Mention the 6 skills (review, search, graph, context, docs, content) and that the code-intelligence skills use direct MCP tools with no LLM round-trip. Keep it under 200 words.
```

**Commit message:**
```
Write a conventional-commits style git commit message (format: plain) for a change that restructures the repo to match SkillsMP's path pattern: skills/<name>/SKILL.md plus .claude-plugin/plugin.json.
```
The message comes back plain and professional, with no persona voice. That is by design in 2.0 (see below), not a misconfiguration.

**Blog post draft:**
```
Draft a 500-word markdown blog post about why graph-based code review finds bugs that grep misses — specifically stubs (zero-edge functions) and swallowed errors (_ = err with outgoing calls). Audience: mid-level developers on a team adopting Celeste.
```

## Why Not Just Use Claude?

You can. But `celeste_content` has two advantages:
1. **Persona consistency**: all Celeste-flavored content has the same voice, which matters for docs and social posts under a single brand. In celeste 2.0 the full voice needs an official release binary. A build from a checkout or a fork runs a short public persona. `celeste persona verify` prints `official persona: ...` and exits 0 on an official build.
2. **Separation of concerns** — content generation uses Celeste's chat LLM; Claude Code stays clean for orchestration, editing, and verification.

If you want generic content, Claude Code handles it directly.

## Plain by design

celeste 2.0 has a **voice boundary**: her voice applies only to prose addressed to a person. Code, comments, commit messages, file contents and tool arguments come back plain and professional. So:
- a commit message, a code comment or a config snippet comes back plain;
- a social post or a blog post addressed to readers keeps her voice;
- text meant for a file, such as a README intro, usually comes back plain. If you want it flavoured, say so: "in your own voice, write ...";
- the `celeste` chat tool won't put her voice into a file, so `celeste-docs` never asks it to. Generate flavoured text here and insert it yourself.
