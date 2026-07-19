extends "res://scripts/runtime/main_context.gd"

## Pet progression, economy, gacha, evolution, settings, and commands.

func _is_pet_unlocked(pet_id: String) -> bool:
	return not pet_id.is_empty() and _unlocked_pet_ids.has(pet_id)

func _get_inventory_pet_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for pet_id_value in _unlocked_pet_ids:
		var pet_id = String(pet_id_value)
		if _deployed_pet_ids.has(pet_id):
			continue
		var entry = PetCatalog.make_inventory_entry(pet_id)
		entry["name"] = _get_pet_display_name(pet_id)
		var state = _get_pet_state(pet_id)
		entry["texture"] = String(PetCatalog.get_runtime_definition(pet_id, bool(state.get("evolved", false))).get("icon", entry.get("texture", "")))
		entry["level"] = PetProgression.progression_level(state)
		entry["evolved"] = bool(state.get("evolved", false))
		entry["has_evolution"] = PetCatalog.can_evolve(pet_id)
		entry["age_text"] = _get_pet_age_text(PetCatalog.get_definition(pet_id))
		entry["personality"] = PetCatalog.get_localized_field(pet_id, "personality", _language)
		entry.merge(_get_pet_recovery_info(pet_id), true)
		entries.append(entry)
	return entries

func _select_pet(actor: Node2D) -> void:
	if actor == null or not is_instance_valid(actor):
		return

	var pet_id = _host._get_actor_pet_id(actor)
	if pet_id.is_empty():
		return

	_selected_pet_id = pet_id
	_ensure_pet_state(pet_id)
	_host._refresh_pet_stats()

func _ensure_pet_state(pet_id: String) -> void:
	if not _pet_states.has(pet_id) or not _pet_states[pet_id] is Dictionary:
		_pet_states[pet_id] = {"upgrade_level": 1}
		return

	var state: Dictionary = _pet_states[pet_id]
	var level = clampi(
		int(state.get("upgrade_level", state.get("count", 1))),
		1,
		PetProgression.MAX_LEVEL
	)
	for key in state.keys():
		if key not in ["upgrade_level", "name", "evolved", "recovery_started_at", "recover_until", "recovery_duration"]:
			state.erase(key)
	state["upgrade_level"] = level
	if bool(state.get("evolved", false)) and PetCatalog.has_evolution(pet_id):
		state["evolved"] = true
	else:
		state.erase("evolved")
	var custom_name = String(state.get("name", "")).strip_edges().left(40)
	if custom_name.is_empty():
		state.erase("name")
	else:
		state["name"] = custom_name
	var recover_until = maxf(0.0, float(state.get("recover_until", 0.0)))
	var recovery_duration = clampf(float(state.get("recovery_duration", 0.0)), 0.0, 3600.0)
	if recover_until <= _host._get_now_seconds() or recovery_duration <= 0.0:
		state.erase("recovery_started_at")
		state.erase("recover_until")
		state.erase("recovery_duration")
	else:
		state["recovery_started_at"] = maxf(0.0, float(state.get("recovery_started_at", recover_until - recovery_duration)))
		state["recover_until"] = recover_until
		state["recovery_duration"] = recovery_duration
	_pet_states[pet_id] = state

func _get_pet_state(pet_id: String) -> Dictionary:
	# Loaded and externally supplied states are sanitized at their mutation
	# boundaries. Re-sanitizing on every economy read used to walk and rewrite the
	# same dictionary dozens of times per background tick.
	if not _pet_states.has(pet_id) or not _pet_states[pet_id] is Dictionary:
		_ensure_pet_state(pet_id)
	return _pet_states[pet_id]

func _is_pet_recovering(pet_id: String, now := -1.0) -> bool:
	if pet_id.is_empty() or not _pet_states.has(pet_id):
		return false
	var check_time = _host._get_now_seconds() if now < 0.0 else now
	var state: Dictionary = _pet_states[pet_id]
	return float(state.get("recover_until", 0.0)) > check_time

func _get_pet_recovery_info(pet_id: String) -> Dictionary:
	var state = _get_pet_state(pet_id)
	var now = _host._get_now_seconds()
	var recover_until = float(state.get("recover_until", 0.0))
	var duration = maxf(0.0, float(state.get("recovery_duration", 0.0)))
	var remaining = maxf(0.0, recover_until - now)
	var recovering = remaining > 0.0 and duration > 0.0
	return {
		"recovering": recovering,
		"recovery_seconds_remaining": remaining,
		"recovery_progress": clampf(1.0 - remaining / maxf(0.001, duration), 0.0, 1.0) if recovering else 1.0
	}

func _update_recovery_states(delta: float) -> void:
	_recovery_ui_refresh_time += maxf(0.0, delta)
	if _recovery_ui_refresh_time < 1.0:
		return
	_recovery_ui_refresh_time = 0.0
	var now = _host._get_now_seconds()
	var has_active_recovery = false
	var recovery_completed = false
	for pet_id_value in _pet_states.keys():
		var pet_id = String(pet_id_value)
		var state: Dictionary = _pet_states[pet_id]
		var recover_until = float(state.get("recover_until", 0.0))
		if recover_until <= 0.0:
			continue
		if recover_until > now:
			has_active_recovery = true
			continue
		state.erase("recovery_started_at")
		state.erase("recover_until")
		state.erase("recovery_duration")
		_pet_states[pet_id] = state
		recovery_completed = true
	if has_active_recovery or recovery_completed:
		_pet_upgrade_stats_dirty = true
		if _inventory_window != null and _inventory_window.visible:
			_host._sync_inventory_window()
	if recovery_completed:
		_host._refresh_pet_stats(true)
		_host._request_save()

