extends "res://scripts/runtime/main_context.gd"

const CoinCollectorShovel = preload("res://scripts/coin_collector_shovel.gd")

const COIN_COLLECTOR_ITEM_ID := "coin_collector"
const COIN_COLLECTOR_EMPTY_RECHECK_SECONDS := 0.28
const COIN_COLLECTOR_POST_SWEEP_DELAY_MIN := 0.45
const COIN_COLLECTOR_POST_SWEEP_DELAY_MAX := 0.85

var _next_coin_collector_sweep_at := 0.0
var _coin_collector_batch_serial := 0

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
	_update_coin_collector(now)


func _update_coin_collector(now: float) -> void:
	var collector := _as_valid_node_2d(_host._get_desktop_item(COIN_COLLECTOR_ITEM_ID))
	if collector == null or not is_instance_valid(collector):
		_next_coin_collector_sweep_at = 0.0
		_cancel_coin_collector_pickups()
		return
	var shovel := _get_or_create_collector_shovel(collector)
	if shovel == null:
		return
	if bool(shovel.call("is_collecting")):
		return
	if now < _next_coin_collector_sweep_at:
		return
	var coin := _get_nearest_collectible_coin(collector.position)
	if coin == null:
		_next_coin_collector_sweep_at = now + COIN_COLLECTOR_EMPTY_RECHECK_SECONDS
		return
	var batch := _get_collectible_coin_batch(coin)
	if batch.is_empty():
		# A later sibling from this same pet drop is still falling or in its short
		# pickup arm delay. Wait so one shovel animation produces one combined +N.
		_next_coin_collector_sweep_at = now + COIN_COLLECTOR_EMPTY_RECHECK_SECONDS
		return
	if bool(shovel.call("begin_collection", coin, batch)):
		_next_coin_collector_sweep_at = now + _rng.randf_range(
			COIN_COLLECTOR_POST_SWEEP_DELAY_MIN,
			COIN_COLLECTOR_POST_SWEEP_DELAY_MAX
		)
	else:
		# A player can start mouse magnet pickup during the shovel's approach.
		# Retry later instead of taking over that manual interaction.
		_next_coin_collector_sweep_at = now + COIN_COLLECTOR_EMPTY_RECHECK_SECONDS


func _get_or_create_collector_shovel(collector: Node2D) -> Node2D:
	if collector == null or not is_instance_valid(collector):
		return null
	var existing := collector.get_node_or_null("CoinCollectorShovel") as Node2D
	if existing != null:
		return existing
	var shovel := CoinCollectorShovel.new()
	shovel.name = "CoinCollectorShovel"
	collector.add_child(shovel)
	shovel.call("setup")
	return shovel


func _get_nearest_collectible_coin(anchor: Vector2) -> Node2D:
	var candidate: Node2D
	var candidate_distance_squared := INF
	for coin_value in _coin_drops:
		var coin := _as_valid_node_2d(coin_value)
		if coin == null or not is_instance_valid(coin) or coin.is_queued_for_deletion():
			continue
		if not coin.has_method("can_be_collected_by_collector"):
			continue
		if not bool(coin.call("can_be_collected_by_collector")):
			continue
		var distance_squared := anchor.distance_squared_to(coin.position)
		if candidate == null or distance_squared < candidate_distance_squared:
			candidate = coin
			candidate_distance_squared = distance_squared
	return candidate


func _get_collectible_coin_batch(seed: Node2D) -> Array[Node2D]:
	if seed == null or not is_instance_valid(seed):
		return []
	if not seed.has_meta("coin_collector_batch_id"):
		return [seed]
	var batch_id := String(seed.get_meta("coin_collector_batch_id", ""))
	if batch_id.is_empty():
		return [seed]
	var batch: Array[Node2D] = []
	for coin_value in _coin_drops:
		var coin := _as_valid_node_2d(coin_value)
		if coin == null or not is_instance_valid(coin) or coin.is_queued_for_deletion():
			continue
		if String(coin.get_meta("coin_collector_batch_id", "")) != batch_id:
			continue
		if coin.has_method("can_be_collected_by_collector") and bool(coin.call("can_be_collected_by_collector")):
			batch.append(coin)
		elif coin.has_method("is_pending_for_collector_batch") and bool(coin.call("is_pending_for_collector_batch")):
			return []
	return batch if not batch.is_empty() else [seed]


func _cancel_coin_collector_pickups() -> void:
	for coin_value in _coin_drops:
		var coin := _as_valid_node_2d(coin_value)
		if coin != null and is_instance_valid(coin) and coin.has_method("cancel_collector_collection"):
			coin.call("cancel_collector_collection")

func _spawn_pet_coin_pile(actor: Node2D, interval_seconds: float) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var pet_id = _host._get_actor_pet_id(actor)
	if pet_id.is_empty():
		return
	var level = PetProgression.progression_level(_host._get_pet_state(pet_id))
	var rate_per_minute = _host._get_pet_money_value_per_minute(pet_id, level)
	var target_value := maxi(1, int(round(
		rate_per_minute * maxf(1.0, interval_seconds) / 60.0
	)))
	var drop_anchor = actor.position + Vector2(0.0, -64.0)
	if actor.has_method("get_emotion_anchor"):
		drop_anchor = actor.call("get_emotion_anchor")
	_spawn_value_as_coins(target_value, drop_anchor, PET_AUTO_COIN_PILE_MAX)

