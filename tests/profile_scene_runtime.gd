extends SceneTree

const Main = preload("res://scripts/main.gd")
const PetCatalog = preload("res://scripts/pet_catalog.gd")

const SAMPLE_FRAMES := 240


func _initialize() -> void:
	_run_profile()


func _run_profile() -> void:
	var main := Main.new()
	var roster: Array[String] = []
	var roster_source: Array = (
		[PetCatalog.ACTIVE_DESKTOP_PETS[0]]
		if OS.get_cmdline_user_args().has("--starter")
		else PetCatalog.ACTIVE_DESKTOP_PETS
	)
	for pet_id_value in roster_source:
		roster.append(String(pet_id_value))
	main.set("_unlocked_pet_ids", roster.duplicate())
	main.set("_deployed_pet_ids", roster.duplicate())

	var setup_started_usec := Time.get_ticks_usec()
	root.add_child(main)
	await process_frame
	var setup_usec := Time.get_ticks_usec() - setup_started_usec
	print("PROFILE scene_ready milliseconds=%.3f pets=%d" % [float(setup_usec) / 1000.0, roster.size()])
	for property_name in [
		"_side_drawer",
		"_inventory_window",
		"_evolution_window",
		"_shop_window",
		"_achievement_window",
		"_news_window",
		"_settings_window",
		"_completion_window",
	]:
		var subtree_root := main.get(property_name) as Node
		print(
			"PROFILE subtree name=%s nodes=%d"
			% [property_name, _count_subtree_nodes(subtree_root)]
		)
	if OS.get_cmdline_user_args().has("--open-drawer"):
		var drawer := main.get("_side_drawer") as Node
		var drawer_started_usec := Time.get_ticks_usec()
		drawer.call("_toggle_drawer")
		var drawer_sync_usec := Time.get_ticks_usec() - drawer_started_usec
		await process_frame
		print(
			"PROFILE drawer_first_open sync_ms=%.3f first_present_ms=%.3f nodes=%d"
			% [
				float(drawer_sync_usec) / 1000.0,
				float(Time.get_ticks_usec() - drawer_started_usec) / 1000.0,
				_count_subtree_nodes(drawer),
			]
		)
		var staged_frames := 0
		var staged_slowest_usec := 0
		while bool(drawer.call("_has_pending_drawer_build_work")) and staged_frames < 30:
			var stage_name := _get_drawer_build_stage_name(drawer)
			var staged_frame_started_usec := Time.get_ticks_usec()
			await process_frame
			var staged_frame_usec := Time.get_ticks_usec() - staged_frame_started_usec
			staged_slowest_usec = maxi(staged_slowest_usec, staged_frame_usec)
			staged_frames += 1
			print(
				"PROFILE drawer_stage name=%s frame_ms=%.3f"
				% [stage_name, float(staged_frame_usec) / 1000.0]
			)
		print(
			"PROFILE drawer_staged_rows frames=%d slowest_ms=%.3f remaining=%d nodes=%d"
			% [
				staged_frames,
				float(staged_slowest_usec) / 1000.0,
				(drawer.get("_pending_upgrade_pet_ids") as Array).size(),
				_count_subtree_nodes(drawer),
			]
		)

	for _warm_frame in 29:
		await process_frame

	var slowest_usec := 0
	var total_usec := 0
	for _sample_frame in SAMPLE_FRAMES:
		var frame_started_usec := Time.get_ticks_usec()
		await process_frame
		var frame_usec := Time.get_ticks_usec() - frame_started_usec
		total_usec += frame_usec
		slowest_usec = maxi(slowest_usec, frame_usec)
	print(
		"PROFILE scene_frames count=%d average_ms=%.3f slowest_ms=%.3f nodes=%d objects=%d static_memory_mb=%.2f"
		% [
			SAMPLE_FRAMES,
			float(total_usec) / float(SAMPLE_FRAMES) / 1000.0,
			float(slowest_usec) / 1000.0,
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0,
		]
	)
	main.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _count_subtree_nodes(subtree_root: Node) -> int:
	if subtree_root == null:
		return 0
	var count := 1
	for child in subtree_root.get_children():
		count += _count_subtree_nodes(child)
	return count


func _get_drawer_build_stage_name(drawer: Node) -> String:
	if bool(drawer.get("_drawer_background_pending")):
		return "background"
	if bool(drawer.get("_drawer_bookmarks_pending")):
		return "bookmarks"
	if bool(drawer.get("_drawer_content_shell_pending")):
		return "content_shell"
	if bool(drawer.get("_drawer_faith_assets_pending")):
		return "faith_assets"
	if bool(drawer.get("_drawer_faith_pending")):
		return "faith"
	if bool(drawer.get("_drawer_upgrades_pending")):
		return "upgrade_shell"
	var pending_pets := drawer.get("_pending_upgrade_pet_ids") as Array
	if not pending_pets.is_empty():
		return "pet_%s" % String(pending_pets.front())
	if bool(drawer.get("_drawer_symbols_pending")):
		return "symbols"
	return "complete"
