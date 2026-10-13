from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "check_view_model_coverage.py"


class CoverageGateTest(unittest.TestCase):
    def run_gate(self, *reports):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            inputs = []
            for index, report in enumerate(reports):
                path = root / f"{index}.info"
                path.write_text(report)
                inputs.append(str(path))
            output = root / "merged.info"
            result = subprocess.run(
                [sys.executable, str(SCRIPT), *inputs, "--output", str(output)],
                capture_output=True, text=True,
            )
            return result, output.read_text() if output.exists() else ""

    def test_merges_hits_without_losing_mode_specific_lines(self):
        result, output = self.run_gate(
            "SF:lib/a.dart\nDA:1,2\nDA:2,0\nend_of_record\n",
            "SF:lib/a.dart\nDA:2,3\nDA:3,1\nend_of_record\n",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("3/3 (100.00%)", result.stdout)
        self.assertIn("DA:1,2\nDA:2,3\nDA:3,1\nLF:3\nLH:3", output)

    def test_missing_lines_in_either_report_fail_the_gate(self):
        result, output = self.run_gate(
            "SF:lib/a.dart\nDA:1,1\nDA:2,0\nend_of_record\n",
            "SF:lib/b.dart\nDA:1,1\nend_of_record\n",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Uncovered lib/a.dart: 2", result.stdout)
        self.assertIn("2/3", result.stdout)
        self.assertIn("SF:lib/b.dart", output)

    def test_empty_reports_cannot_pass(self):
        result, _ = self.run_gate("")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no executable lines", result.stderr)

    def test_invalid_coverage_cannot_pass(self):
        for report in ["DA:1,1", "SF:lib/a.dart\nDA:1,-1"]:
            with self.subTest(report=report):
                result, _ = self.run_gate(report)
                self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