func _get_pet_upgrade_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var level_cap: int = _host._get_campaign_level_cap()
	for pet_id_value in _unlocked_pet_ids:
		var pet_id = String(pet_id_value)
		var state = _get_pet_state(pet_id)
		var level = PetProgression.progression_level(state)
		var pet_data = PetCatalog.get_definition(pet_id)
		var is_max_level = level >= level_cap
		var cost = 0 if is_max_level else _get_upgrade_cost(pet_id)
		var offering_multiplier = _get_pet_offering_multiplier(pet_id)
		var recovery_info = _get_pet_recovery_info(pet_id)
		var recovering = bool(recovery_info.get("recovering", false))
		var current_fps = (
			_get_pet_faith_per_second(pet_id, level)
			* offering_multiplier
			* _get_total_faith_multiplier()
		)
		var next_fps = _get_pet_faith_per_second(
			pet_id,
			mini(level_cap, level + 1)
		) * offering_multiplier * _get_total_faith_multiplier()
		var current_money_rate = _get_pet_money_value_per_minute(pet_id, level)
		var next_money_rate = _get_pet_money_value_per_minute(
			pet_id,
			mini(level_cap, level + 1)
		)
		if recovering:
			current_fps = 0.0
			current_money_rate = 0.0
		entries.append({
			"id": pet_id,
			"name": _get_pet_display_name(pet_id),
			"description": PetCatalog.get_localized_field(pet_id, "description", _language),
			"rarity_stars": clampi(int(pet_data.get("rarity_stars", 1)), 1, 5),
			"age_text": _get_pet_age_text(pet_data),
			"personality": PetCatalog.get_localized_field(pet_id, "personality", _language),
			"level": level,
			"evolved": bool(state.get("evolved", false)),
			"has_evolution": PetCatalog.can_evolve(pet_id),
			"evolution_name": PetCatalog.get_localized_evolution_name(pet_id, _language),
			"icon": String(PetCatalog.get_runtime_definition(pet_id, bool(state.get("evolved", false))).get("icon", "")),
			"evolution_icon": String(PetCatalog.get_evolution_definition(pet_id).get("icon", pet_data.get("icon", ""))),
			"is_max_level": is_max_level,
			"cost": cost,
			"current_fps": current_fps,
			"next_fps": next_fps,
			"next_growth_bonus": maxf(0.0, next_fps - current_fps),
			"total_growth_bonus": current_fps,
			"current_money_rate": current_money_rate,
			"next_money_rate": next_money_rate,
			"money_rate_gain": maxf(0.0, next_money_rate - current_money_rate),
			"offering_multiplier": offering_multiplier,
			"offering_seconds_remaining": _get_pet_offering_seconds_remaining(pet_id),
			"affordable": not is_max_level and int(floor(_faith_points)) >= cost
		})
		entries[entries.size() - 1].merge(recovery_info, true)

	return entries

func _get_pet_age_text(pet_data: Dictionary) -> String:
	if not pet_data.has("base_age_years"):
		var pet_id := String(pet_data.get("id", ""))
		var localized_age := PetCatalog.get_localized_field(pet_id, "age", _language)
		if not localized_age.is_empty():
			return localized_age
		return "Unknown" if _language == "en" else "年龄不详"
	var elapsed_years = EraProgression.get_elapsed_calendar_years(_total_runtime_seconds)
	var age_years = maxi(0, int(pet_data.get("base_age_years", 0)) + elapsed_years)
	var qualifier = String(pet_data.get("age_qualifier", ""))
	if _language == "en":
		if qualifier == "about":
			return "about %d years" % age_years
		if qualifier == "at_least":
			return "at least %d years" % age_years
		return "%d years" % age_years
	if qualifier == "about":
		return "约%d岁" % age_years
	if qualifier == "at_least":
		return "至少%d岁" % age_years
	return "%d岁" % age_years

func _get_upgrade_cost(pet_id: String) -> int:
	var pet_data = PetCatalog.get_definition(pet_id)
	var state = _get_pet_state(pet_id)
	return PetProgression.upgrade_cost(pet_data, state)

func _get_faith_growth_rate() -> float:
	if _background_faith_growth_cache_active:
		return _background_faith_growth_cache
	return _calculate_faith_growth_rate()

func _calculate_faith_growth_rate() -> float:
	var total_fps = 0.0
	for pet_id_value in _unlocked_pet_ids:
		var pet_id = String(pet_id_value)
		if _is_pet_recovering(pet_id):
			continue
		var state = _get_pet_state(pet_id)
		total_fps += (
			_get_pet_faith_per_second(pet_id, PetProgression.progression_level(state))
			* _get_pet_offering_multiplier(pet_id)
		)

	return total_fps * _get_total_faith_multiplier()


func _get_baseline_faith_growth_rate() -> float:
	var total_fps := 0.0
	for pet_id_value in _unlocked_pet_ids:
		var pet_id := String(pet_id_value)
		var state := _get_pet_state(pet_id)
		total_fps += _get_pet_faith_per_second(
			pet_id,
			PetProgression.progression_level(state)
		)
	return total_fps * _get_total_faith_multiplier()