func _spawn_value_as_coins(
	total_value: int,
	drop_anchor: Vector2,
	max_drop_count := 8
) -> Array[Node2D]:
	var spawned: Array[Node2D] = []
	var plan := CoinDrop.make_drop_plan(total_value, max_drop_count)
	var batch_id := _make_coin_collector_batch_id()
	for drop_index in plan.size():
		var drop_data: Dictionary = plan[drop_index]
		var spread_weight := float(drop_index) - float(plan.size() - 1) * 0.5
		var coin := _spawn_coin(
			String(drop_data.get("type", "R")),
			drop_anchor + Vector2(
				spread_weight * 13.0 + _rng.randf_range(-8.0, 8.0),
				_rng.randf_range(-14.0, 10.0)
			)
		)
		if coin != null and is_instance_valid(coin):
			coin.call("set_drop_value", int(drop_data.get("value", 0)))
			coin.set_meta("coin_collector_batch_id", batch_id)
			spawned.append(coin)
	_request_coin_collector_check()
	return spawned

func _update_coin_drops(delta := 0.0) -> void:
	var safe_delta := maxf(0.0, delta)
	for index in range(_coin_drops.size() - 1, -1, -1):
		# A typed Array can retain a dead Object slot after free(). Casting that
		# slot throws before is_instance_valid() gets a chance to inspect it.
		# Validate the Variant first, then narrow it to Node2D.
		var coin := _as_valid_node_2d(_coin_drops[index])
		if coin == null or not is_instance_valid(coin) or coin.is_queued_for_deletion():
			_coin_drops.remove_at(index)
			continue
		if safe_delta > 0.0 and coin.has_method("advance_resting"):
			coin.call("advance_resting", safe_delta)

func _spawn_pet_coin(actor: Node2D) -> Node2D:
	if actor == null or not is_instance_valid(actor):
		return null
	var spawn_position = actor.position + Vector2(0.0, -72.0)
	if actor.has_method("get_emotion_anchor"):
		spawn_position = actor.call("get_emotion_anchor")
	var coin := _spawn_coin("R", spawn_position)
	if coin != null and is_instance_valid(coin):
		coin.set_meta("coin_collector_batch_id", _make_coin_collector_batch_id())
		_request_coin_collector_check()
	return coin


func _make_coin_collector_batch_id() -> String:
	_coin_collector_batch_serial += 1
	return "drop_%d" % _coin_collector_batch_serial


func _request_coin_collector_check() -> void:
	# A new pet pile should be handled soon after it settles rather than waiting
	# for an unrelated old ambient sweep cooldown.
	_next_coin_collector_sweep_at = minf(
		_next_coin_collector_sweep_at,
		_host._get_now_seconds()
	)

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
	coin.tree_exiting.connect(_on_coin_tree_exiting.bind(coin.get_instance_id()))
	add_child(coin)
	_coin_drops.append(coin)
	return coin

func _make_desktop_coin_capacity(incoming_count: int) -> void:
	_update_coin_drops()
	var required_slots = maxi(0, incoming_count)
	while _coin_drops.size() + required_slots > DESKTOP_COIN_LIMIT:
		var oldest_coin := _as_valid_node_2d(_coin_drops.pop_front())
		if oldest_coin == null or not is_instance_valid(oldest_coin):
			continue
		if oldest_coin.has_method("expire"):
			oldest_coin.call("expire")
		else:
			oldest_coin.queue_free()

func _on_coin_collected(actor: Node2D, coin_type: String, value: int) -> void:
	var popup_position = actor.position if actor != null and is_instance_valid(actor) else _host._get_window_mouse_position(get_window())
	if actor != null and is_instance_valid(actor) and actor.has_method("get_collector_popup_anchor"):
		var collector_anchor: Variant = actor.call("get_collector_popup_anchor")
		if collector_anchor is Vector2:
			popup_position = collector_anchor
	if actor != null:
		_coin_drops.erase(actor)
	var safe_value = maxi(0, value)
	if safe_value <= 0:
		return
	_gold_coins = CurrencyDisplay.add_gold(_gold_coins, safe_value)
	_host._refresh_coin_display()
	_host._show_coin_change_popup(popup_position, safe_value, coin_type)


func _on_coin_tree_exiting(instance_id: int) -> void:
	# Not every removal awards currency: shovel batching folds siblings into one
	# coin, expiry/capacity paths discard coins, and external teardown may free a
	# child directly. Remove all of those paths before their Object becomes stale.
	for index in range(_coin_drops.size() - 1, -1, -1):
		var coin := _as_valid_node_2d(_coin_drops[index])
		if coin == null or coin.get_instance_id() == instance_id:
			_coin_drops.remove_at(index)


func _on_believer_scared_away(
	_actor: Node2D,
	drop_position: Vector2,
	reward_value := 0
) -> void:
	var safe_value := clampi(
		int(reward_value),
		0,
		PILGRIMAGE_MAX_SINGLE_GOLD_REWARD
	)
	if safe_value > 0:
		_spawn_value_as_coins(safe_value, drop_position, 3)

func _on_believer_prayed(_actor: Node2D, drop_position: Vector2, reward_value: int) -> void:
	var safe_value := clampi(
		reward_value,
		0,
		PILGRIMAGE_MAX_SINGLE_GOLD_REWARD
	)
	if safe_value <= 0:
		return
	_spawn_value_as_coins(safe_value, drop_position, 3)
