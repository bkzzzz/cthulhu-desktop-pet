extends SceneTree

const TEST_SUITES := [
	preload("res://tests/test_pet_progression.gd"),
	preload("res://tests/test_pet_catalog.gd"),
	preload("res://tests/test_follower_progression.gd"),
	preload("res://tests/test_ui_number_format.gd")
]


func _initialize() -> void:
	var failures: Array[String] = []
	var checks := 0
	for suite in TEST_SUITES:
		var suite_failures: Array[String] = suite.run()
		checks += 1
		failures.append_array(suite_failures)

	if failures.is_empty():
		print("PASS: %d test suite(s)" % checks)
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	print("FAIL: %d failure(s)" % failures.size())
	quit(1)
