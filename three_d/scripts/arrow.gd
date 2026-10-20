extends Node3D
const Art = preload("res://scripts/art.gd")
var game
var velocity := Vector3.ZERO
var remaining := 2.5
var damage := 38.0
var hostile := false


func setup(owner_game, at: Vector3, direction: Vector3, bullet: bool = false) -> void:
	game = owner_game
	position = at
	velocity = direction.normalized() * (65 if bullet else 30)
	damage = 27 if bullet else 38
	Art.box(
		self,
		Vector3.ZERO,
		Vector3(0.018, 0.018, 0.25 if bullet else 0.8),
		Color("ffe4ad") if bullet else Color("b99761")
	)
	if not bullet:
		var head := Art.cone(self, Vector3(0, 0, -0.44), 0.045, 0, 0.12, Color("c6d1ce"))
		head.rotation.x = -PI / 2
		Art.box(self, Vector3(0, 0, 0.3), Vector3(0.11, 0.012, 0.15), Color("e3dfcf"))
	if direction.length_squared() > 0:
		look_at(position + direction, Vector3.UP)


func _physics_process(dt: float) -> void:
	if game == null or not game.playing:
		return
	remaining -= dt
	var next := global_position + velocity * dt
	var query := PhysicsRayQueryParameters3D.create(global_position, next, 3 if hostile else 5)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var target = result.collider
		if hostile and target.has_method("hurt"):
			var previous: float = target.health
			target.hurt(10)
			if target.health < previous:
				target.apply_status("stun")
		if not hostile and target.has_method("hit"):
			target.hit(damage, velocity.normalized())
		queue_free()
		return
	global_position = next
	if remaining <= 0:
		queue_free()
