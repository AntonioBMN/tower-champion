# Aseprite generators

The `generate_dungeon_tiles.lua` script creates a 4×4 sprite sheet for the
top-down prototype:

- row 1: four floors (normal, cracked, debris, and moss);
- row 2: walls in all four directions;
- row 3: four corners;
- row 4: four solid-wall variations.

## Installation

1. In Aseprite, open **File > Scripts > Open Scripts Folder**.
2. Copy `generate_dungeon_tiles.lua` into that folder.
3. Return to Aseprite and select **File > Scripts > Rescan Scripts Folder**.
4. Run **File > Scripts > generate_dungeon_tiles**.

Use tile size `32` for the current project. Save the generated source as an
`.aseprite` file, then export a `.png` copy to
`assets/sprites/tiles/dungeon_tiles_32px.png`.

In Godot, import the PNG without filtering, create a 32×32 `TileSet`, and
select the grid regions. The first four cells may use different probabilities
to vary the floor without changing collisions.

The **Seed** field reproduces the same cracks, rocks, and moss spots.

## Characters, weapons, and items

The `generate_game_assets.lua` script provides three modes:

- **Character:** a 4×4 sprite sheet. Rows represent down, left, right, and up;
  columns contain the four walk frames.
- **Weapons:** four variations of swords, axes, bows, and staves.
- **Items:** four variations of potions, coins, keys, and chests.

Install it in the same scripts folder and run
**File > Scripts > generate_game_assets**. Use 32 px cells for the current
prototype. Save the source `.aseprite` file and export a PNG copy into an
appropriate `assets/sprites/` subfolder.

In Godot, configure the character with `hframes = 4` and `vframes = 4`. The
animation order is `down`, `left`, `right`, `up`, with four frames per row.
