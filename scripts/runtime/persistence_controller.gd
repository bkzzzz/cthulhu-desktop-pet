extends "res://scripts/runtime/main_context.gd"

const SaveSlotRepository = preload("res://scripts/runtime/save_slot_repository.gd")

var _save_slots := SaveSlotRepository.new()
var _save_slot_switch_in_progress := false


func _load_game() -> void:
	if not _persistence_enabled:
		return
	var slot_init_result := _save_slots.initialize()
	if not bool(slot_init_result.get("ok", false)):
		_persistence_enabled = false
		_save_dirty = false
		_save_debounce_remaining = 0.0
		push_warning("Could not initialize save-slot data; autosave is disabled: %s" % error_string(int(slot_init_result.get("error", ERR_FILE_NOT_FOUND))))
		return
	if bool(slot_init_result.get("migrated_legacy", false)):
		push_warning("Migrated the legacy save into Save 1. The original save files were kept as recovery copies.")
	var load_result := _save_slots.load_active_slot()
	var save := load_result.get("config") as ConfigFile
	if save == null:
		var load_error := int(load_result.get("error", ERR_FILE_NOT_FOUND))
		var backup_error := int(load_result.get("backup_error", ERR_FILE_NOT_FOUND))
		if load_error == ERR_FILE_NOT_FOUND and backup_error == ERR_FILE_NOT_FOUND:
			return
		# A damaged save must remain intact for recovery instead of being replaced
		# by the fresh in-memory state during the next autosave tick.
		_persistence_enabled = false
		_save_dirty = false
		_save_debounce_remaining = 0.0
		push_warning("Could not load save data or its backup; autosave is disabled: %s" % error_string(load_error))
		return
	if String(load_result.get("source", "")) == String(_save_slots.get_slot_paths(_save_slots.get_active_slot_id()).get("backup", "")):
		push_warning("Primary save was invalid; recovered the last valid backup.")
	var loaded_save_version = maxi(0, int(save.get_value("meta", "version", 0)))

	_faith_points = sanitize_finite_float(
		save.get_value("economy", "faith_points", 0.0),
		0.0,
		MAX_PERSISTED_FLOAT,
		0.0
	)
	_lifetime_faith = maxf(
		_faith_points,
		sanitize_finite_float(
			save.get_value("economy", "lifetime_faith", _faith_points),
			0.0,
			MAX_PERSISTED_FLOAT,
			_faith_points
		)
	)
	_follower_count = sanitize_finite_float(
		save.get_value("economy", "followers", 0.0),
		0.0,
		MAX_PERSISTED_FLOAT,
		0.0
	)
	_gold_coins = CurrencyDisplay.sanitize_gold(int(save.get_value("economy", "gold_coins", 0)))
	_total_runtime_seconds = sanitize_finite_float(
		save.get_value("statistics", "total_runtime_seconds", 0.0),
		0.0,
		MAX_PERSISTED_FLOAT,
		0.0
	)
	_era_floor_index = (
		clampi(
			int(save.get_value("progression", "era_floor_index", 0)),
			0,
			EraProgression.get_era_count() - 1
		)
		if save.has_section_key("progression", "era_floor_index")
		else EraProgression.get_legacy_era_index(_total_runtime_seconds)
	)
	_campaign_completed = bool(save.get_value("progression", "campaign_completed", false))
	_campaign_completion_acknowledged = bool(save.get_value(
		"progression",
		"completion_acknowledged",
		false
	))
	_endless_mode = bool(save.get_value("progression", "endless_mode", false))
	_final_boss_defeated = _get_loaded_final_boss_defeated(
		loaded_save_version,
		_campaign_completed,
		bool(save.get_value("progression", "final_boss_defeated", false)),
		_endless_mode
	)
	if _endless_mode:
		_campaign_completed = true
		_campaign_completion_acknowledged = true
		_final_boss_defeated = true
	_pet_activity_range = String(save.get_value("settings", "pet_activity_range", "full"))
	if _pet_activity_range not in ["full", "right", "left"]:
		_pet_activity_range = "full"
	_language = resolve_saved_language(save)
	_selected_pet_id = String(save.get_value("pets", "selected_pet_id", ""))
	_pet_states = _sanitize_loaded_pet_states(save.get_value("pets", "states", {}))
	if loaded_save_version >= PET_UNLOCK_SAVE_VERSION:
		_unlocked_pet_ids = _sanitize_pet_id_list(
			save.get_value("pets", "unlocked_ids", PetCatalog.STARTER_UNLOCKED_PETS),
			PetCatalog.ACTIVE_DESKTOP_PETS
		)
		if not _unlocked_pet_ids.has("pet1"):
			_unlocked_pet_ids.push_front("pet1")
		_deployed_pet_ids = _sanitize_pet_id_list(
			save.get_value("pets", "deployed_ids", PetCatalog.STARTER_UNLOCKED_PETS),
			_unlocked_pet_ids
		)
	else:
		_unlocked_pet_ids = ["pet1"]
		_deployed_pet_ids = ["pet1"]
	for deployed_pet_id in _deployed_pet_ids.duplicate():
		if _host._is_pet_recovering(String(deployed_pet_id)):
			_deployed_pet_ids.erase(deployed_pet_id)
	if _deployed_pet_ids.is_empty():
		for unlocked_pet_id in _unlocked_pet_ids:
			if not _host._is_pet_recovering(String(unlocked_pet_id)):
				_deployed_pet_ids.append(String(unlocked_pet_id))
				break
	if not _selected_pet_id.is_empty() and not _unlocked_pet_ids.has(_selected_pet_id):
		_selected_pet_id = ""
	_pet_offering_buffs = _sanitize_loaded_offering_buffs(
		save.get_value("offerings", "active_buffs", {})
	)
	_shop_owned_counts = _sanitize_owned_counts(save.get_value("shop", "owned_counts", {}))
	# Removed combat-object save data is intentionally ignored. Desktop items use
	# their own namespace and are never inferred from an older save.
	_item_states = _sanitize_item_states(save.get_value("items", "states", {}))
	_battle_victories = clampi(
		int(save.get_value("achievements", "battle_victories", 0)),
		0,
		1_000_000_000
	)
	_claimed_achievement_ids = AchievementProgression.sanitize_claimed_ids(
		save.get_value("achievements", "claimed_ids", [])
	)
	_loaded_news_state = {
		"copy_version": save.get_value("news", "copy_version", 0),
		"history": save.get_value("news", "history", []),
		"next_id": save.get_value("news", "next_id", 1),
		"faith_tier": _get_loaded_news_faith_tier(
			loaded_save_version,
			save.get_value("news", "faith_tier", 0),
			_host._get_faith_growth_rate()
		),
		"follower_tier": save.get_value("news", "follower_tier", NewsFeed.get_follower_tier(_follower_count)),
		"recent_templates": save.get_value("news", "recent_templates", [])
	}
	var carried_value: Variant = save.get_value(
		"shop",
		"carried_offering",
		save.get_value("offerings", "carried", {})
	)
	if carried_value is Dictionary:
		_carried_offering = OfferingCatalog.normalize_offering(carried_value)
	else:
		_carried_offering.clear()
	_loaded_save_unix = sanitize_finite_float(
		save.get_value("meta", "saved_unix", 0.0),
		0.0,
		MAX_PERSISTED_FLOAT,
		0.0
	)
	var saved_menu_anchor = float(save.get_value("ui", "menu_handle_anchor", -1.0))
	_loaded_menu_handle_anchor = (
		clampf(saved_menu_anchor, 0.0, 1.0)
		if is_finite(saved_menu_anchor) and saved_menu_anchor >= 0.0
		else -1.0
	)


