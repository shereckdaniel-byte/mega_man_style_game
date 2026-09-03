## The collision layer bits from docs/ARCHITECTURE.md section 4, as names.
##
## They were being written as `1 << 2` at each use site, which is correct and
## unreadable: nothing at the call site says whether bit 2 is `ladder` or
## `player_body`, and the two are off by one because the table is 1-based and
## the shift is 0-based. That off-by-one has already cost one bug -- a ladder
## that watched the wrong layer and made Climb unreachable.
##
## Layer numbers here are the 1-based ones the project settings and the
## inspector show. `bit()` does the conversion once, in one place.
class_name Layers
extends RefCounted

const WORLD := 1
const ONE_WAY := 2
const LADDER := 3
const PLAYER_BODY := 4
const PLAYER_HURTBOX := 5
const PLAYER_ATTACK := 6
const ENEMY_BODY := 7
const ENEMY_HURTBOX := 8
const ENEMY_ATTACK := 9
const PICKUP := 10
const HAZARD := 11
const TRIGGER := 12
const PLATFORM := 13


## Mask value for a single layer, from its 1-based number.
static func bit(layer: int) -> int:
	return 1 << (layer - 1)


## Mask value for several layers at once.
static func mask(layers: Array) -> int:
	var out := 0
	for layer: int in layers:
		out |= bit(layer)
	return out
