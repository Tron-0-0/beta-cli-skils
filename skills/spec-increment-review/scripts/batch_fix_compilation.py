#!/usr/bin/env python3
"""
batch_fix_compilation.py — Сборщик ошибок компиляции Maven.

Запускает mvn compile, парсит stdout/stderr, выдаёт структурированный
отчёт с ошибками и предупреждениями. Не исправляет код — только собирает
информацию для ручного исправления.

Использование:
    python scripts/batch_fix_compilation.py

Выход:
    stdout — отформатированный отчёт (для чтения LLM)
    exit code: 0 — чисто, 1 — есть ошибки
"""

import re
import subprocess
import sys
from dataclasses import dataclass, field
from typing import Literal


@dataclass
class CompilationIssue:
    """Один инцидент: ошибка или предупреждение."""
    file: str          # относительный путь к файлу (src/main/... или src/test/...)
    line: int          # строка (0 если неизвестно)
    col: int           # колонка (0 если неизвестно)
    severity: Literal["ERROR", "WARNING"]
    message: str       # текст сообщения компилятора


@dataclass
class CompilationReport:
    """Полный отчёт о компиляции."""
    errors: list[CompilationIssue] = field(default_factory=list)
    warnings: list[CompilationIssue] = field(default_factory=list)
    raw_output: str = ""
    mvn_exit_code: int = -1

    @property
    def has_issues(self) -> bool:
        return bool(self.errors or self.warnings)


# ===========================================================================
# Парсеры
# ===========================================================================

# Maven javac errors (support Windows absolute paths like /C:/Work/...):
#   [ERROR] /C:/Work/.../File.java:[45,10] error: cannot find symbol
ERROR_PATTERN = re.compile(
    r"\[ERROR\]\s+"
    r"(?:(?P<file>(?:/[A-Z]:[^\s:]+\.java)|(?P<rel>[^\s/][^\s:]*\.java)))"
    r":\[(?P<line>\d+)(?:,(?P<col>\d+))?\]\s+"
    r"(?:error:)?\s*"
    r"(?P<message>.+)$"
)

# Multi-line continuation: "  symbol:   class Foo" или "  location: ..."
CONTINUATION_PATTERN = re.compile(
    r"^(\s{2,})(symbol|location|required|found|class|package|override|mismatch)\s*:\s*(.+)$"
)

# Maven javac warnings:
#   [WARNING] /path/to/File.java:[50,15] unchecked cast
WARNING_PATTERN = re.compile(
    r"\[WARNING\]\s+"
    r"(?:(?P<file>(?:/[^\s:]+\.java)|(?P<rel>[^\s/][^\s:]*\.java)))"
    r":\[(?P<line>\d+)(?:,(?P<col>\d+))?\]\s*"
    r"(?:warning:)?\s*"
    r"(?P<message>.+)$"
)

# Maven BUILD FAILURE / SUCCESS
BUILD_PATTERN = re.compile(r"BUILD (FAILURE|SUCCESS|ERROR)")


# Maven checkstyle / plugin errors:
#   [ERROR] Failed to execute goal org.apache.maven.plugins:maven-checkstyle-plugin:3.6.0:check
CHECKSTYLE_ERROR_PATTERN = re.compile(
    r"\[ERROR\]\s+Failed to execute goal\s+(?P<goal>[^:]+):[^:]+:(?P<phase>\w+)"
)

# Checkstyle file-level error (single line, full path with .java):
#   ...processing C:\Work\...\File.java: IllegalStateException ... 20:16: mismatched input
CHECKSTYLE_FILE_ERROR_PATTERN = re.compile(r'(.+\.java).*?(\d+):(\d+):\s+(.+)')

# Continue lines in checkstyle output
CHECKSTYLE_CONTINUATION = re.compile(r'^\s+\[ERROR\]\s+(.+)$')


