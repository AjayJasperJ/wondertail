extends RefCounted
## Three persistent expedition contracts, independent of the old cloud quest.
const Art = preload("res://scripts/art.gd")
const TITLES = ["THE SILENT NETWORK", "THE SEALED ARCHIVE", "THE OCCUPIED RIDGE"]
const BRIEFS = [
	"Restore three ancient relays. Hold position during calibration; taking damage breaks the link.",
	"Recover two survey fragments, decode the underground vault, then extract its archive.",
	"Defeat three marked sentinels to secure the island. Return to the extraction gate for payment."
]
var game
var kind := 0
var stages: Array[Dictionary] = []
var focus := -1
var channel := -1
var remaining := 0.0
var channel_health := 0.0
var retry := 0.0
var guide := Node3D.new()
var guide_nodes: Array[Node3D] = []
var route_clock := 0.0


func setup(owner_game) -> void:
	game = owner_game
	var index := int(game.store.data.island)
	kind = (index + int(index / 3)) % 3
	var memory: Dictionary = game.store.memory()
	if not memory.has("expedition"):
		# Retain prior completed seeds as equivalent contract progress. Original
		# cloud/seeds/receipts remain intact for older saves and compatibility.
		memory.expedition = {"kind": kind, "done": memory.seeds.duplicate()}
	kind = int(memory.expedition.kind)
	if kind == 2 or (kind == 0 and 2 in completed()):
		if kind == 0:
			game.guardian_defeated = true
		for enemy in game.enemies.duplicate():
			if enemy.elite:
				game.enemies.erase(enemy)
				enemy.queue_free()
	var keys := ["ruins", "cave", "ridge"]
	for i in range(3):
		var at: Vector3 = game.terrain.point(keys[i]) + Vector3(0, 0.4, 3.5)
		if i == 1:
			at += Vector3(5.8, 0, 2.0)
		var surface_point := Vector2(at.x, at.z)
		if not game.terrain.walkable(surface_point, 4):
			var best := INF
			for route in game.terrain.paths:
				for segment in range(route.size() - 1):
					var candidate := Geometry2D.get_closest_point_to_segment(
						surface_point, route[segment], route[segment + 1]
					)
					if candidate.distance_squared_to(surface_point) < best:
						best = candidate.distance_squared_to(surface_point)
						at.x = candidate.x
						at.z = candidate.y
		at.y = game.terrain.height_at(Vector2(at.x, at.z)) + 0.4
		if kind == 1 and i == 2:
			at = Vector3(0, 1.0, -161)
		var title: String = (
			["OBSERVATORY RELAY", "CAVERN RELAY", "RIDGE RELAY"]
			if kind == 0
			else (
				["SURVEY FRAGMENT A", "SURVEY FRAGMENT B", "ARCHIVE VAULT"]
				if kind == 1
				else ["RUINS SENTINEL", "CAVERN SENTINEL", "RIDGE SENTINEL"]
			)
		)[i]
		var n := Node3D.new()
		game.world.add_child(n)
		n.position = at
		var tint: Color = [Color("48e9ff"), Color("b58cff"), Color("ffc55a")][i]
		Art.cone(n, Vector3(0, 0.1, 0), 1.0, 0.85, 0.2, Color("283641"))
		if kind == 0:
			Art.box(n, Vector3(0, 1.0, 0), Vector3(0.4, 1.8, 0.4), Color("536575"))
			var ring := TorusMesh.new()
			ring.inner_radius = 0.42
			ring.outer_radius = 0.58
			var mesh := Art.mesh(n, ring, Vector3(0, 2.0, 0), tint, 1.3)
			mesh.rotation.x = PI / 2
			Art.sphere(n, Vector3(0, 2.0, 0), 0.18, tint, 2)
		else:
			Art.box(n, Vector3(0, 0.4, 0), Vector3(1.0, 0.65, 0.7), Color("293a4c"))
			for side in [-1, 1]:
				Art.box(
					n, Vector3(side * 0.36, 0.73, 0), Vector3(0.08, 0.08, 0.72), tint, false, 1.4
				)
		Art.loot_ray(n, tint, 5.0)
		Art.label(n, title, Vector3(0, 3.2, 0), tint)
		game.add_object("expedition_%d" % i, n, "expedition", at, 3.2, i)
		stages.append({"node": n, "at": at, "title": title})
		if kind == 2 and i not in completed():
			var enemy = game.Creature.new()
			game.world.add_child(enemy)
			enemy.setup(game, at + Vector3(2.0, 0.2, -1.0), i == 2)
			enemy.set_meta("expedition_target", i)
			game.enemies.append(enemy)
	for i in range(3):
		var id := "exp_optional_%d" % i
		if id in game.store.memory().picked:
			continue
		var route: Array = game.terrain.paths[i % 2]
		var p: Vector2 = route[1].lerp(route[2], 0.2 + i * 0.2) + Vector2(3.0 if i % 2 else -3.0, 0)
		if not game.terrain.walkable(p, 4):
			p = route[1].lerp(route[2], 0.2 + i * 0.2)
		var chest := Node3D.new()
		game.world.add_child(chest)
		chest.position = Vector3(p.x, game.terrain.height_at(p) + 0.1, p.y)
		Art.box(chest, Vector3(0, 0.4, 0), Vector3(1.0, 0.7, 0.7), Color("233345"))
		for side in [-1, 1]:
			Art.box(
				chest,
				Vector3(side * 0.3, 0.75, 0),
				Vector3(0.06, 0.06, 0.72),
				Color("ffc14c"),
				false,
				1.1
			)
		Art.sphere(chest, Vector3(0, 0.85, 0), 0.12, Color("ffc14c"), 1.3)
		Art.loot_ray(chest, Color("ffc14c"), 3.5)
		Art.label(chest, "FIELD CACHE", Vector3(0, 1.7, 0), Color("ffd47d"))
		game.add_object(id, chest, "field_cache", chest.position, 2.6)
	game.world.add_child(guide)
	for i in range(12):
		var n := Node3D.new()
		guide.add_child(n)
		var arrow := Art.cone(n, Vector3.ZERO, 0.09, 0, 0.35, Color("72eaff"), 1.2)
		arrow.rotation.x = -PI / 2
		guide_nodes.append(n)
	refresh()


