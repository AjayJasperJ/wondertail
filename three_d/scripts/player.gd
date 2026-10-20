extends CharacterBody3D
const CameraManager = preload("res://scripts/camera_manager.gd")
const Art = preload("res://scripts/art.gd")
const ModelActor = preload("res://scripts/model_actor.gd")
var game
var cameras := CameraManager.new()
var crouching := false
var slow_time := 0.0
var burn_time := 0.0
var burn_tick := 0.0
var stun_time := 0.0
var collider: CollisionShape3D
var standing_height := 1.9
var body
var sword: Node3D
var bow: Node3D
var gun: Node3D
var bow_string: MeshInstance3D
var bow_arrow: Node3D
var shot_kick := 0.0
var bow_draw := 0.0
var eye_equipment := Node3D.new()
var eye_items: Array[Node3D] = []
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
var pitch := -0.36
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
	collision_mask = 5
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
	collider = col
	standing_height = capsule.height
	body = ModelActor.new()
	body.controller = game
	add_child(body)
	var paths := ["adventurer", "hooded_adventurer", "farmer"]
	body.setup(
		"res://assets/models/characters/" + paths[hero] + ".glb",
		[Vector3(1, 1.05, 1), Vector3(0.94, 1.1, 0.94), Vector3(1.17, 1.02, 1.17)][hero]
	)
	var socket: Node3D = body.weapon_socket()
	sword = Art.model(socket, "equipment/sword", 1.0)
	# Preserve the sword model's authored wrist/grip pivot.
	sword.position = Vector3.ZERO
	gun = Art.model(socket, "equipment/pistol", 0.48, 2)
	gun.rotation.x = 0
	gun.position = Vector3(0, -0.06, -0.08)

	bow = Node3D.new()
	socket.add_child(bow)
	for segment in range(10):
		var a := float(segment) * PI / 10
		var b := float(segment + 1) * PI / 10
		var start := Vector3(sin(a) * 0.24, cos(a) * 0.6, 0)
		var finish := Vector3(sin(b) * 0.24, cos(b) * 0.6, 0)
		var limb := Art.cone(
			bow, (start + finish) * 0.5, 0.028, 0.025, start.distance_to(finish), Color("926a43")
		)
		limb.quaternion = Quaternion(Vector3.UP, (finish - start).normalized())
	bow_string = Art.box(bow, Vector3.ZERO, Vector3(0.008, 1.2, 0.008), Color("d2c9ad"))
	bow_string.visible = false
	for part in ["UpperString", "LowerString"]:
		var thread := Art.box(bow, Vector3.ZERO, Vector3(0.008, 1, 0.008), Color("d2c9ad"))
		thread.name = part
	Art.box(bow, Vector3(0.22, 0, 0), Vector3(0.06, 0.22, 0.06), Color("4b3828"))
	bow_arrow = Node3D.new()
	bow.add_child(bow_arrow)
	Art.box(bow_arrow, Vector3(0.12, 0, -0.2), Vector3(0.014, 0.014, 0.65), Color("b99360"))
	var tip := Art.cone(bow_arrow, Vector3(0.12, 0, -0.55), 0.035, 0, 0.1, Color("cbd4d0"))
	tip.rotation.x = -PI / 2

	# Imported character sockets face backward on the low-poly rigs; flip the held bow so its limbs, string and arrow point with the explorer.
	bow.rotation.y = PI
	bow.position = Vector3(0, 0.02, -0.16)
	refresh_weapon()
	add_child(pivot)
	pivot.position.y = 1.6
	pivot.add_child(arm)
	arm.spring_length = 9.5
	arm.margin = 0.25
	arm.collision_mask = 9
	var camera_shape := SphereShape3D.new()
	camera_shape.radius = 0.28
	arm.shape = camera_shape
	arm.add_excluded_object(get_rid())
	arm.add_child(camera)
	camera.add_child(eye_equipment)
	eye_equipment.visible = false
	eye_equipment.position = Vector3(0.28, -0.34, -0.65)
	for item in [sword, bow, gun]:
		var copy: Node3D = item.duplicate()
		eye_equipment.add_child(copy)
		eye_items.append(copy)
	camera.fov = 64
	camera.near = 0.06
	camera.far = 240
	camera.current = true
	pivot.rotation = Vector3(pitch, yaw, 0)
	add_child(cameras)
	cameras.setup(self)


func look(delta: Vector2) -> void:
	var sensitivity := float(game.store.data.sensitivity) * 0.004
	yaw -= delta.x * sensitivity
	pitch = clampf(
		pitch - delta.y * sensitivity,
		-1.10,
		0.85 if cameras.mode in [1, 2] or cameras.aiming else -0.12
	)
	pivot.rotation = Vector3(pitch, yaw, 0)


func request_jump() -> void:
	if cameras.reveal_remaining > 0:
		return
	jump_buffer = 0.16


func attack() -> void:
	if stun_time > 0 or cameras.reveal_remaining > 0:
		return
	if int(game.store.data.bag.weapon) == 1:
		if attack_cooldown <= 0 and stamina >= 6:
			if game.store.data.bag.arrows <= 0:
				game.tell("Quiver empty. Craft arrows from wood at camp.")
				return
			bow_draw = 0.22
			attack_cooldown = 0.65
			stamina -= 6
		return
	if int(game.store.data.bag.weapon) == 2:
		if attack_cooldown <= 0 and stamina >= 6 and game.fire_arrow():
			stamina -= 6
			attack_cooldown = 0.65 if int(game.store.data.bag.weapon) == 1 else 0.32
			shot_kick = 1.0
		return
	if attack_cooldown > 0 or stamina < 9:
		return
	stamina -= 9
	attack_cooldown = 0.42
	game.strike(global_position + Vector3.UP, -body.global_basis.z, [28, 23, 39][hero])


