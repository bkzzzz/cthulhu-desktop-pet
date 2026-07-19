extends "res://scripts/runtime/main_context.gd"

## Ambient currency drops, capacity, and collection rewards.

func _schedule_next_ambient_coin_drop(now: float) -> void:
	for pet in _pets:
		if is_instance_valid(pet):
			_schedule_pet_coin_drop(pet, now)

func _schedule_pet_coin_drop(actor: Node2D, now: float) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var pet_id = _host._get_actor_pet_id(actor)
	if pet_id.is_empty():
		return
	var level = PetProgression.progression_level(_host._get_pet_state(pet_id))
	var current_rate = _host._get_pet_money_value_per_minute(pet_id, level)
	var base_rate = maxf(0.01, _host._get_pet_money_value_per_minute(pet_id, 1))
	var speed_scale = sqrt(maxf(1.0, current_rate / base_rate))
	var interval_min = clampf(34.0 / speed_scale, PET_AUTO_COIN_INTERVAL_MIN, 40.0)
	var interval_max = clampf(52.0 / speed_scale, interval_min + 4.0, PET_AUTO_COIN_INTERVAL_MAX)
	var interval = _rng.randf_range(interval_min, interval_max)
	var actor_key = str(actor.get_instance_id())
	_next_pet_coin_drop_at[actor_key] = now + interval
	_pet_coin_drop_intervals[actor_key] = interval

func _update_ambient_coin_drops() -> void:
	var now = _host._get_now_seconds()
	var active_keys = {}
	for pet in _pets:
		if not is_instance_valid(pet):
			continue
		var actor_key = str(pet.get_instance_id())
		active_keys[actor_key] = true
		if not _next_pet_coin_drop_at.has(actor_key):
			_schedule_pet_coin_drop(pet, now)
			continue
		if now < float(_next_pet_coin_drop_at.get(actor_key, now)):
			continue
		var interval = float(_pet_coin_drop_intervals.get(actor_key, 40.0))
		_schedule_pet_coin_drop(pet, now)
		if _pilgrimage_active or _battle_active:
			continue
		if pet.has_method("is_swallowed") and bool(pet.call("is_swallowed")):
			continue
		_spawn_pet_coin_pile(pet, interval)
	for actor_key_value in _next_pet_coin_drop_at.keys().duplicate():
		var actor_key = String(actor_key_value)
		if active_keys.has(actor_key):
			continue
		_next_pet_coin_drop_at.erase(actor_key)
		_pet_coin_drop_intervals.erase(actor_key)

func _spawn_pet_coin_pile(actor: Node2D, interval_seconds: float) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var pet_id = _host._get_actor_pet_id(actor)
	if pet_id.is_empty():
		return
	var level = PetProgression.progression_level(_host._get_pet_state(pet_id))
	var rate_per_minute = _host._get_pet_money_value_per_minute(pet_id, level)
	var target_value = maxf(
		float(PET_AUTO_COIN_PILE_MIN),
		rate_per_minute * maxf(1.0, interval_seconds) / 60.0
	)
	var pile_count = clampi(
		int(ceil(target_value / 8.0)),
		PET_AUTO_COIN_PILE_MIN,
		PET_AUTO_COIN_PILE_MAX
	)
	var drop_anchor = actor.position + Vector2(0.0, -64.0)
	if actor.has_method("get_emotion_anchor"):
		drop_anchor = actor.call("get_emotion_anchor")
	var remaining_value = target_value
	var crystal_budget = maxf(0.0, target_value - float(maxi(0, pile_count - 1)))
	var crystal_type = _choose_crystal_drop_type(
		PetCatalog.get_definition(pet_id),
		level,
		crystal_budget
	)
	for coin_index in pile_count:
		var slots_left = pile_count - coin_index
		var average_value = remaining_value / float(maxi(1, slots_left))
		var coin_type = "R"
		if coin_index == 0 and not crystal_type.is_empty():
			coin_type = crystal_type
		elif average_value >= 24.0:
			coin_type = "D"
		elif average_value >= 3.0:
			coin_type = "P"
		remaining_value = maxf(0.0, remaining_value - float(CoinDrop.get_coin_value(coin_type)))
		var spread_weight = float(coin_index) - float(pile_count - 1) * 0.5
		_spawn_coin(coin_type, drop_anchor + Vector2(
			spread_weight * 13.0 + _rng.randf_range(-8.0, 8.0),
			_rng.randf_range(-14.0, 10.0)
		))

func _update_coin_drops() -> void:
	for index in range(_coin_drops.size() - 1, -1, -1):
		if not is_instance_valid(_coin_drops[index]) or _coin_drops[index].is_queued_for_deletion():
			_coin_drops.remove_at(index)

func _spawn_pet_coin(actor: Node2D) -> Node2D:
	if actor == null or not is_instance_valid(actor):
		return null
	var coin_type = "P" if _rng.randf() < PET_P_COIN_CHANCE else "R"
	var spawn_position = actor.position + Vector2(0.0, -72.0)
	if actor.has_method("get_emotion_anchor"):
		spawn_position = actor.call("get_emotion_anchor")
	return _spawn_coin(coin_type, spawn_position)

func _spawn_coin(coin_type: String, spawn_position: Vector2) -> Node2D:
	_make_desktop_coin_capacity(1)
	var coin: Node2D = CoinDrop.new()
	coin.setup(
		coin_type,
		spawn_position,
		_pet_window_size,
		float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS)
	)
	coin.collected.connect(_on_coin_collected)
	add_child(coin)
	_coin_drops.append(coin)
	return coin

func _make_desktop_coin_capacity(incoming_count: int) -> void:
	_update_coin_drops()
	var required_slots = maxi(0, incoming_count)
	while _coin_drops.size() + required_slots > DESKTOP_COIN_LIMIT:
		var oldest_coin = _coin_drops.pop_front() as Node2D
		if oldest_coin == null or not is_instance_valid(oldest_coin):
			continue
		if oldest_coin.has_method("expire"):
			oldest_coin.call("expire")
		else:
			oldest_coin.queue_free()

func _on_coin_collected(actor: Node2D, coin_type: String, value: int) -> void:
	var popup_position = actor.position if actor != null and is_instance_valid(actor) else _host._get_window_mouse_position(get_window())
	if actor != null:
		_coin_drops.erase(actor)
	var safe_value = maxi(0, value)
	if safe_value <= 0:
		return
	_gold_coins += safe_value
	_host._refresh_coin_display()
	_host._show_coin_change_popup(popup_position, safe_value, coin_type)

func _on_believer_scared_away(_actor: Node2D, _drop_position: Vector2) -> void:
	# Flight is the no-reward outcome. Only a completed prayer creates coins.
	pass

func _on_believer_prayed(_actor: Node2D, drop_position: Vector2, coin_count: int) -> void:
	var safe_count = clampi(coin_count, 1, BelieverActor.PILGRIMAGE_PRAY_COIN_MAX)
	for coin_index in safe_count:
		var spread_weight = float(coin_index) - (float(safe_count - 1) * 0.5)
		var coin_position = drop_position + Vector2(
			spread_weight * 11.0 + _rng.randf_range(-7.0, 7.0),
			_rng.randf_range(-12.0, 8.0)
		)
		_spawn_coin("D", coin_position)


# UI windows
