from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
from check_pub_publish import check_output

FIXTURES = Path(__file__).parent / "fixtures"
GENERATOR = (FIXTURES / "generator_dry_run.txt").read_text()
MAIN = (FIXTURES / "view_model_dry_run.txt").read_text()
CLEAN = (
    "Validating package...\n"
    "The server may enforce additional checks.\n\nPackage has 0 warnings.\n"
)
# 在真实输出中增加一条新警告，同时更新数量，复现 review 中的绕过场景。
UNKNOWN = MAIN.replace("3 potential issues", "4 potential issues").replace(
    "The server may enforce",
    "\n* Your package contains an unexpected credential file.\nThe server may enforce",
).replace("3 warnings", "4 warnings")


class PublishWarningGateTest(unittest.TestCase):
    def test_actual_generator_warning_and_nonfatal_hint(self):
        self.assertEqual(check_output("view_model_generator", 65, GENERATOR), 1)

    def test_actual_main_warnings(self):
        self.assertEqual(check_output("view_model", 65, MAIN), 3)

    def test_main_warnings_without_flutter_trailer(self):
        report = MAIN.replace("Failed to update packages.\n", "")
        self.assertEqual(check_output("view_model", 65, report), 3)

    def test_flutter_dependency_failure_without_summary_is_blocked(self):
        report = "Resolving dependencies...\nVersion solving failed.\nFailed to update packages.\n"
        with self.assertRaises(ValueError):
            check_output("view_model", 65, report)

    def test_no_warnings(self):
        self.assertEqual(check_output("view_model", 0, CLEAN), 0)

    def test_hints_without_warnings(self):
        report = GENERATOR[:GENERATOR.index("Package validation")]
        report += GENERATOR[GENERATOR.index("Package validation found the following hint:"):]
        report = report.replace("1 warning", "0 warnings")
        self.assertEqual(check_output("view_model_generator", 0, report), 0)

    def test_color_line_endings_and_whitespace(self):
        report = MAIN.replace("Validating package...", "\x1b[32mValidating package...\x1b[0m")
        report = report.replace("For example:", "For example:\n  ").replace("\n", "\r\n")
        self.assertEqual(check_output("view_model", 65, report), 3)

    def test_dependency_versions_can_change(self):
        report = MAIN.replace("^1.2.0", "^1.3.0").replace("^1.17.0", "^2.0.0")
        self.assertEqual(check_output("view_model", 65, report), 3)

    def test_new_warning_alongside_expected_warnings_is_blocked(self):
        with self.assertRaisesRegex(ValueError, "Unexpected"):
            check_output("view_model", 65, UNKNOWN)

    def test_same_dependency_different_warning_is_blocked(self):
        report = MAIN.replace("should have a version constraint", "has a security advisory")
        with self.assertRaisesRegex(ValueError, "Unexpected"):
            check_output("view_model", 65, report)

    def test_matching_first_line_does_not_allow_changed_body(self):
        report = MAIN.replace(
            "Without a constraint", "Additional unreviewed warning. Without a constraint"
        )
        with self.assertRaisesRegex(ValueError, "Unexpected"):
            check_output("view_model", 65, report)

    def test_unrelated_unconstrained_dependency_is_blocked(self):
        with self.assertRaisesRegex(ValueError, "Unexpected"):
            check_output("view_model", 65, MAIN.replace("meta", "other_package"))

    def test_main_exceptions_are_not_allowed_for_generator(self):
        report = MAIN.replace("Failed to update packages.\n", "")
        with self.assertRaisesRegex(ValueError, "Unexpected"):
            check_output("view_model_generator", 65, report)

    def test_duplicate_known_warning_is_blocked(self):
        with self.assertRaisesRegex(ValueError, "repeated"):
            check_output("view_model", 65, MAIN.replace("stack_trace", "meta"))

    def test_failures_are_not_mistaken_for_warning_exit(self):
        for code in (1, 64, 66, 69, -15):
            with self.subTest(code=code), self.assertRaises(ValueError):
                check_output("view_model", code, MAIN)

    def test_exit_code_must_match_warning_count(self):
        for code, report in ((0, MAIN), (65, CLEAN)):
            with self.subTest(code=code), self.assertRaises(ValueError):
                check_output("view_model", code, report)

    def test_errors_block_even_with_a_warning_summary(self):
        report = MAIN.replace(
            "Package validation found",
            "Package validation found the following error:\n* Missing LICENSE.\n\n"
            "Package validation found",
            1,
        )
        with self.assertRaises(ValueError):
            check_output("view_model", 65, report)

    def test_malformed_or_incomplete_outputs_are_blocked(self):
        reports = (
            "", "Network error", MAIN.replace("3 warnings", "4 warnings"),
            MAIN.replace("3 potential issues", "2 potential issues"),
            MAIN.replace("potential issues", "new diagnostics"),
            MAIN.replace("* Your dependency", "- Your dependency", 1),
            MAIN[:MAIN.index("The server may enforce")],
            MAIN + "Unexpected trailing error\n",
            MAIN + MAIN,
            GENERATOR.replace("1 hint", "2 hints"),
        )
        for report in reports:
            with self.subTest(report=report[-80:]), self.assertRaises(ValueError):
                check_output("view_model", 65, report)

    def test_unknown_package_is_blocked(self):
        with self.assertRaises(ValueError):
            check_output("another_package", 0, CLEAN)

    def test_cli_prevents_following_upload_on_unknown_warnings_or_errors(self):
        cases = ((MAIN, 65, True), (UNKNOWN, 65, False), (MAIN, 69, False))
        for report, status, allowed in cases:
            with self.subTest(status=status, allowed=allowed):
                self.check_upload_gate(report, status, allowed)

    def check_upload_gate(self, report, status, allowed):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "dry-run.log"
            uploaded = Path(directory) / "uploaded"
            log.write_text(report)
            # 与 workflow 相同，检查失败时 shell -e 不得执行后续上传步骤。
            command = '"$1" "$2" --package view_model --exit-code "$3" "$4"\ntouch "$5"'
            result = subprocess.run(
                ["bash", "-ec", command, "test", sys.executable,
                 str(SCRIPTS / "check_pub_publish.py"), str(status),
                 str(log), str(uploaded)],
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode == 0, allowed, result.stderr)
            self.assertEqual(uploaded.exists(), allowed)


if __name__ == "__main__":
    unittest.main()
