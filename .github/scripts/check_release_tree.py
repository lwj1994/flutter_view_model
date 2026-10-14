"""发布前确认检出内容未被工具改写；仅允许不进入发布包的 lockfile 更新。"""

import argparse
from pathlib import Path
import subprocess
import sys


def git(root, *arguments):
    return subprocess.check_output(["git", "-C", str(root), *arguments])


def check_tree(directory, package):
    root = Path(git(directory, "rev-parse", "--show-toplevel").decode().strip())
    package_root = root / "packages" / package
    overrides = package_root / "pubspec_overrides.yaml"
    if overrides.exists() or overrides.is_symlink():
        raise ValueError(f"Release must not use {overrides.relative_to(root)}")

    # Pub intentionally excludes pubspec.lock from library archives. Resolving
    # the hosted release dependency can update that file without changing the
    # package being published. No source/config migration is allowed.
    allowed = f"packages/{package}/pubspec.lock"
    changed = git(root, "diff", "--name-only", "-z", "HEAD", "--").split(b"\0")
    untracked = git(root, "ls-files", "--others", "--exclude-standard", "-z").split(b"\0")
    unexpected = sorted({
        path.decode() for path in changed + untracked
        if path and path.decode() != allowed
    })
    if unexpected:
        raise ValueError("Release checkout changed:\n" + "\n".join(unexpected))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", required=True, choices=(
        "view_model_annotation", "view_model_generator", "view_model",
    ))
    args = parser.parse_args()
    try:
        check_tree(Path.cwd(), args.package)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"Release content validation blocked: {error}", file=sys.stderr)
        return 1
    print("Release content matches the checked-out commit.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
