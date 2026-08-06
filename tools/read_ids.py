#!/usr/bin/env python3
"""Читает place.json и печатает значения для шагов GitHub Actions."""

from __future__ import annotations

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CONFIG = ROOT / "place.json"


def read_number(data, key):
    try:
        return int(data.get(key) or 0)
    except (TypeError, ValueError):
        return 0


def main():
    universe = 0
    place = 0
    version_type = "Published"

    if not CONFIG.exists():
        print("Нет файла place.json — публикация будет пропущена", file=sys.stderr)
    else:
        try:
            data = json.loads(CONFIG.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            print("place.json сломан: %s" % error, file=sys.stderr)
            data = {}
        universe = read_number(data, "universeId")
        place = read_number(data, "placeId")
        wanted = str(data.get("versionType") or "Published")
        if wanted in ("Published", "Saved"):
            version_type = wanted

    if universe <= 0 or place <= 0:
        print("В place.json нет корректных id — публикация будет пропущена", file=sys.stderr)

    print("universe=%d" % universe)
    print("place=%d" % place)
    print("version_type=%s" % version_type)
    return 0


if __name__ == "__main__":
    sys.exit(main())