func completed() -> Array:
	return game.store.memory().expedition.done


func next_index() -> int:
	if focus >= 0 and focus not in completed():
		return focus
	for i in range(3):
		if i not in completed():
			return i
	return -1


func target() -> Vector3:
	var next := next_index()
	if game.in_cave:
		if kind == 1 and next == 2:
			if not game.store.memory().cave:
				var rune_id: int = game.cave_sequence[mini(game.cave_steps.size(), 2)]
				for object in game.objects:
					if object.kind == "rune" and object.value == rune_id:
						return object.base
			return stages[2].at
		return Vector3(0, 1, -142)
	if next < 0:
		return game.terrain.point("gate") + Vector3(0, 0.5, 2)
	if kind == 1 and next == 2:
		return game.terrain.point("cave") + Vector3(0, 0.5, 4)
	if kind == 2:
		for enemy in game.enemies:
			if enemy.get_meta("expedition_target", -1) == next and enemy.health > 0:
				return enemy.position
	return stages[next].at


func instruction() -> String:
	if game.store.memory().restored:
		return "Contract complete. Enter the illuminated extraction gate."
	if channel >= 0:
		return "Hold position • calibrating %.1fs • damage breaks the link" % remaining
	var next := next_index()
	if next < 0:
		return "Return to extraction • claim %d Starlight" % reward()
	if game.in_cave:
		if kind != 1 or next != 2:
			return "Optional cavern. Return to the entrance for your contract."
		return (
			"Decode terminal %d / 3 • follow the cyan guide" % (game.cave_steps.size() + 1)
			if not game.store.memory().cave
			else "Open the gold archive chest at the end of the vault"
		)
	if kind == 0:
		if next == 2 and not game.guardian_defeated:
			return "Defeat the ridge warden, then calibrate its relay • SHOOT / STRIKE"
		return "Reach %s • tap CALIBRATE RELAY" % String(stages[next].title).to_lower()
	if kind == 1:
		return (
			"Enter the cavern • decode its terminals and open the vault"
			if next == 2
			else "Open %s • tap OPEN CACHE" % String(stages[next].title).to_lower()
		)
	return (
		"Defeat %s • dodge its windup, then SHOOT / STRIKE" % String(stages[next].title).to_lower()
	)


