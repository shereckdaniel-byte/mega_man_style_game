## The password grid: run progress packed into twenty-five dots.
##
## docs/ARCHITECTURE.md section 8 specified this at M0 and it has been waiting
## since -- a 5x5 grid, one bit per cell, with a checksum so a typo is refused
## rather than loaded. This is that, and nothing here touches a file: the save
## slot is the other persistence path and they share `GameState.to_dict`.
##
## ### Why a password at all, when there is a save file
##
## Fidelity, and one practical thing. MM3 had no save; the password *was* the
## save, and a player who wrote one down could carry their run to a friend's
## machine. Shipping both means the retro flow is intact for anyone who wants
## it and nobody is forced through it -- ARCHITECTURE's own note is "cosmetic
## retro but cheap".
##
## ### What is in it, and the one thing that is not
##
##   bits 0-7    bosses defeated, one per boss index
##   bits 8-10   items unlocked (coil, jet, marine)
##   bits 11-14  E-tanks, 0-9
##   bits 15-18  checksum
##   bits 19-24  reserved, and **must be zero**
##
## **Lives are not encoded**, and that is deliberate rather than an oversight.
## MM3's password does not carry them either: a password that restored a life
## count would let a player farm one, write it down, and come back topped up,
## which turns the whole system into a cheat menu. The save slot does carry
## lives, because a save is a pause in one run rather than a way back into it.
##
## ### The check is a CRC, and it had to be
##
## It catches the two mistakes people actually make copying a grid off paper:
## **any single wrong dot**, and **any two dots swapped**. Those are weight-one
## and weight-two error patterns, and a degree-5 primitive generator gives a
## code of minimum distance 3 over any word shorter than 31 bits -- ours is 20 --
## so both are caught for every payload, provably rather than probably.
##
## **The first version was a weighted sum and it did not do this.** Each set
## payload bit contributed its own position, which catches every single flip and
## every swap *within the payload* -- and the argument quietly assumed both
## swapped dots were payload. They need not be. Swapping a payload dot with a
## check dot changes the payload and the stored check together, and they can
## land on each other: `tests/test_password.gd` walks all 300 pairs and found
## D3 with B4 on the first run. The docstring claimed a guarantee the code did
## not have.
##
## A CRC has the property the sum was reaching for: the check bits are part of
## the codeword rather than a separate opinion about it, so an error anywhere in
## the twenty bits is an error in the same word. The five reserved cells are the
## second net -- they must come back blank, so most random grids are refused
## before the CRC runs at all.
class_name Password

## Grid shape. Five by five is ARCHITECTURE's number and there is room to spare:
## nineteen bits are used and twenty-five are available.
const COLUMNS := 5
const ROWS := 5
const CELLS := COLUMNS * ROWS

## Where each field sits. Written as offsets and widths rather than magic
## numbers so the layout can be read in one place and a later field cannot
## silently overlap an existing one.
const BOSS_OFFSET := 0
const BOSS_BITS := 8
const ITEM_OFFSET := 8
const ITEM_BITS := 3
const ETANK_OFFSET := 11
const ETANK_BITS := 4
const PAYLOAD_BITS := BOSS_BITS + ITEM_BITS + ETANK_BITS
const CHECK_OFFSET := PAYLOAD_BITS
const CHECK_BITS := 5
const RESERVED_OFFSET := CHECK_OFFSET + CHECK_BITS

## The CRC generator: x^5 + x^2 + 1.
##
## **Primitive**, which is the property doing the work -- a primitive degree-5
## polynomial gives minimum distance 3 for codewords under 31 bits, so every
## one- and two-bit error in our 20-bit word is detected. A non-primitive
## polynomial of the same degree would look identical here and quietly lose the
## two-bit guarantee.
const GENERATOR := 0b100101

## Column letters, so a grid can be spoken and written down. `A1` is the
## top-left cell and `E5` the bottom-right, which is how anybody reads a grid.
const COLUMN_LETTERS := "ABCDE"


## Packs progress into twenty-five booleans, row-major from the top-left.
##
## Takes the same dictionary `GameState.to_dict` produces, so the two
## persistence paths cannot drift apart: anything the save slot can hold, this
## is handed too, and it decides for itself what survives (see the note on
## lives).
static func encode(state: Dictionary) -> Array[bool]:
	var payload := 0
	payload |= (int(state.get("bosses_defeated", 0)) & _mask(BOSS_BITS)) << BOSS_OFFSET
	payload |= (int(state.get("items_unlocked", 0)) & _mask(ITEM_BITS)) << ITEM_OFFSET
	payload |= (clampi(int(state.get("etanks", 0)), 0, _mask(ETANK_BITS))) << ETANK_OFFSET

	var cells: Array[bool] = []
	cells.resize(CELLS)
	cells.fill(false)
	for i in PAYLOAD_BITS:
		cells[i] = (payload >> i) & 1 == 1
	var check := checksum(payload)
	for i in CHECK_BITS:
		cells[CHECK_OFFSET + i] = (check >> i) & 1 == 1
	# The reserved cells stay blank. Nothing writes them, and `decode` refuses a
	# grid where they are not.
	return cells