func _get_follower_growth_rate() -> float:
	return FollowerProgression.followers_per_second(_get_faith_growth_rate())

func _get_pet_faith_per_second(pet_id: String, level: int) -> float:
	var value = PetProgression.faith_per_second(PetCatalog.get_definition(pet_id), level)
	return value * (PetCatalog.EVOLUTION_PRODUCTION_MULTIPLIER if bool(_get_pet_state(pet_id).get("evolved", false)) else 1.0)

func _get_pet_money_value_per_minute(pet_id: String, level: int) -> float:
	var value = PetProgression.money_drop_value_per_minute(PetCatalog.get_definition(pet_id), level)
	return value * (PetCatalog.EVOLUTION_PRODUCTION_MULTIPLIER if bool(_get_pet_state(pet_id).get("evolved", false)) else 1.0)

func _get_pet_offering_multiplier(pet_id: String, now := -1.0) -> float:
	var buff_value: Variant = _pet_offering_buffs.get(pet_id, {})
	if not buff_value is Dictionary:
		return 1.0
	var buff: Dictionary = buff_value
	var current_time = _host._get_now_seconds() if now < 0.0 else now
	if float(buff.get("expires_at", 0.0)) <= current_time:
		return 1.0
	return maxf(1.0, float(buff.get("multiplier", 1.0)))

func _get_pet_offering_seconds_remaining(pet_id: String, now := -1.0) -> float:
	var buff_value: Variant = _pet_offering_buffs.get(pet_id, {})
	if not buff_value is Dictionary:
		return 0.0
	var current_time = _host._get_now_seconds() if now < 0.0 else now
	return maxf(0.0, float((buff_value as Dictionary).get("expires_at", 0.0)) - current_time)

func _update_pet_offering_buffs() -> void:
	if _pet_offering_buffs.is_empty():
		return
	var now = _host._get_now_seconds()
	var changed = false
	for pet_id_value in _pet_offering_buffs.keys().duplicate():
		var pet_id = String(pet_id_value)
		if _get_pet_offering_seconds_remaining(pet_id, now) > 0.0:
			continue
		_pet_offering_buffs.erase(pet_id)
		changed = true
	if changed:
		_pet_upgrade_stats_dirty = true

func _get_total_faith_multiplier() -> float:
	return GLOBAL_FAITH_MULTIPLIER * BUFF_FAITH_MULTIPLIER

func _get_pet_display_name(pet_id: String) -> String:
	var state = _get_pet_state(pet_id)
	var custom_name = String(state.get("name", "")).strip_edges()
	if not custom_name.is_empty():
		return custom_name

	return PetCatalog.get_localized_name(pet_id, _language)

func _apply_pet_display_name(pet_id: String) -> void:
	for pet in _pets:
		if not is_instance_valid(pet):
			continue
		if _host._get_actor_pet_id(pet) != pet_id:
			continue
		if pet.has_method("set_display_name"):
			pet.call("set_display_name", _get_pet_display_name(pet_id))

func _set_pet_custom_name(pet_id: String, custom_name: String) -> void:
	if pet_id.is_empty():
		return

	var state = _get_pet_state(pet_id)
	custom_name = custom_name.strip_edges().left(40)
	if custom_name.is_empty():
		state.erase("name")
	else:
		state["name"] = custom_name
	_pet_states[pet_id] = state

	_apply_pet_display_name(pet_id)
	var display_name = _get_pet_display_name(pet_id)
	if _inventory_window != null and _inventory_window.has_method("set_pet_name"):
		_inventory_window.call("set_pet_name", pet_id, custom_name)
	if _side_drawer != null and _side_drawer.has_method("set_pet_name"):
		_side_drawer.call("set_pet_name", pet_id, display_name)
	_pet_upgrade_stats_dirty = true

func _grant_faith(amount: float) -> void:
	var safe_amount = maxf(0.0, amount)
	if safe_amount <= 0.0:
		return
	_faith_points += safe_amount
	_lifetime_faith += safe_amount

func _update_faith(delta: float) -> void:
	_grant_faith(_get_faith_growth_rate() * delta)
	_host._refresh_faith_display()
	_stats_refresh_timer += delta
	if _stats_refresh_timer >= UI_REFRESH_INTERVAL:
		_stats_refresh_timer = 0.0
		_host._refresh_pet_stats()

func _update_followers(delta: float) -> void:
	_follower_count = FollowerProgression.advance(
		_follower_count,
		_get_faith_growth_rate(),
		delta
	)
	var follower_count = int(floor(_follower_count))
	if follower_count != _last_reported_follower_count:
		_last_reported_follower_count = follower_count
		_host._refresh_follower_display()

