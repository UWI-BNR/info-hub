#!/usr/bin/env python3
"""Create a read-only local link register for BNR documentation.

The checker validates local links and writes CSV and Markdown reports. It does
not edit source files. Use ``--manual`` to review one BNR manual at a time;
omit it to retain the original whole-repository check.
"""

from __future__ import annotations

import argparse
import csv
import re
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import unquote, urlsplit

MARKDOWN_LINK = re.compile(
    r"!?\[([^\]]*)\]\(([^)\s]+)(?:\s+[\"'][^\"']*[\"'])?\)"
)
HTML_LINK = re.compile(r"(?:href|src)\s*=\s*[\"']([^\"']+)[\"']", re.IGNORECASE)
HEADING = re.compile(r"^\s{0,3}#{1,6}\s+(.+?)(?:\s+\{[^}]*\})?\s*$")
FRONT_MATTER = re.compile(r"\A\ufeff?---\r?\n(.*?)\r?\n---\r?\n", re.DOTALL)
YAML_VALUE = re.compile(r"^([A-Za-z0-9_-]+):\s*(.*?)\s*$")

SKIP_SCHEMES = {"http", "https", "mailto", "tel", "data", "javascript"}
TEXT_EXTENSIONS = {".qmd", ".md", ".html", ".htm", ".yml", ".yaml"}
EXCLUDED_DIRS = {".git", ".quarto", "_site", "repo-review", "node_modules"}
MANUAL_SCOPES = {
    "methods": Path("site/methods"),
    "operations": Path("site/operations"),
    "technical": Path("site/technical"),
}


@dataclass(frozen=True)
class PageInfo:
    title: str
    description: str


@dataclass(frozen=True)
class LinkResult:
    source_file: str
    source_title: str
    source_description: str
    link_context: str
    line: int
    link_text: str
    link_target: str
    destination_path: str
    destination_title: str
    destination_description: str
    status: str
    works: str
    appropriateness: str
    note: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="Repository root (default: current directory)")
    parser.add_argument(
        "--manual",
        choices=sorted(MANUAL_SCOPES),
        help="Check one manual only: methods, operations or technical.",
    )
    parser.add_argument("--report-dir", default="repo-review", help="Report directory relative to root")
    return parser.parse_args()


def iter_source_files(root: Path, scan_root: Path):
    for path in scan_root.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in TEXT_EXTENSIONS:
            continue
        if any(part in EXCLUDED_DIRS for part in path.relative_to(root).parts):
            continue
        yield path


