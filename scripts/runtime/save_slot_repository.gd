class_name SaveSlotRepository
extends RefCounted

# This class owns file paths and slot metadata only.  Keeping it separate from
# PersistenceController prevents slot management from becoming mixed into the
# GameState serialization code.
const STORAGE_ROOT := "user://cthulhu_saves"
const LEGACY_PRIMARY_PATH := "user://cthulu_save.cfg"
const LEGACY_BACKUP_PATH := "user://cthulu_save.cfg.bak"
const REGISTRY_FILE_NAME := "registry.cfg"
const REGISTRY_VERSION := 1
const SLOT_COUNT := 3
const SLOT_ID_PREFIX := "slot_"
const SLOT_ID_DIGITS := 6
const MAX_REGISTRY_FILE_BYTES := 65_536
const MAX_SLOT_FILE_BYTES := 1_500_000
const MAX_DISPLAY_NAME_LENGTH := 32

var _storage_root: String
var _legacy_primary_path: String
var _legacy_backup_path: String
var _active_slot_id := ""
var _slot_entries: Array[Dictionary] = []
var _initialized := false


func _init(
	storage_root := STORAGE_ROOT,
	legacy_primary_path := LEGACY_PRIMARY_PATH,
	legacy_backup_path := LEGACY_BACKUP_PATH
) -> void:
	_storage_root = String(storage_root).strip_edges()
	if _storage_root.is_empty():
		_storage_root = STORAGE_ROOT
	_legacy_primary_path = String(legacy_primary_path).strip_edges()
	_legacy_backup_path = String(legacy_backup_path).strip_edges()


func initialize() -> Dictionary:
	if _initialized:
		return _success()
	var directory_error := _ensure_storage_directory()
	if directory_error != OK:
		return _failure(directory_error)
	var registry_paths := get_registry_paths()
	var registry_result := _load_registry_with_backup(registry_paths)
	if bool(registry_result.get("ok", false)):
		_initialized = true
		return _success({"recovered_registry": String(registry_result.get("source", "")) == String(registry_paths.get("backup", ""))})

	var registry_error := int(registry_result.get("error", ERR_FILE_NOT_FOUND))
	var registry_backup_error := int(registry_result.get("backup_error", ERR_FILE_NOT_FOUND))
	if registry_error != ERR_FILE_NOT_FOUND or registry_backup_error != ERR_FILE_NOT_FOUND:
		return _failure(registry_error, {"recovery_required": true})

	var existing_slots_result := _find_existing_slot_ids()
	if int(existing_slots_result.get("error", OK)) != OK:
		return _failure(int(existing_slots_result.get("error", ERR_PARSE_ERROR)), {"recovery_required": true})
	var existing_slots = existing_slots_result.get("ids", [])
	if not existing_slots.is_empty():
		_slot_entries = _make_default_slot_entries()
		_active_slot_id = String(existing_slots[0])
		var reconstruct_error := _write_registry()
		if reconstruct_error != OK:
			return _failure(reconstruct_error)
		_initialized = true
		return _success({"reconstructed_registry": true})

	var legacy_result := load_config_with_backup(
		_legacy_primary_path,
		_legacy_backup_path,
		MAX_SLOT_FILE_BYTES
	)
	var legacy_save := legacy_result.get("config") as ConfigFile
	if legacy_save != null:
		_slot_entries = _make_default_slot_entries()
		_active_slot_id = get_slot_id(1)
		var migration_error := save_slot(_active_slot_id, legacy_save, false)
		if migration_error != OK:
			return _failure(migration_error)
		var registry_write_error := _write_registry()
		if registry_write_error != OK:
			return _failure(registry_write_error)
		_initialized = true
		return _success({"migrated_legacy": true})

	var legacy_error := int(legacy_result.get("error", ERR_FILE_NOT_FOUND))
	var legacy_backup_error := int(legacy_result.get("backup_error", ERR_FILE_NOT_FOUND))
	if legacy_error != ERR_FILE_NOT_FOUND or legacy_backup_error != ERR_FILE_NOT_FOUND:
		return _failure(legacy_error, {"recovery_required": true})
	_slot_entries = _make_default_slot_entries()
	_active_slot_id = get_slot_id(1)
	var initial_registry_error := _write_registry()
	if initial_registry_error != OK:
		return _failure(initial_registry_error)
	_initialized = true
	return _success()


