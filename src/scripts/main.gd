extends Node3D
# ПРОСВЕТ-9 · godot-срез · главный узел: мир, уровень, HUD

var mats := {}
var player: CharacterBody3D
var hud: CanvasLayer
var subtitle_label: RichTextLabel
var objective_label: Label
var interact_label: Label
var paper_panel: PanelContainer
var paper_label: Label
var death_panel: ColorRect
var menu_panel: ColorRect
var pause_panel: ColorRect
var hp_label: Label
var ammo_label: Label
var flicker_lights := []
var sub_queue := []
var sub_time := 0.0
var interactables := []
var triggers := []
var started := false
var resume_cd := 0.0

const SND := {
	"pm": preload("res://assets/sfx/pm.wav"),
	"ak": preload("res://assets/sfx/ak.wav"),
	"eshot": preload("res://assets/sfx/eshot.wav"),
	"reload": preload("res://assets/sfx/reload.wav"),
	"hit": preload("res://assets/sfx/hit.wav"),
	"hurt": preload("res://assets/sfx/hurt.wav"),
	"pickup": preload("res://assets/sfx/pickup.wav"),
	"step": preload("res://assets/sfx/step.wav"),
	"creature": preload("res://assets/sfx/creature.wav"),
}

func _ready() -> void:
	_make_env()
	_make_mats()
	_build_level()
	_spawn_player(Vector3(0, 1.0, 6), 0.0)
	_make_hud()
	_ambience()

func snd(name_: String, at: Vector3 = Vector3.INF, vol := 0.0) -> void:
	if at == Vector3.INF:
		var p := AudioStreamPlayer.new()
		p.stream = SND[name_]
		p.volume_db = vol
		add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
	else:
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = SND[name_]
		p3.volume_db = vol
		p3.max_distance = 40
		add_child(p3)
		p3.global_position = at
		p3.play()
		p3.finished.connect(p3.queue_free)

func _ambience() -> void:
	var amb := AudioStreamPlayer.new()
	var st: AudioStreamWAV = load("res://assets/sfx/ambience.wav")
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_end = st.data.size() / 2
	amb.stream = st
	amb.volume_db = -12
	add_child(amb)
	amb.play()

