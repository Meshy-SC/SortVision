#!/usr/bin/env python3
"""
split_achievements.py
Splits the composite achievement badge image into 20 individual 512×512 PNG files
with a grey background at 72 DPI, ready for App Store Connect upload.

Usage:
    python3 Scripts/split_achievements.py <path_to_composite_image>

Example:
    python3 Scripts/split_achievements.py ~/Desktop/achievements.png
"""

import sys
import os
from PIL import Image

# ---------------------------------------------------------------------------
# Achievement filenames in grid order (left→right, top→bottom, 5 cols × 4 rows)
# ---------------------------------------------------------------------------
ACHIEVEMENT_NAMES = [
    # Row 1
    "first_steps",
    "ten_down",
    "fifty_solver",
    "century",
    "double_century",
    # Row 2
    "completionist",
    "world_conqueror",
    "dual_explorer",
    "globe_trotter",
    "star_collector",
    # Row 3
    "star_hoarder",
    "shining_bright",
    "perfectionist",
    "world_master",
    "triple_master",
    # Row 4
    "absolute_master",
    "optimal_solver",
    "precision_expert",
    "hidden_talent",
    "grand_master",
]

COLS = 5
ROWS = 4
OUTPUT_SIZE = 512          # px — square output required by App Store Connect
DPI = 72
GREY = (180, 180, 180)     # neutral mid-grey background
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "Pushbox", "Store assets", "Achievements")


def split(input_path: str) -> None:
    img = Image.open(input_path).convert("RGBA")
    w, h = img.size
    print(f"Source image: {w}×{h} px")

    cell_w = w // COLS
    cell_h = h // ROWS
    print(f"Detected cell size: {cell_w}×{cell_h} px")

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    for idx, name in enumerate(ACHIEVEMENT_NAMES):
        row = idx // COLS
        col = idx % COLS

        left   = col * cell_w
        top    = row * cell_h
        right  = left + cell_w
        bottom = top  + cell_h

        badge = img.crop((left, top, right, bottom))

        # Scale badge to fit inside OUTPUT_SIZE with a small margin
        margin = int(OUTPUT_SIZE * 0.04)   # 4% margin each side
        fit_size = OUTPUT_SIZE - margin * 2
        badge_resized = badge.resize((fit_size, fit_size), Image.LANCZOS)

        # Paste onto grey canvas
        canvas = Image.new("RGBA", (OUTPUT_SIZE, OUTPUT_SIZE), (*GREY, 255))
        canvas.paste(badge_resized, (margin, margin), badge_resized)

        # Save as RGB PNG at 72 DPI
        out_path = os.path.join(OUTPUT_DIR, f"{name}.png")
        canvas.convert("RGB").save(out_path, "PNG", dpi=(DPI, DPI))
        print(f"  ✅  {name}.png")

    print(f"\nDone — {len(ACHIEVEMENT_NAMES)} images saved to:\n  {os.path.abspath(OUTPUT_DIR)}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 Scripts/split_achievements.py <path_to_composite_image>")
        sys.exit(1)
    split(sys.argv[1])