func get_storage_root() -> String:
	return _storage_root


func get_active_slot_id() -> String:
	return _active_slot_id


func list_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for slot_entry in _slot_entries:
		var entry := slot_entry.duplicate(true)
		var slot_id := String(entry.get("id", ""))
		var load_result := load_slot(slot_id)
		var save := load_result.get("config") as ConfigFile
		entry["is_active"] = slot_id == _active_slot_id
		entry["has_data"] = save != null
		entry["recovered_from_backup"] = (
			save != null
			and String(load_result.get("source", "")) == String(get_slot_paths(slot_id).get("backup", ""))
		)
		entry["last_saved_unix"] = 0.0
		entry["playtime_seconds"] = 0.0
		if save != null:
			entry["last_saved_unix"] = _sanitize_non_negative_float(save.get_value("meta", "saved_unix", 0.0))
			entry["playtime_seconds"] = _sanitize_non_negative_float(save.get_value("statistics", "total_runtime_seconds", 0.0))
		slots.append(entry)
	return slots


func get_slot_paths(slot_id: String) -> Dictionary:
	if not is_valid_slot_id(slot_id):
		return {}
	var primary_path := _storage_root.path_join("%s.cfg" % slot_id)
	var backup_path := "%s.bak" % primary_path
	return {
		"primary": primary_path,
		"backup": backup_path,
		"temporary": make_temporary_path(primary_path),
		"backup_temporary": make_temporary_path(backup_path)
	}


func get_registry_paths() -> Dictionary:
	var primary_path := _storage_root.path_join(REGISTRY_FILE_NAME)
	var backup_path := "%s.bak" % primary_path
	return {
		"primary": primary_path,
		"backup": backup_path,
		"temporary": make_temporary_path(primary_path),
		"backup_temporary": make_temporary_path(backup_path)
	}


func load_active_slot() -> Dictionary:
	return load_slot(_active_slot_id)


func load_slot(slot_id: String) -> Dictionary:
	var paths := get_slot_paths(slot_id)
	if paths.is_empty():
		return _failure(ERR_INVALID_PARAMETER)
	var primary_path := String(paths.get("primary", ""))
	var backup_path := String(paths.get("backup", ""))
	var primary := ConfigFile.new()
	var primary_error := _load_config_file(primary, primary_path, MAX_SLOT_FILE_BYTES)
	if primary_error == OK and _config_belongs_to_slot(primary, slot_id):
		return {"ok": true, "config": primary, "source": primary_path, "error": OK, "backup_error": OK}
	if primary_error == OK:
		primary_error = ERR_PARSE_ERROR
	var backup := ConfigFile.new()
	var backup_error := _load_config_file(backup, backup_path, MAX_SLOT_FILE_BYTES)
	if backup_error == OK and _config_belongs_to_slot(backup, slot_id):
		return {"ok": true, "config": backup, "source": backup_path, "error": primary_error, "backup_error": OK}
	if backup_error == OK:
		backup_error = ERR_PARSE_ERROR
	return {"ok": false, "config": null, "source": "", "error": primary_error, "backup_error": backup_error}


func save_active_slot(save: ConfigFile) -> Dictionary:
	return _save_slot_result(_active_slot_id, save)


func save_slot(slot_id: String, save: ConfigFile, require_initialized := true) -> Error:
	var result := _save_slot_result(slot_id, save, require_initialized)
	return int(result.get("error", ERR_INVALID_PARAMETER))


func select_slot(slot_id: String) -> Dictionary:
	var init_result := _initialize_if_needed()
	if not bool(init_result.get("ok", false)):
		return init_result
	if not _has_slot_id(slot_id):
		return _failure(ERR_INVALID_PARAMETER)
	if _active_slot_id == slot_id:
		return _success({"already_active": true})
	var previous_active_slot_id := _active_slot_id
	_active_slot_id = slot_id
	_set_slot_last_selected(slot_id, Time.get_unix_time_from_system())
	var write_error := _write_registry()
	if write_error != OK:
		_active_slot_id = previous_active_slot_id
		return _failure(write_error)
	return _success()


