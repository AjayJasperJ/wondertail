extends SceneTree


## Render the real scene under Xvfb/desktop; never used as substitute for playtesting.
func _initialize() -> void:
	call_deferred("run")


func capture(filename: String) -> void:
	for i in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/" + filename)


func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	var ignore := FileAccess.open("res://build/.gdignore", FileAccess.WRITE)
	ignore.close()
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.store.data = game.store.fresh()
	game.store.path = "user://visual_test_only.json"
	game.build_world()
	await capture("lobby.png")
	game.start_game()
	for i in range(30):
		await physics_frame
	await capture("trail.png")
	game.player.position = game.terrain.point("ruins") + Vector3(0, 0.2, 7)
	await capture("ruins.png")
	game.enter_cave()
	await capture("cave.png")
	game.pause_game()
	game.hud.show_heroes()
	await capture("explorers.png")
	game.hud.show_settings()
	await capture("settings.png")
	game.open_bag()
	await capture("backpack.png")
	game.hud.show_game()
	root.size = Vector2i(640, 360)
	await capture("phone-640x360.png")
	quit()
