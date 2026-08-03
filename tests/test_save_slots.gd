extends RefCounted

const SaveSlotRepository = preload("res://scripts/runtime/save_slot_repository.gd")
const Main = preload("res://scripts/main.gd")
const GameState = preload("res://scripts/runtime/game_state.gd")
const TEST_ROOT_PREFIX := "user://cthulhu_test_save_slots_"


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_first_run_creates_three_controlled_slots(failures)
	_test_first_snapshots_have_immediate_backups(failures)
	_test_legacy_migration_preserves_original_files(failures)
	_test_legacy_backup_migration_recovers_damaged_primary(failures)
	_test_slot_isolation_and_backup_recovery(failures)
	_test_registry_validation_and_slot_name_sanitization(failures)
	_test_registry_rejects_oversized_slot_list(failures)
	_test_orphaned_corrupt_slot_requires_recovery(failures)
	_test_persistence_controller_serializes_to_the_active_slot(failures)
	_test_slot_switch_blocks_uncollected_coins(failures)
	return failures


static func _test_first_run_creates_three_controlled_slots(failures: Array[String]) -> void:
	var root := _make_test_root("first_run")
	var repository := _make_repository(root)
	var result := repository.initialize()
	if not bool(result.get("ok", false)):
		failures.append("a new save-slot repository must initialize a registry")
	elif repository.get_active_slot_id() != "slot_000001":
		failures.append("a new save-slot repository must select the first controlled slot")
	else:
		var slots := repository.list_slots()
		if slots.size() != SaveSlotRepository.SLOT_COUNT:
			failures.append("a new save-slot repository must expose exactly three managed slots")
		elif bool(slots[0].get("has_data", true)):
			failures.append("a new managed slot must stay empty until it is actually saved")
	if not repository.get_slot_paths("../outside").is_empty():
		failures.append("an invalid slot id must never produce a writable path")
	_cleanup_root(root)


static func _test_legacy_migration_preserves_original_files(failures: Array[String]) -> void:
	var root := _make_test_root("legacy")
	var legacy_path := root.path_join("legacy_save.cfg")
	var legacy_backup_path := "%s.bak" % legacy_path
	_ensure_directory(root)
	var legacy := ConfigFile.new()
	legacy.set_value("meta", "version", 15)
	legacy.set_value("economy", "faith_points", 123.0)
	legacy.set_value("meta", "marker", "legacy")
	if legacy.save(legacy_path) != OK:
		failures.append("save-slot migration test could not create its legacy source")
	else:
		var repository := SaveSlotRepository.new(root, legacy_path, legacy_backup_path)
		var init_result := repository.initialize()
		var migrated := repository.load_active_slot().get("config") as ConfigFile
		if not bool(init_result.get("ok", false)) or not bool(init_result.get("migrated_legacy", false)):
			failures.append("an existing legacy save must migrate only after the new slot registry is valid")
		elif migrated == null or String(migrated.get_value("meta", "marker", "")) != "legacy":
			failures.append("legacy migration must preserve the game snapshot contents")
		elif String(migrated.get_value("meta", "slot_id", "")) != "slot_000001":
			failures.append("legacy migration must bind the copied snapshot to the first managed slot")
		elif not FileAccess.file_exists(legacy_path):
			failures.append("legacy migration must retain the original single-save file as a recovery copy")
	_cleanup_root(root)


