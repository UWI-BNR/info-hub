#!/usr/bin/env python3
"""Report local links in Markdown, QMD and simple HTML attributes.

The script is read-only. It writes CSV and Markdown reports and makes no edits.
"""

from __future__ import annotations

import argparse
import csv
import re
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import unquote, urlsplit

MARKDOWN_LINK = re.compile(r"!?\[[^\]]*\]\(([^)\s]+)(?:\s+[\"'][^\"']*[\"'])?\)")
HTML_LINK = re.compile(r"(?:href|src)\s*=\s*[\"']([^\"']+)[\"']", re.IGNORECASE)
SKIP_SCHEMES = {"http", "https", "mailto", "tel", "data", "javascript"}
TEXT_EXTENSIONS = {".qmd", ".md", ".html", ".htm", ".yml", ".yaml"}
EXCLUDED_DIRS = {".git", ".quarto", "_site", "repo-review", "node_modules"}


@dataclass(frozen=True)
class LinkResult:
    source_file: str
    line: int
    link: str
    resolved_target: str
    status: str
    note: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="Repository root (default: current directory)")
    parser.add_argument("--report-dir", default="repo-review", help="Report directory relative to root")
    return parser.parse_args()


def iter_source_files(root: Path):
    for path in root.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in TEXT_EXTENSIONS:
            continue
        if any(part in EXCLUDED_DIRS for part in path.relative_to(root).parts):
            continue
        yield path


def candidate_targets(root: Path, source: Path, raw_link: str) -> tuple[Path | None, str]:
    parsed = urlsplit(raw_link)
    if parsed.scheme.lower() in SKIP_SCHEMES or raw_link.startswith("//"):
        return None, "external"
    if not parsed.path:
        return None, "anchor-only"

    link_path = unquote(parsed.path)
    if link_path.startswith("/"):
        # Root-relative website links are resolved from the Quarto site source root.
        site_root = root / "site"
        base = site_root if site_root.exists() else root
        target = base / link_path.lstrip("/")
    else:
        target = source.parent / link_path
    return target.resolve(), "local"


def assess_target(root: Path, target: Path) -> tuple[str, str, Path]:
    if target.exists():
        return "exists", "Local target exists.", target

    # Rendered HTML links commonly correspond to a QMD source.
    if target.suffix.lower() in {".html", ".htm"}:
        qmd = target.with_suffix(".qmd")
        md = target.with_suffix(".md")
        if qmd.exists():
            return "generated", "Rendered HTML is absent, but the matching QMD source exists.", qmd
        if md.exists():
            return "generated", "Rendered HTML is absent, but the matching Markdown source exists.", md

    # A directory URL may be generated from index.qmd.
    index_qmd = target / "index.qmd"
    if index_qmd.exists():
        return "generated", "Directory target is expected to be generated from index.qmd.", index_qmd

    try:
        relative = target.relative_to(root)
    except ValueError:
        relative = target
    return "missing", "No matching local file or obvious Quarto source was found.", relative


def main() -> int:
    args = parse_args()
    root = Path(args.root).resolve()
    report_dir = root / args.report_dir
    report_dir.mkdir(parents=True, exist_ok=True)

    results: list[LinkResult] = []
    for source in iter_source_files(root):
        try:
            lines = source.read_text(encoding="utf-8-sig", errors="replace").splitlines()
        except OSError:
            continue
        for number, line in enumerate(lines, start=1):
            links = [*MARKDOWN_LINK.findall(line), *HTML_LINK.findall(line)]
            for raw_link in links:
                # Tokenised templates are validated after instantiation. Their
                # placeholders are not repository paths and must not be
                # reported as broken links.
                if "@@" in raw_link:
                    continue
                target, kind = candidate_targets(root, source, raw_link.strip("<>"))
                if kind != "local" or target is None:
                    continue
                status, note, assessed_target = assess_target(root, target)
                try:
                    resolved = assessed_target.relative_to(root).as_posix()
                except ValueError:
                    resolved = str(assessed_target)
                results.append(
                    LinkResult(
                        source_file=source.relative_to(root).as_posix(),
                        line=number,
                        link=raw_link,
                        resolved_target=resolved,
                        status=status,
                        note=note,
                    )
                )

    results.sort(key=lambda row: (row.status != "missing", row.source_file, row.line, row.link))
    csv_path = report_dir / "local-links.csv"
    with csv_path.open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.writer(handle)
        writer.writerow(["source_file", "line", "link", "resolved_target", "status", "note"])
        for row in results:
            writer.writerow([row.source_file, row.line, row.link, row.resolved_target, row.status, row.note])

    md_path = report_dir / "local-links.md"
    counts = {status: sum(row.status == status for row in results) for status in ("missing", "generated", "exists")}
    with md_path.open("w", encoding="utf-8") as handle:
        handle.write("# Local link review\n\n")
        handle.write(f"- Missing: {counts['missing']}\n")
        handle.write(f"- Expected generated targets: {counts['generated']}\n")
        handle.write(f"- Existing targets: {counts['exists']}\n\n")
        handle.write("The script reports links only. Review missing and generated targets before editing.\n\n")
        handle.write("| Source | Line | Link | Status | Resolved target |\n")
        handle.write("|---|---:|---|---|---|\n")
        for row in results:
            safe_link = row.link.replace("|", "\\|")
            handle.write(
                f"| `{row.source_file}` | {row.line} | `{safe_link}` | {row.status} | `{row.resolved_target}` |\n"
            )

    print(f"Local link review complete: {len(results)} links checked")
    print(f"CSV report: {csv_path}")
    print(f"Markdown report: {md_path}")
    return 1 if counts["missing"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
