# Installing Celeste for Claude

Celeste's code-intelligence runs as a local MCP server (`celeste serve`). How you
wire it depends on the client. The one rule that causes most breakage:

> **GUI clients (Claude Desktop, Cursor) do not inherit your shell `PATH`.** They
> need the **absolute** path to the `celeste` binary. Claude Code (CLI) inherits
> `PATH`, so a bare `celeste` works there.

## Prerequisite: install the binary

This plugin needs celeste-cli **v2.0.0+**. 2.0's Go module path ends in `/v2`;
the old path without it still installs the last 1.x release.

```bash
go install github.com/whykusanagi/celeste-cli/v2/cmd/celeste@latest   # -> ~/go/bin
# or a signed binary from https://github.com/whykusanagi/celeste-cli/releases
#   (verify it as described in celeste-cli's VERIFY.md)
# or, from a checkout, macOS-safe + codesigned:
git clone https://github.com/whykusanagi/celeste-cli.git && cd celeste-cli && make install   # -> ~/.local/bin
```

Confirm it's on your `PATH`, and (for a `go install` build) install the official
binary before an MCP client launches it, since `celeste serve` doesn't replace
itself mid-run:
```bash
command -v celeste && celeste version   # 2.x
celeste update
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

Desktop has no `mcp add` CLI and won't see your `PATH`, so the config needs the
absolute path. celeste writes it itself:

```bash
celeste mcp install --client claude-desktop   # --dry-run to preview
```

Or use this repo's installer, which does the same:

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

## Verify it connected

**Claude Code:**
```bash
claude mcp list   # celeste should show "✔ Connected"
```

**Claude Desktop:** after the Cmd-Q restart, open a chat and check the tools/MCP
menu — `celeste` and its `celeste_*` tools should be listed. If the server failed
to start, Desktop shows it as disconnected there.

## Troubleshooting

**`Failed to spawn process: No such file or directory`** — the configured path
points at a binary that no longer exists (e.g. you moved from `~/go/bin` to
`~/.local/bin`). Fix: re-run `celeste mcp install` (or `./install.sh`) to rewrite the absolute path, then
restart the client.

**Server connects but tools are missing** — confirm the binary works standalone:
`celeste version`, and `celeste serve` should start and wait on stdio.

**Tools work but behave like an older version** — the most common and least
obvious failure. Your MCP client spawns the server **once** and keeps that
process alive, so reinstalling the binary does not touch an already-running
server. The config can point at a brand-new binary while the live process is
weeks old.

Ask Celeste for `celeste_status` and compare the `commit` it reports against the
binary you installed:

```bash
celeste version    # e.g. Celeste CLI 1.15.0 (bubbletea-tui) [v1.15.0-3-g4078dec]
```

If the two differ, the server is stale — **fully restart the client** (Cmd-Q on
Claude Desktop; exit and relaunch Claude Code). Re-running `celeste mcp install`
will not help: it rewrites config, and the stale process is already running.

> Requires celeste **v1.15.0+**. Older builds report only a version string, which
> is a release constant — it reads identically for a shipped release and a local
> build many commits ahead, so a stale server is invisible there. If `commit` is
> missing or `unknown`, the binary was built without a stamp (a bare `go build`
> rather than `make install` or a release download).

**Two `celeste` binaries on your PATH** — `which -a celeste` shows them. A
leftover `~/go/bin/celeste` from an old `go install` can shadow, or be shadowed
by, `~/.local/bin/celeste`, so a direct CLI call and the MCP server can end up
running different builds. `celeste mcp install` writes an **absolute** path,
which makes the MCP side immune to PATH order; delete the stale copy to fix the
CLI side.

**Editing the config by hand** — the file is
`~/Library/Application Support/Claude/claude_desktop_config.json` (note: under
`~/Library/...`, **not** `~/.claude/`). Use an absolute `command` path.
