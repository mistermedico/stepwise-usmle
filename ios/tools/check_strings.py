#!/usr/bin/env python3
"""Verifies that every localisation file carries the same keys.

Run locally or in CI:

    python3 ios/tools/check_strings.py

Fails when a key exists in one language but not another, when a key is
duplicated, when a value is empty, or when the format specifiers of a
translation do not match the English original (a mismatch there crashes
`String(format:)` at runtime rather than merely looking wrong).
"""

import os
import re
import sys

ROOT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Strainwave", "Sources", "Resources",
)
BASE_LANGUAGE = "en"
ENTRY = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;\s*$')
SPECIFIER = re.compile(r"%(?:\d+\$)?[-+ #0]*[\d.]*[@dfsxu]")


def load(path):
    entries = {}
    duplicates = []
    with open(path, encoding="utf-8") as handle:
        for number, line in enumerate(handle, start=1):
            stripped = line.strip()
            if not stripped or stripped.startswith("/*") or stripped.startswith("//"):
                continue
            match = ENTRY.match(line)
            if not match:
                print("  ! %s:%d unparseable line: %s" % (path, number, stripped))
                return None, duplicates
            key, value = match.group(1), match.group(2)
            if key in entries:
                duplicates.append(key)
            entries[key] = value
    return entries, duplicates


def specifiers(value):
    # Order matters for un-numbered specifiers; sort the numbered ones so
    # "%1$@ %2$@" and "%2$@ %1$@" compare equal.
    found = SPECIFIER.findall(value)
    return sorted(found) if any("$" in item for item in found) else found


def main():
    languages = sorted(
        name[:-len(".lproj")]
        for name in os.listdir(ROOT)
        if name.endswith(".lproj")
    )
    if BASE_LANGUAGE not in languages:
        print("No %s.lproj found in %s" % (BASE_LANGUAGE, ROOT))
        return 1

    tables = {}
    problems = 0
    for language in languages:
        path = os.path.join(ROOT, language + ".lproj", "Localizable.strings")
        if not os.path.exists(path):
            print("Missing %s" % path)
            problems += 1
            continue
        entries, duplicates = load(path)
        if entries is None:
            problems += 1
            continue
        for key in duplicates:
            print("Duplicate key '%s' in %s" % (key, language))
            problems += 1
        tables[language] = entries
        print("%s: %d keys" % (language, len(entries)))

    base = tables.get(BASE_LANGUAGE, {})
    for language, entries in tables.items():
        if language == BASE_LANGUAGE:
            continue
        missing = sorted(set(base) - set(entries))
        extra = sorted(set(entries) - set(base))
        for key in missing:
            print("Missing in %s: %s" % (language, key))
        for key in extra:
            print("Not in %s: %s (%s)" % (BASE_LANGUAGE, key, language))
        problems += len(missing) + len(extra)

        for key, value in entries.items():
            if not value.strip():
                print("Empty value in %s: %s" % (language, key))
                problems += 1
            if key in base and specifiers(base[key]) != specifiers(value):
                print(
                    "Format mismatch for '%s': %s has %s, %s has %s"
                    % (key, BASE_LANGUAGE, specifiers(base[key]), language, specifiers(value))
                )
                problems += 1

    if problems:
        print("\n%d localisation problem(s)." % problems)
        return 1
    print("\nAll %d languages agree on %d keys." % (len(tables), len(base)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