static func _test_first_snapshots_have_immediate_backups(failures: Array[String]) -> void:
	var root := _make_test_root("first_backup")
	var repository := _make_repository(root)
	if not bool(repository.initialize().get("ok", false)):
		failures.append("first-backup test could not initialize its isolated repository")
		_cleanup_root(root)
		return
	var registry_paths := repository.get_registry_paths()
	if not FileAccess.file_exists(String(registry_paths.get("primary", ""))) or not FileAccess.file_exists(String(registry_paths.get("backup", ""))):
		failures.append("the first registry snapshot must immediately receive a verified backup")
	var first_slot_snapshot := ConfigFile.new()
	first_slot_snapshot.set_value("meta", "marker", "first_slot_snapshot")
	if repository.save_slot("slot_000001", first_slot_snapshot) != OK:
		failures.append("first-backup test could not write its isolated slot snapshot")
	else:
		var slot_paths := repository.get_slot_paths("slot_000001")
		if not FileAccess.file_exists(String(slot_paths.get("backup", ""))):
			failures.append("the first slot snapshot must immediately receive a verified backup")
		else:
			var damaged := FileAccess.open(String(slot_paths.get("primary", "")), FileAccess.WRITE)
			if damaged == null:
				failures.append("first-backup test could not damage its isolated slot primary")
			else:
				var oversized_contents := PackedByteArray()
				oversized_contents.resize(SaveSlotRepository.MAX_SLOT_FILE_BYTES + 1)
				damaged.store_buffer(oversized_contents)
				damaged.close()
				var recovered := repository.load_slot("slot_000001").get("config") as ConfigFile
				if recovered == null or String(recovered.get_value("meta", "marker", "")) != "first_slot_snapshot":
					failures.append("a first slot snapshot must recover before any later autosave occurs")
	var registry_damaged := FileAccess.open(String(registry_paths.get("primary", "")), FileAccess.WRITE)
	if registry_damaged == null:
		failures.append("first-backup test could not damage its isolated registry primary")
	else:
		registry_damaged.store_string("corrupt registry")
		registry_damaged.close()
		var recovered_repository := _make_repository(root)
		if not bool(recovered_repository.initialize().get("ok", false)):
			failures.append("a first registry snapshot must recover before any later slot operation occurs")
	_cleanup_root(root)


static func _test_legacy_backup_migration_recovers_damaged_primary(failures: Array[String]) -> void:
	var root := _make_test_root("legacy_backup")
	var legacy_path := root.path_join("legacy_save.cfg")
	var legacy_backup_path := "%s.bak" % legacy_path
	_ensure_directory(root)
	var damaged := FileAccess.open(legacy_path, FileAccess.WRITE)
	if damaged == null:
		failures.append("save-slot backup migration test could not create a damaged primary")
	else:
		var oversized_contents := PackedByteArray()
		oversized_contents.resize(SaveSlotRepository.MAX_SLOT_FILE_BYTES + 1)
		damaged.store_buffer(oversized_contents)
		damaged.close()
		var backup := ConfigFile.new()
		backup.set_value("meta", "version", 15)
		backup.set_value("meta", "marker", "legacy_backup")
		if backup.save(legacy_backup_path) != OK:
			failures.append("save-slot backup migration test could not create a valid backup")
		else:
			var repository := SaveSlotRepository.new(root, legacy_path, legacy_backup_path)
			var init_result := repository.initialize()
			var migrated := repository.load_active_slot().get("config") as ConfigFile
			if not bool(init_result.get("ok", false)) or migrated == null or String(migrated.get_value("meta", "marker", "")) != "legacy_backup":
				failures.append("legacy migration must recover from a valid legacy backup when its primary is damaged")
	_cleanup_root(root)


static func _test_slot_isolation_and_backup_recovery(failures: Array[String]) -> void:
	var root := _make_test_root("isolation")
	var repository := _make_repository(root)
	if not bool(repository.initialize().get("ok", false)):
		failures.append("slot isolation test could not initialize its repository")
		_cleanup_root(root)
		return
	var first := ConfigFile.new()
	first.set_value("meta", "marker", "slot_one_first")
	var second := ConfigFile.new()
	second.set_value("meta", "marker", "slot_one_second")
	if repository.save_slot("slot_000001", first) != OK or repository.save_slot("slot_000001", second) != OK:
		failures.append("managed slots must save through their own safe snapshot path")
	else:
		if not bool(repository.select_slot("slot_000002").get("ok", false)):
			failures.append("a managed empty slot must be selectable without touching another slot")
		var third := ConfigFile.new()
		third.set_value("meta", "marker", "slot_two")
		if repository.save_slot("slot_000002", third) != OK:
			failures.append("the second managed slot must save independently")
		var paths := repository.get_slot_paths("slot_000001")
		var damaged := FileAccess.open(String(paths.get("primary", "")), FileAccess.WRITE)
		if damaged == null:
			failures.append("slot recovery test could not damage its isolated slot primary")
		else:
			var oversized_contents := PackedByteArray()
			oversized_contents.resize(SaveSlotRepository.MAX_SLOT_FILE_BYTES + 1)
			damaged.store_buffer(oversized_contents)
			damaged.close()
			var recovered := repository.load_slot("slot_000001").get("config") as ConfigFile
			var untouched := repository.load_slot("slot_000002").get("config") as ConfigFile
			if recovered == null or String(recovered.get_value("meta", "marker", "")) != "slot_one_first":
				failures.append("a damaged slot primary must recover from that slot's backup")
			if untouched == null or String(untouched.get_value("meta", "marker", "")) != "slot_two":
				failures.append("recovering one slot must not affect another slot")
			if not bool(repository.delete_slot("slot_000001").get("ok", false)):
				failures.append("a non-active managed slot must be deletable")
			elif not repository.is_slot_empty("slot_000001") or repository.is_slot_empty("slot_000002"):
				failures.append("deleting one managed slot must not touch the active slot data")
	_cleanup_root(root)


