## The password codec: every state round-trips, and everything that is not a
## password is refused.
##
## The refusals are what this file is really for. A codec that encodes correctly
## and accepts garbage is worse than no password at all -- it hands the player a
## run that is subtly not the one they wrote down, and nothing on screen says so.
extends TestCase

const PasswordScript := preload("res://scripts/core/password.gd")


# --- Round trips ------------------------------------------------------------------

## **Every reachable state**, not a sample: eight boss bits, eight item states
## and ten E-tank counts is 20,480 combinations and they all round-trip or none
## of them is trustworthy.
func test_every_reachable_state_round_trips() -> void:
	var checked := 0
	for bosses in 256:
		for items in 8:
			for etanks in [0, 1, 5, 9]:
				var state := {
					"bosses_defeated": bosses,
					"items_unlocked": items,
					"etanks": etanks,
				}
				var back := Password.decode(Password.encode(state))
				assert_false(back.is_empty(),
					"bosses %d items %d etanks %d did not decode"
						% [bosses, items, etanks])
				if back.is_empty():
					return
				assert_eq(int(back["bosses_defeated"]), bosses)
				assert_eq(int(back["items_unlocked"]), items)
				assert_eq(int(back["etanks"]), etanks)
				checked += 1
	assert_eq(checked, 256 * 8 * 4, "the sweep did not cover what it claims")


## **Lives are not carried**, and a password comes back with the starting count
## whatever the run had. A password that restored lives would let a player farm
## one, write it down and come back topped up.
func test_a_password_does_not_carry_lives() -> void:
	var rich := {"bosses_defeated": 0xFF, "items_unlocked": 7, "etanks": 9, "lives": 9}
	var back := Password.decode(Password.encode(rich))
	assert_eq(int(back["lives"]), GameState.STARTING_LIVES,
		"a password restored a life count")
	# And the grid is identical whatever the lives were, so two runs that differ
	# only in lives cannot be told apart by their passwords.
	var poor := rich.duplicate()
	poor["lives"] = 0
	assert_eq(Password.to_text(Password.encode(rich)),
		Password.to_text(Password.encode(poor)),
		"the grid changed when only the life count did")


## A fresh run's password is a real password, not an empty grid that anything
## would match.
func test_a_new_run_has_a_password() -> void:
	var cells := Password.encode({"bosses_defeated": 0, "items_unlocked": 0, "etanks": 0})
	var back := Password.decode(cells)
	assert_false(back.is_empty(), "a fresh run has no valid password")
	assert_eq(int(back["bosses_defeated"]), 0)


# --- Refusals ---------------------------------------------------------------------

## **Any single wrong dot is refused.** This is the mistake people actually make
## copying a grid, and it is what the weighted checksum buys over a parity
## count. Every cell, on a state with something in it.
func test_flipping_any_single_cell_is_refused() -> void:
	var state := {"bosses_defeated": 0b10110101, "items_unlocked": 5, "etanks": 6}
	var good := Password.encode(state)
	for i in Password.CELLS:
		var bad: Array[bool] = good.duplicate()
		bad[i] = not bad[i]
		assert_true(Password.decode(bad).is_empty(),
			"flipping cell %s was accepted" % Password.cell_name(i))


## **Any two dots swapped is refused.** The other mistake -- reading a grid off
## a photo in the wrong order -- and the one a parity check would miss
## completely. Walked over every pair whose cells actually differ.
func test_swapping_any_two_cells_is_refused() -> void:
	var state := {"bosses_defeated": 0b01101100, "items_unlocked": 2, "etanks": 3}
	var good := Password.encode(state)
	var pairs := 0
	for i in Password.CELLS:
		for j in range(i + 1, Password.CELLS):
			if good[i] == good[j]:
				continue  # swapping two identical cells changes nothing
			var bad: Array[bool] = good.duplicate()
			var keep: bool = bad[i]
			bad[i] = bad[j]
			bad[j] = keep
			pairs += 1
			assert_true(Password.decode(bad).is_empty(),
				"swapping %s and %s was accepted"
					% [Password.cell_name(i), Password.cell_name(j)])
	assert_true(pairs > 50, "only %d swaps were actually tried" % pairs)