func create_slot(slot_id: String) -> Dictionary:
	var init_result := _initialize_if_needed()
	if not bool(init_result.get("ok", false)):
		return init_result
	if not _has_slot_id(slot_id) or _slot_has_files(slot_id):
		return _failure(ERR_INVALID_PARAMETER)
	return select_slot(slot_id)


func rename_slot(slot_id: String, display_name: String) -> Dictionary:
	var init_result := _initialize_if_needed()
	if not bool(init_result.get("ok", false)):
		return init_result
	if not _has_slot_id(slot_id):
		return _failure(ERR_INVALID_PARAMETER)
	var slot_index := _get_slot_entry_index(slot_id)
	var previous_name := String(_slot_entries[slot_index].get("display_name", ""))
	_slot_entries[slot_index]["display_name"] = sanitize_display_name(display_name, _default_slot_name(slot_id))
	var write_error := _write_registry()
	if write_error != OK:
		_slot_entries[slot_index]["display_name"] = previous_name
		return _failure(write_error)
	return _success()


func delete_slot(slot_id: String) -> Dictionary:
	var init_result := _initialize_if_needed()
	if not bool(init_result.get("ok", false)):
		return init_result
	if not _has_slot_id(slot_id) or slot_id == _active_slot_id:
		return _failure(ERR_INVALID_PARAMETER)
	var slot_index := _get_slot_entry_index(slot_id)
	var previous_entry := _slot_entries[slot_index].duplicate(true)
	_slot_entries[slot_index] = _make_default_slot_entry(slot_id)
	var write_error := _write_registry()
	if write_error != OK:
		_slot_entries[slot_index] = previous_entry
		return _failure(write_error)
	var remove_error := _remove_slot_files(slot_id)
	if remove_error != OK:
		_slot_entries[slot_index] = previous_entry
		_write_registry()
		return _failure(remove_error)
	return _success()


func reset_slot(slot_id: String) -> Dictionary:
	var init_result := _initialize_if_needed()
	if not bool(init_result.get("ok", false)):
		return init_result
	if not _has_slot_id(slot_id):
		return _failure(ERR_INVALID_PARAMETER)
	var remove_error := _remove_slot_files(slot_id)
	if remove_error != OK:
		return _failure(remove_error)
	return _success()


func is_slot_empty(slot_id: String) -> bool:
	return _has_slot_id(slot_id) and not _slot_has_files(slot_id)


static func get_slot_id(slot_number: int) -> String:
	if slot_number < 1 or slot_number > SLOT_COUNT:
		return ""
	return "%s%0*d" % [SLOT_ID_PREFIX, SLOT_ID_DIGITS, slot_number]


static func is_valid_slot_id(slot_id: String) -> bool:
	if not slot_id.begins_with(SLOT_ID_PREFIX):
		return false
	var numeric_part := slot_id.trim_prefix(SLOT_ID_PREFIX)
	if numeric_part.length() != SLOT_ID_DIGITS or not numeric_part.is_valid_int():
		return false
	return get_slot_id(int(numeric_part)) == slot_id


static func sanitize_display_name(value: Variant, fallback: String) -> String:
	var sanitized := String(value).replace("\r", " ").replace("\n", " ").replace("\t", " ").strip_edges()
	if sanitized.is_empty():
		sanitized = fallback
	return sanitized.left(MAX_DISPLAY_NAME_LENGTH)


static func make_temporary_path(path: String) -> String:
	return "%s.%s.tmp" % [path, OS.get_process_id()]


static func load_config_with_backup(primary_path: String, backup_path: String, max_file_bytes := MAX_SLOT_FILE_BYTES) -> Dictionary:
	var primary := ConfigFile.new()
	var primary_error := _load_config_file(primary, primary_path, max_file_bytes)
	if primary_error == OK:
		return {"ok": true, "config": primary, "source": primary_path, "error": OK, "backup_error": OK}
	var backup := ConfigFile.new()
	var backup_error := _load_config_file(backup, backup_path, max_file_bytes)
	if backup_error == OK:
		return {"ok": true, "config": backup, "source": backup_path, "error": primary_error, "backup_error": OK}
	return {"ok": false, "config": null, "source": "", "error": primary_error, "backup_error": backup_error}


