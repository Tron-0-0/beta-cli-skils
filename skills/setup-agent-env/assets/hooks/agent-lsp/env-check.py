#!/usr/bin/env python3
"""SessionStart: проверяет, что agent-lsp и его языковые серверы на месте,
версия Lombok в аргументах jdtls совпадает с проектом, плагин jdtls-lsp не вернулся.
Молчит, если всё в порядке. Попутно чистит очереди проверок старше 7 дней."""
import json, os, re, sys, time, shutil
import xml.etree.ElementTree as ET

home = os.path.expanduser("~")
inp = json.load(sys.stdin)
project = os.environ.get("CLAUDE_PROJECT_DIR") or inp.get("cwd", "")
problems = []

# Очистка старых очередей.
root = os.path.join(home, ".claude/state/agent-lsp-pending")
if os.path.isdir(root):
    for name in os.listdir(root):
        p = os.path.join(root, name)
        if time.time() - os.path.getmtime(p) > 7 * 86400:
            shutil.rmtree(p, ignore_errors=True)

# Конфигурация agent-lsp.
try:
    cfg = json.load(open(os.path.join(home, ".claude.json")))["mcpServers"]["agent-lsp"]
except Exception:
    cfg = None
    problems.append("agent-lsp не найден в mcpServers ~/.claude.json")

lombok_arg = None
if cfg:
    if not os.access(cfg.get("command", ""), os.X_OK):
        problems.append(f"нет исполняемого файла agent-lsp: {cfg.get('command')}")
    for arg in cfg.get("args", []):
        lang, _, rest = arg.partition(":")
        parts = rest.split(",")
        if not os.access(parts[0], os.X_OK):
            problems.append(f"{lang}: нет языкового сервера {parts[0]}")
        for p in parts[1:]:
            m = re.search(r"-javaagent:(\S+\.jar)", p)
            if m:
                lombok_arg = m.group(1)
                if not os.path.isfile(lombok_arg):
                    problems.append(f"java: нет jar агента Lombok {lombok_arg}")

# Версия Lombok проекта: явная в pom.xml или из BOM spring-boot-dependencies в ~/.m2.
def project_lombok():
    pom = os.path.join(project, "pom.xml")
    if not os.path.isfile(pom):
        return None
    ns = {"m": "http://maven.apache.org/POM/4.0.0"}
    t = ET.parse(pom).getroot()
    if "lombok" not in open(pom).read():
        return None
    v = t.find("m:properties/m:lombok.version", ns)
    if v is not None:
        return v.text.strip()
    for dep in t.iterfind(".//m:dependency", ns):
        if dep.findtext("m:artifactId", "", ns) == "lombok" and dep.findtext("m:version", None, ns):
            return dep.findtext("m:version", "", ns).strip()
    par = t.find("m:parent", ns)
    if par is not None and par.findtext("m:groupId", "", ns) == "org.springframework.boot":
        ver = par.findtext("m:version", "", ns).strip()
        bom = os.path.join(home, ".m2/repository/org/springframework/boot/spring-boot-dependencies",
                           ver, f"spring-boot-dependencies-{ver}.pom")
        if os.path.isfile(bom):
            m = re.search(r"<lombok\.version>([^<]+)</lombok\.version>", open(bom).read())
            if m:
                return m.group(1).strip()
    return None

try:
    want = project_lombok()
except Exception:
    want = None
if want and lombok_arg:
    m = re.search(r"lombok-([^/]+)\.jar$", lombok_arg)
    if m and m.group(1) != want:
        problems.append(f"java: в agent-lsp Lombok {m.group(1)}, а проект использует {want} — "
                        f"поправь путь -javaagent в ~/.claude.json (возможны ложные ошибки LSP)")

# Плагин jdtls-lsp портит target/classes заглушками без Lombok.
try:
    plugins = json.load(open(os.path.join(home, ".claude/plugins/installed_plugins.json"))).get("plugins", {})
    for pid in plugins:
        if pid.split("@")[0] == "jdtls-lsp":
            problems.append(f"установлен плагин {pid}: он перезаписывает target/classes без Lombok — удали его")
except Exception:
    pass

if problems:
    text = "agent-lsp: проблемы окружения:\n" + "\n".join("- " + p for p in problems)
    print(json.dumps({"systemMessage": text,
                      "hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": text}},
                     ensure_ascii=False))
