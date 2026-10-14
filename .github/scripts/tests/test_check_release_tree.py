from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
from check_release_tree import check_tree


class ReleaseTreeTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.package = self.root / "packages/view_model"
        self.package.mkdir(parents=True)
        self.options = self.package / "analysis_options.yaml"
        self.options.write_text("analyzer:\n  exclude:\n    - example/**\n")
        self.lock = self.package / "pubspec.lock"
        self.lock.write_text("packages: {}\n")
        (self.root / ".gitignore").write_text(".dart_tool/\nbuild/\npubspec_overrides.yaml\n")
        self.git("init", "--quiet")
        self.git("add", ".")
        self.git("-c", "user.name=Test", "-c", "user.email=test@example.com",
                 "commit", "--quiet", "-m", "release")

    def git(self, *arguments):
        subprocess.run(["git", "-C", str(self.root), *arguments], check=True,
                       capture_output=True)

    def test_hosted_resolution_lockfile_and_ignored_build_outputs_are_allowed(self):
        self.lock.write_text("packages: {view_model_annotation: {version: 1.2.1}}\n")
        generated = self.package / ".dart_tool/package_config.json"
        generated.parent.mkdir()
        generated.write_text("{}")
        check_tree(self.package, "view_model")

    def test_flutter_analysis_options_migration_is_rejected_without_restoring_it(self):
        migrated = self.options.read_text() + "    - build/**\n"
        self.options.write_text(migrated)
        with self.assertRaisesRegex(ValueError, "analysis_options.yaml"):
            check_tree(self.package, "view_model")
        self.assertEqual(self.options.read_text(), migrated)

    def test_staged_edits_deleted_files_and_untracked_files_are_rejected(self):
        self.options.write_text("modified: true\n")
        self.git("add", str(self.options))
        with self.assertRaisesRegex(ValueError, "analysis_options.yaml"):
            check_tree(self.package, "view_model")
        self.git("restore", "--source=HEAD", "--staged", "--worktree", str(self.options))
        self.options.unlink()
        with self.assertRaisesRegex(ValueError, "analysis_options.yaml"):
            check_tree(self.package, "view_model")
        self.git("restore", str(self.options))
        (self.package / "unexpected.txt").write_text("must not be published")
        with self.assertRaisesRegex(ValueError, "unexpected.txt"):
            check_tree(self.package, "view_model")

    def test_example_changes_outside_package_symlink_are_rejected(self):
        example = self.root / "example/counter/lib/main.dart"
        example.parent.mkdir(parents=True)
        example.write_text("modified example")
        with self.assertRaisesRegex(ValueError, "example/counter/lib/main.dart"):
            check_tree(self.package, "view_model")

    def test_ignored_override_and_dangling_override_symlink_are_rejected(self):
        overrides = self.package / "pubspec_overrides.yaml"
        overrides.write_text("dependency_overrides: {}\n")
        with self.assertRaisesRegex(ValueError, "pubspec_overrides.yaml"):
            check_tree(self.package, "view_model")
        overrides.unlink()
        overrides.symlink_to("missing.yaml")
        with self.assertRaisesRegex(ValueError, "pubspec_overrides.yaml"):
            check_tree(self.package, "view_model")


if __name__ == "__main__":
    unittest.main()
