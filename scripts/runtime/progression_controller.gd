extends "res://scripts/runtime/main_context.gd"

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
		var sofa_multiplier = _host._get_pet_sofa_multiplier(pet_id)
		var sofa_seconds = _host._get_pet_sofa_seconds_remaining(pet_id)
		var production_multiplier = offering_multiplier * sofa_multiplier
		var production_seconds = maxf(
			_get_pet_offering_seconds_remaining(pet_id),
			sofa_seconds
		)
		var recovery_info = _get_pet_recovery_info(pet_id)
		var recovering = bool(recovery_info.get("recovering", false))
		var current_fps = (
			_get_pet_faith_per_second(pet_id, level)
			* production_multiplier
			* _get_total_faith_multiplier()
		)
		var next_fps = _get_pet_faith_per_second(
			pet_id,
			mini(level_cap, level + 1)
		) * production_multiplier * _get_total_faith_multiplier()
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
			"sofa_multiplier": sofa_multiplier,
			"sofa_seconds_remaining": sofa_seconds,
			"production_multiplier": production_multiplier,
			"production_seconds_remaining": production_seconds,
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
	var elapsed_years = EraProgression.get_elapsed_calendar_years(_get_era_runtime_seconds())
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
			* _host._get_pet_sofa_multiplier(pet_id)
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
	# Unlocks, achievements, and battle budgets use permanent production only.
	# Pilgrimages, offerings, sofas, and recovery are session effects and must not
	# open (or close) a permanent progression gate.
	return total_fps * GLOBAL_FAITH_MULTIPLIER * BUFF_FAITH_MULTIPLIER

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
	var pilgrimage_multiplier := 1.0
	if _host != null and _host.has_method("_get_active_pilgrimage_faith_multiplier"):
		pilgrimage_multiplier = maxf(
			1.0,
			float(_host.call("_get_active_pilgrimage_faith_multiplier"))
		)
	return GLOBAL_FAITH_MULTIPLIER * BUFF_FAITH_MULTIPLIER * pilgrimage_multiplier

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


func _get_achievement_metrics() -> Dictionary:
	return {
		"battle_victories": _battle_victories,
		"faith_rate": _get_baseline_faith_growth_rate(),
		"followers": floor(_follower_count),
		"pets_unlocked": _unlocked_pet_ids.size(),
	}


func _unlock_growth_eligible_pets() -> Array[String]:
	var newly_unlocked: Array[String] = []
	# Adding an eligible pet raises the permanent rate, so repeat until the new
	# roster no longer crosses another authored threshold.
	while true:
		var eligible := PetUnlockProgression.get_newly_eligible_pet_ids(
			_get_baseline_faith_growth_rate(),
			_unlocked_pet_ids
		)
		if eligible.is_empty():
			break
		for pet_id in eligible:
			_ensure_pet_state(pet_id)
			_unlocked_pet_ids.append(pet_id)
			newly_unlocked.append(pet_id)
			if not _deployed_pet_ids.has(pet_id):
				_deployed_pet_ids.append(pet_id)
				var actor = _host._spawn_desktop_pet(pet_id)
				if actor == null:
					_deployed_pet_ids.erase(pet_id)
				else:
					_selected_pet_id = pet_id
	if newly_unlocked.is_empty():
		return newly_unlocked
	_unlocked_pet_ids = _sanitize_pet_id_list(_unlocked_pet_ids, PetCatalog.ACTIVE_DESKTOP_PETS)
	_host._sync_inventory_window()
	_apply_automatic_evolution_thresholds()
	_host._refresh_era_display()
	_pet_upgrade_stats_dirty = true
	_host._refresh_pet_stats(true)
	_host._sync_achievement_state()
	_host._request_save()
	var names_en: Array[String] = []
	var names_zh: Array[String] = []
	for pet_id in newly_unlocked:
		names_en.append(PetCatalog.get_localized_name(pet_id, "en"))
		names_zh.append(PetCatalog.get_localized_name(pet_id, "zh"))
	_host._publish_news({
		"category": "ROSTER" if _language == "en" else "眷族",
		"headline": "增长速度达到新阶段，%s 已加入桌面眷族。" % "、".join(names_zh),
		"headline_en": "Faith growth reached a new tier; %s joined the desktop roster." % ", ".join(names_en),
	}, true, true)
	return newly_unlocked


func _on_achievement_claim_requested(achievement_id: String) -> void:
	if _claimed_achievement_ids.has(achievement_id):
		return
	var definition := AchievementProgression.get_definition(achievement_id)
	if definition.is_empty() or not AchievementProgression.is_complete(definition, _get_achievement_metrics()):
		return
	_claimed_achievement_ids.append(achievement_id)
	var faith_reward := maxf(0.0, float(definition.get("faith", 0.0)))
	var gold_reward := maxi(0, int(definition.get("gold", 0)))
	_grant_faith(faith_reward)
	_gold_coins = CurrencyDisplay.add_gold(_gold_coins, gold_reward)
	_host._refresh_faith_display()
	_host._refresh_coin_display()
	_host._sync_achievement_state()
	_host._request_save()