static func resolve_saved_language(save: ConfigFile) -> String:
	return LanguageSettings.sanitize(String(save.get_value(
		"settings",
		"language",
		LanguageSettings.DEFAULT_LANGUAGE
	)))


static func sanitize_finite_float(
	value: Variant,
	minimum: float,
	maximum: float,
	fallback: float
) -> float:
	var safe_minimum := minf(minimum, maximum)
	var safe_maximum := maxf(minimum, maximum)
	var numeric_value := float(value)
	if not is_finite(numeric_value):
		return clampf(fallback, safe_minimum, safe_maximum)
	return clampf(numeric_value, safe_minimum, safe_maximum)


static func load_config_with_backup(primary_path: String, backup_path: String) -> Dictionary:
	return SaveSlotRepository.load_config_with_backup(primary_path, backup_path, MAX_SAVE_FILE_BYTES)


static func save_config_with_backup(
	save: ConfigFile,
	primary_path: String,
	backup_path: String,
	temporary_path: String
) -> Error:
	return SaveSlotRepository.save_config_with_backup(
		save,
		primary_path,
		backup_path,
		temporary_path,
		MAX_SAVE_FILE_BYTES
	)

func _request_save() -> void:
	if not _persistence_enabled or _reset_in_progress or _save_slot_switch_in_progress:
		return
	_save_dirty = true
	_save_debounce_remaining = SAVE_DEBOUNCE_SECONDS

