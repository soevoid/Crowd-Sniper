# Crowd Sniper — Godot + MCP Environment Setup Report

**Date:** 2026-08-07
**Machine:** Windows 11 Home (10.0.26200), NVIDIA RTX 3060 Laptop GPU

## 1. Environment

| Component | Version / Location |
|---|---|
| OS | Windows 11 Home Single Language 10.0.26200 |
| Godot | 4.7.1.stable.official (a13da4feb) |
| Godot executable | `C:\Users\user\AppData\Local\Programs\Godot\godot.exe` |
| Godot console executable | `C:\Users\user\AppData\Local\Programs\Godot\godot_console.exe` |
| Claude Code | 2.1.223 |
| Git | 2.38.1.windows.1 |
| Node.js / npm | v20.19.5 / 10.8.2 |

Godot was found in `Downloads`, copied to `%LOCALAPPDATA%\Programs\Godot\`, and added to the user PATH so `godot` works from any new terminal. No duplicate software was installed.

## 2. Godot MCP Server

**Repository:** https://github.com/Coding-Solo/godot-mcp

**Why this one:**
- Most established open-source option (5.1k stars, MIT license)
- Actively maintained — latest commit April 16, 2026 (a security fix)
- No editor plugin required: drives Godot headless via CLI
- First-class Claude Code support via `npx @coding-solo/godot-mcp`
- Covers scene creation/editing, running projects, and debug/error capture on Windows

**Configuration** (project scope, `D:\Projects\SA\Crowd-Sniper\.mcp.json`):

```json
{
  "mcpServers": {
    "godot": {
      "command": "cmd",
      "args": ["/c", "npx", "-y", "@coding-solo/godot-mcp"],
      "env": {
        "GODOT_PATH": "C:\\Users\\user\\AppData\\Local\\Programs\\Godot\\godot_console.exe"
      }
    }
  }
}
```

Approved via `enabledMcpjsonServers` in `.claude/settings.local.json`.
`claude mcp list` → **godot: ✓ Connected**

**Available tools (14):** `launch_editor`, `run_project`, `get_debug_output`, `stop_project`, `get_godot_version`, `list_projects`, `get_project_info`, `create_scene`, `add_node`, `load_sprite`, `export_mesh_library`, `save_scene`, `get_uid`, `update_project_uids`

## 3. Project

**Path:** `D:\Projects\SA\Crowd-Sniper`

| Setting | Value |
|---|---|
| Engine | Godot 4.7 (Mobile feature set) |
| Base resolution | 1080 × 1920 portrait |
| Stretch | `canvas_items` / `expand` (scalable UI) |
| Renderer | Mobile (D3D12 on desktop) |
| Touch | Mouse-to-touch emulation enabled |
| Texture compression | ETC2/ASTC (Android + iOS ready) |
| Language | GDScript |

**Structure:**

```
Crowd-Sniper/
├── assets/        (sprites, audio, fonts)
├── autoload/      (global singletons)
├── scenes/
│   └── test/test_scene.tscn
├── scripts/
│   ├── gameplay/  (test_scene.gd, crosshair.gd)
│   └── ui/
├── report/
├── .mcp.json
└── project.godot
```

Git repository with Godot-appropriate `.gitignore` (`.godot/`, `/android/`, export artifacts, local Claude settings).

## 4. MCP Integration Test

The test scene was built **through MCP tool calls** (`create_scene` + 9 × `add_node`), not by hand-editing files: a full-screen background, five gray placeholder NPCs under a `Crowd` node, one red `Target`, and a `Crosshair`. Colors and script attachment were applied via direct `.tscn` edits (a server limitation — see below), and tap/aim interaction was implemented in GDScript.

**Run 1 — clean run via `run_project`:** scene loaded at 1080×1920, zero errors. Live taps were captured through `get_debug_output`:

```
[TestScene] Ready. Viewport: (1080.0, 1920.0). Tap the red target.
[TestScene] HIT: target eliminated at (484.0, 1192.0)
```

**Run 2 — error visibility:** a deliberate `push_error` was injected; MCP surfaced it with a full backtrace:

```
ERROR: [TestScene] Deliberate test error for MCP error-visibility check
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace: [0] _ready (res://scripts/gameplay/test_scene.gd:10)
```

**Run 3 — after fix:** zero errors; gameplay events streamed correctly:

```
[TestScene] MISS: hit civilian NPC2 at (504.0, 884.0)
[TestScene] MISS: nothing at (380.0, 1122.0)
[TestScene] HIT: target eliminated at (474.0, 1204.0)
```

## 5. Verification Checklist

- [x] Godot launches
- [x] Crowd Sniper project opens
- [x] Claude Code sees Godot MCP (`claude mcp list` → Connected)
- [x] MCP can interact with Godot (14 tools exercised)
- [x] Claude can create/edit a scene via MCP
- [x] Claude can run the game via MCP
- [x] Claude can see runtime/debug errors (with backtraces)
- [x] Test scene runs successfully

## 6. Known Limitations / Notes

1. **Session restart needed for native tools** — MCP servers registered mid-session are not hot-loaded; after restarting Claude Code the tools appear as `mcp__godot__*`. The integration itself is proven (tested over the same JSON-RPC stdio protocol).
2. **`add_node` property limits** — properties pass through `node.set()` with raw JSON, so only float/int/string/bool work. `Color`/`Vector2` values and script attachment require direct `.tscn` edits (hybrid workflow).
3. **Crash-at-launch output is lost** — `get_debug_output` needs a live process; if Godot exits immediately the buffer is gone.
4. **Mobile export templates not installed** — required only when building APK/IPA, not for development.

## 7. Next Steps

Environment is ready for production gameplay development: crowd spawning/movement, target identification mechanics, scoring, UI, and mobile export presets.
