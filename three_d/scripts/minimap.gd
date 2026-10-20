extends Control
var game
var refresh := 0.0
const CENTER := Vector2(88, 88)
const RADIUS := 78.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(dt: float) -> void:
	if not game.playing:
		return
	refresh -= dt
	if refresh <= 0:
		refresh = 0.1
		queue_redraw()


func point(at: Vector3) -> Vector2:
	var delta: Vector3 = at - game.player.position
	return CENTER + Vector2(delta.x, delta.z).limit_length(39) * 2


func _draw() -> void:
	if not is_instance_valid(game.player):
		return
	draw_circle(CENTER, RADIUS + 4, Color(0.04, 0.12, 0.16, 0.85))
	draw_arc(CENTER, RADIUS + 4, 0, TAU, 64, Color("a4c8b3"), 1.5, true)
	# North-up radar, 39m range; rim markers indicate off-radar landmarks.
	for route in game.terrain.paths:
		for i in range(route.size() - 1):
			var a: Vector2 = route[i] - Vector2(game.player.position.x, game.player.position.z)
			var b: Vector2 = route[i + 1] - Vector2(game.player.position.x, game.player.position.z)
			if not game.in_cave and a.length() < 37 and b.length() < 37:
				draw_line(CENTER + a * 2, CENTER + b * 2, Color(0.6, 0.73, 0.59, 0.5), 2, true)
	for object in game.objects:
		if not is_instance_valid(object.node) or not object.node.visible:
			continue
		if (
			object.kind in ["coin", "resource", "seed", "drop"]
			and object.node.global_position.distance_to(game.player.position) < 37
		):
			draw_circle(point(object.node.global_position), 2, Color("ebd58a"))
	for enemy in game.enemies:
		if (
			is_instance_valid(enemy)
			and enemy.health > 0
			and enemy.position.distance_to(game.player.position) < 37
		):
			var at := point(enemy.position)
			draw_circle(at, 3, Color("ec9a86"))
			draw_line(
				at,
				at + Vector2(enemy.velocity.x, enemy.velocity.z).limit_length(3) * 2,
				Color("ec9a86"),
				1,
				true
			)
	if game.in_cave:
		for object in game.objects:
			if object.kind in ["rune", "exit_cave"]:
				draw_circle(point(object.base), 3, Color("9edcda"))
	else:
		draw_circle(point(game.nav_marker.position), 4, Color("f2df9c"))
	var forward := Vector2(-sin(game.player.yaw), -cos(game.player.yaw))
	draw_circle(CENTER, 4, Color("e6f5dd"))
	draw_line(CENTER, CENTER + forward * 13, Color("e6f5dd"), 2, true)
