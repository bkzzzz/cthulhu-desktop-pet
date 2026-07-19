# Runtime architecture

The runtime layer is organized around a small composition root instead of one monolithic scene script.

- `main.gd` creates the controllers and drives `_ready`, `_process`, notifications, and shutdown.
- `game_state.gd` owns mutable session data. Controllers receive the same state instance.
- `main_context.gd` exposes shared dependencies, tuning constants, and compatibility state properties.
- Each `*_controller.gd` owns one feature boundary and may create the nodes belonging to that feature.
- Cross-feature work goes through the main compatibility API, so controllers do not hold references to one another.
- Pure calculations and trusted catalogs belong in `scripts/domain/`; actor and window animation stays with its owning script.

When a controller approaches roughly 800–1000 lines, split it by a narrower feature boundary rather than growing `main.gd` again. New code should not add gameplay implementations to `main.gd`.
