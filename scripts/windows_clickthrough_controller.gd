extends RefCounted

const HELPER_SCRIPT := "res://scripts/windows_clickthrough_helper.ps1"

var _enabled := false
var _clickthrough := false
var _state_path := ""
var _helper_pid := -1


func setup(window: Window, label: String) -> bool:
	if OS.get_name() != "Windows" or window == null:
		return false
	if _enabled:
		return true

	var window_id := window.get_window_id()
	if window_id <= 0:
		return false

	var hwnd := int(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, window_id))
	if hwnd <= 0:
		return false

	var helper_path := ProjectSettings.globalize_path(HELPER_SCRIPT)
	if not FileAccess.file_exists(helper_path):
		return false

	var safe_label := label.replace(" ", "_")
	_state_path = ProjectSettings.globalize_path("user://%s_clickthrough_%d.state" % [safe_label, hwnd])
	_write_state(true)

	var args := PackedStringArray([
		"-NoProfile",
		"-ExecutionPolicy",
		"Bypass",
		"-WindowStyle",
		"Hidden",
		"-File",
		helper_path,
		str(hwnd),
		_state_path
	])
	_helper_pid = OS.create_process("powershell.exe", args, false)
	_enabled = _helper_pid > 0
	_clickthrough = true
	return _enabled


func set_clickthrough(enabled: bool, force := false) -> bool:
	if not _enabled:
		return false
	if not force and _clickthrough == enabled:
		return true

	_clickthrough = enabled
	_write_state(enabled)
	return true


func shutdown() -> void:
	if _enabled:
		_write_raw_state("exit")
	if _helper_pid > 0:
		OS.kill(_helper_pid)
	_helper_pid = -1
	_enabled = false
	_remove_state_file()


func _write_state(enabled: bool) -> void:
	_write_raw_state("1" if enabled else "0")


func _write_raw_state(state: String) -> void:
	if _state_path.is_empty():
		return

	var file := FileAccess.open(_state_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(state)


func _remove_state_file() -> void:
	if _state_path.is_empty():
		return

	var dir := DirAccess.open(_state_path.get_base_dir())
	if dir != null:
		dir.remove(_state_path.get_file())
