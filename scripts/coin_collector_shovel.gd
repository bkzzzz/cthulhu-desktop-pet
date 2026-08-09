extends Node2D

# A short-lived visual helper owned by the coin collector. It deliberately is
# not a shop item: the shovel only appears at a settled coin pile, sweeps it,
# then disappears before the coins are deposited in the collector.
const SHOVEL_TEXTURE := "res://assets/furniture/shopItems/铲子.png"
const SHOVEL_SCALE := 0.74
const SWEEP_STROKE_COUNT := 3
const SWEEP_STROKE_SECONDS := 0.22
const SWEEP_ARC_PIXELS := 17.0
const SWEEP_LIFT_PIXELS := 6.0

var _sprite: Sprite2D
var _active_coin: Node2D
var _batch_coins: Array[Node2D] = []
var _sweep_elapsed := 0.0
var _transfer_started := false


func _ready() -> void:
	setup()


func _exit_tree() -> void:
	# Returning the collector to the shop must leave any in-flight currency on
	# the desktop. CoinDrop resumes its normal ground physics after cancellation.
	cancel_collection()


func setup() -> void:
	_create_sprite()
	_hide_shovel()


func is_collecting() -> bool:
	return _active_coin != null and is_instance_valid(_active_coin)


func is_visible_at_coin() -> bool:
	return _sprite != null and _sprite.visible


func begin_collection(coin: Node2D, batch_coins: Array[Node2D] = []) -> bool:
	if is_collecting() or not _is_collectible(coin):
		return false
	_create_sprite()
	_active_coin = coin
	_batch_coins = _normalize_batch(coin, batch_coins)
	_transfer_started = false
	_sweep_elapsed = 0.0
	_connect_active_coin(coin)

	_show_shovel_at_coin()
	return true


func cancel_collection() -> void:
	if _active_coin != null and is_instance_valid(_active_coin):
		if _active_coin.has_method("cancel_collector_collection"):
			_active_coin.call("cancel_collector_collection")
		_disconnect_active_coin(_active_coin)
	_active_coin = null
	_batch_coins.clear()
	_transfer_started = false
	_sweep_elapsed = 0.0
	_hide_shovel()


func get_deposit_position() -> Vector2:
	var collector_size := _get_collector_visual_size()
	# The top coin tray is visually near the upper middle of the collector.
	return global_position + Vector2(0.0, -collector_size.y * 0.31)


func _process(delta: float) -> void:
	if not is_collecting():
		_hide_shovel()
		return
	if _transfer_started:
		_retarget_active_coin()
		return
	_update_sweep(maxf(0.0, delta))


func _create_sprite() -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "CoinCollectorShovelSprite"
		_sprite.centered = true
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Coins use z=210. The temporary shovel must visibly pass over the pile.
		_sprite.z_index = 214
		add_child(_sprite)
	_sprite.texture = load(SHOVEL_TEXTURE) as Texture2D
	_sprite.scale = Vector2.ONE * SHOVEL_SCALE


func _update_sweep(delta: float) -> void:
	# A player may begin a normal mouse-magnet pickup while the shovel is doing
	# its visible work. Cancel without reserving or deleting that coin; the
	# controller will retry another eligible drop later.
	if not _is_collectible(_active_coin):
		_finish_collection()
		return
	_sweep_elapsed += delta
	_show_shovel_at_coin()
	if _sweep_elapsed >= SWEEP_STROKE_COUNT * SWEEP_STROKE_SECONDS:
		_hide_shovel()
		_begin_coin_transfer()


func _show_shovel_at_coin() -> void:
	if _sprite == null or _active_coin == null or not is_instance_valid(_active_coin):
		return
	var phase := _sweep_elapsed / SWEEP_STROKE_SECONDS
	var swing := sin(phase * TAU)
	var center := _get_sweep_center(_active_coin)
	_sprite.global_position = center + Vector2(
		swing * SWEEP_ARC_PIXELS,
		-absf(swing) * SWEEP_LIFT_PIXELS
	)
	_sprite.rotation = deg_to_rad(-9.0 + swing * 18.0)
	_sprite.visible = true


func _hide_shovel() -> void:
	if _sprite == null:
		return
	_sprite.visible = false
	_sprite.rotation = 0.0


func _get_sweep_center(coin: Node2D) -> Vector2:
	var shovel_size := _get_shovel_visual_size()
	# Match the old blade-to-ground alignment but use the coin's current global
	# coordinate. The shovel therefore appears directly at a real coin pile
	# instead of travelling or teleporting from beside the collector.
	return coin.global_position + Vector2(0.0, -shovel_size.y * 0.5 + 16.0)


