"""Draws the app icon and writes it at every size the platforms need.

A cobalt tile holding a 3x3 grid with the middle cell picked out in marker
yellow, the way the app marks the answer cell. Needs Pillow.

    python3 tool/make_icons.py

Run it from the repository root. It overwrites the icon files under
`android/`, `ios/`, `web/` and `windows/`.
"""

from pathlib import Path

from PIL import Image, ImageDraw

COBALT = (0x2A, 0x4B, 0xFF)
MARKER = (0xFF, 0xD8, 0x4A)
WHITE = (0xFF, 0xFF, 0xFF)

# How the drawing is laid out, as shares of the icon's width.
GRID_SHARE = 0.60  # the grid's side
LINE_SHARE = 0.018  # a thin grid line
BOX_LINE_SHARE = 0.032  # the outline of the grid
CORNER_SHARE = 0.22  # corner rounding of a rounded icon
CELL_INSET_SHARE = 0.0  # gap between the yellow cell and the lines
MASKABLE_SCALE = 0.78  # content stays inside the area every mask keeps

MASTER_SIZE = 1024
SUPERSAMPLE = 2  # draw big, then shrink, for smooth edges

ROOT = Path(__file__).resolve().parent.parent


def draw_master(size, *, rounded, scale=1.0):
    """The icon at [size] pixels. [rounded] clips the corners (transparent);
    [scale] shrinks the drawing inside a full-bleed tile."""
    big = size * SUPERSAMPLE
    image = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    if rounded:
        draw.rounded_rectangle(
            (0, 0, big - 1, big - 1), radius=big * CORNER_SHARE, fill=COBALT
        )
    else:
        draw.rectangle((0, 0, big, big), fill=COBALT)

    side = big * GRID_SHARE * scale
    left = (big - side) / 2
    top = left
    cell = side / 3
    thin = max(1, round(big * LINE_SHARE * scale))
    heavy = max(1, round(big * BOX_LINE_SHARE * scale))

    inset = big * CELL_INSET_SHARE * scale
    draw.rectangle(
        (
            left + cell + inset,
            top + cell + inset,
            left + 2 * cell - inset,
            top + 2 * cell - inset,
        ),
        fill=MARKER,
    )
    for i in (1, 2):
        offset = i * cell
        draw.line((left + offset, top, left + offset, top + side), WHITE, thin)
        draw.line((left, top + offset, left + side, top + offset), WHITE, thin)
    draw.rectangle(
        (left, top, left + side, top + side), outline=WHITE, width=heavy
    )
    return image.resize((size, size), Image.LANCZOS)


def save(image, path, size, *, opaque=False):
    out = image.resize((size, size), Image.LANCZOS)
    if opaque:
        out = out.convert("RGB")
    path = ROOT / path
    path.parent.mkdir(parents=True, exist_ok=True)
    out.save(path)


def main():
    rounded = draw_master(MASTER_SIZE, rounded=True)
    square = draw_master(MASTER_SIZE, rounded=False)
    maskable = draw_master(MASTER_SIZE, rounded=False, scale=MASKABLE_SCALE)

    # Android launcher icons, by density.
    for density, size in {
        "mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192,
    }.items():
        save(rounded, f"android/app/src/main/res/mipmap-{density}/ic_launcher.png", size)

    # iOS wants square, opaque icons: the system rounds them.
    iconset = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for file in sorted(iconset.glob("Icon-App-*.png")):
        name = file.stem.removeprefix("Icon-App-")  # such as 83.5x83.5@2x
        points, _, scale = name.partition("@")
        size = round(float(points.split("x")[0]) * int(scale.removesuffix("x")))
        save(square, file.relative_to(ROOT), size, opaque=True)

    # Web: the installable app, the maskable variants, and the tab icon.
    save(rounded, "web/icons/Icon-192.png", 192)
    save(rounded, "web/icons/Icon-512.png", 512)
    save(maskable, "web/icons/Icon-maskable-192.png", 192)
    save(maskable, "web/icons/Icon-maskable-512.png", 512)
    save(rounded, "web/favicon.png", 32)

    # Windows holds several sizes in one file.
    ico = ROOT / "windows/runner/resources/app_icon.ico"
    rounded.save(ico, sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])


if __name__ == "__main__":
    main()
