extends Node
## "Tactical" is the specification's wide overhead ("6th person") camera.
const MODES := ["TRAIL", "FIRST PERSON", "SHOULDER", "TACTICAL"]
var player
var mode := 0
var shoulder := 1.0
var aiming := false
var reveal_remaining := 0.0
var reveal_target := Vector3.ZERO


func setup(actor) -> void:
	player = actor


func cycle() -> void:
	if reveal_remaining > 0:
		reveal_remaining = 0
		return
	mode = (mode + 1) % MODES.size()
	aiming = false
	player.pitch = -0.48


func reveal(at: Vector3) -> void:
	reveal_target = at
	reveal_remaining = 3.0
	player.reset_controls()
	player.invulnerable = maxf(player.invulnerable, 3.2)


func tick(dt: float) -> void:
	var first := mode == 1
	var tactical := mode == 3
	var shoulder_view := mode == 2 or aiming
	var length := 0.0 if first else (23.0 if tactical else (3.4 if shoulder_view else 9.5))
	var target_pitch: float = -1.05 if tactical else player.pitch
	var offset := Vector3(
		shoulder * 0.65 if shoulder_view and not first else 0.0,
		1.05 if player.crouching else 1.65,
		0
	)
	player.pivot.position = player.pivot.position.lerp(offset, 1.0 - exp(-dt * 14))
	player.arm.spring_length = lerpf(player.arm.spring_length, length, 1.0 - exp(-dt * 12))
	player.pivot.rotation = Vector3(target_pitch, player.yaw, 0)
	player.camera.fov = lerpf(player.camera.fov, 48.0 if aiming else 68.0, 1.0 - exp(-dt * 12))
	# Hide the complete local model in eye view; collisions are unchanged.
	player.body.visible = (
		not first and (player.invulnerable <= 0 or int(player.invulnerable * 14) % 2 == 0)
	)
	if reveal_remaining > 0:
		reveal_remaining = maxf(0, reveal_remaining - dt)
		player.pivot.global_position = reveal_target + Vector3(0, 3, 0)
		player.pivot.rotation = Vector3(-0.45, player.yaw + (3.0 - reveal_remaining) * 0.28, 0)
		player.arm.spring_length = 14.0


func forward() -> Vector3:
	return -player.camera.global_basis.z
