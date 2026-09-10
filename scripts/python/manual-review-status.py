#!/usr/bin/env python3
"""Create a project-management register of BNR manual review statuses.

The utility reads ``manual-review-status`` from each QMD front matter block in
the three manuals. If a page has no page-specific value, it uses the nearest
``_metadata.yml`` value, matching Quarto's metadata inheritance.
"""

from __future__ import annotations

import argparse
import csv
import re
from dataclasses import dataclass
from pathlib import Path


MANUALS = {
    "methods": ("Public Methods Manual", Path("site/methods")),
    "operations": ("Operations Manual", Path("site/operations")),
    "technical": ("Technical Manual", Path("site/technical")),
}
STATUS_ORDER = ("not-used", "not-reviewed", "reviewed-by-irh", "approved-by-bnr")
STATUS_LABELS = {
    "not-used": "Not used",
    "not-reviewed": "Not reviewed",
    "reviewed-by-irh": "Reviewed by IRH",
    "approved-by-bnr": "Approved by BNR",
}
FRONT_MATTER = re.compile(r"\A\ufeff?---\r?\n(.*?)\r?\n---\r?\n", re.DOTALL)
YAML_VALUE = re.compile(r"^([A-Za-z0-9_-]+):\s*(.*?)\s*$")
HEADING = re.compile(r"^\s{0,3}#\s+(.+?)(?:\s+\{[^}]*\})?\s*$")
SIDEBAR_ID = re.compile(r"^ {4}- id: ([A-Za-z0-9_-]+)\s*$")
SIDEBAR_HREF = re.compile(r"^\s+href:\s+([^\s#]+)\s*$")


@dataclass(frozen=True)
class PageStatus:
    manual_key: str
    manual_name: str
    title: str
    path: str
    status: str
    status_source: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="Repository root (default: current directory)")
    parser.add_argument(
        "--report-dir",
        default="outputs/utility-reports",
        help="Report directory relative to root",
    )
    return parser.parse_args()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig", errors="replace")


def front_matter_values(path: Path) -> dict[str, str]:
    text = read_text(path)
    match = FRONT_MATTER.match(text)
    content = match.group(1) if match else (text if path.suffix.lower() in {".yml", ".yaml"} else "")
    values: dict[str, str] = {}
    for line in content.splitlines():
        item = YAML_VALUE.match(line)
        if not item:
            continue
        key, value = item.groups()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
            value = value[1:-1]
        values[key] = value
    return values


def page_title(path: Path, values: dict[str, str]) -> str:
    if values.get("title"):
        return values["title"]
    for line in read_text(path).splitlines():
        item = HEADING.match(line)
        if item:
            return item.group(1).strip()
    return path.stem.replace("-", " ").title()


def inherited_status(manual_root: Path, page: Path) -> tuple[str, str]:
    """Return the closest inherited status, looking from the page upwards."""
    for directory in (page.parent, *page.parents):
        if directory < manual_root:
            break
        metadata = directory / "_metadata.yml"
        if metadata.is_file():
            value = front_matter_values(metadata).get("manual-review-status")
            if value:
                return value, f"Inherited from {metadata.relative_to(manual_root).as_posix()}"
        if directory == manual_root:
            break
    return "missing", "No page or inherited status"


def sidebar_page_order(root: Path) -> dict[str, dict[str, int]]:
    """Read manual page order from the Quarto sidebars.

    The three sidebars are maintained to mirror their manual landing-page cards,
    so this keeps the status register in the reader's rather than file-system
    order without requiring a YAML package.
    """
    quarto_config = root / "site/_quarto.yml"
    if not quarto_config.is_file():
        return {manual_key: {} for manual_key in MANUALS}

    order = {manual_key: {} for manual_key in MANUALS}
    active_manual: str | None = None
    for line in read_text(quarto_config).splitlines():
        sidebar_id = SIDEBAR_ID.match(line)
        if sidebar_id:
            candidate = sidebar_id.group(1)
            active_manual = candidate if candidate in MANUALS else None
            continue
        if not active_manual:
            continue
        href = SIDEBAR_HREF.match(line)
        if not href:
            continue
        target = href.group(1).strip('"\'')
        prefix = f"{active_manual}/"
        if target.startswith(prefix) and target.endswith(".qmd"):
            relative_path = f"site/{target}"
            order[active_manual].setdefault(relative_path, len(order[active_manual]))
    return order


