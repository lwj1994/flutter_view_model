"""Merge line coverage from debug/release conditions and require every line."""

import argparse
from pathlib import Path


def merge_reports(paths):
    merged = {}
    for path in paths:
        source = None
        for row in Path(path).read_text().splitlines():
            if row.startswith("SF:"):
                source = row[3:]
                if not source:
                    raise ValueError(f"{path}: empty source path")
                merged.setdefault(source, {})
            elif row.startswith("DA:"):
                if source is None:
                    raise ValueError(f"{path}: coverage without a source")
                number, hits = map(int, row[3:].split(",")[:2])
                if number < 1 or hits < 0:
                    raise ValueError(f"{path}: invalid line coverage: {row}")
                lines = merged[source]
                lines[number] = lines.get(number, 0) + hits
            elif row == "end_of_record":
                source = None
    return merged


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reports", nargs="+")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    coverage = merge_reports(args.reports)
    total = covered = 0
    output = []
    for source, lines in sorted(coverage.items()):
        hits = sum(count > 0 for count in lines.values())
        total += len(lines)
        covered += hits
        output.append(f"SF:{source}")
        output.extend(f"DA:{line},{count}" for line, count in sorted(lines.items()))
        output.extend([f"LF:{len(lines)}", f"LH:{hits}", "end_of_record"])
        missing = [str(line) for line, count in sorted(lines.items()) if not count]
        if missing:
            print(f"Uncovered {source}: {', '.join(missing)}")
    Path(args.output).write_text("\n".join(output) + "\n")
    if not total:
        raise SystemExit("Coverage report contains no executable lines.")
    print(f"Line coverage: {covered}/{total} ({covered / total:.2%})")
    if covered != total:
        raise SystemExit("view_model requires 100% line coverage.")


if __name__ == "__main__":
    main()
