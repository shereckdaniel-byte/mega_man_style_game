## Drives stage 1 from spawn towards the boss door, holding right and hopping.
extends SceneTree

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	for i in 60:
		await process_frame
	var stage = current_scene
	var player = stage.get_node("Player")
	var gs = root.get_node("/root/GameState")
	gs.lives = 99
	var out: String = OS.get_cmdline_user_args()[0]
	var goal: float = stage.boss_door_position().x
	print("rooms=%d  goal_x=%.0f  start_x=%.0f" % [stage.rooms().size(), goal, player.global_position.x])

	var seen := {}
	var transitions: Array = [0]
	stage.room_changed.connect(func(r): transitions[0] += 1; print("  -> entered %s" % r.name))

	var best: float = player.global_position.x
	var stalled := 0
	for i in 2400:                       # 90 s
		await process_frame
		if not stage.is_transitioning():
			Input.action_press(&"move_right")
			# Hop steadily: the raised blocks need jumps, and so do the gaps.
			if i % 34 == 0: Input.action_press(&"jump")
			elif i % 34 == 12: Input.action_release(&"jump")
			if i % 50 == 0: Input.action_press(&"shoot")
			elif i % 50 == 6: Input.action_release(&"shoot")
		else:
			Input.action_release(&"move_right"); Input.action_release(&"jump")
		if player.global_position.x > best + 8.0:
			best = player.global_position.x
			stalled = 0
		else:
			stalled += 1
		if player.global_position.x >= goal:
			print("REACHED boss door at frame %d" % i)
			break
	Input.action_release(&"move_right"); Input.action_release(&"jump"); Input.action_release(&"shoot")
	print("final x=%.0f (goal %.0f)  hp=%d  lives=%d  room=%s  transitions=%d  stalled=%d"
		% [player.global_position.x, goal, player.health.current, gs.lives,
			stage.room.name, transitions[0], stalled])
	root.get_texture().get_image().save_png(out + "/m4_playthrough.png")
	quit()
