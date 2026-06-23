#!/usr/bin/env bash
# Tests for install.sh. Runs it against a sandboxed $HOME with a fake celeste
# binary; asserts merge / backup / idempotency / symlink / resolution behavior.
# No -e: tests must keep running after a `fail` to report all results.
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$HERE/install.sh"
PASS=0; FAIL=0
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
ok()   { echo "  ok:   $1"; PASS=$((PASS+1)); }

new_sandbox() {
  SBX="$(mktemp -d)"; trap 'rm -rf "$SBX"' EXIT
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

echo "Test 8: --client claude-code writes ~/.claude.json, preserves top-level keys"
new_sandbox
printf '{\n  "numStartups": 7,\n  "mcpServers": {\n    "other": {"command": "x", "args": []}\n  }\n}\n' > "$SBX/.claude.json"
run --client claude-code >/dev/null 2>&1
python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));m=d["mcpServers"];assert d.get("numStartups")==7 and "other" in m and m["celeste"]["command"].startswith("/") and m["celeste"]["args"]==["serve"]' "$SBX/.claude.json" \
  && ok "claude-code path preserves top-level keys + other servers, adds celeste" || fail "claude-code path wrong"

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = 0 ]
