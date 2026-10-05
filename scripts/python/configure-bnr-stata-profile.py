"""Update BNR startup paths without changing SHG or other profile entries.

Called by setup-bnr-python.ps1. Uses only the Python standard library.
Supports ordinary line-delimited Stata profiles; unusual syntax stops safely.
Never edits LOCAL.do or reads token files. Existing profiles receive a backup.
"""

from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path
import os
import re
import shutil
import sys
import tempfile


BEGIN = "* BEGIN BNR PYTHON STARTUP (managed by setup-bnr-python)"
END = "* END BNR PYTHON STARTUP"
PYTHON_COMMAND = 'python set exec "$BNR_PYTHON_EXE", permanently'
LOCAL_GLOBAL = 'global BNR_PYTHON_EXE "$BNR_REPO/venv-info-hub/Scripts/python.exe"'


def read_text(path: Path) -> tuple[str, str]:
    """Keep BOM/encoding; do not guess a legacy encoding and corrupt names."""
    raw = path.read_bytes()
    if raw.startswith(b"\xfe\xff"):
        return raw[2:].decode("utf-16-be"), "utf-16-be"
    if raw.startswith(b"\xff\xfe"):
        return raw.decode("utf-16"), "utf-16"
    if raw.startswith(b"\xef\xbb\xbf"):
        return raw.decode("utf-8-sig"), "utf-8-sig"
    return raw.decode("utf-8"), "utf-8"


def commands(text: str) -> list[tuple[int, int, str]]:
    """Identify complete commands, skipping comments and joining /// lines.

    Keep original line offsets so only named commands are replaced.
    #delimit and conditional startup blocks require manual review.
    """
    result = []
    block_comment = False
    pending = []
    start = 0
    for index, line in enumerate(text.splitlines(keepends=True)):
        stripped = line.lstrip()
        if not block_comment and stripped.startswith("*"):
            continue
        code = ""
        quoted = False
        pos = 0
        while pos < len(line):
            if block_comment:
                end = line.find("*/", pos)
                if end < 0:
                    break
                block_comment = False
                pos = end + 2
            elif not quoted and line.startswith("/*", pos):
                block_comment = True
                pos += 2
            elif not quoted and line.startswith("//", pos):
                if line.startswith("///", pos):
                    code += " ///"
                break
            else:
                char = line[pos]
                if char == '"':
                    quoted = not quoted
                code += char
                pos += 1
        code = code.strip()
        if not code:
            continue
        if not pending:
            start = index
        continued = code.endswith(" ///")
        pending.append(code[:-4].rstrip() if continued else code)
        if not continued:
            result.append((start, index + 1, " ".join(pending)))
            pending = []
    if block_comment or pending:
        raise ValueError("Unfinished comment or continued command; profile was not changed.")
    return result


def check_local(repo: Path) -> None:
    local_file = repo / "scripts/stata/config/bnr_paths_LOCAL.do"
    if not local_file.is_file():
        raise ValueError("bnr_paths_LOCAL.do is missing. Complete workstation setup Stage 4.")
    text, _ = read_text(local_file)
    active = [command for _, _, command in commands(text)]
    roots = [command for command in active if re.match(r"global\s+BNR_REPO\s", command)]
    python_paths = [command for command in active if re.match(r"global\s+BNR_PYTHON_EXE\s", command)]
    if len(roots) != 1:
        raise ValueError("Expected one BNR_REPO definition in LOCAL.do; check Stage 4.")
    match = re.fullmatch(r'global\s+BNR_REPO\s+"([^"\r\n]+)"', roots[0])
    if not match or Path(match.group(1).replace("\\", "/")).resolve() != repo.resolve():
        raise ValueError("BNR_REPO in LOCAL.do must identify this repository. Check Stage 4.")
    if len(python_paths) != 1 or re.sub(r"\s+", " ", python_paths[0]) != LOCAL_GLOBAL:
        raise ValueError(
            "Add this single line under Derived public-repository folders in LOCAL.do "
            "(replace any existing BNR_PYTHON_EXE definition):\n" + LOCAL_GLOBAL
        )