def _extract_last_java_file(path: str) -> str:
    """Извлекает только имя файла и путь до последнего .java в строке."""
    idx = path.rfind('.java')
    if idx > 0:
        start = path.rfind(' ', 0, idx)
        if start >= 0:
            return path[start + 1:idx + 5]
    return path


def _normalize_file_path(raw: str) -> str:
    """Убирает лишние пути, оставляет src/..."""
    cleaned = raw.strip().lstrip("/")
    for prefix in ("src/main/java/", "src/test/java/", "src/main/resources/",
                   "src/test/resources/"):
        idx = cleaned.find(prefix)
        if idx >= 0:
            return cleaned[idx:]
    for sep in ("/", "\\"):
        idx = cleaned.rfind(sep)
        if idx > 0:
            return cleaned[idx + 1:]
    return cleaned


def parse_issues(raw_output: str) -> CompilationReport:
    """Парсит сырой вывод mvn compile."""
    report = CompilationReport(raw_output=raw_output)
    lines = raw_output.splitlines()

    current_issue: CompilationIssue | None = None
    in_checkstyle_block = False

    for line in lines:
        # --- Java compiler errors (javac format) ---
        m = ERROR_PATTERN.match(line)
        if m:
            if current_issue and current_issue.severity == "ERROR":
                report.errors.append(current_issue)
            in_checkstyle_block = False

            current_issue = CompilationIssue(
                file=_normalize_file_path(m.group("file") or m.group("rel") or ""),
                line=int(m.group("line")),
                col=int(m.group("col") or 0),
                severity="ERROR",
                message=m.group("message").strip(),
            )
            continue

        # --- Продолжение многострочного описания ошибки (javac) ---
        if current_issue and current_issue.severity == "ERROR":
            cont = CONTINUATION_PATTERN.match(line)
            if cont:
                current_issue.message += f"\n  [sup] {cont.group(3).strip()}"
                continue

        # --- Checkstyle / plugin errors ---
        cs_error_match = CHECKSTYLE_ERROR_PATTERN.match(line)
        if cs_error_match:
            if current_issue and current_issue.severity == "ERROR":
                report.errors.append(current_issue)
            in_checkstyle_block = True
            # В той же строке ищем .java + line:col
            cs_file_match = CHECKSTYLE_FILE_ERROR_PATTERN.search(line)
            if cs_file_match:
                raw_path = _extract_last_java_file(cs_file_match.group(1))
                current_issue = CompilationIssue(
                    file=_normalize_file_path(raw_path),
                    line=int(cs_file_match.group(2)),
                    col=int(cs_file_match.group(3) or 0),
                    severity="ERROR",
                    message=cs_file_match.group(4).replace(" -> [Help 1]", "").strip(),
                )
            else:
                current_issue = CompilationIssue(
                    file="",
                    line=0,
                    col=0,
                    severity="ERROR",
                    message=cs_error_match.group(0).strip()[:200],
                )
            continue

        # --- Checkstyle file-level error ---
        cs_match = CHECKSTYLE_FILE_ERROR_PATTERN.search(line)
        if cs_match and in_checkstyle_block:
            raw_path = _extract_last_java_file(cs_match.group(1))
            if current_issue and current_issue.severity == "ERROR":
                report.errors.append(current_issue)
            current_issue = CompilationIssue(
                file=_normalize_file_path(raw_path),
                line=int(cs_match.group(2)),
                col=int(cs_match.group(3) or 0),
                severity="ERROR",
                message=cs_match.group(4).strip(),
            )
            continue

        # --- Checkstyle continuation ---
        if in_checkstyle_block and CHECKSTYLE_CONTINUATION.match(line):
            msg = CHECKSTYLE_CONTINUATION.match(line).group(1).strip()
            if current_issue:
                current_issue.message += f"\n  [sup] {msg}"
            continue

        # --- Предупреждения ---
        m = WARNING_PATTERN.match(line)
        if m:
            if current_issue and current_issue.severity == "WARNING":
                report.warnings.append(current_issue)
            current_issue = CompilationIssue(
                file=_normalize_file_path(m.group("file") or m.group("rel") or ""),
                line=int(m.group("line")),
                col=int(m.group("col") or 0),
                severity="WARNING",
                message=m.group("message").strip(),
            )
            continue

    # Сохраняем последний накопленный issue
    if current_issue:
        if current_issue.severity == "ERROR":
            report.errors.append(current_issue)
        elif current_issue.severity == "WARNING":
            report.warnings.append(current_issue)

    return report