static func save_config_with_backup(
	save: ConfigFile,
	primary_path: String,
	backup_path: String,
	temporary_path: String,
	max_file_bytes := MAX_SLOT_FILE_BYTES
) -> Error:
	if save == null or primary_path.is_empty() or backup_path.is_empty() or temporary_path.is_empty():
		return ERR_INVALID_PARAMETER
	var write_error := save.save(temporary_path)
	if write_error != OK:
		return write_error
	var verification := ConfigFile.new()
	var verification_error := _load_config_file(verification, temporary_path, max_file_bytes)
	if verification_error != OK:
		_remove_file_if_present(temporary_path)
		return verification_error
	var primary_snapshot := ConfigFile.new()
	if _load_config_file(primary_snapshot, primary_path, max_file_bytes) == OK:
		var backup_error := _publish_backup_from_source(primary_path, backup_path, max_file_bytes)
		if backup_error != OK:
			_remove_file_if_present(temporary_path)
			return backup_error
	elif not FileAccess.file_exists(primary_path) and not FileAccess.file_exists(backup_path):
		# Publish a verified duplicate before the first primary write.  A freshly
		# migrated slot or registry can therefore recover even if its first
		# primary file is interrupted or damaged before the next autosave.
		var initial_backup_error := _publish_backup_from_source(temporary_path, backup_path, max_file_bytes)
		if initial_backup_error != OK:
			_remove_file_if_present(temporary_path)
			return initial_backup_error
	return _replace_file_from_temporary(temporary_path, primary_path, backup_path)


static func _load_config_file(save: ConfigFile, path: String, max_file_bytes := MAX_SLOT_FILE_BYTES) -> Error:
	if save == null or path.is_empty() or not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ERR_FILE_CANT_READ
	var file_size := file.get_length()
	file.close()
	if file_size > maxi(1, int(max_file_bytes)):
		return ERR_FILE_CANT_READ
	return save.load(path)


static func _copy_file(source_path: String, destination_path: String) -> Error:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return ERR_FILE_CANT_READ
	var contents := source.get_buffer(source.get_length())
	source.close()
	var destination := FileAccess.open(destination_path, FileAccess.WRITE)
	if destination == null:
		return ERR_FILE_CANT_WRITE
	destination.store_buffer(contents)
	var write_error := destination.get_error()
	destination.close()
	return write_error


static func _publish_backup_from_source(source_path: String, backup_path: String, max_file_bytes: int) -> Error:
	var backup_temporary_path := make_temporary_path(backup_path)
	var backup_error := _copy_file(source_path, backup_temporary_path)
	if backup_error != OK:
		return backup_error
	var backup_verification := ConfigFile.new()
	var backup_verification_error := _load_config_file(backup_verification, backup_temporary_path, max_file_bytes)
	if backup_verification_error != OK:
		_remove_file_if_present(backup_temporary_path)
		return backup_verification_error
	return _replace_file_from_temporary(backup_temporary_path, backup_path)


static func _replace_file_from_temporary(temporary_path: String, primary_path: String, backup_path := "") -> Error:
	var primary_absolute := ProjectSettings.globalize_path(primary_path)
	var temporary_absolute := ProjectSettings.globalize_path(temporary_path)
	if FileAccess.file_exists(primary_path):
		var remove_error := DirAccess.remove_absolute(primary_absolute)
		if remove_error != OK:
			return remove_error
	var replace_error := DirAccess.rename_absolute(temporary_absolute, primary_absolute)
	if replace_error == OK:
		return OK
	if not backup_path.is_empty() and FileAccess.file_exists(backup_path):
		_copy_file(backup_path, primary_path)
	return replace_error


static func _remove_file_if_present(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _initialize_if_needed() -> Dictionary:
	return initialize() if not _initialized else _success()


func _ensure_storage_directory() -> Error:
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_storage_root))


