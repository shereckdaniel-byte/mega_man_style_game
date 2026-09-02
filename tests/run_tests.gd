## Headless test runner.
##
##   godot --headless --script res://tests/run_tests.gd
##
## Exits 0 when every test passes, 1 otherwise, so CI needs no wrapper.
##
## Tests run from _initialize() as a coroutine rather than from _init(), so that
## a test case can await physics frames. That is what lets integration tests
## drive a real CharacterBody2D through move_and_slide() instead of
## re-implementing the integration and testing the re-implementation.
extends SceneTree

const TEST_DIR := "res://tests"
const PREFIX := "test_"

var _total := 0
var _failed := 0
var _assertions := 0
var _report: PackedStringArray = []


func _initialize() -> void:
	_run_all()


func _run_all() -> void:
	var files := _find_tests(TEST_DIR)
	files.sort()

	for path in files:
		var script: GDScript = load(path)
		if script == null:
			push_error("could not load %s" % path)
			_failed += 1
			continue
		var instance: Variant = script.new()
		if not (instance is TestCase):
			push_error("%s does not extend TestCase" % path)
			_failed += 1
			continue

		var test_case := instance as TestCase
		test_case.tree = self
		var names := _test_methods(script)
		names.sort()

		for method in names:
			_total += 1
			test_case.reset()
			if test_case.is_async():
				await test_case.before_each_async()
				await test_case.call(method)
				await test_case.after_each_async()
			else:
				test_case.before_each()
				test_case.call(method)
				test_case.after_each()
			_record(method, test_case)

		_report.append("%s (%d)" % [path.get_file(), names.size()])

	print("\n".join(_report))
	print("")
	print("%d tests, %d assertions, %d failed" % [_total, _assertions, _failed])
	quit(1 if _failed > 0 else 0)


func _record(method: String, test_case: TestCase) -> void:
	_assertions += test_case.assertion_count()
	var problems := test_case.failures()
	if problems.is_empty():
		_report.append("  ok    %s" % method)
		return
	_failed += 1
	_report.append("  FAIL  %s" % method)
	for problem in problems:
		_report.append("          %s" % problem)


## Test methods are found by reflection: any method named test_*, declared on
## the script itself rather than inherited from TestCase.
func _test_methods(script: GDScript) -> PackedStringArray:
	var out: PackedStringArray = []
	for method: Dictionary in script.get_script_method_list():
		var name: String = method.get("name", "")
		if name.begins_with(PREFIX) and not out.has(name):
			out.append(name)
	return out


func _find_tests(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("no test directory at %s" % dir_path)
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				out.append_array(_find_tests(full))
		elif entry.begins_with(PREFIX) and entry.ends_with(".gd") and entry != "test_case.gd":
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return out
