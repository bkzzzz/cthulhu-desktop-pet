extends SceneTree

const DesktopPetActor = preload("res://scripts/desktop_pet_actor.gd")
const EnemyActor = preload("res://scripts/enemy_actor.gd")


func _initialize() -> void:
	call_deferred("_render_preview")


func _render_preview() -> void:
	var window := Window.new()
	window.size = Vector2i(1200, 720)
	window.min_size = window.size
	root.add_child(window)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.018, 0.026, 0.045)
	backdrop.size = Vector2(window.size)
	window.add_child(backdrop)

	var title := Label.new()
	title.text = "FINAL ORRERY  ·  PHASE II"
	title.position = Vector2(32.0, 28.0)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.96, 0.80, 0.38))
	window.add_child(title)

	var pet := DesktopPetActor.new()
	pet.setup("pet10", window.size, 0.0, 1200.0, 900.0, 704.0, false, true)
	pet.position.x = 900.0
	window.add_child(pet)
	pet.set_battle_mode(true)
	pet.play_battle_attack_toward(-1.0)

	var boss := EnemyActor.new()
	boss.setup("final_boss", Vector2(300.0, 704.0), 704.0, 2.4, 300.0)
	boss.set_target(pet)
	window.add_child(boss)
	boss.take_damage(boss.max_health * 0.55, 0.0)
	boss.set("_attack_cooldown", 0.0)
	boss.call("_process", 0.01)
	boss.call("_process", 0.34)

	window.visible = true
	for _frame in 8:
		await process_frame
	var preview_path := OS.get_user_data_dir().path_join("final_boss_preview.png")
	var image := window.get_texture().get_image()
	if image == null:
		push_error("Final boss preview capture returned no image")
		window.queue_free()
		quit(1)
		return
	var save_error := image.save_png(preview_path)
	if save_error != OK:
		push_error("Could not save final boss preview: %s" % error_string(save_error))
		window.queue_free()
		quit(1)
		return
	print("PREVIEW_FINAL_BOSS=%s" % preview_path)
	window.queue_free()
	quit(0)
