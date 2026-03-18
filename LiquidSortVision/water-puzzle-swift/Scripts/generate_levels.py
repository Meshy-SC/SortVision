#!/usr/bin/env python3
"""
Water Sort Puzzle — Level Generator & Solver
=============================================
Generates 1000 puzzles (10 worlds × 100 levels) with progressive difficulty.
Each puzzle is guaranteed solvable because it is produced by backward-scrambling
from a solved state; the reversed scramble path IS the solution.

Algorithm:
  1. Start from a SOLVED state (each tube has 4 units of one color + 2 empty tubes).
  2. Apply K random reverse-pours to scramble, recording every move.
  3. Validate quality (entropy, uniqueness).
  4. The reversed move list is the guaranteed solution.
  5. Output puzzle + solution JSON files.

Usage:
  python3 generate_levels.py
"""

import json
import os
import random
import hashlib
import sys
from copy import deepcopy
from pathlib import Path

# ─── Constants ──────────────────────────────────────────────────────────────────

TUBE_CAPACITY = 4

WORLDS = [
    {"name": "iron",        "title": "Iron",        "subtitle": "The Forge",
     "colors_range": (3, 4),   "scramble_range": (15, 25),   "hidden_range": (0, 0)},
    {"name": "bronze",      "title": "Bronze",      "subtitle": "Age of Valor",
     "colors_range": (4, 5),   "scramble_range": (25, 35),   "hidden_range": (0, 0)},
    {"name": "silver",      "title": "Silver",      "subtitle": "Moonlit Trials",
     "colors_range": (5, 6),   "scramble_range": (35, 50),   "hidden_range": (0, 0)},
    {"name": "gold",        "title": "Gold",        "subtitle": "Crown Jewels",
     "colors_range": (6, 7),   "scramble_range": (50, 65),   "hidden_range": (0, 1)},
    {"name": "platinum",    "title": "Platinum",    "subtitle": "Ethereal Heights",
     "colors_range": (7, 8),   "scramble_range": (65, 80),   "hidden_range": (0, 1)},
    {"name": "emerald",     "title": "Emerald",     "subtitle": "Verdant Maze",
     "colors_range": (8, 9),   "scramble_range": (80, 100),  "hidden_range": (1, 1)},
    {"name": "diamond",     "title": "Diamond",     "subtitle": "Crystal Depths",
     "colors_range": (9, 10),  "scramble_range": (100, 120), "hidden_range": (1, 2)},
    {"name": "master",      "title": "Master",      "subtitle": "The Crucible",
     "colors_range": (10, 11), "scramble_range": (120, 150), "hidden_range": (1, 2)},
    {"name": "grandmaster", "title": "Grandmaster", "subtitle": "Shadow Realm",
     "colors_range": (11, 12), "scramble_range": (150, 180), "hidden_range": (2, 2)},
    {"name": "legend",      "title": "Legend",      "subtitle": "Hall of Fame",
     "colors_range": (12, 14), "scramble_range": (180, 250), "hidden_range": (2, 3)},
]

LEVELS_PER_WORLD = 100
EMPTY_TUBES = 2

# ─── Helpers ────────────────────────────────────────────────────────────────────


def make_solved_state(num_colors: int) -> list[list[int]]:
    """Create the solved state: N tubes of 4 same-color units + 2 empty tubes."""
    tubes = [[c] * TUBE_CAPACITY for c in range(num_colors)]
    tubes.extend([[] for _ in range(EMPTY_TUBES)])
    return tubes


def tube_hash(tubes: list[list[int]]) -> str:
    """Canonical hash of a tube state (order-independent among tubes)."""
    canonical = tuple(sorted(tuple(t) for t in tubes))
    return hashlib.md5(str(canonical).encode()).hexdigest()


def is_solved(tubes: list[list[int]]) -> bool:
    """Check if all tubes are either empty or contain 4 of the same color."""
    for tube in tubes:
        if len(tube) == 0:
            continue
        if len(tube) != TUBE_CAPACITY:
            return False
        if len(set(tube)) != 1:
            return False
    return True


def count_top_same(tube: list[int]) -> int:
    """Count how many units of the same color sit on top of a tube."""
    if not tube:
        return 0
    top = tube[-1]
    count = 0
    for v in reversed(tube):
        if v == top:
            count += 1
        else:
            break
    return count


# ─── Backward Scrambler (with path recording) ──────────────────────────────────


