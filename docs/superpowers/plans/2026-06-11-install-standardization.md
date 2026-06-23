# Install Standardization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the Claude Desktop "Failed to spawn process" bug by making `celeste-for-claude` wire its own MCP server the standard way (plugin + marketplace), shipping a re-runnable installer that writes the binary's absolute path, and rewriting the docs to kill the fabricated config path.

**Architecture:** Pure additive files plus a docs rewrite, all in `celeste-for-claude`. A plugin-root `.mcp.json` auto-wires Celeste for Claude Code (PATH-relative, correct there). A `.claude-plugin/marketplace.json` makes the repo installable via `/plugin install`. A `install.sh` resolves the absolute `celeste` path and merges it into Claude Desktop's config (idempotent, backed up, symlink-safe) — the fix for GUI clients that don't inherit `PATH`. README/INSTALL.md document the correct per-client paths.

**Tech Stack:** Bash + `python3` (ubiquitous on macOS) for JSON merging; JSON config files; Markdown docs.

**Spec:** `docs/superpowers/specs/2026-06-09-install-standardization-design.md`
**Branch:** `docs/install-standardization` (already created)

---

## File Structure

```
celeste-for-claude/
  .mcp.json                                   (new — plugin self-wiring)
  .claude-plugin/
    plugin.json                               (edit — version bump 1.9.1 -> 1.10.0)
    marketplace.json                          (new — marketplace manifest)
  install.sh                                  (new — resolve abs path, merge config)
  test/
    install_test.sh                           (new — install.sh test harness)
  README.md                                   (edit — Prerequisites, Installation, Skills headers)
  INSTALL.md                                  (new — per-client install detail)
```

---

### Task 1: Plugin self-wiring (`.mcp.json`)

**Files:**
- Create: `.mcp.json`

- [ ] **Step 1: Create the plugin-root `.mcp.json`**

```json
{
  "celeste": {
    "command": "celeste",
    "args": ["serve"]
  }
}
```

PATH-relative `celeste` is correct here: Claude Code inherits the shell PATH, and this file is only consumed by the plugin (Claude Code), never by a GUI client.

- [ ] **Step 2: Validate it is well-formed JSON and has the right shape**

Run:
```bash
python3 -c 'import json;d=json.load(open(".mcp.json"));assert d["celeste"]["command"]=="celeste" and d["celeste"]["args"]==["serve"];print("ok")'
```
Expected: `ok`

- [ ] **Step 3: Commit**

```bash
git add .mcp.json
git commit -m "feat: plugin self-wires celeste MCP server via .mcp.json"
```

---

### Task 2: Marketplace manifest

**Files:**
- Create: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Create the marketplace manifest**

`source: "./"` is the verified form for a plugin that lives at the repo root (the marketplace and the plugin are the same repo).

```json
{
  "name": "celeste-for-claude",
  "owner": {
    "name": "whykusanagi",
    "url": "https://whykusanagi.xyz"
  },
  "metadata": {
    "description": "Graph-based code intelligence skills for Claude Code via MCP, powered by Celeste CLI",
    "version": "1.10.0"
  },
  "plugins": [
    {
      "name": "celeste-for-claude",
      "source": "./",
      "description": "Structural code review, semantic search, dependency analysis, project context, docs maintenance, and persona-voiced content generation via Celeste CLI's code graph.",
      "version": "1.10.0",
      "strict": true
    }
  ]
}
```

- [ ] **Step 2: Validate JSON + schema basics**

Run:
```bash
python3 -c 'import json;d=json.load(open(".claude-plugin/marketplace.json"));p=d["plugins"][0];assert d["name"]=="celeste-for-claude" and p["source"]=="./" and p["name"]=="celeste-for-claude";print("ok")'
```
Expected: `ok`

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "feat: add marketplace manifest for /plugin install"
```

---

### Task 3: Bump `plugin.json` version

**Files:**
- Modify: `.claude-plugin/plugin.json` (the `"version"` field)

- [ ] **Step 1: Edit the version field**

Change the version from `1.9.1` to `1.10.0` so `plugin.json`, `marketplace.json`, and the release tag all agree.

Old:
```json
  "version": "1.9.1",
