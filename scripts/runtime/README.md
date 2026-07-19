# Runtime Architecture

The runtime uses a small composition root instead of a monolithic scene script.

- `main.gd` creates controllers and owns Godot lifecycle callbacks.
- `game_state.gd` owns mutable session data shared by every controller.
- `main_context.gd` exposes common dependencies, constants, and compatibility properties.
- Each `*_controller.gd` owns one feature boundary and creates only the nodes belonging to that feature.
- Cross-feature operations use the main compatibility API; controllers do not reference one another directly.
- Deterministic calculations and trusted catalogs belong in `scripts/domain/`.
- Actor and window animation remains in the script that owns the visual node.

Split a controller when it approaches roughly 800-1,000 lines or begins to cover more than one feature boundary. Do not add gameplay implementations to `main.gd`.
