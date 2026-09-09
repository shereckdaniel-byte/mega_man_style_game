## Builds every sound effect in the game.
##
##   godot --headless --script res://tools/make_sfx.gd
##
## **Each sound is a recipe, not a file.** A `.wav` in a repository is opaque --
## nobody can tell why it sounds the way it does or change it by a semitone
## without opening an editor nobody has. A recipe is four lines that say "a pulse
## falling from 880 to 220 over a tenth of a second", which is both the sound and
## its own documentation, and re-running this rebuilds the lot.
##
## The names are the game's own event names. `Sfx` maps them to files and every
## call site asks for a name, so a sound that is renamed here and nowhere else
## fails a test rather than going quiet in play.
##
## Development tool: not referenced by the game.
extends SceneTree

const OUT := "res://assets/audio/sfx"

## Duty cycles, named. The chip had exactly these and they are the difference
## between a sound that reads as this era and one that reads as a synthesiser.
const THIN := 0.125
const REED := 0.25
const HOLLOW := 0.5


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var made := 0
	for name in _recipes():
		var synth: Synth = (_recipes()[name] as Callable).call()
		synth.normalise().fade_out(0.01)
		var path := "%s/%s.wav" % [OUT, name]
		if synth.save(ProjectSettings.globalize_path(path)) != OK:
			printerr("could not write %s" % path)
			quit(1)
			return
		made += 1
		print("%-22s %5.2fs" % [name, synth.length_seconds()])
	print("%d sounds -> %s" % [made, OUT])
	quit(0)


