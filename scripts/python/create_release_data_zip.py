#!/usr/bin/env python3
"""Create a portable, folder-aware public-data ZIP without changing data."""

from __future__ import annotations

import argparse
from pathlib import Path, PurePosixPath
import os
import tempfile
import zipfile


def portable_member_name(value: str) -> str:
    """Return one safe ZIP member name, always using POSIX separators."""
    name = PurePosixPath(value.replace("\\", "/"))
    if name.is_absolute() or ".." in name.parts or str(name) in {"", "."}:
        raise ValueError(f"Unsafe ZIP member name: {value}")
    return str(name)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create a portable ZIP from explicit source/member pairs."
    )
    parser.add_argument("--output", required=True, help="ZIP file to create")
    parser.add_argument(
        "--entry",
        action="append",
        nargs=2,
        metavar=("SOURCE", "MEMBER"),
        required=True,
        help="source file and its ZIP member name; may be repeated",
    )
    args = parser.parse_args()

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    entries: list[tuple[Path, str]] = []
    names: set[str] = set()
    for source_value, member_value in args.entry:
        source = Path(source_value)
        if not source.is_file():
            raise FileNotFoundError(f"Source file does not exist: {source}")
        member = portable_member_name(member_value)
        if member in names:
            raise ValueError(f"Duplicate ZIP member name: {member}")
        names.add(member)
        entries.append((source, member))

    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{output.stem}.", suffix=".tmp", dir=output.parent
    )
    os.close(descriptor)
    temporary = Path(temporary_name)
    try:
        with zipfile.ZipFile(
            temporary, mode="w", compression=zipfile.ZIP_DEFLATED
        ) as archive:
            for source, member in entries:
                archive.write(source, arcname=member)
            if archive.namelist() != [member for _, member in entries]:
                raise RuntimeError("ZIP member list did not match requested entries")
        temporary.replace(output)
    finally:
        if temporary.exists():
            temporary.unlink()

    print(f"Created portable ZIP with {len(entries)} files: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
