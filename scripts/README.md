# Scripts Map

This folder is split by runtime responsibility:

- `main.gd`: desktop scene orchestration, pet/believer spawning, faith economy, offerings, and window clickthrough.
- `side_drawer_controller.gd`: menu handle, side drawer, adder UI, upgrade rows, altar/offering window, and drawer visual effects.
- `desktop_pet_actor.gd`: data-driven movement, multi-height flight, wall crawling, hover, recall, petting, and offering travel.
- `believer_actor.gd`: believer spawning, movement, fear response, and exit behavior.
- `pet_catalog.gd`: pet movement ranges, personality emotion weights, evolution milestones, frame building, and icon processing.
- `inventory_window.gd`: pet storage window, rename/deploy UI, and pet detail panel.
- `shop_window.gd`: shop window, paged goods grid, hover info, and purchase requests.
- `domain/pet_progression.gd`: pure faith, batch population growth, safe upgrade costs, and two-stage evolution rules.
- `domain/follower_progression.gd`: pure passive follower growth derived from the current faith growth rate.

Followers grow automatically from faith production and require no separate player management.
The altar presents one persistent two-item decision: taking either offering spoils
the other, and the next pair appears after the chosen offering is placed.

The active desktop roster is defined by `pet_catalog.gd`. Character-specific scale and frame-floor values keep different source sheet sizes aligned to the desktop floor.

Run the headless unit tests from the project directory with:

`.\run_tests.cmd`

The root launcher resolves both the project and the Godot executable from its own
location, so tests and game startup do not depend on the caller's working directory.

Keep runtime state and orchestration in `main.gd`. Move deterministic gameplay rules into `domain/`, and keep visual-only behavior near the window or actor that owns it.
