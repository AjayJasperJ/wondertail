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
	for enemy in game.enemies:
		enemy.set_physics_process(false)
	await capture("lobby.png")
	game.store.data.quality = 0
	game.apply_quality()
	game.start_game()
	for i in range(30):
		await physics_frame
	await capture("trail.png")
	game.player.position = game.lava_position + Vector3(0, 1, 7)
	for i in range(10):
		await physics_frame
	await capture("pool.png")
	game.player.position = game.terrain.point("ruins") + Vector3(0, 0.2, 7)
	await capture("ruins.png")
	for mode in range(4):
		game.player.cameras.mode = mode
		for i in range(50):
			await physics_frame
		await capture("camera-%d.png" % mode)
	game.player.cameras.mode = 0
	game.player.toggle_crouch()
	await capture("crouch.png")
	game.player.toggle_crouch()
	game.enter_cave()
	await capture("cave.png")
	game.return_lobby()
	game.hud.show_heroes()
	await capture("explorers.png")
	game.hud.show_settings()
	await capture("settings.png")
	game.player.position = game.terrain.point("camp") + Vector3.UP
	game.store.data.bag.wood = 12
	game.store.data.bag.crystal = 12
	game.store.data.bag.herbs = 4
	game.open_bag()
	game.hud.selected_item = "wood"
	game.hud.craft_grid = ["wood", "wood", "wood", "crystal", "crystal", "", "", "", ""]
	game.hud.show_bag()
	await capture("backpack.png")
	game.drop_inventory("wood", 3)
	game.hud.bag_tab = "nearby"
	game.hud.show_bag()
	await capture("nearby-loot.png")
	game.store.data.bag.gun = true
	game.store.data.bag.bullets = 12
	game.store.equip(2)
	game.player.refresh_weapon()
	game.resume_game()
	game.player.cameras.mode = 1
	for i in range(12):
		await physics_frame
	await capture("pistol-eye.png")
	game.store.equip(0)
	game.player.refresh_weapon()
	game.player.cameras.mode = 0
	game.player.set_physics_process(false)
	game.hud.visible = false
	game.player.arm.spring_length = 3.5
	game.player.pivot.rotation = Vector3(-0.1, PI, 0)
	await capture("sword-equipped.png")
	game.player.set_physics_process(true)
	game.hud.visible = true
	game.hud.show_game()
	game.hud.visible = false
	for hero in range(3):
		game.store.data.hero = hero
		game.rebuild_hero()
		game.player.arm.spring_length = 3.8
		game.player.pivot.rotation = Vector3(-0.15, PI, 0)
		await capture("character-%d.png" % hero)
	game.hud.visible = true
	game.start_game()
	for i in range(20):
		await physics_frame
	root.size = Vector2i(640, 360)
	await capture("phone-640x360.png")
	quit()
