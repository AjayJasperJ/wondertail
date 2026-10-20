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


func walk_to(scene, target: Vector2) -> bool:
	var previous: Vector3 = scene.player.position
	for frame in range(650):
		var at := Vector2(scene.player.position.x, scene.player.position.z)
		if at.distance_to(target) < 1.5:
			scene.player.stick = Vector2.ZERO
			return true
		scene.player.stick = (target - at).normalized()
		if frame % 35 == 34:
			if scene.player.position.distance_to(previous) < 0.8:
				scene.player.request_jump()
			previous = scene.player.position
		await physics_frame
	scene.player.stick = Vector2.ZERO
	return false


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
	var legacy := Store.fresh()
	legacy.erase("bag")
	legacy.coins = 77
	legacy.unlocked = 3
	var legacy_file := FileAccess.open(store.path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy))
	legacy_file.close()
	check(
		(
			restored.load_save()
			and restored.data.coins == 77
			and restored.data.unlocked == 3
			and restored.data.bag.arrows == 0
		),
		"Legacy 3D saves migrate without losing progress"
	)
	check(
		restored.gather("resource0", "wood") and not restored.gather("resource0", "wood"),
		"Resource receipts prevent duplicate gathering"
	)
	restored.data.bag.wood = 5
	restored.data.bag.crystal = 3
	restored.data.bag.herbs = 2
	check(
		restored.craft("bow") and restored.data.bag.bow and restored.data.bag.wood == 2,
		"Bow crafting debits materials once"
	)
	check(
		not restored.craft("bow") and restored.data.bag.wood == 2,
		"Owned gear cannot be crafted twice"
	)
	check(
		restored.craft("arrows") and restored.data.bag.arrows == 8,
		"Quiver recipe gives eight arrows"
	)
	check(
		restored.craft("tonic") and restored.data.bag.tonic == 1,
		"Tonic recipe uses herbs and crystals"
	)
	check(restored.equip(1), "Owned bow can be selected")
	check(
		(
			restored.persist()
			and store.load_save()
			and store.data.bag.bow
			and store.data.bag.weapon == 1
		),
		"Equipment round trip persists"
	)
	bad.data.bag.wood = 4
	bad.data.bag.crystal = 3
	check(
		not bad.craft("bow") and not bad.data.bag.bow and bad.data.bag.wood == 4,
		"Failed crafting writes refund materials and gear"
	)
	bad.data.hero = 1
	bad.data.bag.wood = 31
	check(
		not bad.gather("full", "wood") and not "full" in bad.memory().picked,
		"Full bag leaves world resource unclaimed"
	)
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
	for enemy in scene.enemies:
		enemy.set_physics_process(false)
	# Walk the generated paths with the actual capsule, including cave approach
	# and ridge bridge. Permit jumping onto constructed ledges, as in normal play.
	for route in scene.terrain.paths:
		scene.player.position = scene.terrain.point("camp") + Vector3(0, 0.3, 0)
		scene.player.velocity = Vector3.ZERO
		for waypoint in route.slice(1):
			var reached: bool = await walk_to(scene, waypoint)
			check(reached, "Physical landmark route reaches " + str(waypoint))
	scene.player.position = scene.terrain.point("camp") + Vector3(0, 0.3, 3)
	scene.player.velocity = Vector3.ZERO
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
	# Ranged damage uses swept collision. A wall must intercept the same shot.
	scene.player.position = Vector3(0, 0.1, -140)
	scene.player.body.rotation.y = 0
	scene.in_cave = true
	scene.store.data.bag.bow = true
	scene.store.data.bag.arrows = 3
	var target = preload("res://scripts/creature.gd").new()
	scene.world.add_child(target)
	target.setup(scene, Vector3(0, 0, -148))
	target.set_physics_process(false)
	scene.enemies.append(target)
	check(scene.fire_arrow() and scene.store.data.bag.arrows == 2, "Firing commits one arrow")
	for i in range(24):
		await physics_frame
	check(target.health < 60, "Swept arrow hits enemy")
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(5, 4, 0.3)
	preload("res://scripts/art.gd").collider(scene.world, wall_shape, Vector3(0, 2, -144))
	await physics_frame
	var previous_health: float = target.health
	scene.fire_arrow()
	for i in range(24):
		await physics_frame
	check(target.health == previous_health, "Solid wall intercepts arrows")
	var writable_path: String = scene.store.path
	scene.store.path = "user://missing_shot_directory/save.json"
	var ammo_before: int = scene.store.data.bag.arrows
	var arrows_before := get_nodes_in_group("arrows").size()
	check(
		(
			not scene.fire_arrow()
			and scene.store.data.bag.arrows == ammo_before
			and get_nodes_in_group("arrows").size() == arrows_before
		),
		"Failed shot write neither consumes ammo nor spawns a projectile"
	)
	scene.store.path = writable_path
	scene.open_bag()
	check(not scene.playing and scene.hud.page == "bag", "Backpack pauses the world")
	scene.player.health = scene.player.max_health
	scene.store.data.bag.tonic = 1
	scene.use_tonic()
	check(scene.store.data.bag.tonic == 1, "Full health does not consume tonic")
	scene.player.health -= 60
	scene.use_tonic()
	check(
		scene.store.data.bag.tonic == 0 and scene.player.health == scene.player.max_health - 5,
		"Tonic heals only after committed consumption"
	)
	scene.resume_game()
	scene.leave_cave()
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
