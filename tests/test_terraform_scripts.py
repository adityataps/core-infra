"""Exercise the real wrappers and workflow shell with Terraform isolated."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import textwrap
import unittest


REPO = Path(__file__).resolve().parents[1]


class TerraformScriptsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copytree(REPO / "scripts", self.root / "scripts")
        (self.root / "Makefile").write_text(
            "all: ci-plan\n"
            "ci-plan:\n"
            "\t@scripts/tf-module.sh $(CMD) 0 providers/first\n"
            "\t@scripts/tf-module.sh $(CMD) 0 providers/second\n"
        )
        for name in ("first", "second"):
            (self.root / "providers" / name).mkdir(parents=True)
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        terraform = bin_dir / "terraform"
        terraform.write_text(
            '#!/usr/bin/env bash\n'
            'case "$1" in\n'
            'init) if [[ "${PWD##*/}" == "${TEST_INIT_FAIL_MODULE:-}" ]]; then exit 1; fi\n'
            '      exit "${TEST_INIT_EXIT:-0}" ;;\n'
            'plan) exit "${TEST_PLAN_EXIT:-0}" ;;\n'
            '*) exit 99 ;;\n'
            'esac\n'
        )
        terraform.chmod(0o755)
        self.env = dict(os.environ, PATH=f"{bin_dir}:{os.environ['PATH']}")
        self.env.pop("TF_PROGRESS_DIR", None)

    def run_wrapper(self, *, cwd=None, target="ci-plan", **env):
        return subprocess.run(
            ["bash", str(self.root / "scripts/tf-all.sh"), "plan", target],
            cwd=cwd or self.root,
            env=dict(self.env, **env),
            capture_output=True,
            text=True,
        )

    def test_clean_plan_is_success(self):
        result = self.run_wrapper()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Summary (2 modules)", result.stdout)

    def test_pending_changes_are_drift(self):
        result = self.run_wrapper(TEST_PLAN_EXIT="2")
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertEqual(result.stdout.count("~ changes"), 2)

    def test_plan_error_is_failure(self):
        self.assertEqual(self.run_wrapper(TEST_PLAN_EXIT="1").returncode, 1)

    def test_error_takes_precedence_over_drift(self):
        result = self.run_wrapper(TEST_PLAN_EXIT="2", TEST_INIT_FAIL_MODULE="second")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("~ changes", result.stdout)
        self.assertIn("✗ error", result.stdout)

    def test_standalone_apply_with_no_changes_is_success(self):
        result = subprocess.run(
            ["bash", str(self.root / "scripts/tf-module.sh"), "apply", "0", "providers/first"],
            cwd=self.root, env=self.env, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_init_error_is_failure_and_appears_in_summary(self):
        result = self.run_wrapper(TEST_INIT_EXIT="1")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("✗ error", result.stdout)

    def test_unexpected_plan_exit_is_failure(self):
        self.assertEqual(self.run_wrapper(TEST_PLAN_EXIT="42").returncode, 1)

    def test_invalid_make_target_is_failure(self):
        self.assertEqual(self.run_wrapper(target="missing-target").returncode, 1)

    def test_invocation_from_outside_repo_counts_modules(self):
        result = self.run_wrapper(cwd=self.root / "providers")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Summary (2 modules)", result.stdout)

    def run_plan_workflow(self, **env):
        # Execute the actual workflow's shell, including its pipeline and status handling.
        workflow = (REPO / ".github/workflows/terraform-plan.yml").read_text()
        step = workflow.split("      - name: Terraform Plan\n", 1)[1]
        block = step.split("        run: |\n", 1)[1].split("\n      - name:", 1)[0]
        script = textwrap.dedent(block).replace("${{", "UNEXPECTED_EXPRESSION")
        output = self.root / "github-output"
        result = subprocess.run(
            ["bash", "-e", "-o", "pipefail", "-c", script],
            cwd=self.root,
            env=dict(self.env, GITHUB_OUTPUT=str(output), **env),
            capture_output=True,
            text=True,
        )
        values = output.read_text() if output.exists() else ""
        return result, values

    def test_plan_workflow_does_not_hide_make_failure(self):
        result, values = self.run_plan_workflow(TEST_PLAN_EXIT="1")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertRegex(values, r"(?m)^exit_code=1$")

    def test_plan_workflow_reports_drift_without_failing(self):
        result, values = self.run_plan_workflow(TEST_PLAN_EXIT="2")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertRegex(values, r"(?m)^exit_code=2$")

    def test_plan_workflow_reports_init_failure(self):
        result, values = self.run_plan_workflow(TEST_INIT_EXIT="1")
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertRegex(values, r"(?m)^exit_code=1$")


if __name__ == "__main__":
    unittest.main()
