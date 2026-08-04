from datetime import date
from pathlib import Path, PurePosixPath
import re
import sys


# ---------------------------------------------------------------------------
# BNR download catalogue builder
#
# Purpose:
#   Combine approved briefing and metric download records into one site-wide
#   downloads/downloads.yml file for the Quarto downloads listing page.
#
# Scope:
#   Publication-layer indexing only.
#   This script does not compute, transform, approve, or validate surveillance
#   results. It checks only the catalogue metadata and referenced ZIP files.
#
# Dependency policy:
#   Standard-library Python only. No PyYAML dependency.
#
# Expected inputs:
#   site/downloads/files/briefings/{briefing_id}/downloads.yml
#   site/downloads/files/metrics/**/catalogue/{release_id}.yml
#
# Output:
#   site/downloads/downloads.yml
#
# Important:
#   Paths are resolved from this script's location, not from the current
#   terminal working directory.
#
# Public catalogue rule:
#   The central downloads page lists approved ZIP packages only.
#
# Failure-safety rule:
#   Every input and every selected ZIP is validated before the central file is
#   written. If validation fails, the existing downloads.yml is left unchanged.
#
# Preview-safety rule:
#   The output file is written only when its content has changed. This prevents
#   Quarto preview from entering a live-reload loop when this script is run as
#   a pre-render step.
# ---------------------------------------------------------------------------


SCRIPT_PATH = Path(__file__).resolve()
SITE_ROOT = SCRIPT_PATH.parent.parent

DOWNLOADS_ROOT = SITE_ROOT / "downloads"
BRIEFINGS_DIR = DOWNLOADS_ROOT / "files" / "briefings"
METRICS_DIR = DOWNLOADS_ROOT / "files" / "metrics"
OUTPUT_FILE = DOWNLOADS_ROOT / "downloads.yml"

SUPPORTED_PACKAGE_TYPES = {
    "briefing": "Briefing",
    "metric": "Metric dataset",
}

SUPPORTED_SCHEMA = "bnr_download_manifest_v1"


class CatalogueError(Exception):
    """Controlled catalogue validation error."""


def write_text_if_changed(path, content):
    """
    Write text only when the file content has actually changed.

    Returns:
        True  if the file was written
        False if the existing file was already identical
    """
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)

    if path.exists():
        old_content = path.read_text(encoding="utf-8")
        if old_content == content:
            return False

    path.write_text(content, encoding="utf-8", newline="\n")
    return True


def coerce_value(value):
    """Coerce a simple YAML scalar into a Python value."""
    value = value.strip()

    if value == "":
        return ""

    if (value.startswith('"') and value.endswith('"')) or (
        value.startswith("'") and value.endswith("'")
    ):
        value = value[1:-1]

    lower_value = value.lower()

    if lower_value == "true":
        return True

    if lower_value == "false":
        return False

    if lower_value in {"null", "none", "~"}:
        return ""

    try:
        return int(value)
    except ValueError:
        return value


def parse_key_value(text):
    """Parse a simple key: value line."""
    if ":" not in text:
        return None, None

    key, value = text.split(":", 1)
    return key.strip(), coerce_value(value)


def collect_block(lines, start_index, indent):
    """Collect a simple YAML block scalar."""
    values = []
    index = start_index

    while index < len(lines):
        line = lines[index].rstrip("\n")

        if line.strip() == "":
            values.append("")
            index += 1
            continue

        current_indent = len(line) - len(line.lstrip(" "))

        if current_indent < indent:
            break

        values.append(line[indent:].rstrip())
        index += 1

    return "\n".join(values).strip(), index


