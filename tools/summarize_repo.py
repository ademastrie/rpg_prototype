"""Create lightweight repo summaries for Codex/context prompts.

Run locally from the repository root:
    python tools/summarize_repo.py

This script performs static text parsing only. It does not import project code,
launch Godot, connect to the backend, or run tests.
"""
from __future__ import annotations

from pathlib import Path
import re
from typing import Iterable

ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "docs" / "context"

GD_PATTERNS = {
    "class_name": re.compile(r"^class_name\s+(\w+)", re.MULTILINE),
    "extends": re.compile(r"^extends\s+([^\n]+)", re.MULTILINE),
    "signals": re.compile(r"^signal\s+([^\n]+)", re.MULTILINE),
    "exports": re.compile(r"^@export(?:\([^\n]*\))?\s+var\s+([^\n]+)", re.MULTILINE),
    "functions": re.compile(r"^(?:@rpc\([^\n]+\)\s*)?func\s+([^\n]+)", re.MULTILINE),
    "rpcs": re.compile(r"^@rpc\(([^\n]+)\)\s*\nfunc\s+([^\n]+)", re.MULTILINE),
}

PY_PATTERNS = {
    "classes": re.compile(r"^class\s+([^:\n(]+)(?:\([^\n]*\))?:", re.MULTILINE),
    "functions": re.compile(r"^(?:async\s+)?def\s+([^\n]+)", re.MULTILINE),
    "routers": re.compile(r"^@router\.(get|post|put|patch|delete)\(([^\n]+)\)", re.MULTILINE),
}

SKIP_PARTS = {".git", ".godot", ".import", ".venv", "__pycache__"}


def iter_files(pattern: str) -> Iterable[Path]:
    for path in sorted(ROOT.glob(pattern)):
        if any(part in SKIP_PARTS for part in path.parts):
            continue
        if path.is_file():
            yield path


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def bullet_list(values: list[str], fallback: str = "None found") -> str:
    if not values:
        return f"- {fallback}\n"
    return "".join(f"- `{value.strip()}`\n" for value in values)


def summarize_godot() -> str:
    chunks = ["# Generated Godot Symbol Summary\n\n"]
    for path in iter_files("godot/scripts/**/*.gd"):
        text = read(path)
        chunks.append(f"## `{rel(path)}`\n\n")
        for label, pattern in GD_PATTERNS.items():
            matches = []
            for match in pattern.finditer(text):
                if label == "rpcs":
                    matches.append(f"@rpc({match.group(1).strip()}) func {match.group(2).strip()}")
                else:
                    matches.append(match.group(1).strip())
            chunks.append(f"### {label.replace('_', ' ').title()}\n")
            chunks.append(bullet_list(matches))
            chunks.append("\n")
    return "".join(chunks)


def summarize_backend() -> str:
    chunks = ["# Generated Backend Symbol Summary\n\n"]
    for path in iter_files("backend/app/**/*.py"):
        text = read(path)
        chunks.append(f"## `{rel(path)}`\n\n")
        for label, pattern in PY_PATTERNS.items():
            matches = []
            for match in pattern.finditer(text):
                if label == "routers":
                    matches.append(f"{match.group(1).upper()} {match.group(2).strip()}")
                else:
                    matches.append(match.group(1).strip())
            chunks.append(f"### {label.title()}\n")
            chunks.append(bullet_list(matches))
            chunks.append("\n")
    return "".join(chunks)


def write_output(name: str, content: str) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUTPUT_DIR / name).write_text(content, encoding="utf-8")


def main() -> None:
    write_output("generated_godot_symbols.md", summarize_godot())
    write_output("generated_backend_symbols.md", summarize_backend())
    print("Wrote docs/context/generated_godot_symbols.md")
    print("Wrote docs/context/generated_backend_symbols.md")


if __name__ == "__main__":
    main()
