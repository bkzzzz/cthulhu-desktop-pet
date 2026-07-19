extends SceneTree

const PetCatalog = preload("res://scripts/pet_catalog.gd")
const InventoryWindow = preload("res://scripts/inventory_window.gd")
const EvolutionWindow = preload("res://scripts/evolution_window.gd")
const SettingsWindow = preload("res://scripts/settings_window.gd")
const DesktopPetActor = preload("res://scripts/desktop_pet_actor.gd")
const SideDrawerController = preload("res://scripts/side_drawer_controller.gd")
const OUTPUT_DIR := "res://tests/_artifacts"


func _initialize() -> void:
	call_deferred("_render_previews")


func _render_previews() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var inventory := InventoryWindow.new()
	root.add_child(inventory)
	var inventory_entry := PetCatalog.make_inventory_entry("pet1")
	inventory_entry["level"] = 99
	inventory_entry["has_evolution"] = true
	inventory_entry["evolved"] = false
	inventory.setup([inventory_entry])
	inventory.visible = true
	inventory.call("_show_detail_panel", 0)
	await process_frame
	await process_frame
	var hook_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("evolution_hook_preview.png"))
	inventory.get_texture().get_image().save_png(hook_path)
	inventory.visible = false

	var evolution := EvolutionWindow.new()
	root.add_child(evolution)
	evolution.setup("zh")
	evolution.open_for_pet("pet1", "腐生眷族", 100)
	await process_frame
	await process_frame
	var window_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("evolution_window_preview.png"))
	evolution.get_texture().get_image().save_png(window_path)
	evolution.visible = false

	var settings := SettingsWindow.new()
	root.add_child(settings)
	settings.setup("full", "zh")
	var levels := {}
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		levels[String(pet_id_value)] = 100 if String(pet_id_value) in ["pet1", "pet2", "pet3"] else 1
	settings.refresh_debug_values(123456, 999999, 1.0, 1.0, levels)
	settings.open_window()
	settings.call("_open_debug_panel")
	await process_frame
	await process_frame
	var debug_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("debug_pet_levels_preview.png"))
	settings.get_texture().get_image().save_png(debug_path)
	settings.visible = false

	var actor_window := Window.new()
	root.add_child(actor_window)
	actor_window.size = Vector2i(1000, 360)
	actor_window.transparent = true
	actor_window.transparent_bg = true
	actor_window.visible = true
	var x := 170.0
	for pet_id in ["pet1", "pet2", "pet3"]:
		var actor := DesktopPetActor.new()
		actor.setup(pet_id, Vector2i(1000, 360), 0.0, 1000.0, x, 344.0, false, true)
		actor_window.add_child(actor)
		actor.set_battle_mode(true)
		actor.play_battle_attack_toward(1.0)
		x += 320.0
	await process_frame
	await create_timer(0.28).timeout
	var actors_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("evolved_pet_actors_preview.png"))
	actor_window.get_texture().get_image().save_png(actors_path)

	var base_pet3_window := Window.new()
	root.add_child(base_pet3_window)
	base_pet3_window.size = Vector2i(430, 310)
	base_pet3_window.transparent = true
	base_pet3_window.transparent_bg = true
	base_pet3_window.visible = true
	var base_pet3 := DesktopPetActor.new()
	base_pet3.setup("pet3", Vector2i(430, 310), 0.0, 430.0, 215.0, 294.0, false, false)
	base_pet3_window.add_child(base_pet3)
	base_pet3.set_battle_mode(true)
	base_pet3.play_battle_attack_toward(1.0)
	await create_timer(0.28).timeout
	var base_pet3_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("pet3_base_actor_preview.png"))
	base_pet3_window.get_texture().get_image().save_png(base_pet3_path)

	var drawer := SideDrawerController.new()
	root.add_child(drawer)
	drawer.setup()
	var detail_entry := PetCatalog.make_inventory_entry("pet1")
	detail_entry["level"] = 99
	detail_entry["upgrade_level"] = 99
	detail_entry["money_rate"] = 12.5
	detail_entry["has_evolution"] = true
	detail_entry["evolved"] = false
	detail_entry["evolution_icon"] = String(PetCatalog.get_evolution_definition("pet1").get("icon", ""))
	detail_entry["evolution_name"] = String(PetCatalog.get_evolution_definition("pet1").get("evolution_name", ""))
	drawer.refresh_pet_upgrades([detail_entry])
	await process_frame
	var upgrade_button := (drawer.get("_upgrade_buttons") as Dictionary).get("pet1") as Control
	drawer.call("_show_upgrade_detail_panel", "pet1", upgrade_button)
	await process_frame
	await process_frame
	var detail_window := drawer.get("_upgrade_detail_window") as Window
	var detail_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("menu_pet_evolution_info_preview.png"))
	detail_window.get_texture().get_image().save_png(detail_path)

	print("PREVIEW_EVOLUTION_HOOK=%s" % hook_path)
	print("PREVIEW_EVOLUTION_WINDOW=%s" % window_path)
	print("PREVIEW_DEBUG_LEVELS=%s" % debug_path)
	print("PREVIEW_EVOLVED_ACTORS=%s" % actors_path)
	print("PREVIEW_PET3_BASE=%s" % base_pet3_path)
	print("PREVIEW_MENU_EVOLUTION_INFO=%s" % detail_path)
	quit(0)