func _make_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.045, 0.055, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.72)
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.075, 0.09)
	env.fog_density = 0.028
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _mat(tex: String, rx := 1.0, ry := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/tex/%s.png" % tex)
	m.uv1_scale = Vector3(rx, ry, 1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.92
	return m

func _make_mats() -> void:
	mats["concrete"] = _mat("concrete")
	mats["wallstripe"] = _mat("wallstripe")
	mats["tile"] = _mat("tile", 2, 1)
	mats["metal"] = _mat("metal")
	mats["floor"] = _mat("floor", 4, 4)
	mats["ceil"] = _mat("ceil", 3, 3)
	mats["rust"] = _mat("rust")
	mats["wood"] = _mat("wood")

# ---------- геометрия ----------

func add_box(pos: Vector3, size: Vector3, mat_name: String, solid := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mats[mat_name]
	add_child(mi)
	mi.global_position = pos
	if solid:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		sb.add_child(cs)
		mi.add_child(sb)
	return mi

func room(cx: float, cz: float, w: float, d: float, h: float, o := {}) -> void:
	var wall: String = o.get("wall", "concrete")
	var floor_m: String = o.get("floor", "floor")
	var ceil_m: String = o.get("ceil", "ceil")
	var t := 0.4
	add_box(Vector3(cx, -0.2, cz), Vector3(w + t * 2, 0.4, d + t * 2), floor_m)
	add_box(Vector3(cx, h + 0.2, cz), Vector3(w + t * 2, 0.4, d + t * 2), ceil_m)
	for side in ["n", "s", "e", "w"]:
		var open = o.get(side, null)
		var along_x: bool = (side == "n" or side == "s")
		var length := w if along_x else d
		var wx := cx if along_x else cx + (w / 2 + t / 2) * (1 if side == "e" else -1)
		var wz := cz + (d / 2 + t / 2) * (-1 if side == "n" else 1) if along_x else cz
		if open == null:
			var size := Vector3(length + t * 2, h, t) if along_x else Vector3(t, h, length + t * 2)
			add_box(Vector3(wx, h / 2, wz), size, wall)
		else:
			var ow: float = open.get("w", 2.0)
			var oh: float = open.get("h", 2.6)
			var off: float = open.get("off", 0.0)
			var seg_a := (length - ow) / 2 + off
			var seg_b := (length - ow) / 2 - off
			if along_x:
				if seg_a > 0.05:
					add_box(Vector3(cx - length / 2 + seg_a / 2, h / 2, wz), Vector3(seg_a, h, t), wall)
				if seg_b > 0.05:
					add_box(Vector3(cx + length / 2 - seg_b / 2, h / 2, wz), Vector3(seg_b, h, t), wall)
				add_box(Vector3(cx - length / 2 + seg_a + ow / 2, oh + (h - oh) / 2, wz), Vector3(ow, h - oh, t), wall)
			else:
				if seg_a > 0.05:
					add_box(Vector3(wx, h / 2, cz - length / 2 + seg_a / 2), Vector3(t, h, seg_a), wall)
				if seg_b > 0.05:
					add_box(Vector3(wx, h / 2, cz + length / 2 - seg_b / 2), Vector3(t, h, seg_b), wall)
				add_box(Vector3(wx, oh + (h - oh) / 2, cz - length / 2 + seg_a + ow / 2), Vector3(t, h - oh, ow), wall)

func fluor(pos: Vector3, len_ := 2.0, axis := "x", flick := 0.0, energy := 2.4, shadows := false) -> void:
	var tube := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(len_ if axis == "x" else 0.14, 0.07, len_ if axis == "z" else 0.14)
	tube.mesh = bm
	var m := StandardMaterial3D.new()
	m.emission_enabled = true
	m.emission = Color(0.87, 0.91, 0.84)
	m.emission_energy_multiplier = 2.0
	m.albedo_color = Color(0.8, 0.85, 0.8)
	tube.material_override = m
	add_child(tube)
	tube.global_position = pos
	var l := OmniLight3D.new()
	l.light_color = Color(0.85, 0.89, 0.8)
	l.light_energy = energy
	l.omni_range = 13
	l.shadow_enabled = shadows
	add_child(l)
	l.global_position = pos + Vector3(0, -0.35, 0)
	if flick > 0:
		flicker_lights.append({"tube": tube, "light": l, "base": energy, "speed": flick, "seed": randf() * 99})

func red_lamp(pos: Vector3, energy := 1.6) -> void:
	var b := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	b.mesh = sm
	var m := StandardMaterial3D.new()
	m.emission_enabled = true
	m.emission = Color(0.8, 0.25, 0.2)
	m.emission_energy_multiplier = 2.5
	b.material_override = m
	add_child(b)
	b.global_position = pos
	var l := OmniLight3D.new()
	l.light_color = Color(0.8, 0.28, 0.22)
	l.light_energy = energy
	l.omni_range = 10
	l.shadow_enabled = false
	add_child(l)
	l.global_position = pos

func pipe(from: Vector3, to: Vector3, r := 0.07) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = from.distance_to(to)
	mi.mesh = cm
	mi.material_override = mats["rust"]
	add_child(mi)
	mi.global_position = (from + to) / 2
	mi.look_at_from_position(mi.global_position, to, Vector3.UP)
	mi.rotate_object_local(Vector3.RIGHT, PI / 2)

func label3d(pos: Vector3, text: String, ry: float, size := 46, col := Color(0.78, 0.28, 0.22), outline := 8) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.modulate = col
	l.outline_size = outline
	l.outline_modulate = Color(0, 0, 0, 0.6)
	l.pixel_size = 0.01
	add_child(l)
	l.global_position = pos
	l.rotation.y = ry

func sign_plate(pos: Vector3, text: String, ry: float, w := 2.2) -> void:
	var plate := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, 0.7, 0.06)
	plate.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.19, 0.24)
	plate.material_override = m
	add_child(plate)
	plate.global_position = pos
	plate.rotation.y = ry
	var l := Label3D.new()
	l.text = text
	l.font_size = 36
	l.modulate = Color(0.78, 0.8, 0.76)
	l.pixel_size = 0.008
	add_child(l)
	l.global_position = pos + Vector3(sin(ry), 0, cos(ry)) * 0.05
	l.rotation.y = ry

func crate(x: float, z: float, s := 1.3) -> void:
	add_box(Vector3(x, s / 2, z), Vector3(s, s, s), "wood")

func barrel_dyn(x: float, z: float) -> void:
	var rb := RigidBody3D.new()
	rb.mass = 14
	rb.linear_damp = 0.4
	rb.angular_damp = 0.6
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.42
	sh.height = 1.15
	cs.shape = sh
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.42
	cm.bottom_radius = 0.42
	cm.height = 1.15
	mi.mesh = cm
	mi.material_override = mats["rust"]
	rb.add_child(mi)
	add_child(rb)
	rb.global_position = Vector3(x, 0.7, z)

func crate_dyn(x: float, z: float, s := 0.9) -> void:
	var rb := RigidBody3D.new()
	rb.mass = 8
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(s, s, s)
	cs.shape = sh
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(s, s, s)
	mi.mesh = bm
	mi.material_override = mats["wood"]
	rb.add_child(mi)
	add_child(rb)
	rb.global_position = Vector3(x, s / 2 + 0.3, z)

func barrel(x: float, z: float) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.42
	cm.bottom_radius = 0.42
	cm.height = 1.15
	mi.mesh = cm
	mi.material_override = mats["rust"]
	add_child(mi)
	mi.global_position = Vector3(x, 0.575, z)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.45
	sh.height = 1.15
	cs.shape = sh
	sb.add_child(cs)
	mi.add_child(sb)

func machine(x: float, z: float) -> void:
	add_box(Vector3(x, 1.0, z), Vector3(2.6, 2.0, 1.6), "metal")
	add_box(Vector3(x, 2.25, z), Vector3(1.0, 0.5, 1.0), "rust")

func item(pos: Vector3, type: String, amount := 0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.16, 0.2, 0.9) if type in ["ak", "mosin", "sg"] else Vector3(0.34, 0.22, 0.34)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	var cols := {"medkit": Color(0.7, 0.2, 0.16), "ammo_pm": Color(0.55, 0.55, 0.35),
		"ammo_ak": Color(0.6, 0.48, 0.22), "ak": Color(0.35, 0.27, 0.18),
		"sg": Color(0.3, 0.24, 0.16), "ammo_sg": Color(0.5, 0.38, 0.2),
		"mosin": Color(0.42, 0.3, 0.16), "ammo_mosin": Color(0.45, 0.42, 0.3)}
	m.albedo_color = cols.get(type, Color.GRAY)
	m.emission_enabled = true
	m.emission = m.albedo_color
	m.emission_energy_multiplier = 0.35
	mi.material_override = m
	add_child(mi)
	mi.global_position = pos
	var it := {"node": mi, "type": type, "amount": amount, "taken": false}
	set_meta("items", get_meta("items", []) + [it])

func note(pos: Vector3, text: String) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.4, 0.5)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.81, 0.79, 0.71)
	mi.material_override = m
	add_child(mi)
	mi.global_position = pos
	mi.rotation.z = randf() * 0.6
	interactables.append({"pos": pos, "label": "прочитать записку", "cb": func(): show_paper(text)})

