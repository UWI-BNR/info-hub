"""Finish a completed BNR annual-report PDF.

Stata/putpdf creates every report page and the editorial contents
specification. This presentation-only helper replaces one explicit contents
placeholder with a dynamic, linked contents page, adds restrained running page
furniture, and can extract the final public-health-update appendix as a
standalone companion PDF before the existing approval workflow.
"""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from io import BytesIO
from pathlib import Path
import re
import sys
import tempfile
import unicodedata

from pypdf import PdfReader, PdfWriter
from pypdf.annotations import Link
from reportlab.lib.colors import Color
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase.pdfmetrics import stringWidth
from reportlab.pdfgen import canvas


INK = Color(44 / 255, 62 / 255, 80 / 255)
TEAL = Color(4 / 255, 81 / 255, 116 / 255)
MUTED = Color(102 / 255, 102 / 255, 102 / 255)
RULE = Color(222 / 255, 226 / 255, 230 / 255)
WHITE = Color(1, 1, 1)


@dataclass(frozen=True)
class TocEntry:
    """One Stata-owned contents entry and its resolved PDF destination."""

    level: int
    title: str
    anchor_text: str
    required_full_report: bool
    target_page_index: int | None = None


@dataclass(frozen=True)
class TocLayout:
    """Rendered contents page plus clickable entry rectangles."""

    page: object
    link_rectangles: tuple[tuple[float, float, float, float], ...]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Finish a BNR annual-report PDF with navigation and page furniture."
    )
    parser.add_argument("--input", required=True, type=Path, help="putpdf body PDF")
    parser.add_argument("--output", required=True, type=Path, help="finished candidate PDF")
    parser.add_argument(
        "--report-title",
        required=True,
        help="short annual-report title displayed in the running furniture",
    )
    parser.add_argument(
        "--report-year",
        help="report year substituted into {report_year} contents fields",
    )
    parser.add_argument(
        "--logo",
        type=Path,
        help="optional small logo placed at the top-left of interior pages",
    )
    parser.add_argument(
        "--skip-first-pages",
        type=int,
        default=1,
        help="number of leading pages left undecorated (default: 1 for the cover)",
    )
    parser.add_argument(
        "--toc-spec",
        action="append",
        type=Path,
        help=(
            "contents CSV with level, title, anchor_text and required_full_report; "
            "may be supplied once for the standard report and once for the "
            "year-specific Special chapter"
        ),
    )
    parser.add_argument(
        "--toc-placeholder",
        default="BNR_TOC_PLACEHOLDER",
        help="unique text identifying the putpdf page to replace",
    )
    parser.add_argument(
        "--toc-mode",
        choices=("adaptive", "full"),
        default="adaptive",
        help=(
            "adaptive omits sections absent from a shortened test render; "
            "full stops when a required section is absent"
        ),
    )
    parser.add_argument(
        "--extract-anchor",
        help="exact displayed heading identifying the final page to extract",
    )
    parser.add_argument(
        "--extract-output",
        type=Path,
        help="standalone one-page companion PDF written from the extracted page",
    )
    parser.add_argument(
        "--extract-title",
        help="short title displayed in the standalone running header",
    )
    return parser.parse_args()


def validate_args(args: argparse.Namespace) -> None:
    if not args.input.is_file():
        raise FileNotFoundError(f"Input PDF was not found: {args.input}")
    if args.input.resolve() == args.output.resolve():
        raise ValueError("Input and output PDFs must be different files.")
    if args.skip_first_pages < 0:
        raise ValueError("--skip-first-pages must be zero or greater.")
    if args.logo is not None and not args.logo.is_file():
        raise FileNotFoundError(f"Logo image was not found: {args.logo}")
    if args.toc_spec is not None:
        for toc_spec in args.toc_spec:
            if not toc_spec.is_file():
                raise FileNotFoundError(
                    f"Contents specification was not found: {toc_spec}"
                )
    if args.toc_spec is not None and not args.report_year:
        raise ValueError("--report-year is required when --toc-spec is used.")
    extraction_values = (
        args.extract_anchor,
        args.extract_output,
        args.extract_title,
    )
    if any(value is not None for value in extraction_values) and not all(
        value is not None for value in extraction_values
    ):
        raise ValueError(
            "--extract-anchor, --extract-output and --extract-title must be supplied together."
        )
    if args.extract_output is not None:
        if args.extract_output.resolve() in {
            args.input.resolve(),
            args.output.resolve(),
        }:
            raise ValueError("The extracted and annual PDF paths must be different files.")
        if not args.report_year:
            raise ValueError("--report-year is required for standalone page furniture.")
        args.extract_output.parent.mkdir(parents=True, exist_ok=True)
    args.output.parent.mkdir(parents=True, exist_ok=True)


