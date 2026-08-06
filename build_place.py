#!/usr/bin/env python3
"""Собирает place.rbxlx из Lua-исходников. Только стандартная библиотека."""

from __future__ import annotations

import pathlib
import sys
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent
SRC = ROOT / "src"
TOOLS = ROOT / "tools"
OUT = ROOT / "place.rbxlx"

# Адреса собраны из частей, чтобы никакой редактор их не переписал.
XMIME = "http:" + "//www.w3.org/2005/05/xmlmime"
XSI = "http:" + "//www.w3.org/2001/XMLSchema-instance"
XSD = "http:" + "//www.roblox.com/roblox.xsd"

HEADER = (
    '<roblox xmlns:xmime="%s" xmlns:xsi="%s" xsi:noNamespaceSchemaLocation="%s" version="4">\n'
    '\t<Meta name="ExplicitAutoJoints">true</Meta>\n'
    "\t<External>null</External>\n"
    "\t<External>nil</External>\n"
) % (XMIME, XSI, XSD)

FOOTER = "</roblox>\n"

_counter = [0]


def new_ref():
    _counter[0] += 1
    return "RBX%d" % _counter[0]


def esc(text):
    """Экранирует текст для XML.

    CDATA не используем нарочно: Lua любит последовательность ]] и это опасно.
    """
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def read_source(file_name):
    path = SRC / file_name
    if not path.exists():
        raise SystemExit("Нет исходника: %s" % path)
    text = path.read_text(encoding="utf-8")
    if not text.strip():
        raise SystemExit("Пустой исходник: %s" % path)
    return text


def script_item(class_name, name, source, indent="\t"):
    pad = indent + "\t"
    lines = [
        '%s<Item class="%s" referent="%s">' % (indent, class_name, new_ref()),
        "%s<Properties>" % pad,
        '%s\t<string name="Name">%s</string>' % (pad, esc(name)),
        '%s\t<ProtectedString name="Source">%s</ProtectedString>' % (pad, esc(source)),
        '%s\t<bool name="Disabled">false</bool>' % pad,
        "%s</Properties>" % pad,
        "%s</Item>" % indent,
    ]
    return "\n".join(lines)


def container_item(class_name, name, children, indent="\t"):
    pad = indent + "\t"
    lines = [
        '%s<Item class="%s" referent="%s">' % (indent, class_name, new_ref()),
        "%s<Properties>" % pad,
        '%s\t<string name="Name">%s</string>' % (pad, esc(name)),
        "%s</Properties>" % pad,
    ]
    lines.extend(children)
    lines.append("%s</Item>" % indent)
    return "\n".join(lines)


def lint_sources(sources):
    sys.path.insert(0, str(TOOLS))
    try:
        import lua_lint
    except ImportError:
        print("  lint: проверялка не найдена, пропускаю")
        return
    problems = []
    for name, text in sources.items():
        for message in lua_lint.check(text):
            problems.append("%s: %s" % (name, message))
    if problems:
        for message in problems:
            print("  lint FAIL %s" % message)
        raise SystemExit("Луа-проверка не прошла, публикация отменена")
    print("  lint: Lua без замечаний")


def build():
    sources = {
        "Config.lua": read_source("Config.lua"),
        "GameServer.server.lua": read_source("GameServer.server.lua"),
        "GameClient.client.lua": read_source("GameClient.client.lua"),
    }
    lint_sources(sources)

    parts = [HEADER]

    parts.append(container_item("Workspace", "Workspace", []))

    parts.append(
        container_item(
            "ReplicatedStorage",
            "ReplicatedStorage",
            [script_item("ModuleScript", "Config", sources["Config.lua"], indent="\t\t")],
        )
    )

    parts.append(
        container_item(
            "ServerScriptService",
            "ServerScriptService",
            [script_item("Script", "GameServer", sources["GameServer.server.lua"], indent="\t\t")],
        )
    )

    starter_scripts = container_item(
        "StarterPlayerScripts",
        "StarterPlayerScripts",
        [script_item("LocalScript", "GameClient", sources["GameClient.client.lua"], indent="\t\t\t")],
        indent="\t\t",
    )
    parts.append(container_item("StarterPlayer", "StarterPlayer", [starter_scripts]))

    parts.append(FOOTER)
    return "\n".join(parts[:-1]) + "\n" + parts[-1]


def main():
    print("Сборка плейса...")
    xml_text = build()

    root = ET.fromstring(xml_text)
    items = root.findall(".//Item")
    scripts = root.findall(".//ProtectedString[@name='Source']")
    if len(scripts) != 3:
        raise SystemExit("Ожидалось 3 скрипта, найдено %d" % len(scripts))
    for node in scripts:
        if not (node.text or "").strip():
            raise SystemExit("Пустой Source в собранном плейсе")

    OUT.write_text(xml_text, encoding="utf-8")
    print("  элементов: %d, скриптов: %d" % (len(items), len(scripts)))
    print("  готово: %s (%d байт)" % (OUT.name, OUT.stat().st_size))


if __name__ == "__main__":
    main()
