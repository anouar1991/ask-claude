# Ask Claude

Right-click a file or folder in GNOME Files, choose **Scripts → Ask Claude**, type what you want, and [Claude Code](https://code.claude.com) opens in a terminal at that location, already working on your request.

## Requirements

- GNOME Files (Nautilus). Tested on Nautilus 42, Ubuntu 22.04.
- `gnome-terminal`, and Python 3 with PyGObject (`python3-gi`). Both ship with Ubuntu and Fedora GNOME desktops.
- [Claude Code](https://code.claude.com/docs/en/overview) installed, with `claude` in your `PATH` or at `~/.local/bin/claude`.

## Install

```bash
git clone https://github.com/anouar1991/ask-claude.git
cd ask-claude
./install.sh
```

This copies the script to `~/.local/share/nautilus/scripts/Ask Claude`. Files watches that folder, so the Scripts menu appears right away, no restart needed.

## Use

1. Right-click a file, a folder, or the empty space inside a folder.
2. Choose **Scripts → Ask Claude**.
3. Type your request, for example *rename these photos by date* or *explain this log*. Leave it empty to just open Claude Code there.
   Tick **Just answer, no session** for a one-shot reply: Claude prints its answer in the terminal and exits (`claude -p`), and the terminal waits for a key press before closing. Nobody can approve a tool call in that mode, so it is read-only unless you also tick the next box.
   Tick **Skip permission prompts** if Claude may edit files and run commands in that folder without asking first. That is Claude Code's `--dangerously-skip-permissions`: use it only where you can afford every change it might make.
4. A terminal opens in that folder with Claude Code running. The selected paths are appended to your request.

## How it works

GNOME Files lists every executable in `~/.local/share/nautilus/scripts/` under the Scripts menu. When one runs, Files passes the selected paths in `NAUTILUS_SCRIPT_SELECTED_FILE_PATHS` and the current folder in `NAUTILUS_SCRIPT_CURRENT_URI`.

The script is a single Python file: resolve the folder, show a small GTK dialog (request, two checkboxes), then launch `gnome-terminal --working-directory=<folder> -- claude [-p] [--dangerously-skip-permissions] "<request>"`. With `-p` the call is wrapped in a shell that waits for a key, because gnome-terminal closes as soon as the command exits. It runs on `/usr/bin/python3` on purpose, because that is where the system's PyGObject lives.

## Uninstall

```bash
rm ~/.local/share/nautilus/scripts/"Ask Claude"
```

## Test

```bash
python3 tests/test_ask_claude.py
```

Unit tests for path resolution, the launched command and the installer. No GUI needed.

## Not yet supported

- Other file managers. Nemo and Caja use the same convention with `NEMO_SCRIPT_*` and `CAJA_SCRIPT_*` variables; Dolphin uses service menus.
- Other terminals such as Ptyxis, kitty or konsole.
- Remote locations (`sftp://`, `smb://`). Claude Code needs a local folder.

Pull requests welcome.

## License

[MIT](LICENSE)
