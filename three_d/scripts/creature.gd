extends CharacterBody3D
const Art = preload("res://scripts/art.gd")
var game
var home := Vector3.ZERO
var body := Node3D.new()
var health := 60.0
var elite := false
var clock := 0.0
var windup := 0.0
var cooldown := 1.0
var stun := 0.0
var respawn_timer := 0.0
var spawn_location := Vector3.ZERO


func setup(owner_game, at: Vector3, guardian: bool = false) -> void:
	game = owner_game
	position = at
	home = at
	spawn_location = at
	elite = guardian
	health = 110 if elite else 60
	collision_layer = 4
	collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = 0.65 if elite else 0.45
	shape.height = 1.8 if elite else 1.2
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = shape.height / 2
	add_child(col)
	add_child(body)
	Art.sphere(
		body,
		Vector3(0, 0.65, 0),
		0.7 if elite else 0.5,
		Color("8b7795") if elite else Color("cd826f")
	)
	for side in [-1, 1]:
		Art.cone(body, Vector3(side * 0.35, 1.25, 0), 0.22, 0, 0.6, Color("f3dfb6"))
		Art.sphere(body, Vector3(side * 0.22, 0.82, -0.43), 0.075, Color("ffd878"), 0.5)
	if elite:
		Art.label(self, "VAULT WARDEN", Vector3(0, 2.6, 0), Color("ffd293"))


func hit(amount: float, direction: Vector3) -> void:
	if health <= 0:
		return
	health -= amount
	stun = 0.35
	windup = 0
	velocity += direction * (5 if not elite else 2)
	game.sound.cue(180, 0.08, 0.12)
	if health <= 0:
		visible = false
		collision_layer = 0
		if elite:
			game.guardian_defeated = true
			game.tell("The warden rests. The ridge skyseed is yours.")
		else:
			respawn_timer = 30


func _physics_process(dt: float) -> void:
	if game == null or not game.playing or game.in_cave:
		return
	if health <= 0:
		if not elite:
			respawn_timer -= dt
			if respawn_timer <= 0 and game.player.position.distance_to(home) > 14:
				health = 60
				position = home
				visible = true
				collision_layer = 4
		return
	clock += dt
	cooldown = maxf(0, cooldown - dt)
	stun = maxf(0, stun - dt)
	var offset: Vector3 = game.player.global_position - global_position
	var distance := offset.length()
	var direction := Vector3(offset.x, 0, offset.z).normalized()
	if distance < 13 and global_position.distance_to(home) < 19:
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-direction.x, -direction.z), dt * 7)
		if distance < 2.4 and cooldown <= 0:
			windup = 0.65
			cooldown = 2.0
		if windup > 0:
			windup -= dt
			body.scale = Vector3.ONE * (1 + sin(windup * 20) * 0.08)
			if windup <= 0 and distance < 2.8:
				game.player.hurt(23 if elite else 13)
		else:
			body.scale = Vector3.ONE
			var ahead := Vector2(position.x + direction.x * 1.2, position.z + direction.z * 1.2)
			var safe: bool = game.terrain.walkable(ahead, 4)
			var target := (
				direction * (3.6 if elite else 3.0)
				if safe and distance > 1.6 and stun <= 0
				else Vector3.ZERO
			)
			velocity.x = move_toward(velocity.x, target.x, dt * 12)
			velocity.z = move_toward(velocity.z, target.z, dt * 12)
	else:
		var offset_home := home - position
		velocity.x = offset_home.x * 0.5
		velocity.z = offset_home.z * 0.5
	velocity.y -= 24 * dt
	move_and_slide()
	body.position.y = absf(sin(clock * 5)) * 0.12
	if position.y < -5:
		position = spawn_location
		velocity = Vector3.ZERO
