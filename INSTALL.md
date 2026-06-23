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
`~/.local/bin`). Fix: re-run `./install.sh` to rewrite the absolute path, then
restart the client.

**Server connects but tools are missing** — confirm the binary works standalone:
`celeste version`, and `celeste serve` should start and wait on stdio.

**Editing the config by hand** — the file is
`~/Library/Application Support/Claude/claude_desktop_config.json` (note: under
`~/Library/...`, **not** `~/.claude/`). Use an absolute `command` path.
