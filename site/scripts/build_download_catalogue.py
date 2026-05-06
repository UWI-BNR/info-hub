from pathlib import Path
import re
import sys


# ---------------------------------------------------------------------------
# BNR download catalogue builder
#
# Purpose:
#   Combine briefing-level downloads.yml manifests into one site-wide
#   downloads/downloads.yml file for the Quarto downloads listing page.
#
# Scope:
#   Publication-layer indexing only.
#   This script does not compute, transform, or validate surveillance results.
#
# Dependency policy:
#   Standard-library Python only. No PyYAML dependency.
#
# Expected input:
#   site/downloads/files/briefings/{briefing_id}/downloads.yml
#
# Output:
#   site/downloads/downloads.yml
#
# Important:
#   Paths are resolved from this script's location, not from the current
#   terminal working directory.
# ---------------------------------------------------------------------------


SCRIPT_PATH = Path(__file__).resolve()
SITE_ROOT = SCRIPT_PATH.parent.parent

BRIEFINGS_DIR = SITE_ROOT / "downloads" / "files" / "briefings"
OUTPUT_FILE = SITE_ROOT / "downloads" / "downloads.yml"


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
    Parse one briefing-level downloads.yml file.

    This is deliberately a small parser for the restricted manifest structure
    written by the BNR Stata briefing jobs. It is not intended to be a general
    YAML parser.
    """
    lines = path.read_text(encoding="utf-8-sig").splitlines()

    manifest = {}
    downloads = []
    index = 0

    while index < len(lines):
        line = lines[index].rstrip("\n")

        if line.strip() == "":
            index += 1
            continue

        if line.startswith("downloads:"):
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

    current_download = None

    while index < len(lines):
        line = lines[index].rstrip("\n")

        if line.strip() == "":
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


def write_catalogue(rows):
    """Write the flattened site-wide downloads catalogue."""
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)

    if not rows:
        OUTPUT_FILE.write_text("[]\n", encoding="utf-8")
        return

    fields = [
        "title",
        "briefing_title",
        "briefing_id",
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

    OUTPUT_FILE.write_text("\n".join(output_lines) + "\n", encoding="utf-8")


def build_catalogue():
    """Build the site-wide download catalogue."""
    print("BNR download catalogue builder")
    print(f"Site root:        {SITE_ROOT}")
    print(f"Briefings folder: {BRIEFINGS_DIR}")
    print(f"Output file:      {OUTPUT_FILE}")

    if not BRIEFINGS_DIR.exists():
        print("")
        print("WARNING: Briefings folder was not found.")
        print("Writing empty downloads.yml.")
        write_catalogue([])
        return 0

    manifest_paths = sorted(BRIEFINGS_DIR.glob("*/downloads.yml"))

    print(f"Manifests found:  {len(manifest_paths)}")

    if not manifest_paths:
        print("")
        print("WARNING: No briefing-level downloads.yml files were found.")
        print("Writing empty downloads.yml.")
        write_catalogue([])
        return 0

    rows = []

    for manifest_path in manifest_paths:
        try:
            manifest = parse_download_manifest(manifest_path)
        except Exception as error:
            print(f"ERROR: Could not parse {manifest_path}", file=sys.stderr)
            print(str(error), file=sys.stderr)
            return 1

        briefing_id = manifest.get("briefing_id", manifest_path.parent.name)
        briefing_title = manifest.get("title", briefing_id)
        surveillance_area = manifest.get("surveillance_area", "")
        domain = manifest.get("domain", "")
        period = str(manifest.get("period", ""))
        updated = str(manifest.get("release_date", ""))

        download_items = manifest.get("downloads", [])

        print(
            f"  {manifest_path.parent.name}: "
            f"{len(download_items)} download item(s)"
        )

        for item in download_items:
            include_in_listing = item.get("include_in_listing", True)

            if include_in_listing is False:
                continue

            href = str(item.get("href", "")).strip()
            file_path = str(item.get("file", "")).strip()
            title = str(item.get("title", "")).strip()

            # Skip incomplete download records.
            # An empty href can render as a link to the current page.
            if not href or not title:
                print(
                    f"    skipped incomplete item in {manifest_path.parent.name}: "
                    f"title='{title}', href='{href}'"
                )
                continue

            actual_path = SITE_ROOT / "downloads" / Path(href)

            size_bytes = 0
            size = ""

            if href and actual_path.exists():
                size_bytes = actual_path.stat().st_size
                size = format_size(size_bytes)

            rows.append(
                {
                    "title": title,
                    "briefing_title": briefing_title,
                    "briefing_id": briefing_id,
                    "surveillance_area": surveillance_area,
                    "domain": domain,
                    "period": period,
                    "artefact_type": item.get("artefact_type", ""),
                    "format": item.get("format", ""),
                    "description": item.get("description", ""),
                    "href": href,
                    "path": href,
                    "file": file_path,
                    "updated": updated,
                    "size": size,
                    "size_bytes": size_bytes,
                    "sort_order": item.get("sort_order", 9999),
                }
            )

    rows.sort(
        key=lambda row: (
            row.get("updated", ""),
            row.get("surveillance_area", ""),
            row.get("briefing_id", ""),
            int(row.get("sort_order", 9999)),
        )
    )

    write_catalogue(rows)

    print("")
    print(f"Download catalogue written: {OUTPUT_FILE}")
    print(f"Download rows written:      {len(rows)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(build_catalogue())