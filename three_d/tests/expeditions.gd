extends SceneTree
const Store = preload("res://scripts/save_store.gd")
const Terrain = preload("res://scripts/terrain.gd")
var checks := 0
var failures := 0


func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _initialize():
	call_deferred("run")


func walk_to(game, destination: Vector3) -> bool:
	var previous: Vector3 = game.player.position
	for frame in range(650):
		var at := Vector2(game.player.position.x, game.player.position.z)
		var target := Vector2(destination.x, destination.z)
		if at.distance_to(target) < 1.5:
			game.player.stick = Vector2.ZERO
			return true
		game.player.stick = (target - at).normalized()
		if frame % 35 == 34:
			if game.player.position.distance_to(previous) < 0.8:
				game.player.request_jump()
			previous = game.player.position
		await physics_frame
	game.player.stick = Vector2.ZERO
	return false


func run():
	var shapes := {}
	for index in range(24):
		var terrain := Terrain.new()
		terrain.configure(47021, index, 2)
		var same := Terrain.new()
		same.configure(47021, index, 2)
		check(
			terrain.anchors == same.anchors and terrain.formation == same.formation,
			"New layouts deterministic"
		)
		shapes[terrain.formation] = true
		for key in terrain.anchors:
			check(terrain.inside(terrain.anchors[key], 6), "Landmarks stay inside varied coastline")
			check(terrain.walkable(terrain.anchors[key]), "Landmarks keep accessible grade")
		var guide := terrain.guided_route(terrain.point("camp"), terrain.point("gate"))
		check(guide.size() >= 2, "Connected guide reaches extraction")
		for i in range(guide.size() - 1):
			for j in range(1, 10):
				var at := guide[i].lerp(guide[i + 1], float(j) / 10)
				check(terrain.walkable(Vector2(at.x, at.z)), "Guide follows walkable trail")
		terrain.free()
		same.free()
	check(shapes.size() == 4, "Four terrain formations generated")
	var economy := Store.new()
	economy.path = "user://exp_upgrade_%d.json" % Time.get_ticks_usec()
	economy.data.coins = 200
	var initial_capacity := economy.capacity()
	check(
		(
			economy.upgrade_pack()
			and economy.capacity() == initial_capacity + 9
			and economy.data.coins == 150
		),
		"Contract currency buys persistent capacity"
	)
	var writable_upgrade := economy.path
	economy.path = "user://missing_upgrade_parent/save.json"
	check(
		(
			not economy.upgrade_pack()
			and economy.data.coins == 150
			and economy.capacity() == initial_capacity + 9
		),
		"Failed upgrade rolls back currency and capacity"
	)
	economy.path = writable_upgrade
	check(
		economy.upgrade_pack() and economy.upgrade_pack() and not economy.upgrade_pack(),
		"Pack upgrades capped at three"
	)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.store.path = "user://expedition_test_%d.json" % Time.get_ticks_usec()
	for index in range(3):
		game.store.data = Store.fresh()
		game.store.data.island = index
		game.store.data.unlocked = index
		game.build_world()
		for enemy in game.enemies:
			enemy.set_physics_process(false)
		game.player.set_physics_process(false)
		game.start_game()
		check(
			game.playing and game.hud.page == "game",
			"New island permits free exploration without a mandatory briefing"
		)
		game.resume_game()
		var contract = game.expedition
		check(contract.kind == index, "Distinct contract types in first three islands")
		check(not game.cloud_node.visible, "Cloud rescue removed from active expedition")
		game.hud.show_brief()
		game.resume_game()
		game._process(0.01)
		check(game.objective().contains(contract.TITLES[index]), "HUD names active contract")
		if index == 0:
			var caches := []
			for object in game.objects:
				if object.kind == "field_cache":
					caches.append(object)
			var coins_before_cache: int = game.store.data.coins
			game.interact_object(caches[0])
			check(
				(
					game.store.data.coins == coins_before_cache + 15
					and caches[0].id in game.store.memory().picked
				),
				"Optional cache awards a durable receipt"
			)
			game.interact_object(caches[0])
			check(
				game.store.data.coins == coins_before_cache + 15, "Opened cache cannot award again"
			)
			var valid_path: String = game.store.path
			game.store.path = "user://missing_cache_parent/save.json"
			game.interact_object(caches[1])
			check(
				caches[1].id not in game.store.memory().picked,
				"Failed cache save preserves unopened reward"
			)
			game.store.path = valid_path
			game.store.data.bag.wood = 1300
			game.store.data.bag.arrows = 0
			game.interact_object(caches[2])
			check(
				game.store.data.bag.arrows == 0 and caches[2].id in game.store.memory().picked,
				"Full bag does not block cache currency or overfill ammo"
			)
			game.store.data.bag.wood = 0
			game.store.data.bag.arrows = 24
			game.player.yaw = 0
			game.player.pivot.rotation.y = 0
			game.player.set_physics_process(true)
			for frame in range(20):
				await physics_frame
			var route: PackedVector3Array = game.terrain.guided_route(
				game.player.position, contract.stages[0].at
			)
			for waypoint in route:
				check(await walk_to(game, waypoint), "Physical guided route reaches first relay")
			check(
				game.player.position.distance_to(contract.stages[0].at) < 3.5,
				"Relay is physically reachable in interaction range"
			)
			game.player.set_physics_process(false)
			game.player.position = contract.stages[0].at
			contract.interact(0)
			game.playing = false
			var time_left: float = contract.remaining
			game._process(0.5)
			check(contract.remaining == time_left, "Calibration pauses in menus")
			game.playing = true
			game.player.health -= 1
			contract.tick(0.5)
			check(
				contract.channel == -1 and contract.completed().is_empty(),
				"Damage interrupts relay without reward"
			)
			contract.interact(0)
			contract.tick(2)
			check(0 in contract.completed(), "Stable calibration completes relay")
			var coins: int = game.store.data.coins
			check(
				not contract.commit(0) and game.store.data.coins == coins,
				"Relay receipt idempotent"
			)
			game.player.position = contract.stages[1].at
			contract.interact(1)
			contract.tick(2)
			game.player.position = contract.stages[2].at
			contract.interact(2)
			check(contract.channel == -1, "Guard blocks final relay")
			game.guardian_defeated = true
			contract.interact(2)
			contract.tick(2)
		elif index == 1:
			contract.interact(2)
			check(contract.completed().is_empty(), "Vault requires both survey fragments")
			contract.interact(0)
			contract.interact(1)
			contract.interact(2)
			check(2 not in contract.completed(), "Undecoded vault remains locked")
			game.enter_cave()
			check(contract.target().z < -140, "Vault guide points to underground terminals")
			for rune in game.cave_sequence:
				game.sing_rune(rune)
			contract.interact(2)
			check(2 in contract.completed(), "Decoded vault can be claimed")
			game.leave_cave()
		else:
			for enemy in game.enemies:
				if enemy.has_meta("expedition_target"):
					enemy.hit(999, Vector3.ZERO)
			contract.tick(2)
			check(contract.completed().size() == 3, "Marked sentinels complete outpost contract")
			var previous: int = game.store.data.coins
			contract.tick(2)
			check(game.store.data.coins == previous, "Dead sentinels cannot award twice")
		check(contract.completed().size() == 3, "All three contract steps reachable")
		var writable: String = game.store.path
		var coins_before: int = game.store.data.coins
		game.store.path = "user://missing_expedition_parent/save.json"
		contract.extract()
		check(
			not game.store.memory().restored and game.store.data.coins == coins_before,
			"Failed extraction rolls back rewards and unlock"
		)
		game.store.path = writable
		contract.extract()
		check(
			game.store.memory().restored and game.store.data.unlocked == index + 1,
			"Extraction unlocks next island"
		)
		var restored := Store.new()
		restored.path = writable

		check(
			restored.load_save() and restored.memory().expedition.done.size() == 3,
			"Contract progress survives reload"
		)
		check(Store.valid(restored.data), "Contract save validates")
		game.playing = false
		game.hud.show_brief()
		await process_frame
		var buttons := []
		for child in game.hud.widgets.get_children():
			if child is Button:
				check(
					Rect2(0, 0, 1280, 720).encloses(Rect2(child.position, child.size)),
					"Brief controls in viewport"
				)
				for other in buttons:
					check(
						not Rect2(child.position, child.size).intersects(
							Rect2(other.position, other.size)
						),
						"Brief controls do not overlap"
					)
				buttons.append(child)
	game.queue_free()
	await process_frame
	print("EXPEDITIONS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
