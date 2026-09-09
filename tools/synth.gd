## The NES-style synthesiser every sound in this game is made with.
##
## **Why the audio is generated rather than recorded.** Nobody on this project
## can record foley or play an instrument, and the alternative to synthesis is
## silence or a licence. What the hardware this game imitates actually had was
## two pulse channels, a triangle, and a noise generator -- so a synthesiser with
## exactly those four voices is not a compromise here, it is the instrument.
##
## Everything is a `RefCounted` rather than an `EditorScript` for the reason the
## importers are: `EditorScript` cannot run headless, and every asset in this
## project has to be rebuildable from a command line.
##
## ### The four voices
##
##   `pulse`     square wave with a duty cycle. Duty is the timbre: 0.5 is
##               hollow, 0.25 reedy, 0.125 thin and nasal. Melody and effects.
##   `triangle`  soft and flute-like, no duty. Bass.
##   `noise`     white noise through a hold, which is what makes it read as
##               "percussion" rather than "hiss". Drums and explosions.
##   `silence`   a rest, so a channel can be written as an unbroken list.
##
## Every voice takes an envelope, because a chip sound without a decay is a
## test tone. `Env` is attack/decay/sustain/release in seconds, and the four
## numbers are what separates a pickup chime from a menu blip when both are the
## same three notes.
class_name Synth
extends RefCounted

## 22050 rather than 44100: NES audio was far below either, nothing here has
## content above 11 kHz, and it halves every file in the repository.
const RATE := 22050
const MAX := 32767.0

## Semitone -> frequency, from A4 = 440. Written as a function rather than a
## table so a melody can be authored in note numbers and read as music.
static func hz(semitone: float) -> float:
	return 440.0 * pow(2.0, (semitone - 69.0) / 12.0)


## One note's shape over time. Seconds, except `sustain` which is a level.
class Env:
	extends RefCounted
	var attack := 0.005
	var decay := 0.05
	var sustain := 0.6
	var release := 0.05

	func _init(a := 0.005, d := 0.05, s := 0.6, r := 0.05) -> void:
		attack = a
		decay = d
		sustain = s
		release = r

	## Level at `t` seconds into a note of `length` seconds.
	func at(t: float, length: float) -> float:
		var body := maxf(length - release, 0.0)
		if t < attack and attack > 0.0:
			return t / attack
		if t < attack + decay and decay > 0.0:
			return lerpf(1.0, sustain, (t - attack) / decay)
		if t < body:
			return sustain
		if release <= 0.0:
			return 0.0
		return sustain * clampf(1.0 - (t - body) / release, 0.0, 1.0)


## A buffer of floats in -1..1, which every voice writes into and `to_stream`
## turns into 16-bit PCM.
var samples := PackedFloat32Array()


func length_seconds() -> float:
	return float(samples.size()) / float(RATE)


## Mixes a square wave in, from `at` seconds, sweeping from `from_hz` to `to_hz`.
##
## The sweep is what makes almost every game sound: a jump is a rising pulse, a
## hurt is a falling one, and the difference between them is the sign of one
## argument.
func pulse(at: float, length: float, from_hz: float, to_hz: float, duty: float,
		gain: float, env: Env) -> Synth:
	var phase := 0.0
	for i in _count(length):
		var t := float(i) / float(RATE)
		var f := lerpf(from_hz, to_hz, t / maxf(length, 0.0001))
		phase = fmod(phase + f / float(RATE), 1.0)
		var value := 1.0 if phase < duty else -1.0
		_add(at, i, value * gain * env.at(t, length))
	return self


## Triangle: four straight segments a cycle, which is close enough to the chip's
## stepped triangle at this rate and much cheaper to write.
func triangle(at: float, length: float, from_hz: float, to_hz: float,
		gain: float, env: Env) -> Synth:
	var phase := 0.0
	for i in _count(length):
		var t := float(i) / float(RATE)
		var f := lerpf(from_hz, to_hz, t / maxf(length, 0.0001))
		phase = fmod(phase + f / float(RATE), 1.0)
		var value := 4.0 * absf(phase - 0.5) - 1.0
		_add(at, i, value * gain * env.at(t, length))
	return self


## Noise, held for `hold` samples at a time.
##
## **The hold is the whole character.** Unheld white noise is hiss and reads as a
## fault; held for 30 samples it is a snare, and for 300 it is a distant
## collapse. The chip did this with a shift register at selectable rates and this
## is the same idea with a simpler mechanism.
func noise(at: float, length: float, hold: int, gain: float, env: Env,
		seed_value: int = 1) -> Synth:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var value := 0.0
	var held := 0
	for i in _count(length):
		if held <= 0:
			value = rng.randf_range(-1.0, 1.0)
			held = maxi(hold, 1)
		held -= 1
		var t := float(i) / float(RATE)
		_add(at, i, value * gain * env.at(t, length))
	return self


## A rest. Exists so a channel is an unbroken sequence of calls and a gap is
## visible in the source rather than implied by arithmetic.
func silence(at: float, length: float) -> Synth:
	_reserve(at, length)
	return self


## Fades the last `seconds` of the buffer to nothing, so a sound cannot end on a
## non-zero sample -- which is a click, and at this sample rate a loud one.
func fade_out(seconds: float) -> Synth:
	var n := _count(seconds)
	var start := samples.size() - n
	if start < 0:
		return self
	for i in n:
		samples[start + i] *= 1.0 - float(i) / float(n)
	return self


## Normalises to `peak` so every sound in the game arrives at a predictable
## level and the mix is set on the buses rather than per file.
func normalise(peak := 0.85) -> Synth:
	var loudest := 0.0
	for s in samples:
		loudest = maxf(loudest, absf(s))
	if loudest <= 0.0001:
		return self
	var factor := peak / loudest
	for i in samples.size():
		samples[i] *= factor
	return self


## 16-bit mono PCM, which is what `AudioStreamWAV` wants and what a `.wav` on
## disk is.
func to_stream(loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * MAX)
		bytes.encode_s16(i * 2, v)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream


func save(path: String, loop := false) -> Error:
	return to_stream(loop).save_to_wav(path)


# --- Buffer -------------------------------------------------------------------

func _count(seconds: float) -> int:
	return maxi(int(seconds * float(RATE)), 1)


func _reserve(at: float, length: float) -> void:
	var needed := int(at * float(RATE)) + _count(length)
	if samples.size() < needed:
		samples.resize(needed)


func _add(at: float, index: int, value: float) -> void:
	var i := int(at * float(RATE)) + index
	if i >= samples.size():
		samples.resize(i + 1)
	samples[i] += value
