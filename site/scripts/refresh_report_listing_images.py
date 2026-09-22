"""Assign listing images consistently before a full Info-Hub render.

This presentation-only helper reads the editable listing-images.csv catalogue
and updates image metadata on published CVD report landing pages. It does not
read analytical data or alter report text, dates, identifiers or links.
"""

from __future__ import annotations

import csv
import re
import sys
from dataclasses import dataclass
from pathlib import Path


VISIBLE_LATEST_CARDS = 6
REPORT_KINDS = ("updates", "annual", "briefings", "studies")
FRONT_MATTER = re.compile(r"\A---\r?\n(.*?)\r?\n---", re.DOTALL)


@dataclass(frozen=True)
class ListingImage:
    filename: str
    alt_text: str


@dataclass(frozen=True)
class ReportPage:
    path: Path
    date: str
    report_id: str


def front_matter_value(front_matter: str, name: str) -> str:
    match = re.search(rf"(?m)^{re.escape(name)}:\s*[\"']?([^\n\"']+)[\"']?\s*$", front_matter)
    return match.group(1).strip() if match else ""


def active_images(catalogue: Path, image_dir: Path) -> list[ListingImage]:
    with catalogue.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))

    required = {"image_file", "image_alt", "active"}
    if not rows or not required.issubset(rows[0]):
        raise ValueError("Listing image catalogue must have image_file, image_alt and active columns.")

    images = []
    for row in rows:
        if row["active"].strip().lower() != "yes":
            continue
        filename = row["image_file"].strip()
        alt_text = row["image_alt"].strip()
        if not filename or not alt_text:
            raise ValueError("Each active listing image needs both a filename and alternative text.")
        if Path(filename).name != filename or Path(filename).suffix.lower() != ".webp":
            raise ValueError(f"Listing image filename must be a WebP filename only: {filename}")
        if not (image_dir / filename).is_file():
            raise ValueError(f"Active listing image is missing: {image_dir / filename}")
        images.append(ListingImage(filename, alt_text))

    if len(images) < VISIBLE_LATEST_CARDS:
        raise ValueError(
            f"At least {VISIBLE_LATEST_CARDS} active listing images are required for the "
            f"{VISIBLE_LATEST_CARDS} Latest Surveillance Output cards; found {len(images)}."
        )
    return images


def report_pages(reports_root: Path) -> list[ReportPage]:
    pages = []
    for kind in REPORT_KINDS:
        for path in (reports_root / kind).glob("*/index.qmd"):
            text = path.read_text(encoding="utf-8")
            match = FRONT_MATTER.match(text)
            if not match:
                raise ValueError(f"Published report page has no YAML header: {path}")
            front_matter = match.group(1)
            date = front_matter_value(front_matter, "date")
            report_id = front_matter_value(front_matter, "report-id")
            if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", date) or not report_id:
                raise ValueError(f"Published report page needs ISO date and report-id: {path}")
            pages.append(ReportPage(path, date, report_id))
    return sorted(pages, key=lambda page: (page.date, page.report_id), reverse=True)


def replace_yaml_value(front_matter: str, name: str, value: str) -> str:
    pattern = re.compile(rf"(?m)^{re.escape(name)}:.*$")
    replacement = f'{name}: "{value}"'
    if not pattern.search(front_matter):
        raise ValueError(f"Published report page is missing {name} metadata.")
    return pattern.sub(replacement, front_matter, count=1)


def apply_images(pages: list[ReportPage], images: list[ListingImage]) -> int:
    changed = 0
    for index, page in enumerate(pages):
        image = images[index % len(images)]
        text = page.path.read_text(encoding="utf-8")
        match = FRONT_MATTER.match(text)
        assert match is not None
        front_matter = replace_yaml_value(match.group(1), "image", f"/assets/images/listings/{image.filename}")
        front_matter = replace_yaml_value(front_matter, "image-alt", image.alt_text)
        refreshed = f"---\n{front_matter}\n---" + text[match.end():]
        if refreshed != text:
            page.path.write_text(refreshed, encoding="utf-8")
            changed += 1
    return changed


def main() -> int:
    site_root = Path(__file__).resolve().parents[1]
    image_dir = site_root / "assets" / "images" / "listings"
    images = active_images(image_dir / "listing-images.csv", image_dir)
    pages = report_pages(site_root / "surveillance" / "cvd" / "reports")
    print(f"Report-listing images: {len(pages)} page(s), {len(images)} active image(s), {apply_images(pages, images)} page(s) updated.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as error:
        print(f"Report-listing image refresh stopped: {error}", file=sys.stderr)
        raise SystemExit(1)
