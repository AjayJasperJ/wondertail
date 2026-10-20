extends SceneTree
const Terrain = preload("res://scripts/terrain.gd")
var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var forms := {}
	for index in range(36):
		var terrain := Terrain.new()
		terrain.configure(47021, index, 3)
		var clone := Terrain.new()
		clone.configure(47021, index, 3)
		forms[terrain.landform] = true
		check(
			terrain.anchors == clone.anchors and terrain.paths == clone.paths,
			"New routes regenerate deterministically"
		)
		for key in terrain.anchors:
			check(
				terrain.walkable(terrain.anchors[key], 4),
				"New landmark has safe ground: %d %s" % [index, key]
			)
		for route in terrain.paths:
			for i in range(route.size() - 1):
				for step in range(21):
					var p: Vector2 = route[i].lerp(route[i + 1], float(step) / 20)
					check(
						terrain.walkable(p, 2),
						"New route stays inside walkable terrain: %d" % index
					)
		terrain.free()
		clone.free()
	check(forms.size() == 6, "Six formations appear across deterministic seeds")
	check(
		(
			Terrain.difficulty_for(0) == 0
			and Terrain.difficulty_for(4) == 1
			and Terrain.difficulty_for(12) == 3
			and Terrain.difficulty_for(10000) == 3
		),
		"Difficulty bands have bounded scaling"
	)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.hud.show_lobby()
	await process_frame
	check(game.hud.level_points.size() == 8, "Lobby shows eight journey nodes")
	for control in game.hud.widgets.get_children():
		if control is Button:
			check(
				control.position.x >= 0 and control.position.x + control.size.x <= 1281,
				"Journey controls fit landscape width"
			)
	game.open_bag()
	await process_frame
	var icon_count := 0
	for control in game.hud.widgets.get_children():
		if control is Button:
			for child in control.get_children():
				if child.get_script() == game.hud.ItemIcon:
					icon_count += 1
	check(icon_count > 0, "Backpack uses item artwork")
	game.queue_free()
	await process_frame
	print("JOURNEY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
