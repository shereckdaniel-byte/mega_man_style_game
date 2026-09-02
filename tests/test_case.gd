## Base class for tests. Subclass it, name methods test_*, and the runner finds
## them by reflection.
##
## This is deliberately ~100 lines rather than a vendored framework: the tests
## this project needs are physics simulations and resource lints, not fixtures
## and mocks. Test bodies are plain GDScript, so moving to gdUnit4 or GUT later
## is a rename of the assert calls, not a rewrite. See docs/ARCHITECTURE.md
## section 9.
class_name TestCase
extends RefCounted

## Injected by the runner so tests that need real nodes can add them.
var tree: SceneTree

var _failures: PackedStringArray = []
var _assertions := 0


## Override for per-test setup.
func before_each() -> void:
	pass


## Override for per-test teardown. Runs even if the test failed.
func after_each() -> void:
	pass


func failures() -> PackedStringArray:
	return _failures


func assertion_count() -> int:
	return _assertions


func reset() -> void:
	_failures = []
	_assertions = 0


# --- Assertions ---------------------------------------------------------------

func assert_true(value: bool, message: String = "") -> void:
	_check(value, "expected true", message)


func assert_false(value: bool, message: String = "") -> void:
	_check(not value, "expected false", message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	_check(actual == expected, "expected %s, got %s" % [expected, actual], message)


func assert_ne(actual: Variant, expected: Variant, message: String = "") -> void:
	_check(actual != expected, "expected anything but %s" % [expected], message)


func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.001,
		message: String = "") -> void:
	_check(absf(actual - expected) <= tolerance,
		"expected %f +/- %f, got %f" % [expected, tolerance, actual], message)


func assert_between(actual: float, low: float, high: float, message: String = "") -> void:
	_check(actual >= low and actual <= high,
		"expected %f..%f, got %f" % [low, high, actual], message)


func assert_has(container: Variant, key: Variant, message: String = "") -> void:
	_check(key in container, "expected to contain %s" % [key], message)


func assert_not_null(value: Variant, message: String = "") -> void:
	_check(value != null, "expected non-null", message)


func fail(message: String) -> void:
	_check(false, "explicit failure", message)


func _check(passed: bool, detail: String, message: String) -> void:
	_assertions += 1
	if passed:
		return
	var where := ""
	var stack := get_stack()  # empty in release builds; tests run in debug
	if stack.size() > 2:
		var frame: Dictionary = stack[2]
		where = " (%s:%d)" % [String(frame.get("source", "?")).get_file(), frame.get("line", 0)]
	_failures.append("%s%s%s" % [detail, "" if message.is_empty() else " -- " + message, where])
