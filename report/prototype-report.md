# Crowd Sniper — Playable Prototype Report

**Date:** 2026-08-07 · **Commit:** `3b0e3f2` · **Engine:** Godot 4.7.1 stable

## 1. What was built

The complete core loop: **SHOW TARGET → FIND IN CROWD → AIM → SHOOT → HIT/MISS → WIN/FAIL**, endless procedural levels, 3-bullet ammo economy, fail/retry, slow-motion kill cam, and a dev debug panel — all placeholder-art, data-driven, and verified running through Godot MCP.

## 2. Architecture

```
Game (game.tscn)
├── GameManager      state machine only: INTRO → SEARCHING → RESOLVING
├── Backdrop         plaza environment, one draw call
├── Camera2D         punch/recoil effects
├── CrowdManager     spawns crowd, single movement loop, hit queries
│   └── CrowdCharacter ×N   _draw()-rendered from DNA, no physics
├── AimController    touch press/drag/release → shot_fired signal
│   ├── ScopeVignette
│   └── Crosshair
├── TargetManager    wanted-poster intro → shrink-to-card tween
├── HUD              level, ammo pips, feedback messages
├── DebugPanel       stats + restart/next/regen buttons (DBG toggle)
└── [autoload] Analytics   in-memory structured event log

Pure logic (no nodes): CharacterDNA · LevelConfig · LevelGenerator
```

Responsibilities are strictly separated: GameManager never generates, the generator never touches nodes, characters never process input.

## 3. Files created

| File | Role |
|---|---|
| `scenes/game/game.tscn` | Main scene (skeleton built via MCP `create_scene`/`add_node`) |
| `scripts/core/character_dna.gd` | Trait data model + palettes |
| `scripts/core/level_config.gd` | Difficulty parameters + `for_level(n)` math |
| `scripts/core/level_generator.gd` | Crowd composition + placement |
| `scripts/gameplay/game_manager.gd` | State machine, ammo, win/fail |
| `scripts/gameplay/crowd_manager.gd` | Crowd lifecycle, movement, hit query |
| `scripts/gameplay/crowd_character.gd` | Procedural character rendering |
| `scripts/gameplay/aim_controller.gd` | Sniper input |
| `scripts/gameplay/crosshair.gd`, `scope_vignette.gd` | Reticle + scope mood |
| `scripts/gameplay/target_manager.gd` | Target intro / portrait card |
| `scripts/gameplay/bullet_hole.gd`, `backdrop.gd` | Impact FX, environment |
| `scripts/ui/hud.gd`, `debug_panel.gd` | HUD, dev panel |
| `autoload/analytics.gd` | Event recording stub |
| `scripts/dev/autotest.gd` | Env-gated scripted playthrough |

## 4. Procedural characters

`CharacterDNA` holds 9 traits (hair style/color, skin tone, shirt style/color, pants color, glasses, hat, accessory) as structured data — serializable via `to_dict()`, e.g. `{"hair_color":"black","shirt_style":"jacket","shirt_color":"blue","glasses":true,...}`. Characters render themselves in `CrowdCharacter._draw()` from DNA: rects/circles/polygons only, zero textures, readable at phone size. No character is handcrafted anywhere.

## 5. Mathematical difficulty

`LevelConfig` is pure data: `crowd_count, target_trait_count, similarity, decoy_count, decoy_diff_traits, movement_speed, character_scale, spacing, ammo, time_limit, target_memory_time`. `LevelConfig.for_level(n)` provides tuned presets for levels 1–5 (easy → dense with 3 decoys) and a smooth curve beyond (e.g. L10: crowd 21, sim 0.47, 3 decoys, movement 16; L25: crowd 40, sim 0.72, 6 decoys, movement 46, scale 0.75). An analytics-driven tuner can later reshape difficulty by changing only these numbers.

The generator enforces the identity guarantee: **exactly one** crowd member matches the target on all active traits — decoys are clones differing in exactly `decoy_diff_traits` traits; fillers copy each target trait with probability `similarity`, re-rolled if they'd be an exact match.

## 6. Aiming & shooting

Press-and-hold raises the scope (vignette + crosshair offset 170 px above the finger so the hand never hides it), dragging moves the aim with exponential smoothing plus a subtle breathing sway, releasing fires at the crosshair (not the finger). Shot resolution is a rect test at the reticle: target → slow-mo (time_scale 0.18), dim crowd, flash, camera punch, "TARGET HIT", next level; decoy/innocent → "WRONG TARGET", −1 bullet; empty → "MISS", −1 bullet; 0 bullets → "TARGET ESCAPED", fresh retry of the same level. Every shot leaves a fading bullet hole, flashes the screen, and makes nearby crowd members flinch.

## 7. Performance

- Characters: one cached canvas item each, redrawn only on flash — idle cost ≈ 0
- One `_process` loop total for crowd movement (disabled when the level is static); no physics bodies, no per-character scripts running
- Hit detection = N rect tests per shot, not per frame; no shaders, no particles
- Measured via MCP FPS probe: **165 FPS (display-capped) with 40 moving characters**, zero errors — ample headroom for 50–100 characters on low-end Android

## 8. MCP tests performed

All through the godot-mcp server (`create_scene`, `add_node`, `run_project`, `get_debug_output`, `stop_project`):

1. Scene skeleton (17 nodes) built via MCP
2. First run: booted clean; 3 GDScript warnings found in debug output → fixed → re-run clean
3. Scripted playthrough (`CROWD_SNIPER_AUTOTEST=1`) — **20/20 checks passed**: intro→searching transition, exactly-one-target guarantee, crowd size, correct-hit → next level, empty shot ammo, wrong-target ammo, no level end on wrong shot, fail at 0 ammo, same-level retry with refilled ammo and fresh crowd, retry → win → level 3, config validity at L10/L20, all analytics events (`level_start/complete/fail`, `shot`, `wrong_shot`, `empty_shot`, `target_found` with `search_time_ms`, `shots_used`)
4. Dense-level probe (L25, 40 moving characters): 165 FPS, no errors

One earlier autotest "failure" was traced via the analytics stream to a human playing the live game window during the test run (gameplay continued after the test finished) — reproduced clean 20/20 on re-run.

## 9. Remaining issues / notes

- Crowd flinch reaction is overridden by the wander loop on moving-crowd levels (≥6) — cosmetic only
- `time_limit` is in the data model but not yet enforced (reserved)
- Characters can still overlap slightly at extreme density; fine at current sizes
- No audio yet; feedback is purely visual
- Mobile export templates not installed (needed only for device builds)

## 10. How to run

```
godot --path D:\Projects\SA\Crowd-Sniper
```
(or open the project in the Godot editor and press F5)

Dev shortcuts (set env vars before launching):
- `CROWD_SNIPER_START_LEVEL=12` — boot into any level
- `CROWD_SNIPER_AUTOTEST=1` — scripted verification playthrough
- `CROWD_SNIPER_FPS_PROBE=1` — print FPS every 2 s
- In-game **DBG** button (bottom-right) — stats + Restart / Next / Regen