func _on_gacha_draw_requested(draw_amount: int = 1) -> void:
	if _gacha_window == null:
		return
	if _gacha_batch_active:
		# A stale/direct second signal must not mutate the active batch or reserve
		# another copy of its gold. In particular, do not mark a newly-replaced
		# window busy for a result owned by the original request window.
		return
	var safe_draw_amount = clampi(draw_amount, 1, GachaProgression.MAX_BATCH_DRAWS)
	var reserved_cost = int(round(GachaProgression.draw_cost_total(
		_gacha_draw_count,
		safe_draw_amount
	)))
	if _gold_coins < reserved_cost:
		_set_gacha_request_pending(_gacha_window, false)
		_host._sync_gacha_state()
		return

	var owned_lookup = GachaProgression.make_unlocked_lookup(_unlocked_pet_ids)
	# Gacha stages use permanent production only. A short offering buff cannot
	# temporarily open a late-game pet and skip the intended growth curve.
	var faith_growth_rate := maxf(0.0, _get_baseline_faith_growth_rate())
	var locked_pool = GachaProgression.make_locked_pool(
		owned_lookup,
		faith_growth_rate
	)
	var valid_pet_ids = {}
	var pet_names = {}
	for pool_entry_value in GachaProgression.PET_POOL:
		var pool_entry: Dictionary = pool_entry_value
		var pool_pet_id = String(pool_entry.get("pet_id", ""))
		valid_pet_ids[pool_pet_id] = true
		pet_names[pool_pet_id] = _get_pet_display_name(pool_pet_id)

	_gacha_batch_token += 1
	_gacha_batch_active = true
	_gold_coins -= reserved_cost
	_gacha_batch_state = {
		"token": _gacha_batch_token,
		"remaining": safe_draw_amount,
		"reserved_cost": reserved_cost,
		"spent_cost": 0,
		"results": [],
		"owned_lookup": owned_lookup,
		"locked_pool": locked_pool,
		"faith_growth_rate": faith_growth_rate,
		"valid_pet_ids": valid_pet_ids,
		"pet_names": pet_names,
		"new_names": [],
		"new_pet_ids": [],
		"seen_new_ids": {},
		"first_new_pet_id": "",
		"duplicate_faith_total": 0,
		"inventory_changed": false,
		"news_item_name": "",
		"news_item_name_en": "",
		"news_item_name_zh": "",
		"window_ref": weakref(_gacha_window)
	}
	_set_gacha_request_pending(_gacha_window, true)
	# Reflect the reserved balance immediately without rebuilding other UI.
	_host._sync_gacha_state()
	if is_inside_tree():
		call_deferred("_process_gacha_draw_batch", _gacha_batch_token)

func _process_gacha_draw_batch(batch_token: int = -1) -> void:
	if not _gacha_batch_active:
		return
	var active_token = int(_gacha_batch_state.get("token", -1))
	if batch_token < 0:
		batch_token = active_token
	if batch_token != active_token:
		return

	var frame_started_usec = Time.get_ticks_usec()
	var processed_this_frame = 0
	var remaining = maxi(0, int(_gacha_batch_state.get("remaining", 0)))
	var spent_cost = maxi(0, int(_gacha_batch_state.get("spent_cost", 0)))
	var results: Array = _gacha_batch_state.get("results", [])
	var owned_lookup: Dictionary = _gacha_batch_state.get("owned_lookup", {})
	var locked_pool: Array = _gacha_batch_state.get("locked_pool", [])
	var faith_growth_rate = maxf(
		0.0,
		float(_gacha_batch_state.get("faith_growth_rate", 0.0))
	)
	var valid_pet_ids: Dictionary = _gacha_batch_state.get("valid_pet_ids", {})
	var pet_names: Dictionary = _gacha_batch_state.get("pet_names", {})
	var new_names: Array = _gacha_batch_state.get("new_names", [])
	var new_pet_ids: Array = _gacha_batch_state.get("new_pet_ids", [])
	var seen_new_ids: Dictionary = _gacha_batch_state.get("seen_new_ids", {})
	var duplicate_faith_total = maxi(
		0,
		int(_gacha_batch_state.get("duplicate_faith_total", 0))
	)

	while remaining > 0 and processed_this_frame < GACHA_BATCH_MAX_DRAWS_PER_FRAME:
		var cost = GachaProgression.draw_cost(_gacha_draw_count)
		var result = GachaProgression.roll_pet_with_context(
			_rng.randf(),
			owned_lookup,
			locked_pool,
			_gacha_pity_count,
			faith_growth_rate
		)
		if result.is_empty():
			remaining = 0
			_gacha_batch_state["failed"] = true
			break

		var pet_id = String(result.get("pet_id", ""))
		if pet_id.is_empty() or not valid_pet_ids.has(pet_id):
			remaining = 0
			_gacha_batch_state["failed"] = true
			break

		spent_cost += cost
		var result_pet_state := _get_pet_state(pet_id)
		var result_custom_name := String(result_pet_state.get("name", "")).strip_edges()
		result["use_localized_name"] = result_custom_name.is_empty()
		if not result_custom_name.is_empty():
			result["custom_name"] = result_custom_name
		result["name"] = String(pet_names.get(pet_id, pet_id))
		if bool(result.get("is_new", false)):
			_ensure_pet_state(pet_id)
			if not owned_lookup.has(pet_id):
				owned_lookup[pet_id] = true
				_unlocked_pet_ids.append(pet_id)
				for locked_index in locked_pool.size():
					var locked_entry: Dictionary = locked_pool[locked_index]
					if String(locked_entry.get("pet_id", "")) == pet_id:
						locked_pool.remove_at(locked_index)
						break
			if not seen_new_ids.has(pet_id):
				seen_new_ids[pet_id] = true
				new_names.append(String(result.get("name", pet_id)))
				new_pet_ids.append(pet_id)
				if String(_gacha_batch_state.get("first_new_pet_id", "")).is_empty():
					_gacha_batch_state["first_new_pet_id"] = pet_id
			_gacha_batch_state["inventory_changed"] = true
		else:
			var duplicate_faith = GachaProgression.duplicate_faith_reward(cost, result)
			_faith_points += float(duplicate_faith)
			result["duplicate_faith"] = duplicate_faith
			duplicate_faith_total += duplicate_faith

		_gacha_pity_count = GachaProgression.next_pity_count(_gacha_pity_count, result)
		_gacha_draw_count += 1
		_gacha_history.push_front(result.duplicate(true))
		if _gacha_history.size() > 10:
			_gacha_history.resize(10)
		results.append(result)
		if (
			String(_gacha_batch_state.get("news_item_name", "")).is_empty()
			or bool(result.get("is_new", false))
		):
			_gacha_batch_state["news_item_name"] = String(result.get("name", "未知宠物"))
			_gacha_batch_state["news_item_name_en"] = (
				result_custom_name
				if not result_custom_name.is_empty()
				else PetCatalog.get_localized_name(pet_id, "en")
			)
			_gacha_batch_state["news_item_name_zh"] = (
				result_custom_name
				if not result_custom_name.is_empty()
				else PetCatalog.get_localized_name(pet_id, "zh")
			)

		remaining -= 1
		processed_this_frame += 1
		if (
			processed_this_frame % GACHA_BATCH_BUDGET_CHECK_INTERVAL == 0
			and Time.get_ticks_usec() - frame_started_usec >= GACHA_BATCH_FRAME_BUDGET_USEC
		):
			break

	_gacha_batch_state["remaining"] = remaining
	_gacha_batch_state["spent_cost"] = spent_cost
	_gacha_batch_state["duplicate_faith_total"] = duplicate_faith_total
	if remaining <= 0:
		_finish_gacha_draw_batch(active_token)
		return
	if is_inside_tree():
		call_deferred("_process_gacha_draw_batch", active_token)