static func _test_registry_validation_and_slot_name_sanitization(failures: Array[String]) -> void:
	var root := _make_test_root("validation")
	var repository := _make_repository(root)
	if not bool(repository.initialize().get("ok", false)):
		failures.append("slot validation test could not initialize its repository")
		_cleanup_root(root)
		return
	var long_name := "A".repeat(SaveSlotRepository.MAX_DISPLAY_NAME_LENGTH + 8) + "\nignored"
	if not bool(repository.rename_slot("slot_000001", long_name).get("ok", false)):
		failures.append("a valid slot name must be persistable")
	else:
		var slots := repository.list_slots()
		var saved_name := String(slots[0].get("display_name", ""))
		if saved_name.length() != SaveSlotRepository.MAX_DISPLAY_NAME_LENGTH or saved_name.contains("\n"):
			failures.append("slot names must be bounded and strip control characters")
	if bool(repository.rename_slot("../../cthulu_save", "unsafe").get("ok", true)):
		failures.append("path-like ids must be rejected before slot metadata is written")
	if bool(repository.delete_slot("slot_000001").get("ok", true)):
		failures.append("the active slot must never be deletable")
	var registry_paths := repository.get_registry_paths()
	var damaged := FileAccess.open(String(registry_paths.get("primary", "")), FileAccess.WRITE)
	if damaged == null:
		failures.append("registry recovery test could not damage its primary registry")
	else:
		damaged.store_string("corrupt registry")
		damaged.close()
		var recovered_repository := _make_repository(root)
		if not bool(recovered_repository.initialize().get("ok", false)):
			failures.append("a damaged slot registry must recover from its valid backup")
	_cleanup_root(root)


static func _test_persistence_controller_serializes_to_the_active_slot(failures: Array[String]) -> void:
	var root := _make_test_root("controller")
	var legacy_path := root.path_join("legacy.cfg")
	var legacy_backup_path := "%s.bak" % legacy_path
	_ensure_directory(root)
	var legacy := ConfigFile.new()
	legacy.set_value("meta", "version", 15)
	legacy.set_value("economy", "faith_points", 321.0)
	legacy.set_value("economy", "lifetime_faith", 321.0)
	if legacy.save(legacy_path) != OK:
		failures.append("persistence-controller slot test could not create its isolated legacy source")
		_cleanup_root(root)
		return
	var main := Main.new()
	var controller := main.get("_persistence_controller") as Node
	var repository := SaveSlotRepository.new(root, legacy_path, legacy_backup_path)
	if controller == null:
		failures.append("main must retain a dedicated persistence controller for slot serialization")
	else:
		controller.set("_save_slots", repository)
		main.set("_persistence_enabled", true)
		main.call("_load_game")
		if not is_equal_approx(float(main.get("_faith_points")), 321.0):
			failures.append("the persistence controller must load migrated data through the active slot")
		main.set("_faith_points", 654.0)
		if int(main.call("_save_game")) != OK:
			failures.append("the persistence controller must save to the active managed slot")
		var first_slot := repository.load_slot("slot_000001").get("config") as ConfigFile
		if first_slot == null or not is_equal_approx(float(first_slot.get_value("economy", "faith_points", 0.0)), 654.0):
			failures.append("saving the active slot must not fall back to the retired single-save path")
		if not bool(repository.select_slot("slot_000002").get("ok", false)):
			failures.append("an isolated persistence test must be able to select a second slot")
		main.set("_faith_points", 987.0)
		if int(main.call("_save_game")) != OK:
			failures.append("the persistence controller must save after the active slot changes")
		var second_slot := repository.load_slot("slot_000002").get("config") as ConfigFile
		if second_slot == null or not is_equal_approx(float(second_slot.get_value("economy", "faith_points", 0.0)), 987.0):
			failures.append("the persistence controller must serialize state into the newly active slot only")
		if first_slot != null and not is_equal_approx(float(first_slot.get_value("economy", "faith_points", 0.0)), 654.0):
			failures.append("changing active slots must preserve prior slot snapshots")
	main.free()
	_cleanup_root(root)