func trigger(pos: Vector3, size: Vector3, cb: Callable) -> void:
	triggers.append({"min": pos - size / 2, "max": pos + size / 2, "cb": cb, "fired": false})

# ---------- HUD ----------

func _make_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var font_col := Color(0.85, 0.83, 0.77)

	var cross := ColorRect.new()
	cross.color = Color(0.85, 0.83, 0.77, 0.8)
	cross.size = Vector2(4, 4)
	cross.position = Vector2(478, 268)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(cross)

	hp_label = Label.new()
	hp_label.position = Vector2(16, 500)
	hp_label.add_theme_color_override("font_color", font_col)
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hp_label)

	ammo_label = Label.new()
	ammo_label.position = Vector2(840, 490)
	ammo_label.add_theme_font_size_override("font_size", 22)
	ammo_label.add_theme_color_override("font_color", font_col)
	ammo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(ammo_label)

	objective_label = Label.new()
	objective_label.position = Vector2(16, 12)
	objective_label.add_theme_color_override("font_color", Color(0.6, 0.63, 0.6))
	objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(objective_label)

	interact_label = Label.new()
	interact_label.position = Vector2(400, 300)
	interact_label.add_theme_color_override("font_color", font_col)
	interact_label.visible = false
	interact_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(interact_label)

	subtitle_label = RichTextLabel.new()
	subtitle_label.bbcode_enabled = true
	subtitle_label.position = Vector2(160, 430)
	subtitle_label.size = Vector2(640, 80)
	subtitle_label.add_theme_font_size_override("normal_font_size", 16)
	subtitle_label.visible = false
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(subtitle_label)

	paper_panel = PanelContainer.new()
	paper_panel.position = Vector2(180, 60)
	paper_panel.size = Vector2(600, 420)
	paper_panel.visible = false
	paper_label = Label.new()
	paper_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	paper_label.add_theme_font_size_override("font_size", 19)
	paper_label.add_theme_color_override("font_color", Color(0.13, 0.12, 0.09))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.81, 0.79, 0.71)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
	paper_panel.add_theme_stylebox_override("panel", sb)
	paper_panel.add_child(paper_label)
	hud.add_child(paper_panel)

	death_panel = ColorRect.new()
	death_panel.color = Color(0.04, 0.02, 0.02, 0.92)
	death_panel.size = Vector2(960, 540)
	death_panel.visible = false
	var dl := Label.new()
	dl.text = "СИГНАЛ ПОТЕРЯН"
	dl.position = Vector2(390, 220)
	dl.add_theme_font_size_override("font_size", 28)
	dl.add_theme_color_override("font_color", Color(0.7, 0.25, 0.2))
	death_panel.add_child(dl)
	var db := Button.new()
	db.text = "ПОДНЯТЬСЯ"
	db.position = Vector2(430, 280)
	db.focus_mode = Control.FOCUS_NONE
	db.pressed.connect(func(): get_tree().reload_current_scene())
	death_panel.add_child(db)
	hud.add_child(death_panel)

	pause_panel = ColorRect.new()
	pause_panel.color = Color(0.02, 0.025, 0.03, 0.85)
	pause_panel.size = Vector2(960, 540)
	pause_panel.visible = false
	var pl := Label.new()
	pl.text = "СВЯЗЬ ПРИОСТАНОВЛЕНА · КЛИКНИ ЧТОБЫ ПРОДОЛЖИТЬ"
	pl.position = Vector2(240, 230)
	pl.add_theme_font_size_override("font_size", 24)
	pl.add_theme_color_override("font_color", Color(0.7, 0.72, 0.66))
	pause_panel.add_child(pl)
	var pb := Button.new()
	pb.text = "ПРОДОЛЖИТЬ"
	pb.position = Vector2(424, 270)
	pb.focus_mode = Control.FOCUS_NONE
	pb.pressed.connect(func():
		pause_panel.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)
	pause_panel.add_child(pb)
	hud.add_child(pause_panel)

	menu_panel = ColorRect.new()
	menu_panel.color = Color(0.03, 0.035, 0.045, 1.0)
	menu_panel.size = Vector2(960, 540)
	var ml := Label.new()
	ml.text = "ПРОСВЕТ-9"
	ml.position = Vector2(370, 180)
	ml.add_theme_font_size_override("font_size", 44)
	ml.add_theme_color_override("font_color", font_col)
	menu_panel.add_child(ml)
	var ms := Label.new()
	ms.text = "вертикальный срез · godot"
	ms.position = Vector2(392, 240)
	ms.add_theme_color_override("font_color", Color(0.45, 0.48, 0.45))
	menu_panel.add_child(ms)
	var mb := Button.new()
	mb.text = "СПУСТИТЬСЯ (или кликни)"
	mb.position = Vector2(424, 300)
	mb.focus_mode = Control.FOCUS_NONE
	mb.pressed.connect(_start_game)
	menu_panel.add_child(mb)
	hud.add_child(menu_panel)

