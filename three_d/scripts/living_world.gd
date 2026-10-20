extends RefCounted
const Art = preload("res://scripts/art.gd")
const Actor = preload("res://scripts/model_actor.gd")
const TASKS := [
	"Supply the workshop • deliver 6 wood",
	"Survey crystals • deliver 4 crystals",
	"Prepare medicines • deliver 6 herbs",
	"Hunt the marked stalker at the ridge",
	"Rescue the stranded explorer at the ruins"
]
const UPGRADES := {"workshop": 2, "garden": 3, "telescope": 4, "forge": 5, "storage": 3}
var game
var dressing: Node3D


func setup(owner_game) -> void:
	game = owner_game
	state()
	build()


func state() -> Dictionary:
	if not game.store.data.has("living"):
		game.store.data.living = {"diamonds": 0, "camp": [], "completed": 0, "active": {}}
	return game.store.data.living


func accept(kind: int) -> bool:
	if kind < 0 or kind >= TASKS.size() or not state().active.is_empty():
		return false
	var ok: bool = game.store.transact(
		func():
			state().active = {"kind": kind, "island": int(game.store.data.island), "done": false}
	)
	if ok:
		build()
	return ok


func encounter_id() -> String:
	return "living_encounter_%d" % int(state().completed)


func build() -> void:
	if is_instance_valid(dressing):
		for object in game.objects.duplicate():
			if is_instance_valid(object.node) and dressing.is_ancestor_of(object.node):
				game.objects.erase(object)
		dressing.queue_free()
	dressing = Node3D.new()
	game.world.add_child(dressing)
	var camp: Vector3 = game.terrain.point("camp")
	var board := Node3D.new()
	dressing.add_child(board)
	board.position = camp + Vector3(1.8, 0, 2)
	Art.box(board, Vector3(0, 0.6, 0), Vector3(0.12, 1.2, 0.12), Color("8b7350"))
	Art.box(board, Vector3(0, 1.4, 0), Vector3(1.5, 0.8, 0.12), Color("35575e"))
	Art.label(board, "CAMP BOARD", Vector3(0, 2.2, 0), Color("73e3ce"))
	game.add_object("camp_board", board, "camp_board", board.position, 3.0)
	for enemy in game.enemies.duplicate():
		if (
			enemy.has_meta("living_id")
			and (state().active.is_empty() or int(state().active.kind) != 3 or state().active.done)
		):
			game.enemies.erase(enemy)
			enemy.queue_free()
	for i in range(state().camp.size()):
		var feature: String = state().camp[i]
		var at := camp + Vector3(6 + i * 1.6, 0, -4)
		at.y = game.terrain.height_at(Vector2(at.x, at.z))
		var prop := Node3D.new()
		dressing.add_child(prop)
		prop.position = at
		match feature:
			"garden":
				Art.box(prop, Vector3(0, 0.1, 0), Vector3(1.4, 0.2, 1.4), Color("624b38"))
				for j in range(4):
					Art.cone(
						prop,
						Vector3((j % 2) * 0.6 - 0.3, 0.45, (j / 2) * 0.6 - 0.3),
						0.18,
						0,
						0.7,
						Color("64ac74")
					)
			"telescope":
				Art.cone(prop, Vector3(0, 0.6, 0), 0.45, 0.1, 1.2, Color("8b7350"))
				var tube := Art.cone(prop, Vector3(0, 1.3, 0), 0.18, 0.25, 1.4, Color("bda771"))
				tube.rotation.z = 0.85
			_:
				Art.box(
					prop,
					Vector3(0, 0.45, 0),
					Vector3(1.4, 0.9, 1.0),
					Color("537b81") if feature != "forge" else Color("6e5961")
				)
		Art.label(prop, feature.to_upper(), Vector3(0, 2.0, 0), Color("73e3ce"))
	var active: Dictionary = state().active
	if active.is_empty() or int(active.island) != int(game.store.data.island) or active.done:
		return
	if int(active.kind) == 3:
		# One contract encounter, not a permanent increase in the ambient mob budget.
		for enemy in game.enemies:
			if enemy.get_meta("living_id", "") == encounter_id() and enemy.health > 0:
				return
		var hunter = game.Creature.new()
		game.world.add_child(hunter)
		hunter.setup(game, game.terrain.point("ridge") + Vector3(2, 0.3, 0))
		hunter.set_meta("living_id", encounter_id())
		game.enemies.append(hunter)
		Art.label(hunter, "CONTRACT STALKER", Vector3(0, 2.3, 0), Color("ffb887"))
	if int(active.kind) == 4:
		var npc := Actor.new()
		dressing.add_child(npc)
		npc.controller = game
		npc.position = game.terrain.point("ruins") + Vector3(4, 0, 3)
		npc.position.y = game.terrain.height_at(Vector2(npc.position.x, npc.position.z))
		npc.setup("res://assets/models/characters/farmer.glb", Vector3.ONE)
		Art.label(npc, "STRANDED EXPLORER • HELP", Vector3(0, 2.3, 0), Color("73e3ce"))
		game.add_object(encounter_id(), npc, "living_rescue", npc.position, 3.5)


