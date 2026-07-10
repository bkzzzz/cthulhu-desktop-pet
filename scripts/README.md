# Scripts Map

This folder is split by runtime responsibility:

- `main.gd`: desktop scene orchestration, pet/believer spawning, faith economy, offerings, and window clickthrough.
- `side_drawer_controller.gd`: menu handle, side drawer, adder UI, upgrade rows, altar/offering window, and drawer visual effects.
- `desktop_pet_actor.gd`: one desktop pet leader actor, movement, hover hint, recall, petting, and offering travel.
- `believer_actor.gd`: believer spawning, movement, fear response, and exit behavior.
- `pet_catalog.gd`: pet definitions, frame building, icon cropping, and transparent-key processing.
- `inventory_window.gd`: pet storage window, rename/deploy UI, and pet detail panel.
- `shop_window.gd`: shop window, paged goods grid, hover info, and purchase requests.
- `windows_clickthrough_controller.gd`: Windows-specific mouse passthrough helper wrapper.

Keep gameplay state in `main.gd` until a system becomes independently testable. Keep visual-only behavior near the window or actor that owns it.