func _save_game() -> Error:
	if not _persistence_enabled or _reset_in_progress or _save_slot_switch_in_progress:
		return ERR_INVALID_PARAMETER
	var save = ConfigFile.new()
	save.set_value("meta", "version", SAVE_VERSION)
	save.set_value("meta", "saved_unix", Time.get_unix_time_from_system())
	save.set_value("economy", "faith_points", sanitize_finite_float(_faith_points, 0.0, MAX_PERSISTED_FLOAT, 0.0))
	save.set_value("economy", "lifetime_faith", sanitize_finite_float(_lifetime_faith, 0.0, MAX_PERSISTED_FLOAT, 0.0))
	save.set_value("economy", "followers", sanitize_finite_float(_follower_count, 0.0, MAX_PERSISTED_FLOAT, 0.0))
	save.set_value("economy", "gold_coins", CurrencyDisplay.sanitize_gold(_gold_coins))
	save.set_value("statistics", "total_runtime_seconds", sanitize_finite_float(_total_runtime_seconds, 0.0, MAX_PERSISTED_FLOAT, 0.0))
	save.set_value("progression", "era_floor_index", _era_floor_index)
	save.set_value("progression", "campaign_completed", _campaign_completed)
	save.set_value("progression", "final_boss_defeated", _final_boss_defeated)
	save.set_value(
		"progression",
		"completion_acknowledged",
		_campaign_completion_acknowledged
	)
	save.set_value("progression", "endless_mode", _endless_mode)
	save.set_value("settings", "pet_activity_range", _pet_activity_range)
	save.set_value("settings", "language", _language)
	save.set_value("pets", "selected_pet_id", _selected_pet_id)
	save.set_value("pets", "states", _pet_states.duplicate(true))
	save.set_value("pets", "unlocked_ids", _unlocked_pet_ids.duplicate())
	save.set_value("pets", "deployed_ids", _deployed_pet_ids.duplicate())
	save.set_value("shop", "owned_counts", _shop_owned_counts.duplicate(true))
	save.set_value("items", "states", _item_states.duplicate(true))
	save.set_value("achievements", "battle_victories", _battle_victories)
	save.set_value("achievements", "claimed_ids", _claimed_achievement_ids.duplicate())
	var news_state = _news_feed.get_state()
	save.set_value("news", "copy_version", news_state.get("copy_version", NewsFeed.NEWS_COPY_VERSION))
	save.set_value("news", "history", news_state.get("history", []))
	save.set_value("news", "next_id", news_state.get("next_id", 1))
	save.set_value("news", "faith_tier", news_state.get("faith_tier", 0))
	save.set_value("news", "follower_tier", news_state.get("follower_tier", 0))
	save.set_value("news", "recent_templates", news_state.get("recent_templates", []))
	save.set_value("shop", "carried_offering", _carried_offering.duplicate(true))
	save.set_value("offerings", "active_buffs", _pet_offering_buffs.duplicate(true))
	if _side_drawer != null and _side_drawer.has_method("get_menu_handle_anchor"):
		save.set_value("ui", "menu_handle_anchor", _side_drawer.call("get_menu_handle_anchor"))
	var save_result := _save_slots.save_active_slot(save)
	var save_error := int(save_result.get("error", ERR_INVALID_PARAMETER))
	if save_error != OK:
		push_warning("Could not save game data: %s" % error_string(save_error))
		_save_dirty = true
		_save_debounce_remaining = 5.0
		return save_error
	_save_dirty = false
	_save_debounce_remaining = 0.0
	return OK

