#!/usr/bin/env python3
"""Generate the Theme colour sets from financeplan/Design/tokens.json.

    python3 -I scripts/tokens/generate_colorsets.py          # rewrite the colour sets
    python3 -I scripts/tokens/generate_colorsets.py --check  # exit 1 if any is stale

tokens.json is a byte copy of the web master, norviq-web-v2/design/tokens.json.
Edit the master, copy it here, then run `make tokens`. Never edit a Theme
colour set by hand: `make tokens-check` (CI) fails on it.

Every colour token whose $extensions.norviq has an `ios` name becomes
Assets.xcassets/Theme/<ios>.colorset/Contents.json: `$value` is the light
(universal) colour, `dark` the dark-appearance one. Alpha is the last hex byte,
round(alpha * 255); it is written back as round(byte / 255, 2), so 0x1A is
"0.100" and 0x0D is "0.050". A byte that does not survive that round trip
(0x19 would come back as 0x1A) is an error.

--check also fails when a Theme colour set has no token, or a token names a
colour set twice, so a set cannot quietly fall out of the generated range.
"""

import argparse
import json
import os
import sys

TOKENS = os.path.join("financeplan", "Design", "tokens.json")
THEME = os.path.join("financeplan", "Assets.xcassets", "Theme")


def parse_hex(value, where):
    if not isinstance(value, str) or not value.startswith("#") or len(value) not in (7, 9):
        raise ValueError("%s: expected #RRGGBB or #RRGGBBAA, got %r" % (where, value))
    digits = value[1:]
    try:
        channels = [int(digits[i:i + 2], 16) for i in range(0, len(digits), 2)]
    except ValueError:
        raise ValueError("%s: not hex: %r" % (where, value))
    if len(channels) == 3:
        channels.append(255)
    return channels


def components(value, where):
    red, green, blue, alpha = parse_hex(value, where)
    # A colour set stores alpha to two decimals. A byte that does not survive
    # that round trip (0x19 -> 0.10 -> 0x1A) would ship a different colour than
    # the token, so it is an error, not a silent rounding.
    stored = round(alpha / 255.0, 2)
    if int(stored * 255 + 0.5) != alpha:
        raise ValueError(
            "%s: alpha byte 0x%02X does not round-trip through a two-decimal alpha (%.2f -> 0x%02X); "
            "pick a byte that is round(alpha * 255) of a two-decimal alpha" % (where, alpha, stored, int(stored * 255 + 0.5))
        )
    return {
        "alpha": "%.3f" % stored,
        "blue": "0x%02X" % blue,
        "green": "0x%02X" % green,
        "red": "0x%02X" % red,
    }


def ios_tokens(tokens):
    """Returns {ios name: (token path, light hex, dark hex)}."""
    found = {}

    def walk(node, path):
        if not isinstance(node, dict):
            return
        if node.get("$type") == "color":
            norviq = node.get("$extensions", {}).get("norviq", {})
            name = norviq.get("ios")
            if name is None:
                return
            where = ".".join(path)
            if name in found:
                raise ValueError("%s: iOS name %s is already used by %s" % (where, name, found[name][0]))
            if "dark" not in norviq:
                raise ValueError("%s: an iOS colour needs a dark value" % where)
            found[name] = (where, node["$value"], norviq["dark"])
            return
        for key, child in node.items():
            if not key.startswith("$"):
                walk(child, path + [key])

    walk(tokens.get("color", {}), ["color"])
    return found


def colorset(path, light, dark):
    """Xcode's own layout: keys sorted, `"key" : value`, two-space indent."""
    document = {
        "colors": [
            {
                "color": {"color-space": "srgb", "components": components(light, path)},
                "idiom": "universal",
            },
            {
                "appearances": [{"appearance": "luminosity", "value": "dark"}],
                "color": {"color-space": "srgb", "components": components(dark, path + " dark")},
                "idiom": "universal",
            },
        ],
        "info": {"author": "xcode", "version": 1},
    }
    return json.dumps(document, indent=2, separators=(",", " : "), sort_keys=True) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--check", action="store_true", help="fail if any colour set is stale; write nothing")
    parser.add_argument(
        "--root",
        default=os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")),
        help="repository root (default: this script's repository)",
    )
    args = parser.parse_args()

    with open(os.path.join(args.root, TOKENS), encoding="utf-8") as handle:
        tokens = json.load(handle)
    try:
        wanted = ios_tokens(tokens)
    except ValueError as error:
        print("error: %s" % error, file=sys.stderr)
        return 1

    theme = os.path.join(args.root, THEME)
    existing = sorted(
        entry[: -len(".colorset")] for entry in os.listdir(theme) if entry.endswith(".colorset")
    )

    problems = []
    for name in existing:
        if name not in wanted:
            problems.append("%s.colorset has no token in %s; add one with \"ios\": \"%s\"" % (name, TOKENS, name))

    for name in sorted(wanted):
        path, light, dark = wanted[name]
        target = os.path.join(theme, name + ".colorset", "Contents.json")
        try:
            content = colorset(path, light, dark)
        except ValueError as error:
            problems.append(str(error))
            continue
        current = None
        if os.path.exists(target):
            with open(target, encoding="utf-8") as handle:
                current = handle.read()
        if current == content:
            continue
        if args.check:
            state = "missing" if current is None else "stale"
            problems.append("%s.colorset is %s (token %s)" % (name, state, path))
        else:
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with open(target, "w", encoding="utf-8") as handle:
                handle.write(content)
            print("wrote %s" % os.path.relpath(target, args.root))

    if problems:
        for problem in problems:
            print("error: %s" % problem, file=sys.stderr)
        if args.check:
            print("Run `make tokens` after copying the web master tokens.json; never edit a Theme colour set by hand.", file=sys.stderr)
        return 1
    if args.check:
        print("ok: %d Theme colour sets match %s" % (len(wanted), TOKENS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
