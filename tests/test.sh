#!/bin/bash
# Runs ask-claude and install.sh against stubbed zenity / gnome-terminal / claude / nautilus
# and checks what would have been launched. No GUI needed:  bash tests/test.sh
set -eu
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export STUB_DIR="$tmp"

stub="$tmp/bin"; mkdir -p "$stub"
cat > "$stub/zenity" <<'STUB'
#!/bin/bash
case "$1" in
  --entry) printf '%s\n' "$*" > "$STUB_DIR/entry"; [ -n "${STUB_CANCEL:-}" ] && exit 1; printf '%s\n' "${STUB_ANSWER-}" ;;
  --error) printf '%s\n' "$*" > "$STUB_DIR/error" ;;
esac
STUB
printf '#!/bin/bash\nprintf "%%s\\0" "$@" > "$STUB_DIR/launch"\n' > "$stub/gnome-terminal"
printf '#!/bin/bash\nprintf "%%s\\n" "$*" > "$STUB_DIR/nautilus"\n' > "$stub/nautilus"
printf '#!/bin/bash\n' > "$stub/claude"
chmod +x "$stub"/*
noclaude="$tmp/bin-noclaude"; mkdir -p "$noclaude"; ln -s "$stub/zenity" "$stub/gnome-terminal" "$noclaude/"
export PATH="$stub:$PATH"

dir="$tmp/My Dir/mé"; mkdir -p "$dir"; touch "$dir/notes.txt" "$dir/b.txt"
uri="file://$tmp/My%20Dir/m%C3%A9"

fail=0
check() { if [ "$2" == "$3" ]; then echo "ok   $1"; else echo "FAIL $1"; printf '  want: %q\n  got:  %q\n' "$2" "$3"; fail=1; fi; }
run() { rm -f "$tmp/launch" "$tmp/error" "$tmp/entry"; rc=0; env "$@" "$root/ask-claude" || rc=$?; }
arg() { [ -f "$tmp/launch" ] || return 0; mapfile -d '' -t a < "$tmp/launch"; printf '%s' "${a[$1]}"; }
nargs() { [ -f "$tmp/launch" ] || { printf 0; return; }; mapfile -d '' -t a < "$tmp/launch"; printf '%s' "${#a[@]}"; }

run NAUTILUS_SCRIPT_SELECTED_FILE_PATHS="$dir/notes.txt" NAUTILUS_SCRIPT_CURRENT_URI="$uri" STUB_ANSWER="summarize"
check "file selected: terminal opens in its folder"  "--working-directory=$dir" "$(arg 0)"
check "file selected: runs the claude found in PATH"  "$stub/claude" "$(arg 3)"
check "file selected: prompt = request + selected path" "summarize"$'\n\n'"Selected: $dir/notes.txt" "$(arg 4)"
check "file selected: exit 0" 0 "$rc"

touch "$dir/my_file.txt"
run NAUTILUS_SCRIPT_SELECTED_FILE_PATHS="$dir/my_file.txt" NAUTILUS_SCRIPT_CURRENT_URI="$uri" STUB_ANSWER="x"
check "underscore in name: escaped for zenity, which treats _ as a mnemonic" "yes" "$(grep -q 'my__file.txt' "$tmp/entry" && echo yes)"

run NAUTILUS_SCRIPT_SELECTED_FILE_PATHS="$dir" NAUTILUS_SCRIPT_CURRENT_URI="file://$tmp/My%20Dir" STUB_ANSWER="x"
check "folder selected: terminal opens in that folder" "--working-directory=$dir" "$(arg 0)"

run NAUTILUS_SCRIPT_SELECTED_FILE_PATHS="$dir/notes.txt"$'\n'"$dir/b.txt" NAUTILUS_SCRIPT_CURRENT_URI="$uri" STUB_ANSWER="diff"
check "multi-select: prompt lists every path" "diff"$'\n\n'"Selected: $dir/notes.txt"$'\n'"$dir/b.txt" "$(arg 4)"

run -u NAUTILUS_SCRIPT_SELECTED_FILE_PATHS NAUTILUS_SCRIPT_CURRENT_URI="$uri" STUB_ANSWER="tidy"
check "nothing selected: %20 and UTF-8 in the URI decode to the folder" "--working-directory=$dir" "$(arg 0)"
check "nothing selected: prompt names the folder" "tidy"$'\n\n'"Selected: $dir" "$(arg 4)"

run NAUTILUS_SCRIPT_SELECTED_FILE_PATHS="$dir/notes.txt" NAUTILUS_SCRIPT_CURRENT_URI="$uri" STUB_CANCEL=1
check "cancelled dialog: nothing launched" "" "$(ls "$tmp/launch" 2>/dev/null)"
check "cancelled dialog: exit 0" 0 "$rc"

run NAUTILUS_SCRIPT_SELECTED_FILE_PATHS="$dir/notes.txt" NAUTILUS_SCRIPT_CURRENT_URI="$uri" STUB_ANSWER=""
check "empty request: claude opens there with no prompt" 4 "$(nargs)"

run -u NAUTILUS_SCRIPT_SELECTED_FILE_PATHS NAUTILUS_SCRIPT_CURRENT_URI="sftp://host/srv" STUB_ANSWER="x"
check "remote location: error dialog shown" "--error" "$(head -1 "$tmp/error" | cut -d' ' -f1)"
check "remote location: nothing launched" "" "$(ls "$tmp/launch" 2>/dev/null)"
check "remote location: exit 1" 1 "$rc"

run HOME="$tmp" PATH="$noclaude:/usr/bin:/bin" NAUTILUS_SCRIPT_SELECTED_FILE_PATHS="$dir/notes.txt" NAUTILUS_SCRIPT_CURRENT_URI="$uri" STUB_ANSWER="x"
check "claude missing: error dialog shown" "--error" "$(head -1 "$tmp/error" | cut -d' ' -f1)"
check "claude missing: exit 1" 1 "$rc"

rc=0; XDG_DATA_HOME="$tmp/data" "$root/install.sh" >/dev/null || rc=$?
check "install: script lands in the Nautilus scripts folder, executable" "yes" "$([ -x "$tmp/data/nautilus/scripts/Ask Claude" ] && echo yes)"
check "install: identical to the repo file" "" "$(cmp "$root/ask-claude" "$tmp/data/nautilus/scripts/Ask Claude" 2>&1)"
check "install: does not restart Files (it watches the scripts folder; -q would close the user's windows)" "" "$(cat "$tmp/nautilus" 2>/dev/null)"
check "install: exit 0" 0 "$rc"

[ "$fail" -eq 0 ] && echo "ALL PASS" || { echo "FAILURES"; exit 1; }
