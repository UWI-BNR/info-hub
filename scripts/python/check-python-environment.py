"""Validate the supported BNR Python environment without accessing private data."""

from __future__ import annotations

import importlib
from importlib.metadata import PackageNotFoundError, version
from pathlib import Path
import sys


TESTED_PYTHON = (3, 13)

# Distribution names do not always match their import names.
REQUIRED_PACKAGES = (
    ("PyCap", "redcap"),
    ("altair", "altair"),
    ("jupyter", "jupyter_core"),
    ("matplotlib", "matplotlib"),
    ("numpy", "numpy"),
    ("pandas", "pandas"),
    ("plotly", "plotly"),
    ("plotnine", "plotnine"),
    ("PyYAML", "yaml"),
    ("pypdf", "pypdf"),
    ("reportlab", "reportlab"),
)


def main() -> int:
    """Print an auditable environment summary and return non-zero on failure."""
    failures: list[str] = []
    python_version = sys.version.split()[0]
    in_virtual_environment = sys.prefix != sys.base_prefix

    print("BNR Python environment check")
    print(f"Python:      {python_version}")
    print(f"Executable:  {Path(sys.executable).resolve()}")
    print(f"Virtual env: {'yes' if in_virtual_environment else 'no'}")

    if sys.version_info[:2] != TESTED_PYTHON:
        failures.append(
            "Python 3.13 is the tested baseline; "
            f"found {sys.version_info.major}.{sys.version_info.minor}."
        )

    print("Packages:")
    for distribution, module in REQUIRED_PACKAGES:
        try:
            installed_version = version(distribution)
            importlib.import_module(module)
        except PackageNotFoundError:
            failures.append(f"{distribution} is not installed.")
            print(f"  {distribution:<12} MISSING")
        except Exception as exc:  # An installed but unusable package is a failure.
            failures.append(f"{distribution} could not be imported: {exc}")
            print(f"  {distribution:<12} IMPORT FAILED")
        else:
            print(f"  {distribution:<12} {installed_version}")

    if failures:
        print("FAILED")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
