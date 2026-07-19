# Scripts Map

This folder is split by runtime responsibility:

- `main.gd`: thin composition root. It owns Godot lifecycle callbacks and delegates feature work while preserving the existing scene/test API.
- `runtime/game_state.gd`: the single mutable session-state container shared by runtime controllers.
- `runtime/main_context.gd`: shared dependencies, tuning constants, state accessors, and small deterministic compatibility helpers.
- `runtime/desktop_controller.gd`: desktop window placement, pet spawning, pointer safety, and emotion visuals.
- `runtime/events_controller.gd`: believer spawning, invitations, and pilgrimage flow.
- `runtime/battle_controller.gd`: battle scheduling, formation, combat resolution, and battle effects.
- `runtime/coin_controller.gd`: ambient currency drops, collection, and retention limits.
- `runtime/presentation_controller.gd`: auxiliary windows, HUD synchronization, and news presentation.
- `runtime/persistence_controller.gd`: save/load, migrations, autosave, sanitization, and offline progress.
- `runtime/progression_controller.gd`: economy, pet progression, gacha, evolution, settings, and player commands.
- `runtime/offering_controller.gd`: offering cursor input, placement, feeding, buffs, and feedback popups.
- `runtime/campaign_controller.gd`: Lv.100 campaign cap, completion flow, endless-mode transition, and shared economy projections.
- `side_drawer_controller.gd`: compact menu handle, side drawer, adder UI, upgrade rows, editable pet details, and drawer visual effects.
- `desktop_pet_actor.gd`: data-driven walking, sleeping, hiding/ambushing, flight, optional wall crawling, hover, recall, petting, and offering travel.
- `believer_actor.gd`: believer spawning, movement, fear response, and exit behavior.
- `pet_catalog.gd`: pet movement ranges, personality emotion weights, frame building, and icon processing.
- `inventory_window.gd`: pet storage window, rename/deploy UI, and pet detail panel.
- `shop_window.gd`: shop window, paged durable goods and consumable offerings, hover info, and purchase requests.
- `news_window.gd`: persistent cult-news archive opened from the side-drawer bookmark.
- `domain/pet_progression.gd`: pure pet-level faith output and safe upgrade-cost rules.
- `domain/follower_progression.gd`: pure passive follower growth derived from the current faith growth rate.
- `domain/news_feed.gd`: deterministic absurd, propagation, faith, and pet-event news rules plus save sanitization.
- `domain/offering_catalog.gd`: trusted shop-offering definitions and carried-item normalization.
- `domain/economy_balance.gd`: shared campaign target, potential coin income, dynamic shop pricing, and completion predicates.
- `domain/battle_balance.gd`: adaptive wave size, enemy strength, and rate-aware battle reward budgets.
- `domain/language_settings.gd`: the English-default locale policy plus the shared English and CJK font selection.
- `domain/display_layout.gd`: DPI-aware Windows work-area fitting, design-space scaling, centering, and drag clamping.

Followers grow automatically from faith production and require no separate player management.
Clicking a pet row in the side drawer buys one level and raises that pet's faith generation; there is no separate population, leader, or evolution layer.
The Lv.100 campaign now opens with a natural upgrade in under 10 seconds, reaches the full roster within a few minutes, and is calibrated to roughly 85 hours of optimized passive production or about 50 hours with sustained petting, battles, and offerings. Early battles use short 2-3 enemy waves, while rewards are rate-aware and never fall below 75 current Adder clicks. Endless upgrades use a rate-linked payback curve so late levels keep growing without collapsing into instant purchases.
The news feed treats pets as silent sacred sources and reports only the surrounding conversion and loss of reason. Its scope unlocks with follower milestones, progressing from local incidents through regional collapse, biosphere conversion, planetary submission, and cosmic contamination. Faith-rate milestones broadcast immediately; other reports wait for the low-frequency idle-news slot, while the newest 80 remain available from the news bookmark.
Offerings are bought with gold at prices derived from the unlocked roster's potential coin production. A purchased offering replaces the mouse cursor until the player left-clicks the lower desktop to drop it for a pet, or right-clicks to cancel and refund the purchase.

Fresh games default to English. Authored pet names and UI copy follow the selected language while explicit player renames remain unchanged. Locked pets keep their real slot but expose only a dark silhouette and question marks until unlocked.

The root desktop window follows the active monitor's usable Windows work area and reflows when its resolution, DPI, taskbar, or monitor changes. Auxiliary windows keep their authored design coordinate space but scale their native window to fit the current work area. `project.godot` has no fixed physical window-size override.

The active desktop roster is defined by `pet_catalog.gd`. Character-specific scale and frame-floor values keep different source sheet sizes aligned to the desktop floor; pet6 keeps its authored foot line on the taskbar edge while its lower hand remains visual and click-through. Pet7 reuses its idle sheet while code-driven clockwise/counterclockwise rotation rolls the coin in its travel direction on a slightly lowered contact line.

Run the headless unit tests from the project directory with:

`.\run_tests.cmd`

The root launcher resolves both the project and the Godot executable from its own
location, so tests and game startup do not depend on the caller's working directory.

Keep `main.gd` limited to lifecycle orchestration and compatibility delegation. Put mutable session data in `runtime/game_state.gd`, feature coordination in the matching `runtime/*_controller.gd`, deterministic gameplay rules in `domain/`, and visual-only behavior near the window or actor that owns it.
