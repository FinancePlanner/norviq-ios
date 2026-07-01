#!/usr/bin/env python3
"""Derive transparent Norviq UI assets from opaque source exports."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageChops


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--mode", required=True, choices=("logo", "icon"))
    parser.add_argument("--width", required=True, type=int)
    parser.add_argument("--height", required=True, type=int)
    parser.add_argument("--theme", required=True, choices=("light", "dark"))
    return parser.parse_args()


def border_pixels(image: Image.Image) -> list[tuple[int, int, int]]:
    rgb = image.convert("RGB")
    width, height = rgb.size
    pixels: list[tuple[int, int, int]] = []
    step_x = max(1, width // 160)
    step_y = max(1, height // 160)

    for x in range(0, width, step_x):
        pixels.append(rgb.getpixel((x, 0)))
        pixels.append(rgb.getpixel((x, height - 1)))
    for y in range(0, height, step_y):
        pixels.append(rgb.getpixel((0, y)))
        pixels.append(rgb.getpixel((width - 1, y)))

    return pixels


def median_channel(values: list[int]) -> int:
    ordered = sorted(values)
    return ordered[len(ordered) // 2]


def estimate_background(image: Image.Image) -> tuple[int, int, int]:
    pixels = border_pixels(image)
    return (
        median_channel([pixel[0] for pixel in pixels]),
        median_channel([pixel[1] for pixel in pixels]),
        median_channel([pixel[2] for pixel in pixels]),
    )


def has_real_alpha(image: Image.Image) -> bool:
    if image.mode != "RGBA":
        return False
    alpha = image.getchannel("A")
    return alpha.getextrema()[0] < 250


def alpha_from_background(
    image: Image.Image,
    background: tuple[int, int, int],
    theme: str,
) -> Image.Image:
    rgb = image.convert("RGB")
    diff = ImageChops.difference(rgb, Image.new("RGB", rgb.size, background))
    red, green, blue = diff.split()
    max_diff = ImageChops.lighter(ImageChops.lighter(red, green), blue)

    if theme == "dark":
        transparent_at = 18
        opaque_at = 58
    else:
        transparent_at = 28
        opaque_at = 84

    span = opaque_at - transparent_at
    return max_diff.point(
        lambda value: 0
        if value <= transparent_at
        else 255
        if value >= opaque_at
        else int((value - transparent_at) * 255 / span)
    )


def unmatte(
    image: Image.Image,
    alpha: Image.Image,
    background: tuple[int, int, int],
) -> Image.Image:
    rgb_image = image.convert("RGB")
    rgb_pixels = list(
        rgb_image.get_flattened_data()
        if hasattr(rgb_image, "get_flattened_data")
        else rgb_image.getdata()
    )
    alpha_pixels = list(
        alpha.get_flattened_data()
        if hasattr(alpha, "get_flattened_data")
        else alpha.getdata()
    )
    bg_red, bg_green, bg_blue = background
    output: list[tuple[int, int, int, int]] = []

    for (red, green, blue), alpha_value in zip(rgb_pixels, alpha_pixels):
        if alpha_value <= 0:
            output.append((0, 0, 0, 0))
            continue
        if alpha_value >= 255:
            output.append((red, green, blue, 255))
            continue

        alpha_float = alpha_value / 255
        unmatted = (
            round((red - bg_red * (1 - alpha_float)) / alpha_float),
            round((green - bg_green * (1 - alpha_float)) / alpha_float),
            round((blue - bg_blue * (1 - alpha_float)) / alpha_float),
        )
        output.append(
            (
                max(0, min(255, unmatted[0])),
                max(0, min(255, unmatted[1])),
                max(0, min(255, unmatted[2])),
                alpha_value,
            )
        )

    result = Image.new("RGBA", image.size)
    result.putdata(output)
    return result


def transparent_source(source: Path, theme: str) -> Image.Image:
    image = Image.open(source).convert("RGBA")
    if has_real_alpha(image):
        return image

    background = estimate_background(image)
    alpha = alpha_from_background(image, background, theme)
    return unmatte(image, alpha, background)


def alpha_bbox(image: Image.Image, threshold: int = 32) -> tuple[int, int, int, int]:
    mask = image.getchannel("A").point(lambda value: 255 if value > threshold else 0)
    bbox = mask.getbbox()
    if bbox is None:
        raise SystemExit("derived asset has no visible pixels")
    return bbox


def icon_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = alpha_bbox(image)
    left, top, right, bottom = bbox
    mask = image.getchannel("A")
    width = right - left
    height = bottom - top
    low_limit = max(1, int(height * 0.012))
    columns: list[int] = []

    for x in range(left, right):
        count = 0
        for y in range(top, bottom):
            if mask.getpixel((x, y)) > 32:
                count += 1
        columns.append(count)

    best_start = -1
    best_end = -1
    run_start: int | None = None
    for index, count in enumerate(columns):
        in_middle = width * 0.16 < index < width * 0.62
        if in_middle and count <= low_limit:
            if run_start is None:
                run_start = index
        elif run_start is not None:
            if index - run_start > best_end - best_start:
                best_start, best_end = run_start, index
            run_start = None

    if run_start is not None and len(columns) - run_start > best_end - best_start:
        best_start, best_end = run_start, len(columns)

    if best_start >= 0 and best_end - best_start >= max(8, int(width * 0.025)):
        split_x = left + best_start
        return (left, top, split_x, bottom)

    return bbox


def fit_on_canvas(
    image: Image.Image,
    bbox: tuple[int, int, int, int],
    width: int,
    height: int,
    padding_ratio: float,
) -> Image.Image:
    crop = image.crop(bbox)
    max_width = int(width * (1 - padding_ratio * 2))
    max_height = int(height * (1 - padding_ratio * 2))
    scale = min(max_width / crop.width, max_height / crop.height)
    resized_width = max(1, round(crop.width * scale))
    resized_height = max(1, round(crop.height * scale))
    crop = crop.resize((resized_width, resized_height), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    canvas.alpha_composite(crop, ((width - resized_width) // 2, (height - resized_height) // 2))
    return canvas


def main() -> None:
    args = parse_args()
    image = transparent_source(args.source, args.theme)

    if args.mode == "icon":
        bbox = icon_bbox(image)
        padding = 0.11
    else:
        bbox = alpha_bbox(image)
        padding = 0.035

    output = fit_on_canvas(image, bbox, args.width, args.height, padding)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    output.save(args.output, optimize=True)


if __name__ == "__main__":
    main()