```
New:
```json
  "version": "1.10.0",
```

- [ ] **Step 2: Verify**

Run:
```bash
python3 -c 'import json;assert json.load(open(".claude-plugin/plugin.json"))["version"]=="1.10.0";print("ok")'
```
Expected: `ok`

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/plugin.json
git commit -m "chore: bump plugin version 1.9.1 -> 1.10.0"
```

---

### Task 4: Write the `install.sh` test harness (failing first)

**Files:**
- Create: `test/install_test.sh`

The harness runs `install.sh` against a sandboxed `$HOME` with a fake `celeste`
on `PATH`, asserting merge / backup / idempotency / symlink / resolution
behavior. It is written before `install.sh` exists, so it must fail.

- [ ] **Step 1: Write the test harness**

```bash
#!/usr/bin/env bash
# Tests for install.sh. Runs it against a sandboxed $HOME with a fake celeste
# binary; asserts merge / backup / idempotency / symlink / resolution behavior.
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$HERE/install.sh"
PASS=0; FAIL=0
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
ok()   { echo "  ok:   $1"; PASS=$((PASS+1)); }

new_sandbox() {
  SBX="$(mktemp -d)"
  FAKEBIN="$SBX/fakebin"; mkdir -p "$FAKEBIN"
  printf '#!/bin/sh\necho celeste\n' > "$FAKEBIN/celeste"; chmod +x "$FAKEBIN/celeste"
  DESKTOP="$SBX/Library/Application Support/Claude/claude_desktop_config.json"
}
run() { HOME="$SBX" PATH="$FAKEBIN:$PATH" bash "$INSTALL" "$@"; }
cmd() { python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["mcpServers"]["celeste"]["command"])' "$1"; }

echo "Test 1: no binary -> non-zero exit, no config written"
new_sandbox
if HOME="$SBX" PATH="/usr/bin:/bin" bash "$INSTALL" --client claude-desktop >/dev/null 2>&1; then
  fail "expected non-zero exit when celeste missing"; else ok "exits non-zero"; fi
[ -f "$DESKTOP" ] && fail "config should not exist" || ok "no config written"

echo "Test 2: fresh write -> absolute command path + args=[serve]"
new_sandbox
run --client claude-desktop >/dev/null 2>&1
if [ -f "$DESKTOP" ]; then
  got="$(cmd "$DESKTOP")"
  case "$got" in /*) ok "absolute path: $got" ;; *) fail "not absolute: $got" ;; esac
  a="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["mcpServers"]["celeste"]["args"][0])' "$DESKTOP")"
  [ "$a" = "serve" ] && ok 'args == ["serve"]' || fail "args wrong: $a"
else fail "config not written"; fi

echo "Test 3: preserve other servers + create .bak"
new_sandbox
mkdir -p "$(dirname "$DESKTOP")"
printf '{\n  "mcpServers": {\n    "other": {"command": "x", "args": []}\n  }\n}\n' > "$DESKTOP"
run --client claude-desktop >/dev/null 2>&1
python3 -c 'import json,sys;d=json.load(open(sys.argv[1]))["mcpServers"];assert "other" in d and "celeste" in d' "$DESKTOP" \
  && ok "other preserved, celeste added" || fail "merge clobbered other server"
[ -f "$DESKTOP.bak" ] && ok ".bak created" || fail ".bak not created"

echo "Test 4: idempotent second run -> unchanged"
new_sandbox
run --client claude-desktop >/dev/null 2>&1
s1="$(shasum "$DESKTOP" | awk '{print $1}')"
out2="$(run --client claude-desktop 2>&1)"
s2="$(shasum "$DESKTOP" | awk '{print $1}')"
[ "$s1" = "$s2" ] && ok "file unchanged on rerun" || fail "file changed on rerun"
echo "$out2" | grep -q "unchanged" && ok "reports unchanged" || fail "did not report unchanged"

echo "Test 5: --dry-run writes nothing"
new_sandbox
run --client claude-desktop --dry-run >/dev/null 2>&1
[ -f "$DESKTOP" ] && fail "dry-run wrote a file" || ok "dry-run wrote nothing"

echo "Test 6: symlinked config -> refuses, target untouched"
new_sandbox
mkdir -p "$(dirname "$DESKTOP")"
real="$SBX/real.json"; printf '{"mcpServers":{}}\n' > "$real"
ln -s "$real" "$DESKTOP"
run --client claude-desktop >/dev/null 2>&1 || true
python3 -c 'import json,sys;sys.exit(0 if "celeste" not in json.load(open(sys.argv[1]))["mcpServers"] else 1)' "$real" \
  && ok "refused to write through symlink" || fail "wrote through symlink"

echo "Test 7: resolves ~/.local/bin when not on PATH"
new_sandbox
mkdir -p "$SBX/.local/bin"
printf '#!/bin/sh\necho celeste\n' > "$SBX/.local/bin/celeste"; chmod +x "$SBX/.local/bin/celeste"
out="$(HOME="$SBX" PATH="/usr/bin:/bin" bash "$INSTALL" --client claude-desktop 2>&1)" || true
echo "$out" | grep -q "/.local/bin/celeste" && ok "resolved ~/.local/bin/celeste" || fail "did not resolve ~/.local/bin: $out"

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = 0 ]
```

