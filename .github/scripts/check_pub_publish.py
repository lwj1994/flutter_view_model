"""只放行已审阅的 Pub 发布警告；未知诊断或输出格式变化均阻断发布。"""

import argparse
from pathlib import Path
import re
import sys


VERSION = r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?"
ANNOTATION_WARNING = (
    'Your dependency on "view_model_annotation" should allow more than one '
    'version. For example: dependencies: view_model_annotation: ^{version} '
    'Constraints that are too tight will make it difficult for people to use '
    'your package along with other packages that also depend on '
    '"view_model_annotation".'
)
UNCONSTRAINED_WARNING = (
    'Your dependency on "{dependency}" should have a version constraint. '
    'For example: dependencies: {dependency}: ^{version} '
    'Without a constraint, you\'re promising to support all future versions '
    'of "{dependency}".'
)
HEADER = re.compile(
    r"Package validation found the following (?:(\d+) )?"
    r"(potential issue|hint|error)s?:\n"
)
FOOTER = re.compile(
    r"The server may enforce additional checks\.\s*"
    r"Package has (\d+) warnings?(?: and (\d+) hints?)?\.\s*\Z"
)


def check_output(package, exit_code, output):
    """返回放行的警告数；无法确认成功完成校验时抛出 ValueError。"""
    if package not in ("view_model_generator", "view_model"):
        raise ValueError(f"Unsupported package: {package}")
    if exit_code not in (0, 65):
        raise ValueError(f"pub publish --dry-run failed with exit code {exit_code}")

    output = re.sub(r"\x1b\[[0-9;]*m", "", output).replace("\r\n", "\n")
    # Flutter 会为 Pub 的非零退出码追加此行；仍须核对完整校验结果与退出码。
    if package == "view_model" and exit_code == 65:
        output = re.sub(r"\nFailed to update packages\.\s*\Z", "", output)
    sections = output.split("Validating package...\n")
    if len(sections) != 2:
        raise ValueError("Missing or ambiguous Pub validation output")
    diagnostics = sections[1]
    footer = FOOTER.search(diagnostics)
    if footer is None:
        raise ValueError("Pub validation did not finish with a recognized summary")
    warning_count = int(footer[1])
    hint_count = int(footer[2] or 0)
    if exit_code != (65 if warning_count else 0):
        raise ValueError("Pub exit code disagrees with its warning summary")

    remaining = diagnostics[:footer.start()].strip()
    found = {}
    while remaining:
        header = HEADER.match(remaining)
        if header is None:
            raise ValueError("Unrecognized Pub diagnostic section")
        kind = header[2]
        if kind == "error" or kind in found:
            raise ValueError(f"Pub reported an error or repeated section: {kind}")
        next_header = remaining.find("\nPackage validation found", header.end())
        end = len(remaining) if next_header < 0 else next_header
        items = re.split(r"(?m)^\* ", remaining[header.end():end])
        if items[0].strip() or len(items) - 1 != int(header[1] or 1):
            raise ValueError("Pub diagnostic count or bullet format changed")
        found[kind] = [" ".join(item.split()) for item in items[1:]]
        remaining = remaining[end:].strip()

    warnings = found.get("potential issue", [])
    if len(warnings) != warning_count or len(found.get("hint", [])) != hint_count:
        raise ValueError("Pub diagnostic counts disagree with its summary")

    allowed = [ANNOTATION_WARNING]
    if package == "view_model":
        allowed += [
            UNCONSTRAINED_WARNING.replace("{dependency}", dependency)
            for dependency in ("meta", "stack_trace")
        ]
    patterns = [
        re.compile(re.escape(warning).replace(re.escape("{version}"), VERSION))
        for warning in allowed
    ]
    used = set()
    for warning in warnings:
        match = next(
            (i for i, pattern in enumerate(patterns) if pattern.fullmatch(warning)),
            None,
        )
        if match is None or match in used:
            raise ValueError(f"Unexpected or repeated publish warning: {warning}")
        used.add(match)
    return warning_count


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", required=True)
    parser.add_argument("--exit-code", required=True, type=int)
    parser.add_argument("log", type=Path)
    args = parser.parse_args()
    try:
        count = check_output(args.package, args.exit_code, args.log.read_text())
    except (ValueError, OSError) as error:
        print(f"Publish validation blocked: {error}", file=sys.stderr)
        return 1
    print(f"Publish validation passed: {count} reviewed dependency warning(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