func _apply_offline_progress() -> void:
	if _loaded_save_unix <= 0.0:
		return
	var elapsed_seconds = clampf(
		Time.get_unix_time_from_system() - _loaded_save_unix,
		0.0,
		OFFLINE_PROGRESS_MAX_SECONDS
	)
	_loaded_save_unix = 0.0
	if elapsed_seconds < 1.0:
		return
	var effective_seconds = elapsed_seconds * OFFLINE_PROGRESS_EFFICIENCY
	var faith_rate = _host._get_faith_growth_rate()
	_host._grant_faith(faith_rate * effective_seconds)
	_follower_count = FollowerProgression.advance(_follower_count, faith_rate, effective_seconds)


func _reset_game_progress() -> void:
	if _reset_in_progress:
		return
	Engine.time_scale = 1.0
	if _persistence_enabled:
		var slot_init_result := _save_slots.initialize()
		if not bool(slot_init_result.get("ok", false)):
			push_error("Could not reset save data: %s" % error_string(int(slot_init_result.get("error", ERR_FILE_NOT_FOUND))))
			return
		var reset_result := _save_slots.reset_slot(_save_slots.get_active_slot_id())
		if not bool(reset_result.get("ok", false)):
			push_error("Could not reset save data: %s" % error_string(int(reset_result.get("error", ERR_INVALID_PARAMETER))))
			return
	_reset_in_progress = true
	_persistence_enabled = false
	_save_dirty = false
	_save_debounce_remaining = 0.0
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		tree.call_deferred("reload_current_scene")


func get_save_slots() -> Array[Dictionary]:
	if not _persistence_enabled:
		return []
	var init_result := _save_slots.initialize()
	if not bool(init_result.get("ok", false)):
		return []
	return _save_slots.list_slots()


func get_active_save_slot_id() -> String:
	if not _persistence_enabled:
		return ""
	var init_result := _save_slots.initialize()
	if not bool(init_result.get("ok", false)):
		return ""
	return _save_slots.get_active_slot_id()


func create_save_slot(slot_id: String) -> Dictionary:
	var operation_result := _can_manage_save_slots()
	if not bool(operation_result.get("ok", false)):
		return operation_result
	if not _save_slots.is_slot_empty(slot_id):
		return _save_slot_failure("The selected save slot already contains data.")
	return _switch_to_save_slot(slot_id, true)


func switch_save_slot(slot_id: String) -> Dictionary:
	var operation_result := _can_manage_save_slots()
	if not bool(operation_result.get("ok", false)):
		return operation_result
	return _switch_to_save_slot(slot_id, false)


func rename_save_slot(slot_id: String, display_name: String) -> Dictionary:
	var operation_result := _can_manage_save_slots()
	if not bool(operation_result.get("ok", false)):
		return operation_result
	return _save_slots.rename_slot(slot_id, display_name)


func delete_save_slot(slot_id: String) -> Dictionary:
	var operation_result := _can_manage_save_slots()
	if not bool(operation_result.get("ok", false)):
		return operation_result
	return _save_slots.delete_slot(slot_id)


func _switch_to_save_slot(slot_id: String, creating_empty_slot: bool) -> Dictionary:
	if not SaveSlotRepository.is_valid_slot_id(slot_id):
		return _save_slot_failure("The requested save slot is invalid.")
	if _save_slots.get_active_slot_id() == slot_id:
		return {"ok": true, "error": OK, "already_active": true}
	if creating_empty_slot and not _save_slots.is_slot_empty(slot_id):
		return _save_slot_failure("The selected save slot already contains data.")
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return _save_slot_failure("The save slot could not be switched because the game scene is unavailable.")
	var save_error := _save_game()
	if save_error != OK:
		return _save_slot_failure("The current save could not be written, so the slot was not switched.", save_error)
	_save_slot_switch_in_progress = true
	var select_result := _save_slots.create_slot(slot_id) if creating_empty_slot else _save_slots.select_slot(slot_id)
	if not bool(select_result.get("ok", false)):
		_save_slot_switch_in_progress = false
		return select_result
	_save_dirty = false
	_save_debounce_remaining = 0.0
	tree.call_deferred("reload_current_scene")
	return {"ok": true, "error": OK, "reloading": true}