def update_profile(text: str, repo: Path) -> str:
    """Prepare the new text completely before any file is changed."""
    newline = "\r\n" if "\r\n" in text else "\n"
    if text.count(BEGIN) != text.count(END) or text.count(BEGIN) > 1:
        raise ValueError("Ambiguous managed Python block; profile was not changed.")
    if BEGIN in text:
        pattern = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END) + r"(?:\r?\n|$)", re.S)
        text, count = pattern.subn(lambda _: PYTHON_COMMAND + newline, text)
        if count != 1:
            raise ValueError("Incomplete managed Python block; profile was not changed.")
    lines = text.splitlines(keepends=True)
    active = commands(text)
    for _, _, command in active:
        if command.startswith("#delimit") or command.endswith("{") or command == "}":
            raise ValueError("Profile uses delimiters or conditional blocks. Review manually; nothing was changed.")
    loads = [item for item in active if "bnr_paths_LOCAL.do" in item[2]]
    python_exec = [item for item in active if re.search(r"\bpython\s+set\s+exec\b", item[2])]
    if len(loads) > 1 or len(python_exec) > 1:
        raise ValueError("Multiple BNR loads or Python settings; profile was not changed.")
    for _, _, command in active:
        python_call = re.sub(r"^(?:(?:capture|noisily|quietly)\s+)+", "", command)
        if re.match(r"python\b", python_call) and not re.match(r"python\s+(?:query\b|set\s+exec\b)", python_call):
            raise ValueError("Profile already runs embedded Python. Review startup order manually; nothing was changed.")
    repo_path = repo.resolve().as_posix()
    if any(char in repo_path for char in ('"', '$', '`', '\n', '\r')):
        raise ValueError("Repository path contains characters that need manual Stata quoting.")
    load_line = f'do "{repo_path}/scripts/stata/config/bnr_paths_LOCAL.do"'
    if loads:
        if not re.fullmatch(r'do\s+"[^"\r\n]*bnr_paths_LOCAL\.do"', loads[0][2]):
            raise ValueError("BNR load is not a simple do command; profile was not changed.")
        if python_exec and python_exec[0][0] < loads[0][1]:
            raise ValueError("Python setting precedes BNR configuration; profile was not changed.")
    if python_exec and not re.fullmatch(r'python\s+set\s+exec\s+"[^"\r\n]+"(?:\s*,\s*permanently)?', python_exec[0][2]):
        raise ValueError("Python setting is not a simple command; profile was not changed.")
    if not loads and python_exec:
        raise ValueError("Existing Python setting has no BNR configuration load; review this profile manually.")

    block = newline.join([
        BEGIN,
        '* BNR uses its own venv. SHG continues to use its external interpreter.',
        'capture confirm file "$BNR_PYTHON_EXE"',
        'if _rc {',
        '    display as error "BNR Python venv not found: $BNR_PYTHON_EXE"',
        '    display as error "Run setup-bnr-python.bat from the BNR repository root."',
        '    exit 601',
        '}',
        PYTHON_COMMAND,
        'noisily python query',
        END,
        '',
    ])
    edits = []
    if loads:
        edits.append((loads[0][0], loads[0][1], load_line + newline))
    else:
        lines.append(newline + '* Load BNR workstation configuration' + newline + load_line + newline)
    menu_exists = any(re.fullmatch(r'do\s+"\$BNR_STATA/menu/bnr_menu\.do"', command.replace('\\', '/')) for _, _, command in active)
    menu = '' if menu_exists else '* Build the BNR menu' + newline + 'do "$BNR_STATA/menu/bnr_menu.do"' + newline
    if python_exec:
        start, stop, _ = python_exec[0]
        # The managed block already prints query. Consume only an immediately
        # adjacent standard query; leave all unrelated commands/comments intact.
        query = next((item for item in active if item[0] == stop), None)
        if query and query[2] in ('python query', 'noisily python query'):
            stop = query[1]
        edits.append((start, stop, menu + block))
    else:
        lines.append(newline + menu + block)
    for start, end, replacement in sorted(edits, reverse=True):
        lines[start:end] = [replacement]
    return ''.join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, required=True)
    parser.add_argument('--profile', type=Path)
    parser.add_argument('--check-local', action='store_true')
    args = parser.parse_args()
    try:
        repo = args.repo.resolve()
        check_local(repo)
        if args.check_local:
            print('BNR LOCAL configuration checked; file was not changed.')
            return 0
        if not args.profile or args.profile.name.lower() != 'profile.do':
            raise ValueError('Select the file named profile.do from Stata PERSONAL (use sysdir).')
        profile = args.profile.resolve()
        if profile.is_relative_to(repo):
            raise ValueError('The personal profile must be outside the public repository.')
        if not profile.parent.is_dir():
            raise ValueError('Profile directory does not exist. Select the Stata PERSONAL directory.')
        existing = profile.is_file()
        text, encoding = read_text(profile) if existing else ('', 'utf-8')
        updated = update_profile(text, repo)
        if updated == text:
            print(f'BNR startup already configured: {profile}')
            return 0
        backup = None
        if existing:
            stamp = datetime.now().strftime('%Y%m%d_%H%M%S_%f')
            backup = profile.with_name(f'profile.bnr_backup_{stamp}.bak')
            shutil.copy2(profile, backup)
        # Atomic replacement: a failed write leaves the original profile in place.
        descriptor, temporary = tempfile.mkstemp(prefix='.bnr-profile-', dir=profile.parent)
        try:
            with os.fdopen(descriptor, 'wb') as stream:
                if encoding == 'utf-16-be':
                    stream.write(b'\xfe\xff')
                stream.write(updated.encode(encoding))
            os.replace(temporary, profile)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
        print(f'BNR startup configured: {profile}')
        if backup:
            print(f'Original profile backup: {backup}')
        print('SHG and other existing startup entries were retained. LOCAL.do was not changed.')
        return 0
    except (OSError, UnicodeError, ValueError) as exc:
        print(f'BNR profile setup stopped: {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