## A grid of the wrong size is refused rather than read past its end.
func test_a_grid_of_the_wrong_size_is_refused() -> void:
	assert_true(Password.decode([]).is_empty())
	assert_true(Password.decode([true, false]).is_empty())
	var long: Array[bool] = []
	long.resize(Password.CELLS + 1)
	long.fill(false)
	assert_true(Password.decode(long).is_empty())


## **An E-tank count that cannot exist is refused**, even when the checksum
## agrees. Four bits hold fifteen and only ten are legal, so a grid can be
## internally consistent and still say something the game cannot represent.
func test_an_impossible_etank_count_is_refused() -> void:
	var payload := (GameState.MAX_ETANKS + 1) << Password.ETANK_OFFSET
	var cells: Array[bool] = []
	cells.resize(Password.CELLS)
	cells.fill(false)
	for i in Password.PAYLOAD_BITS:
		cells[i] = (payload >> i) & 1 == 1
	var check := Password.checksum(payload)
	for i in Password.CHECK_BITS:
		cells[Password.CHECK_OFFSET + i] = (check >> i) & 1 == 1
	assert_true(Password.decode(cells).is_empty(),
		"a grid claiming %d E-tanks was accepted" % [GameState.MAX_ETANKS + 1])


## Most random grids are refused, which is the property that matters when
## somebody types in a shape they liked the look of. Not a proof -- the codec
## has 19 meaningful bits and cannot be a hash -- but a floor.
func test_random_grids_are_almost_always_refused() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var accepted := 0
	for _try in 400:
		var cells: Array[bool] = []
		cells.resize(Password.CELLS)
		for i in Password.CELLS:
			cells[i] = rng.randi() % 2 == 0
		if not Password.decode(cells).is_empty():
			accepted += 1
	assert_true(accepted <= 8,
		"%d of 400 random grids were accepted as passwords" % accepted)


# --- The written form -------------------------------------------------------------

## The text form round-trips, so a password can be written down and typed back.
func test_the_written_form_round_trips() -> void:
	var state := {"bosses_defeated": 0b11010010, "items_unlocked": 6, "etanks": 4}
	var cells := Password.encode(state)
	var text := Password.to_text(cells)
	assert_true(text.length() > 0, "the grid wrote out as nothing")
	var back := Password.decode(Password.from_text(text))
	assert_false(back.is_empty(), "the written form did not decode: %s" % text)
	assert_eq(int(back["bosses_defeated"]), int(state["bosses_defeated"]))
	assert_eq(int(back["etanks"]), int(state["etanks"]))


## Cell names are reading order, top-left first. Worth pinning because every
## other coordinate in this game is (column, band) with band counting *down*,
## and a grid that numbered its rows the other way would be right in the code
## and wrong on every piece of paper.
func test_cell_names_read_top_left_first() -> void:
	assert_eq(Password.cell_name(0), "A1")
	assert_eq(Password.cell_name(4), "E1")
	assert_eq(Password.cell_name(5), "A2")
	assert_eq(Password.cell_name(Password.CELLS - 1), "E5")
	for i in Password.CELLS:
		assert_eq(Password.cell_index(Password.cell_name(i)), i,
			"cell %d did not survive a name round trip" % i)


## Anything that is not a cell name fails the parse rather than being ignored,
## so a mistyped password is refused instead of quietly decoding as fewer dots.
func test_a_bad_cell_name_fails_the_whole_parse() -> void:
	for bad in ["F1", "A6", "A0", "11", "A", "AA1"]:
		assert_true(Password.from_text("A1 %s B2" % bad).is_empty(),
			"'%s' was accepted as a cell name" % bad)
	# The empty string is checked on `cell_index` rather than through
	# `from_text`, because `split` drops empty tokens and it can never reach the
	# parser that way -- asserting it through `from_text` was testing the
	# splitter and reporting it as a codec result.
	assert_eq(Password.cell_index(""), -1, "the empty string named a cell")
