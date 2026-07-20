extends "res://scripts/runtime/main_context.gd"

func _load_game() -> void:
	if not _persistence_enabled:
		return
	var save = ConfigFile.new()
	var load_error = save.load(SAVE_PATH)
	if load_error == ERR_FILE_NOT_FOUND:
		return
	if load_error != OK:
		push_warning("Could not load save data: %s" % error_string(load_error))
		return
	var loaded_save_version = maxi(0, int(save.get_value("meta", "version", 0)))

	_faith_points = maxf(0.0, float(save.get_value("economy", "faith_points", 0.0)))
	_lifetime_faith = maxf(
		_faith_points,
		float(save.get_value("economy", "lifetime_faith", _faith_points))
	)
	_follower_count = maxf(0.0, float(save.get_value("economy", "followers", 0.0)))
	_gold_coins = CurrencyDisplay.sanitize_gold(int(save.get_value("economy", "gold_coins", 0)))
	_total_runtime_seconds = maxf(0.0, float(save.get_value("statistics", "total_runtime_seconds", 0.0)))
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
	if loaded_save_version >= PET_UNLOCK_SAVE_VERSION:
		_gacha_draw_count = clampi(int(save.get_value("gacha", "draw_count", 0)), 0, 1000000)
		_gacha_pity_count = clampi(
			int(save.get_value("gacha", "pity_count", 0)),
			0,
			GachaProgression.NEW_PET_PITY_DRAWS - 1
		)
		_gacha_history = _sanitize_gacha_history(save.get_value("gacha", "history", []))
	else:
		_gacha_draw_count = 0
		_gacha_pity_count = 0
		_gacha_history.clear()
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
	_loaded_save_unix = maxf(0.0, float(save.get_value("meta", "saved_unix", 0.0)))
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

func _request_save() -> void:
	if not _persistence_enabled or _reset_in_progress:
		return
	_save_dirty = true
	_save_debounce_remaining = SAVE_DEBOUNCE_SECONDS

func _save_game() -> void:
	if not _persistence_enabled or _reset_in_progress:
		return
	var save = ConfigFile.new()
	save.set_value("meta", "version", SAVE_VERSION)
	save.set_value("meta", "saved_unix", Time.get_unix_time_from_system())
	save.set_value("economy", "faith_points", maxf(0.0, _faith_points))
	save.set_value("economy", "lifetime_faith", maxf(0.0, _lifetime_faith))
	save.set_value("economy", "followers", maxf(0.0, _follower_count))
	save.set_value("economy", "gold_coins", CurrencyDisplay.sanitize_gold(_gold_coins))
	save.set_value("statistics", "total_runtime_seconds", maxf(0.0, _total_runtime_seconds))
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
	save.set_value("gacha", "draw_count", _gacha_draw_count)
	save.set_value("gacha", "pity_count", _gacha_pity_count)
	save.set_value("gacha", "history", _gacha_history.duplicate(true))
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
	var save_error = save.save(SAVE_PATH)
	if save_error != OK:
		push_warning("Could not save game data: %s" % error_string(save_error))
		_save_dirty = true
		_save_debounce_remaining = 5.0
		return
	_save_dirty = false
	_save_debounce_remaining = 0.0

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
	var absolute_save_path := ProjectSettings.globalize_path(SAVE_PATH)
	if FileAccess.file_exists(absolute_save_path):
		var remove_error := DirAccess.remove_absolute(absolute_save_path)
		if remove_error != OK:
			push_error("Could not reset save data: %s" % error_string(remove_error))
			return
	_reset_in_progress = true
	_persistence_enabled = false
	_save_dirty = false
	_save_debounce_remaining = 0.0
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		tree.call_deferred("reload_current_scene")

func _update_autosave(delta: float) -> void:
	if not _persistence_enabled or _reset_in_progress:
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

func _sanitize_gacha_history(raw_value: Variant) -> Array[Dictionary]:
	var sanitized: Array[Dictionary] = []
	if not raw_value is Array:
		return sanitized
	for entry_value in raw_value:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var pet_id = String(entry.get("pet_id", ""))
		var pool_entry = GachaProgression.get_pool_entry(pet_id)
		if pool_entry.is_empty():
			continue
		var is_new = bool(entry.get("is_new", false))
		pool_entry["is_new"] = is_new
		pool_entry["duplicate_faith"] = (
			0
			if is_new
			else clampi(
				int(entry.get("duplicate_faith", 0)),
				0,
				GachaProgression.MAX_DUPLICATE_FAITH_REWARD
			)
		)
		pool_entry["name"] = String(
			entry.get("name", PetCatalog.get_definition(pet_id).get("name", pet_id))
		).strip_edges().left(40)
		sanitized.append(pool_entry)
		if sanitized.size() >= 10:
			break
	return sanitized