func mark_encounter(id: String) -> bool:
	if state().active.is_empty() or state().active.done or id != encounter_id():
		return false
	return game.store.transact(func(): state().active.done = true)


func claim() -> bool:
	var active: Dictionary = state().active
	if active.is_empty():
		return false
	var kind := int(active.kind)
	if kind == 3 and not active.done:
		for enemy in game.enemies:
			if enemy.get_meta("living_id", "") == encounter_id() and enemy.health <= 0:
				mark_encounter(encounter_id())
	var resource: String = ["wood", "crystal", "herbs"][kind] if kind < 3 else ""
	var required: int = [6, 4, 6][kind] if kind < 3 else 0
	if kind < 3 and game.store.item_count(resource) < required:
		return false
	if kind >= 3 and not active.done:
		return false
	var ok: bool = game.store.transact(
		func():
			if kind < 3:
				game.store.data.bag[resource] -= required
			game.store.data.coins += 30 + kind * 5
			state().diamonds += 2
			state().completed += 1
			state().active = {}
			if "garden" in state().camp and game.store.can_add("herbs", 2):
				game.store.data.bag.herbs += 2
	)
	if ok:
		build()
	return ok


func rumour() -> String:
	if "telescope" not in state().camp:
		return "Build the telescope to survey hidden field caches."
	for object in game.objects:
		if object.kind == "field_cache" and is_instance_valid(object.node) and object.node.visible:
			var delta: Vector3 = object.base - game.terrain.point("camp")
			return (
				"A golden cache lies %dm %s of camp."
				% [
					int(delta.length()),
					(
						("east" if delta.x > 0 else "west")
						if absf(delta.x) > absf(delta.z)
						else ("south" if delta.z > 0 else "north")
					)
				]
			)
	return "All local field caches recovered. Another island may hold more."


func purchase(item: String) -> bool:
	var prices := {"arrows": 5, "tonic": 10, "bullets": 8}
	var quantities := {"arrows": 8, "tonic": 1, "bullets": 12}
	if not prices.has(item):
		return false
	var cost: int = prices[item] - (2 if "workshop" in state().camp else 0)
	if game.store.data.coins < cost or not game.store.can_add(item, quantities[item]):
		return false
	return game.store.transact(
		func():
			game.store.data.coins -= cost
			game.store.data.bag[item] += quantities[item]
	)


func upgrade(feature: String) -> bool:
	if (
		not UPGRADES.has(feature)
		or feature in state().camp
		or int(state().diamonds) < int(UPGRADES[feature])
	):
		return false
	var ok: bool = game.store.transact(
		func():
			state().diamonds -= UPGRADES[feature]
			state().camp.append(feature)
	)
	if ok:
		build()
	return ok
