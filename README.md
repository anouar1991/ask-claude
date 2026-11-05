# Ask Claude

Right-click a file or folder in GNOME Files, choose **Scripts → Ask Claude**, type what you want, and [Claude Code](https://code.claude.com) opens in a terminal at that location, already working on your request.

## Requirements

- GNOME Files (Nautilus). Tested on Nautilus 42, Ubuntu 22.04.
- `gnome-terminal` and `zenity`. Both ship with Ubuntu GNOME.
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
4. A terminal opens in that folder with Claude Code running. The selected paths are appended to your request.

## How it works

GNOME Files lists every executable in `~/.local/share/nautilus/scripts/` under the Scripts menu. When one runs, Files passes the selected paths in `NAUTILUS_SCRIPT_SELECTED_FILE_PATHS` and the current folder in `NAUTILUS_SCRIPT_CURRENT_URI`.

The script is about 25 lines of bash: resolve the folder, ask with `zenity --entry`, then launch `gnome-terminal --working-directory=<folder> -- claude "<request>"`.

## Uninstall

```bash
rm ~/.local/share/nautilus/scripts/"Ask Claude"
```

## Test

```bash
bash tests/test.sh
```

Runs the script against stubbed `zenity`, `gnome-terminal` and `claude`. No GUI needed.

## Not yet supported

- Other file managers. Nemo and Caja use the same convention with `NEMO_SCRIPT_*` and `CAJA_SCRIPT_*` variables; Dolphin uses service menus.
- Other terminals such as Ptyxis, kitty or konsole.
- Remote locations (`sftp://`, `smb://`). Claude Code needs a local folder.

Pull requests welcome.

## License

[MIT](LICENSE)