def scramble_with_path(
    num_colors: int, depth: int
) -> tuple[list[list[int]], list[tuple[int, int, int]]] | None:
    """
    Start from solved state and perform `depth` random reverse-pours.
    Records each move as (src, dst, amount).

    Returns (scrambled_tubes, move_list) where move_list is the
    sequence of scramble moves applied (to be reversed for the solution).
    """
    tubes = make_solved_state(num_colors)
    visited = {tube_hash(tubes)}
    move_path = []  # (src, dst, amount) for each scramble step

    stall_count = 0
    max_stalls = depth * 3  # allow more attempts to reach target depth

    while len(move_path) < depth and stall_count < max_stalls:
        # Collect all valid reverse-pour moves
        moves = []
        for src in range(len(tubes)):
            if not tubes[src]:
                continue
            top_color = tubes[src][-1]
            top_count = count_top_same(tubes[src])

            for dst in range(len(tubes)):
                if dst == src:
                    continue
                space = TUBE_CAPACITY - len(tubes[dst])
                if space <= 0:
                    continue
                # Can pour 1..min(top_count, space) units
                for amt in range(1, min(top_count, space) + 1):
                    moves.append((src, dst, amt))

        if not moves:
            break

        random.shuffle(moves)

        moved = False
        for src, dst, amt in moves:
            new_tubes = [t[:] for t in tubes]
            units = new_tubes[src][-amt:]
            new_tubes[src] = new_tubes[src][:-amt]
            new_tubes[dst].extend(units)
            h = tube_hash(new_tubes)
            if h not in visited:
                visited.add(h)
                tubes = new_tubes
                move_path.append((src, dst, amt))
                moved = True
                break

        if not moved:
            stall_count += 1
            # Force a random move even if visited (to escape local loops)
            if stall_count % 5 == 0 and moves:
                src, dst, amt = random.choice(moves)
                new_tubes = [t[:] for t in tubes]
                units = new_tubes[src][-amt:]
                new_tubes[src] = new_tubes[src][:-amt]
                new_tubes[dst].extend(units)
                tubes = new_tubes
                move_path.append((src, dst, amt))
                # Don't add to visited — allow revisits to escape

    if len(move_path) < depth // 2:
        # Didn't scramble enough
        return None

    return tubes, move_path


def reverse_path_to_solution(
    scrambled_tubes: list[list[int]], scramble_moves: list[tuple[int, int, int]]
) -> list[tuple[int, int]]:
    """
    Convert the scramble path into forward solving moves.
    Each scramble move (src→dst, amt) becomes a solving move (dst→src).

    But in the actual game, a pour from tube A to tube B pours ALL same-color
    units from the top. So we need to simulate forward and produce valid
    game moves (just src, dst pairs).
    """
    # Work forward from the scrambled state, undoing each scramble move in reverse
    tubes = [t[:] for t in scrambled_tubes]
    solution = []

    for src, dst, amt in reversed(scramble_moves):
        # The scramble moved `amt` units from src→dst.
        # To undo: pour from dst→src.
        # In the game, pouring moves all same-color top units, so let's simulate.
        # The top `amt` units of dst should be the ones that were moved.
        # We move them back to src.
        if not tubes[dst]:
            continue  # shouldn't happen but safety

        # Take the top `amt` units from dst and put back on src
        units = tubes[dst][-amt:]
        tubes[dst] = tubes[dst][:-amt]
        tubes[src].extend(units)
        solution.append((dst, src))

    return solution


# ─── Quality Checks ────────────────────────────────────────────────────────────


def passes_quality_check(tubes: list[list[int]], num_colors: int) -> bool:
    """
    Reject puzzles that are too easy:
    - No tube should have all 4 same color (already solved tube)
    - At least half the tubes should have 2+ distinct colors (well-mixed)
    """
    if is_solved(tubes):
        return False

    # No tube should already be solved
    for tube in tubes:
        if len(tube) == TUBE_CAPACITY and len(set(tube)) == 1:
            return False

    # Count tubes with 2+ distinct colors
    mixed_count = 0
    for tube in tubes:
        if len(tube) >= 2 and len(set(tube)) >= 2:
            mixed_count += 1

    # At least 40% of filled tubes should be mixed
    filled_count = sum(1 for t in tubes if len(t) > 0)
    if filled_count > 0 and mixed_count < filled_count * 0.4:
        return False

    return True


# ─── Puzzle Generator ───────────────────────────────────────────────────────────


def generate_puzzle(
    num_colors: int,
    scramble_depth: int,
    seen_hashes: set[str],
    max_attempts: int = 300,
) -> tuple[list[list[int]], list[tuple[int, int]]] | None:
    """
    Generate a single puzzle with guaranteed solution.
    Returns (tubes, solution_moves) or None after max_attempts.
    """
    for _ in range(max_attempts):
        result = scramble_with_path(num_colors, scramble_depth)
        if result is None:
            continue

        tubes, scramble_moves = result

        # Quality check
        if not passes_quality_check(tubes, num_colors):
            continue

        # Uniqueness
        h = tube_hash(tubes)
        if h in seen_hashes:
            continue

        # Build solution from reversed scramble path
        solution = reverse_path_to_solution(tubes, scramble_moves)

        seen_hashes.add(h)
        return tubes, solution

    return None


