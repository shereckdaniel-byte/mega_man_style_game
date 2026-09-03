## Headless test runner.
##
##   godot --headless --script res://tests/run_tests.gd
##   godot --headless --script res://tests/run_tests.gd -- backdrop
##   godot --headless --script res://tests/run_tests.gd -- backdrop rising_tide
##
## Exits 0 when every test passes, 1 otherwise, so CI needs no wrapper.
##
## Tests run from _initialize() as a coroutine rather than from _init(), so that
## a test case can await physics frames. That is what lets integration tests
## drive a real CharacterBody2D through move_and_slide() instead of
## re-implementing the integration and testing the re-implementation.
##
## **Arguments after `--` narrow the run.** Each is a case-insensitive substring
## matched against the file name and the method name: a file that matches runs
## whole, and in a file that does not, the methods that match run on their own.
## Several arguments are an or.
##
## This exists because the suite is minutes long and most edits touch one file.
## Without it the only way to check six new tests was to run all 273, which is
## slow enough that the check stops being run -- and a check that is skipped is
## worse than one that is slow. CI passes no arguments and is unaffected.
extends SceneTree

const TEST_DIR := "res://tests"
const PREFIX := "test_"

var _total := 0
var _failed := 0
var _assertions := 0
var _report: PackedStringArray = []
## Empty means everything, which is what CI runs.
var _filters: PackedStringArray = []


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		var filter := argument.strip_edges().to_lower()
		if not filter.is_empty():
			_filters.append(filter)
	_run_all()


func _run_all() -> void:
	var files := _find_tests(TEST_DIR)
	files.sort()

	var ran_files := 0
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

		var names := _selected_methods(script, path)
		if names.is_empty():
			continue
		ran_files += 1

		var test_case := instance as TestCase
		test_case.tree = self

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
	# A filter that matched nothing is a typo, and reporting "0 tests, 0 failed"
	# for it is the failure mode this whole project keeps running into: a green
	# result that means nothing was checked. So it exits 1 and says so.
	if _total == 0 and not _filters.is_empty():
		printerr("no test matches %s" % " ".join(_filters))
		quit(1)
		return
	# The filter is printed with the count so a narrowed run can never be read
	# as a clean full suite further up the scrollback.
	var scope := "" if _filters.is_empty() \
		else "  [filtered by %s -- %d of %d files]" % [" ".join(_filters), ran_files, files.size()]
	print("%d tests, %d assertions, %d failed%s" % [_total, _assertions, _failed, scope])
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


## The test methods to run from one file, in order.
##
## A filter naming the file selects all of it -- narrowing to a file you are
## working on is the common case, and having to also name every method in it
## would make the shortcut useless.
func _selected_methods(script: GDScript, path: String) -> PackedStringArray:
	var found := _test_methods(script)
	found.sort()
	if _filters.is_empty():
		return found
	var file_name := path.get_file().to_lower()
	for filter in _filters:
		if file_name.contains(filter):
			return found
	var out: PackedStringArray = []
	for method in found:
		for filter in _filters:
			if method.to_lower().contains(filter):
				out.append(method)
				break
	return out


## Test methods are found by reflection: any method named test_*, declared on
## the script itself rather than inherited from TestCase.
func _test_methods(script: GDScript) -> PackedStringArray:
	var out: PackedStringArray = []
	for method: Dictionary in script.get_script_method_list():
		var method_name: String = method.get("name", "")
		if method_name.begins_with(PREFIX) and not out.has(method_name):
			out.append(method_name)
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