func _start_game() -> void:
	menu_panel.visible = false
	started = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	say("ГРОМКАЯ СВЯЗЬ", "Внимание. Смена семь, горизонт три. Работаем в штатном режиме. Штатном. Штатном.", 6.0)
	set_objective("пройти к цеху сборки №1")

func set_objective(t: String) -> void:
	objective_label.text = "▸ ЗАДАЧА: " + t

func say(who: String, text: String, dur := 4.5) -> void:
	sub_queue.append({"who": who, "text": text, "dur": dur})

func toast(text: String) -> void:
	say("", text, 2.2)

func show_paper(text: String) -> void:
	paper_label.text = text + "\n\n[E] или клик — убрать документ"
	paper_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_paper() -> void:
	paper_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func paper_open() -> bool:
	return paper_panel.visible

func on_player_death() -> void:
	death_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	# мерцание ламп
	var t := Time.get_ticks_msec() / 1000.0
	for f in flicker_lights:
		var v: float = sin(t * f.speed + f.seed) + sin(t * f.speed * 3.7 + f.seed * 2)
		var on := v > -0.6
		f.tube.visible = on
		f.light.light_energy = f.base if on else 0.0
	# субтитры
	if sub_time > 0:
		sub_time -= delta
		if sub_time <= 0:
			subtitle_label.visible = false
	elif sub_queue.size() > 0:
		var s: Dictionary = sub_queue.pop_front()
		var head: String = "[color=#8a92a0]%s[/color]\n" % s.who if s.who != "" else ""
		subtitle_label.text = "[center]" + head + s.text + "[/center]"
		subtitle_label.visible = true
		sub_time = s.dur
	resume_cd = max(0.0, resume_cd - delta)
	if paper_open() and Input.is_action_just_pressed("interact"):
		hide_paper()
		resume_cd = 0.2
	if player == null or not started:
		return
	if started and not player.dead and not death_panel.visible and not paper_open() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not pause_panel.visible and not menu_panel.visible:
		pause_panel.visible = true
	# предметы
	var items: Array = get_meta("items", [])
	for it in items:
		if it.taken:
			continue
		it.node.rotation.y += delta * 1.5
		if it.node.global_position.distance_to(player.global_position) < 1.4:
			it.taken = true
			it.node.visible = false
			snd("pickup")
			player.give(it.type, it.amount)
	# триггеры
	for tr in triggers:
		if tr.fired:
			continue
		var p: Vector3 = player.global_position
		if p.x > tr.min.x and p.x < tr.max.x and p.z > tr.min.z and p.z < tr.max.z and p.y > tr.min.y and p.y < tr.max.y:
			tr.fired = true
			tr.cb.call()
	# интерактив
	var best = null
	var bd := 2.3
	for i in interactables:
		var d: float = i.pos.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = i
	if best != null:
		interact_label.text = "[E] " + best.label
		interact_label.visible = true
	else:
		interact_label.visible = false
	player.interact_target = best

