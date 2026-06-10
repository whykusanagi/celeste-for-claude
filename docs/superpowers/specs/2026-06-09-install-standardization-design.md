# Install standardization for celeste-for-claude

**Date:** 2026-06-09
**Status:** Draft — awaiting review
**Scope:** `celeste-for-claude` repo only. No `celeste-cli` changes (v1.10 shipped).
**Branch:** `docs/install-standardization`

## Problem

Celeste's MCP server stopped launching in Claude Desktop. Every attempt since
2026-06-08 fails at spawn:

```
Failed to spawn process: No such file or directory
```

### Root cause

The Claude Desktop config invoked `/Users/<user>/go/bin/celeste serve`. That
binary no longer exists — Celeste was reinstalled to `~/.local/bin` (v1.10.0)
and the old `go install` copy in `~/go/bin` was removed. The config kept
pointing at the dead path, so the Node MCP host could never spawn the Go
process. (In healthy sessions the logs show `initialize` → `tools/list`
completing; here the process never starts, so it is purely an exec-path
failure, not an MCP protocol problem.)

### Why the docs made this inevitable

`README.md` is the source of the breakage, not any single machine:

1. **Fabricated config path.** It tells users to edit
   `~/.claude/claude_desktop_config.json`. That file does not exist. Claude
   **Desktop** reads `~/Library/Application Support/Claude/claude_desktop_config.json`;
   Claude **Code** uses `claude mcp add` / `~/.claude.json`. The repo is named
   "for Claude Code" but hands users a Desktop filename in the wrong directory.
2. **PATH gotcha undocumented.** The sample config uses
   `"command": "celeste"` (PATH-relative). That resolves only where the shell
   `PATH` is inherited — Claude **Code** (CLI). GUI clients (Claude Desktop,
   Cursor) do **not** inherit the shell `PATH`, so a bare `celeste` fails and
   users hardcode an absolute path that then drifts on the next reinstall.
3. **Install-path inconsistency.** The skill README shows only
   `go install` (→ `~/go/bin`); the celeste-cli README documents both
   `go install` and `make install` (→ `~/.local/bin`, codesigned). Following
   them at different times orphans the old binary — exactly what happened.
4. **Slash-command vs Skill contradiction.** Section headers and code blocks
   present `/celeste-review` etc. as slash commands, while a later line states
   they load via the Skill tool, "not as slash commands."
5. **Version drift.** `plugin.json` = 1.9.1, latest git tag = v1.0.1, README
   badge = "v1.9.0+", celeste-cli is now 1.10.0.

## Goals

- Make the documented install path correct and client-specific (Claude Desktop
  vs Claude Code), so the fabricated-path bug cannot be copied again.
- Replace hand-editing with the **standard** Claude Code mechanism: a plugin
  that wires its own MCP server, installed via a marketplace.
- Provide a small, re-runnable installer that writes the **absolute** binary
  path for GUI clients — and that the user can re-run to repair the config
  whenever the binary moves.
- Track the permanent CLI-side fix (`celeste mcp install`) as a CelesteOps task
  for the next celeste-cli version, out of scope here.

## Non-goals (YAGNI)

- **No `celeste-cli` changes.** v1.10 shipped. The self-locating
  `celeste mcp install` subcommand and any `celeste serve` auth are tracked in
  CelesteOps task `6145b82e-2bfd-42e1-a57f-9b333fb59e03` (`celeste-cli`,
  `next-version`).
- **No `.mcpb` bundle.** celeste-ops bundles its own server binary; Celeste is
  an *external* Go binary, so an `.mcpb` would only prompt for the path the
  installer already resolves. Revisit if GUI drag-install is wanted later.
- **No token/pairing logic.** `celeste serve` is unauthenticated local stdio.
- **No MCP-registry publish.** Out of scope.

## Standards alignment

| Client | Standard mechanism | This spec |
|---|---|---|
| Claude Code (plugin) | Plugin bundles `.mcp.json`; install via marketplace | Add `.mcp.json` + `marketplace.json` |
| Claude Code (manual) | `claude mcp add` | Document it; installer can run it |
| Claude Desktop | Edit `claude_desktop_config.json` (no CLI) | Installer merges absolute path |
| Permanent path-drift fix | `<tool> mcp install` self-locating subcommand | Deferred to celeste-cli (task filed) |

## Design

Four deliverables, all inside `celeste-for-claude`.

### 1. Plugin self-wires its MCP server

Add a plugin-root `.mcp.json`:

```json
{
  "celeste": {
    "command": "celeste",
    "args": ["serve"]
  }
}
```

Verified against installed examples (`serena`, `context7` in
`claude-plugins-official`): a plugin-root `.mcp.json` of the shape
`{ "<server>": { "command", "args" } }` is registered automatically when the
plugin is enabled. PATH-relative `celeste` is **correct here** because Claude
Code inherits the shell `PATH`. Result: `/plugin install celeste-for-claude`
wires Celeste with no manual config and no path to drift.

### 2. Marketplace manifest

Add `.claude-plugin/marketplace.json` so the repo is installable via:

```
/plugin marketplace add whykusanagi/celeste-for-claude
/plugin install celeste-for-claude
```

Shape follows the verified `marketplace.json` schema (`name`, `owner`,
`metadata`, `plugins[]` with `name`/`source`/`version`). A single-plugin
marketplace pointing at this repo. This replaces the
`cp -R … ~/.claude/skills` instructions, which are not the standard
distribution path for a plugin.

