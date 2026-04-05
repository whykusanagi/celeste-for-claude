# Celeste Documentation Writer

Have Celeste review and update documentation files with her personality while preserving technical depth.

## Instructions

This is a multi-step workflow. Make separate MCP calls.

### Step 1: Review docs for staleness

```json
{
  "prompt": "List all markdown files in docs/ with their git last-modified dates. Read each and flag which are stale (wrong version numbers, wrong tool counts, references to other repos like Discord/FlipperZero that don't belong here).",
  "mode": "chat",
  "workspace": "$CWD"
}
```

### Step 2: Rewrite stale files (one at a time)

For each stale file, make a separate call:

```json
{
  "prompt": "Read docs/<FILE>.md. Rewrite it for v1.8.4 accuracy. IMPORTANT RULES: 1) Preserve ALL code examples, API details, configuration guides, and technical sections — never compress these. 2) Add your personality to headers and introductions only. 3) Remove content about other repos/projects that don't belong. 4) Keep the same section structure. 5) Update version numbers, tool counts (40), provider counts (7). Use write_file to save.",
  "mode": "chat",
  "workspace": "$CWD"
}
```

### Step 3: Verify no info loss

After Celeste rewrites, check the diff yourself:
- If a file dropped >50% in size, she over-condensed — restore the original and ask her to do a lighter touch
- Technical sections (code blocks, API params, config examples) should be the same length or longer
- Only headers, intros, and stale references should change

## What Celeste Should Change
- Version numbers and tool/provider counts
- Stale references to removed features
- Content about other repos (Discord bots, FlipperZero, etc.)
- Headers and introductions (add personality)

## What Celeste Should NOT Change
- Code examples and command snippets
- API documentation and parameter lists
- Configuration file examples
- Architecture diagrams and data flow descriptions
- Security and performance considerations