## Every sound, by the event that makes it.
func _recipes() -> Dictionary:
	return {
		# --- The player -------------------------------------------------------
		# Rising, because up is up. Short: the jump is 40 frames and a sound
		# longer than the move it announces reads as lag.
		"jump": func() -> Synth: return Synth.new().pulse(
			0.0, 0.10, 260.0, 620.0, REED, 0.7, Synth.Env.new(0.002, 0.03, 0.5, 0.05)),
		"land": func() -> Synth: return Synth.new().noise(
			0.0, 0.06, 60, 0.5, Synth.Env.new(0.001, 0.03, 0.2, 0.03)),
		# The buster: the single most-heard sound in the game, so it is the
		# shortest and the quietest thing here that still cuts through.
		"shoot": func() -> Synth: return Synth.new().pulse(
			0.0, 0.07, 900.0, 380.0, THIN, 0.55, Synth.Env.new(0.001, 0.02, 0.3, 0.04)),
		# The charge is a *loop* -- see the note in Sfx on why it is one file.
		"charge_loop": func() -> Synth: return (Synth.new()
			.pulse(0.0, 0.08, 620.0, 700.0, THIN, 0.30, Synth.Env.new(0.01, 0.02, 0.9, 0.01))
			.pulse(0.08, 0.08, 700.0, 620.0, THIN, 0.30, Synth.Env.new(0.01, 0.02, 0.9, 0.01))),
		"charge_ready": func() -> Synth: return (Synth.new()
			.pulse(0.0, 0.06, 740.0, 740.0, REED, 0.5, Synth.Env.new(0.001, 0.02, 0.7, 0.03))
			.pulse(0.06, 0.10, 1100.0, 1100.0, REED, 0.5, Synth.Env.new(0.001, 0.03, 0.7, 0.05))),
		"charge_fire": func() -> Synth: return (Synth.new()
			.pulse(0.0, 0.22, 520.0, 140.0, HOLLOW, 0.8, Synth.Env.new(0.002, 0.06, 0.5, 0.10))
			.noise(0.0, 0.16, 24, 0.35, Synth.Env.new(0.001, 0.05, 0.3, 0.08))),
		# The sword is the one attack with no projectile, so its sound is the
		# whole feedback: a fast noise sweep with a pitched edge on it.
		"sword": func() -> Synth: return (Synth.new()
			.noise(0.0, 0.14, 12, 0.55, Synth.Env.new(0.004, 0.05, 0.3, 0.07))
			.pulse(0.0, 0.12, 1400.0, 500.0, THIN, 0.3, Synth.Env.new(0.002, 0.04, 0.2, 0.06))),
		"slide": func() -> Synth: return Synth.new().noise(
			0.0, 0.26, 40, 0.4, Synth.Env.new(0.02, 0.08, 0.35, 0.14)),
		# Falling, and the only player sound with a dissonant second voice: the
		# hurt has to be unmistakable at any volume.
		"hurt": func() -> Synth: return (Synth.new()
			.pulse(0.0, 0.20, 420.0, 150.0, HOLLOW, 0.7, Synth.Env.new(0.001, 0.06, 0.5, 0.10))
			.pulse(0.0, 0.20, 445.0, 160.0, HOLLOW, 0.4, Synth.Env.new(0.001, 0.06, 0.5, 0.10))),
		"death": func() -> Synth: return (Synth.new()
			.noise(0.0, 0.55, 18, 0.7, Synth.Env.new(0.002, 0.20, 0.4, 0.30))
			.pulse(0.0, 0.50, 300.0, 60.0, HOLLOW, 0.5, Synth.Env.new(0.002, 0.18, 0.3, 0.28))),
		"teleport_in": func() -> Synth: return Synth.new().pulse(
			0.0, 0.40, 120.0, 1600.0, THIN, 0.6, Synth.Env.new(0.01, 0.05, 0.8, 0.10)),
		"teleport_out": func() -> Synth: return Synth.new().pulse(
			0.0, 0.40, 1600.0, 120.0, THIN, 0.6, Synth.Env.new(0.01, 0.05, 0.8, 0.10)),

		# --- Weapons ----------------------------------------------------------
		# One per archetype. They are deliberately a family: same envelope, same
		# length, different timbre and direction, so a player learns "that is a
		# weapon" before learning which.
		"weapon_spread": func() -> Synth: return Synth.new().pulse(
			0.0, 0.09, 700.0, 1200.0, THIN, 0.55, Synth.Env.new(0.001, 0.03, 0.4, 0.05)),
		"weapon_homing": func() -> Synth: return Synth.new().pulse(
			0.0, 0.14, 500.0, 900.0, REED, 0.55, Synth.Env.new(0.004, 0.05, 0.6, 0.07)),
		"weapon_beam": func() -> Synth: return Synth.new().pulse(
			0.0, 0.16, 1500.0, 1500.0, THIN, 0.45, Synth.Env.new(0.002, 0.03, 0.8, 0.09)),
		"weapon_arc": func() -> Synth: return Synth.new().triangle(
			0.0, 0.16, 320.0, 180.0, 0.8, Synth.Env.new(0.002, 0.06, 0.5, 0.08)),
		"weapon_pierce": func() -> Synth: return Synth.new().pulse(
			0.0, 0.18, 260.0, 260.0, REED, 0.6, Synth.Env.new(0.002, 0.04, 0.9, 0.08)),
		"weapon_crawl": func() -> Synth: return Synth.new().triangle(
			0.0, 0.20, 200.0, 260.0, 0.8, Synth.Env.new(0.01, 0.06, 0.7, 0.10)),
		"weapon_stun": func() -> Synth: return Synth.new().pulse(
			0.0, 0.20, 1800.0, 600.0, THIN, 0.5, Synth.Env.new(0.001, 0.06, 0.4, 0.10)),
		"weapon_throw": func() -> Synth: return Synth.new().pulse(
			0.0, 0.18, 600.0, 1000.0, HOLLOW, 0.5, Synth.Env.new(0.002, 0.05, 0.6, 0.09)),

		# --- Enemies ----------------------------------------------------------
		"enemy_shoot": func() -> Synth: return Synth.new().pulse(
			0.0, 0.08, 500.0, 260.0, REED, 0.45, Synth.Env.new(0.001, 0.03, 0.3, 0.04)),
		"enemy_hit": func() -> Synth: return Synth.new().noise(
			0.0, 0.05, 20, 0.4, Synth.Env.new(0.001, 0.02, 0.3, 0.03)),
		"enemy_die": func() -> Synth: return (Synth.new()
			.noise(0.0, 0.26, 16, 0.6, Synth.Env.new(0.001, 0.10, 0.3, 0.14))
			.pulse(0.0, 0.20, 400.0, 120.0, HOLLOW, 0.35, Synth.Env.new(0.001, 0.08, 0.2, 0.11))),
		# A shot that hits a wall and stops. Quiet: it happens constantly.
		"shot_spent": func() -> Synth: return Synth.new().noise(
			0.0, 0.04, 14, 0.3, Synth.Env.new(0.001, 0.02, 0.2, 0.02)),

		# --- Pickups ----------------------------------------------------------
		# A rising third, which is the shape of every good-news sound ever made.
		"pickup_health": func() -> Synth: return (Synth.new()
			.pulse(0.00, 0.07, Synth.hz(76.0), Synth.hz(76.0), REED, 0.5, Synth.Env.new(0.001, 0.02, 0.8, 0.03))
			.pulse(0.07, 0.10, Synth.hz(83.0), Synth.hz(83.0), REED, 0.5, Synth.Env.new(0.001, 0.03, 0.8, 0.05))),
		"pickup_ammo": func() -> Synth: return (Synth.new()
			.pulse(0.00, 0.07, Synth.hz(74.0), Synth.hz(74.0), THIN, 0.5, Synth.Env.new(0.001, 0.02, 0.8, 0.03))
			.pulse(0.07, 0.10, Synth.hz(81.0), Synth.hz(81.0), THIN, 0.5, Synth.Env.new(0.001, 0.03, 0.8, 0.05))),
		"pickup_etank": func() -> Synth: return (Synth.new()
			.pulse(0.00, 0.07, Synth.hz(72.0), Synth.hz(72.0), REED, 0.5, Synth.Env.new(0.001, 0.02, 0.8, 0.03))
			.pulse(0.07, 0.07, Synth.hz(79.0), Synth.hz(79.0), REED, 0.5, Synth.Env.new(0.001, 0.02, 0.8, 0.03))
			.pulse(0.14, 0.14, Synth.hz(84.0), Synth.hz(84.0), REED, 0.5, Synth.Env.new(0.001, 0.04, 0.8, 0.07))),
		# The 1-UP is the longest pickup on purpose: it is the rarest thing in
		# the game and it should stop the player for a moment.
		"pickup_life": func() -> Synth: return (Synth.new()
			.pulse(0.00, 0.09, Synth.hz(72.0), Synth.hz(72.0), REED, 0.5, Synth.Env.new(0.001, 0.02, 0.9, 0.03))
			.pulse(0.09, 0.09, Synth.hz(76.0), Synth.hz(76.0), REED, 0.5, Synth.Env.new(0.001, 0.02, 0.9, 0.03))
			.pulse(0.18, 0.09, Synth.hz(79.0), Synth.hz(79.0), REED, 0.5, Synth.Env.new(0.001, 0.02, 0.9, 0.03))
			.pulse(0.27, 0.22, Synth.hz(84.0), Synth.hz(84.0), REED, 0.5, Synth.Env.new(0.001, 0.06, 0.9, 0.12))),
		"etank_use": func() -> Synth: return (Synth.new()
			.pulse(0.0, 0.30, 300.0, 900.0, THIN, 0.5, Synth.Env.new(0.01, 0.06, 0.8, 0.10))
			.triangle(0.0, 0.30, 150.0, 450.0, 0.5, Synth.Env.new(0.01, 0.06, 0.8, 0.10))),

		# --- The menus --------------------------------------------------------
		# Tiny, because they fire on every keypress. The refusal is the only one
		# with any weight to it, because it is the only one that means "no".
		"cursor": func() -> Synth: return Synth.new().pulse(
			0.0, 0.03, 1200.0, 1200.0, THIN, 0.35, Synth.Env.new(0.001, 0.01, 0.4, 0.015)),
		"confirm": func() -> Synth: return (Synth.new()
			.pulse(0.00, 0.05, Synth.hz(79.0), Synth.hz(79.0), REED, 0.45, Synth.Env.new(0.001, 0.02, 0.8, 0.02))
			.pulse(0.05, 0.09, Synth.hz(86.0), Synth.hz(86.0), REED, 0.45, Synth.Env.new(0.001, 0.03, 0.8, 0.04))),
		"refuse": func() -> Synth: return Synth.new().pulse(
			0.0, 0.16, 220.0, 150.0, HOLLOW, 0.5, Synth.Env.new(0.002, 0.05, 0.5, 0.08)),
		"pause": func() -> Synth: return Synth.new().pulse(
			0.0, 0.07, 900.0, 1300.0, THIN, 0.4, Synth.Env.new(0.001, 0.02, 0.6, 0.03)),
		"dot": func() -> Synth: return Synth.new().pulse(
			0.0, 0.04, 1600.0, 1600.0, THIN, 0.35, Synth.Env.new(0.001, 0.01, 0.5, 0.02)),

		# --- The stage --------------------------------------------------------
		"door": func() -> Synth: return (Synth.new()
			.noise(0.0, 0.22, 90, 0.4, Synth.Env.new(0.02, 0.08, 0.4, 0.10))
			.triangle(0.0, 0.22, 90.0, 60.0, 0.6, Synth.Env.new(0.01, 0.08, 0.4, 0.10))),
		"checkpoint": func() -> Synth: return (Synth.new()
			.pulse(0.00, 0.06, Synth.hz(81.0), Synth.hz(81.0), THIN, 0.4, Synth.Env.new(0.001, 0.02, 0.8, 0.03))
			.pulse(0.06, 0.12, Synth.hz(88.0), Synth.hz(88.0), THIN, 0.4, Synth.Env.new(0.001, 0.04, 0.8, 0.06))),
		"crumble": func() -> Synth: return Synth.new().noise(
			0.0, 0.18, 34, 0.5, Synth.Env.new(0.001, 0.07, 0.3, 0.09)),
		# The press is the loudest thing in the game that is not a boss. It has
		# to be: the room is asking for a decision and this is the deadline.
		"crusher": func() -> Synth: return (Synth.new()
			.noise(0.0, 0.34, 100, 0.8, Synth.Env.new(0.001, 0.12, 0.4, 0.20))
			.triangle(0.0, 0.30, 70.0, 40.0, 0.9, Synth.Env.new(0.001, 0.10, 0.4, 0.18))),
		"crusher_tell": func() -> Synth: return Synth.new().noise(
			0.0, 0.30, 200, 0.25, Synth.Env.new(0.06, 0.10, 0.5, 0.12)),
		"panel": func() -> Synth: return Synth.new().pulse(
			0.0, 0.06, 1000.0, 1400.0, THIN, 0.3, Synth.Env.new(0.001, 0.02, 0.5, 0.03)),
		"spike": func() -> Synth: return Synth.new().noise(
			0.0, 0.10, 8, 0.6, Synth.Env.new(0.001, 0.04, 0.3, 0.05)),
		"teleport_pad": func() -> Synth: return (Synth.new()
			.pulse(0.0, 0.30, 400.0, 1800.0, THIN, 0.5, Synth.Env.new(0.005, 0.05, 0.8, 0.10))
			.pulse(0.0, 0.30, 404.0, 1810.0, THIN, 0.3, Synth.Env.new(0.005, 0.05, 0.8, 0.10))),

		# --- Bosses -----------------------------------------------------------
		"boss_seal": func() -> Synth: return (Synth.new()
			.noise(0.0, 0.30, 120, 0.6, Synth.Env.new(0.001, 0.10, 0.5, 0.16))
			.triangle(0.0, 0.30, 110.0, 55.0, 0.8, Synth.Env.new(0.001, 0.10, 0.5, 0.16))),
		"boss_bar": func() -> Synth: return Synth.new().pulse(
			0.0, 0.025, 1400.0, 1400.0, THIN, 0.30, Synth.Env.new(0.001, 0.008, 0.5, 0.01)),
		"boss_hit": func() -> Synth: return Synth.new().noise(
			0.0, 0.07, 14, 0.5, Synth.Env.new(0.001, 0.03, 0.3, 0.03)),
		"boss_die": func() -> Synth: return (Synth.new()
			.noise(0.0, 0.70, 22, 0.8, Synth.Env.new(0.001, 0.25, 0.4, 0.40))
			.pulse(0.0, 0.60, 260.0, 40.0, HOLLOW, 0.5, Synth.Env.new(0.001, 0.20, 0.3, 0.35))),
		# The form change is the only sound in the game that goes down and then
		# up: the shell breaking, and what is inside it standing up.
		"boss_form": func() -> Synth: return (Synth.new()
			.noise(0.0, 0.30, 26, 0.7, Synth.Env.new(0.001, 0.12, 0.4, 0.16))
			.pulse(0.0, 0.28, 500.0, 90.0, HOLLOW, 0.5, Synth.Env.new(0.001, 0.10, 0.4, 0.15))
			.pulse(0.30, 0.36, 120.0, 900.0, REED, 0.6, Synth.Env.new(0.01, 0.06, 0.9, 0.14))),
		# Two notes, rising. Ward's whistle has existed as a signal with nothing
		# listening since M7c, which is exactly why it gets connected now.
		"whistle": func() -> Synth: return (Synth.new()
			.pulse(0.00, 0.26, Synth.hz(81.0), Synth.hz(81.0), THIN, 0.45, Synth.Env.new(0.03, 0.06, 0.85, 0.10))
			.pulse(0.30, 0.42, Synth.hz(88.0), Synth.hz(88.0), THIN, 0.45, Synth.Env.new(0.03, 0.08, 0.85, 0.18))),
	}
