extends RefCounted

const HELPER_SCRIPT := "res://scripts/windows_visual_clickthrough_once.ps1"
const RUNTIME_HELPER_SCRIPT := "user://windows_visual_clickthrough_once.ps1"


static func apply(window: Window) -> bool:
	if window == null:
		return false
	if DisplayServer.get_name() == "headless":
		return true

	# Keep Godot's cross-platform passthrough enabled as the first line of
	# defence. On Windows, transparent borderless windows still need the native
	# WS_EX_TRANSPARENT flag to let other desktop applications receive clicks.
	window.mouse_passthrough = true
	if OS.get_name() != "Windows":
		return window.mouse_passthrough

	var window_id := window.get_window_id()
	if window_id == DisplayServer.INVALID_WINDOW_ID:
		return false
	var hwnd := int(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, window_id))
	if hwnd == 0:
		return false
	var helper_path := _prepare_runtime_helper()
	if helper_path.is_empty():
		return false

	# Do not wait here. OS.execute(..., blocking=true) freezes Godot's main
	# thread on some Windows systems while PowerShell/Add-Type starts up.
	var helper_pid := OS.create_process(
		"powershell.exe",
		PackedStringArray([
			"-NoProfile",
			"-ExecutionPolicy", "Bypass",
			"-WindowStyle", "Hidden",
			"-File", helper_path,
			str(hwnd)
		]),
		false
	)
	return helper_pid > 0


static func _prepare_runtime_helper() -> String:
	var source := FileAccess.open(HELPER_SCRIPT, FileAccess.READ)
	if source == null:
		return ""
	var script_text := source.get_as_text()
	source.close()
	if script_text.is_empty():
		return ""
	var target := FileAccess.open(RUNTIME_HELPER_SCRIPT, FileAccess.WRITE)
	if target == null:
		return ""
	target.store_string(script_text)
	target.close()
	return ProjectSettings.globalize_path(RUNTIME_HELPER_SCRIPT)
