# RUNE TRIO source atlases

Place finished PNG atlases in this folder. The slicer uses fixed grid coordinates only: it does not resize images or analyze their contents.

## Rune Tiles

- File: `rune_tiles_atlas.png`
- Dimensions: `1536x1024`
- Grid: `3 columns x 2 rows`
- Cell: `512x512`
- Order: `FIRE`, `ICE`, `LIGHTNING`, `WIND`, `LIFE`, `SHIELD`
- Output: `res://assets/textures/tiles/`
- Names: `fire.png`, `ice.png`, `lightning.png`, `wind.png`, `life.png`, `shield.png`

## Enemies

- File: `enemies_atlas.png`
- Dimensions: `2048x1024`
- Grid: `4 columns x 2 rows`
- Cell: `512x512`
- Order: `rune_dummy`, `stone_guard`, `stone_golem`, `frost_beast`, `frost_witch`
- Output: `res://assets/textures/enemies/`

Unused cells are ignored.

## Core and Relics

- File: `core_relics_atlas.png`
- Dimensions: `1536x512`
- Grid: `3 columns x 1 row`
- Cell: `512x512`
- Order: `core`, `golem_heart`, `frozen_crown`
- Outputs: `res://assets/textures/core/` and `res://assets/textures/relics/`

## Run

From the project root:

```shell
python tools/slice_atlases.py
```

The command validates every atlas before writing output, preserves alpha, crops exact `512x512` cells, reports generated files, and assigns them to the existing Godot Resources.
