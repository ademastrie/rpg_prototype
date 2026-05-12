# Godot Assets

Generated, purchased, or imported art assets should live under `godot/assets/`. The visual scenes under `godot/scenes/visuals/` are replaceable shells that gameplay scenes can instance without taking ownership of art-specific mesh details.

## Folder Structure

- `godot/assets/materials/`: shared placeholder and production materials.
- `godot/assets/models/characters/`: imported player and NPC character model files.
- `godot/assets/models/enemies/`: imported enemy model files.
- `godot/assets/models/projectiles/`: imported projectile model files.
- `godot/assets/models/loot/`: imported loot and pickup model files.
- `godot/assets/models/environment/`: imported terrain, prop, and environment model files.
- `godot/scenes/visuals/characters/`: character visual-only scenes.
- `godot/scenes/visuals/enemies/`: enemy visual-only scenes.
- `godot/scenes/visuals/projectiles/`: projectile visual-only scenes.
- `godot/scenes/visuals/loot/`: loot visual-only scenes.
- `godot/scenes/visuals/environment/`: environment visual-only scenes.

## Naming

- Visual scenes: `PlayerVisual_<Variant>.tscn`, `EnemyVisual_<Variant>.tscn`, `ProjectileVisual_<Variant>.tscn`, `LootVisual_<Variant>.tscn`.
- Imported models: use the same variant name when possible, for example `Enemy_Grunt.glb` used by `EnemyVisual_Grunt.tscn`.
- Materials: `mat_<category>_<variant>.tres`, for example `mat_enemy_grunt.tres`.
- Keep variant names stable once gameplay scenes reference them.

## Import And Scale

- Prefer `.glb` for imported 3D models.
- Use `1 Godot unit = 1 meter`.
- Use the Godot Y-up world convention.
- Characters should stand with their feet at the origin.
- Projectiles should be centered on the origin and point forward.
- Loot should be centered slightly above ground so it can be displayed without clipping into the floor.

## Visual-Only Scene Pattern

- Visual scene roots should be `Node3D`.
- Visual scenes can contain meshes, skeletons, animation players, lights, particles, and labels when consistent with debug style.
- Gameplay collision, combat, inventory, HP, cooldown, respawn, networking, persistence state, and RPC behavior should not live inside art-only scenes.
- Gameplay scenes should reference visual scenes instead of embedding final meshes directly.
- Do not modify networking or gameplay scripts for art swaps unless a real gameplay-facing reference must change.

## Replacing A Placeholder

1. Put the imported `.glb` under the matching `godot/assets/models/...` folder.
2. Open or update the matching visual scene under `godot/scenes/visuals/...`.
3. Replace the primitive `MeshInstance3D` placeholders with the imported model instance.
4. Keep the same visual scene file path and root `Node3D` when possible.
5. Preserve the expected origin, scale, and forward direction.
6. Leave gameplay collision and server/client state in the gameplay scene or script layer.

See `docs/art_pipeline.md` for the longer pipeline notes.
