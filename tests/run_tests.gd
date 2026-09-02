## Headless test runner.
##
##   godot --headless --script res://tests/run_tests.gd
##
## Exits 0 when every test passes, 1 otherwise, so CI needs no wrapper.
extends SceneTree

const TEST_DIR := "res://tests"
const PREFIX := "test_"


func _init() -> void:
	var files := _find_tests(TEST_DIR)
	files.sort()

	var total := 0
	var failed := 0
	var assertions := 0
	var report: PackedStringArray = []

	for path in files:
		var script: GDScript = load(path)
		if script == null:
			push_error("could not load %s" % path)
			failed += 1
			continue
		var instance: Variant = script.new()
		if not (instance is TestCase):
			push_error("%s does not extend TestCase" % path)
			failed += 1
			continue

		var test_case := instance as TestCase
		test_case.tree = self
		var names := _test_methods(script)
		names.sort()

		for method in names:
			total += 1
			test_case.reset()
			test_case.before_each()
			test_case.call(method)
			test_case.after_each()
			assertions += test_case.assertion_count()
			var problems := test_case.failures()
			if problems.is_empty():
				report.append("  ok    %s" % method)
			else:
				failed += 1
				report.append("  FAIL  %s" % method)
				for problem in problems:
					report.append("          %s" % problem)

		report.append("%s (%d)" % [path.get_file(), names.size()])

	print("\n".join(report))
	print("")
	print("%d tests, %d assertions, %d failed" % [total, assertions, failed])
	quit(1 if failed > 0 else 0)


## Test methods are found by reflection: any method named test_*, declared on the
## script itself rather than inherited from TestCase.
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