def parse_download_manifest(path):
    """
    Parse one BNR download record.

    This is deliberately a small parser for the restricted manifest structure
    written by the BNR publication jobs. It is not a general YAML parser.
    Unsupported or incomplete structures fail later through required-field
    validation rather than being accepted silently.
    """
    lines = path.read_text(encoding="utf-8-sig").splitlines()

    if any("\t" in line for line in lines):
        raise CatalogueError("Tab indentation is not permitted in catalogue YAML.")

    manifest = {}
    downloads = []
    index = 0
    downloads_section_found = False

    while index < len(lines):
        line = lines[index].rstrip("\n")

        if line.strip() == "" or line.lstrip().startswith("#"):
            index += 1
            continue

        if line.startswith("downloads:"):
            downloads_section_found = True
            index += 1
            break

        block_match = re.match(r"^([A-Za-z0-9_-]+):\s*\|-\s*$", line)

        if block_match:
            key = block_match.group(1)
            value, index = collect_block(lines, index + 1, indent=2)
            manifest[key] = value
            continue

        if not line.startswith(" "):
            key, value = parse_key_value(line)

            if key:
                manifest[key] = value

        index += 1

    if not downloads_section_found:
        raise CatalogueError("Required downloads: section was not found.")

    current_download = None

    while index < len(lines):
        line = lines[index].rstrip("\n")

        if line.strip() == "" or line.lstrip().startswith("#"):
            index += 1
            continue

        if line.startswith("  - "):
            if current_download:
                downloads.append(current_download)

            current_download = {}
            first_item_text = line[4:].strip()

            if first_item_text:
                key, value = parse_key_value(first_item_text)

                if key:
                    current_download[key] = value

            index += 1
            continue

        if current_download is not None and line.startswith("    "):
            item_line = line[4:]
            block_match = re.match(r"^([A-Za-z0-9_-]+):\s*\|-\s*$", item_line)

            if block_match:
                key = block_match.group(1)
                value, index = collect_block(lines, index + 1, indent=6)
                current_download[key] = value
                continue

            key, value = parse_key_value(item_line)

            if key:
                current_download[key] = value

        index += 1

    if current_download:
        downloads.append(current_download)

    manifest["downloads"] = downloads
    return manifest


def required_text(record, field, source_path):
    """Return one required, non-empty text field."""
    value = str(record.get(field, "")).strip()

    if not value:
        raise CatalogueError(f"Missing required field '{field}' in {source_path}")

    return value


def package_type_from_manifest(manifest, source_path):
    """Read and normalise the briefing or metric package type."""
    raw_value = manifest.get("package_type", manifest.get("output_type", ""))
    package_type = str(raw_value).strip().lower()

    if not package_type:
        raise CatalogueError(
            f"Missing required field 'package_type' or 'output_type' in {source_path}"
        )

    if package_type not in SUPPORTED_PACKAGE_TYPES:
        raise CatalogueError(
            f"Unsupported package type '{raw_value}' in {source_path}. "
            "Expected briefing or metric."
        )

    return package_type


def package_id_from_manifest(manifest, package_type, source_path):
    """Read the existing briefing ID or the metric package ID."""
    if package_type == "briefing":
        value = manifest.get("briefing_id", manifest.get("package_id", ""))
        expected_field = "briefing_id"
    else:
        value = manifest.get("package_id", "")
        expected_field = "package_id"

    package_id = str(value).strip()

    if not package_id:
        raise CatalogueError(
            f"Missing required field '{expected_field}' in {source_path}"
        )

    return package_id


def validated_iso_date(value, source_path):
    """Validate and return an ISO calendar date in YYYY-MM-DD form."""
    date_text = str(value).strip()

    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", date_text):
        raise CatalogueError(
            f"Invalid release_date '{date_text}' in {source_path}. "
            "Expected YYYY-MM-DD."
        )

    try:
        date.fromisoformat(date_text)
    except ValueError as error:
        raise CatalogueError(
            f"Invalid release_date '{date_text}' in {source_path}: {error}"
        ) from error

    return date_text


def validated_href(value, source_path):
    """Validate one internal ZIP href and return it unchanged."""
    href = str(value).strip()

    if not href:
        raise CatalogueError(f"Missing required field 'href' in {source_path}")

    if "://" in href or href.startswith("//"):
        raise CatalogueError(f"External href is not permitted in {source_path}: {href}")

    if not href.startswith("files/"):
        raise CatalogueError(
            f"Catalogue href must begin with 'files/' in {source_path}: {href}"
        )

    if "\\" in href:
        raise CatalogueError(
            f"Catalogue href must use forward slashes in {source_path}: {href}"
        )

    href_path = PurePosixPath(href)

    if href_path.is_absolute() or ".." in href_path.parts:
        raise CatalogueError(f"Unsafe catalogue href in {source_path}: {href}")

    if href_path.suffix.lower() != ".zip":
        raise CatalogueError(f"ZIP catalogue href does not end in .zip: {href}")

    actual_path = DOWNLOADS_ROOT.joinpath(*href_path.parts)

    if not actual_path.is_file():
        raise CatalogueError(
            f"Referenced ZIP does not exist for {source_path}: {actual_path}"
        )

    return href, actual_path


