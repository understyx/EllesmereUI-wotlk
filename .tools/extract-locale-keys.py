#!/usr/bin/env python3
"""Extract statically-known EllesmereUI.L/Lf string keys from Lua source."""

from __future__ import annotations

from pathlib import Path
import os
import re


ROOT = Path(__file__).resolve().parent.parent
EXCLUDED_DIRS = {".git", "Libs", "libs", "Locales"}
EXCLUDED_FILES = {"EllesmereUI_LocaleDev.lua"}


def skip_long_bracket(source: str, start: int) -> int | None:
    match = re.match(r"\[(=*)\[", source[start:])
    if not match:
        return None
    close = "]" + match.group(1) + "]"
    end = source.find(close, start + match.end())
    return len(source) if end < 0 else end + len(close)


def parse_long_string(source: str, start: int) -> tuple[str | None, int]:
    match = re.match(r"\[(=*)\[", source[start:])
    if not match:
        return None, start
    content_start = start + match.end()
    close = "]" + match.group(1) + "]"
    end = source.find(close, content_start)
    if end < 0:
        return None, len(source)
    value = source[content_start:end]
    if value.startswith("\r\n"):
        value = value[2:]
    elif value.startswith(("\n", "\r")):
        value = value[1:]
    return value, end + len(close)


def parse_quoted_string(source: str, start: int) -> tuple[str | None, int]:
    if start >= len(source) or source[start] not in {'"', "'"}:
        return None, start
    quote = source[start]
    index = start + 1
    output: list[str] = []
    escapes = {
        "a": "\a", "b": "\b", "f": "\f", "n": "\n",
        "r": "\r", "t": "\t", "v": "\v", "\\": "\\",
        '"': '"', "'": "'",
    }
    while index < len(source):
        char = source[index]
        index += 1
        if char == quote:
            return "".join(output), index
        if char != "\\":
            output.append(char)
            continue
        if index >= len(source):
            return None, index
        escaped = source[index]
        index += 1
        if escaped.isdigit():
            digits = escaped
            while index < len(source) and len(digits) < 3 and source[index].isdigit():
                digits += source[index]
                index += 1
            output.append(chr(int(digits, 10)))
        elif escaped == "x" and re.match(r"[0-9a-fA-F]{2}", source[index:index + 2]):
            output.append(chr(int(source[index:index + 2], 16)))
            index += 2
        elif escaped == "z":
            while index < len(source) and source[index].isspace():
                index += 1
        elif escaped == "\r":
            if index < len(source) and source[index] == "\n":
                index += 1
            output.append("\n")
        elif escaped == "\n":
            output.append("\n")
        else:
            output.append(escapes.get(escaped, escaped))
    return None, index


def parse_string(source: str, start: int) -> tuple[str | None, int]:
    value, end = parse_quoted_string(source, start)
    if value is not None:
        return value, end
    return parse_long_string(source, start)


def skip_trivia(source: str, start: int) -> int:
    index = start
    while index < len(source):
        if source[index].isspace():
            index += 1
        elif source.startswith("--", index):
            long_end = skip_long_bracket(source, index + 2)
            if long_end is not None:
                index = long_end
            else:
                newline = source.find("\n", index + 2)
                index = len(source) if newline < 0 else newline + 1
        else:
            break
    return index


def parse_literal_argument(source: str, start: int) -> tuple[str | None, int]:
    index = skip_trivia(source, start)
    value, index = parse_string(source, index)
    if value is None:
        return None, index
    while True:
        index = skip_trivia(source, index)
        if not source.startswith("..", index):
            break
        index = skip_trivia(source, index + 2)
        next_value, index = parse_string(source, index)
        if next_value is None:
            return None, index
        value += next_value
    index = skip_trivia(source, index)
    if index >= len(source) or source[index] not in {",", ")"}:
        return None, index
    return value, index


def extract_keys(source: str) -> set[str]:
    keys: set[str] = set()
    index = 0
    while index < len(source):
        if source.startswith("--", index):
            index = skip_trivia(source, index)
            continue
        if source[index] in {'"', "'"}:
            _, index = parse_quoted_string(source, index)
            continue
        if source[index] == "[":
            long_end = skip_long_bracket(source, index)
            if long_end is not None:
                index = long_end
                continue

        if source[index] != "E":
            index += 1
            continue

        call_end = None
        for name in ("EllesmereUI.Lf", "EllesmereUI.L"):
            if source.startswith(name, index):
                before_ok = index == 0 or not (source[index - 1].isalnum() or source[index - 1] == "_")
                after = index + len(name)
                after_ok = after >= len(source) or not (source[after].isalnum() or source[after] == "_")
                if before_ok and after_ok:
                    call_end = after
                    break
        if call_end is None:
            index += 1
            continue

        open_paren = skip_trivia(source, call_end)
        if open_paren < len(source) and source[open_paren] == "(":
            key, end = parse_literal_argument(source, open_paren + 1)
            if key is not None:
                keys.add(key)
            index = max(end, open_paren + 1)
        else:
            index = call_end
    return keys


def display_key(key: str) -> str:
    value = (key.replace("\\", "\\\\")
                .replace("\r", "\\r")
                .replace("\n", "\\n")
                .replace("\t", "\\t"))
    trailing = len(value) - len(value.rstrip(" "))
    if trailing:
        value = value[:-trailing] + ("\\x20" * trailing)
    return value


def main() -> None:
    keys: set[str] = set()
    for directory, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [name for name in dirnames if name not in EXCLUDED_DIRS]
        for filename in filenames:
            if not filename.endswith(".lua") or filename in EXCLUDED_FILES:
                continue
            path = Path(directory, filename)
            keys.update(extract_keys(path.read_text(encoding="utf-8")))
    for key in sorted(keys):
        print(display_key(key))


if __name__ == "__main__":
    main()
