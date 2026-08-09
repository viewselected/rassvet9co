extends CharacterBody3D
# враги: gunner (одержимый боец в противогазе) и crawler (ползун)

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
var walk_phase := 0.0
var l_leg: Node3D
var r_leg: Node3D
var l_arm: Node3D
var torso: Node3D
var legs := []

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

func _m(col: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	if glow > 0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	return m

func _part(parent: Node3D, size: Vector3, col: Color, pos: Vector3, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _m(col, glow)
	mi.position = pos
	parent.add_child(mi)
	return mi

func _cyl(parent: Node3D, r: float, h: float, col: Color, pos: Vector3, rot := Vector3.ZERO, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	mi.mesh = cm
	mi.material_override = _m(col, glow)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _build_body() -> void:
	if kind == "gunner":
		var uni := Color(0.23, 0.26, 0.22)      # выцветшая форма
		var dark := Color(0.14, 0.15, 0.14)
		var rubber := Color(0.11, 0.12, 0.12)   # резина противогаза
		var metal := Color(0.3, 0.32, 0.3)

		torso = Node3D.new()
		torso.position.y = 1.28
		add_child(torso)
		_part(torso, Vector3(0.56, 0.86, 0.34), uni, Vector3(0, 0, 0))
		_part(torso, Vector3(0.5, 0.55, 0.06), dark, Vector3(0, 0.08, -0.2))       # бронеплита
		_part(torso, Vector3(0.58, 0.12, 0.36), Color(0.3, 0.25, 0.16), Vector3(0, -0.36, 0)) # ремень
		_part(torso, Vector3(0.34, 0.5, 0.2), Color(0.28, 0.3, 0.24), Vector3(0, 0.05, 0.28)) # вещмешок
		# подсумки
		_part(torso, Vector3(0.14, 0.18, 0.08), dark, Vector3(-0.16, -0.28, -0.2))
		_part(torso, Vector3(0.14, 0.18, 0.08), dark, Vector3(0.06, -0.28, -0.2))

		# голова: противогаз
		var head := Node3D.new()
		head.position.y = 1.94
		add_child(head)
		_part(head, Vector3(0.26, 0.3, 0.26), rubber, Vector3.ZERO)
		_part(head, Vector3(0.18, 0.14, 0.1), rubber, Vector3(0, -0.04, -0.17))     # морда маски
		_cyl(head, 0.06, 0.08, Color(0.35, 0.36, 0.3), Vector3(0.12, -0.1, -0.14), Vector3(PI / 2, 0, 0.5)) # фильтр
		_cyl(head, 0.055, 0.02, Color(0.85, 0.87, 0.78), Vector3(-0.07, 0.05, -0.135), Vector3(PI / 2, 0, 0), 1.8) # окуляры светятся
		_cyl(head, 0.055, 0.02, Color(0.85, 0.87, 0.78), Vector3(0.07, 0.05, -0.135), Vector3(PI / 2, 0, 0), 1.8)
		# каска
		_part(head, Vector3(0.3, 0.1, 0.3), metal, Vector3(0, 0.17, 0))
		_part(head, Vector3(0.34, 0.05, 0.34), metal, Vector3(0, 0.12, 0))

		# руки
		l_arm = Node3D.new()
		l_arm.position = Vector3(-0.36, 1.62, 0)
		add_child(l_arm)
		_part(l_arm, Vector3(0.13, 0.58, 0.13), uni, Vector3(0, -0.29, 0))
		var r_arm := Node3D.new()
		r_arm.position = Vector3(0.36, 1.62, 0)
		add_child(r_arm)
		_part(r_arm, Vector3(0.13, 0.42, 0.13), uni, Vector3(0, -0.16, -0.08))
		# оружие в правой руке
		var gun := _part(r_arm, Vector3(0.07, 0.07, 0.66), Color(0.13, 0.13, 0.15), Vector3(-0.12, -0.3, -0.28))
		_part(gun, Vector3(0.045, 0.16, 0.08), Color(0.5, 0.28, 0.15), Vector3(0, -0.1, 0.02)) # магазин
		gun_tip = Node3D.new()
		gun_tip.position = Vector3(0, 0, -0.38)
		gun.add_child(gun_tip)

		# ноги
		l_leg = Node3D.new()
		l_leg.position = Vector3(-0.15, 0.85, 0)
		add_child(l_leg)
		_part(l_leg, Vector3(0.2, 0.85, 0.22), Color(0.17, 0.19, 0.17), Vector3(0, -0.42, 0))
		_part(l_leg, Vector3(0.2, 0.12, 0.3), Color(0.1, 0.1, 0.1), Vector3(0, -0.8, -0.04)) # сапог
		r_leg = Node3D.new()
		r_leg.position = Vector3(0.15, 0.85, 0)
		add_child(r_leg)
		_part(r_leg, Vector3(0.2, 0.85, 0.22), Color(0.17, 0.19, 0.17), Vector3(0, -0.42, 0))
		_part(r_leg, Vector3(0.2, 0.12, 0.3), Color(0.1, 0.1, 0.1), Vector3(0, -0.8, -0.04))
	else:
		var bodycol := Color(0.15, 0.14, 0.12)
		var b := Node3D.new()
		b.position.y = 0.28
		add_child(b)
		torso = b
		_part(b, Vector3(0.66, 0.26, 0.9), bodycol, Vector3.ZERO)
		_part(b, Vector3(0.4, 0.2, 0.34), bodycol, Vector3(0, 0.06, -0.55))       # голова
		_part(b, Vector3(0.5, 0.1, 0.5), Color(0.24, 0.2, 0.16), Vector3(0, 0.17, 0.1)) # горб
		_cyl(b, 0.03, 0.5, bodycol, Vector3(0, 0.08, 0.62), Vector3(PI / 2.4, 0, 0))    # хвост
		_part(b, Vector3(0.05, 0.03, 0.02), Color(0.82, 0.45, 0.3), Vector3(-0.11, 0.1, -0.72), 2.2)
		_part(b, Vector3(0.05, 0.03, 0.02), Color(0.82, 0.45, 0.3), Vector3(0.11, 0.1, -0.72), 2.2)
		for i in range(3):
			for s in [-1, 1]:
				var leg := Node3D.new()
				leg.position = Vector3(s * 0.38, 0.3, -0.3 + i * 0.3)
				add_child(leg)
				_part(leg, Vector3(0.055, 0.34, 0.055), bodycol, Vector3(s * 0.08, -0.14, 0))
				legs.append(leg)

func take_damage(n: float, impulse := Vector3.ZERO) -> void:
	hp -= n
	if state == "idle":
		state = "combat"
	if impulse != Vector3.ZERO:
		velocity += impulse
	if hp <= 0 and not dead:
		dead = true
		main.snd("creature", global_position)
		set_collision_layer_value(1, false)
		var tw := create_tween()
		if kind == "gunner":
			tw.tween_property(self, "rotation:x", PI / 2 * (1 if randf() > 0.5 else -1), 0.45)
		else:
			tw.tween_property(self, "scale:y", 0.12, 0.35)
		tw.tween_interval(4.0)
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

	velocity.x = move.x * speed * (2.0 if lunge_t > 0 else 1.0)
	velocity.z = move.z * speed * (2.0 if lunge_t > 0 else 1.0)
	velocity.y -= 22 * delta
	move_and_slide()

	# анимация ходьбы
	var moving := Vector2(velocity.x, velocity.z).length() > 0.4
	if moving:
		walk_phase += delta * (10.0 if kind == "gunner" else 20.0)
	if kind == "gunner":
		var sw := sin(walk_phase) * 0.55 if moving else 0.0
		if l_leg:
			l_leg.rotation.x = sw
			r_leg.rotation.x = -sw
			l_arm.rotation.x = -sw * 0.6
		if torso:
			torso.rotation.z = sin(walk_phase * 0.5) * 0.03 if moving else 0.0
			torso.rotation.x = 0.06	# лёгкая сутулость
	else:
		for i in range(legs.size()):
			legs[i].rotation.x = sin(walk_phase + i * 1.7) * 0.7 if moving else 0.0
		if torso:
			torso.position.y = 0.28 + (sin(walk_phase * 2) * 0.02 if moving else 0.0)

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
		elif hit.collider is RigidBody3D:
			hit.collider.apply_central_impulse((end - from).normalized() * 2.5)
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
