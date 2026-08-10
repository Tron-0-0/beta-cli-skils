#!/usr/bin/env python3
"""
collect_changes.py — Сборщик списка изменённых файлов для Шага 5.

Запускается после успешной компиляции, показывает какие файлы изменены.
Не стейджирует, не показывает diff — только список файлов.

Использование:
    python scripts/collect_changes.py

Выход:
    stdout — список изменённых/новых файлов
    exit code: 0 всегда
"""

import subprocess
import sys


def run_git_status() -> str:
    """Запускает git status --short."""
    result = subprocess.run(
        ["git", "status", "--short"],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    return result.stdout.strip()


def format_output(git_status_output: str) -> str:
    """Форматирует вывод — только список файлов."""
    parts: list[str] = []

    parts.append("=" * 70)
    parts.append("ИЗМЕНЕНИЯ")
    parts.append("=" * 70)
    parts.append("")

    if not git_status_output:
        parts.append("Нет изменённых файлов.")
        return "\n".join(parts)

    status_lines = git_status_output.splitlines()
    modified: list[str] = []
    new_files: list[str] = []
    deleted: list[str] = []

    for line in status_lines:
        line = line.strip()
        if not line or "?? " in line:
            continue

        code = line[:2].strip()
        path = line[3:]

        if "A" in code:
            new_files.append(path)
        elif "D" in code:
            deleted.append(path)
        else:
            modified.append(path)

    parts.append(f"Всего: {len(modified) + len(new_files)}")
    if modified:
        parts.append(f"  M {len(modified)}")
    if new_files:
        parts.append(f"  A {len(new_files)}")
    if deleted:
        parts.append(f"  D {len(deleted)}")
    parts.append("")

    for f in modified:
        parts.append(f"  M {f}")
    for f in new_files:
        parts.append(f"  A {f}")
    for f in deleted:
        parts.append(f"  D {f}")

    parts.append("")
    parts.append("=" * 70)
    return "\n".join(parts)


def main():
    git_status_output = run_git_status()
    output = format_output(git_status_output)
    try:
        print(output)
    except UnicodeEncodeError:
        print(output.encode("cp1251", errors="replace").decode("cp1251"))
    sys.exit(0)


if __name__ == "__main__":
    main()
