extends CharacterBody3D
# игрок: движение + боёвка

var main: Node3D
var cam: Camera3D
var head: Node3D
var flash: SpotLight3D
var muzzle_light: OmniLight3D
var vm := {}
var interact_target = null

var hp := 100.0
var god := false
var dead := false
var weapon := "pm"
var have := {"pm": true, "ak": false}
var clip := {"pm": 8, "ak": 0}
var clip_size := {"pm": 8, "ak": 30}
var ammo := {"pm": 24, "ak": 0}
var fire_rate := {"pm": 0.22, "ak": 0.1}
var is_auto := {"pm": false, "ak": true}
var dmg := {"pm": 25.0, "ak": 14.0}
var spread := {"pm": 0.012, "ak": 0.028}
var fire_t := 0.0
var reload_t := 0.0
var recoil := 0.0
var step_t := 0.0

func _ready() -> void:
	add_to_group("player")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)

	head = Node3D.new()
	head.position.y = 1.58
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 76
	head.add_child(cam)

	flash = SpotLight3D.new()
	flash.light_energy = 0.0
	flash.spot_range = 24
	flash.spot_angle = 28
	flash.light_color = Color(1.0, 0.94, 0.8)
	flash.shadow_enabled = true
	cam.add_child(flash)

	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.8, 0.55)
	muzzle_light.light_energy = 0.0
	muzzle_light.omni_range = 8
	muzzle_light.position = Vector3(0.2, -0.15, -0.7)
	cam.add_child(muzzle_light)

	_build_viewmodels()
	_update_hud()

func _build_viewmodels() -> void:
	var pm_g := Node3D.new()
	pm_g.position = Vector3(0.26, -0.24, -0.45)
	var slide := MeshInstance3D.new()
	var b1 := BoxMesh.new()
	b1.size = Vector3(0.06, 0.07, 0.26)
	slide.mesh = b1
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.17, 0.18, 0.2)
	slide.material_override = mm
	pm_g.add_child(slide)
	var grip := MeshInstance3D.new()
	var b2 := BoxMesh.new()
	b2.size = Vector3(0.055, 0.14, 0.07)
	grip.mesh = b2
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.23, 0.19, 0.15)
	grip.material_override = gm
	grip.position = Vector3(0, -0.09, 0.08)
	grip.rotation.x = 0.25
	pm_g.add_child(grip)
	cam.add_child(pm_g)
	vm["pm"] = pm_g

	var ak_g := Node3D.new()
	ak_g.position = Vector3(0.24, -0.25, -0.42)
	var recv := MeshInstance3D.new()
	var b3 := BoxMesh.new()
	b3.size = Vector3(0.07, 0.09, 0.5)
	recv.mesh = b3
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.18, 0.17, 0.15)
	recv.material_override = rm
	ak_g.add_child(recv)
	var barrel := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.018
	cm.bottom_radius = 0.018
	cm.height = 0.3
	barrel.mesh = cm
	barrel.rotation.x = PI / 2
	barrel.position = Vector3(0, 0.01, -0.38)
	barrel.material_override = rm
	ak_g.add_child(barrel)
	var mag := MeshInstance3D.new()
	var b4 := BoxMesh.new()
	b4.size = Vector3(0.05, 0.2, 0.09)
	mag.mesh = b4
	var mgm := StandardMaterial3D.new()
	mgm.albedo_color = Color(0.54, 0.29, 0.16)
	mag.material_override = mgm
	mag.position = Vector3(0, -0.13, -0.04)
	mag.rotation.x = 0.35
	ak_g.add_child(mag)
	var hg := MeshInstance3D.new()
	var b5 := BoxMesh.new()
	b5.size = Vector3(0.075, 0.07, 0.18)
	hg.mesh = b5
	var hgm := StandardMaterial3D.new()
	hgm.albedo_color = Color(0.42, 0.29, 0.17)
	hg.material_override = hgm
	hg.position = Vector3(0, -0.005, -0.26)
	ak_g.add_child(hg)
	cam.add_child(ak_g)
	ak_g.visible = false
	vm["ak"] = ak_g

func _unhandled_input(event: InputEvent) -> void:
	if dead or main.paper_open() or not main.started:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * 0.0021
		head.rotation.x = clamp(head.rotation.x - event.relative.y * 0.0021, -1.5, 1.5)
	if event.is_action_pressed("interact") and interact_target != null:
		interact_target.cb.call()
	if event.is_action_pressed("flash"):
		flash.light_energy = 3.0 if flash.light_energy == 0.0 else 0.0
	if event.is_action_pressed("reload"):
		_start_reload()
	if event.is_action_pressed("godmode"):
		god = not god
		main.toast("режим наблюдателя: " + ("ВКЛ" if god else "ВЫКЛ"))
	if event.is_action_pressed("weapon1"):
		_switch("pm")
	if event.is_action_pressed("weapon2"):
		_switch("ak")

func _switch(w: String) -> void:
	if not have[w] or reload_t > 0:
		return
	weapon = w
	for k in vm:
		vm[k].visible = k == weapon
	_update_hud()

func give(type: String, amount: int) -> void:
	match type:
		"medkit":
			hp = min(100, hp + amount)
			main.toast("аптечка +%d" % amount)
		"ammo_pm":
			ammo["pm"] += amount
			main.toast("9×18 +%d" % amount)
		"ammo_ak":
			ammo["ak"] += amount
			main.toast("5,45 +%d" % amount)
		"ak":
			have["ak"] = true
			clip["ak"] = 30
			_switch("ak")
			main.toast("АКС-74У")
	_update_hud()

