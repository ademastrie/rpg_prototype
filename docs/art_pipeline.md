# Placeholder 3D Art Pipeline

This project uses lightweight visual-only scenes so prototype meshes can be replaced by generated or purchased models without rewriting gameplay code.

## Folder Structure

- `godot/assets/materials/`: shared placeholder and production materials.
- `godot/assets/models/characters/`: imported player and NPC character models.
- `godot/assets/models/enemies/`: imported enemy models.
- `godot/assets/models/projectiles/`: imported projectile models.
- `godot/assets/models/loot/`: imported loot and pickup models.
- `godot/assets/models/environment/`: imported terrain, prop, and environment models.
- `godot/scenes/visuals/characters/`: visual-only character scenes.
- `godot/scenes/visuals/enemies/`: visual-only enemy scenes.
- `godot/scenes/visuals/projectiles/`: visual-only projectile scenes.
- `godot/scenes/visuals/loot/`: visual-only loot scenes.
- `godot/scenes/visuals/environment/`: visual-only environment scenes.

## Naming Conventions

- Visual scenes use a category and variant: `PlayerVisual_<Variant>.tscn`, `EnemyVisual_<Variant>.tscn`, `ProjectileVisual_<Variant>.tscn`, `LootVisual_<Variant>.tscn`.
- Imported models should match the visual variant where practical, such as `Enemy_Grunt.glb` for `EnemyVisual_Grunt.tscn`.
- Materials use `mat_<category>_<variant>.tres`, such as `mat_projectile_fireball.tres`.
- Keep names descriptive and stable once a gameplay scene references the visual scene.

## Import Format

Prefer `.glb` for imported 3D models. It keeps mesh, material, skeleton, and animation data bundled in a compact format that Godot imports cleanly.

Use these conventions before import when possible:
- `1 Godot unit = 1 meter`.
- Godot world space is Y-up.
- Forward direction should be consistent per asset category.
- Apply transforms in the modeling tool so imported scale and rotation are clean.

## Origins And Orientation

Characters:
- Place feet at the origin.
- Use a stable upright pose.
- Keep the character centered around the vertical axis.

Projectiles:
- Center the projectile on the origin.
- Point the projectile forward.
- Keep length and pivot predictable so gameplay can rotate or move the parent node without visual offsets.

Loot:
- Center loot slightly above ground.
- Avoid origins far from the visible item.
- Keep the model small enough to fit inside the pickup presentation expected by the gameplay scene.

Environment:
- Use world-friendly pivots, such as the bottom center for props or a corner/origin grid point for modular pieces.
- Keep collision out of art-only scenes unless the gameplay scene explicitly owns and references that collision.

## Visual-Only Scene Pattern

Every visual scene should have a clear `Node3D` root. The root can contain render-only nodes such as `MeshInstance3D`, `Skeleton3D`, `AnimationPlayer`, particles, lights, and debug labels when they match the current debug style.

Gameplay collision and gameplay state should not live inside art-only scenes. That includes combat state, HP, cooldowns, inventory, respawn behavior, persistence, networking nodes, RPC paths, and server-authoritative simulation logic.

Gameplay scenes should instance or reference visual scenes instead of embedding final meshes directly. This keeps art replacement local to the visual scene.

## Replacing A Placeholder Visual

1. Add the imported `.glb` to the matching `godot/assets/models/...` folder.
2. Open the matching scene under `godot/scenes/visuals/...`.
3. Remove or hide the primitive placeholder mesh nodes.
4. Instance the imported model under the existing `Node3D` root.
5. Adjust only visual transform, scale, materials, animation hookup, and render-only child nodes.
6. Keep the visual scene path stable if gameplay already references it.
7. Confirm the model follows the origin, scale, and Y-up conventions above.

Do not modify networking or gameplay scripts for art swaps unless the swap requires a real gameplay-facing reference change. If a script must change, keep that change focused on the scene reference and avoid changing abilities, enemies, stats, inventory, combat, persistence, or server authority.
