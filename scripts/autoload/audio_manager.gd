## Music and sound effects.
##
## Stub for M0: the bus layout, crossfades, and jingle ducking land in M8. The
## API is fixed now so call sites written in M1-M7 do not need revisiting.
extends Node

const SFX_VOICES := 12

var _bgm: AudioStreamPlayer
var _sfx: Array[AudioStreamPlayer] = []
var _next_voice := 0


func _ready() -> void:
	_bgm = AudioStreamPlayer.new()
	_bgm.name = "BGM"
	add_child(_bgm)
	for i in SFX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.name = "SFX%d" % i
		add_child(voice)
		_sfx.append(voice)


func play_bgm(stream: AudioStream, restart_if_same: bool = false) -> void:
	if stream == null:
		return
	if _bgm.stream == stream and _bgm.playing and not restart_if_same:
		return
	_bgm.stream = stream
	_bgm.play()


func stop_bgm() -> void:
	_bgm.stop()


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