func _begin_coin_transfer() -> void:
	if _active_coin == null or not is_instance_valid(_active_coin):
		_finish_collection()
		return
	if not _active_coin.has_method("begin_collector_collection"):
		_finish_collection()
		return
	if not _prepare_batch_for_transfer():
		_finish_collection()
		return
	if not bool(_active_coin.call("begin_collector_collection", get_deposit_position())):
		_finish_collection()
		return
	_transfer_started = true
	_hide_shovel()


func _prepare_batch_for_transfer() -> bool:
	if not _is_collectible(_active_coin):
		return false
	var combined_value := 0
	var consumed_coins: Array[Node2D] = []
	for candidate in _batch_coins:
		if not _is_collectible(candidate):
			continue
		combined_value += maxi(0, int(candidate.get("value")))
		consumed_coins.append(candidate)
	if combined_value <= 0:
		return false
	# Preserve one physical coin for the existing movement/reward path and fold
	# its same-pile siblings into it. This produces one collector-side +N popup
	# instead of a noisy burst of individual +1 labels.
	if _active_coin.has_method("set_drop_value"):
		_active_coin.call("set_drop_value", combined_value)
	for candidate in consumed_coins:
		if candidate != _active_coin and is_instance_valid(candidate):
			candidate.queue_free()
	_batch_coins.clear()
	return true


func _retarget_active_coin() -> void:
	if _active_coin == null or not is_instance_valid(_active_coin):
		_finish_collection()
		return
	if not _active_coin.has_method("is_collector_collecting"):
		_finish_collection()
		return
	if not bool(_active_coin.call("is_collector_collecting")):
		_finish_collection()
		return
	if _active_coin.has_method("retarget_collector_collection"):
		_active_coin.call("retarget_collector_collection", get_deposit_position())


func _normalize_batch(coin: Node2D, batch_coins: Array[Node2D]) -> Array[Node2D]:
	var normalized: Array[Node2D] = [coin]
	for candidate in batch_coins:
		if candidate == null or not is_instance_valid(candidate) or candidate == coin:
			continue
		if candidate not in normalized:
			normalized.append(candidate)
	return normalized


func _is_collectible(coin: Node2D) -> bool:
	return (
		coin != null
		and is_instance_valid(coin)
		and not coin.is_queued_for_deletion()
		and coin.has_method("can_be_collected_by_collector")
		and bool(coin.call("can_be_collected_by_collector"))
	)


func _get_collector_visual_size() -> Vector2:
	var collector := get_parent()
	if collector != null and collector.has_method("get_item_definition"):
		var definition: Dictionary = collector.call("get_item_definition")
		var texture := load(String(definition.get("texture", ""))) as Texture2D
		if texture != null:
			var visual_scale := clampf(float(definition.get("visual_scale", 0.3)), 0.1, 2.0)
			return texture.get_size() * visual_scale
	return Vector2(320.0, 220.0)


func _get_shovel_visual_size() -> Vector2:
	if _sprite == null or _sprite.texture == null:
		return Vector2(58.0, 120.0)
	return _sprite.texture.get_size() * Vector2(absf(_sprite.scale.x), absf(_sprite.scale.y))


func _connect_active_coin(coin: Node2D) -> void:
	var collected_callback := Callable(self, "_on_active_coin_collected")
	if coin.has_signal("collected") and not coin.is_connected("collected", collected_callback):
		coin.connect("collected", collected_callback)
	var exited_callback := Callable(self, "_on_active_coin_exited")
	if not coin.tree_exited.is_connected(exited_callback):
		coin.tree_exited.connect(exited_callback)


func _disconnect_active_coin(coin: Node2D) -> void:
	if coin == null or not is_instance_valid(coin):
		return
	var collected_callback := Callable(self, "_on_active_coin_collected")
	if coin.has_signal("collected") and coin.is_connected("collected", collected_callback):
		coin.disconnect("collected", collected_callback)
	var exited_callback := Callable(self, "_on_active_coin_exited")
	if coin.tree_exited.is_connected(exited_callback):
		coin.tree_exited.disconnect(exited_callback)


func _on_active_coin_collected(_coin: Node2D, _coin_type: String, _value: int) -> void:
	_finish_collection()


func _on_active_coin_exited() -> void:
	_finish_collection()


func _finish_collection() -> void:
	if _active_coin != null and is_instance_valid(_active_coin):
		_disconnect_active_coin(_active_coin)
	_active_coin = null
	_batch_coins.clear()
	_transfer_started = false
	_sweep_elapsed = 0.0
	_hide_shovel()
