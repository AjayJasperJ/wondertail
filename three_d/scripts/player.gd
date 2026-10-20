extends CharacterBody3D
const Art = preload("res://scripts/art.gd")
var game
var body: Node3D
var pivot := Node3D.new()
var arm := SpringArm3D.new()
var camera := Camera3D.new()
var hero := 0
var health := 100.0
var stamina := 100.0
var speed := 7.0
var max_health := 100.0
var jump_speed := 9.0
var stick := Vector2.ZERO
var sprinting := false
var yaw := 0.0
var pitch := -0.48
var jumps := 0
var coyote := 0.0
var jump_buffer := 0.0
var invulnerable := 0.0
var attack_cooldown := 0.0
var dash_cooldown := 0.0
var animation_time := 0.0
var walking_sound := 0.0


func setup(owner_game, chosen: int) -> void:
	game = owner_game
	hero = chosen
	max_health = [100.0, 80.0, 135.0][hero]
	health = max_health
	speed = [7.0, 8.2, 6.2][hero]
	jump_speed = [9.0, 10.0, 8.7][hero]
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(46)
	wall_min_slide_angle = 0.1
	max_slides = 6
	safe_margin = 0.025
	var capsule := CapsuleShape3D.new()
	capsule.radius = [0.35, 0.29, 0.43][hero]
	capsule.height = [1.9, 2.05, 1.85][hero]
	var col := CollisionShape3D.new()
	col.shape = capsule
	col.position.y = capsule.height * 0.5
	add_child(col)
	body = Art.explorer(self, hero)
	refresh_weapon()
	add_child(pivot)
	pivot.position.y = 1.6
	pivot.add_child(arm)
	arm.spring_length = 9.5
	arm.margin = 0.25
	arm.collision_mask = 1
	var camera_shape := SphereShape3D.new()
	camera_shape.radius = 0.28
	arm.shape = camera_shape
	arm.add_excluded_object(get_rid())
	arm.add_child(camera)
	camera.fov = 64
	camera.near = 0.15
	camera.far = 240
	camera.current = true
	pivot.rotation = Vector3(pitch, yaw, 0)


func look(delta: Vector2) -> void:
	var sensitivity := float(game.store.data.sensitivity) * 0.004
	yaw -= delta.x * sensitivity
	pitch = clampf(pitch - delta.y * sensitivity, -1.10, -0.12)
	pivot.rotation = Vector3(pitch, yaw, 0)


func request_jump() -> void:
	jump_buffer = 0.16


func attack() -> void:
	if int(game.store.data.bag.weapon) == 1:
		if attack_cooldown <= 0 and stamina >= 6 and game.fire_arrow():
			stamina -= 6
			attack_cooldown = 0.65
		return
	if attack_cooldown > 0 or stamina < 9:
		return
	stamina -= 9
	attack_cooldown = 0.42
	game.strike(global_position + Vector3.UP, -body.global_basis.z, [28, 23, 39][hero])


func refresh_weapon() -> void:
	var ranged: bool = int(game.store.data.bag.weapon) == 1
	body.get_node("Arm1/Sword").visible = not ranged
	body.get_node("Arm1/Bow").visible = ranged


func dash() -> void:
	if dash_cooldown > 0 or stamina < 30:
		return
	stamina -= 30
	dash_cooldown = 2.5
	invulnerable = maxf(invulnerable, 0.45)
	# Velocity is resolved by move_and_slide, never a teleport through scenery.
	var forward := -body.global_basis.z
	velocity.x = forward.x * 22
	velocity.z = forward.z * 22
	game.sound.cue(320, 0.15, 0.15)


func hurt(amount: float) -> void:
	if invulnerable > 0:
		return
	health = maxf(0, health - amount)
	invulnerable = 1.2
	game.sound.cue(120, 0.18, 0.2)
	if health <= 0:
		game.respawn()


func reset_controls() -> void:
	stick = Vector2.ZERO
	sprinting = false
	jump_buffer = 0
	velocity = Vector3.ZERO


func _physics_process(dt: float) -> void:
	if game == null or not game.playing:
		return
	invulnerable = maxf(0, invulnerable - dt)
	attack_cooldown = maxf(0, attack_cooldown - dt)
	dash_cooldown = maxf(0, dash_cooldown - dt)
	jump_buffer = maxf(0, jump_buffer - dt)
	if is_on_floor():
		coyote = 0.12
		jumps = 0
	else:
		coyote = maxf(0, coyote - dt)
		velocity.y -= 24 * dt
	if jump_buffer > 0 and stamina >= 12 and (coyote > 0 or jumps < 2):
		if coyote <= 0 and jumps == 0:
			jumps = 1
		velocity.y = jump_speed * (0.88 if jumps > 0 else 1.0)
		stamina -= 12
		jumps += 1
		coyote = 0
		jump_buffer = 0
		game.sound.cue(410 + jumps * 110, 0.1, 0.1)
	var input := Input.get_vector("left", "right", "forward", "back") + stick
	input = input.limit_length()
	var direction := Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)
	var running := (
		(sprinting or Input.is_action_pressed("sprint")) and stamina > 2 and input.length() > 0.2
	)
	var target_speed := speed * (1.55 if running else 1.0)
	if dash_cooldown < 2.15:
		velocity.x = move_toward(velocity.x, direction.x * target_speed, dt * 34)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, dt * 34)
	stamina = clampf(stamina + (-22 if running else 16) * dt, 0, 100)
	move_and_slide()
	if direction.length_squared() > 0.02:
		body.rotation.y = lerp_angle(
			body.rotation.y, atan2(-direction.x, -direction.z), 1 - exp(-16 * dt)
		)
	var horizontal := Vector2(velocity.x, velocity.z).length()
	animation_time += dt * horizontal * 1.5
	for side in [-1, 1]:
		body.get_node("Leg" + str(side)).rotation.x = (
			sin(animation_time) * 0.65 * side if horizontal > 0.2 and is_on_floor() else 0.0
		)
		body.get_node("Arm" + str(side)).rotation.x = -sin(animation_time) * 0.45 * side
	if attack_cooldown > 0.20:
		body.get_node("Arm1").rotation.x = -1.4
		body.get_node("Arm1").rotation.z = sin(attack_cooldown * 19) * 1.1
	else:
		body.get_node("Arm1").rotation.z = 0
	body.visible = invulnerable <= 0 or int(invulnerable * 14) % 2 == 0
	walking_sound -= dt
	if horizontal > 0.8 and is_on_floor() and walking_sound <= 0:
		walking_sound = 0.3 if not running else 0.21
		game.sound.cue(95 + horizontal * 4, 0.035, 0.035)
	if global_position.y < -9:
		game.respawn()
