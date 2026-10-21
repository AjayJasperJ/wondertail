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
	bad.data.bag = Store.starter_bag()
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
	var Actor = preload("res://scripts/model_actor.gd")
	for path in [
		"characters/adventurer",
		"characters/hooded_adventurer",
		"characters/farmer",
		"creatures/mushnub",
		"creatures/cactoro",
		"creatures/yeti",
		"creatures/goleling"
	]:
		var visual := Actor.new()
		root.add_child(visual)
		visual.setup("res://assets/models/" + path + ".glb", Vector3.ONE)
		check(
			visual.skeleton != null and visual.animator != null,
			"Imported rig and animations: " + path
		)
		check(not visual.current.is_empty(), "Imported model has a valid idle animation: " + path)
		visual.play(["Run", "Walk", "Fast_Flying"], true)
		check(
			visual.animator.get_animation(visual.current).loop_mode == Animation.LOOP_LINEAR,
			"Locomotion loops: " + path
		)
		visual.queue_free()
	# Run the actual game scene, not a mocked controller.
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.hud.page == "lobby" and not scene.playing, "Lobby appears before playing")
	var ground = scene.terrain.get_child(0)
	var normals: PackedVector3Array = ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	check(normals.size() > 20000, "Smooth terrain has denser geometry")
	check(
		absf(normals[0].length() - 1.0) < 0.001 and normals[0].y > 0,
		"Smooth terrain normals remain unit and upward"
	)
	check(
		scene.player.body.skeleton.find_bone("Wrist.R") >= 0,
		"Player equipment has a rigged hand socket"
	)
	var live_path: String = scene.store.path
	scene.store.path = store.path + ".game"
	scene.use_expeditions = false
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
	scene.resume_game()
	var touch_origin: Vector2 = scene.hud.position
	var stick_touch := InputEventScreenTouch.new()
	stick_touch.index = 11
	stick_touch.position = touch_origin + Vector2(150, 575)
	stick_touch.pressed = true
	scene.hud._input(stick_touch)
	var camera_touch := InputEventScreenTouch.new()
	camera_touch.index = 12
	camera_touch.position = touch_origin + Vector2(940, 360)
	camera_touch.pressed = true
	scene.hud._input(camera_touch)
	await process_frame
	check(
		scene.hud.stick_id == 11 and scene.hud.look_id == 12,
		"Two touch pointers keep separate joystick and camera owners"
	)
	var stick_drag := InputEventScreenDrag.new()
	stick_drag.index = 11
	stick_drag.position = touch_origin + Vector2(210, 575)
	scene.hud._input(stick_drag)
	check(scene.player.stick.x > 0.5, "Joystick drag produces movement input")
	var camera_drag := InputEventScreenDrag.new()
	camera_drag.index = 12
	camera_drag.position = touch_origin + Vector2(960, 360)
	scene.hud._input(camera_drag)
	await process_frame
	check(
		scene.hud.touch_points.has(11) and scene.hud.touch_points.has(12),
		"Multitouch tracks both positions"
	)
	var release_stick := InputEventScreenTouch.new()
	release_stick.index = 11
	release_stick.position = touch_origin + Vector2(150, 575)
	release_stick.pressed = false
	scene.hud._input(release_stick)
	var release_camera := InputEventScreenTouch.new()
	release_camera.index = 12
	release_camera.position = touch_origin + Vector2(960, 360)
	release_camera.pressed = false
	scene.hud._input(release_camera)
	await process_frame
	check(
		scene.hud.stick_id == -1 and scene.hud.look_id == -1,
		"Both touch pointers release independently"
	)
	scene.pause_game()
	var position_before: Vector3 = scene.player.position
	await physics_frame
	await physics_frame
	check(scene.player.position == position_before, "Pause freezes player simulation")
	await process_frame
	var pose_time: float = scene.player.body.animator.current_animation_position
	for i in range(4):
		await process_frame
	check(
		scene.player.body.animator.current_animation_position == pose_time,
		"Pause also freezes the imported character animation"
	)
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
	await polish_checks(scene)
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