func refresh_weapon() -> void:
	bow_draw = 0
	var weapon := int(game.store.data.bag.weapon)
	sword.visible = weapon == 0
	bow.visible = weapon == 1
	gun.visible = weapon == 2


func dash() -> void:
	if cameras.reveal_remaining > 0 or stun_time > 0:
		return
	if dash_cooldown > 0 or stamina < 30:
		return
	stamina -= 30
	dash_cooldown = 2.5
	invulnerable = maxf(invulnerable, 0.45)
	# Velocity is resolved by move_and_slide, never a teleport through scenery.
	var forward: Vector3 = -body.global_basis.z
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


func toggle_crouch() -> void:
	if crouching:
		# Test the standing capsule before expanding into a ceiling.
		var shape := CapsuleShape3D.new()
		shape.radius = collider.shape.radius
		shape.height = standing_height
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(
			Basis.IDENTITY, global_position + Vector3.UP * standing_height * 0.5
		)
		query.collision_mask = 5
		query.exclude = [get_rid()]
		if not get_world_3d().direct_space_state.intersect_shape(query).is_empty():
			return
	crouching = not crouching
	collider.shape.height = standing_height * (0.65 if crouching else 1.0)
	collider.position.y = collider.shape.height * 0.5


func apply_status(kind: String) -> void:
	if kind == "burn":
		burn_time = 3.0
	elif kind == "slow":
		slow_time = 3.0
	elif kind == "stun":
		stun_time = 0.6


func reset_controls() -> void:
	stick = Vector2.ZERO
	sprinting = false
	jump_buffer = 0
	velocity = Vector3.ZERO


func _physics_process(dt: float) -> void:
	if game == null or not game.playing:
		return
	cameras.tick(dt)
	slow_time = maxf(0, slow_time - dt)
	stun_time = maxf(0, stun_time - dt)
	burn_time = maxf(0, burn_time - dt)
	burn_tick -= dt
	if burn_time > 0 and burn_tick <= 0:
		burn_tick = 1.4
		hurt(5)
	invulnerable = maxf(0, invulnerable - dt)
	attack_cooldown = maxf(0, attack_cooldown - dt)
	if bow_draw > 0:
		bow_draw = maxf(0, bow_draw - dt)
		if bow_draw == 0 and int(game.store.data.bag.weapon) == 1:
			if game.fire_arrow():
				shot_kick = 1.0
	var pull: float = (1.0 - bow_draw / 0.22) * 0.18 if bow_draw > 0 else 0.0
	pose_bow(bow, pull)
	if eye_items.size() > 1:
		pose_bow(eye_items[1], pull)
	shot_kick = maxf(0, shot_kick - dt * 7)
	eye_equipment.visible = cameras.mode == 1
	eye_equipment.position.y = -0.34 + sin(animation_time * 0.5) * 0.008
	for i in range(eye_items.size()):
		eye_items[i].visible = int(game.store.data.bag.weapon) == i
		if i == 2:
			eye_items[i].rotation.x = -shot_kick * 0.16
			eye_items[i].position.z = -0.08 + shot_kick * 0.06
	gun.rotation.x = -shot_kick * 0.16
	gun.position.z = -0.08 + shot_kick * 0.06
	bow_arrow.visible = int(game.store.data.bag.arrows) > 0 and attack_cooldown < 0.3
	bow_string.position.z = sin(animation_time * 40) * shot_kick * 0.025
	bow.rotation.z = sin(animation_time * 2) * 0.02
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
	if stun_time > 0 or cameras.reveal_remaining > 0:
		input = Vector2.ZERO
		jump_buffer = 0
	var direction := Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)
	var running := (
		(sprinting or Input.is_action_pressed("sprint"))
		and not crouching
		and stamina > 2
		and input.length() > 0.2
	)
	var target_speed := (
		speed
		* (0.45 if crouching else (1.55 if running else 1.0))
		* (0.55 if slow_time > 0 else 1.0)
	)
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
	if invulnerable > 1.0 and invulnerable < 1.21:
		body.play(["HitRecieve", "Idle_Neutral"], false)
	elif attack_cooldown > 0.20:
		body.play(["Sword_Slash"] if int(game.store.data.bag.weapon) == 0 else ["Gun_Shoot"], false)
	elif horizontal > 0.3 and is_on_floor():
		body.play(
			["Run"] if running else ["Walk"],
			true,
			clampf(horizontal / (7 if running else 3.5), 0.7, 1.6)
		)
	else:
		body.play(
			(
				["Idle_Gun_Pointing", "Idle_Gun", "Idle_Neutral"]
				if int(game.store.data.bag.weapon) == 2
				else (
					["Idle_Sword", "Idle_Neutral"]
					if int(game.store.data.bag.weapon) == 0
					else ["Idle_Neutral", "Idle"]
				)
			),
			true
		)
	body.scale.y = lerpf(body.scale.y, 0.7 if crouching else 1.0, 1 - exp(-dt * 12))
	walking_sound -= dt
	if horizontal > 0.8 and is_on_floor() and walking_sound <= 0:
		walking_sound = 0.3 if not running else 0.21
		game.sound.cue(95 + horizontal * 4, 0.035, 0.035)
	if global_position.y < -9:
		game.respawn()


func pose_bow(root: Node3D, pull: float) -> void:
	for side in [-1, 1]:
		var thread: MeshInstance3D = root.get_node("UpperString" if side > 0 else "LowerString")
		var start := Vector3(0, side * 0.6, 0)
		var end := Vector3(0, 0, pull)
		thread.position = (start + end) * 0.5
		thread.scale.y = start.distance_to(end)
		thread.quaternion = Quaternion(Vector3.UP, (start - end).normalized())
