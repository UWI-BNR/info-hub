"""Check that every tracked BNR Stata path global is defined by the template."""

from __future__ import annotations

from pathlib import Path
import re


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
STATA_ROOT = REPOSITORY_ROOT / "scripts" / "stata"
PATH_TEMPLATE = STATA_ROOT / "config" / "bnr_paths_TEMPLATE.do"
STATA_SUFFIXES = {".ado", ".dlg", ".do", ".qmd", ".sthlp"}

DEFINITION = re.compile(r"^\s*global\s+(BNR_[A-Z0-9_]+)\b", re.MULTILINE)
REFERENCE = re.compile(r"\$(?:\{)?(BNR_[A-Z0-9_]+)")
WINDOWS_PATH = re.compile(r'''["'][A-Z]:[\\/]''', re.IGNORECASE)
LEGACY_PATH_EXCEPTIONS = {
    Path("scripts/stata/refit/bnrcvd-2023-forensics1.do"),
}


def main() -> int:
    """Report undefined path globals and return non-zero when any are found."""
    template_text = PATH_TEMPLATE.read_text(encoding="utf-8")
    definitions = set(DEFINITION.findall(template_text))
    references: dict[str, set[Path]] = {}
    hard_coded_paths: list[tuple[Path, int]] = []

    for path in STATA_ROOT.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in STATA_SUFFIXES:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        relative_path = path.relative_to(REPOSITORY_ROOT)
        for name in REFERENCE.findall(text):
            references.setdefault(name, set()).add(relative_path)
        if path != PATH_TEMPLATE and relative_path not in LEGACY_PATH_EXCEPTIONS:
            for line_number, line in enumerate(text.splitlines(), 1):
                stripped = line.lstrip()
                if stripped.startswith(("*", "//")):
                    continue
                if WINDOWS_PATH.search(line):
                    hard_coded_paths.append((relative_path, line_number))

    missing = sorted(set(references) - definitions)

    print("BNR Stata path-contract check")
    print(f"Defined:    {len(definitions)}")
    print(f"Referenced: {len(references)}")

    if missing or hard_coded_paths:
        print("FAILED")
        for name in missing:
            print(f"- {name} is not defined in {PATH_TEMPLATE.relative_to(REPOSITORY_ROOT)}")
            for path in sorted(references[name]):
                print(f"    {path}")
        for path, line_number in hard_coded_paths:
            print(f"- machine-specific Windows path: {path}:{line_number}")
        return 1

    print("PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
