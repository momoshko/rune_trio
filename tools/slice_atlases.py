#!/usr/bin/env python3
"""Slice fixed-grid RUNE TRIO source atlases and wire generated textures."""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

try:
    from PIL import Image
except ImportError as exc:
    raise SystemExit("Pillow is required: python -m pip install Pillow") from exc


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = PROJECT_ROOT / "assets" / "source_atlases"


@dataclass(frozen=True)
class Sprite:
    name: str
    output: Path
    resource: Path
    property_name: str = "texture"


@dataclass(frozen=True)
class Atlas:
    filename: str
    size: tuple[int, int]
    columns: int
    rows: int
    sprites: tuple[Sprite, ...]

    @property
    def cell_size(self) -> tuple[int, int]:
        return self.size[0] // self.columns, self.size[1] // self.rows


ATLASES = (
    Atlas(
        "rune_tiles_atlas.png", (1536, 1024), 3, 2,
        tuple(
            Sprite(name, Path("assets/textures/tiles") / f"{name}.png", Path("resources/tiles") / f"{name}.tres")
            for name in ("fire", "ice", "lightning", "wind", "life", "shield")
        ),
    ),
    Atlas(
        "enemies_atlas.png", (2048, 1024), 4, 2,
        (
            Sprite("rune_dummy", Path("assets/textures/enemies/rune_dummy.png"), Path("resources/enemies/training_dummy.tres")),
            Sprite("stone_guard", Path("assets/textures/enemies/stone_guard.png"), Path("resources/enemies/stone_guard.tres")),
            Sprite("stone_golem", Path("assets/textures/enemies/stone_golem.png"), Path("resources/enemies/stone_golem.tres")),
            Sprite("frost_beast", Path("assets/textures/enemies/frost_beast.png"), Path("resources/enemies/frost_beast.tres")),
            Sprite("frost_witch", Path("assets/textures/enemies/frost_witch.png"), Path("resources/enemies/frost_witch.tres")),
        ),
    ),
    Atlas(
        "core_relics_atlas.png", (1536, 512), 3, 1,
        (
            Sprite("core", Path("assets/textures/core/core.png"), Path("resources/visuals/visual_library.tres"), "core_texture"),
            Sprite("golem_heart", Path("assets/textures/relics/golem_heart.png"), Path("resources/relics/golem_heart.tres")),
            Sprite("frozen_crown", Path("assets/textures/relics/frozen_crown.png"), Path("resources/relics/frozen_crown.tres")),
        ),
    ),
)


def validate() -> dict[Atlas, Image.Image]:
    opened: dict[Atlas, Image.Image] = {}
    errors: list[str] = []
    for atlas in ATLASES:
        source = SOURCE_DIR / atlas.filename
        if not source.is_file():
            errors.append(f"Missing atlas: {source}")
            continue
        image = Image.open(source)
        if image.size != atlas.size:
            errors.append(f"Wrong dimensions for {source}: got {image.size[0]}x{image.size[1]}, expected {atlas.size[0]}x{atlas.size[1]}")
            image.close()
            continue
        if len(atlas.sprites) > atlas.columns * atlas.rows:
            errors.append(f"Too many sprite mappings for {atlas.filename}")
            image.close()
            continue
        opened[atlas] = image
    if errors:
        for image in opened.values():
            image.close()
        raise SystemExit("Atlas validation failed:\n- " + "\n- ".join(errors))
    return opened


def res_path(path: Path) -> str:
    return "res://" + path.as_posix()


def assign_texture(resource_relative: Path, property_name: str, texture_relative: Path) -> None:
    resource_path = PROJECT_ROOT / resource_relative
    if not resource_path.is_file():
        raise RuntimeError(f"Mapped resource does not exist: {resource_path}")
    text = resource_path.read_text(encoding="utf-8")
    texture_path = res_path(texture_relative)
    existing = re.search(r'^\[ext_resource type="Texture2D" path="' + re.escape(texture_path) + r'" id="([^"]+)"\]$', text, re.MULTILINE)
    if existing:
        ext_id = existing.group(1)
    else:
        ext_id = "atlas_texture"
        stable = re.search(r'^\[ext_resource type="Texture2D" path="[^"]+" id="atlas_texture"\]$', text, re.MULTILINE)
        declaration = f'[ext_resource type="Texture2D" path="{texture_path}" id="{ext_id}"]'
        if stable:
            text = text[:stable.start()] + declaration + text[stable.end():]
        else:
            marker = "\n[resource]"
            if marker not in text:
                raise RuntimeError(f"Invalid Godot resource format: {resource_path}")
            text = text.replace(marker, f"\n{declaration}\n{marker}", 1)
            text = re.sub(
                r'^(\[gd_resource[^\]]*load_steps=)(\d+)',
                lambda match: match.group(1) + str(int(match.group(2)) + 1),
                text,
                count=1,
                flags=re.MULTILINE,
            )
    assignment = f'{property_name} = ExtResource("{ext_id}")'
    pattern = rf'^{re.escape(property_name)}\s*=.*$'
    if re.search(pattern, text, re.MULTILINE):
        text = re.sub(pattern, assignment, text, count=1, flags=re.MULTILINE)
    else:
        text = text.replace("[resource]\n", f"[resource]\n{assignment}\n", 1)
    resource_path.write_text(text, encoding="utf-8", newline="\n")
    print(f"ASSIGNED {resource_relative.as_posix()}:{property_name} -> {texture_path}")


def main() -> int:
    images = validate()
    generated: list[tuple[Sprite, Path]] = []
    try:
        for atlas, image in images.items():
            rgba = image.convert("RGBA")
            cell_width, cell_height = atlas.cell_size
            for index, sprite in enumerate(atlas.sprites):
                column, row = index % atlas.columns, index // atlas.columns
                box = (column * cell_width, row * cell_height, (column + 1) * cell_width, (row + 1) * cell_height)
                output_path = PROJECT_ROOT / sprite.output
                output_path.parent.mkdir(parents=True, exist_ok=True)
                rgba.crop(box).save(output_path, "PNG")
                generated.append((sprite, output_path))
                print(f"GENERATED {output_path} ({cell_width}x{cell_height})")
            rgba.close()
    finally:
        for image in images.values():
            image.close()
    for sprite, _output in generated:
        assign_texture(sprite.resource, sprite.property_name, sprite.output)
    print(f"DONE: generated and assigned {len(generated)} sprites")
    return 0


if __name__ == "__main__":
    sys.exit(main())