func _physics_process(delta: float) -> void:
	if dead or not main.started:
		return
	if main.paper_open():
		return
	var dir := Vector3.ZERO
	var fwd := -global_transform.basis.z
	var right := global_transform.basis.x
	if Input.is_action_pressed("move_fw"):
		dir += fwd
	if Input.is_action_pressed("move_bk"):
		dir -= fwd
	if Input.is_action_pressed("move_rt"):
		dir += right
	if Input.is_action_pressed("move_lt"):
		dir -= right
	dir.y = 0
	dir = dir.normalized()
	var speed := 7.2 if Input.is_action_pressed("sprint") else 4.4
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y -= 22 * delta
	if Input.is_action_pressed("jump") and is_on_floor():
		velocity.y = 7.2
	move_and_slide()

	if dir.length() > 0.1 and is_on_floor():
		step_t -= delta * (1.6 if speed > 5 else 1.0)
		if step_t <= 0:
			main.snd("step")
			step_t = 0.42

	fire_t -= delta
	if Input.is_action_pressed("fire") and fire_t <= 0 and reload_t <= 0:
		if is_auto[weapon] or Input.is_action_just_pressed("fire"):
			_fire()
	if reload_t > 0:
		reload_t -= delta
		if reload_t <= 0:
			var need: int = clip_size[weapon] - clip[weapon]
			var take: int = min(need, ammo[weapon])
			clip[weapon] += take
			ammo[weapon] -= take
			_update_hud()
	recoil = max(0.0, recoil - delta * 4)
	vm[weapon].position.z = -0.45 + recoil * 0.07
	vm[weapon].rotation.x = recoil * 0.18
	if reload_t > 0:
		vm[weapon].position.y = -0.25 - 0.14 * sin(min(1.0, reload_t) * PI)
	else:
		vm[weapon].position.y = -0.24 if weapon == "pm" else -0.25

func _fire() -> void:
	if clip[weapon] <= 0:
		_start_reload()
		return
	clip[weapon] -= 1
	fire_t = fire_rate[weapon]
	recoil = 1.0
	head.rotation.x += 0.012 if weapon == "ak" else 0.02
	main.snd(weapon)
	muzzle_light.light_energy = 4.0
	get_tree().create_timer(0.05).timeout.connect(func(): muzzle_light.light_energy = 0.0)

	var from := cam.global_position
	var f := -cam.global_transform.basis.z
	f += cam.global_transform.basis.x * randf_range(-1, 1) * spread[weapon] * (1 + recoil)
	f += cam.global_transform.basis.y * randf_range(-1, 1) * spread[weapon] * (1 + recoil)
	f = f.normalized()
	var to := from + f * 90
	var q := PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end := to
	if hit:
		end = hit.position
		var col = hit.collider
		var enemy = col if col.is_in_group("enemies") else (col.get_parent() if col.get_parent() and col.get_parent().is_in_group("enemies") else null)
		if enemy != null:
			enemy.take_damage(dmg[weapon])
			main.snd("hit")
		_impact(end, hit.get("normal", Vector3.UP))
	_tracer(from + f * 0.9, end)
	_update_hud()

func _start_reload() -> void:
	if reload_t > 0 or clip[weapon] >= clip_size[weapon] or ammo[weapon] <= 0:
		if ammo[weapon] <= 0 and clip[weapon] <= 0:
			main.toast("нет патронов")
		return
	reload_t = 1.6 if weapon == "ak" else 1.1
	main.snd("reload")

func _tracer(a: Vector3, b: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.015, 0.015, a.distance_to(b))
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.emission_enabled = true
	m.emission = Color(1.0, 0.9, 0.6)
	m.emission_energy_multiplier = 3.0
	m.albedo_color = Color(1.0, 0.9, 0.6)
	mi.material_override = m
	main.add_child(mi)
	mi.global_position = (a + b) / 2
	if a.distance_to(b) > 0.1:
		mi.look_at_from_position(mi.global_position, b, Vector3.UP)
	get_tree().create_timer(0.06).timeout.connect(mi.queue_free)

func _impact(pos: Vector3, _n: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 8
	p.lifetime = 0.35
	p.one_shot = true
	p.emitting = true
	p.direction = Vector3.UP
	p.spread = 60
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, -9, 0)
	p.mesh = BoxMesh.new()
	p.mesh.size = Vector3(0.03, 0.03, 0.03)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.8, 0.76, 0.62)
	m.emission_enabled = true
	m.emission = Color(0.8, 0.76, 0.62)
	p.mesh.material = m
	main.add_child(p)
	p.global_position = pos
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)

func take_damage(n: float) -> void:
	if god or dead:
		return
	hp -= n
	main.snd("hurt")
	if hp <= 0:
		hp = 0
		dead = true
		main.on_player_death()
	_update_hud()

func _update_hud() -> void:
	if main == null or main.hp_label == null:
		return
	main.hp_label.text = "ЗДР %d" % int(hp)
	var names := {"pm": "ПМ", "ak": "АКС-74У"}
	main.ammo_label.text = "%s  %d / %d" % [names[weapon], clip[weapon], ammo[weapon]]
