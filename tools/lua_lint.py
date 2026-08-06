#!/usr/bin/env python3
"""Простая проверка Lua без внешних зависимостей: баланс блоков и скобок."""

from __future__ import annotations

import pathlib
import re
import sys

OPENERS = ("function", "if", "do", "repeat")
CLOSERS = ("end", "until")
WORD = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
LONG_OPEN = re.compile(r"\[(=*)\[")


def strip_noise(text):
    """Убирает комментарии и строковые литералы, сохраняя номера строк."""
    out = []
    i = 0
    size = len(text)
    while i < size:
        ch = text[i]

        # комментарий: обычный или длинный
        if ch == "-" and text.startswith("--", i):
            match = LONG_OPEN.match(text, i + 2)
            if match:
                closer = "]" + match.group(1) + "]"
                end = text.find(closer, match.end())
                stop = size if end == -1 else end + len(closer)
                out.append("\n" * text.count("\n", i, stop))
                i = stop
                continue
            end = text.find("\n", i)
            i = size if end == -1 else end
            continue

        # длинная строка [[ ... ]]
        match = LONG_OPEN.match(text, i)
        if match:
            closer = "]" + match.group(1) + "]"
            end = text.find(closer, match.end())
            stop = size if end == -1 else end + len(closer)
            out.append("\n" * text.count("\n", i, stop))
            i = stop
            continue

        # обычная строка
        if ch == "'" or ch == '"':
            i += 1
            while i < size:
                if text[i] == "\\":
                    i += 2
                    continue
                if text[i] == "\n":
                    break
                if text[i] == ch:
                    i += 1
                    break
                i += 1
            continue

        out.append(ch)
        i += 1

    return "".join(out)


def check(text):
    """Возвращает список сообщений об ошибках; пустой список — всё хорошо."""
    problems = []
    stack = []
    round_depth = 0
    curly_depth = 0

    for number, line in enumerate(strip_noise(text).splitlines(), 1):
        for word in WORD.findall(line):
            if word in OPENERS:
                stack.append((number, word))
            elif word in CLOSERS:
                if not stack:
                    problems.append("строка %d: лишний %s" % (number, word))
                    continue
                open_line, open_word = stack.pop()
                if word == "until" and open_word != "repeat":
                    problems.append(
                        "строка %d: until закрывает %s со строки %d" % (number, open_word, open_line)
                    )
                elif word == "end" and open_word == "repeat":
                    problems.append(
                        "строка %d: repeat со строки %d надо закрывать через until" % (number, open_line)
                    )

        round_depth += line.count("(") - line.count(")")
        curly_depth += line.count("{") - line.count("}")
        if round_depth < 0:
            problems.append("строка %d: лишняя закрывающая круглая скобка" % number)
            round_depth = 0
        if curly_depth < 0:
            problems.append("строка %d: лишняя закрывающая фигурная скобка" % number)
            curly_depth = 0

    for open_line, open_word in stack:
        problems.append("строка %d: блок %s не закрыт" % (open_line, open_word))
    if round_depth > 0:
        problems.append("не закрыто круглых скобок: %d" % round_depth)
    if curly_depth > 0:
        problems.append("не закрыто фигурных скобок: %d" % curly_depth)
    return problems


def main(argv):
    paths = argv[1:]
    if not paths:
        print("использование: lua_lint.py файл.lua [ещё.lua]", file=sys.stderr)
        return 2

    failed = False
    for name in paths:
        path = pathlib.Path(name)
        if not path.exists():
            print("FAIL %s: файла нет" % name)
            failed = True
            continue
        problems = check(path.read_text(encoding="utf-8"))
        if problems:
            failed = True
            for message in problems:
                print("FAIL %s: %s" % (name, message))
        else:
            print("OK   %s" % name)

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
