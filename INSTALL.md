# Installing Celeste for Claude

Celeste's code-intelligence runs as a local MCP server (`celeste serve`). How you
wire it depends on the client. The one rule that causes most breakage:

> **GUI clients (Claude Desktop, Cursor) do not inherit your shell `PATH`.** They
> need the **absolute** path to the `celeste` binary. Claude Code (CLI) inherits
> `PATH`, so a bare `celeste` works there.

## Prerequisite: install the binary

This plugin needs celeste-cli **v2.0.0+**. 2.0's Go module path ends in `/v2`;
the old path without it still installs the last 1.x release. (On celeste-cli
1.x, use companion v1.11.0; see the README's Versions table.)

```bash
# Recommended (Go 1.26+): -> ~/go/bin
go install github.com/whykusanagi/celeste-cli/v2/cmd/celeste@latest
# No Go: a signed binary from https://github.com/whykusanagi/celeste-cli/releases
#   (verify it as described in celeste-cli's VERIFY.md)
```

`make install` from a celeste-cli checkout (-> `~/.local/bin`, codesigned) is
for contributors: it runs the public persona and never upgrades itself to the
official binary.

Confirm it's on your `PATH`, and (for a `go install` build) install the official
binary before an MCP client launches it, since `celeste serve` doesn't replace
itself mid-run:
```bash
command -v celeste && celeste version   # Celeste CLI 2.x.y ...
celeste update
celeste persona verify                  # exits 0 on an official build
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
celeste mcp install --client claude-desktop             # Claude Desktop only
celeste mcp install --client claude-desktop --dry-run   # preview without writing
```

It resolves the running binary's absolute path and merges a `celeste` entry into
`~/Library/Application Support/Claude/claude_desktop_config.json`, preserving
your other MCP servers. It backs the file up to `.bak`, writes it readable by
you only (0600), never writes through a symlink, and is safe to re-run to
repair a stale path after a reinstall.

> Pass `--client claude-desktop`. A bare `celeste mcp install` defaults to
> `--client all`: it also writes Claude Code's `~/.claude.json`, Cursor's
> config and `~/.celeste/mcp.json` for every client installed. If you use the
> plugin, that Claude Code entry duplicates the plugin's server.

Then **fully quit and reopen** Claude Desktop (Cmd-Q — closing the window isn't
enough). The entry it writes:

```json
{
  "mcpServers": {
    "celeste": { "command": "/Users/you/.local/bin/celeste", "args": ["serve"] }
  }
}
```

**Alternative: this repo's installer.** `./install.sh` predates
`celeste mcp install` and does the same for Claude Desktop:

```bash
git clone https://github.com/whykusanagi/celeste-for-claude.git
cd celeste-for-claude
./install.sh                 # default: Claude Desktop
./install.sh --dry-run       # preview without writing
```

It resolves `celeste` to an absolute path (`command -v` → `$(go env GOPATH)/bin`
→ `~/.local/bin`), refuses a celeste older than 2.0, and merges the same entry,
preserving your other servers, backing up to `.bak` and refusing symlinks.

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
`~/.local/bin`). Fix: re-run `celeste mcp install --client claude-desktop` (or
`./install.sh`) to rewrite the absolute path, then restart the client.

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
celeste version    # e.g. Celeste CLI 2.0.0 (bubbletea-tui) [df2896d]
```

If the two differ, the server is stale — **fully restart the client** (Cmd-Q on
Claude Desktop; exit and relaunch Claude Code). Re-running `celeste mcp install`
will not help: it rewrites config, and the stale process is already running.

This is expected once after a fresh `go install`: the first CLI command you run
(`celeste update`, or anything but `help`, `version` and `persona`) swaps the
binary for the official signed release, but `celeste serve` never replaces
itself mid-run. A server the client started before that keeps running the
`go install` build, with the public persona, until you restart the client.

> The `version` field alone can't show this: it is a release constant and reads
> the same for a shipped release and a local build many commits ahead. If
> `commit` is `unknown`, the binary was built without a stamp (a bare
> `go build` rather than `make install` or a release download).

**Two `celeste` binaries on your PATH** — `which -a celeste` shows them. A
leftover `~/go/bin/celeste` from an old `go install` can shadow, or be shadowed
by, `~/.local/bin/celeste`, so a direct CLI call and the MCP server can end up
running different builds. `celeste mcp install` writes an **absolute** path,
which makes the MCP side immune to PATH order; delete the stale copy to fix the
CLI side.

**Editing the config by hand** — the file is
`~/Library/Application Support/Claude/claude_desktop_config.json` (note: under
`~/Library/...`, **not** `~/.claude/`). Use an absolute `command` path.

**Call edges look wrong outside Go** — check that the binary has the
tree-sitter parsers: `celeste index selfcheck` prints
`tree-sitter: ok (typescript, php, python, java)`. A build with
`CGO_ENABLED=0` (or without a C compiler) fails that check and falls back to
regex parsing. Release binaries include tree-sitter; an index built by 1.x
needs one `celeste index rebuild` to use it.

**celeste's own chat keeps skipping this repo's `.mcp.json`** — when you run
`celeste` inside a checkout of this repo, its chat asks before starting a
server from the repo's `.mcp.json`, and remembers a "no" until the server's
command, args, env or URL change. `celeste mcp list` shows each server's
status; `celeste mcp untrust celeste` forgets the decision so it asks again
(`celeste mcp trust celeste` approves it). The plugin's server in Claude Code
is not affected.

## Remote clients (SSE)

`celeste serve` uses stdio by default, which is what the plugin and the configs
above use. `celeste serve --sse` serves over HTTP on `127.0.0.1:8420`
(`--port N` to change it) and requires the bearer token stored in
`~/.celeste/server.token`. `--remote` binds to all interfaces and needs TLS:
pass `--cert <file>` and `--key <file>`, or it refuses to start. The server
accepts at most 16 open event streams and 1 MiB per request body.