- [ ] **Step 2: Run the harness to verify it fails (no script yet)**

Run:
```bash
chmod +x test/install_test.sh && bash test/install_test.sh; echo "exit=$?"
```
Expected: failures / non-zero `exit=` because `install.sh` does not exist yet (bash can't read it, assertions fail).

- [ ] **Step 3: Commit the test**

```bash
git add test/install_test.sh
git commit -m "test: add install.sh sandbox test harness"
```

---

### Task 5: Implement `install.sh`

**Files:**
- Create: `install.sh`
- Test: `test/install_test.sh`

**Design decision (locked):** default client is **`claude-desktop`** only. Claude
Code is already wired by the plugin's `.mcp.json`; writing a second user-scope
`celeste` entry would duplicate the server name. Claude Code remains opt-in via
`--client claude-code` for users who install the MCP server manually instead of
the plugin.

- [ ] **Step 1: Write `install.sh`**

```bash
#!/usr/bin/env bash
# install.sh — wire the Celeste MCP server into local Claude clients using the
# binary's ABSOLUTE path, so GUI clients (which don't inherit your shell PATH)
# can launch it and the path can't go stale on reinstall. Re-run any time the
# binary moves to repair the config.
#
#   ./install.sh                            # Claude Desktop (default)
#   ./install.sh --client claude-code       # only if NOT using the plugin
#   ./install.sh --client all
#   ./install.sh --dry-run                  # show changes, write nothing
set -euo pipefail

SERVER_NAME="celeste"
CLIENT="claude-desktop"
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: ./install.sh [--client claude-desktop|claude-code|all] [--dry-run] [--help]

Resolves the absolute path to the `celeste` binary and merges a `celeste`
MCP server entry into each client config (preserving your other servers,
backing up to <file>.bak first). Default: claude-desktop. Re-run after any
reinstall to repair a stale path.

Note: Claude Code is normally wired by the celeste-for-claude plugin's
.mcp.json — only use --client claude-code / all if you register the MCP
server manually instead of installing the plugin.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --client) CLIENT="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

case "$CLIENT" in claude-desktop|claude-code|all) ;; *)
  echo "--client must be one of: claude-desktop | claude-code | all" >&2; exit 1 ;;
esac

command -v python3 >/dev/null 2>&1 || {
  echo "python3 is required (ships with macOS Command Line Tools)." >&2; exit 1; }

# Resolve celeste to an absolute, symlink-resolved path.
resolve_celeste() {
  local cand=""
  if cand="$(command -v celeste 2>/dev/null)"; then :; else
    local gp; gp="$(go env GOPATH 2>/dev/null || true)"
    if [ -n "$gp" ] && [ -x "$gp/bin/celeste" ]; then cand="$gp/bin/celeste"
    elif [ -x "$HOME/.local/bin/celeste" ]; then cand="$HOME/.local/bin/celeste"
    fi
  fi
  [ -n "$cand" ] || return 1
  python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$cand"
}

if ! CELESTE_BIN="$(resolve_celeste)"; then
  cat >&2 <<'EOF'
celeste binary not found. Install it first:
    go install github.com/whykusanagi/celeste-cli/cmd/celeste@latest   # -> ~/go/bin
  or from a celeste-cli checkout:
    make install                                                       # -> ~/.local/bin (codesigned)
  Ensure that directory is on your PATH, then re-run ./install.sh
EOF
  exit 1
fi

echo "celeste : $CELESTE_BIN"
echo "client  : $CLIENT"
echo "mode    : $([ "$DRY_RUN" = 1 ] && echo dry-run || echo write)"
echo

# Merge {command,args} into <file>.mcpServers.celeste, preserving the rest.
# Backs up to <file>.bak, refuses symlinks, idempotent.
merge_config() {
  local file="$1"
  python3 - "$file" "$CELESTE_BIN" "$DRY_RUN" "$SERVER_NAME" <<'PY'
import json, os, sys, shutil
file, binpath, dry, name = sys.argv[1], sys.argv[2], sys.argv[3] == "1", sys.argv[4]
label = file.replace(os.path.expanduser("~"), "~")
if os.path.islink(file):
    print(f"  skipped   {label} (symlink — refusing to write)"); sys.exit(0)
cfg = {}
if os.path.exists(file):
    try:
        with open(file, encoding="utf-8") as f: cfg = json.load(f)
    except Exception as e:
        print(f"  skipped   {label} (not valid JSON: {e})"); sys.exit(0)
if not isinstance(cfg, dict): cfg = {}
cfg.setdefault("mcpServers", {})
cfg["mcpServers"][name] = {"command": binpath, "args": ["serve"]}
out = json.dumps(cfg, indent=2) + "\n"
if os.path.exists(file) and open(file, encoding="utf-8").read() == out:
    print(f"  unchanged {label}"); sys.exit(0)
if dry:
    print(f"  would write {label}:")
    print("\n".join("    " + l for l in out.splitlines())); sys.exit(0)
os.makedirs(os.path.dirname(file), exist_ok=True)
if os.path.exists(file) and not os.path.exists(file + ".bak"):
    shutil.copy2(file, file + ".bak")
with open(file, "w", encoding="utf-8") as f: f.write(out)
print(f"  wrote     {label}")
PY
}

DESKTOP="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
CLAUDE_CODE="$HOME/.claude.json"

if [ "$CLIENT" = "all" ] || [ "$CLIENT" = "claude-desktop" ]; then
  echo "Claude Desktop:"; merge_config "$DESKTOP"
fi
if [ "$CLIENT" = "all" ] || [ "$CLIENT" = "claude-code" ]; then
  echo "Claude Code (user scope):"; merge_config "$CLAUDE_CODE"
fi

echo
if [ "$DRY_RUN" = 1 ]; then
  echo "Dry run — nothing written."
else
  echo "Done. Fully quit and reopen each client (Cmd-Q for Claude Desktop) to load the change."
fi
```

- [ ] **Step 2: Make it executable and run the test harness**

Run:
```bash
chmod +x install.sh && bash test/install_test.sh; echo "exit=$?"
```
Expected: all `ok:` lines, final `PASS=11 FAIL=0`, `exit=0`.

- [ ] **Step 3: Lint with shellcheck (if available)**

Run:
```bash
command -v shellcheck >/dev/null && shellcheck install.sh test/install_test.sh || echo "shellcheck not installed — skipping"
```
Expected: no warnings, or the skip message.

- [ ] **Step 4: Commit**

```bash
git add install.sh
git commit -m "feat: install.sh resolves absolute celeste path, merges client config"
```

---

### Task 6: Rewrite README sections

**Files:**
- Modify: `README.md` (Prerequisites, Installation, and the six skill headers)

- [ ] **Step 1: Replace the Prerequisites section**

Replace the block from `## Prerequisites` through the line ending the persona-key
code fence (the current lines 35–54) with:

````markdown
## Prerequisites

Install [Celeste CLI](https://github.com/whykusanagi/celeste-cli) (v1.9.0+). Two options:

```bash
# Quick: installs to ~/go/bin (must be on your PATH)
go install github.com/whykusanagi/celeste-cli/cmd/celeste@latest

# Or from a checkout: installs to ~/.local/bin and code-signs (macOS-safe)
git clone https://github.com/whykusanagi/celeste-cli.git && cd celeste-cli && make install
```

> Whichever you pick, the install directory must be on your `PATH`, and it must
> match the binary your MCP client launches. On macOS, don't `cp` over an existing
> `~/.local/bin/celeste` — that breaks its code signature; use `make install`.

Verify:
```bash
celeste version
celeste index status   # in any project directory
```

You'll need an API key configured only if you use the persona tools (xAI/Grok by
default). The direct codegraph tools (`celeste_index`, `celeste_code_search`, etc.)
run entirely locally and need no key.

```bash
celeste config --set-key YOUR_API_KEY   # only for persona tools
```
````

- [ ] **Step 2: Replace the Installation section**

Replace the block from `## Installation` through the end of the skills-install
explanation (the current lines 56–86) with:

````markdown
## Installation

### Option A — Install the plugin (recommended)

The plugin bundles the skills **and** wires the Celeste MCP server for Claude Code
automatically (no manual config):

```
/plugin marketplace add whykusanagi/celeste-for-claude
/plugin install celeste-for-claude
```

This works in Claude Code because it inherits your shell `PATH`, so the bundled
server entry (`celeste serve`) resolves on its own.

### Option B — Manual MCP registration

Use this if you're not installing the plugin, or you're on Claude **Desktop**.

**Claude Code** (CLI — inherits `PATH`):
```bash
claude mcp add celeste --scope user -- celeste serve
```

**Claude Desktop** (GUI — does **not** inherit your shell `PATH`):
Claude Desktop launches the server without your shell environment, so a bare
`celeste` won't be found — it needs the binary's **absolute** path. Run the
installer, which resolves it for you and merges it into
`~/Library/Application Support/Claude/claude_desktop_config.json`:

```bash
git clone https://github.com/whykusanagi/celeste-for-claude.git
cd celeste-for-claude
./install.sh                 # writes the absolute path; --dry-run to preview
```

It preserves any other MCP servers, backs the file up to `.bak`, and is safe to
**re-run** any time you reinstall or move the binary (it repairs the path). Then
fully quit and reopen Claude Desktop (Cmd-Q) to load it. The resulting entry looks
like:

```json
{
  "mcpServers": {
    "celeste": { "command": "/Users/you/.local/bin/celeste", "args": ["serve"] }
  }
}
```

See [INSTALL.md](INSTALL.md) for per-client detail and troubleshooting.

### Skills without the plugin

If you registered the MCP server manually and want the skills too, copy them into
your skills directory:

```bash
mkdir -p ~/.claude/skills
cp -R celeste-for-claude/skills/* ~/.claude/skills/
```
````

- [ ] **Step 3: Fix the six skill headers (remove the slash, fix the "usage" blocks)**

These are **Skills** (invoked via the Skill tool / by asking Claude), not slash
commands. For each of the six skill subsections, change the `### \`/name\` — …`
header to `### \`name\` — …` and replace its fenced ` ``` /name … ``` ` usage block
with an **Invoke:** line. Apply exactly these six replacements:

- `### \`/celeste-review\` — Graph-Based Code Review` → `### \`celeste-review\` — Graph-Based Code Review`; replace its ` ```\n/celeste-review\n``` ` block with: `**Invoke:** ask Claude to "run a Celeste code review on this project."`
- `### \`/celeste-search\` — Semantic Code Search` → `### \`celeste-search\` — Semantic Code Search`; replace its ` ```\n/celeste-search authentication token validation\n``` ` block with: `**Invoke:** ask Claude to "use Celeste to search for authentication token validation."`
- `### \`/celeste-graph\` — Dependency Analysis` → `### \`celeste-graph\` — Dependency Analysis`; replace its ` ```\n/celeste-graph\n``` ` block with: `**Invoke:** ask Claude to "analyze this project's dependencies with Celeste."`
- `### \`/celeste-context\` — Project Context Setup` → `### \`celeste-context\` — Project Context Setup`; replace its ` ```\n/celeste-context\n``` ` block with: `**Invoke:** ask Claude to "set up Celeste project context here."`
- `### \`/celeste-docs\` — Documentation Maintainer` → `### \`celeste-docs\` — Documentation Maintainer`; replace its ` ```\n/celeste-docs\n``` ` block with: `**Invoke:** ask Claude to "use Celeste to update the docs in this repo."`
- `### \`/celeste-content\` — Content Generator` → `### \`celeste-content\` — Content Generator`; replace its ` ```\n/celeste-content\n``` ` block with: `**Invoke:** ask Claude to "draft this in Celeste's voice."`

- [ ] **Step 4: Verify the fabricated path is gone and slashes are removed**

Run:
```bash
! grep -q '~/.claude/claude_desktop_config.json' README.md && echo "no fabricated path: ok"
! grep -qE '^### `/celeste-' README.md && echo "no slash headers: ok"
grep -q 'Library/Application Support/Claude/claude_desktop_config.json' README.md && echo "real desktop path present: ok"
```
Expected: three `ok` lines.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: rewrite install (per-client, absolute path, plugin-first); fix skill headers"
```

---

### Task 7: Create `INSTALL.md`

**Files:**
- Create: `INSTALL.md`

- [ ] **Step 1: Write `INSTALL.md`**

````markdown
# Installing Celeste for Claude

Celeste's code-intelligence runs as a local MCP server (`celeste serve`). How you
wire it depends on the client. The one rule that causes most breakage:

> **GUI clients (Claude Desktop, Cursor) do not inherit your shell `PATH`.** They
> need the **absolute** path to the `celeste` binary. Claude Code (CLI) inherits
> `PATH`, so a bare `celeste` works there.

## Prerequisite: install the binary

```bash
go install github.com/whykusanagi/celeste-cli/cmd/celeste@latest   # -> ~/go/bin
# or, from a checkout, macOS-safe + codesigned:
git clone https://github.com/whykusanagi/celeste-cli.git && cd celeste-cli && make install   # -> ~/.local/bin
```

Confirm it's on your `PATH`:
```bash
command -v celeste && celeste version
```

## Claude Code

**Recommended — the plugin wires it for you:**
```
/plugin marketplace add whykusanagi/celeste-for-claude
/plugin install celeste-for-claude
```

**Manual (no plugin):**
```bash
claude mcp add celeste --scope user -- celeste serve
```

## Claude Desktop

Desktop has no `mcp add` CLI and won't see your `PATH`, so use the installer to
write the absolute path:

```bash
git clone https://github.com/whykusanagi/celeste-for-claude.git
cd celeste-for-claude
./install.sh                 # default: Claude Desktop
./install.sh --dry-run       # preview without writing
```

The installer:
- resolves `celeste` to an absolute path (`command -v` → `$(go env GOPATH)/bin` → `~/.local/bin`),
- merges a `celeste` entry into
  `~/Library/Application Support/Claude/claude_desktop_config.json`,
- **preserves** your other MCP servers and backs the file up to `.bak`,
- is **idempotent** and safe to re-run to repair a stale path after a reinstall.

Then **fully quit and reopen** Claude Desktop (Cmd-Q — closing the window isn't
enough). The entry it writes:

```json
{
  "mcpServers": {
    "celeste": { "command": "/Users/you/.local/bin/celeste", "args": ["serve"] }
  }
}
```

## Troubleshooting

**`Failed to spawn process: No such file or directory`** — the configured path
points at a binary that no longer exists (e.g. you moved from `~/go/bin` to
`~/.local/bin`). Fix: re-run `./install.sh` to rewrite the absolute path, then
restart the client.

**Server connects but tools are missing** — confirm the binary works standalone:
`celeste version`, and `celeste serve` should start and wait on stdio.

**Editing the config by hand** — the file is
`~/Library/Application Support/Claude/claude_desktop_config.json` (note: under
`~/Library/...`, **not** `~/.claude/`). Use an absolute `command` path.
````

- [ ] **Step 2: Validate any JSON fences parse and the real path is referenced**

Run:
```bash
grep -q 'Library/Application Support/Claude/claude_desktop_config.json' INSTALL.md && echo "real path: ok"
! grep -q '~/.claude/claude_desktop_config.json' INSTALL.md && echo "no fabricated path: ok"
```
Expected: two `ok` lines.

- [ ] **Step 3: Commit**

```bash
git add INSTALL.md
git commit -m "docs: add INSTALL.md with per-client setup + troubleshooting"
```

---

### Task 8: Final verification

**Files:** none (verification + optional release tag)

- [ ] **Step 1: Re-run the installer tests**

Run:
```bash
bash test/install_test.sh; echo "exit=$?"
```
Expected: `PASS=11 FAIL=0`, `exit=0`.

- [ ] **Step 2: Validate every JSON file in the repo parses**

Run:
```bash
for f in .mcp.json .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
  python3 -c "import json;json.load(open('$f'));print('ok: $f')"
done
```
Expected: three `ok:` lines.

- [ ] **Step 3: Confirm the fabricated path appears nowhere**

Run:
```bash
! grep -rq '~/.claude/claude_desktop_config.json' README.md INSTALL.md && echo "clean: ok"
```
Expected: `clean: ok`

- [ ] **Step 4: Confirm working tree is committed**

Run:
```bash
git status --short
```
Expected: empty output.

- [ ] **Step 5 (optional, at release): tag the version**

Only when you're ready to publish — keeps `plugin.json` (1.10.0),
`marketplace.json` (1.10.0), and the git tag in sync:
```bash
git tag v1.10.0
```

---

## Self-Review

**Spec coverage:**
- Defect 1 (fabricated path) → Task 6 (README) + Task 7 (INSTALL.md) + verification in Tasks 6/7/8.
- Defect 2 (PATH gotcha) → documented in Task 6 Option B + Task 7; fixed mechanically by Task 5 absolute-path resolution.
- Defect 3 (install-path inconsistency) → Task 6 Step 1 (both `go install` and `make install`, codesigning note).
- Defect 4 (slash-command contradiction) → Task 6 Step 3 (all six headers).
- Defect 5 (version drift) → Task 3 (plugin.json) + Task 2 (marketplace.json) + Task 8 Step 5 (tag).
- Deliverable: plugin self-wiring → Task 1. Marketplace → Task 2. Installer → Tasks 4–5. README/INSTALL → Tasks 6–7.
- CLI-side `celeste mcp install` correctly excluded (CelesteOps task `6145b82e`).

**Placeholder scan:** No TBD/TODO; every file's full content is shown; every command has expected output.

**Type/name consistency:** `SERVER_NAME="celeste"`, the `celeste` key, `command`/`args`/`["serve"]`, and the `--client claude-desktop|claude-code|all` flag are identical across `install.sh`, the test harness, `.mcp.json`, and the docs. The test harness asserts `PASS=11` — matching its 11 `ok` assertions across 7 tests (T1:2, T2:2, T3:2, T4:2, T5:1, T6:1, T7:1).