func _can_manage_save_slots() -> Dictionary:
	if not _persistence_enabled:
		return _save_slot_failure("Save-slot management is unavailable because persistence is disabled.")
	if _reset_in_progress or _save_slot_switch_in_progress:
		return _save_slot_failure("A save operation is already in progress.")
	if _battle_active:
		return _save_slot_failure("Finish the current battle before changing save slots.")
	if not _carried_offering.is_empty() or not _pending_offering_feeds.is_empty():
		return _save_slot_failure("Finish or cancel the current offering before changing save slots.")
	if not _coin_drops.is_empty():
		return _save_slot_failure("Collect the visible coins before changing save slots so their rewards are not lost.")
	var init_result := _save_slots.initialize()
	if not bool(init_result.get("ok", false)):
		return _save_slot_failure("Save-slot data could not be initialized.", int(init_result.get("error", ERR_INVALID_PARAMETER)))
	return {"ok": true, "error": OK}


func _save_slot_failure(reason: String, error_code := ERR_INVALID_PARAMETER) -> Dictionary:
	push_warning(reason)
	return {"ok": false, "error": error_code, "reason": reason}


func _update_autosave(delta: float) -> void:
	if not _persistence_enabled or _reset_in_progress or _save_slot_switch_in_progress:
		return
	var saved_this_tick = false
	if _save_dirty:
		_save_debounce_remaining = maxf(0.0, _save_debounce_remaining - maxf(0.0, delta))
		if _save_debounce_remaining <= 0.0:
			_save_game()
			saved_this_tick = not _save_dirty
	_autosave_timer += maxf(0.0, delta)
	if _autosave_timer < AUTOSAVE_INTERVAL_SECONDS:
		return
	_autosave_timer = 0.0
	if not saved_this_tick:
		_save_game()

func _sanitize_loaded_pet_states(raw_value: Variant) -> Dictionary:
	var sanitized = {}
	if not raw_value is Dictionary:
		return sanitized
	var raw_states: Dictionary = raw_value
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id = String(pet_id_value)
		var state_value: Variant = raw_states.get(pet_id, {})
		if not state_value is Dictionary:
			continue
		var raw_state: Dictionary = state_value
		var sanitized_level = clampi(
			int(raw_state.get("upgrade_level", raw_state.get("count", 1))),
			1,
			PetProgression.MAX_LEVEL
		)
		var state = {
			"upgrade_level": sanitized_level
		}
		if sanitized_level >= 100 and PetCatalog.has_evolution(pet_id):
			state["evolved"] = true
		var recover_until = maxf(0.0, float(raw_state.get("recover_until", 0.0)))
		var recovery_duration = clampf(float(raw_state.get("recovery_duration", 0.0)), 0.0, 3600.0)
		var recovery_started_at = maxf(0.0, float(raw_state.get("recovery_started_at", recover_until - recovery_duration)))
		if recover_until > Time.get_unix_time_from_system() and recovery_duration > 0.0:
			state["recovery_started_at"] = recovery_started_at
			state["recover_until"] = recover_until
			state["recovery_duration"] = recovery_duration
		var custom_name = String(raw_state.get("name", "")).strip_edges().left(40)
		if custom_name.is_empty():
			state.erase("name")
		else:
			state["name"] = custom_name
		sanitized[pet_id] = state
	return sanitized

func _sanitize_owned_counts(raw_value: Variant) -> Dictionary:
	var sanitized = {}
	if not raw_value is Dictionary:
		return sanitized
	var raw_counts: Dictionary = raw_value
	for key_value in raw_counts:
		var key = String(key_value)
		if key.is_empty():
			continue
		sanitized[key] = clampi(int(raw_counts[key_value]), 0, 100000)
	return sanitized

