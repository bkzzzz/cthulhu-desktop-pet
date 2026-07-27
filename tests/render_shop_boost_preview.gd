extends SceneTree

const EconomyBalance = preload("res://scripts/domain/economy_balance.gd")
const OfferingCatalog = preload("res://scripts/domain/offering_catalog.gd")
const PetCatalog = preload("res://scripts/pet_catalog.gd")
const ShopWindow = preload("res://scripts/shop_window.gd")
const SideDrawer = preload("res://scripts/side_drawer_controller.gd")
const OUTPUT_DIR := "res://tests/_artifacts"


func _initialize() -> void:
	call_deferred("_render_previews")


func _render_previews() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var shop := ShopWindow.new()
	root.add_child(shop)
	shop.setup()
	shop.set_goods(EconomyBalance.make_dynamic_shop_goods(
		OfferingCatalog.make_shop_goods(),
		185.0
	))
	shop.set_coin_balance(12_450)
	shop.visible = true
	await process_frame
	await process_frame
	var shop_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("shop_dynamic_price_preview.png"))
	shop.get_texture().get_image().save_png(shop_path)

	var drawer := SideDrawer.new()
	root.add_child(drawer)
	drawer.setup()
	drawer.refresh_faith(1_284_550.0, 842.5)
	var entries: Array[Dictionary] = []
	for index in 3:
		var pet_id := String(PetCatalog.ACTIVE_DESKTOP_PETS[index])
		var entry := PetCatalog.make_inventory_entry(pet_id)
		entry["level"] = 45 + index * 8
		entry["cost"] = 2000 + index * 800
		entry["current_fps"] = 125.0 + index * 40.0
		entry["next_fps"] = 132.0 + index * 44.0
		entry["affordable"] = true
		entry["offering_multiplier"] = 5.0 if index == 0 else 1.0
		entry["offering_seconds_remaining"] = 42.0 if index == 0 else 0.0
		entries.append(entry)
	drawer.refresh_pet_upgrades(entries)
	drawer.call("_toggle_drawer")
	await process_frame
	await create_timer(0.24).timeout
	var drawer_window := drawer.get("_drawer_window") as Window
	var boost_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("menu_boost_aura_preview.png"))
	drawer_window.get_texture().get_image().save_png(boost_path)

	print("PREVIEW_SHOP=%s" % shop_path)
	print("PREVIEW_BOOST=%s" % boost_path)
	quit(0)
