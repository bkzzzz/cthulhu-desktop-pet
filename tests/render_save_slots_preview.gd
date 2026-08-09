extends SceneTree

const SettingsWindow = preload("res://scripts/settings_window.gd")
const OUTPUT_DIR := "res://tests/_artifacts"


func _initialize() -> void:
	call_deferred("_render_preview")


func _render_preview() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var settings := SettingsWindow.new()
	root.add_child(settings)
	settings.setup("full", "en")
	settings.set_save_slots([
		{
			"id": "slot_000001",
			"display_name": "Campaign — The First Cult",
			"has_data": true,
			"is_active": true,
			"playtime_seconds": 8_460.0
		},
		{
			"id": "slot_000002",
			"display_name": "Desktop Items Test",
			"has_data": true,
			"is_active": false,
			"playtime_seconds": 2_940.0
		},
		{
			"id": "slot_000003",
			"display_name": "Fresh Slot",
			"has_data": false,
			"is_active": false,
			"playtime_seconds": 0.0
		}
	], "slot_000001")
	settings.open_window()
	settings.call("_open_save_slots_panel")
	await process_frame
	await process_frame
	await process_frame
	await create_timer(0.45).timeout
	var preview_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("save_slots_preview.png"))
	settings.get_texture().get_image().save_png(preview_path)
	print("PREVIEW_SAVE_SLOTS=%s" % preview_path)
	quit(0)