func _finish_gacha_draw_batch(batch_token: int) -> void:
	if not _gacha_batch_active or batch_token != int(_gacha_batch_state.get("token", -1)):
		return
	var completed_state = _gacha_batch_state
	_gacha_batch_active = false
	_gacha_batch_state = {}

	var reserved_cost = maxi(0, int(completed_state.get("reserved_cost", 0)))
	var spent_cost = clampi(int(completed_state.get("spent_cost", 0)), 0, reserved_cost)
	_gold_coins += reserved_cost - spent_cost
	var results: Array = completed_state.get("results", [])
	var request_window_ref = completed_state.get("window_ref") as WeakRef
	var request_window: Variant = request_window_ref.get_ref() if request_window_ref != null else null

	if results.is_empty():
		_set_gacha_request_pending(request_window, false)
		_host._sync_gacha_state()
		return

	_unlocked_pet_ids = _sanitize_pet_id_list(
		_unlocked_pet_ids,
		PetCatalog.ACTIVE_DESKTOP_PETS
	)
	# Newly summoned pets arrive on the desktop immediately. Storage is reserved
	# for pets the player explicitly recalls later.
	for new_pet_id_value in completed_state.get("new_pet_ids", []):
		var new_pet_id := String(new_pet_id_value)
		if new_pet_id.is_empty() or not _is_pet_unlocked(new_pet_id) or _deployed_pet_ids.has(new_pet_id):
			continue
		_deployed_pet_ids.append(new_pet_id)
		var new_actor = _host._spawn_desktop_pet(new_pet_id)
		if new_actor == null:
			_deployed_pet_ids.erase(new_pet_id)
		else:
			_selected_pet_id = new_pet_id
	var batch_summary = {
		"new_names": (completed_state.get("new_names", []) as Array).duplicate(),
		"first_new_pet_id": String(completed_state.get("first_new_pet_id", "")),
		"duplicate_faith_total": maxi(0, int(completed_state.get("duplicate_faith_total", 0)))
	}
	_host._show_coin_change_popup(_host._get_window_mouse_position(get_window()), -spent_cost)
	if is_instance_valid(request_window) and request_window.has_method("show_results"):
		request_window.call("show_results", results, batch_summary)
	_set_gacha_request_pending(request_window, false)
	if bool(completed_state.get("inventory_changed", false)):
		_host._sync_inventory_window()
	# Debug levels can be set before a pet is owned. If that pet is later drawn at
	# Lv.100, acquisition is also a threshold event and must evolve it immediately.
	_apply_automatic_evolution_thresholds()
	var news_item_name = String(completed_state.get("news_item_name", ""))
	if not news_item_name.is_empty():
		_host._try_queue_news_event(
			"gacha",
			{
				"item_name": news_item_name,
				"item_name_en": String(completed_state.get("news_item_name_en", news_item_name)),
				"item_name_zh": String(completed_state.get("news_item_name_zh", news_item_name))
			},
			"gacha",
			5.0
		)
	_pet_upgrade_stats_dirty = true
	_host._refresh_pet_stats(true)
	_host._refresh_coin_display()
	_host._request_save()

func _set_gacha_request_pending(window_value: Variant, pending: bool) -> void:
	if is_instance_valid(window_value) and window_value.has_method("set_draw_request_pending"):
		window_value.call("set_draw_request_pending", pending)

