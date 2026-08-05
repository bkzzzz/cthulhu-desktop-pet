extends SceneTree

const OfferingCatalog = preload("res://scripts/domain/offering_catalog.gd")
const TurretCatalog = preload("res://scripts/domain/turret_catalog.gd")
const ShopWindow = preload("res://scripts/shop_window.gd")


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var shop := ShopWindow.new()
	root.add_child(shop)
	shop.setup()
	var goods := OfferingCatalog.make_shop_goods()
	goods.append_array(TurretCatalog.make_shop_goods())
	shop.set_goods(goods)
	shop.visible = true
	await process_frame
	await process_frame

	var failures: Array[String] = []
	await _verify_tab_samples(shop, "Offering", OfferingCatalog.KIND, TurretCatalog.KIND, failures)
	await _verify_tab_samples(shop, "Turret", TurretCatalog.KIND, OfferingCatalog.KIND, failures)
	if failures.is_empty():
		print("PASS: shop bookmark edge interaction")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_tab_samples(
	shop: Window,
	tab_name: String,
	expected_category: String,
	reset_category: String,
	failures: Array[String]
) -> void:
	var hit_area := shop.get_node_or_null(
		"ShopRoot/ShopCategoryTabHitAreas/%sCategoryTabHitArea" % tab_name
	) as Control
	if hit_area == null:
		failures.append("missing %s bookmark hit area" % tab_name)
		return
	var hit_rect := Rect2(hit_area.position, hit_area.size)
	for y_factor in [0.06, 0.5, 0.94]:
		for x_factor in [0.06, 0.5, 0.94]:
			shop.set("_active_category", reset_category)
			shop.call("_refresh_page")
			var point := hit_rect.position + hit_rect.size * Vector2(x_factor, y_factor)
			_send_click(shop, point)
			await process_frame
			if String(shop.get("_active_category")) != expected_category:
				failures.append("%s bookmark did not switch category at edge sample %s" % [tab_name, point])


func _send_click(window: Window, local_position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = local_position
	motion.global_position = local_position
	window.push_input(motion, true)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = local_position
	pressed.global_position = local_position
	window.push_input(pressed, true)
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	released.position = local_position
	released.global_position = local_position
	window.push_input(released, true)