def collect_pages(root: Path) -> list[PageStatus]:
    navigation_order = sidebar_page_order(root)
    rows: list[PageStatus] = []
    for manual_key, (manual_name, relative_root) in MANUALS.items():
        manual_root = root / relative_root
        if not manual_root.is_dir():
            raise SystemExit(f"Manual folder not found: {manual_root}")
        for page in manual_root.rglob("*.qmd"):
            if page.name == "_metadata.yml":
                continue
            values = front_matter_values(page)
            status = values.get("manual-review-status")
            if status:
                source = "Page YAML"
            else:
                status, source = inherited_status(manual_root, page)
            rows.append(
                PageStatus(
                    manual_key=manual_key,
                    manual_name=manual_name,
                    title=page_title(page, values),
                    path=page.relative_to(root).as_posix(),
                    status=status,
                    status_source=source,
                )
            )
    return sorted(
        rows,
        key=lambda row: (
            list(MANUALS).index(row.manual_key),
            0 if row.path in navigation_order[row.manual_key] else 1,
            navigation_order[row.manual_key].get(row.path, 0),
            row.path,
        ),
    )


def status_label(status: str) -> str:
    return STATUS_LABELS.get(status, f"Needs attention: {status}")


def count(rows: list[PageStatus], manual_key: str, status: str) -> int:
    return sum(row.manual_key == manual_key and row.status == status for row in rows)


def markdown_report(rows: list[PageStatus]) -> str:
    lines = ["# Manual review-status register", "", "## Summary", ""]
    lines.extend([
        "| Manual | Not used | Not reviewed | Reviewed by IRH | Approved by BNR | Needs attention | Total |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ])
    for manual_key, (manual_name, _) in MANUALS.items():
        known = sum(count(rows, manual_key, status) for status in STATUS_ORDER)
        total = sum(row.manual_key == manual_key for row in rows)
        lines.append(
            f"| {manual_name} | {count(rows, manual_key, 'not-used')} | "
            f"{count(rows, manual_key, 'not-reviewed')} | "
            f"{count(rows, manual_key, 'reviewed-by-irh')} | "
            f"{count(rows, manual_key, 'approved-by-bnr')} | {total - known} | {total} |"
        )

    for manual_key, (manual_name, _) in MANUALS.items():
        lines.extend(["", f"## {manual_name}", "", "| Page | Path | Status | Source |", "|---|---|---|---|"])
        for row in (item for item in rows if item.manual_key == manual_key):
            lines.append(
                f"| {row.title.replace('|', '\\|')} | `{row.path}` | {status_label(row.status)} | {row.status_source} |"
            )
    return "\n".join(lines) + "\n"


def main() -> int:
    args = parse_args()
    root = Path(args.root).resolve()
    rows = collect_pages(root)
    report_dir = root / args.report_dir
    report_dir.mkdir(parents=True, exist_ok=True)

    csv_path = report_dir / "manual-review-status.csv"
    with csv_path.open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.writer(handle)
        writer.writerow(["manual", "page", "path", "manual_review_status", "status_source"])
        for row in rows:
            writer.writerow([row.manual_name, row.title, row.path, row.status, row.status_source])

    markdown_path = report_dir / "manual-review-status.md"
    markdown_path.write_text(markdown_report(rows), encoding="utf-8")

    print("Manual review-status summary")
    for manual_key, (manual_name, _) in MANUALS.items():
        values = ", ".join(f"{STATUS_LABELS[status]}: {count(rows, manual_key, status)}" for status in STATUS_ORDER)
        attention = sum(row.manual_key == manual_key and row.status not in STATUS_ORDER for row in rows)
        print(f"- {manual_name}: {values}; needs attention: {attention}")
    print(f"\nCreated: {markdown_path.relative_to(root)}")
    print(f"Created: {csv_path.relative_to(root)}")
    return 1 if any(row.status not in STATUS_ORDER for row in rows) else 0


if __name__ == "__main__":
    raise SystemExit(main())