func _read_registry(registry: ConfigFile) -> Error:
	if registry == null or int(registry.get_value("meta", "version", 0)) != REGISTRY_VERSION:
		return ERR_PARSE_ERROR
	var raw_ids: Variant = registry.get_value("slots", "ids", [])
	if not (raw_ids is Array or raw_ids is PackedStringArray):
		return ERR_PARSE_ERROR
	if raw_ids.size() != SLOT_COUNT:
		return ERR_PARSE_ERROR
	var ids: Array[String] = []
	for raw_id in raw_ids:
		var slot_id := String(raw_id)
		if not is_valid_slot_id(slot_id) or ids.has(slot_id):
			return ERR_PARSE_ERROR
		ids.append(slot_id)
	for slot_number in range(1, SLOT_COUNT + 1):
		if not ids.has(get_slot_id(slot_number)):
			return ERR_PARSE_ERROR
	var active_slot_id := String(registry.get_value("meta", "active_slot_id", ""))
	if not ids.has(active_slot_id):
		return ERR_PARSE_ERROR
	_slot_entries.clear()
	for slot_id in ids:
		_slot_entries.append({
			"id": slot_id,
			"display_name": sanitize_display_name(
				registry.get_value("slot.%s" % slot_id, "display_name", _default_slot_name(slot_id)),
				_default_slot_name(slot_id)
			),
			"created_unix": _sanitize_non_negative_float(registry.get_value("slot.%s" % slot_id, "created_unix", 0.0)),
			"last_selected_unix": _sanitize_non_negative_float(registry.get_value("slot.%s" % slot_id, "last_selected_unix", 0.0))
		})
	_active_slot_id = active_slot_id
	return OK


func _load_registry_with_backup(paths: Dictionary) -> Dictionary:
	var primary_path := String(paths.get("primary", ""))
	var backup_path := String(paths.get("backup", ""))
	var primary := ConfigFile.new()
	var primary_error := _load_config_file(primary, primary_path, MAX_REGISTRY_FILE_BYTES)
	if primary_error == OK:
		var primary_validation_error := _read_registry(primary)
		if primary_validation_error == OK:
			return {"ok": true, "source": primary_path, "error": OK, "backup_error": OK}
		primary_error = primary_validation_error
		_slot_entries.clear()
		_active_slot_id = ""
	var backup := ConfigFile.new()
	var backup_error := _load_config_file(backup, backup_path, MAX_REGISTRY_FILE_BYTES)
	if backup_error == OK:
		var backup_validation_error := _read_registry(backup)
		if backup_validation_error == OK:
			return {"ok": true, "source": backup_path, "error": primary_error, "backup_error": OK}
		backup_error = backup_validation_error
		_slot_entries.clear()
		_active_slot_id = ""
	return {"ok": false, "source": "", "error": primary_error, "backup_error": backup_error}


func _write_registry() -> Error:
	var registry := ConfigFile.new()
	registry.set_value("meta", "version", REGISTRY_VERSION)
	registry.set_value("meta", "active_slot_id", _active_slot_id)
	var ids := PackedStringArray()
	for slot_entry in _slot_entries:
		var slot_id := String(slot_entry.get("id", ""))
		ids.append(slot_id)
		var section := "slot.%s" % slot_id
		registry.set_value(section, "display_name", sanitize_display_name(slot_entry.get("display_name", ""), _default_slot_name(slot_id)))
		registry.set_value(section, "created_unix", _sanitize_non_negative_float(slot_entry.get("created_unix", 0.0)))
		registry.set_value(section, "last_selected_unix", _sanitize_non_negative_float(slot_entry.get("last_selected_unix", 0.0)))
	registry.set_value("slots", "ids", ids)
	var paths := get_registry_paths()
	return save_config_with_backup(
		registry,
		String(paths.get("primary", "")),
		String(paths.get("backup", "")),
		String(paths.get("temporary", "")),
		MAX_REGISTRY_FILE_BYTES
	)