func _on_shop_purchase_requested(good_id: String) -> void:
	if _shop_window == null or good_id.is_empty():
		return

	var good: Dictionary = _shop_window.call("get_good", good_id)
	if good.is_empty():
		_shop_window.call("set_purchase_result", good_id, false, "Item not found" if _language == "en" else "商品不存在")
		return

	var price = maxi(0, int(good.get("price", 0)))
	var is_offering = OfferingCatalog.is_offering(good)
	if is_offering and not _carried_offering.is_empty():
		_shop_window.call("set_purchase_result", good_id, false, "Place or cancel the carried offering first" if _language == "en" else "请先投放或取消鼠标上的贡品")
		return
	if _gold_coins < price:
		_shop_window.call("set_purchase_result", good_id, false, "Not enough gold" if _language == "en" else "金币不足")
		return

	if is_offering:
		var carried = OfferingCatalog.normalize_offering(good)
		if carried.is_empty():
			_shop_window.call("set_purchase_result", good_id, false, "Invalid offering data" if _language == "en" else "贡品数据无效")
			return
		_gold_coins -= price
		carried["purchase_price"] = price
		_carried_offering = carried
		_host._set_offering_cursor(String(_carried_offering.get("texture", "")))
		_host._show_coin_change_popup(_host._get_window_mouse_position(get_window()), -price)
		_host._sync_shop_state()
		_shop_window.call(
			"set_purchase_result",
			good_id,
			true,
			("Carrying %s. Click the desktop to place it; right-click to cancel" if _language == "en" else "已拿起：%s，点击桌面任意位置投放，右键取消") % String(OfferingCatalog.localize(good, _language).get("name", "Offering" if _language == "en" else "贡品"))
		)
		if _shop_window.has_method("close_window"):
			_shop_window.call("close_window")
		else:
			_shop_window.visible = false
		_host.call_deferred("_update_offering_input_window")
		_host._refresh_pet_stats(true)
		_host._refresh_coin_display()
		_host._request_save()
		return

	_gold_coins -= price
	_host._show_coin_change_popup(_host._get_window_mouse_position(get_window()), -price)
	_shop_owned_counts[good_id] = int(_shop_owned_counts.get(good_id, 0)) + 1
	_host._sync_shop_state()
	var purchased_good := OfferingCatalog.localize(good, _language)
	_shop_window.call(
		"set_purchase_result",
		good_id,
		true,
		("Purchased: %s" if _language == "en" else "购买成功：%s") % String(
			purchased_good.get("name", "Item" if _language == "en" else "商品")
		)
	)
	_host._refresh_pet_stats(true)
	_host._refresh_coin_display()
	_host._request_save()

func _on_inventory_pet_deploy_requested(pet_id: String) -> void:
	if pet_id.is_empty() or not _is_pet_unlocked(pet_id) or _deployed_pet_ids.has(pet_id):
		return
	if _is_pet_recovering(pet_id):
		_host._sync_inventory_window()
		return

	var actor = _host._spawn_desktop_pet(pet_id)
	if actor == null:
		return

	_selected_pet_id = pet_id
	_deployed_pet_ids.append(pet_id)
	if _inventory_window != null and _inventory_window.has_method("remove_pet"):
		_inventory_window.call("remove_pet", pet_id)
	_pet_upgrade_stats_dirty = true
	_host._refresh_pet_stats(true)
	_host._request_save()

func _on_inventory_pet_rename_requested(pet_id: String, custom_name: String) -> void:
	_set_pet_custom_name(pet_id, custom_name)

func _on_inventory_pet_evolution_requested(pet_id: String) -> void:
	# Kept for compatibility with an already-open legacy inventory window. Level
	# thresholds are processed globally; there is no manual evolution choice.
	_apply_automatic_evolution_thresholds()

func _apply_automatic_evolution_thresholds() -> bool:
	var changed = false
	for pet_id_value in _unlocked_pet_ids:
		var pet_id = String(pet_id_value)
		if not PetCatalog.has_evolution(pet_id):
			continue
		var state = _get_pet_state(pet_id)
		var should_be_evolved = PetProgression.progression_level(state) >= 100
		var was_evolved = bool(state.get("evolved", false))
		if was_evolved == should_be_evolved:
			continue
		if should_be_evolved:
			state["evolved"] = true
			if not _pending_evolution_notifications.has(pet_id):
				_pending_evolution_notifications.append(pet_id)
		else:
			state.erase("evolved")
			_pending_evolution_notifications.erase(pet_id)
			if (
				_evolution_window != null
				and _evolution_window.visible
				and String(_evolution_window.get("_pet_id")) == pet_id
			):
				_evolution_window.call("close_window")
		_pet_states[pet_id] = state
		_replace_deployed_pet_form(pet_id)
		changed = true
	if changed:
		_pet_upgrade_stats_dirty = true
		if _inventory_window != null:
			_host._sync_inventory_window()
	_show_next_evolution_notification()
	_host._check_campaign_completion()
	return changed

func _show_next_evolution_notification() -> void:
	if _evolution_window == null or _evolution_window.visible:
		return
	while not _pending_evolution_notifications.is_empty():
		var pet_id = String(_pending_evolution_notifications.pop_front())
		if not _is_pet_unlocked(pet_id) or not bool(_get_pet_state(pet_id).get("evolved", false)):
			continue
		_evolution_window.call(
			"open_for_pet",
			pet_id,
			_get_pet_display_name(pet_id),
			PetProgression.progression_level(_get_pet_state(pet_id)),
			String(_get_pet_state(pet_id).get("name", ""))
		)
		return
	_host._check_campaign_completion()

