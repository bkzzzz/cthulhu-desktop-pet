extends SceneTree

const OfferingCatalog = preload("res://scripts/domain/offering_catalog.gd")
const TurretCatalog = preload("res://scripts/domain/turret_catalog.gd")
const ShopWindow = preload("res://scripts/shop_window.gd")
const TurretActor = preload("res://scripts/turret_actor.gd")
const OUTPUT_DIR := "res://tests/_artifacts"


func _initialize() -> void:
	call_deferred("_render_previews")


func _render_previews() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var shop := ShopWindow.new()
	root.add_child(shop)
	shop.setup()
	var goods := OfferingCatalog.make_shop_goods()
	goods.append_array(TurretCatalog.make_shop_goods())
	shop.set_goods(goods)
	shop.set_language("zh")
	shop.set_coin_balance(5_000_000)
	shop.set_turret_states({
		"turret1": {"owned": true, "deployed": true, "current_hp": 31.0},
		"turret2": {"owned": true, "deployed": false, "current_hp": 74.0}
	})
	shop.set("_active_category", TurretCatalog.KIND)
	shop.call("_refresh_page")
	shop.visible = true
	await process_frame
	await process_frame
	var tower_shop_path := ProjectSettings.globalize_path(
		OUTPUT_DIR.path_join("shop_tower_actions_preview.png")
	)
	shop.get_texture().get_image().save_png(tower_shop_path)

	shop.set("_active_category", ShopWindow.FURNITURE_KIND)
	shop.call("_refresh_page")
	await process_frame
	await process_frame
	var furniture_path := ProjectSettings.globalize_path(
		OUTPUT_DIR.path_join("shop_furniture_empty_preview.png")
	)
	shop.get_texture().get_image().save_png(furniture_path)
	shop.visible = false

	var stage_size := root.size
	var tower := TurretActor.new()
	root.add_child(tower)
	tower.setup(
		"turret1",
		Vector2(float(stage_size.x) * 0.5, float(stage_size.y) - 6.0),
		stage_size
	)
	tower.set_language("zh")
	tower.set_durability(31.0, 46.0)
	tower.call("_set_pointer_hovered", true)
	await process_frame
	await process_frame
	var hover_path := ProjectSettings.globalize_path(
		OUTPUT_DIR.path_join("desktop_tower_hover_preview.png")
	)
	root.get_texture().get_image().save_png(hover_path)

	print("PREVIEW_TOWER_SHOP=%s" % tower_shop_path)
	print("PREVIEW_FURNITURE=%s" % furniture_path)
	print("PREVIEW_TOWER_HOVER=%s" % hover_path)
	quit(0)