func _save_slot_result(slot_id: String, save: ConfigFile, require_initialized := true) -> Dictionary:
	if require_initialized:
		var init_result := _initialize_if_needed()
		if not bool(init_result.get("ok", false)):
			return init_result
	if save == null or not _has_slot_id(slot_id):
		return _failure(ERR_INVALID_PARAMETER)
	save.set_value("meta", "slot_id", slot_id)
	if not save.has_section_key("meta", "created_unix"):
		save.set_value("meta", "created_unix", Time.get_unix_time_from_system())
	var paths := get_slot_paths(slot_id)
	var save_error := save_config_with_backup(
		save,
		String(paths.get("primary", "")),
		String(paths.get("backup", "")),
		String(paths.get("temporary", "")),
		MAX_SLOT_FILE_BYTES
	)
	if save_error != OK:
		return _failure(save_error)
	return _success()


func _find_existing_slot_ids() -> Dictionary:
	var slot_ids: Array[String] = []
	for slot_number in range(1, SLOT_COUNT + 1):
		var slot_id := get_slot_id(slot_number)
		if not _slot_has_files(slot_id):
			continue
		var load_result := load_slot(slot_id)
		if load_result.get("config") as ConfigFile == null:
			return {"ids": slot_ids, "error": int(load_result.get("error", ERR_PARSE_ERROR))}
		slot_ids.append(slot_id)
	return {"ids": slot_ids, "error": OK}


func _make_default_slot_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var now := Time.get_unix_time_from_system()
	for slot_number in range(1, SLOT_COUNT + 1):
		var slot_id := get_slot_id(slot_number)
		entries.append({
			"id": slot_id,
			"display_name": _default_slot_name(slot_id),
			"created_unix": now,
			"last_selected_unix": now if slot_number == 1 else 0.0
		})
	return entries


func _make_default_slot_entry(slot_id: String) -> Dictionary:
	return {
		"id": slot_id,
		"display_name": _default_slot_name(slot_id),
		"created_unix": Time.get_unix_time_from_system(),
		"last_selected_unix": 0.0
	}


func _default_slot_name(slot_id: String) -> String:
	var slot_number := int(slot_id.trim_prefix(SLOT_ID_PREFIX))
	return "Save %d" % slot_number


func _has_slot_id(slot_id: String) -> bool:
	return is_valid_slot_id(slot_id) and _get_slot_entry_index(slot_id) >= 0


func _get_slot_entry_index(slot_id: String) -> int:
	for index in _slot_entries.size():
		if String(_slot_entries[index].get("id", "")) == slot_id:
			return index
	return -1


func _set_slot_last_selected(slot_id: String, timestamp: float) -> void:
	var slot_index := _get_slot_entry_index(slot_id)
	if slot_index >= 0:
		_slot_entries[slot_index]["last_selected_unix"] = _sanitize_non_negative_float(timestamp)


func _slot_has_files(slot_id: String) -> bool:
	var paths := get_slot_paths(slot_id)
	if paths.is_empty():
		return false
	return (
		FileAccess.file_exists(String(paths.get("primary", "")))
		or FileAccess.file_exists(String(paths.get("backup", "")))
	)


func _remove_slot_files(slot_id: String) -> Error:
	var paths := get_slot_paths(slot_id)
	if paths.is_empty():
		return ERR_INVALID_PARAMETER
	for path_key in ["primary", "backup", "temporary", "backup_temporary"]:
		var remove_error := _remove_file_if_present(String(paths.get(path_key, "")))
		if remove_error != OK:
			return remove_error
	return OK


func _config_belongs_to_slot(save: ConfigFile, slot_id: String) -> bool:
	if save == null:
		return false
	var saved_slot_id := String(save.get_value("meta", "slot_id", ""))
	return saved_slot_id == slot_id


static func _sanitize_non_negative_float(value: Variant) -> float:
	var numeric_value := float(value)
	if not is_finite(numeric_value):
		return 0.0
	return maxf(0.0, numeric_value)


func _success(extra := {}) -> Dictionary:
	var result := {"ok": true, "error": OK}
	for key in extra:
		result[key] = extra[key]
	return result


func _failure(error_code: Error, extra := {}) -> Dictionary:
	var result := {"ok": false, "error": error_code}
	for key in extra:
		result[key] = extra[key]
	return result
