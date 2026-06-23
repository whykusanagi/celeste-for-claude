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
    --client)
      [ -n "${2:-}" ] || { echo "--client requires a value" >&2; exit 1; }
      CLIENT="$2"; shift 2 ;;
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
if not isinstance(cfg, dict):
    print(f"  skipped   {label} (unexpected JSON type: {type(cfg).__name__})"); sys.exit(0)
cfg.setdefault("mcpServers", {})
cfg["mcpServers"][name] = {"command": binpath, "args": ["serve"]}
out = json.dumps(cfg, indent=2) + "\n"
if os.path.exists(file):
    with open(file, encoding="utf-8") as f:
        if f.read() == out:
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
