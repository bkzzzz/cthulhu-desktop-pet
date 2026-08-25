# Runtime Architecture

The runtime uses a small composition root instead of a monolithic scene script.

- `main.gd` creates controllers and owns Godot lifecycle callbacks.
- `runtime_cadence.gd` staggers progression, world, and maintenance work while preserving each group's 10 Hz simulation rate.
- `game_state.gd` owns mutable session data shared by every controller.
- `main_context.gd` exposes common dependencies, constants, and compatibility properties.
- Each `*_controller.gd` owns one feature boundary and creates only the nodes belonging to that feature.
- Cross-feature operations use the main compatibility API; controllers do not reference one another directly.
- Deterministic calculations and trusted catalogs belong in `scripts/domain/`.
- Actor and window animation remains in the script that owns the visual node.

Runtime performance and lifecycle safety follow these ownership rules:

- Hidden secondary windows are created on first use; large drawers materialize their chrome, content, and rows across the slide-in frames.
- Resting actors disable their own `_process`; their owning controller performs any low-frequency lifecycle tick.
- Native window geometry is written only when cached target geometry changes.
- Repeated decorative particles are drawn in one batched CanvasItem instead of one node per particle.
- Pixel-derived animation, icons, and combat geometry are generated offline under `assets/generated/`, never rebuilt on a gameplay frame.
- State containers that hold Godot Objects must read a `Variant`, call `is_instance_valid()`, verify its type, and only then use `as NodeType`; casting a freed Object before validation is an engine error.
- Feature-owned transient nodes register an exit callback that removes them from their state container. Periodic reverse-order cleanup remains a fallback and never grants gameplay rewards.

Split a controller when it approaches roughly 800-1,000 lines or begins to cover more than one feature boundary. Do not add gameplay implementations to `main.gd`.