func _on_shop_purchase_requested(good_id: String) -> void:
	if _shop_window == null or good_id.is_empty():
		return

	var good: Dictionary = _shop_window.call("get_good", good_id)
	if good.is_empty():
		_shop_window.call("set_purchase_result", good_id, false, "Item not found" if _language == "en" else "商品不存在")
		return
	if DesktopItemCatalog.is_item(good):
		_handle_item_shop_action(good)
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
		_gold_coins = CurrencyDisplay.add_gold(_gold_coins, -price)
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

	_gold_coins = CurrencyDisplay.add_gold(_gold_coins, -price)
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


func _handle_item_shop_action(good: Dictionary) -> void:
	var item_id := String(good.get("id", ""))
	var definition := DesktopItemCatalog.get_definition(item_id)
	if item_id.is_empty() or definition.is_empty():
		_shop_window.call(
			"set_purchase_result",
			item_id,
			false,
			"Invalid item data" if _language == "en" else "道具数据无效"
		)
		return
	var localized := DesktopItemCatalog.localize(good, _language)
	var display_name := String(localized.get("name", item_id))
	var state_value: Variant = _item_states.get(item_id, {})
	var state: Dictionary = state_value if state_value is Dictionary else {}

	if state.is_empty() or not bool(state.get("owned", false)):
		var price := maxi(0, int(good.get("price", 0)))
		if _gold_coins < price:
			_shop_window.call("set_purchase_result", item_id, false, "Not enough gold" if _language == "en" else "金币不足")
			return
		_gold_coins = CurrencyDisplay.add_gold(_gold_coins, -price)
		_item_states[item_id] = {
			"owned": true,
			"deployed": false,
			"position_x": -1.0
		}
		var deployed: bool = bool(_host._deploy_item(item_id))
		_host._show_coin_change_popup(_host._get_window_mouse_position(get_window()), -price)
		_host._sync_shop_state()
		_shop_window.call(
			"set_purchase_result",
			item_id,
			deployed,
			(
				"Placed %s"
				if _language == "en"
				else "已摆放 %s"
			) % display_name
		)
		_host._refresh_coin_display()
		_host._request_save()
		return

	if bool(state.get("deployed", false)):
		if not _host._recall_item(item_id):
			_shop_window.call(
				"set_purchase_result",
				item_id,
				false,
				"Item could not be returned to the shop" if _language == "en" else "道具暂时无法收回商城"
			)
			return
		_host._sync_shop_state()
		_shop_window.call(
			"set_purchase_result",
			item_id,
			true,
		("Returned %s" if _language == "en" else "已收回 %s") % display_name
		)
		_host._request_save()
		return

	if not _host._deploy_item(item_id):
		_shop_window.call(
			"set_purchase_result",
			item_id,
			false,
			"Item could not be placed" if _language == "en" else "道具暂时无法摆放"
		)
		return
	_host._sync_shop_state()
	_shop_window.call(
		"set_purchase_result",
		item_id,
		true,
		("Placed %s" if _language == "en" else "已摆放 %s") % display_name
	)
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
	if _pending_evolution_notifications.is_empty():
		_host._check_campaign_completion()
		return
	if _evolution_window == null or not is_instance_valid(_evolution_window):
		_host._create_evolution_window()
	if _evolution_window == null or not is_instance_valid(_evolution_window) or _evolution_window.visible:
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
		# Replacing a form invalidates the current desktop actor. End a possible
		# sofa visit and offering walk first so no long-lived runtime dictionary
		# retains the actor after its old form is released.
		_host._release_sofa_interaction(pet_id, false)
		_host._finish_pending_offering_for_actor(pet)
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
			_host._attach_battle_health_bar(
				evolved_pet,
				float(battle_health),
				float(battle_max_health)
			)
			_battle_pet_attack_at[new_actor_key] = battle_attack_at
			_battle_pet_target_x[new_actor_key] = battle_target_x
			_battle_pet_formed[new_actor_key] = battle_formed
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
	_unlock_growth_eligible_pets()
	_pet_upgrade_stats_dirty = true
	_host._refresh_pet_stats(true)
	_host._sync_shop_state()
	_host._try_queue_news_event(
		"upgrade",
		{},
		"membership:registry",
		240.0,
		0.18
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
	var safe_faith_points := clampf(faith_points, 0.0, 1_000_000_000_000_000.0)
	var safe_gold_coins := clampi(gold_coins, 0, 1_000_000_000_000_000)
	if (
		is_equal_approx(_faith_points, safe_faith_points)
		and _gold_coins == safe_gold_coins
		and _lifetime_faith >= safe_faith_points
	):
		return
	_faith_points = safe_faith_points
	_lifetime_faith = maxf(_lifetime_faith, _faith_points)
	_gold_coins = safe_gold_coins
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
	var safe_enemy_power_scale := clampf(enemy_power_scale, 0.0, 1_000_000_000_000_000.0)
	var safe_game_speed := clampf(game_speed, 0.1, 20.0)
	var changed := (
		not is_equal_approx(_debug_enemy_power_scale, safe_enemy_power_scale)
		or not is_equal_approx(_debug_game_speed, safe_game_speed)
	)
	_debug_enemy_power_scale = safe_enemy_power_scale
	_debug_game_speed = safe_game_speed
	Engine.time_scale = safe_game_speed
	if not changed:
		return
	if _settings_window != null and _settings_window.has_method("refresh_debug_values"):
		_settings_window.call(
			"refresh_debug_values",
			_faith_points,
			_gold_coins,
			_debug_enemy_power_scale,
			_debug_game_speed,
			_get_debug_pet_levels()
		)


func _on_debug_era_requested(era_index: int) -> void:
	var safe_era_index := clampi(era_index, 0, EraProgression.get_era_count() - 1)
	_total_runtime_seconds = EraProgression.get_era_start_runtime_seconds(safe_era_index)
	_era_floor_index = safe_era_index
	# Debug users must still be able to inspect an earlier chapter after having
	# unlocked a large roster. This is intentionally runtime-only and is never
	# persisted into a save.
	_debug_era_preview_index = safe_era_index
	_session_runtime_seconds = minf(_session_runtime_seconds, _total_runtime_seconds)
	_last_era_display = ""
	_pet_upgrade_stats_dirty = true
	_host._refresh_pet_stats(true)
	_host._refresh_era_display(true)
	_host._schedule_next_pilgrimage(_host._get_now_seconds(), true)
	_host._schedule_next_battle(_host._get_now_seconds(), true)
	if _side_drawer != null and _side_drawer.has_method("refresh_playtime"):
		_side_drawer.call("refresh_playtime", _total_runtime_seconds)
	if _settings_window != null:
		_settings_window.refresh_debug_era(EraProgression.get_era_index(_get_era_runtime_seconds()))
	_host._request_save()

func _get_debug_pet_levels() -> Dictionary:
	var levels = {}
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id = String(pet_id_value)
		levels[pet_id] = PetProgression.progression_level(_get_pet_state(pet_id))
	return levels

func _on_debug_pet_levels_requested(levels: Dictionary) -> void:
	var levels_changed := false
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id = String(pet_id_value)
		if not levels.has(pet_id):
			continue
		var state = _get_pet_state(pet_id)
		var requested_level := clampi(int(levels[pet_id]), 1, PetProgression.MAX_LEVEL)
		if PetProgression.progression_level(state) == requested_level:
			continue
		state["upgrade_level"] = requested_level
		_pet_states[pet_id] = state
		levels_changed = true
	var evolution_changed := _apply_automatic_evolution_thresholds()
	if not levels_changed and not evolution_changed:
		return
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		_sync_deployed_pet_level(String(pet_id_value))
	_unlock_growth_eligible_pets()
	_pet_upgrade_stats_dirty = true
	_host._refresh_pet_stats(true)
	if _inventory_window != null and _inventory_window.visible:
		_host._sync_inventory_window()
	_host._request_save()

func _on_debug_event_requested(event_type: String) -> void:
	if event_type not in ["pilgrimage", "battle"]:
		return
	# Debug buttons submit their current values before dispatching the event. The
	# no-op guards above avoid rebuilding every panel when those values are unchanged.
	_host._cancel_battle_asset_warmup()
	if _event_invitation != null and is_instance_valid(_event_invitation):
		_event_invitation.queue_free()
	_event_invitation = null
	_pending_battle_difficulty_scale = -1.0
	if _pilgrimage_active:
		_host._finish_pilgrimage(false)
	if _battle_active:
		_host._cancel_battle_for_debug()
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
	if _achievement_window != null and _achievement_window.has_method("set_language"):
		_achievement_window.call("set_language", _language)
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
	for presentation_value in [
		_news_broadcast_label,
		_pilgrimage_status_label,
		_pilgrimage_broadcast_title,
		_pilgrimage_broadcast_subtitle
	]:
		if not is_instance_valid(presentation_value) or not presentation_value is Control:
			continue
		var presentation_label := presentation_value as Control
		presentation_label.add_theme_font_override("font", presentation_font)
	_host._refresh_pilgrimage_broadcast_language()
	if is_instance_valid(_news_broadcast_label) and _news_broadcast_label.has_meta("news_entry"):
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
	for item in _desktop_items:
		if is_instance_valid(item) and item.has_method("set_language"):
			item.call("set_language", _language)
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