def clean_yaml_value(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return value[1:-1]
    return value


def read_page_info(path: Path, cache: dict[Path, PageInfo]) -> PageInfo:
    if path in cache:
        return cache[path]
    if not path.is_file() or path.suffix.lower() not in {".qmd", ".md", ".html", ".htm"}:
        info = PageInfo("", "")
        cache[path] = info
        return info

    try:
        text = path.read_text(encoding="utf-8-sig", errors="replace")
    except OSError:
        info = PageInfo("", "")
        cache[path] = info
        return info

    title = ""
    description = ""
    match = FRONT_MATTER.match(text)
    if match:
        for line in match.group(1).splitlines():
            item = YAML_VALUE.match(line)
            if not item:
                continue
            key, value = item.groups()
            if key == "title":
                title = clean_yaml_value(value)
            elif key == "description":
                description = clean_yaml_value(value)

    if not title:
        for line in text.splitlines():
            heading = HEADING.match(line)
            if heading:
                title = heading.group(1).strip()
                break

    info = PageInfo(title, description)
    cache[path] = info
    return info


def candidate_targets(root: Path, source: Path, raw_link: str) -> tuple[Path | None, str]:
    parsed = urlsplit(raw_link)
    if parsed.scheme.lower() in SKIP_SCHEMES or raw_link.startswith("//"):
        return None, "external"
    if not parsed.path:
        return None, "anchor-only"

    link_path = unquote(parsed.path)
    if link_path.startswith("/"):
        site_root = root / "site"
        base = site_root if site_root.exists() else root
        target = base / link_path.lstrip("/")
    else:
        target = source.parent / link_path
    return target.resolve(), "local"


def assess_target(target: Path) -> tuple[str, str, Path]:
    if target.exists():
        return "exists", "Local target exists.", target
    if target.suffix.lower() in {".html", ".htm"}:
        qmd = target.with_suffix(".qmd")
        md = target.with_suffix(".md")
        if qmd.exists():
            return "generated", "Rendered HTML is absent, but the matching QMD source exists.", qmd
        if md.exists():
            return "generated", "Rendered HTML is absent, but the matching Markdown source exists.", md

    index_qmd = target / "index.qmd"
    if index_qmd.exists():
        return "generated", "Directory target is expected to be generated from index.qmd.", index_qmd
    return "missing", "No matching local file or obvious Quarto source was found.", target


def relative_path(root: Path, path: Path) -> str:
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return str(path)


def works_label(status: str) -> str:
    if status == "exists":
        return "Yes — local target exists"
    if status == "generated":
        return "Yes — generated on render"
    return "No — target missing"


def escape_markdown(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", " ")


def main() -> int:
    args = parse_args()
    root = Path(args.root).resolve()
    scan_root = root / MANUAL_SCOPES[args.manual] if args.manual else root
    if not scan_root.is_dir():
        raise SystemExit(f"Check scope does not exist: {scan_root}")

    report_dir = root / args.report_dir
    report_dir.mkdir(parents=True, exist_ok=True)
    page_cache: dict[Path, PageInfo] = {}
    results: list[LinkResult] = []

    for source in iter_source_files(root, scan_root):
        try:
            lines = source.read_text(encoding="utf-8-sig", errors="replace").splitlines()
        except OSError:
            continue

        source_info = read_page_info(source, page_cache)
        context = "Page introduction"
        for number, line in enumerate(lines, start=1):
            heading = HEADING.match(line)
            if heading:
                context = heading.group(1).strip()

            markdown_links = [(text.strip(), target) for text, target in MARKDOWN_LINK.findall(line)]
            html_links = [("HTML link", target) for target in HTML_LINK.findall(line)]
            for link_text, raw_link in [*markdown_links, *html_links]:
                if "@@" in raw_link:
                    continue
                target, kind = candidate_targets(root, source, raw_link.strip("<>"))
                if kind != "local" or target is None:
                    continue

                status, note, assessed_target = assess_target(target)
                destination_info = read_page_info(assessed_target, page_cache)
                results.append(
                    LinkResult(
                        source_file=relative_path(root, source),
                        source_title=source_info.title,
                        source_description=source_info.description,
                        link_context=context,
                        line=number,
                        link_text=link_text,
                        link_target=raw_link,
                        destination_path=relative_path(root, assessed_target),
                        destination_title=destination_info.title,
                        destination_description=destination_info.description,
                        status=status,
                        works=works_label(status),
                        appropriateness="Not assessed",
                        note=note,
                    )
                )

    results.sort(key=lambda row: (row.status != "missing", row.source_file, row.line, row.link_target))
    report_name = f"{args.manual}-link-register" if args.manual else "local-links"
    csv_path = report_dir / f"{report_name}.csv"
    md_path = report_dir / f"{report_name}.md"
    counts = {status: sum(row.status == status for row in results) for status in ("missing", "generated", "exists")}

    headers = [
        "origin_path", "origin_page", "origin_summary", "link_context", "line", "link_text",
        "link_target", "destination_path", "destination_page", "destination_summary", "status",
        "link_works", "destination_appropriate", "note",
    ]
    with csv_path.open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.writer(handle)
        writer.writerow(headers)
        for row in results:
            writer.writerow([
                row.source_file, row.source_title, row.source_description, row.link_context, row.line,
                row.link_text, row.link_target, row.destination_path, row.destination_title,
                row.destination_description, row.status, row.works, row.appropriateness, row.note,
            ])

    scope_label = args.manual.title() + " Manual" if args.manual else "Whole repository"
    with md_path.open("w", encoding="utf-8") as handle:
        handle.write(f"# {scope_label} link register\n\n")
        handle.write(f"- Links checked: {len(results)}\n")
        handle.write(f"- Missing: {counts['missing']}\n")
        handle.write(f"- Expected generated targets: {counts['generated']}\n")
        handle.write(f"- Existing targets: {counts['exists']}\n\n")
        handle.write("Link validation is automated. Destination appropriateness requires human review.\n\n")
        handle.write("| Origin page | Link context | Link text | Link target | Destination page | Destination path | Link works? | Appropriate? |\n")
        handle.write("|---|---|---|---|---|---|---|---|\n")
        for row in results:
            origin = row.source_title or row.source_file
            destination = row.destination_title or "—"
            handle.write(
                "| " + " | ".join([
                    escape_markdown(origin),
                    escape_markdown(row.link_context),
                    escape_markdown(row.link_text),
                    f"`{escape_markdown(row.link_target)}`",
                    escape_markdown(destination),
                    f"`{escape_markdown(row.destination_path)}`",
                    escape_markdown(row.works),
                    row.appropriateness,
                ]) + " |\n"
            )

    print(f"{scope_label} link register complete: {len(results)} links checked")
    print(f"CSV report: {csv_path}")
    print(f"Markdown report: {md_path}")
    return 1 if counts["missing"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