def normalise_text(value: str) -> str:
    """Normalise extracted PDF text without weakening anchor matching."""
    value = unicodedata.normalize("NFKC", value)
    value = value.replace("\u2013", "-").replace("\u2014", "-")
    return re.sub(r"\s+", " ", value).strip().casefold()


def parse_required(value: str, row_number: int) -> bool:
    normalised = value.strip().casefold()
    if normalised in {"yes", "true", "1"}:
        return True
    if normalised in {"no", "false", "0"}:
        return False
    raise ValueError(
        f"Contents row {row_number}: required_full_report must be yes or no."
    )


def substitute_report_year(value: str, report_year: str) -> str:
    try:
        return value.format(report_year=report_year)
    except (KeyError, ValueError) as exc:
        raise ValueError(f"Invalid contents template field: {value}") from exc


def read_toc_spec(path: Path, report_year: str) -> list[TocEntry]:
    required_columns = {"level", "title", "anchor_text", "required_full_report"}
    entries: list[TocEntry] = []
    with path.open("r", encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        if reader.fieldnames is None or not required_columns.issubset(reader.fieldnames):
            missing = sorted(required_columns.difference(reader.fieldnames or []))
            raise ValueError(
                "Contents specification is missing column(s): " + ", ".join(missing)
            )
        for row_number, row in enumerate(reader, start=2):
            try:
                level = int(row["level"].strip())
            except (AttributeError, ValueError) as exc:
                raise ValueError(
                    f"Contents row {row_number}: level must be 1 or 2."
                ) from exc
            if level not in (1, 2):
                raise ValueError(f"Contents row {row_number}: level must be 1 or 2.")
            title = substitute_report_year(row["title"].strip(), report_year)
            anchor = substitute_report_year(row["anchor_text"].strip(), report_year)
            if not title or not anchor:
                raise ValueError(
                    f"Contents row {row_number}: title and anchor_text cannot be empty."
                )
            entries.append(
                TocEntry(
                    level=level,
                    title=title,
                    anchor_text=anchor,
                    required_full_report=parse_required(
                        row["required_full_report"], row_number
                    ),
                )
            )
    if not entries:
        raise ValueError("Contents specification contains no entries.")
    if entries[0].level != 1:
        raise ValueError("The first contents entry must be level 1.")
    return entries


def read_toc_specs(paths: list[Path], report_year: str) -> list[TocEntry]:
    """Combine reusable standard and year-specific Special-chapter entries."""
    entries: list[TocEntry] = []
    for path in paths:
        entries.extend(read_toc_spec(path, report_year))
    if not entries:
        raise ValueError("No contents specifications were supplied.")
    if entries[0].level != 1:
        raise ValueError("The first contents entry must be level 1.")
    return entries


def extracted_page_text(reader: PdfReader) -> list[tuple[str, ...]]:
    """Preserve extracted lines so an anchor must equal a displayed heading."""
    pages: list[tuple[str, ...]] = []
    for page in reader.pages:
        lines = tuple(
            normalised
            for line in (page.extract_text() or "").splitlines()
            if (normalised := normalise_text(line))
        )
        pages.append(lines)
    return pages


def find_unique_page(page_text: list[tuple[str, ...]], anchor: str) -> int | None:
    wanted = normalise_text(anchor)
    matches = [index for index, lines in enumerate(page_text) if wanted in lines]
    if len(matches) > 1:
        pages = ", ".join(str(index + 1) for index in matches)
        raise ValueError(
            f'Contents anchor occurs on more than one physical page: "{anchor}" ({pages}).'
        )
    return matches[0] if matches else None


def locate_toc_entries(
    entries: list[TocEntry],
    page_text: list[tuple[str, ...]],
    placeholder_page_index: int,
    toc_mode: str,
) -> tuple[list[TocEntry], list[str]]:
    resolved: list[TocEntry] = []
    omitted: list[str] = []
    current_level_one_present = False
    searchable_text = list(page_text)
    searchable_text[placeholder_page_index] = ()

    for entry in entries:
        target = find_unique_page(searchable_text, entry.anchor_text)
        if entry.level == 1:
            current_level_one_present = target is not None
        elif not current_level_one_present:
            target = None

        if target is None:
            if toc_mode == "full" and entry.required_full_report:
                raise ValueError(
                    f'Required annual-report contents anchor was not found: '
                    f'"{entry.anchor_text}".'
                )
            omitted.append(entry.title)
            continue

        resolved.append(
            TocEntry(
                level=entry.level,
                title=entry.title,
                anchor_text=entry.anchor_text,
                required_full_report=entry.required_full_report,
                target_page_index=target,
            )
        )

    if not resolved:
        raise ValueError("No contents entries were found in the rendered PDF.")
    return resolved, omitted


def visible_page_number(page_index: int, skipped_pages: int) -> int:
    number = page_index - skipped_pages + 1
    if number < 1:
        raise ValueError("A contents destination points into the unnumbered front pages.")
    return number


def render_toc_page(
    width: float,
    height: float,
    entries: list[TocEntry],
    skipped_pages: int,
) -> TocLayout:
    """Render one restrained contents page and capture its link areas."""
    packet = BytesIO()
    page_canvas = canvas.Canvas(packet, pagesize=(width, height))
    left = 47.0
    right = width - 47.0
    y = height - 78.0

    page_canvas.setFillColor(INK)
    page_canvas.setFont("Helvetica-Bold", 19)
    page_canvas.drawString(left, y, "Contents")
    y -= 28
    page_canvas.setStrokeColor(TEAL)
    page_canvas.setLineWidth(1.0)
    page_canvas.line(left, y, right, y)
    y -= 25

    link_rectangles: list[tuple[float, float, float, float]] = []
    for entry in entries:
        if entry.target_page_index is None:
            raise RuntimeError("An unresolved contents entry reached the renderer.")

        if entry.level == 1:
            font_name, font_size = "Helvetica-Bold", 10.2
            title_x, row_height, fill = left, 25, INK
        else:
            font_name, font_size = "Helvetica", 9.0
            title_x, row_height, fill = left + 18, 20, MUTED

        if y - row_height < 50:
            raise ValueError(
                "The dynamic contents entries do not fit on one page; "
                "reduce the contents specification."
            )

        page_number = str(
            visible_page_number(entry.target_page_index, skipped_pages)
        )
        page_canvas.setFillColor(fill)
        page_canvas.setFont(font_name, font_size)
        page_canvas.drawString(title_x, y, entry.title)
        page_canvas.drawRightString(right, y, page_number)

        title_end = title_x + stringWidth(entry.title, font_name, font_size) + 8
        number_start = right - stringWidth(page_number, font_name, font_size) - 8
        if number_start > title_end:
            page_canvas.setStrokeColor(RULE)
            page_canvas.setLineWidth(0.5)
            page_canvas.setDash(1, 2)
            page_canvas.line(title_end, y + 2, number_start, y + 2)
            page_canvas.setDash()

        link_rectangles.append((title_x, y - 5, right, y + font_size + 4))
        y -= row_height

    page_canvas.save()
    packet.seek(0)
    return TocLayout(
        page=PdfReader(packet).pages[0],
        link_rectangles=tuple(link_rectangles),
    )


def footer_overlay(
    width: float,
    height: float,
    page_number: int,
    page_total: int,
    report_title: str,
    logo: Path | None,
) -> object:
    """Return a one-page PDF overlay matching the target page dimensions."""
    packet = BytesIO()
    page_canvas = canvas.Canvas(packet, pagesize=(width, height))

    header_y = height - 20
    if logo is not None:
        image = ImageReader(str(logo))
        image_width, image_height = image.getSize()
        logo_height = 13
        logo_width = logo_height * image_width / image_height
        page_canvas.drawImage(
            image,
            36,
            header_y - logo_height + 3,
            width=logo_width,
            height=logo_height,
            mask="auto",
        )
        title_x = 36 + logo_width + 6
    else:
        title_x = 36

    page_canvas.setStrokeColor(RULE)
    page_canvas.setLineWidth(0.35)
    page_canvas.line(36, height - 31, width - 36, height - 31)
    page_canvas.setFillColor(MUTED)
    page_canvas.setFont("Helvetica", 7.2)
    page_canvas.drawString(title_x, header_y - 4, report_title)

    page_canvas.line(36, 31, width - 36, 31)
    page_canvas.setFont("Helvetica", 7.2)
    page_canvas.drawString(36, 19, "Barbados National Registry")
    footer_right = f"Page {page_number} of {page_total}"
    page_canvas.drawRightString(width - 36, 19, footer_right)

    page_canvas.save()
    packet.seek(0)
    return PdfReader(packet).pages[0]


def standalone_overlay(
    width: float,
    height: float,
    report_title: str,
    report_year: str,
    logo: Path | None,
) -> object:
    """Replace annual furniture with restrained one-page-product furniture."""
    packet = BytesIO()
    page_canvas = canvas.Canvas(packet, pagesize=(width, height))

    # The putpdf content starts inside 0.55-inch margins. These two white masks
    # cover only the annual helper's 31-point header/footer furniture.
    page_canvas.setFillColor(WHITE)
    page_canvas.rect(0, height - 33, width, 33, stroke=0, fill=1)
    page_canvas.rect(0, 0, width, 33, stroke=0, fill=1)

    header_y = height - 20
    if logo is not None:
        image = ImageReader(str(logo))
        image_width, image_height = image.getSize()
        logo_height = 13
        logo_width = logo_height * image_width / image_height
        page_canvas.drawImage(
            image,
            36,
            header_y - logo_height + 3,
            width=logo_width,
            height=logo_height,
            mask="auto",
        )
        title_x = 36 + logo_width + 6
    else:
        title_x = 36

    page_canvas.setStrokeColor(RULE)
    page_canvas.setLineWidth(0.35)
    page_canvas.line(36, height - 31, width - 36, height - 31)
    page_canvas.setFillColor(MUTED)
    page_canvas.setFont("Helvetica", 7.2)
    page_canvas.drawString(title_x, header_y - 4, report_title)

    page_canvas.line(36, 31, width - 36, 31)
    page_canvas.setFont("Helvetica", 7.0)
    page_canvas.drawString(36, 19, "Barbados National Registry")
    page_canvas.drawRightString(
        width - 36, 19, f"Public health update | {report_year}"
    )

    page_canvas.save()
    packet.seek(0)
    return PdfReader(packet).pages[0]


def extract_final_page(args: argparse.Namespace) -> None:
    """Extract one uniquely anchored final page and replace annual furniture."""
    if args.extract_output is None:
        return

    reader = PdfReader(str(args.output))
    page_text = extracted_page_text(reader)
    page_index = find_unique_page(page_text, args.extract_anchor)
    if page_index is None:
        raise ValueError(
            f'Public-health-update extraction anchor was not found: "{args.extract_anchor}".'
        )
    if page_index != len(reader.pages) - 1:
        raise ValueError(
            "The public-health-update anchor is not on the final physical page; "
            "the appendix may have spilled or the report order may have changed."
        )

    page = reader.pages[page_index]
    page.merge_page(
        standalone_overlay(
            float(page.mediabox.width),
            float(page.mediabox.height),
            args.extract_title,
            args.report_year,
            args.logo,
        )
    )

    writer = PdfWriter()
    writer.add_page(page)
    writer.add_metadata(
        {
            "/Title": args.extract_title,
            "/Subject": "BNR annual CVD public health update",
        }
    )

    with tempfile.NamedTemporaryFile(
        mode="wb", suffix=".pdf", dir=args.extract_output.parent, delete=False
    ) as stream:
        temporary_output = Path(stream.name)
        writer.write(stream)

    try:
        check = PdfReader(str(temporary_output))
        if len(check.pages) != 1:
            raise RuntimeError(
                f"Standalone helper wrote {len(check.pages)} pages; expected 1."
            )
        extracted_lines = extracted_page_text(check)[0]
        if normalise_text(args.extract_anchor) not in extracted_lines:
            raise RuntimeError(
                "The standalone PDF does not retain its required displayed title."
            )
        temporary_output.replace(args.extract_output)
    finally:
        if temporary_output.exists():
            temporary_output.unlink()


def finish_pdf(args: argparse.Namespace) -> int:
    validate_args(args)

    reader = PdfReader(str(args.input))
    if reader.is_encrypted:
        raise ValueError("The putpdf body PDF is encrypted and cannot be finished.")

    page_total = len(reader.pages)
    if page_total <= args.skip_first_pages:
        raise ValueError("The PDF has no interior pages available for page furniture.")

    entries: list[TocEntry] = []
    omitted: list[str] = []
    toc_page_index: int | None = None
    toc_layout: TocLayout | None = None
    pages = list(reader.pages)

    if args.toc_spec is not None:
        page_text = extracted_page_text(reader)
        placeholder_matches = [
            index
            for index, text in enumerate(page_text)
            if normalise_text(args.toc_placeholder) in " ".join(text)
        ]
        if len(placeholder_matches) != 1:
            raise ValueError(
                "Expected exactly one contents placeholder page; "
                f"found {len(placeholder_matches)}."
            )
        toc_page_index = placeholder_matches[0]
        if toc_page_index < args.skip_first_pages:
            raise ValueError("The contents placeholder is inside the unnumbered cover pages.")

        spec_entries = read_toc_specs(args.toc_spec, args.report_year)
        entries, omitted = locate_toc_entries(
            spec_entries, page_text, toc_page_index, args.toc_mode
        )
        placeholder_page = pages[toc_page_index]
        toc_layout = render_toc_page(
            float(placeholder_page.mediabox.width),
            float(placeholder_page.mediabox.height),
            entries,
            args.skip_first_pages,
        )
        pages[toc_page_index] = toc_layout.page

    writer = PdfWriter()
    visible_total = page_total - args.skip_first_pages
    for index, page in enumerate(pages):
        if index >= args.skip_first_pages:
            overlay = footer_overlay(
                float(page.mediabox.width),
                float(page.mediabox.height),
                visible_page_number(index, args.skip_first_pages),
                visible_total,
                args.report_title,
                args.logo,
            )
            page.merge_page(overlay)
        writer.add_page(page)

    if reader.metadata:
        metadata = {
            str(key): str(value)
            for key, value in reader.metadata.items()
            if value is not None
        }
        if metadata:
            writer.add_metadata(metadata)

    if toc_page_index is not None and toc_layout is not None:
        parent_outline = None
        for entry, rectangle in zip(entries, toc_layout.link_rectangles, strict=True):
            if entry.target_page_index is None:
                raise RuntimeError("An unresolved contents entry reached PDF assembly.")
            writer.add_annotation(
                toc_page_index,
                Link(rect=rectangle, target_page_index=entry.target_page_index),
            )
            if entry.level == 1:
                parent_outline = writer.add_outline_item(
                    entry.title, entry.target_page_index, bold=True
                )
            else:
                if parent_outline is None:
                    raise ValueError("A level-2 contents item has no level-1 parent.")
                writer.add_outline_item(
                    entry.title,
                    entry.target_page_index,
                    parent=parent_outline,
                )

    with tempfile.NamedTemporaryFile(
        mode="wb", suffix=".pdf", dir=args.output.parent, delete=False
    ) as stream:
        temporary_output = Path(stream.name)
        writer.write(stream)

    try:
        check = PdfReader(str(temporary_output))
        if len(check.pages) != page_total:
            raise RuntimeError(
                f"PDF helper wrote {len(check.pages)} pages; expected {page_total}."
            )
        if toc_page_index is not None:
            annotations = check.pages[toc_page_index].get("/Annots", [])
            if len(annotations) < len(entries):
                raise RuntimeError(
                    "The finished contents page does not contain every expected link."
                )
        temporary_output.replace(args.output)
    finally:
        if temporary_output.exists():
            temporary_output.unlink()

    extract_final_page(args)

    print("BNR annual PDF finishing completed")
    print(f"Input:       {args.input}")
    print(f"Output:      {args.output}")
    print(f"Pages:       {page_total}")
    print(f"Decorated:   {visible_total}")
    if args.toc_spec is not None:
        print(f"TOC mode:    {args.toc_mode}")
        print(f"TOC entries: {len(entries)}")
        print(f"TOC omitted: {len(omitted)}")
        for title in omitted:
            print(f"  omitted from this render: {title}")
    if args.extract_output is not None:
        print(f"Extracted:   {args.extract_output}")
        print("Extract pages: 1")
    return 0


def main() -> int:
    try:
        return finish_pdf(parse_args())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