# ===========================================================================
# Форматирование отчёта
# ===========================================================================

def format_report(report: CompilationReport) -> str:
    """Форматирует отчёт для чтения человеком/LLM."""
    parts: list[str] = []

    parts.append("=" * 70)
    parts.append("КОМПИЛЯЦИЯ: full-project  exit_code=" + str(report.mvn_exit_code))
    parts.append("=" * 70)
    parts.append("")

    parts.append(f"SUM: {len(report.errors)} errors, "
                 f"{len(report.warnings)} warnings")
    parts.append("")

    if not report.has_issues and report.mvn_exit_code == 0:
        parts.append("[OK] Compilation successful")
        return "\n".join(parts)

    # Group errors by file
    if report.errors:
        by_file: dict[str, list[CompilationIssue]] = {}
        for err in report.errors:
            by_file.setdefault(err.file, []).append(err)

        parts.append("-" * 70)
        parts.append("ERRORS")
        parts.append("-" * 70)
        parts.append("")

        for filepath, issues in sorted(by_file.items()):
            parts.append(f"FILE: {filepath}")
            for issue in issues:
                loc = f":{issue.line}" if issue.line else ""
                parts.append(f"  line {loc}: [{issue.severity}] {issue.message}")
            parts.append("")

    if report.warnings:
        by_file: dict[str, list[CompilationIssue]] = {}
        for warn in report.warnings:
            by_file.setdefault(warn.file, []).append(warn)

        parts.append("-" * 70)
        parts.append("WARNINGS")
        parts.append("-" * 70)
        parts.append("")

        for filepath, issues in sorted(by_file.items()):
            parts.append(f"FILE: {filepath}")
            for issue in issues:
                loc = f":{issue.line}" if issue.line else ""
                parts.append(f"  line {loc}: {issue.message}")
            parts.append("")

    # Raw tail — последние 10 строк сырого вывода (если есть BUILD FAILURE)
    if report.mvn_exit_code != 0:
        raw_lines = report.raw_output.rstrip().splitlines()
        tail = raw_lines[-10:] if len(raw_lines) > 10 else raw_lines
        parts.append("-" * 70)
        parts.append("LAST OUTPUT LINES:")
        parts.append("-" * 70)
        for rl in tail:
            parts.append(f"  {rl}")
        parts.append("")

    parts.append("=" * 70)
    return "\n".join(parts)


# ===========================================================================
# Main
# ===========================================================================

def run_compilation() -> CompilationReport:
    """Запускает mvn compile -am на весь проект."""
    cmd_str = "mvn compile -am"
    result = subprocess.run(
        cmd_str, capture_output=True, text=True, encoding="utf-8", errors="replace",
        shell=True,
    )

    raw = result.stdout + result.stderr

    # На Windows mvn.cmd часто возвращает exit code -1
    # Определяем статус из BUILD SUCCESS/FAILURE
    bm = BUILD_PATTERN.search(raw)
    if bm:
        status = bm.group(1)
        if status in ("FAILURE", "ERROR"):
            report = CompilationReport(mvn_exit_code=1)
        else:
            report = CompilationReport(mvn_exit_code=0)
        return parse_issues(raw)

    # Fallback
    report = CompilationReport(mvn_exit_code=result.returncode)
    return parse_issues(raw)


def main():
    report = run_compilation()
    output = format_report(report)
    print(output)
    sys.exit(1 if report.errors else 0)


if __name__ == "__main__":
    main()
