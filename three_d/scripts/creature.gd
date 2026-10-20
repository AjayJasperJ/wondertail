extends CharacterBody3D
const Art = preload("res://scripts/art.gd")
const ModelActor = preload("res://scripts/model_actor.gd")
var game
var home := Vector3.ZERO
var body = ModelActor.new()
var health := 60.0
var elite := false
var clock := 0.0
var windup := 0.0
var cooldown := 1.0
var stun := 0.0
var respawn_timer := 0.0
var spawn_location := Vector3.ZERO
var health_label: Label3D
var status_kind := ""
var ranged_timer := 2.5
var tactic := 0


func setup(owner_game, at: Vector3, guardian: bool = false) -> void:
	game = owner_game
	position = at
	home = at
	tactic = posmod(roundi(at.x + at.z), 3)
	spawn_location = at
	elite = guardian
	health = 150 if elite else 78
	collision_layer = 4
	collision_mask = 7
	var shape := CapsuleShape3D.new()
	shape.radius = 0.65 if elite else 0.45
	shape.height = 1.9 if elite else 1.35
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = shape.height / 2
	add_child(col)
	add_child(body)
	body.controller = game
	var biome: int = int(game.store.data.island) % 6
	var model_name := (
		"goleling"
		if elite
		else ("cactoro" if biome == 1 else ("yeti" if biome == 2 else "mushnub"))
	)
	var size := 0.62 if elite else (0.46 if model_name == "mushnub" else 0.52)
	body.setup(
		"res://assets/models/creatures/" + model_name + ".glb",
		Vector3.ONE * size,
		-0.65 if elite else 0.0
	)
	health_label = Art.label(self, "", Vector3(0, 2.1 if elite else 1.7, 0), Color("a9e4c5"))
	health_label.remove_from_group("landmark_labels")
	health_label.visibility_range_begin = 0
	health_label.font_size = 32
	health_label.visible = false
	status_kind = "burn" if biome == 4 else ("slow" if biome == 2 else "")
	# Hostiles read as threats at a glance: emissive warning eyes and a more deliberate pursuit cadence.
	for side in [-1, 1]:
		Art.sphere(
			self,
			Vector3(side * 0.16, 1.35 if not elite else 1.95, -0.42),
			0.055,
			Color("ff604d"),
			1.4
		)
	if elite:
		Art.label(self, "VAULT WARDEN", Vector3(0, 2.6, 0), Color("ffd293"))


func hit(amount: float, direction: Vector3) -> void:
	if health <= 0:
		return
	# Wardens resist frontal hits. Flanking their telegraphed strike is rewarded.
	if elite and windup <= 0 and (-body.global_basis.z).dot(-direction.normalized()) > 0.45:
		amount *= 0.35
	health -= amount
	stun = 0.35
	windup = 0
	velocity += direction * (5 if not elite else 2)
	game.sound.cue(180, 0.08, 0.12)
	if health <= 0:
		game.spawn_drop(self)
		visible = false
		collision_layer = 0
		if elite:
			game.guardian_defeated = true
			game.tell(
				(
					"The warden is down. The ridge is clear."
					if game.use_expeditions
					else "The warden rests. The ridge skyseed is yours."
				)
			)
		else:
			respawn_timer = 30


func _physics_process(dt: float) -> void:
	if game == null or not game.playing or game.in_cave:
		return
	if health <= 0:
		if has_meta("expedition_target"):
			return
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
	var alpha := clampf((18.0 - distance) / 3.5, 0, 1)
	health_label.visible = alpha > 0
	health_label.modulate.a = alpha
	var filled := ceili(health / (110.0 if elite else 60.0) * 8)
	health_label.text = "▰".repeat(clampi(filled, 0, 8)) + "▱".repeat(8 - clampi(filled, 0, 8))
	var direction := Vector3(offset.x, 0, offset.z).normalized()
	if not elite and tactic == 1 and distance > 4:
		direction = direction.rotated(Vector3.UP, 0.4 if home.x > 0 else -0.4)
	ranged_timer -= dt
	if elite and distance > 4 and distance < 17 and ranged_timer <= 0 and stun <= 0:
		ranged_timer = 3.5
		var source := global_position + Vector3.UP * 1.5
		var aim: Vector3 = game.player.position + Vector3.UP - source
		var query := PhysicsRayQueryParameters3D.create(source, source + aim, 1)
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			var bolt := preload("res://scripts/arrow.gd").new()
			game.world.add_child(bolt)
			bolt.hostile = true
			bolt.setup(game, source, aim.normalized())
			bolt.velocity = aim.normalized() * 12
			game.sound.cue(230, 0.12, 0.08)
	if distance < 18 and global_position.distance_to(home) < 23:
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-direction.x, -direction.z), dt * 7)
		if distance < 2.4 and cooldown <= 0:
			windup = 0.48
			cooldown = 1.35
		if windup > 0:
			body.play(["Headbutt", "Bite_Front", "Punch"], false)
			windup -= dt
			body.scale = Vector3.ONE * (1 + sin(windup * 20) * 0.08)
			if windup <= 0 and distance < 2.8:
				var previous: float = game.player.health
				game.player.hurt(31 if elite else 18)
				if game.player.health < previous:
					game.player.apply_status(status_kind)
		else:
			body.play(
				["HitReact", "HitRecieve"] if stun > 0 else ["Fast_Flying", "Walk"], stun <= 0
			)
			body.scale = Vector3.ONE
			var ahead := Vector2(position.x + direction.x * 1.2, position.z + direction.z * 1.2)
			var safe: bool = game.terrain.walkable(ahead, 4)
			var target := (
				direction * (4.8 if elite else 4.2)
				if safe and distance > 1.6 and stun <= 0
				else Vector3.ZERO
			)
			velocity.x = move_toward(velocity.x, target.x, dt * 12)
			velocity.z = move_toward(velocity.z, target.z, dt * 12)
	else:
		body.play(["Flying_Idle", "Idle"], true)
		var offset_home := home - position
		velocity.x = offset_home.x * 0.5
		velocity.z = offset_home.z * 0.5
	velocity.y -= 24 * dt
	move_and_slide()
	body.position.y = absf(sin(clock * 5)) * 0.12
	if position.y < -5:
		position = spawn_location
		velocity = Vector3.ZERO