func _on_evolution_notification_dismissed() -> void:
	call_deferred("_show_next_evolution_notification")

func _replace_deployed_pet_form(pet_id: String) -> void:
	for pet in _pets.duplicate():
		if not is_instance_valid(pet) or _host._get_actor_pet_id(pet) != pet_id:
			continue
		var spawn_x: float = float(pet.position.x)
		var old_actor_key = str(pet.get_instance_id())
		var battle_health: Variant = _battle_pet_health.get(old_actor_key, null)
		var battle_max_health: Variant = _battle_pet_max_health.get(old_actor_key, null)
		var battle_attack_at: Variant = _battle_pet_attack_at.get(old_actor_key, null)
		var battle_target_x: Variant = _battle_pet_target_x.get(old_actor_key, null)
		var battle_formed: Variant = _battle_pet_formed.get(old_actor_key, null)
		var battle_enemy_target: Variant = _battle_pet_enemy_targets.get(old_actor_key, null)
		_battle_pet_health.erase(old_actor_key)
		_battle_pet_max_health.erase(old_actor_key)
		_battle_pet_attack_at.erase(old_actor_key)
		_battle_pet_target_x.erase(old_actor_key)
		_battle_pet_formed.erase(old_actor_key)
		_battle_pet_enemy_targets.erase(old_actor_key)
		_battle_pet5_rolls.erase(old_actor_key)
		_next_pet_coin_drop_at.erase(old_actor_key)
		_pet_coin_drop_intervals.erase(old_actor_key)
		_pets.erase(pet)
		pet.queue_free()
		var evolved_pet = _host._spawn_desktop_pet(pet_id, spawn_x)
		if evolved_pet != null and battle_health != null:
			var new_actor_key = str(evolved_pet.get_instance_id())
			_battle_pet_health[new_actor_key] = battle_health
			_battle_pet_max_health[new_actor_key] = battle_max_health
			_battle_pet_attack_at[new_actor_key] = battle_attack_at
			_battle_pet_target_x[new_actor_key] = battle_target_x
			_battle_pet_formed[new_actor_key] = battle_formed
			# Evolution can replace an actor on the same frame its enemy disappears.
			# Never copy a freed target lock into the replacement actor.
			if is_instance_valid(battle_enemy_target):
				var battle_enemy_target_node = battle_enemy_target as Node2D
				if not battle_enemy_target_node.is_queued_for_deletion():
					_battle_pet_enemy_targets[new_actor_key] = battle_enemy_target_node
		return

func _sync_deployed_pet_level(pet_id: String) -> void:
	if pet_id.is_empty():
		return
	var level = PetProgression.progression_level(_get_pet_state(pet_id))
	for pet in _pets:
		if (
			is_instance_valid(pet)
			and _host._get_actor_pet_id(pet) == pet_id
			and pet.has_method("set_pet_level")
		):
			pet.call("set_pet_level", level)

func _on_pet_detail_rename_requested(pet_id: String, custom_name: String) -> void:
	_set_pet_custom_name(pet_id, custom_name)
	_host._request_save()


# Offerings

func _on_pet_upgrade_requested(pet_id: String) -> void:
	if pet_id.is_empty() or not _is_pet_unlocked(pet_id):
		return
	var state = _get_pet_state(pet_id)
	var level_cap: int = _host._get_campaign_level_cap()
	if PetProgression.progression_level(state) >= level_cap:
		_host._refresh_pet_stats(true)
		return
	var cost = _get_upgrade_cost(pet_id)
	if int(floor(_faith_points)) < cost:
		_host._refresh_pet_stats(true)
		return

	_faith_points = maxf(0.0, _faith_points - float(cost))
	state["upgrade_level"] = clampi(
		PetProgression.progression_level(state) + 1,
		1,
		level_cap
	)
	_selected_pet_id = pet_id
	_apply_automatic_evolution_thresholds()
	_sync_deployed_pet_level(pet_id)
	_pet_upgrade_stats_dirty = true
	_host._refresh_pet_stats(true)
	_host._try_queue_news_event(
		"upgrade",
		{"level": PetProgression.progression_level(state)},
		"upgrade:%s" % pet_id,
		40.0,
		0.45
	)
	_host._request_save()

func _on_faith_add_requested(amount: int) -> void:
	var faith_gain = _get_manual_faith_click_gain(amount)
	_grant_faith(faith_gain)
	_host._show_faith_change_popup(_host._get_window_mouse_position(get_window()), faith_gain)
	_host._refresh_pet_stats(true)
	_host._request_save()

func _on_menu_handle_moved(anchor: float) -> void:
	_loaded_menu_handle_anchor = clampf(anchor, 0.0, 1.0)
	_host._request_save()

func _on_activity_range_changed(range_mode: String) -> void:
	if range_mode not in ["full", "right", "left"]:
		return
	_pet_activity_range = range_mode
	_host._update_actor_window_bounds()
	_host._request_save()

func _on_debug_economy_requested(faith_points: float, gold_coins: int) -> void:
	_faith_points = clampf(faith_points, 0.0, 1_000_000_000_000_000.0)
	_lifetime_faith = maxf(_lifetime_faith, _faith_points)
	_gold_coins = clampi(gold_coins, 0, 1_000_000_000_000_000)
	_pet_upgrade_stats_dirty = true
	_host._refresh_pet_stats(true)
	_host._refresh_faith_display()
	_host._refresh_coin_display()
	_host._sync_shop_state()
	if _settings_window != null and _settings_window.has_method("refresh_debug_values"):
		_settings_window.call(
			"refresh_debug_values",
			_faith_points,
			_gold_coins,
			_debug_enemy_power_scale,
			_debug_game_speed,
			_get_debug_pet_levels()
		)
	_host._request_save()