func polish_checks(scene) -> void:
	check(
		Store.fresh().bag.bow and Store.fresh().bag.arrows == 24 and Store.fresh().bag.weapon == 1,
		"New game has a usable default bow"
	)
	var drops := Store.new()
	drops.path = "user://polish_drops_%d.json" % Time.get_ticks_usec()
	check(drops.claim_drop("warden", true), "Elite drop commits")
	var ammo: int = drops.data.bag.arrows
	check(
		not drops.claim_drop("warden", true) and drops.data.bag.arrows == ammo,
		"Mob loot cannot be claimed twice"
	)
	var recovered := Store.new()
	recovered.path = drops.path
	check(
		recovered.load_save() and not recovered.claim_drop("warden", true),
		"Mob receipt survives reload"
	)
	drops.path = "user://no_such_polish_dir/save.json"
	check(
		not drops.claim_drop("failed", false) and not "failed" in drops.memory().picked,
		"Failed loot writes roll back receipt"
	)
	scene.use_expeditions = false
	scene.store.data = Store.fresh()
	scene.build_world()
	scene.pause_game()
	var actor = scene.player
	for i in range(4):
		actor.cameras.mode = i
		actor.cameras.tick(1.0)
		check(actor.camera.fov > 0 and actor.arm.spring_length >= 0, "Valid camera mode %d" % i)
		check(actor.body.visible == (i != 1), "First person hides local mesh only")
	actor.cameras.mode = 2
	actor.cameras.shoulder = -1
	actor.cameras.tick(1)
	check(actor.pivot.position.x < 0, "Shoulder camera switches side")
	actor.cameras.mode = 0
	actor.position = scene.terrain.point("camp") + Vector3(0, 0.2, 3)
	actor.toggle_crouch()
	check(
		actor.crouching and actor.collider.shape.height < actor.standing_height,
		"Crouch shrinks physical capsule"
	)
	var ceiling_shape := BoxShape3D.new()
	ceiling_shape.size = Vector3(3, 0.2, 3)
	var ceiling = preload("res://scripts/art.gd").collider(
		scene.world, ceiling_shape, actor.position + Vector3(0, 1.65, 0)
	)
	await physics_frame
	await physics_frame
	actor.toggle_crouch()
	check(actor.crouching, "Crouched player cannot stand through a low ceiling")
	ceiling.queue_free()
	await physics_frame
	await physics_frame
	actor.toggle_crouch()
	check(not actor.crouching, "Standing resumes after ceiling clears")
	var locked := {"kind": "seed", "value": 0}
	check(not scene.can_collect(locked), "Locked quest seeds resist automatic collection")
	scene.store.memory().cloud = true
	check(scene.can_collect(locked), "Quest condition unlocks automatic collection")
	var loot := Node3D.new()
	scene.world.add_child(loot)
	loot.position = actor.position + Vector3.UP * 0.9
	scene.add_object("polish_auto", loot, "coin", loot.position)
	scene.pickup_clock = 0
	scene.auto_collect(1)
	check(
		"polish_auto" in scene.store.memory().picked and not loot.visible,
		"Automatic coin collection commits and hides the item"
	)
	var blocked := Node3D.new()
	scene.world.add_child(blocked)
	blocked.position = actor.position + Vector3(2.5, 0.9, 0)
	scene.add_object("polish_blocked", blocked, "coin", blocked.position)
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(0.2, 3, 3)
	var wall = preload("res://scripts/art.gd").collider(
		scene.world, wall_shape, actor.position + Vector3(1.2, 1.4, 0)
	)
	await physics_frame
	await physics_frame
	scene.pickup_clock = 0
	scene.auto_collect(1)
	check(
		not "polish_blocked" in scene.store.memory().picked and blocked.visible,
		"Pickup magnet cannot collect through walls"
	)
	wall.queue_free()
	await physics_frame
	await physics_frame
	var writable: String = scene.store.path
	scene.store.path = "user://missing_pickup_polish/save.json"
	scene.pickup_clock = 0
	scene.auto_collect(1)
	check(
		blocked.visible and not "polish_blocked" in scene.store.memory().picked,
		"Failed auto-collection preserves item and receipt"
	)
	scene.store.path = writable
	scene.clock += 2.0
	scene.pickup_clock = 0
	scene.auto_collect(1)
	check(
		not blocked.visible and "polish_blocked" in scene.store.memory().picked,
		"Pickup can retry after storage recovers"
	)
	actor.apply_status("slow")
	actor.cameras.reveal(scene.terrain.point("gate"))
	var timer: float = actor.cameras.reveal_remaining
	await physics_frame
	check(
		actor.cameras.reveal_remaining == timer and actor.slow_time == 3,
		"Menus freeze cinematics and status timers"
	)
	actor.cameras.cycle()
	check(actor.cameras.reveal_remaining == 0, "Camera control skips cinematic safely")
	scene.resume_game()
	actor.cameras.mode = 1
	actor.cameras.tick(1)
	check(not actor.body.visible, "Eye view hides explorer")
	scene.return_lobby()
	check(
		actor.body.visible and actor.cameras.mode == 0 and actor.cameras.reveal_remaining == 0,
		"Leaving eye view restores visible explorer and lobby camera"
	)
	scene.start_game()
	actor.cameras.mode = 0
	actor.cameras.cycle()
	check(absf(actor.pitch) < 0.1, "First-person view starts at the horizon")
	actor.cameras.mode = 2
	actor.cameras.shoulder = 1
	actor.yaw = PI / 2
	actor.cameras.tick(1)
	check(
		absf(actor.pivot.position.x) < 0.01 and actor.pivot.position.z < -0.6,
		"Shoulder offset follows camera yaw"
	)
	await process_frame
	var buttons: Array[Button] = []
	for child in scene.hud.widgets.get_children():
		if child is Button and child.visible:
			buttons.append(child)
	for i in range(buttons.size()):
		var rect := Rect2(buttons[i].position, buttons[i].size)
		check(
			Rect2(0, 0, 1280, 720).encloses(rect), "Touch control remains inside landscape canvas"
		)
		for j in range(i + 1, buttons.size()):
			check(
				not rect.intersects(Rect2(buttons[j].position, buttons[j].size)),
				(
					"Touch controls do not overlap: %s %s / %s %s"
					% [
						buttons[i].text,
						rect,
						buttons[j].text,
						Rect2(buttons[j].position, buttons[j].size)
					]
				)
			)
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(recovered.path + suffix))
