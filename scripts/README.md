# Script Map

## Runtime composition

- `main.gd`: lifecycle orchestration and compatibility delegation
- `runtime/game_state.gd`: mutable session state shared by controllers
- `runtime/main_context.gd`: shared dependencies, constants, and state accessors
- `runtime/runtime_cadence.gd`: deterministic, frame-staggered dispatch for 10 Hz runtime groups
- `runtime/desktop_controller.gd`: desktop bounds, pet spawning, pointer safety, and emotion effects
- `runtime/events_controller.gd`: believers, invitations, and pilgrimage events
- `runtime/battle_controller.gd`: two-sided waves, combat, health UI, rewards, and battle effects
- `runtime/coin_controller.gd`: ambient currency drops and collection
- `runtime/presentation_controller.gd`: windows, HUD synchronization, and news presentation
- `runtime/persistence_controller.gd`: game-state serialization, sanitization, autosave, offline progress, and safe slot-switch coordination
- `runtime/save_slot_repository.gd`: controlled slot IDs, registry/backup I/O, legacy-save migration, and exact-path reset/delete operations
- `runtime/progression_controller.gd`: faith, growth-based pet unlocks, achievements, evolution, settings, and player commands
- `runtime/offering_controller.gd`: offering purchase, cursor placement, feeding, and buffs
- `runtime/campaign_controller.gd`: final-boss gating, campaign completion, level caps, and Endless Mode

## Actors and interface

- `desktop_pet_actor.gd`: data-driven pet movement, interaction, animation, and combat behavior
- `believer_actor.gd`: believer movement, fear, and exit behavior
- `enemy_actor.gd`: enemy movement, attacks, damage, and defeat behavior
- `combat_health_bar.gd`: animated pet, enemy, and boss health-bar visuals
- `pet_catalog.gd`: pet definitions, localization metadata, and versioned offline frame/icon caches
- `side_drawer_controller.gd`: lazy, frame-staged menu composition, progression rows, and pet details
- `drawer_symbol_flow.gd`: one batched draw node for the drawer's decorative symbol field
- `inventory_window.gd`: storage, deployment, renaming, and pet details
- `shop_window.gd`: paged goods, offerings, and purchases
- `achievement_window.gd`: achievement progress, rewards, and claim controls
- `news_window.gd`: persistent cult-news history

## Domain rules

- `domain/pet_progression.gd`: pet output and upgrade costs
- `domain/pet_unlock_progression.gd`: permanent growth-rate gates for roster unlocks
- `domain/achievement_progression.gd`: achievement definitions, progress checks, and reward data
- `domain/economy_balance.gd`: campaign targets, potential income, pricing, and completion checks
- `domain/battle_balance.gd`: wave density, adaptive enemy strength, and reward budgets
- `domain/currency_display.gd`: exact gold-to-crystal display denominations and overflow-safe balance helpers
- `domain/follower_progression.gd`: passive follower growth
- `domain/offering_catalog.gd`: trusted offering definitions
- `domain/news_feed.gd`: deterministic news generation and save sanitization
- `domain/language_settings.gd`: locale and font policy
- `domain/display_layout.gd`: DPI-aware work-area and auxiliary-window geometry

Keep `main.gd` limited to lifecycle work and delegation. Put mutable data in `runtime/game_state.gd`, feature coordination in the matching runtime controller, deterministic rules in `domain/`, and visual behavior beside the actor or window that owns it.

Run all tests from the repository root with `./run_tests.cmd`.

Regenerate versioned pet frames, cropped pet icons, believer frames, and enemy runtime caches after changing their source art or pixel-derived geometry:

```powershell
..\godot.windows.editor.x86_64.exe --headless --path . --script res://tools/generate_runtime_caches.gd
```

Run the repeatable cold-resource and scene profiles with:

```powershell
..\godot.windows.editor.x86_64.exe --headless --path . --script res://tests/profile_runtime_costs.gd
..\godot.windows.editor.x86_64.exe --headless --path . --script res://tests/profile_scene_runtime.gd
..\godot.windows.editor.x86_64.exe --headless --path . --script res://tests/profile_scene_runtime.gd -- --open-drawer
```

Increment the matching cache version constant whenever a generator algorithm changes, then commit the regenerated assets with that code change.