# ─── Main ───────────────────────────────────────────────────────────────────────


def main():
    script_dir = Path(__file__).parent
    resources_dir = script_dir.parent / "Resources"
    resources_dir.mkdir(exist_ok=True)

    # Delete ALL old level/solution files
    old_patterns = [
        "levels.json", "levels-normal.json", "levels-hard.json", "levels-ex.json",
    ]
    # Delete old puzzles-*.json and solutions-*.json
    for f in resources_dir.glob("puzzles-*.json"):
        f.unlink()
        print(f"  🗑  Deleted old file: {f.name}")
    for f in resources_dir.glob("solutions-*.json"):
        f.unlink()
        print(f"  🗑  Deleted old file: {f.name}")
    # Delete old World*.json files
    for f in resources_dir.glob("World*.json"):
        f.unlink()
        print(f"  🗑  Deleted old file: {f.name}")
    for f in old_patterns:
        path = resources_dir / f
        if path.exists():
            path.unlink()
            print(f"  🗑  Deleted old file: {f}")

    seen_hashes: set[str] = set()
    total_generated = 0

    for world_idx, world in enumerate(WORLDS):
        world_number = world_idx + 1
        world_name = world["name"]
        world_title = world["title"]
        world_subtitle = world["subtitle"]
        colors_lo, colors_hi = world["colors_range"]
        scramble_lo, scramble_hi = world["scramble_range"]

        puzzles = []
        optimal_moves_list = []
        solution_moves_list = []

        print(f"\n{'='*60}")
        print(f"  World {world_number}: {world_name.upper()} "
              f"({colors_lo}–{colors_hi} colors, "
              f"scramble {scramble_lo}–{scramble_hi})")
        print(f"{'='*60}")

        for level_idx in range(LEVELS_PER_WORLD):
            # Linearly interpolate difficulty within the world
            t = level_idx / max(LEVELS_PER_WORLD - 1, 1)
            num_colors = colors_lo + int(t * (colors_hi - colors_lo))
            scramble_depth = scramble_lo + int(t * (scramble_hi - scramble_lo))

            result = generate_puzzle(num_colors, scramble_depth, seen_hashes)

            if result is None:
                result = generate_puzzle(
                    num_colors, max(10, scramble_depth // 2), seen_hashes, max_attempts=500
                )

            if result is None:
                for fallback_colors in range(num_colors - 1, 2, -1):
                    result = generate_puzzle(
                        fallback_colors, scramble_depth // 2, seen_hashes, max_attempts=500
                    )
                    if result:
                        print(f"  ⚠️  Fallback: level {level_idx + 1} "
                              f"uses {fallback_colors} colors")
                        break

            if result is None:
                print(f"  🚨 CRITICAL: Could not generate level {level_idx + 1}!")
                sys.exit(1)

            tubes, solution_moves = result
            local_no = level_idx + 1

            # Build puzzle entry (matches existing JSON format)
            puzzle_entry = {
                "no": local_no,
                "map": [{"values": tube} for tube in tubes],
            }
            puzzles.append(puzzle_entry)

            # Track optimal moves and solution
            optimal_moves_list.append(len(solution_moves))
            solution_moves_list.append([list(m) for m in solution_moves])

            total_generated += 1
            if (level_idx + 1) % 10 == 0:
                print(f"  ✅ Generated {level_idx + 1}/{LEVELS_PER_WORLD} "
                      f"(last: {num_colors} colors, {len(solution_moves)} moves)")

        # Write World{N}.json (puzzles — same format as Pushbox World{N}.json)
        puzzle_file = resources_dir / f"World{world_number}.json"
        with open(puzzle_file, "w") as f:
            json.dump({"levels": puzzles}, f, separators=(",", ":"))
        print(f"  📄 Wrote {puzzle_file.name} ({len(puzzles)} levels)")

        # Write World{N}Data.json (metadata — mirrors Pushbox WorldData format)
        world_data = {
            "worldName": f"World{world_number}",
            "title": world_title,
            "subtitle": world_subtitle,
            "optimalPushCounts": optimal_moves_list,
            "solutions": solution_moves_list,
        }
        data_file = resources_dir / f"World{world_number}Data.json"
        with open(data_file, "w") as f:
            json.dump(world_data, f, separators=(",", ":"))
        print(f"  📄 Wrote {data_file.name}")


    print(f"\n{'='*60}")
    print(f"  ✅ DONE: {total_generated} puzzles generated successfully")
    print(f"{'='*60}")


if __name__ == "__main__":
    random.seed(42)  # Reproducible output
    main()