## Unpacks a grid, or returns an empty dictionary if it is not a real password.
##
## Empty rather than a partial state or a boolean-plus-out-parameter: a caller
## that forgets to check gets a dictionary with nothing in it and a run that
## visibly did not load, rather than a silently corrupted one.
static func decode(cells: Array) -> Dictionary:
	if cells.size() != CELLS:
		return {}
	for i in range(RESERVED_OFFSET, CELLS):
		if bool(cells[i]):
			return {}  # a cell that should never be marked is marked

	var payload := 0
	for i in PAYLOAD_BITS:
		if bool(cells[i]):
			payload |= 1 << i
	var given := 0
	for i in CHECK_BITS:
		if bool(cells[CHECK_OFFSET + i]):
			given |= 1 << i
	if given != checksum(payload):
		return {}

	var etanks := (payload >> ETANK_OFFSET) & _mask(ETANK_BITS)
	if etanks > GameState.MAX_ETANKS:
		# Reachable: four bits hold up to 15 and only 0-9 are legal, so a grid
		# can pass the checksum and still say something impossible.
		return {}
	return {
		"bosses_defeated": (payload >> BOSS_OFFSET) & _mask(BOSS_BITS),
		"items_unlocked": (payload >> ITEM_OFFSET) & _mask(ITEM_BITS),
		"etanks": etanks,
		# Not carried by a password -- see the class docstring. Handed back as
		# the starting count so a caller can pass this straight to
		# `GameState.from_dict` without special-casing it.
		"lives": GameState.STARTING_LIVES,
	}


## The five-bit CRC over a payload. See the class docstring for what it catches
## and why a weighted sum was not enough.
##
## Plain long division: shift the payload up by the check width and subtract the
## generator wherever a high bit is set. Written out rather than table-driven
## because it runs twice per password and a table would be sixteen lines of
## constants nobody could check by eye.
static func checksum(payload: int) -> int:
	var reg := (payload & _mask(PAYLOAD_BITS)) << CHECK_BITS
	for i in range(PAYLOAD_BITS + CHECK_BITS - 1, CHECK_BITS - 1, -1):
		if (reg >> i) & 1 == 1:
			reg ^= GENERATOR << (i - CHECK_BITS)
	return reg & _mask(CHECK_BITS)


# --- Reading and writing a grid as text -------------------------------------------

## A grid as the cells that are marked: `"A1 B3 C5"`, top-left is `A1`.
##
## For the console, for a player writing one down, and for the tests -- a
## twenty-five-element boolean array is not something anybody can check by eye,
## and a bug in the codec that only shows up as the wrong array is a bug nobody
## will spot in a diff.
static func to_text(cells: Array) -> String:
	var marks: Array[String] = []
	for i in mini(cells.size(), CELLS):
		if bool(cells[i]):
			marks.append(cell_name(i))
	return " ".join(marks)


## Parses that form back. Returns an empty array when anything in it is not a
## cell name, so a mistyped password fails here rather than decoding to garbage.
static func from_text(text: String) -> Array[bool]:
	var cells: Array[bool] = []
	cells.resize(CELLS)
	cells.fill(false)
	for token in text.to_upper().split(" ", false):
		var index := cell_index(token)
		if index < 0:
			return [] as Array[bool]
		cells[index] = true
	return cells


## `A1` for cell 0, `E5` for cell 24. Row-major, which is reading order.
static func cell_name(index: int) -> String:
	if index < 0 or index >= CELLS:
		return ""
	return "%s%d" % [COLUMN_LETTERS[index % COLUMNS], index / COLUMNS + 1]


## The inverse, or -1 for anything that is not a cell name.
static func cell_index(name: String) -> int:
	if name.length() != 2:
		return -1
	var column := COLUMN_LETTERS.find(name[0])
	if column < 0:
		return -1
	if not name[1].is_valid_int():
		return -1
	var row := name[1].to_int() - 1
	if row < 0 or row >= ROWS:
		return -1
	return row * COLUMNS + column


static func _mask(bits: int) -> int:
	return (1 << bits) - 1
