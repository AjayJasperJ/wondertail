extends Node3D
const Art = preload("res://scripts/art.gd")
var game
var velocity := Vector3.ZERO
var remaining := 2.5
var damage := 38.0


func setup(owner_game, at: Vector3, direction: Vector3) -> void:
	game = owner_game
	position = at
	velocity = direction.normalized() * 30
	Art.box(self, Vector3.ZERO, Vector3(0.06, 0.06, 0.8), Color("e3c68d"))
	if direction.length_squared() > 0:
		look_at(position + direction, Vector3.UP)


func _physics_process(dt: float) -> void:
	if game == null or not game.playing:
		return
	remaining -= dt
	var next := global_position + velocity * dt
	var query := PhysicsRayQueryParameters3D.create(global_position, next, 5)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var target = result.collider
		if target.has_method("hit"):
			target.hit(damage, velocity.normalized())
		queue_free()
		return
	global_position = next
	if remaining <= 0:
		queue_free()
