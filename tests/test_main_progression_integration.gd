extends RefCounted

const Main = preload("res://scripts/main.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_legacy_state_migration(failures)
	_test_manual_two_stage_evolution(failures)
	_test_batch_population_upgrade(failures)
	_test_upgrade_entry_simplicity(failures)
	return failures


static func _make_main() -> Node:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	return main


static func _test_legacy_state_migration(failures: Array[String]) -> void:
	var main := _make_main()
	var sanitized: Dictionary = main.call("_sanitize_loaded_pet_states", {
		"pet1": {
			"count": 150,
			"trust": 3,
			"favor": 5,
			"next_trust_pet_at": 123.0,
			"hungry": true,
			"last_fed_at": 1.0
		}
	})
	var state: Dictionary = sanitized.get("pet1", {})
	if int(state.get("upgrade_level", 0)) != 150 or int(state.get("evolution_stage", -1)) != 0:
		failures.append("legacy pet saves must migrate progression and evolution fields")
	if state.has("hungry") or state.has("last_fed_at"):
		failures.append("legacy hunger state must be removed during save migration")
	if state.has("trust") or state.has("favor") or state.has("next_trust_pet_at"):
		failures.append("legacy affinity state must be removed during save migration")
	main.free()


static func _test_manual_two_stage_evolution(failures: Array[String]) -> void:
	var main := _make_main()
	var state: Dictionary = main.call("_get_pet_state", "pet1")
	state["count"] = 100
	state["upgrade_level"] = 100
	var faith_before := float(main.get("_faith_points"))
	main.call("_on_pet_evolution_requested", "pet1")
	if int(state.get("evolution_stage", 0)) != 1 or int(state.get("count", 0)) != 100:
		failures.append("first evolution must be manual and preserve population")
	main.call("_on_pet_evolution_requested", "pet1")
	if int(state.get("evolution_stage", 0)) != 1:
		failures.append("second evolution must wait for its own threshold")
	state["count"] = 1000
	main.call("_on_pet_evolution_requested", "pet1")
	main.call("_on_pet_evolution_requested", "pet1")
	if int(state.get("evolution_stage", 0)) != 2:
		failures.append("each pet must stop after exactly two evolutions")
	if not is_equal_approx(float(main.get("_faith_points")), faith_before):
		failures.append("evolution must not charge extra faith after meeting its population threshold")
	main.free()


static func _test_batch_population_upgrade(failures: Array[String]) -> void:
	var main := _make_main()
	var state: Dictionary = main.call("_get_pet_state", "pet2")
	state["count"] = 100
	state["upgrade_level"] = 100
	main.set("_faith_points", 1.0e15)
	main.call("_on_pet_count_upgrade_requested", "pet2")
	if int(state.get("count", 0)) != 110 or int(state.get("upgrade_level", 0)) != 101:
		failures.append("population upgrades at 100 must add ten while price level advances once")
	main.free()


static func _test_upgrade_entry_simplicity(failures: Array[String]) -> void:
	var main := _make_main()
	var entries: Array[Dictionary] = main.call("_get_pet_upgrade_entries")
	var pet1_entry: Dictionary = entries[0]
	if int(pet1_entry.get("count", 0)) != 1 or int(pet1_entry.get("next_evolution_threshold", 0)) != 100:
		failures.append("upgrade entries must expose current population and the next evolution target")
	for removed_key in ["favor", "favor_output_bonus", "upgrade_discount", "evolution_form_name", "population_gain", "leader_age"]:
		if pet1_entry.has(removed_key):
			failures.append("upgrade entries must not expose removed UI field %s" % removed_key)
	main.free()