func _on_debug_simulation_requested(enemy_power_scale: float, game_speed: float) -> void:
	_debug_enemy_power_scale = clampf(enemy_power_scale, 0.0, 1_000_000_000_000_000.0)
	_debug_game_speed = clampf(game_speed, 0.1, 20.0)
	Engine.time_scale = _debug_game_speed
	if _settings_window != null and _settings_window.has_method("refresh_debug_values"):
		_settings_window.call(
			"refresh_debug_values",
			_faith_points,
			_gold_coins,
			_debug_enemy_power_scale,
			_debug_game_speed,
			_get_debug_pet_levels()
		)

func _get_debug_pet_levels() -> Dictionary:
	var levels = {}
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id = String(pet_id_value)
		levels[pet_id] = PetProgression.progression_level(_get_pet_state(pet_id))
	return levels

func _on_debug_pet_levels_requested(levels: Dictionary) -> void:
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id = String(pet_id_value)
		if not levels.has(pet_id):
			continue
		var state = _get_pet_state(pet_id)
		state["upgrade_level"] = clampi(int(levels[pet_id]), 1, PetProgression.MAX_LEVEL)
		_pet_states[pet_id] = state
	_apply_automatic_evolution_thresholds()
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		_sync_deployed_pet_level(String(pet_id_value))
	_pet_upgrade_stats_dirty = true
	_host._refresh_pet_stats(true)
	if _inventory_window != null and _inventory_window.visible:
		_host._sync_inventory_window()
	_host._request_save()

func _on_debug_event_requested(event_type: String) -> void:
	if event_type not in ["pilgrimage", "battle"]:
		return
	if _event_invitation != null and is_instance_valid(_event_invitation):
		_event_invitation.queue_free()
	_event_invitation = null
	_pending_battle_difficulty_scale = -1.0
	if _pilgrimage_active:
		_host._finish_pilgrimage(false)
	if _battle_active:
		_host._finish_battle(true)
	_host._spawn_event_invitation(event_type)

func _on_language_changed(language_code: String) -> void:
	_language = LanguageSettings.sanitize(language_code)
	_apply_language()
	_host._request_save()

func _apply_language() -> void:
	TranslationServer.set_locale(_language)
	if _side_drawer != null and _side_drawer.has_method("set_language"):
		_side_drawer.call("set_language", _language)
	if _settings_window != null and _settings_window.has_method("set_language"):
		_settings_window.call("set_language", _language)
	if _shop_window != null and _shop_window.has_method("set_language"):
		_shop_window.call("set_language", _language)
	if _gacha_window != null and _gacha_window.has_method("set_language"):
		_gacha_window.call("set_language", _language)
	if _inventory_window != null and _inventory_window.has_method("set_language"):
		_inventory_window.call("set_language", _language)
		_host._sync_inventory_window()
	if _evolution_window != null and _evolution_window.has_method("set_language"):
		_evolution_window.call("set_language", _language)
	if _news_window != null and _news_window.has_method("set_language"):
		_news_window.call("set_language", _language)
	if _completion_window != null and _completion_window.has_method("set_language"):
		_completion_window.call("set_language", _language)
	if _event_invitation != null and is_instance_valid(_event_invitation) and _event_invitation.has_method("set_language"):
		_event_invitation.call("set_language", _language)
	var presentation_font := LanguageSettings.get_ui_font(_language)
	for presentation_label in [
		_news_broadcast_label,
		_pilgrimage_status_label,
		_pilgrimage_broadcast_title,
		_pilgrimage_broadcast_subtitle
	]:
		if presentation_label != null:
			(presentation_label as Control).add_theme_font_override("font", presentation_font)
	_host._refresh_pilgrimage_broadcast_language()
	if _news_broadcast_label != null and _news_broadcast_label.has_meta("news_entry"):
		var active_news_entry: Variant = _news_broadcast_label.get_meta("news_entry")
		if active_news_entry is Dictionary:
			var active_category := String((active_news_entry as Dictionary).get("category", "异闻"))
			_news_broadcast_label.text = "【%s】 %s" % [
				NewsFeed.get_localized_category(active_category, _language),
				NewsFeed.get_localized_headline(active_news_entry as Dictionary, _language)
			]
	for pet in _pets:
		if is_instance_valid(pet) and pet.has_method("set_language"):
			pet.call("set_language", _language)
			if pet.has_method("set_display_name"):
				pet.call("set_display_name", _get_pet_display_name(_host._get_actor_pet_id(pet)))
	_pet_upgrade_stats_dirty = true
	_last_era_display = ""
	_host._refresh_era_display(true)

func _get_manual_faith_click_gain(base_amount := 1) -> float:
	var passive_scaled_gain = _get_faith_growth_rate() * MANUAL_CLICK_RATE_SECONDS
	if not is_finite(passive_scaled_gain):
		passive_scaled_gain = 0.0
	return maxf(float(maxi(1, base_amount)), passive_scaled_gain)

func _on_quit_requested() -> void:
	_host._save_game()
	get_tree().quit()
