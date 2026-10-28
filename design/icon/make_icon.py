#!/usr/bin/env python3
"""Generates the Family app icon SVGs (light, dark, tinted).

Geometry recreates the supplied artwork: three overlapping people in
purple, blue and mint. Render to 1024x1024 PNG with render_icon.js.
"""
from pathlib import Path

def body(cx, w, top, bottom, r=36):
    h = bottom - top
    return (f"M{cx-w},{bottom-r} Q{cx-w},{bottom} {cx-w+r},{bottom} "
            f"L{cx+w-r},{bottom} Q{cx+w},{bottom} {cx+w},{bottom-r} "
            f"C{cx+w-w*0.06},{top+h*0.42} {cx+w*0.52},{top} {cx},{top} "
            f"C{cx-w*0.52},{top} {cx-w+w*0.06},{top+h*0.42} {cx-w},{bottom-r} Z")

# Coordinates in a 1024 canvas (artwork centred, ~8% margin like the original).
LEFT = dict(cx=328, head=(328, 410, 111, 118), body=(328, 236, 548, 768))
RIGHT = dict(cx=696, head=(696, 410, 111, 118), body=(696, 236, 548, 768))
MID = dict(cx=512, head=(512, 368, 140, 148), body=(512, 292, 536, 804))

PALETTES = {
    "light": dict(bg=("#FFFFFF", "#F4F7FB"),
                  left=("#CBC6FB", "#9E93F4"), mid_head=("#8CE6FC", "#4FB6F8"),
                  mid_body=("#5CC4FB", "#2F78FA"), right=("#A8F8DC", "#7BE3CB"),
                  opacity=0.88),
    "dark": dict(bg=("#1C2230", "#0B0E15"),
                 left=("#B9B2FF", "#8C7FF7"), mid_head=("#7FE0FF", "#3FAAFA"),
                 mid_body=("#52BEFF", "#2A6FFB"), right=("#98F5D5", "#62D9BF"),
                 opacity=0.9),
    "tinted": dict(bg=("#000000", "#000000"),
                   left=("#9A9A9A", "#7C7C7C"), mid_head=("#E6E6E6", "#C4C4C4"),
                   mid_body=("#D2D2D2", "#AFAFAF"), right=("#9A9A9A", "#7C7C7C"),
                   opacity=0.92),
}

def grad(gid, colors):
    return (f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{colors[0]}"/>'
            f'<stop offset="1" stop-color="{colors[1]}"/></linearGradient>')

def person(p, head_fill, body_fill, opacity):
    hx, hy, rx, ry = p["head"]
    bx, w, t, b = p["body"]
    return (f'<g opacity="{opacity}">'
            f'<ellipse cx="{hx}" cy="{hy}" rx="{rx}" ry="{ry}" fill="url(#{head_fill})"/>'
            f'<path d="{body(bx, w, t, b)}" fill="url(#{body_fill})"/></g>')

def svg(name):
    p = PALETTES[name]
    defs = "".join([grad("bg", p["bg"]), grad("l", p["left"]), grad("mh", p["mid_head"]),
                    grad("mb", p["mid_body"]), grad("r", p["right"])])
    o = p["opacity"]
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">'
            f'<defs>{defs}</defs><rect width="1024" height="1024" fill="url(#bg)"/>'
            f'{person(LEFT, "l", "l", o)}{person(RIGHT, "r", "r", o)}{person(MID, "mh", "mb", o)}</svg>')

out = Path(__file__).parent
for name in PALETTES:
    (out / f"AppIcon-{name}.svg").write_text(svg(name))
print("wrote", ", ".join(PALETTES))
