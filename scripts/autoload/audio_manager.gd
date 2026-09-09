## Music and sound effects: the players, the buses, and the ducking.
##
## The API here was fixed at M0 and deliberately not changed since, so the call
## sites written across M1-M7 did not need revisiting when the sound arrived.
## What M8 added is a third player and three named buses.
##
## ### Three buses, and the middle one is the whole point
##
##   Master   everything, and where the options screen's master volume lands
##   Music    the looping theme, **compressed with a sidechain on Jingle**
##   Sfx      the pool below
##   Jingle   weapon-gets, checkpoints, game-overs
##
## A jingle in this kind of game plays *over* the stage theme and the theme gets
## out of its way. That is ducking, and the honest way to do it is a compressor
## on Music keyed to Jingle's level rather than a tween that lowers the volume
## and has to remember to put it back -- a tween interrupted by a scene change
## leaves the music quiet for the rest of the run, which is a bug nobody
## reports because it does not look like one.
##
## See `default_bus_layout.tres`. If the layout is missing every bus resolves to
## Master and everything still plays, which is the right failure.
extends Node

const SFX_VOICES := 12

const BUS_MUSIC := &"Music"
const BUS_SFX := &"Sfx"
const BUS_JINGLE := &"Jingle"

var _bgm: AudioStreamPlayer
var _jingle: AudioStreamPlayer
var _sfx: Array[AudioStreamPlayer] = []
var _next_voice := 0


func _ready() -> void:
	# Audio has to survive the pause menu: a game paused with the music stopped
	# reads as a crash.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_bgm = AudioStreamPlayer.new()
	_bgm.name = "BGM"
	_bgm.bus = _bus(BUS_MUSIC)
	add_child(_bgm)

	_jingle = AudioStreamPlayer.new()
	_jingle.name = "Jingle"
	_jingle.bus = _bus(BUS_JINGLE)
	add_child(_jingle)

	for i in SFX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.name = "SFX%d" % i
		voice.bus = _bus(BUS_SFX)
		add_child(voice)
		_sfx.append(voice)


## A bus name, or Master if the layout does not have it.
##
## **Not an assertion.** A missing bus is a project that has lost its layout
## resource, and the right response to that is a game that still makes noise
## rather than one that will not start.
func _bus(wanted: StringName) -> StringName:
	return wanted if AudioServer.get_bus_index(wanted) >= 0 else &"Master"


func play_bgm(stream: AudioStream, restart_if_same: bool = false) -> void:
	if stream == null:
		return
	if _bgm.stream == stream and _bgm.playing and not restart_if_same:
		return
	_bgm.stream = stream
	_bgm.play()


func stop_bgm() -> void:
	_bgm.stop()


func current_bgm() -> AudioStream:
	return _bgm.stream if _bgm != null and _bgm.playing else null


## A jingle, over the top. One at a time: two at once is noise, and the second
## one is always the one that matters.
func play_jingle(stream: AudioStream) -> void:
	if stream == null or _jingle == null:
		return
	_jingle.stream = stream
	_jingle.play()


func jingle_playing() -> bool:
	return _jingle != null and _jingle.playing


## Round-robins a fixed pool so a burst of explosions cannot allocate players
## mid-frame.
func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var voice := _sfx[_next_voice]
	_next_voice = (_next_voice + 1) % SFX_VOICES
	voice.stream = stream
	voice.volume_db = volume_db
	voice.play()


# --- Volume ---------------------------------------------------------------------

## Linear 0..1 per bus, which is what a slider is and what a settings file should
## hold. Decibels are the engine's unit and nobody else's.
func set_volume(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(_bus(bus))
	if index < 0:
		return
	var clamped := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(index, clamped <= 0.0001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(clamped, 0.0001)))


func get_volume(bus: StringName) -> float:
	var index := AudioServer.get_bus_index(_bus(bus))
	if index < 0:
		return 1.0
	if AudioServer.is_bus_mute(index):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(index)), 0.0, 1.0)