static func _test_orphaned_corrupt_slot_requires_recovery(failures: Array[String]) -> void:
	var root := _make_test_root("orphaned_corrupt")
	_ensure_directory(root)
	var corrupt_path := root.path_join("slot_000002.cfg")
	var corrupt_file := FileAccess.open(corrupt_path, FileAccess.WRITE)
	if corrupt_file == null:
		failures.append("orphaned-slot recovery test could not create an isolated damaged slot")
		_cleanup_root(root)
		return
	var oversized_contents := PackedByteArray()
	oversized_contents.resize(SaveSlotRepository.MAX_SLOT_FILE_BYTES + 1)
	corrupt_file.store_buffer(oversized_contents)
	corrupt_file.close()
	var repository := _make_repository(root)
	var init_result := repository.initialize()
	if bool(init_result.get("ok", true)) or not bool(init_result.get("recovery_required", false)):
		failures.append("a corrupt orphaned slot must disable automatic initialization instead of being treated as empty")
	_cleanup_root(root)


static func _test_registry_rejects_oversized_slot_list(failures: Array[String]) -> void:
	var root := _make_test_root("registry_limit")
	_ensure_directory(root)
	var registry := ConfigFile.new()
	registry.set_value("meta", "version", SaveSlotRepository.REGISTRY_VERSION)
	registry.set_value("meta", "active_slot_id", "slot_000001")
	var oversized_ids := PackedStringArray()
	for _index in 512:
		oversized_ids.append("slot_000001")
	registry.set_value("slots", "ids", oversized_ids)
	if registry.save(root.path_join(SaveSlotRepository.REGISTRY_FILE_NAME)) != OK:
		failures.append("registry-limit test could not create its isolated malformed registry")
	else:
		var repository := _make_repository(root)
		var init_result := repository.initialize()
		if bool(init_result.get("ok", true)) or not bool(init_result.get("recovery_required", false)):
			failures.append("a registry with an oversized slot list must be rejected before slot traversal")
	_cleanup_root(root)


static func _test_slot_switch_blocks_uncollected_coins(failures: Array[String]) -> void:
	var root := _make_test_root("coin_guard")
	var main := Main.new()
	var controller := main.get("_persistence_controller") as Node
	var repository := _make_repository(root)
	var pending_coin := Node2D.new()
	if controller == null or not bool(repository.initialize().get("ok", false)):
		failures.append("coin-guard test could not initialize its isolated persistence controller")
	else:
		controller.set("_save_slots", repository)
		main.set("_persistence_enabled", true)
		var state := main.get("_state") as GameState
		state._coin_drops.append(pending_coin)
		# Unit-test the shared precondition directly: the Main instance is deliberately
		# not in a SceneTree, so a full switch would correctly stop at its later
		# scene-reload guard before it could demonstrate this data-loss protection.
		var guard_result: Dictionary = controller.call("_can_manage_save_slots")
		if bool(guard_result.get("ok", true)) or not String(guard_result.get("reason", "")).contains("Collect"):
			failures.append("switching saves must refuse to discard visible uncollected coins")
	pending_coin.free()
	main.free()
	_cleanup_root(root)


static func _make_repository(root: String) -> SaveSlotRepository:
	return SaveSlotRepository.new(root, root.path_join("legacy.cfg"), root.path_join("legacy.cfg.bak"))


static func _make_test_root(label: String) -> String:
	return "%s%s_%s_%s" % [TEST_ROOT_PREFIX, label, OS.get_process_id(), Time.get_ticks_usec()]


static func _ensure_directory(root: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))


static func _cleanup_root(root: String) -> void:
	if not root.begins_with(TEST_ROOT_PREFIX):
		return
	var directory := DirAccess.open(root)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		if not directory.current_is_dir():
			directory.remove(entry_name)
		entry_name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(root))