func _input(event: InputEvent) -> void:
	# мышиные события на вебе доходят всегда — вся навигация UI живёт на них
	if event is InputEventMouseButton and event.pressed:
		if menu_panel.visible:
			_start_game()
			resume_cd = 0.25
			get_viewport().set_input_as_handled()
		elif pause_panel != null and pause_panel.visible:
			pause_panel.visible = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			resume_cd = 0.25
			get_viewport().set_input_as_handled()
		elif paper_open():
			hide_paper()
			resume_cd = 0.25
			get_viewport().set_input_as_handled()
	if event.is_action_pressed("interact") and paper_open():
		hide_paper()
		resume_cd = 0.2
		get_viewport().set_input_as_handled()

# ---------- игрок и враги ----------

func _spawn_player(pos: Vector3, yaw: float) -> void:
	player = preload("res://scripts/player.gd").new()
	player.main = self
	add_child(player)
	player.global_position = pos
	player.rotation.y = yaw

func spawn_gunner(pos: Vector3) -> void:
	var e = preload("res://scripts/enemy.gd").new()
	e.kind = "gunner"
	e.main = self
	add_child(e)
	e.global_position = pos

func spawn_crawler(pos: Vector3) -> void:
	var e = preload("res://scripts/enemy.gd").new()
	e.kind = "crawler"
	e.main = self
	add_child(e)
	e.global_position = pos

# ---------- уровень ----------

