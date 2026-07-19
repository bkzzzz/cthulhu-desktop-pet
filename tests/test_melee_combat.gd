extends RefCounted

const Main = preload("res://scripts/main.gd")
const EnemyActor = preload("res://scripts/enemy_actor.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_battle_facing_is_target_stable(failures)
	_test_melee_chases_while_ranged_holds(failures)
	_test_freed_target_lock_recovers(failures)
	_test_enemy_entry_cannot_be_camped(failures)
	_test_pet5_form_specific_rolling(failures)
	_test_pet5_roll_crushes_each_enemy_once(failures)
	return failures


static func _test_battle_facing_is_target_stable(failures: Array[String]) -> void:
	var pet := Main.DesktopPetActor.new()
	pet.setup("pet1", Vector2i(1000, 720), 0.0, 1000.0, 500.0, 704.0, false)
	pet.set_battle_mode(true)
	var sprite := pet.get_node_or_null("pet1Sprite") as AnimatedSprite2D
	var authored_faces_right := bool(pet.get("_faces_right"))
	if sprite == null:
		failures.append("battle-facing test pet must build its sprite")
		pet.free()
		return
	if sprite.flip_h != authored_faces_right:
		failures.append("every pet must face left as soon as a battle starts")
	pet.battle_move_toward(620.0, 1.0, 500.0, 1.0)
	if sprite.flip_h == authored_faces_right:
		failures.append("a pet must face right when its locked enemy is genuinely on the right")
	pet.battle_move_toward(380.0, 1.0, 500.0, -1.0)
	if sprite.flip_h != authored_faces_right:
		failures.append("arriving at a left-side target must not create a one-frame right-facing flicker")
	pet.free()


static func _test_melee_chases_while_ranged_holds(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_battle_active", true)
	main.set("_pet_window_size", Vector2i(1100, 720))
	var melee := Main.DesktopPetActor.new()
	melee.setup("pet1", Vector2i(1100, 720), 0.0, 1100.0, 850.0, 704.0, false)
	melee.set_battle_mode(true)
	main.add_child(melee)
	(main.get("_pets") as Array).append(melee)
	var melee_key := str(melee.get_instance_id())
	(main.get("_battle_pet_health") as Dictionary)[melee_key] = 20.0
	(main.get("_battle_pet_formed") as Dictionary)[melee_key] = true

	var ranged := Main.DesktopPetActor.new()
	ranged.setup("pet2", Vector2i(1100, 720), 0.0, 1100.0, 930.0, 704.0, false)
	ranged.set_battle_mode(true)
	main.add_child(ranged)
	(main.get("_pets") as Array).append(ranged)
	var ranged_key := str(ranged.get_instance_id())
	(main.get("_battle_pet_health") as Dictionary)[ranged_key] = 10.0
	(main.get("_battle_pet_formed") as Dictionary)[ranged_key] = true

	var enemy := EnemyActor.new()
	enemy.setup("villager1", Vector2(210.0, 704.0), 704.0, 1.0, 210.0)
	main.add_child(enemy)
	(main.get("_battle_enemies") as Array).append(enemy)
	var melee_start_x := melee.position.x
	var ranged_start_x := ranged.position.x
	main.call("_update_battle_pet_formation", 0.1)
	if melee.position.x >= melee_start_x:
		failures.append("formed melee pets must actively seek and charge a distant enemy")
	if not is_equal_approx(ranged.position.x, ranged_start_x):
		failures.append("ranged pets must hold the rear line while melee pets charge")

	# Target locks keep the chosen facing stable even when another enemy briefly
	# becomes a few pixels nearer on the opposite side.
	var locked_target := main.call("_get_battle_target_for_pet", melee) as Node2D
	var second_enemy := EnemyActor.new()
	second_enemy.setup("villager2", Vector2(melee.position.x + 20.0, 704.0), 704.0, 1.0, melee.position.x + 20.0)
	main.add_child(second_enemy)
	(main.get("_battle_enemies") as Array).append(second_enemy)
	if main.call("_get_battle_target_for_pet", melee) != locked_target:
		failures.append("melee target selection must not oscillate between enemies every frame")

	melee.position.x = 270.0
	var candidates: Array[Node2D] = [ranged, melee]
	if main.call("_get_nearest_battle_pet", enemy, candidates) != melee:
		failures.append("a player-positioned front-line melee pet must intercept enemy targeting before rear pets")

	melee.play_battle_attack_toward(-1.0)
	var melee_sprite := melee.get_node_or_null("pet1Sprite") as AnimatedSprite2D
	main.call("_update_battle_pet_formation", 0.1)
	if melee_sprite != null and melee_sprite.animation != "attack":
		failures.append("melee pursuit must not cancel an authored attack animation on its next frame")
	main.free()


static func _test_freed_target_lock_recovers(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_battle_active", true)
	var pet := Main.DesktopPetActor.new()
	pet.setup("pet1", Vector2i(1000, 720), 0.0, 1000.0, 700.0, 704.0, false)
	main.add_child(pet)
	var first_enemy := EnemyActor.new()
	first_enemy.setup("villager1", Vector2(520.0, 704.0), 704.0, 1.0, 520.0)
	main.add_child(first_enemy)
	var next_enemy := EnemyActor.new()
	next_enemy.setup("villager2", Vector2(410.0, 704.0), 704.0, 1.0, 410.0)
	main.add_child(next_enemy)
	var enemies: Array = main.get("_battle_enemies")
	enemies.append_array([first_enemy, next_enemy])
	var actor_key := str(pet.get_instance_id())
	(main.get("_battle_pet_enemy_targets") as Dictionary)[actor_key] = first_enemy
	# Reproduce the frame boundary that used to freeze combat: the lock keeps an
	# Object Variant after the target has already left the tree and been freed.
	enemies.erase(first_enemy)
	first_enemy.free()
	var replacement := main.call("_get_battle_target_for_pet", pet) as Node2D
	if replacement != next_enemy:
		failures.append("a freed enemy target lock must be discarded and retargeted without aborting battle updates")
	main.free()


static func _test_enemy_entry_cannot_be_camped(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_battle_active", true)
	var pet := Main.DesktopPetActor.new()
	pet.setup("pet10", Vector2i(1000, 720), 0.0, 1000.0, 140.0, 704.0, false)
	main.add_child(pet)
	var enemy := EnemyActor.new()
	enemy.setup("villager1", Vector2(-80.0, 704.0), 704.0, 1.0, 180.0)
	main.add_child(enemy)
	(main.get("_battle_enemies") as Array).append(enemy)
	var health_before := enemy.get_health()
	enemy.take_damage(999.0)
	if enemy.get_health() != health_before:
		failures.append("an offscreen enemy must be protected until it reaches its battlefield entry post")
	if main.call("_get_battle_target_for_pet", pet) != null:
		failures.append("pets must not lock enemies while they are still entering from offscreen")
	enemy.call("_process", 3.0)
	if not bool(enemy.call("has_entered_battlefield")):
		failures.append("an enemy must become targetable after reaching its entry post")
	elif main.call("_get_battle_target_for_pet", pet) != enemy:
		failures.append("pets must immediately acquire an enemy after its protected entry ends")
	main.free()


static func _test_pet5_form_specific_rolling(failures: Array[String]) -> void:
	var base_pet5 := Main.DesktopPetActor.new()
	base_pet5.setup("pet5", Vector2i(1000, 720), 0.0, 1000.0, 620.0, 704.0, false, false)
	if not base_pet5.uses_battle_roll_attack():
		failures.append("base pet5 must expose its ball-form rolling attack")
	base_pet5.set("_behavior", Main.DesktopPetActor.Behavior.WALK)
	base_pet5.set("_target_x", base_pet5.position.x - 120.0)
	base_pet5.set("_walk_speed", 180.0)
	base_pet5.call("_update_walking", 0.1)
	var base_sprite := base_pet5.get_node_or_null("pet5Sprite") as AnimatedSprite2D
	if base_sprite == null or is_zero_approx(base_sprite.rotation):
		failures.append("base pet5 must continuously rotate whenever ordinary movement changes its position")
	base_pet5.call("_start_idle")
	if base_sprite != null and not is_zero_approx(base_sprite.rotation):
		failures.append("base pet5 must settle upright after it stops rolling")
	base_pet5.free()

	if not Main.PetCatalog.has_evolution("pet5"):
		failures.append("pet5 evolved assets must be registered so the worm form can stay separate")
		return
	var evolved_pet5 := Main.DesktopPetActor.new()
	evolved_pet5.setup("pet5", Vector2i(1000, 720), 0.0, 1000.0, 620.0, 704.0, false, true)
	if evolved_pet5.uses_battle_roll_attack():
		failures.append("evolved pet5 is a worm and must use its own walk/attack instead of rotating as a ball")
	evolved_pet5.set_battle_mode(true)
	if evolved_pet5.begin_battle_roll_attack(300.0):
		failures.append("evolved pet5 must never enter the base ball-form crush animation")
	evolved_pet5.free()


static func _test_pet5_roll_crushes_each_enemy_once(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_battle_active", true)
	main.set("_simulation_now_seconds", 100.0)
	main.set("_battle_started_at", 100.0)
	main.set("_battle_ends_at", 200.0)
	main.set("_battle_wave_schedule", [])
	main.set("_battle_next_wave_index", 0)
	main.set("_pet_window_size", Vector2i(1100, 720))
	var pet5 := Main.DesktopPetActor.new()
	pet5.setup("pet5", Vector2i(1100, 720), 0.0, 1100.0, 820.0, 704.0, false, false)
	pet5.set_battle_mode(true)
	pet5.battle_roll_swept.connect(Callable(main, "_on_pet5_battle_roll_swept"))
	pet5.battle_roll_finished.connect(Callable(main, "_on_pet5_battle_roll_finished"))
	main.add_child(pet5)
	(main.get("_pets") as Array).append(pet5)
	var pet_key := str(pet5.get_instance_id())
	(main.get("_battle_pet_health") as Dictionary)[pet_key] = 30.0
	(main.get("_battle_pet_max_health") as Dictionary)[pet_key] = 30.0
	(main.get("_battle_pet_formed") as Dictionary)[pet_key] = true
	(main.get("_battle_pet_attack_at") as Dictionary)[pet_key] = 0.0

	var enemy_a := EnemyActor.new()
	enemy_a.setup("victorian_boss", Vector2(720.0, 704.0), 704.0, 1.0, 720.0)
	main.add_child(enemy_a)
	(main.get("_battle_enemies") as Array).append(enemy_a)
	var enemy_b := EnemyActor.new()
	enemy_b.setup("victorian_boss", Vector2(650.0, 704.0), 704.0, 1.0, 650.0)
	main.add_child(enemy_b)
	(main.get("_battle_enemies") as Array).append(enemy_b)
	var health_a_before := enemy_a.get_health()
	var health_b_before := enemy_b.get_health()
	main.call("_update_battle", 0.016)
	if not pet5.is_battle_roll_active():
		failures.append("base pet5 attacks must begin a real movement-based roll toward the enemy")
		main.free()
		return
	var roll_data: Dictionary = (main.get("_battle_pet5_rolls") as Dictionary).get(pet_key, {})
	var expected_damage := float(roll_data.get("damage", 0.0))
	pet5.call("_update_pet", 0.1)
	pet5.call("_update_pet", 0.1)
	if not is_equal_approx(health_a_before - enemy_a.get_health(), expected_damage):
		failures.append("pet5 must damage the first enemy crossed by its rolling path exactly once")
	if not is_equal_approx(health_b_before - enemy_b.get_health(), expected_damage):
		failures.append("pet5 must damage every additional enemy crossed by the same roll exactly once")
	var health_a_after := enemy_a.get_health()
	var health_b_after := enemy_b.get_health()
	main.call("_on_pet5_battle_roll_swept", pet5, 744.0, 668.0)
	if not is_equal_approx(enemy_a.get_health(), health_a_after) or not is_equal_approx(enemy_b.get_health(), health_b_after):
		failures.append("one pet5 roll must not repeatedly damage an enemy on overlapping sweep frames")
	if (main.get("_battle_effects") as Array).size() < 2:
		failures.append("each enemy crushed by pet5 must receive a visible impact effect")
	pet5.call("_update_pet", 0.2)
	if pet5.is_battle_roll_active():
		failures.append("pet5 must stop and settle after reaching the far side of its crush target")
	main.free()