def format_size(size_bytes):
    """Return a compact file size label."""
    if not size_bytes:
        return ""

    units = ["B", "KB", "MB", "GB"]
    size = float(size_bytes)

    for unit in units:
        if size < 1024 or unit == units[-1]:
            if unit == "B":
                return f"{int(size)} {unit}"

            return f"{size:.1f} {unit}"

        size = size / 1024

    return ""


def yaml_value(value, indent=2):
    """Return a YAML-safe value."""
    spaces = " " * indent

    if value is None:
        return '""'

    if isinstance(value, bool):
        return "true" if value else "false"

    if isinstance(value, int):
        return str(value)

    value = str(value)

    if "\n" in value or len(value) > 90:
        lines = value.splitlines() or [""]
        return "|-\n" + "\n".join(f"{spaces}{line}" for line in lines)

    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def sort_order_value(value):
    """Return a safe integer sort order."""
    try:
        return int(value)
    except (TypeError, ValueError):
        return 9999


def discover_source_records():
    """Return briefing and metric catalogue-record paths."""
    source_paths = []

    if BRIEFINGS_DIR.exists():
        briefing_paths = sorted(BRIEFINGS_DIR.glob("*/downloads.yml"))
        source_paths.extend(briefing_paths)
        print(f"Briefing records found: {len(briefing_paths)}")
    else:
        print("WARNING: Briefings catalogue folder was not found.")

    if METRICS_DIR.exists():
        metric_paths = sorted(METRICS_DIR.glob("**/catalogue/*.yml"))
        source_paths.extend(metric_paths)
        print(f"Metric records found:   {len(metric_paths)}")
    else:
        print("WARNING: Metrics catalogue folder was not found.")

    return source_paths


def rows_from_manifest(manifest, source_path):
    """Validate one source record and return its public ZIP catalogue rows."""
    schema = required_text(manifest, "schema", source_path)

    if schema != SUPPORTED_SCHEMA:
        raise CatalogueError(
            f"Unsupported schema '{schema}' in {source_path}. "
            f"Expected {SUPPORTED_SCHEMA}."
        )

    download_items = manifest.get("downloads", [])

    if not isinstance(download_items, list):
        raise CatalogueError(
            f"The downloads section is not a list in {source_path}"
        )

    # A package-level manifest may deliberately contribute nothing to the
    # central downloads catalogue. This is used, for example, by supporting
    # public artefacts that are copied to the site but are not offered as a
    # downloadable ZIP package.
    #
    # Determine whether the manifest has an eligible ZIP before validating
    # briefing- or metric-specific fields. An unsupported package type is
    # therefore harmless when it requests no catalogue listing, but it still
    # fails closed if it attempts to list a ZIP.
    listed_zip_items = []

    for item_number, item in enumerate(download_items, start=1):
        if not isinstance(item, dict):
            raise CatalogueError(
                f"Download item {item_number} is not a record in {source_path}"
            )

        include_in_listing = item.get("include_in_listing", True)
        item_format = str(item.get("format", "")).strip().upper()

        if include_in_listing is not False and item_format == "ZIP":
            listed_zip_items.append((item_number, item))

    if not listed_zip_items:
        return []

    package_type = package_type_from_manifest(manifest, source_path)
    output_type = SUPPORTED_PACKAGE_TYPES[package_type]
    output_id = package_id_from_manifest(manifest, package_type, source_path)
    output_title = required_text(manifest, "title", source_path)
    surveillance_area = required_text(manifest, "surveillance_area", source_path)
    domain = required_text(manifest, "domain", source_path)
    period = required_text(manifest, "period", source_path)
    updated = validated_iso_date(
        required_text(manifest, "release_date", source_path), source_path
    )

    if package_type == "metric":
        required_text(manifest, "release_id", source_path)
        required_text(manifest, "metric_family", source_path)

    rows = []

    for item_number, item in listed_zip_items:
        item_format = "ZIP"
        item_source = f"{source_path} (download item {item_number})"
        title = required_text(item, "title", item_source)
        description = required_text(item, "description", item_source)
        href, actual_path = validated_href(item.get("href", ""), item_source)
        file_name = str(item.get("file", "")).strip() or PurePosixPath(href).name
        size_bytes = actual_path.stat().st_size

        rows.append(
            {
                "title": title,
                "output_type": output_type,
                "output_title": output_title,
                "output_id": output_id,
                "surveillance_area": surveillance_area,
                "domain": domain,
                "period": period,
                "artefact_type": item.get("artefact_type", "ZIP package"),
                "format": item_format,
                "description": description,
                "href": href,
                "path": href,
                "file": file_name,
                "updated": updated,
                "size": format_size(size_bytes),
                "size_bytes": size_bytes,
                "sort_order": sort_order_value(item.get("sort_order", 9999)),
            }
        )

    return rows