func objective() -> String:
	return (
		"%s • %d/3 / %s • %dm"
		% [
			TITLES[kind],
			completed().size(),
			instruction(),
			int(game.player.position.distance_to(target()))
		]
	)


func interact(index: int) -> void:
	if index in completed():
		game.tell("Already secured. " + instruction())
		return
	if kind == 2:
		game.tell("This outpost is guarded. Defeat its marked sentinel.")
		return
	if kind == 1 and index == 2:
		if 0 not in completed() or 1 not in completed():
			game.tell("Recover both surface fragments before opening the archive.")
			return
		if not game.store.memory().cave:
			game.tell("Decode the three marked terminals first. Follow the cyan guide.")
			return
	if kind == 0:
		if index == 2 and not game.guardian_defeated:
			game.tell("Clear the ridge warden before calibrating this relay.")
			return
		channel = index
		remaining = 1.8
		channel_health = game.player.health
		game.tell("Calibrating. Stay close and avoid taking damage.")
	else:
		commit(index)


func commit(index: int) -> bool:
	if index in completed():
		return false
	if game.store.transact(
		func():
			game.store.memory().expedition.done.append(index)
			game.store.data.coins += 8
	):
		game.sound.cue(1180, 0.24, 0.16)
		game.celebrate_pickup(stages[index].at, Color("ffc55a"))
		refresh()
		game.tell("%s SECURED • +8 Starlight. %s" % [stages[index].title, instruction()])
		return true
	game.tell(game.store.last_error)
	return false


func reward() -> int:
	return [40, 55, 65][kind]


func extract() -> void:
	if game.store.memory().restored:
		game.travel_next()
		return
	if completed().size() < 3:
		game.tell("Contract incomplete. " + instruction())
		return
	if game.store.transact(
		func():
			game.store.memory().restored = true
			game.store.data.unlocked = maxi(
				int(game.store.data.unlocked), int(game.store.data.island) + 1
			)
			game.store.data.coins += reward()
	):
		game.tell("EXPEDITION COMPLETE • +%d Starlight. The extraction gate is open." % reward())
		game.sound.cue(1046, 0.5, 0.16)
		game.celebrate()
		game.player.cameras.reveal(game.terrain.point("gate"))
	else:
		game.tell(game.store.last_error)


func refresh() -> void:
	for i in range(stages.size()):
		stages[i].node.visible = i not in completed() and ((kind == 1 and i == 2) == game.in_cave)


func tick(dt: float) -> void:
	refresh()
	if channel >= 0:
		if (
			game.player.position.distance_to(stages[channel].at) > 3.5
			or game.player.health < channel_health
			or game.in_cave
		):
			channel = -1
			game.tell("Calibration interrupted. Return to the relay and try again.")
		else:
			remaining -= dt
			if remaining <= 0:
				var index := channel
				channel = -1
				commit(index)
	retry -= dt
	if kind == 2 and retry <= 0:
		retry = 1.5
		for enemy in game.enemies:
			var index: int = enemy.get_meta("expedition_target", -1)
			if index >= 0 and enemy.health <= 0 and index not in completed():
				commit(index)
	var goal := target()
	game.nav_marker.position = goal + Vector3.UP * 4.0
	route_clock -= dt
	if route_clock <= 0:
		route_clock = 0.3
		var points: PackedVector3Array = (
			game.terrain.guided_route(game.player.position, goal)
			if not game.in_cave
			else PackedVector3Array([game.player.position, goal])
		)
		var distance := 0.0
		var placed := 0
		for segment in range(points.size() - 1):
			var start := points[segment]
			var finish := points[segment + 1]
			var length := start.distance_to(finish)
			if length < 0.05:
				continue
			while distance < length and placed < guide_nodes.size():
				var at := start.lerp(finish, distance / maxf(length, 0.01))
				if not game.in_cave:
					at.y = game.terrain.height_at(Vector2(at.x, at.z)) + 0.22
				else:
					at.y = 0.15
				guide_nodes[placed].position = at
				var facing := Vector3(finish.x - start.x, 0, finish.z - start.z)
				if facing.length_squared() > 0.001:
					guide_nodes[placed].look_at(at + facing, Vector3.UP)
				guide_nodes[placed].visible = distance > 0.5
				placed += 1
				distance += 2.0
			distance -= length
		for i in range(placed, guide_nodes.size()):
			guide_nodes[i].visible = false