### 3. Repo-local installer: `install.sh`

The short-term fix for GUI clients and the repair tool for path drift. Bash
wrapper, macOS-targeted (Celeste's codesigning story is macOS-centric), with
**no new runtime dependency** beyond what a Mac dev machine already has.

**Binary resolution (in order; first hit wins):**
1. `command -v celeste`
2. `$(go env GOPATH 2>/dev/null)/bin/celeste`
3. `~/.local/bin/celeste`

Resolve to an absolute, real path (`realpath`/`cd … && pwd`). If none found,
print the install instructions and exit non-zero — never write a config that
points at a missing binary.

**Targets:**
- `--client claude-desktop` → `~/Library/Application Support/Claude/claude_desktop_config.json`
- `--client claude-code` → prefer `claude mcp add celeste --scope user -- <abs> serve`
  when the `claude` CLI is present; else merge into `~/.claude.json` user scope.
- `--all` (default) → both, skipping any client whose config dir is absent.

**Write semantics (mirrors the safe parts of celeste-ops' installer):**
- **Merge, never clobber.** Only the `celeste` key in `mcpServers` is
  added/updated; every other server is preserved.
- **Backup** to `<file>.bak` before the first write (don't overwrite an
  existing good backup).
- **Symlink-safe.** Refuse to write through a symlinked config path.
- **Idempotent.** Re-running with an unchanged result writes nothing.
- **`--dry-run`** prints the diff and writes nothing.

The Claude Desktop JSON merge uses an embedded `python3` heredoc (python3 is
reliably present on macOS dev machines; `jq` documented as an alternative but
not required). The merged entry writes the **absolute** path:

```json
{ "mcpServers": { "celeste": { "command": "/abs/path/celeste", "args": ["serve"] } } }
```

**Re-run-to-repair:** because resolution + merge are idempotent, the user runs
`./install.sh` again after any reinstall/move and the absolute path is
corrected. This is the documented recovery for the original bug.

After writing, the script reminds the user to fully **quit and reopen** the GUI
client (Cmd-Q for Claude Desktop) so the new config loads.

### 4. README + INSTALL.md rewrite

Fix all five defects:

- **Per-client install sections**, in this priority order:
  1. **Plugin (recommended):** `/plugin marketplace add …` → `/plugin install …`.
  2. **Claude Code (manual):** `claude mcp add celeste --scope user -- celeste serve`.
  3. **Claude Desktop:** run `./install.sh --client claude-desktop` (writes the
     absolute path); show the resulting JSON and the real config location.
- **Document the PATH gotcha** explicitly: why Desktop needs an absolute path
  and Code does not; why the installer resolves it for you.
- **Align binary-install instructions** with celeste-cli: present both
  `go install` (→ `~/go/bin`, requires PATH) and `make install`
  (→ `~/.local/bin`, codesigned), with the macOS codesigning note, and state
  that whichever you pick must match what's on `PATH` / in the config.
- **Resolve the slash-command contradiction:** present the six as Skills
  (invoked via the Skill tool / by description), consistently — not as
  `/slash` commands.
- **Align versions:** bump `plugin.json`, update the README badge, and tag the
  release so `plugin.json` / tag / badge agree.

### 5. `plugin.json` bump + metadata

Bump the version (and tag the release to match), keep the existing metadata,
and ensure the plugin is consistent with the new `.mcp.json` and
`marketplace.json`.

## Affected files

```
celeste-for-claude/
  .mcp.json                                   (new — plugin self-wiring)
  .claude-plugin/
    plugin.json                               (edit — version bump)
    marketplace.json                          (new — marketplace manifest)
  install.sh                                  (new — resolve abs path, merge config)
  README.md                                   (rewrite — defects 1–5)
  INSTALL.md                                  (new — per-client install detail)
  docs/superpowers/specs/
    2026-06-09-install-standardization-design.md   (this file)
```

## Testing / verification

- **`.mcp.json` / `marketplace.json`:** valid JSON; shapes match the verified
  `serena`/`context7`/`marketplace.json` examples. Manual check: install the
  plugin in a scratch Claude Code session and confirm the `celeste` MCP server
  registers and `celeste_index` responds.
- **`install.sh`:** shellcheck-clean. Test matrix:
  - no binary present → exits non-zero with install guidance, writes nothing.
  - binary on PATH only / in `~/go/bin` only / in `~/.local/bin` only →
    resolves the right absolute path each time.
  - existing Desktop config with **other** MCP servers → those are preserved,
    `.bak` created, only `celeste` added/updated.
  - second run with no change → writes nothing (idempotent).
  - `--dry-run` → prints intended change, writes nothing.
  - symlinked config path → refuses to write.
- **Docs:** every command in README/INSTALL is copy-pasteable and the config
  paths are real. No remaining reference to `~/.claude/claude_desktop_config.json`.

## Rollback

Pure-additive plus a docs rewrite on a branch. Revert the branch to restore the
prior README; `install.sh` writes `.bak` files so any config change it makes is
recoverable.

## Follow-up (out of scope, tracked)

CelesteOps `6145b82e-2bfd-42e1-a57f-9b333fb59e03`: add `celeste mcp install`
(self-locating, `os.Executable()`) to the next celeste-cli version, then point
this README at it and retire `install.sh`.