func _sanitize_item_states(raw_value: Variant) -> Dictionary:
	var sanitized := {}
	if not raw_value is Dictionary:
		return sanitized
	var raw_states: Dictionary = raw_value
	for item_id_value in DesktopItemCatalog.ITEM_IDS:
		var item_id := String(item_id_value)
		var raw_state_value: Variant = raw_states.get(item_id, {})
		if not raw_state_value is Dictionary:
			continue
		var raw_state: Dictionary = raw_state_value
		# Ownership is an explicit purchase flag. A malformed/missing field must
		# not silently mint a free reusable desktop item on load.
		if not bool(raw_state.get("owned", false)):
			continue
		var definition := DesktopItemCatalog.get_definition(item_id)
		if definition.is_empty():
			continue
		var state := {
			"owned": true,
			"deployed": bool(raw_state.get("deployed", false)),
			"position_x": clampf(float(raw_state.get("position_x", -1.0)), -10000.0, 10000.0)
		}
		if item_id == "sofa":
			_sanitize_sofa_runtime_state(raw_state, state)
		sanitized[item_id] = state
	return sanitized


func _sanitize_sofa_runtime_state(raw_state: Dictionary, state: Dictionary) -> void:
	if not bool(state.get("deployed", false)):
		return
	var now: float = float(_host._get_now_seconds())
	var raw_session_value: Variant = raw_state.get("sofa_session", {})
	if raw_session_value is Dictionary:
		var raw_session: Dictionary = raw_session_value
		var pet_id := String(raw_session.get("pet_id", ""))
		var phase := String(raw_session.get("phase", ""))
		if PetCatalog.ACTIVE_DESKTOP_PETS.has(pet_id) and phase == "approaching":
			# Version 18 stored this under ends_at before the guest reached the
			# sofa. Read it once as an approach timeout, then persist the clearer
			# field so only seated visits ever carry a comfort expiry.
			var approach_expires_at := sanitize_finite_float(
				raw_session.get("approach_expires_at", raw_session.get("ends_at", 0.0)),
				0.0,
				now + 3600.0,
				0.0
			)
			if approach_expires_at > now:
				state["sofa_session"] = {
					"pet_id": pet_id,
					"phase": phase,
					"approach_expires_at": approach_expires_at
				}
				return
		elif PetCatalog.ACTIVE_DESKTOP_PETS.has(pet_id) and phase == "seated":
			var ends_at := sanitize_finite_float(
				raw_session.get("ends_at", 0.0),
				0.0,
				now + 3600.0,
				0.0
			)
			if ends_at > now:
				state["sofa_session"] = {
					"pet_id": pet_id,
					"phase": phase,
					"ends_at": ends_at
				}
				return
	var next_visit_at := sanitize_finite_float(
		raw_state.get("sofa_next_visit_at", 0.0),
		0.0,
		now + 3600.0,
		0.0
	)
	if next_visit_at > now:
		state["sofa_next_visit_at"] = next_visit_at

func _sanitize_loaded_offering_buffs(raw_value: Variant) -> Dictionary:
	var sanitized = {}
	if not raw_value is Dictionary:
		return sanitized
	var now = _host._get_now_seconds()
	var raw_buffs: Dictionary = raw_value
	for pet_id_value in raw_buffs:
		var pet_id = String(pet_id_value)
		if not PetCatalog.DEFINITIONS.has(pet_id):
			continue
		var buff_value: Variant = raw_buffs[pet_id_value]
		if not buff_value is Dictionary:
			continue
		var buff: Dictionary = buff_value
		var multiplier = clampf(float(buff.get("multiplier", 1.0)), 1.0, 100.0)
		var expires_at = clampf(float(buff.get("expires_at", 0.0)), 0.0, now + 3600.0)
		if multiplier <= 1.0 or expires_at <= now:
			continue
		sanitized[pet_id] = {
			"multiplier": multiplier,
			"expires_at": expires_at,
			"offering_name": String(buff.get("offering_name", "贡品")).strip_edges().left(40)
		}
	return sanitized
