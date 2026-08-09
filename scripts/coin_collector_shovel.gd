extends Node2D

# A visual helper owned by the coin collector. It is deliberately not a shop
# item: the shovel only exists while its collector is deployed.
const SHOVEL_TEXTURE := "res://assets/furniture/shopItems/铲子.png"
const SHOVEL_SCALE := 0.74
const SWEEP_OUT_SECONDS := 0.42
const SWEEP_BACK_SECONDS := 0.34
const IDLE_BOB_PIXELS := 2.0

var _sprite: Sprite2D
var _home_position := Vector2.ZERO
var _active_coin: Node2D
var _sweep_tween: Tween
var _idle_elapsed := 0.0
# The approach intentionally leaves the coin available to a player mouse
# magnet. Once transfer starts, though, an external cancellation must also
# release this helper or it would remain permanently busy.
var _transfer_started := false


func _ready() -> void:
	setup()


func _exit_tree() -> void:
	# Returning the collector to the shop must leave any in-flight currency on
	# the desktop. CoinDrop resumes its normal ground physics after cancellation.
	cancel_collection()


func setup() -> void:
	_create_sprite()
	_refresh_home_position()
	if _sprite != null and not is_collecting():
		_sprite.position = _home_position


func is_collecting() -> bool:
	return _active_coin != null and is_instance_valid(_active_coin)


func begin_collection(coin: Node2D) -> bool:
	if is_collecting() or coin == null or not is_instance_valid(coin):
		return false
	if not coin.has_method("can_be_collected_by_collector"):
		return false
	if not bool(coin.call("can_be_collected_by_collector")):
		return false
	_create_sprite()
	_refresh_home_position()
	_active_coin = coin
	_transfer_started = false
	_connect_active_coin(coin)

	if not is_inside_tree() or _sprite == null:
		_begin_coin_transfer()
		return is_collecting()

	var sweep_target := _get_sweep_target(coin)
	_sweep_tween = create_tween()
	_sweep_tween.set_trans(Tween.TRANS_SINE)
	_sweep_tween.set_ease(Tween.EASE_IN_OUT)
	_sweep_tween.tween_property(_sprite, "position", sweep_target, SWEEP_OUT_SECONDS)
	_sweep_tween.parallel().tween_property(_sprite, "rotation", deg_to_rad(-14.0), SWEEP_OUT_SECONDS)
	_sweep_tween.tween_callback(_begin_coin_transfer)
	_sweep_tween.tween_property(_sprite, "position", _home_position, SWEEP_BACK_SECONDS)
	_sweep_tween.parallel().tween_property(_sprite, "rotation", 0.0, SWEEP_BACK_SECONDS)
	_sweep_tween.tween_callback(_finish_sweep_animation)
	return true


func cancel_collection() -> void:
	if _sweep_tween != null and is_instance_valid(_sweep_tween):
		_sweep_tween.kill()
	_sweep_tween = null
	if _active_coin != null and is_instance_valid(_active_coin):
		if _active_coin.has_method("cancel_collector_collection"):
			_active_coin.call("cancel_collector_collection")
		_disconnect_active_coin(_active_coin)
	_active_coin = null
	_transfer_started = false
	_refresh_home_position()
	if _sprite != null:
		_sprite.position = _home_position
		_sprite.rotation = 0.0


func get_deposit_position() -> Vector2:
	var collector_size := _get_collector_visual_size()
	# The top coin tray is visually near the upper middle of the collector.
	return global_position + Vector2(0.0, -collector_size.y * 0.31)


func _process(delta: float) -> void:
	if _sprite == null:
		return
	if is_collecting():
		_retarget_active_coin()
		return
	_idle_elapsed += maxf(0.0, delta)
	_refresh_home_position()
	_sprite.position = _home_position + Vector2(0.0, sin(_idle_elapsed * 2.1) * IDLE_BOB_PIXELS)


func _create_sprite() -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "CoinCollectorShovelSprite"
		_sprite.centered = true
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.z_index = 203
		add_child(_sprite)
	_sprite.texture = load(SHOVEL_TEXTURE) as Texture2D
	_sprite.scale = Vector2.ONE * SHOVEL_SCALE


func _refresh_home_position() -> void:
	var collector_size := _get_collector_visual_size()
	var shovel_size := _get_shovel_visual_size()
	_home_position = Vector2(
		-collector_size.x * 0.47,
		-shovel_size.y * 0.5
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


func _get_sweep_target(coin: Node2D) -> Vector2:
	var shovel_size := _get_shovel_visual_size()
	var target_global := coin.global_position + Vector2(0.0, -shovel_size.y * 0.5 + 16.0)
	return to_local(target_global)


func _begin_coin_transfer() -> void:
	if _active_coin == null or not is_instance_valid(_active_coin):
		_finish_collection()
		return
	if not _active_coin.has_method("begin_collector_collection"):
		_finish_collection()
		return
	if not bool(_active_coin.call("begin_collector_collection", get_deposit_position())):
		_finish_collection()
		return
	_transfer_started = true


func _retarget_active_coin() -> void:
	if _active_coin == null or not is_instance_valid(_active_coin):
		return
	if not _active_coin.has_method("is_collector_collecting"):
		return
	if not bool(_active_coin.call("is_collector_collecting")):
		if _transfer_started:
			_finish_collection()
		return
	if _active_coin.has_method("retarget_collector_collection"):
		_active_coin.call("retarget_collector_collection", get_deposit_position())


func _finish_sweep_animation() -> void:
	_sweep_tween = null
	if _active_coin == null or not is_instance_valid(_active_coin):
		_finish_collection()


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
	_transfer_started = false
	if _sweep_tween == null:
		_refresh_home_position()
		if _sprite != null:
			_sprite.position = _home_position
			_sprite.rotation = 0.0
