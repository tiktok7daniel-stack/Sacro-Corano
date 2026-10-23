#!/usr/bin/env python3
"""Generates every Mishkah logo asset from one geometry definition.

The geometry mirrors lib/core/widgets/logo.dart (1024 x 1024 grid):
a mihrab niche (مشكاة) holding a lamp whose light is an eight-pointed star.

Outputs:
  branding/logo.svg, logo-mark.svg, logo-monochrome.svg
  branding/png/mishkah-{16..1024}.png
  assets/branding/*.png            (launcher icon, adaptive icon, splash)
  android/app/src/main/res/drawable-*/ic_stat_mishkah.png (notification)

Usage: python3 tool/branding/build_branding.py   (needs: pip install cairosvg)
"""
import os

import cairosvg

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GOLD = "#D6B26E"
STAR = "#F3D58F"
TEAL = "#1E7F8A"
TEAL_BRIGHT = "#34A9B4"
INK = "#0A0E15"

ARCH = "M300 830 L300 480 C300 330 410 240 512 182 C614 240 724 330 724 480 L724 830"
GLASS = "M462 420 L562 420 C660 452 668 650 512 704 C356 650 364 452 462 420 Z"


def star(cx=512, cy=568, r=82, fill=STAR, hole=TEAL):
    s = r * 1.42 / 2
    sq = f'<rect x="{cx - s}" y="{cy - s}" width="{2 * s}" height="{2 * s}" fill="{fill}"/>'
    rot = f'<g transform="rotate(45 {cx} {cy})">{sq}</g>'
    centre = f'<circle cx="{cx}" cy="{cy}" r="24" fill="{hole}"/>' if hole else ""
    return sq + rot + centre


def mark(color_mode="full"):
    """SVG body of the mark (no background)."""
    if color_mode == "mono":
        c = "#FFFFFF"
        return (
            f'<path d="{ARCH}" fill="none" stroke="{c}" stroke-width="40" stroke-linecap="round" stroke-linejoin="round"/>'
            f'<line x1="262" y1="830" x2="762" y2="830" stroke="{c}" stroke-width="40" stroke-linecap="round"/>'
            f'<line x1="512" y1="300" x2="512" y2="405" stroke="{c}" stroke-width="18" stroke-linecap="round"/>'
            f'<path d="{GLASS}" fill="none" stroke="{c}" stroke-width="22" stroke-linejoin="round"/>'
            + star(fill=c, hole=None)
        )
    return (
        '<defs>'
        f'<linearGradient id="glass" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{TEAL_BRIGHT}" stop-opacity="0.35"/>'
        f'<stop offset="1" stop-color="{TEAL}" stop-opacity="0.75"/></linearGradient>'
        '<radialGradient id="glow"><stop offset="0" stop-color="#FFE6A8" stop-opacity="0.55"/>'
        '<stop offset="1" stop-color="#FFE6A8" stop-opacity="0"/></radialGradient>'
        '</defs>'
        f'<path d="{ARCH}" fill="none" stroke="{GOLD}" stroke-width="34" stroke-linecap="round" stroke-linejoin="round"/>'
        f'<line x1="262" y1="830" x2="762" y2="830" stroke="{GOLD}" stroke-width="34" stroke-linecap="round"/>'
        f'<line x1="512" y1="300" x2="512" y2="405" stroke="{GOLD}" stroke-width="14" stroke-linecap="round"/>'
        f'<path d="{GLASS}" fill="url(#glass)" stroke="{GOLD}" stroke-width="16" stroke-linejoin="round"/>'
        '<circle cx="512" cy="568" r="150" fill="url(#glow)"/>'
        + star()
    )


def background():
    return (
        '<defs><radialGradient id="bg" cx="0.5" cy="0.45" r="0.85">'
        '<stop offset="0" stop-color="#15404A"/><stop offset="0.6" stop-color="#0C1A22"/>'
        f'<stop offset="1" stop-color="{INK}"/></radialGradient></defs>'
        '<rect width="1024" height="1024" rx="232" fill="url(#bg)"/>'
    )


def svg(body, scale=1.0, size=1024):
    off = (1 - scale) * 512
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 1024 1024">'
        f'<g transform="translate({off} {off}) scale({scale})">{body}</g></svg>'
    )


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def png(svg_text, path, size):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    cairosvg.svg2png(bytestring=svg_text.encode(), write_to=path, output_width=size, output_height=size)


def main():
    b = os.path.join(ROOT, "branding")
    full = svg(background() + mark())
    write(os.path.join(b, "logo.svg"), full)
    write(os.path.join(b, "logo-mark.svg"), svg(mark()))
    write(os.path.join(b, "logo-monochrome.svg"), svg(mark("mono")))
    for s in (16, 32, 48, 64, 128, 256, 512, 1024):
        png(full, os.path.join(b, "png", f"mishkah-{s}.png"), s)

    a = os.path.join(ROOT, "assets", "branding")
    png(full, os.path.join(a, "icon-1024.png"), 1024)
    # Adaptive icon: flutter_launcher_icons adds a 16% inset, so 0.92 here
    # lands the mark inside the central 66% safe zone.
    png(svg(mark(), scale=0.92), os.path.join(a, "icon-foreground-1024.png"), 1024)
    png(svg(mark("mono"), scale=0.92), os.path.join(a, "icon-monochrome-1024.png"), 1024)
    png(svg(mark(), scale=0.9), os.path.join(a, "splash-logo.png"), 576)
    # Android 12 splash icon: 960 px, content within a 640 px circle.
    png(svg(mark(), scale=0.6), os.path.join(a, "splash-logo-android12.png"), 960)
    png(svg(mark()), os.path.join(a, "logo-mark-512.png"), 512)

    # Status-bar notification icon: white silhouette.
    res = os.path.join(ROOT, "android", "app", "src", "main", "res")
    for density, px in (("mdpi", 24), ("hdpi", 36), ("xhdpi", 48), ("xxhdpi", 72), ("xxxhdpi", 96)):
        png(svg(mark("mono"), scale=1.05), os.path.join(res, f"drawable-{density}", "ic_stat_mishkah.png"), px)
    print("branding assets written")


if __name__ == "__main__":
    main()
