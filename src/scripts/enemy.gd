extends CharacterBody3D
# враги: gunner (одержимый с АКС) и crawler (ползун)

var main: Node3D
var kind := "gunner"
var hp := 55.0
var state := "idle"
var aggro_r := 24.0
var speed := 2.6
var burst_left := 0
var burst_t := 0.0
var aim_t := 1.0
var strafe_dir := 1.0
var strafe_t := 0.0
var lunge_t := 0.0
var lunge_dir := Vector3.ZERO
var attack_t := 0.0
var voice_t := 0.0
var dead := false
var gun_tip: Node3D
var parts := []

func _ready() -> void:
	add_to_group("enemies")
	voice_t = randf() * 6
	if kind == "crawler":
		hp = 26.0
		speed = 5.4
		aggro_r = 14.0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	if kind == "crawler":
		cap.radius = 0.35
		cap.height = 0.7
		cs.position.y = 0.35
	else:
		cap.radius = 0.34
		cap.height = 1.8
		cs.position.y = 0.9
	cs.shape = cap
	add_child(cs)
	_build_body()

func _box(size: Vector3, col: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	parts.append(mi)
	return mi

func _glow_box(size: Vector3, col: Color, pos: Vector3) -> void:
	var mi := _box(size, col, pos)
	var m: StandardMaterial3D = mi.material_override
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 1.4

func _build_body() -> void:
	if kind == "gunner":
		var uni := Color(0.24, 0.27, 0.24)
		_box(Vector3(0.55, 0.9, 0.32), uni, Vector3(0, 1.25, 0))
		_box(Vector3(0.5, 0.8, 0.3), Color(0.18, 0.2, 0.18), Vector3(0, 0.4, 0))
		_box(Vector3(0.28, 0.3, 0.28), Color(0.54, 0.5, 0.43), Vector3(0, 1.9, 0))
		_glow_box(Vector3(0.05, 0.03, 0.02), Color(0.91, 0.89, 0.83), Vector3(-0.07, 1.93, -0.15))
		_glow_box(Vector3(0.05, 0.03, 0.02), Color(0.91, 0.89, 0.83), Vector3(0.07, 1.93, -0.15))
		var gun := _box(Vector3(0.08, 0.08, 0.7), Color(0.15, 0.15, 0.17), Vector3(0.2, 1.3, -0.3))
		gun_tip = Node3D.new()
		gun_tip.position = Vector3(0, 0, -0.4)
		gun.add_child(gun_tip)
		_box(Vector3(0.13, 0.6, 0.13), uni, Vector3(-0.34, 1.25, -0.1))
	else:
		var bodycol := Color(0.16, 0.15, 0.13)
		_box(Vector3(0.7, 0.3, 0.9), bodycol, Vector3(0, 0.25, 0))
		_glow_box(Vector3(0.06, 0.04, 0.02), Color(0.78, 0.42, 0.29), Vector3(-0.15, 0.32, -0.46))
		_glow_box(Vector3(0.06, 0.04, 0.02), Color(0.78, 0.42, 0.29), Vector3(0.15, 0.32, -0.46))
		for i in range(3):
			for s in [-1, 1]:
				_box(Vector3(0.06, 0.3, 0.06), bodycol, Vector3(s * 0.42, 0.15, -0.3 + i * 0.3))

func take_damage(n: float) -> void:
	hp -= n
	if state == "idle":
		state = "combat"
	if hp <= 0 and not dead:
		dead = true
		main.snd("creature", global_position)
		set_collision_layer_value(1, false)
		var tw := create_tween()
		if kind == "gunner":
			tw.tween_property(self, "rotation:x", PI / 2, 0.5)
		else:
			tw.tween_property(self, "scale:y", 0.1, 0.4)
		tw.tween_interval(3.0)
		tw.tween_callback(queue_free)

func _see_player() -> bool:
	var pl = main.player
	if pl == null:
		return false
	var from := global_position + Vector3(0, 1.6 if kind == "gunner" else 0.4, 0)
	var to: Vector3 = pl.global_position + Vector3(0, 0.6, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, [get_rid(), pl.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty()

func _physics_process(delta: float) -> void:
	if dead or main.player == null or not main.started:
		return
	var pl = main.player
	if pl.dead:
		return
	var to_p: Vector3 = pl.global_position - global_position
	to_p.y = 0
	var dist := to_p.length()

	voice_t -= delta
	if voice_t < 0 and dist < 26:
		main.snd("creature", global_position, -6)
		voice_t = 6 + randf() * 8

	if state == "idle":
		if dist < aggro_r and _see_player():
			state = "combat"
		velocity = Vector3(0, velocity.y - 22 * delta, 0)
		move_and_slide()
		return

	look_at(Vector3(pl.global_position.x, global_position.y, pl.global_position.z), Vector3.UP)
	var see := _see_player()
	var move := Vector3.ZERO

	if kind == "gunner":
		strafe_t -= delta
		if strafe_t <= 0:
			strafe_dir *= -1
			strafe_t = 1 + randf() * 1.5
		var fwd := to_p.normalized()
		var side := Vector3(-fwd.z, 0, fwd.x) * strafe_dir
		if not see or dist > 15:
			move += fwd
		elif dist < 6:
			move -= fwd
		if see and dist < 20:
			move += side * 0.7
		if see and dist < 24:
			if burst_left > 0:
				burst_t -= delta
				if burst_t <= 0:
					burst_left -= 1
					burst_t = 0.13
					_shoot(pl)
			else:
				aim_t -= delta
				if aim_t <= 0:
					burst_left = 3
					burst_t = 0.0
					aim_t = 1.1 + randf() * 0.9
	else:
		if lunge_t > 0:
			lunge_t -= delta
			move = lunge_dir * 2.0
			if dist < 1.2:
				pl.take_damage(9)
				lunge_t = 0
		elif dist > 2.2:
			move = to_p.normalized()
		else:
			lunge_t = 0.4
			lunge_dir = to_p.normalized()
		if dist < 1.5:
			attack_t -= delta
			if attack_t <= 0:
				pl.take_damage(8)
				attack_t = 0.8

	velocity.x = move.x * speed
	velocity.z = move.z * speed
	velocity.y -= 22 * delta
	move_and_slide()

func _shoot(pl) -> void:
	main.snd("eshot", global_position)
	var from: Vector3 = gun_tip.global_position if gun_tip else global_position + Vector3(0, 1.35, 0)
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.8, 0.55)
	fl.light_energy = 2.5
	fl.omni_range = 6
	main.add_child(fl)
	fl.global_position = from
	get_tree().create_timer(0.05).timeout.connect(fl.queue_free)

	var target: Vector3 = pl.global_position + Vector3(0, 1.2, 0)
	var miss: float = 0.5 + pl.velocity.length() * 0.12
	target += Vector3(randf_range(-miss, miss), randf_range(-0.4, 0.4), randf_range(-miss, miss))
	var q := PhysicsRayQueryParameters3D.create(from, target, 0xFFFFFFFF, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end := target
	if hit:
		end = hit.position
		if hit.collider == pl:
			pl.take_damage(8)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.012, from.distance_to(end))
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.emission_enabled = true
	m.emission = Color(1.0, 0.82, 0.6)
	m.emission_energy_multiplier = 2.5
	mi.material_override = m
	main.add_child(mi)
	mi.global_position = (from + end) / 2
	if from.distance_to(end) > 0.1:
		mi.look_at_from_position(mi.global_position, end, Vector3.UP)
	get_tree().create_timer(0.06).timeout.connect(mi.queue_free)
