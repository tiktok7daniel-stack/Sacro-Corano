#!/usr/bin/env python3
"""Writes assets/lottie/celebration.json (Bodymovin 5.x).

A gold eight-pointed star blooms and turns, a soft glow expands and
twelve small stars burst outward. Generated from code so the animation
is reviewable and free of third-party licences.
"""
import json
import math
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FR, OP, W, H = 60, 96, 400, 400
GOLD = [0.839, 0.698, 0.431, 1]
LIGHT = [0.953, 0.835, 0.561, 1]
TEAL = [0.204, 0.663, 0.706, 1]

EASE_OUT = {"i": {"x": [0.2], "y": [1]}, "o": {"x": [0.4], "y": [0]}}


def static(v):
    return {"a": 0, "k": v}


def anim(frames):
    """frames: list of (t, value). Values become lists."""
    ks = []
    for i, (t, v) in enumerate(frames):
        k = {"t": t, "s": v if isinstance(v, list) else [v]}
        if i < len(frames) - 1:
            k.update(EASE_OUT)
        ks.append(k)
    return {"a": 1, "k": ks}


def transform(o=static(100), r=static(0), p=None, s=static([100, 100, 100])):
    return {"o": o, "r": r, "p": p or static([W / 2, H / 2, 0]), "a": static([0, 0, 0]), "s": s}


def group(items, name):
    tr = {"ty": "tr", "p": static([0, 0]), "a": static([0, 0]), "s": static([100, 100]),
          "r": static(0), "o": static(100), "sk": static(0), "sa": static(0), "nm": "t"}
    return {"ty": "gr", "nm": name, "it": items + [tr]}


def polystar(points, outer, inner):
    return {"ty": "sr", "sy": 1, "d": 1, "pt": static(points), "p": static([0, 0]), "r": static(0),
            "ir": static(inner), "is": static(0), "or": static(outer), "os": static(0), "nm": "star"}


def fill(c, opacity=100):
    return {"ty": "fl", "c": static(c), "o": static(opacity), "r": 1, "nm": "fill"}


def layer(ind, name, shapes, ks, ip=0):
    return {"ddd": 0, "ind": ind, "ty": 4, "nm": name, "sr": 1, "ks": ks, "ao": 0,
            "shapes": shapes, "ip": ip, "op": OP, "st": 0, "bm": 0}


def main():
    layers = []
    # Main star.
    layers.append(layer(1, "main-star", [group([polystar(8, 62, 36), fill(LIGHT)], "s"),
                                          group([{"ty": "el", "d": 1, "p": static([0, 0]), "s": static([30, 30]), "nm": "c"}, fill(TEAL)], "c")],
                        transform(
                            r=anim([(0, -90), (40, 0)]),
                            s=anim([(0, [0, 0, 100]), (26, [118, 118, 100]), (40, [100, 100, 100])]),
                        )))
    # Glow.
    layers.append(layer(2, "glow", [group([{"ty": "el", "d": 1, "p": static([0, 0]), "s": static([200, 200]), "nm": "e"}, fill(GOLD, 35)], "g")],
                        transform(
                            o=anim([(0, 0), (16, 80), (OP, 0)]),
                            s=anim([(0, [20, 20, 100]), (OP, [190, 190, 100])]),
                        )))
    # Burst of small stars.
    for i in range(12):
        a = 2 * math.pi * i / 12
        dist = 150 if i % 2 == 0 else 115
        end = [W / 2 + math.cos(a) * dist, H / 2 + math.sin(a) * dist, 0]
        start = 10 + (i % 3) * 3
        layers.append(layer(3 + i, f"spark-{i}", [group([polystar(5, 13, 6), fill(GOLD if i % 2 else LIGHT)], "s")],
                            transform(
                                o=anim([(start, 100), (OP - 10, 100), (OP, 0)]),
                                p=anim([(start, [W / 2, H / 2, 0]), (start + 40, end)]),
                                s=anim([(start, [0, 0, 100]), (start + 18, [110, 110, 100]), (OP, [40, 40, 100])]),
                                r=anim([(start, 0), (OP, 180 if i % 2 else -180)]),
                            ), ip=start))
    # Draw order: glow behind, sparks, main star on top.
    ordered = [layers[0]] + layers[2:] + [layers[1]]
    doc = {"v": "5.7.4", "fr": FR, "ip": 0, "op": OP, "w": W, "h": H, "nm": "mishkah-celebration",
           "ddd": 0, "assets": [], "layers": ordered}
    out = os.path.join(ROOT, "assets", "lottie", "celebration.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w") as f:
        json.dump(doc, f, separators=(",", ":"))
    print("wrote", out)


if __name__ == "__main__":
    main()
