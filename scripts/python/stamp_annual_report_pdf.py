"""Apply restrained page furniture to a completed BNR annual-report PDF.

This utility deliberately has no analytical role.  Stata/putpdf creates every
page, figure, table and narrative element; this script adds a small header and
footer to the finished PDF candidate before the existing approval workflow.
"""

from __future__ import annotations

import argparse
from io import BytesIO
from pathlib import Path
import sys
import tempfile

from pypdf import PdfReader, PdfWriter
from reportlab.lib.colors import Color
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas


# BNR visual language, expressed as RGB proportions for ReportLab.
INK = Color(44 / 255, 62 / 255, 80 / 255)
MUTED = Color(102 / 255, 102 / 255, 102 / 255)
RULE = Color(222 / 255, 226 / 255, 230 / 255)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Add restrained BNR annual-report headers and footers to a PDF."
    )
    parser.add_argument("--input", required=True, type=Path, help="putpdf body PDF")
    parser.add_argument("--output", required=True, type=Path, help="finished candidate PDF")
    parser.add_argument(
        "--report-title",
        required=True,
        help="short annual-report title displayed in the running furniture",
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
    args.output.parent.mkdir(parents=True, exist_ok=True)


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

    # Header: logo plus title, deliberately quiet and above the putpdf margin.
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

    # Footer: stable report identity at left, automatic page numbering at right.
    page_canvas.line(36, 31, width - 36, 31)
    page_canvas.setFont("Helvetica", 7.2)
    page_canvas.drawString(36, 19, "Barbados National Registry")
    footer_right = f"Page {page_number} of {page_total}"
    page_canvas.drawRightString(width - 36, 19, footer_right)

    page_canvas.save()
    packet.seek(0)
    return PdfReader(packet).pages[0]


def stamp_pdf(args: argparse.Namespace) -> int:
    validate_args(args)

    reader = PdfReader(str(args.input))
    if reader.is_encrypted:
        raise ValueError("The putpdf body PDF is encrypted and cannot be stamped.")

    page_total = len(reader.pages)
    if page_total <= args.skip_first_pages:
        raise ValueError("The PDF has no interior pages available for page furniture.")

    writer = PdfWriter()
    visible_total = page_total - args.skip_first_pages
    for index, page in enumerate(reader.pages):
        if index >= args.skip_first_pages:
            page_number = index - args.skip_first_pages + 1
            overlay = footer_overlay(
                float(page.mediabox.width),
                float(page.mediabox.height),
                page_number,
                visible_total,
                args.report_title,
                args.logo,
            )
            page.merge_page(overlay)
        writer.add_page(page)

    with tempfile.NamedTemporaryFile(
        mode="wb", suffix=".pdf", dir=args.output.parent, delete=False
    ) as stream:
        temporary_output = Path(stream.name)
        writer.write(stream)

    try:
        check = PdfReader(str(temporary_output))
        if len(check.pages) != page_total:
            raise RuntimeError(
                f"Footer helper wrote {len(check.pages)} pages; expected {page_total}."
            )
        temporary_output.replace(args.output)
    finally:
        if temporary_output.exists():
            temporary_output.unlink()

    print("BNR annual PDF page furniture applied")
    print(f"Input:       {args.input}")
    print(f"Output:      {args.output}")
    print(f"Pages:       {page_total}")
    print(f"Decorated:   {visible_total}")
    return 0


def main() -> int:
    try:
        return stamp_pdf(parse_args())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
