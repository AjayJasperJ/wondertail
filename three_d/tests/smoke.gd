extends SceneTree
const Store = preload("res://scripts/save_store.gd")
const Terrain = preload("res://scripts/terrain.gd")
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func run() -> void:
	# Data and generation invariants, independently of rendering.
	var store := Store.new()
	store.path = "user://smoke_%d.json" % Time.get_ticks_usec()
	check(store.persist(), "Fresh save must commit")
	check(store.collect("one", 3, 0), "First collection commits")
	check(not store.collect("one", 3, 0), "Collection must be idempotent")
	check(store.data.coins == 3 and store.memory().seeds == [0], "No duplicate rewards")
	var restored := Store.new()
	restored.path = store.path
	check(
		(
			restored.load_save()
			and restored.data.coins == 3
			and restored.memory().picked == ["one"]
			and restored.memory().seeds.size() == 1
		),
		"Round trip preserves progress"
	)
	check(store.collect("two", 2), "Second transaction backs up")
	var corrupt := FileAccess.open(store.path, FileAccess.WRITE)
	corrupt.store_string("broken checkpoint")
	corrupt.close()
	check(
		restored.load_save() and restored.data.coins == 3,
		"Corruption recovers previous committed backup"
	)
	var bad := Store.new()
	bad.path = "user://missing_parent_%d/save.json" % Time.get_ticks_usec()
	check(not bad.collect("one", 99), "Failed writes report failure")
	check(bad.data.coins == 0 and bad.memory().picked.is_empty(), "Failed writes roll back rewards")
	check(not Store.valid({"schema": 1}), "Reject malformed save")
	var variants: Dictionary = {}
	for index in range(24):
		var terrain := Terrain.new()
		terrain.configure(47021, index)
		var clone := Terrain.new()
		clone.configure(47021, index)
		check(
			terrain.height_at(Vector2(12, -7)) == clone.height_at(Vector2(12, -7)),
			"Terrain must be deterministic"
		)
		variants[snappedf(terrain.scale_factor, 0.01)] = true
		for key in terrain.anchors:
			check(
				terrain.walkable(terrain.anchors[key], 2),
				"Landmark %s on island %d must be reachable" % [key, index]
			)
		for route in terrain.paths:
			for i in range(route.size() - 1):
				for j in range(20):
					var p: Vector2 = route[i].lerp(route[i + 1], float(j) / 20)
					check(terrain.walkable(p, 1), "Required trail must stay within walking slope")
		terrain.free()
		clone.free()
	check(variants.size() > 8, "Islands must vary in size")
	# Run the actual game scene, not a mocked controller.
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.hud.page == "lobby" and not scene.playing, "Lobby appears before playing")
	var live_path: String = scene.store.path
	scene.store.path = store.path + ".game"
	scene.store.data = Store.fresh()
	scene.build_world()
	scene.start_game()
	for i in range(90):
		await physics_frame
	check(scene.player.is_on_floor(), "Player settles on physical terrain")
	check(scene.player.position.y > -1, "Spawn does not fall through terrain")
	var start: Vector3 = scene.player.position
	scene.player.stick = Vector2(1, 0)
	for i in range(25):
		await physics_frame
	scene.player.stick = Vector2.ZERO
	check(scene.player.position.x > start.x + 1, "Analog movement travels across terrain")
	# A real solid wall must stop grounded travel and a high-speed dash.
	scene.player.position = Vector3(0, 0.1, -140)
	scene.in_cave = true
	scene.player.velocity = Vector3.ZERO
	scene.player.stick = Vector2(0, 1)
	for i in range(90):
		await physics_frame
	check(scene.player.position.z < -135.7, "Cave wall blocks movement")
	check(
		scene.player.arm.get_hit_length() < scene.player.arm.spring_length,
		"Camera retracts against cave wall"
	)
	scene.player.body.rotation.y = PI
	scene.player.dash()
	for i in range(25):
		await physics_frame
	check(scene.player.position.z < -135.7, "Dash cannot tunnel through scenery")
	scene.leave_cave()
	for i in range(30):
		await physics_frame
	scene.player.request_jump()
	await physics_frame
	await physics_frame
	check(
		scene.player.velocity.y > 0 and scene.player.stamina < 100,
		"Jump uses real velocity and stamina"
	)
	scene.pause_game()
	check(
		scene.player.stick == Vector2.ZERO and scene.hud.stick_id == -1,
		"Menus release touch movement"
	)
	var position_before: Vector3 = scene.player.position
	await physics_frame
	await physics_frame
	check(scene.player.position == position_before, "Pause freezes player simulation")
	scene.resume_game()
	scene.enter_cave()
	check(scene.in_cave and scene.player.position.z < -130, "Cave is an explorable physical space")
	scene.sing_rune(scene.cave_sequence[0])
	scene.sing_rune(scene.cave_sequence[1])
	scene.sing_rune(scene.cave_sequence[2])
	check(scene.store.memory().cave, "Song puzzle persists its completion")
	scene.leave_cave()
	check(not scene.in_cave and scene.player.position.z > -100, "Cave exit returns to island")
	scene.store.memory().cloud = true
	scene.store.memory().seeds = [0, 1, 2]
	scene.player.position = scene.terrain.point("gate") + Vector3(0, 0.3, 2)
	scene.interact()
	check(
		scene.store.memory().restored and scene.store.data.unlocked == 1,
		"Three seeds unlock next island"
	)
	var reward: int = scene.store.data.coins
	# Re-entering uses the unlocked route and cannot award restoration twice.
	scene.interact()
	check(
		scene.store.data.island == 1 and scene.store.data.coins == reward,
		"Travel does not duplicate reward"
	)
	scene.store.path = live_path
	scene.queue_free()
	await process_frame
	for file in [
		store.path,
		store.path + ".bak",
		store.path + ".tmp",
		store.path + ".game",
		store.path + ".game.bak"
	]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	print("WONDERTAIL 3D: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
