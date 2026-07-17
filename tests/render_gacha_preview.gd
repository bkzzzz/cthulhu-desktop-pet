extends SceneTree

const GachaWindow = preload("res://scripts/gacha_window.gd")
const GachaProgression = preload("res://scripts/domain/gacha_progression.gd")


func _initialize() -> void:
	call_deferred("_render_previews")


func _render_previews() -> void:
	var window := GachaWindow.new()
	root.add_child(window)
	window.setup()
	window.visible = true
	await process_frame
	await process_frame
	var initial_path := OS.get_user_data_dir().path_join("gacha_initial_preview.png")
	window.get_texture().get_image().save_png(initial_path)

	var duplicate := GachaProgression.roll_pet(0.0, ["pet1", "pet2"], 0)
	duplicate["name"] = "深渊凝视"
	duplicate["duplicate_faith"] = 650
	window.show_result(duplicate)
	await process_frame
	await process_frame
	var result_path := OS.get_user_data_dir().path_join("gacha_result_preview.png")
	window.get_texture().get_image().save_png(result_path)
	print("PREVIEW_INITIAL=%s" % initial_path)
	print("PREVIEW_RESULT=%s" % result_path)
	window.queue_free()
	quit(0)
