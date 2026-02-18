from __future__ import annotations

import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[5]
SCRIPTS_DIR = REPO_ROOT / ".codex" / "skills" / "fpga-vivado-vitis-structure" / "scripts"
QUERY_DOC = SCRIPTS_DIR / "query_doc.py"
BUILD_DB = SCRIPTS_DIR / "build_skill_db.py"
QUERY_DB = SCRIPTS_DIR / "query_skill_db.py"
NEW_NOTE = SCRIPTS_DIR / "new_codex_note.py"


def run_cmd(args: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        cwd=str(cwd or REPO_ROOT),
        text=True,
        capture_output=True,
        check=False,
    )


class TestSkillScripts(unittest.TestCase):
    def test_query_doc_all_sof(self) -> None:
        proc = run_cmd(["python3", str(QUERY_DOC), "--doc", "all", "SOF", "--max-results", "1"])
        self.assertEqual(proc.returncode, 0, msg=proc.stderr)
        self.assertIn("[ug934]", proc.stdout)

    def test_query_doc_ug835_fallback_to_chapters(self) -> None:
        proc = run_cmd(
            [
                "python3",
                str(QUERY_DOC),
                "--doc",
                "all",
                "--docs",
                "ug835",
                "open_run",
                "--max-results",
                "1",
            ]
        )
        self.assertEqual(proc.returncode, 0, msg=proc.stderr)
        self.assertIn("[ug835][chapter]", proc.stdout)
        self.assertIn("falling back to chapters", proc.stderr.lower())

    def test_build_db_and_query_flows(self) -> None:
        db_path = Path("/tmp/skill_knowledge_test.sqlite")

        build = run_cmd(
            [
                "python3",
                str(BUILD_DB),
                "--db",
                str(db_path),
                "--docs",
                "all",
                "--rtl-root",
                "rtl",
                "--recreate",
            ]
        )
        self.assertEqual(build.returncode, 0, msg=build.stderr)
        self.assertRegex(build.stdout, r"documents:\s+[1-9]")
        self.assertRegex(build.stdout, r"amd_segments:\s+[1-9]")
        self.assertRegex(build.stdout, r"vhdl_files:\s+[1-9]")

        amd = run_cmd(
            [
                "python3",
                str(QUERY_DB),
                "--db",
                str(db_path),
                "amd",
                "--query",
                "project mode",
                "--docs",
                "ug892",
                "--limit",
                "1",
            ]
        )
        self.assertEqual(amd.returncode, 0, msg=amd.stderr)
        self.assertIn("[ug892]", amd.stdout)

        vhdl = run_cmd(
            [
                "python3",
                str(QUERY_DB),
                "--db",
                str(db_path),
                "vhdl",
                "--pattern",
                "library.nonstd_numeric_disallowed",
            ]
        )
        self.assertEqual(vhdl.returncode, 0, msg=vhdl.stderr)
        self.assertTrue("No VHDL matches." in vhdl.stdout or "library.nonstd_numeric_disallowed" in vhdl.stdout)

        attr = run_cmd(
            [
                "python3",
                str(QUERY_DB),
                "--db",
                str(db_path),
                "attr",
                "--query",
                "stable",
                "--limit",
                "1",
            ]
        )
        self.assertEqual(attr.returncode, 0, msg=attr.stderr)
        self.assertIn("stable", attr.stdout.lower())

    def test_new_codex_note_format(self) -> None:
        with tempfile.TemporaryDirectory(prefix="codex_note_test_") as tmp:
            tmp_path = Path(tmp)
            proc = run_cmd(
                [
                    "python3",
                    str(NEW_NOTE),
                    "--category",
                    "Research",
                    "--type",
                    "Report",
                    "--label",
                    "smoke",
                ],
                cwd=tmp_path,
            )
            self.assertEqual(proc.returncode, 0, msg=proc.stderr)
            rel_path = proc.stdout.strip()
            self.assertTrue(rel_path.startswith(".codex/"))
            note_name = Path(rel_path).name
            self.assertRegex(note_name, r"^\d{8}_Research_Report_smoke\.md$")
            self.assertTrue((tmp_path / rel_path).exists())


if __name__ == "__main__":
    unittest.main()
