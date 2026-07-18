extends SceneTree

const DesktopPetActor = preload("res://scripts/desktop_pet_actor.gd")
const EnemyActor = preload("res://scripts/enemy_actor.gd")
const EnemyProjectileActor = preload("res://scripts/enemy_projectile_actor.gd")


func _initialize() -> void:
	call_deferred("_render_preview")


func _render_preview() -> void:
	var window := Window.new()
	window.size = Vector2i(1200, 720)
	window.min_size = window.size
	root.add_child(window)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025, 0.045, 0.075)
	backdrop.size = Vector2(window.size)
	window.add_child(backdrop)

	var pet6 := DesktopPetActor.new()
	pet6.setup("pet6", window.size, 0.0, 1200.0, 720.0, 704.0, false)
	pet6.position.x = 930.0
	window.add_child(pet6)
	pet6.set_autonomy_paused(true)
	pet6.set("_behavior", DesktopPetActor.Behavior.DOZING)
	pet6.set_battle_mode(true)
	pet6.play_battle_attack_toward(-1.0)

	var enemy_ids := ["outerspace1", "outerspace2", "outerspace3"]
	for enemy_index in enemy_ids.size():
		var enemy := EnemyActor.new()
		var enemy_x := 150.0 + float(enemy_index) * 230.0
		enemy.setup(enemy_ids[enemy_index], Vector2(enemy_x, 704.0), 704.0, 1.0, enemy_x)
		enemy.set_target(pet6)
		enemy.projectile_requested.connect(_spawn_preview_projectile.bind(window))
		window.add_child(enemy)
		enemy.call("_process", 0.01)
		enemy.call("_process", 0.4)

	window.visible = true
	for _frame in 5:
		await process_frame
	var preview_path := OS.get_user_data_dir().path_join("battle_outerspace_preview.png")
	window.get_texture().get_image().save_png(preview_path)
	print("PREVIEW_BATTLE=%s" % preview_path)
	window.queue_free()
	quit(0)


func _spawn_preview_projectile(
	actor: Node2D,
	target: Node2D,
	damage: float,
	projectile_kind: String,
	power_scale: float,
	window: Window
) -> void:
	var projectile := EnemyProjectileActor.new()
	projectile.setup(projectile_kind, actor.get_projectile_origin(), target, damage, power_scale)
	window.add_child(projectile)
