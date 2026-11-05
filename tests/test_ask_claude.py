#!/usr/bin/python3
"""Unit tests for the pure parts of ask-claude. No GUI, no Claude needed:  python3 tests/test_ask_claude.py"""
import filecmp, importlib.machinery, importlib.util, os, subprocess, tempfile, unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
loader = importlib.machinery.SourceFileLoader("ask_claude", os.path.join(ROOT, "ask-claude"))
ask_claude = importlib.util.module_from_spec(importlib.util.spec_from_loader("ask_claude", loader))
loader.exec_module(ask_claude)


class Resolve(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.folder = os.path.join(self.tmp.name, "My Dir", "mé")
        os.makedirs(self.folder)
        for f in ("notes.txt", "b.txt"):
            open(os.path.join(self.folder, f), "w").close()
        self.uri = "file://" + self.tmp.name + "/My%20Dir/m%C3%A9"

    def tearDown(self):
        self.tmp.cleanup()

    def env(self, selected=None, uri=None):
        env = {"NAUTILUS_SCRIPT_CURRENT_URI": uri or self.uri}
        if selected is not None:
            env["NAUTILUS_SCRIPT_SELECTED_FILE_PATHS"] = selected
        return env

    def test_file_selected_opens_in_its_folder(self):
        t = ask_claude.resolve(self.env(os.path.join(self.folder, "notes.txt")))
        self.assertEqual(t.folder, self.folder)
        self.assertEqual(t.name, "notes.txt")
        self.assertEqual(t.selected, [os.path.join(self.folder, "notes.txt")])

    def test_folder_selected_opens_in_that_folder(self):
        t = ask_claude.resolve(self.env(self.folder, uri="file://" + self.tmp.name + "/My%20Dir"))
        self.assertEqual(t.folder, self.folder)
        self.assertEqual(t.name, "mé")

    def test_multi_select_names_the_count_and_keeps_every_path(self):
        a, b = os.path.join(self.folder, "notes.txt"), os.path.join(self.folder, "b.txt")
        t = ask_claude.resolve(self.env(a + "\n" + b))
        self.assertEqual(t.folder, self.folder)
        self.assertEqual(t.name, "2 items")
        self.assertEqual(t.selected, [a, b])

    def test_nothing_selected_decodes_percent_and_utf8_in_the_uri(self):
        t = ask_claude.resolve(self.env())
        self.assertEqual(t.folder, self.folder)
        self.assertEqual(t.name, "mé")
        self.assertEqual(t.selected, [self.folder])

    def test_remote_location_is_none(self):
        self.assertIsNone(ask_claude.resolve(self.env(uri="sftp://host/srv")))

    def test_missing_folder_is_none(self):
        self.assertIsNone(ask_claude.resolve(self.env(uri="file:///nonexistent/dir%20x")))


class Command(unittest.TestCase):
    target = ask_claude.Target(folder="/home/u/My Dir", name="notes.txt", selected=["/home/u/My Dir/notes.txt"])

    def test_launches_terminal_in_folder_with_request_and_paths(self):
        argv = ask_claude.command("/usr/bin/claude", self.target, "summarize", bypass=False)
        self.assertEqual(argv, ["gnome-terminal", "--working-directory=/home/u/My Dir", "--title=Claude · notes.txt",
                                "--", "/usr/bin/claude", "summarize\n\nSelected: /home/u/My Dir/notes.txt"])

    def test_bypass_adds_the_skip_permissions_flag_before_the_prompt(self):
        argv = ask_claude.command("/usr/bin/claude", self.target, "fix it", bypass=True)
        self.assertEqual(argv[4:], ["/usr/bin/claude", "--dangerously-skip-permissions", "fix it\n\nSelected: /home/u/My Dir/notes.txt"])

    def test_empty_request_opens_claude_there_with_no_prompt(self):
        argv = ask_claude.command("/usr/bin/claude", self.target, "", bypass=False)
        self.assertEqual(argv[4:], ["/usr/bin/claude"])

    def test_multi_select_lists_every_path(self):
        t = ask_claude.Target(folder="/d", name="2 items", selected=["/d/a", "/d/b"])
        self.assertEqual(ask_claude.command("c", t, "diff", bypass=False)[-1], "diff\n\nSelected: /d/a\n/d/b")


class FindClaude(unittest.TestCase):
    def test_found_on_path(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "claude"); open(p, "w").close(); os.chmod(p, 0o755)
            self.assertEqual(ask_claude.find_claude({"PATH": d, "HOME": "/nonexistent"}), p)

    def test_falls_back_to_local_bin(self):
        with tempfile.TemporaryDirectory() as home:
            os.makedirs(os.path.join(home, ".local", "bin"))
            p = os.path.join(home, ".local", "bin", "claude"); open(p, "w").close(); os.chmod(p, 0o755)
            self.assertEqual(ask_claude.find_claude({"PATH": "/nonexistent", "HOME": home}), p)

    def test_missing_is_none(self):
        self.assertIsNone(ask_claude.find_claude({"PATH": "/nonexistent", "HOME": "/nonexistent"}))


class Install(unittest.TestCase):
    def test_installs_executable_copy_without_restarting_files(self):
        with tempfile.TemporaryDirectory() as d:
            stub = os.path.join(d, "bin"); os.makedirs(stub)
            with open(os.path.join(stub, "nautilus"), "w") as f:
                f.write('#!/bin/sh\necho "$@" > "%s/nautilus-called"\n' % d)
            os.chmod(os.path.join(stub, "nautilus"), 0o755)
            env = {"PATH": stub + ":/usr/bin:/bin", "XDG_DATA_HOME": os.path.join(d, "data"), "HOME": d}
            r = subprocess.run([os.path.join(ROOT, "install.sh")], env=env, capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            dest = os.path.join(d, "data", "nautilus", "scripts", "Ask Claude")
            self.assertTrue(os.access(dest, os.X_OK), "not installed executable")
            self.assertTrue(filecmp.cmp(dest, os.path.join(ROOT, "ask-claude"), shallow=False), "installed copy differs")
            self.assertFalse(os.path.exists(os.path.join(d, "nautilus-called")), "install.sh must not restart Files")


if __name__ == "__main__":
    unittest.main()
