#!/usr/bin/env python3
"""Optimize opaque platform PNGs without changing dimensions."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    parser.add_argument("--colors", type=int, default=256)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    image = Image.open(args.path).convert("RGBA")
    background = Image.new("RGBA", image.size, (255, 255, 255, 255))
    background.alpha_composite(image)
    rgb = background.convert("RGB")

    if args.colors > 0:
        optimized = rgb.quantize(
            colors=args.colors,
            method=Image.Quantize.MAXCOVERAGE,
            dither=Image.Dither.FLOYDSTEINBERG,
        )
    else:
        optimized = rgb

    optimized.save(args.path, optimize=True)


if __name__ == "__main__":
    main()
