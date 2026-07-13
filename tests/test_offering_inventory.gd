extends RefCounted

const SideDrawer = preload("res://scripts/side_drawer_controller.gd")
const Main = preload("res://scripts/main.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var seen_ids := {}
	for item_value in SideDrawer.OFFERING_ITEMS:
		var item: Dictionary = item_value
		var offering_id := String(item.get("id", ""))
		if offering_id.is_empty() or seen_ids.has(offering_id):
			failures.append("every offering type must have a unique stable id")
		seen_ids[offering_id] = true
		var texture_path := String(item.get("texture", ""))
		if texture_path.is_empty() or not FileAccess.file_exists(texture_path):
			failures.append("%s must provide a valid texture" % offering_id)
		if int(item.get("faith_min", 0)) <= 0 or int(item.get("faith_max", 0)) < int(item.get("faith_min", 0)):
			failures.append("%s must provide a valid faith range" % offering_id)
		if item.has("favor_gain"):
			failures.append("%s must not contain the removed affection reward" % offering_id)
	if seen_ids.size() < 10:
		failures.append("the altar must offer at least ten different offering types")
	var legacy_offering := SideDrawer.normalize_offering_entry({
		"id": "red_fruit",
		"faith": 3,
		"favor_gain": 999,
		"stock_id": "legacy"
	})
	if legacy_offering.has("favor_gain"):
		failures.append("legacy saved offerings must discard removed affection data")

	var drawer := SideDrawer.new()
	var stock: Array[Dictionary] = drawer.get("_offering_entries")
	var drawer_rng := drawer.get("_rng") as RandomNumberGenerator
	drawer_rng.seed = 424242
	if not bool(drawer.call("_generate_offering_choice")) or stock.size() != SideDrawer.OFFERING_CHOICE_COUNT:
		failures.append("the altar must generate exactly two choices per round")
	var first: Dictionary = stock[0].duplicate(true)
	var second: Dictionary = stock[1].duplicate(true)
	if String(first.get("id", "")) == String(second.get("id", "")):
		failures.append("the two offering choices must be different types")
	if String(first.get("stock_id", "")) == String(second.get("stock_id", "")):
		failures.append("the two offering choices must have different stock ids")
	if not bool(drawer.call("_remove_offering_entry", first)) or not stock.is_empty():
		failures.append("selecting one offering must immediately spoil the other choice")
	if not drawer.complete_offering_choice() or stock.size() != SideDrawer.OFFERING_CHOICE_COUNT:
		failures.append("finishing a selected offering must begin the next two-choice round")
	var next_round := stock.duplicate(true)
	if drawer.complete_offering_choice() or stock != next_round:
		failures.append("completing an already active choice round must be idempotent")

	stock.clear()
	stock.append(first.duplicate(true))
	stock.append(second.duplicate(true))
	drawer.call("_remove_offering_entry", first)
	if not drawer.return_offering(first) or stock.size() != SideDrawer.OFFERING_CHOICE_COUNT:
		failures.append("cancelling must return the selected item and create one new alternative")
	if not drawer.return_offering(first) or stock.size() != SideDrawer.OFFERING_CHOICE_COUNT:
		failures.append("returning the same selected offering must be idempotent")
	var returned_count := 0
	for entry in stock:
		if String(entry.get("stock_id", "")) == String(first.get("stock_id", "")):
			returned_count += 1
	if returned_count != 1:
		failures.append("the returned offering must appear exactly once")

	var saved_state := drawer.get_offering_state()
	var restored_drawer := SideDrawer.new()
	restored_drawer.restore_offering_state(
		saved_state.get("choices", []),
		int(saved_state.get("next_stock_id", 1)),
		false
	)
	var restored_stock: Array[Dictionary] = restored_drawer.get("_offering_entries")
	if restored_stock.size() != SideDrawer.OFFERING_CHOICE_COUNT:
		failures.append("saved offering choices must restore without rerolling the round")
	restored_drawer.restore_offering_state(saved_state.get("choices", []), 1, true)
	if not restored_stock.is_empty():
		failures.append("a saved carried offering must keep the altar locked")
	restored_drawer.free()

	stock.clear()
	var main := Main.new()
	main.set("_persistence_enabled", false)
	main.set("_side_drawer", drawer)
	main.call("_on_offering_drop_requested", first)
	main.call("_on_offering_drop_requested", first)
	var carried: Dictionary = main.get("_carried_offering")
	if String(carried.get("stock_id", "")) != String(first.get("stock_id", "")) or not stock.is_empty():
		failures.append("duplicate selection callbacks must not copy a carried offering back to the altar")
	main.call("_cancel_carried_offering")
	if stock.size() != SideDrawer.OFFERING_CHOICE_COUNT:
		failures.append("right-click cancellation must restore a two-item decision")
	main.free()
	drawer.free()
	return failures
