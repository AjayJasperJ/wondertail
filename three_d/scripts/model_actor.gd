extends Node3D
## Animated art layer only: gameplay capsules and root movement stay authoritative.
var model: Node3D
var animator: AnimationPlayer
var current := ""
var skeleton: Skeleton3D
var controller
var playback_speed := 1.0


func setup(path: String, visual_scale: Vector3, offset: float = 0.0) -> void:
	model = load(path).instantiate()
	add_child(model)
	model.scale = visual_scale
	model.position.y = offset
	# Uploaded FBX-to-glTF models face +Z; our gameplay faces -Z.
	model.rotation.y = PI
	find_parts(model)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		# The hooded source includes a sword. Equipment is attached separately below.
		if node.name == "Sword":
			node.visible = false
	play(["Idle_Neutral", "Idle", "Flying_Idle"], true)
	if animator:
		animator.advance(0)


func find_parts(node: Node) -> void:
	if node is AnimationPlayer:
		animator = node
	if node is Skeleton3D:
		skeleton = node
	for child in node.get_children():
		find_parts(child)


func play(candidates: Array, looping: bool, speed: float = 1.0) -> void:
	if animator == null:
		return
	for candidate in candidates:
		for name in animator.get_animation_list():
			if String(name).get_slice("|", 1) == candidate or name == candidate:
				playback_speed = speed
				if current != name:
					var animation := animator.get_animation(name)
					animation.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
					animator.play(name, 0.12)
					current = name
				return


func weapon_socket() -> Node3D:
	if skeleton:
		for i in range(skeleton.get_bone_count()):
			var name := skeleton.get_bone_name(i)
			if (
				name.to_lower().replace("_", "").replace(".", "")
				in ["handr", "righthand", "wristr"]
			):
				var attachment := BoneAttachment3D.new()
				attachment.bone_name = name
				skeleton.add_child(attachment)
				# FBX armature uses centimetre transforms. Cancel inherited scale so
				# equipment dimensions stay in world metres while following the hand.
				var socket := Node3D.new()
				attachment.add_child(socket)
				socket.scale = Vector3.ONE / skeleton.global_basis.get_scale().abs()
				return socket
	var fallback := Node3D.new()
	add_child(fallback)
	fallback.position = Vector3(0.45, 1.0, -0.2)
	return fallback


func _process(_dt: float) -> void:
	if animator and controller:
		animator.speed_scale = playback_speed if controller.playing else 0.0
