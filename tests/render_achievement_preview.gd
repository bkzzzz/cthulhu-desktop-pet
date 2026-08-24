extends SceneTree

const AchievementWindow = preload("res://scripts/achievement_window.gd")

const OUTPUT_PATH := "res://tests/_artifacts/achievement_preview.png"


func _initialize() -> void:
	call_deferred("_render_preview")


func _render_preview() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/_artifacts"))
	var window := AchievementWindow.new()
	root.add_child(window)
	window.setup()
	window.set_language("zh")
	window.refresh_state({
		"battle_victories": 10,
		"faith_rate": 12_450.0,
		"followers": 18_600,
		"pets_unlocked": 6,
	}, ["battle_1", "rate_1", "followers_100"])
	window.visible = true
	await process_frame
	await process_frame
	var output_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	window.get_texture().get_image().save_png(output_path)
	print("ACHIEVEMENT_PREVIEW=%s" % output_path)
	quit(0)