func _build_level() -> void:
	# спавн-комната
	room(0, 6, 8, 8, 3.4, {"n": {"w": 2.4, "h": 2.8}, "wall": "metal", "floor": "floor"})
	fluor(Vector3(0, 3.15, 6), 2.0, "x", 0.0, 2.4, true)
	sign_plate(Vector3(0, 2.5, 9.7), "ГОРИЗОНТ 3 · ЦЕХА", PI)
	label3d(Vector3(-3.5, 1.5, 9.55), "ТУТ БЫЛ СЛАВИК", PI, 30, Color(0.35, 0.48, 0.62))

	# коридор
	room(0, -3, 4.4, 12, 3.0, {"n": {"w": 2.8, "h": 2.7}, "s": {"w": 2.4, "h": 2.8}, "wall": "wallstripe"})
	fluor(Vector3(0, 2.8, 0), 1.6, "x", 0.0, 2.0)
	fluor(Vector3(0, 2.8, -6), 1.6, "x", 8.0, 2.0)
	pipe(Vector3(1.95, 2.5, 3), Vector3(1.95, 2.5, -9))
	pipe(Vector3(1.8, 2.3, 3), Vector3(1.8, 2.3, -9))
	label3d(Vector3(-2.35, 1.4, -5), "НОРМУ В ЖОПУ", PI / 2, 40, Color(0.62, 0.2, 0.16))
	label3d(Vector3(2.35, 1.9, -1), "МАРМОН-ПИДОР", -PI / 2, 34, Color(0.2, 0.28, 0.36))

	# цех
	room(0, -19, 22, 18, 5.2, {"s": {"w": 2.8, "h": 2.7}, "n": {"w": 2.4, "h": 2.8}, "wall": "concrete", "floor": "floor"})
	fluor(Vector3(-6, 4.9, -15), 2.6, "x", 0.0, 2.6, true)
	fluor(Vector3(6, 4.9, -15), 2.6, "x", 5.0, 2.6)
	fluor(Vector3(-6, 4.9, -24), 2.6, "x", 9.0, 2.6)
	fluor(Vector3(6, 4.9, -24), 2.6, "x", 0.0, 2.6, true)
	machine(-6, -14)
	machine(-6, -22)
	machine(6, -14)
	machine(6, -22)
	crate(0, -13)
	crate(-1.5, -13)
	crate(-0.7, -12)
	crate(3, -25)
	barrel_dyn(9.5, -26)
	barrel_dyn(10.2, -25)
	barrel_dyn(8.8, -24.6)
	crate_dyn(-3, -20)
	crate_dyn(-2.4, -19.2)
	sign_plate(Vector3(0, 4.4, -27.7), "ЦЕХ СБОРКИ №1", 0, 3.2)
	label3d(Vector3(-10.7, 2.0, -19), "ХУЙ", PI / 2, 84, Color(0.72, 0.24, 0.2), 12)
	label3d(Vector3(10.7, 1.7, -21), "ОНИ В СТЕНАХ", -PI / 2, 38, Color(0.16, 0.22, 0.28))
	label3d(Vector3(6.2, 2.6, -27.7), "МАРМОН-ПИДОР", 0, 30, Color(0.6, 0.22, 0.18))
	item(Vector3(2, 0.45, -17), "ak")
	item(Vector3(3, 0.45, -17.6), "ammo_ak", 30)
	item(Vector3(-6, 2.6, -22), "medkit", 30)
	item(Vector3(9.8, 0.45, -13), "sg")
	item(Vector3(10.4, 0.45, -13.8), "ammo_sg", 8)
	item(Vector3(-8.5, 0.45, -25.5), "mosin")
	item(Vector3(-9.2, 0.45, -25), "ammo_mosin", 10)
	note(Vector3(1.2, 0.5, -17.8), "Рапорт. Пост 2-Б.\nОни приходят на свет и на звук. Если лампа мигает —\nне стой под ней. Гаси фонарь, когда слышишь шаги.\nАвтомат забери. Мне уже не надо.")
	red_lamp(Vector3(0, 4.8, -27), 1.4)

	# выход
	room(0, -32.5, 5, 7, 3.0, {"s": {"w": 2.4, "h": 2.8}, "wall": "metal"})
	sign_plate(Vector3(0, 2.4, -35.6), "ПРОДОЛЖЕНИЕ СЛЕДУЕТ", 0, 3.0)
	red_lamp(Vector3(2, 2.7, -34), 1.2)

	# враги и сценарий
	spawn_gunner(Vector3(-6, 0.5, -20))
	spawn_gunner(Vector3(7, 0.5, -16))
	trigger(Vector3(0, 1.5, -8), Vector3(4, 3, 3), func():
		say("РАЦИЯ · НЕИЗВЕСТНЫЙ", "Тук-тук. Это я. В цеху двое бывших. Они всё ещё держат смену. Не дай им сдать её тебе.", 7.0)
	)
	trigger(Vector3(0, 1.5, -12.5), Vector3(6, 3, 2), func():
		spawn_crawler(Vector3(0, 0.4, -26))
		snd("creature", Vector3(0, 1, -26))
	)
	trigger(Vector3(0, 1.5, -33.5), Vector3(4, 3, 3), func():
		say("РАЦИЯ · НЕИЗВЕСТНЫЙ", "Дальше опечатано до следующей сборки. Но ты уже понял, каким это будет.", 6.0)
		set_objective("срез пройден")
		get_tree().create_timer(6.0).timeout.connect(func():
			started = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			menu_panel.visible = true
		)
	)
