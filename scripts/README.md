# Scripts Map

This folder is split by runtime responsibility:

- `main.gd`: desktop scene orchestration, pet/believer spawning, faith economy, offerings, and window clickthrough.
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

Followers grow automatically from faith production and require no separate player management.
Clicking a pet row in the side drawer buys one level and raises that pet's faith generation; there is no separate population, leader, or evolution layer.
The news feed treats pets as silent sacred sources and reports only the surrounding conversion and loss of reason. Its scope unlocks with follower milestones, progressing from local incidents through regional collapse, biosphere conversion, planetary submission, and cosmic contamination. Faith-rate milestones broadcast immediately; other reports wait for the low-frequency idle-news slot, while the newest 80 remain available from the news bookmark.
Offerings are bought with faith in the shop. A purchased offering replaces the mouse cursor until the player left-clicks the lower desktop to drop it for a pet, or right-clicks to cancel and refund the purchase.

The active desktop roster is defined by `pet_catalog.gd`. Character-specific scale and frame-floor values keep different source sheet sizes aligned to the desktop floor; pet6 keeps its authored foot line on the taskbar edge while its lower hand remains visual and click-through.

Run the headless unit tests from the project directory with:

`.\run_tests.cmd`

The root launcher resolves both the project and the Godot executable from its own
location, so tests and game startup do not depend on the caller's working directory.

Keep runtime state and orchestration in `main.gd`. Move deterministic gameplay rules into `domain/`, and keep visual-only behavior near the window or actor that owns it.
