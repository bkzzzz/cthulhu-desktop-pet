# Cthulhu Pet

Cthulhu Pet is a Godot 4 desktop idle game for Windows. Pets live above the taskbar, generate faith and gold, react to the pointer, accept offerings, and fight era-based enemy waves.

## Requirements

- Windows 10 or 11
- Godot 4.x
- The Godot editor executable in the parent directory of this repository

## Run and test

From the repository root:

```powershell
# Run the game
.\run_game.cmd

# Open the project in the editor
.\run_game.cmd -Editor

# Run all headless tests
.\run_tests.cmd
```

The launch scripts resolve the project directory and Godot executable from their own locations, so they work from any current directory. VS Code tasks named `Godot: Run Game` and `Godot: Run Tests` provide the same workflows.

## Project layout

- `scenes/`: Godot scenes
- `scripts/`: gameplay, UI, runtime controllers, and pure domain rules
- `assets/`: character, interface, audio, and effect assets
- `tests/`: headless regression tests and visual QA harnesses
- `builds/windows/`: Windows export output

The main scene is `res://scenes/Main.tscn`. Runtime features are split into focused controllers under `scripts/runtime/`, while deterministic progression and balance rules live under `scripts/domain/`.

The desktop layer follows the active monitor's usable Windows work area and responds to resolution, DPI, monitor, and taskbar changes. English is the default language; Chinese can be selected in Settings.

## Windows export

The repository includes a Windows export preset. Replace or update project assets as needed, export the executable into `builds/windows/`, and use that output for distribution.
