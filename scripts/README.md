# Scripts Map

This folder is split by runtime responsibility:

- `main.gd`: desktop scene orchestration, pet/believer spawning, faith economy, offerings, and window clickthrough.
- `side_drawer_controller.gd`: menu handle, side drawer, adder UI, upgrade rows, altar/offering window, and drawer visual effects.
- `desktop_pet_actor.gd`: one desktop pet leader actor, movement, hover hint, recall, petting, and offering travel.
- `believer_actor.gd`: believer spawning, movement, fear response, and exit behavior.
- `pet_catalog.gd`: pet definitions, frame building, icon cropping, and transparent-key processing.
- `inventory_window.gd`: pet storage window, rename/deploy UI, and pet detail panel.
- `shop_window.gd`: shop window, paged goods grid, hover info, and purchase requests.
- `domain/pet_progression.gd`: pure faith, favor, discount, and upgrade-cost rules.
- `domain/follower_progression.gd`: pure passive follower growth derived from the current faith growth rate.

Followers grow automatically from faith production and require no separate player management.

The active desktop roster is defined by `pet_catalog.gd`. Character-specific scale and frame-floor values keep different source sheet sizes aligned to the desktop floor.

Run the headless unit tests from the project directory with:

`..\godot.windows.editor.x86_64.exe --headless --path . --script res://tests/run_tests.gd`

Keep runtime state and orchestration in `main.gd`. Move deterministic gameplay rules into `domain/`, and keep visual-only behavior near the window or actor that owns it.
