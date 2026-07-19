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
	window.call("_apply_egg_shuffle_step", 0)
	window.call("_on_draw_amount_preset_pressed", 1000)
	window.call("_update_draw_button")
	await process_frame
	var shuffle_path := OS.get_user_data_dir().path_join("gacha_shuffle_preview.png")
	window.get_texture().get_image().save_png(shuffle_path)
	window.call("_on_draw_amount_preset_pressed", -1)
	var custom_input: LineEdit = window.get("_custom_draw_input")
	custom_input.text = "237"
	await process_frame
	var custom_path := OS.get_user_data_dir().path_join("gacha_custom_preview.png")
	window.get_texture().get_image().save_png(custom_path)

	var duplicate := GachaProgression.roll_pet(0.0, ["pet1", "pet2"], 0)
	duplicate["name"] = "深渊凝视"
	duplicate["duplicate_faith"] = 650
	var new_pet := GachaProgression.roll_pet(0.5, ["pet1"], 4)
	new_pet["name"] = "新宠物"
	window.show_results([new_pet, duplicate])
	window.call("_show_batch_summary")
	await process_frame
	await process_frame
	var result_path := OS.get_user_data_dir().path_join("gacha_result_preview.png")
	window.get_texture().get_image().save_png(result_path)
	print("PREVIEW_INITIAL=%s" % initial_path)
	print("PREVIEW_SHUFFLE=%s" % shuffle_path)
	print("PREVIEW_CUSTOM=%s" % custom_path)
	print("PREVIEW_RESULT=%s" % result_path)
	window.queue_free()
	quit(0)
