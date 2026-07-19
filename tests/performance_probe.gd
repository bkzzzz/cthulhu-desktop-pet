extends SceneTree

const Main = preload("res://scripts/main.gd")
const PetCatalog = preload("res://scripts/pet_catalog.gd")


func _initialize() -> void:
	call_deferred("_run_probe")


func _run_probe() -> void:
	var main := Main.new()
	root.add_child(main)
	for _frame in 12:
		await process_frame

	for actor in (main.get("_pets") as Array).duplicate():
		if is_instance_valid(actor):
			actor.free()
	(main.get("_pets") as Array).clear()
	main.set("_unlocked_pet_ids", PetCatalog.ACTIVE_DESKTOP_PETS.duplicate())
	main.set("_deployed_pet_ids", PetCatalog.ACTIVE_DESKTOP_PETS.duplicate())
	var states := {}
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		states[String(pet_id_value)] = {"upgrade_level": 99}
	main.set("_pet_states", states)
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		main.call("_spawn_desktop_pet", String(pet_id_value))
	for _frame in 30:
		await process_frame

	await _measure_frames("IDLE_CLOSED", 180)
	var side_drawer: Node = main.get("_side_drawer")
	if side_drawer != null:
		side_drawer.call("_toggle_drawer")
	for _frame in 30:
		await process_frame
	await _measure_frames("IDLE_DRAWER_OPEN", 180)

	var entries: Array = main.call("_get_pet_upgrade_entries")
	var refresh_started := Time.get_ticks_usec()
	for _iteration in 120:
		side_drawer.call("refresh_pet_upgrades", entries)
	var refresh_ms := float(Time.get_ticks_usec() - refresh_started) / 1000.0
	print("PERF_UPGRADE_REFRESH calls=120 total_ms=%.2f per_call_ms=%.3f" % [refresh_ms, refresh_ms / 120.0])

	var interaction_started := Time.get_ticks_usec()
	for _iteration in 120:
		for actor in main.get("_pets") as Array:
			if is_instance_valid(actor):
				actor.call("_update_interaction_area")
	var interaction_ms := float(Time.get_ticks_usec() - interaction_started) / 1000.0
	print("PERF_INTERACTION_GEOMETRY calls=1200 total_ms=%.2f per_call_ms=%.3f" % [interaction_ms, interaction_ms / 1200.0])

	var rename_deltas: Array[float] = []
	for index in 30:
		var frame_started := Time.get_ticks_usec()
		main.call("_on_pet_detail_rename_requested", "pet1", "Probe%d" % index)
		await process_frame
		rename_deltas.append(float(Time.get_ticks_usec() - frame_started) / 1000.0)
	_print_samples("RENAME_INTERACTION", rename_deltas)

	main.free()
	quit(0)


func _measure_frames(label: String, frame_count: int) -> void:
	var samples: Array[float] = []
	for _frame in frame_count:
		var frame_started := Time.get_ticks_usec()
		await process_frame
		samples.append(float(Time.get_ticks_usec() - frame_started) / 1000.0)
	_print_samples(label, samples)


func _print_samples(label: String, samples: Array[float]) -> void:
	if samples.is_empty():
		return
	var ordered := samples.duplicate()
	ordered.sort()
	var total := 0.0
	for sample in samples:
		total += sample
	var p95_index := clampi(int(ceil(float(ordered.size()) * 0.95)) - 1, 0, ordered.size() - 1)
	print("PERF_%s frames=%d avg_ms=%.2f p95_ms=%.2f max_ms=%.2f" % [
		label,
		samples.size(),
		total / float(samples.size()),
		ordered[p95_index],
		ordered.back()
	])