def validate_unique_rows(rows):
    """Stop if two listed records share an output ID or ZIP path."""
    output_ids = {}
    zip_paths = {}

    for row in rows:
        output_id = row["output_id"]
        zip_path = row["path"]

        if output_id in output_ids:
            raise CatalogueError(
                f"Duplicate output_id '{output_id}' for:\n"
                f"  {output_ids[output_id]}\n"
                f"  {zip_path}"
            )

        if zip_path in zip_paths:
            raise CatalogueError(
                f"Duplicate ZIP path '{zip_path}' for:\n"
                f"  {zip_paths[zip_path]}\n"
                f"  {output_id}"
            )

        output_ids[output_id] = zip_path
        zip_paths[zip_path] = output_id


def write_catalogue(rows):
    """
    Write the flattened site-wide downloads catalogue.

    Returns:
        True  if downloads.yml was written
        False if downloads.yml was already up to date
    """
    if not rows:
        return write_text_if_changed(OUTPUT_FILE, "[]\n")

    fields = [
        "title",
        "output_type",
        "output_title",
        "output_id",
        "surveillance_area",
        "domain",
        "period",
        "artefact_type",
        "format",
        "description",
        "href",
        "path",
        "file",
        "updated",
        "size",
        "size_bytes",
        "sort_order",
    ]

    output_lines = []

    for row in rows:
        output_lines.append(f"- title: {yaml_value(row.get('title', ''), indent=4)}")

        for field in fields[1:]:
            output_lines.append(
                f"  {field}: {yaml_value(row.get(field, ''), indent=4)}"
            )

    output_text = "\n".join(output_lines) + "\n"
    return write_text_if_changed(OUTPUT_FILE, output_text)


def build_catalogue():
    """Build the site-wide download catalogue."""
    print("BNR download catalogue builder")
    print(f"Site root:        {SITE_ROOT}")
    print(f"Briefings folder: {BRIEFINGS_DIR}")
    print(f"Metrics folder:   {METRICS_DIR}")
    print(f"Output file:      {OUTPUT_FILE}")
    print("")

    source_paths = discover_source_records()
    rows = []

    try:
        for source_path in source_paths:
            try:
                manifest = parse_download_manifest(source_path)
            except CatalogueError:
                raise
            except Exception as error:
                raise CatalogueError(
                    f"Could not parse {source_path}: {error}"
                ) from error

            source_rows = rows_from_manifest(manifest, source_path)
            rows.extend(source_rows)
            print(f"  {source_path.relative_to(DOWNLOADS_ROOT)}: {len(source_rows)} ZIP row(s)")

        validate_unique_rows(rows)
    except CatalogueError as error:
        print("", file=sys.stderr)
        print("CATALOGUE BUILD STOPPED", file=sys.stderr)
        print(str(error), file=sys.stderr)
        print("", file=sys.stderr)
        print(f"Existing catalogue retained: {OUTPUT_FILE}", file=sys.stderr)
        return 1

    rows.sort(
        key=lambda row: (
            row.get("updated", ""),
            row.get("surveillance_area", ""),
            row.get("output_type", ""),
            row.get("output_id", ""),
            sort_order_value(row.get("sort_order", 9999)),
            row.get("title", ""),
        )
    )

    was_written = write_catalogue(rows)

    print("")
    print(f"Download catalogue checked: {OUTPUT_FILE}")
    print(f"Download rows found:        {len(rows)}")
    print("Catalogue status: written" if was_written else "Catalogue status: unchanged")

    return 0


if __name__ == "__main__":
    raise SystemExit(build_catalogue())
