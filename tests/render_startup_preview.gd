extends SceneTree

const MAIN_SCENE = preload("res://scenes/Main.tscn")
const OUTPUT_PATH := "res://tests/_artifacts/startup_main_preview.png"
const MENU_OUTPUT_PATH := "res://tests/_artifacts/startup_menu_preview.png"


func _initialize() -> void:
	call_deferred("_render_startup_preview")


func _render_startup_preview() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var main_scene := MAIN_SCENE.instantiate()
	root.add_child(main_scene)
	# This exercises the ordinary startup path (including the transparent desktop
	# layer) and waits beyond the observed renderer/window initialization period.
	await create_timer(8.0).timeout
	var image := root.get_texture().get_image()
	var save_error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	var side_drawer := main_scene.get("_side_drawer") as Node
	var menu_window := side_drawer.get("_menu_window") as Window if side_drawer != null else null
	if menu_window != null:
		var menu_error := menu_window.get_texture().get_image().save_png(ProjectSettings.globalize_path(MENU_OUTPUT_PATH))
		if save_error == OK:
			save_error = menu_error
	print("STARTUP_PREVIEW=%s" % ProjectSettings.globalize_path(OUTPUT_PATH))
	print("STARTUP_MENU_PREVIEW=%s" % ProjectSettings.globalize_path(MENU_OUTPUT_PATH))
	quit(save_error)
