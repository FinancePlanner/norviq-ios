#!/usr/bin/env python3
"""Fix missing English translations in Localizable.xcstrings.

For each key missing `en` but having `pt-PT`, adds an English stringUnit
using the key itself as the value (xcstrings convention: key = source language text).
Handles format specifier positional conversion for keys with 2+ specifiers.
"""

import json
import re
import sys
from pathlib import Path

XCSTRINGS_PATH = Path(__file__).parent / "financeplan" / "Localizable.xcstrings"

# Matches all printf-style specifiers we need to handle
SPECIFIER_PATTERN = re.compile(r'%(?:\d+\$)?[@dfiugelscq]|%lld|%lf|%ld|%lu')


def count_specifiers(text: str) -> list[str]:
    """Return list of format specifiers found in text, in order."""
    return SPECIFIER_PATTERN.findall(text)


def to_positional(key: str) -> str:
    """Convert format specifiers in key to positional form if 2+ present."""
    specifiers = count_specifiers(key)
    if len(specifiers) < 2:
        return key

    result = key
    index = 1
    # Replace each specifier sequentially with positional version
    for spec in specifiers:
        # Skip if already positional (contains $)
        if '$' in spec:
            index += 1
            continue
        # Build positional replacement: %@ → %1$@, %lld → %1$lld
        suffix = spec[1:]  # everything after %
        positional = f'%{index}${suffix}'
        # Replace only first occurrence
        result = result.replace(spec, positional, 1)
        index += 1

    return result


def fix_xcstrings(path: Path) -> tuple[int, int]:
    """Add missing English translations. Returns (fixed_count, total_count)."""
    with open(path, encoding='utf-8') as f:
        data = json.load(f)

    strings = data.get('strings', {})
    fixed = 0

    for key, entry in strings.items():
        localizations = entry.get('localizations', {})
        if 'en' not in localizations and 'pt-PT' in localizations:
            en_value = to_positional(key)
            localizations['en'] = {
                'stringUnit': {
                    'state': 'translated',
                    'value': en_value
                }
            }
            entry['localizations'] = localizations
            fixed += 1

    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=False)
        f.write('\n')

    return fixed, len(strings)


def verify(path: Path) -> list[str]:
    """Return list of keys still missing English after fix."""
    with open(path, encoding='utf-8') as f:
        data = json.load(f)
    return [
        k for k, v in data['strings'].items()
        if 'en' not in v.get('localizations', {})
        and v.get('localizations')  # skip empty entries like ""
    ]


if __name__ == '__main__':
    if not XCSTRINGS_PATH.exists():
        print(f"ERROR: File not found: {XCSTRINGS_PATH}", file=sys.stderr)
        sys.exit(1)

    print(f"Processing: {XCSTRINGS_PATH}")
    fixed, total = fix_xcstrings(XCSTRINGS_PATH)
    print(f"Fixed {fixed} missing English translations out of {total} total keys.")

    still_missing = verify(XCSTRINGS_PATH)
    if still_missing:
        print(f"\nWARNING: {len(still_missing)} keys still missing English:")
        for k in still_missing:
            print(f"  - {repr(k)}")
    else:
        print("Verification passed: all keys now have English translations.")
