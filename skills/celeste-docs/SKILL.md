---
name: celeste-docs
description: Use when MAINTAINING existing markdown docs to prevent drift — wrong versions, wrong counts, dead references. Claude probes and locates the stale lines itself, then sends Celeste one file per call with a ranged read_file and a patch_file, so large files never flood her context and surrounding content is preserved. Does NOT rewrite whole files, does NOT add persona voice to files, does NOT generate new content from stubs — for that, use celeste-content instead.
---

# Celeste Documentation Maintainer

Keep existing documentation accurate as the code changes. Claude finds the stale lines. Celeste makes one small, surgical patch per call.

**Requires celeste-cli v2.0.0+.** This skill uses the `celeste` tool in `mode: "chat"`, which needs a configured AI provider (unlike the direct `celeste_*` codegraph tools, it is not local-only). If a call errors or comes back empty, run `celeste_status` and check `health` (`"degraded"` means the latest completion failed; `completions.last_error` says why), or set a key with `celeste config --set-key <KEY>` on the command line.

**Key distinction:**
- `celeste-docs` (this skill): fixes files that already exist, one small patch at a time.
- `celeste-content`: generates new prose for stubs, empty sections or new files. It returns text and does not touch disk.

## How celeste 2.0 constrains edits

- **Read before edit.** `patch_file`, `write_file` (overwrite or append) and `splice_file` refuse an existing file that wasn't read in the same session, with `read_file <path> first: ...`. Each MCP chat call is its own session, so a read from an earlier call does not count. The read and the patch must be in the **same** `celeste` call.
- **A ranged read counts.** Any `read_file` of the file counts as the read, even a narrow `start_line`/`end_line` range. A whole-file read is never needed to edit.
- **Reads are capped, but they add up.** One `read_file` result is at most 48 KiB, and it reads at most a 512 KB prefix of the file. A capped result says `"truncated": true` and gives `total_lines`, `total_bytes` and `next_offset_line`. Several large reads in one call still fill the context, and that is how a session crashes. Keep every read small.
- **25 turns per call.** An MCP chat call stops after 25 turns, or earlier when it stalls (the same call repeated, or no progress). One file per call stays well inside that.
- **Her voice stays out of files.** In 2.0 Celeste's voice applies only to prose addressed to you. File contents, code, comments, commit messages and tool arguments are plain. Don't ask her to add personality to a doc. If you want flavoured text in a file, see "Flavoured text" below.

## Instructions

### Step 1: Probe each file (Claude, no Celeste call)

Before touching a file, check its size, type and line count:

```bash
wc -c -l docs/<FILE>.md
file docs/<FILE>.md
```

**Skip** a file, and tell the user you skipped it and why, when it is:
- binary (`file` doesn't report text);
- generated: lock files, minified files (`*.min.*`), anything under a vendored folder (`vendor/`, `node_modules/`, `third_party/`), or a file whose header says it is generated;
- larger than about **200 KB or 3,000 lines**.

Don't send a skipped file to Celeste in any form. If a skipped file is stale, report the stale lines to the user. Don't edit it.

### Step 2: Locate the exact lines (Claude)

Find what's wrong and where it is yourself. Celeste is not asked to scan or read whole docs.

```bash
grep -n "1\.9\.0" docs/<FILE>.md        # a stale version
grep -n "5 skills" docs/<FILE>.md       # a wrong count
grep -n "^## Installation" docs/<FILE>.md   # a section's heading line
```

Check each claim against the code (versions, counts, flags, file names, feature names). For each change, note the line number, the exact `<old>` text and the `<new>` text. `<old>` must be unique in the file, so include enough surrounding words.

### Step 3: Edit, one `celeste` call per file

Choose a range of about 200 lines around the change: from roughly 100 lines before the first changed line to 100 lines after the last, clamped to the file. If one file's changes are far apart, keep them in the same call: name each range (`start_line=<A1> end_line=<B1>`, then `start_line=<A2> end_line=<B2>`), each about 200 lines, and patch after the reads. If that would need more than three or four ranges, the file has drifted too far for surgical patches; report it to the user instead.

```json
{
  "prompt": "Read docs/<FILE>.md with read_file start_line=<A> end_line=<B> (only that section), then patch_file replacing `<old>` with `<new>`. Do not read the rest of the file. Do not use write_file. If read_file returns truncated: true, read a narrower range inside <A>-<B> that still contains the text; do not page through the file. Keep the new text plain: no persona voice in file contents. Report the read_file start_line, end_line, total_lines and truncated values, and the patch_file result.",
  "mode": "chat",
  "workspace": "$CWD"
}
```

Several changes in the same range can go in one prompt as several `patch_file` replacements after the one ranged read.

**Rules for every celeste-docs prompt:**
- One file per `celeste` call.
- Always a ranged `read_file` before `patch_file`, in the same call.
- Never `write_file` over an existing doc.
- If a read comes back `truncated`, narrow the range. Don't page through the file with `next_offset_line`.
- No personality, intros or persona lines in the patch text.

If the reply quotes `read_file <path> first`, the read and the patch weren't in the same call, or the read was of a different path. Send the Step 3 prompt again as one call.

### Step 4: Verify (Claude)

```bash
git diff docs/<FILE>.md
```

Check that:
- only the intended lines changed;
- every `##` heading is still there, and the code-block count is unchanged;
- the line count is within a few lines of the original.

If anything else changed, revert the file (`git checkout -- docs/<FILE>.md`) and retry with a narrower prompt. If the file shrank a lot, something overwrote it. Revert, and don't retry until you know why.

## Flavoured text (not part of the flow)

Celeste won't put her voice into files, by design. If the user wants a styled intro or tagline in a doc:
1. Generate it with `celeste_content` (see the `celeste-content` skill). Ask for it "in your own voice", or it may come back plain.
2. Review it, then insert it yourself with `Edit`.
3. Check the result with `git diff`.

Don't ask the `celeste` chat call to add it.

## Why this flow?

- **Context.** Reading a whole large file, or many files, in one call can overflow the model's context. A probe, a `grep -n` and a 200-line ranged read keep each call small.
- **Preservation.** Given a whole file, a model compresses 800 lines to 80 and loses code examples, config guides and technical depth. A single `patch_file` on a known `<old>` string leaves the rest untouched.
- **2.0's rules.** The read-before-edit check and the 25-turn cap both favour one small, self-contained call per file.

## What to change and what to keep

**Change:** outdated version numbers, wrong counts, stale references, content about unrelated projects.

**Keep:** code examples, API docs, config examples, architecture diagrams, security and performance sections.
