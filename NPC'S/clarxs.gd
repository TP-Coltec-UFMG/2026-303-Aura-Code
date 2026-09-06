extends Node2D

signal npc_saiu
signal path_completed(path: NPCPath)


@export_category("NPC")

@export var sprite_sheet: Texture2D
@export var dialog_texts: Array[String] = []
@export var dialog_enabled: bool = true
@export var dialog_id: String = ""
@export var save_enabled: bool = true
## Vazio usa o caminho na cena. Defina um ID estável para NPCs gerados por código.
@export var save_id: String = ""

var checkpoint_restored: bool = false


@export_category("NPC Movement")

@export var walk_speed: float = 30.0
@export var run_speed: float = 60.0

@export var walk_animation_speed: float = 8.0
@export var run_animation_speed: float = 14.0


@export_category("Desespero")

@export var desperate_radius: float = 2
@export var desperate_min_distance: float = 1.5

@export var desperate_min_wait: float = 0.05
@export var desperate_max_wait: float = 2

@export_range(0.0, 1.0) var desperate_run_chance: float = 0.9


const SHEET_COLUMNS := 24
const SHEET_ROWS := 7

const IDLE_SIDE_FRAME := 1
const IDLE_UP_FRAME := 2
const IDLE_DOWN_FRAME := 4

const SIDE_START_FRAME := 49
const UP_START_FRAME := 55
const DOWN_START_FRAME := 67

const MOVEMENT_FRAME_COUNT := 6


var current_path: NPCPath = null

var path_points: Array[Vector2] = []
var cached_path_points: Dictionary = {}

var current_point: int = -1
var path_finished: bool = true


var player_in_range: bool = false
var player_ref: Node2D = null

var last_direction: Vector2 = Vector2.DOWN


var desperate: bool = false

var desperate_origin: Vector2 = Vector2.ZERO
var desperate_target: Vector2 = Vector2.ZERO

var desperate_wait_timer: float = 0.0

var desperate_movement_type: int = NPCPath.MovementType.RUN


var rng := RandomNumberGenerator.new()


@onready var interaction_icon: Label = $InteractionPrompt
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	rng.randomize()
	interaction_icon.visible = false
	setup_sprite_sheet()
	setup_paths()
	if save_enabled:
		checkpoint_restored = SaveGame.register_checkpoint_actor(self, save_id)


func setup_paths() -> void:
	cached_path_points.clear()

	var automatic_path: NPCPath = null

	for child in get_children():
		if child is NPCPath:
			var path: NPCPath = child

			path.start_requested.connect(
				_on_path_start_requested
			)

			var points: Array[Vector2] = []

			for point in path.points:
				var global_point: Vector2 = path.to_global(point)

				points.append(global_point)

			cached_path_points[path] = points

			if path.start_automatically:
				if automatic_path == null:
					automatic_path = path
				else:
					push_warning("Mais de um caminho está com Start Automatically ativado.")

	if automatic_path != null:
		start_path(automatic_path)
	else:
		path_finished = true
		play_idle(last_direction)


func _on_path_start_requested(path: NPCPath) -> void:
	start_path(path)


func start_path(path: NPCPath) -> void:
	if path == null:
		return

	if not cached_path_points.has(path):
		push_warning(
			"O caminho '%s' não pertence a este NPC."
			% path.name
		)

		return

	desperate = false
	desperate_wait_timer = 0.0

	current_path = path

	path_finished = false
	current_point = 0

	path_points.clear()

	for point in cached_path_points[path]:
		path_points.append(point)

	if path_points.is_empty():
		current_path = null

		current_point = -1
		path_finished = true

		play_idle(last_direction)


func stop_current_path() -> void:
	current_path = null

	path_points.clear()

	current_point = -1
	path_finished = true

	desperate = false
	desperate_wait_timer = 0.0

	play_idle(last_direction)


func setup_sprite_sheet() -> void:
	if sprite_sheet == null:
		push_warning(
			"Nenhuma Sprite Sheet foi colocada no NPC."
		)

		return

	var texture_width: int = sprite_sheet.get_width()
	var texture_height: int = sprite_sheet.get_height()

	if texture_width % SHEET_COLUMNS != 0:
		push_warning(
			"A largura da Sprite Sheet não é divisível por 24."
		)

	if texture_height % SHEET_ROWS != 0:
		push_warning(
			"A altura da Sprite Sheet não é divisível por 7."
		)

	@warning_ignore("integer_division")
	var frame_width: int = texture_width / SHEET_COLUMNS

	@warning_ignore("integer_division")
	var frame_height: int = texture_height / SHEET_ROWS

	var frames := SpriteFrames.new()

	frames.remove_animation("default")

	create_animation_from_frames(
		frames,
		"idle_side",
		IDLE_SIDE_FRAME,
		1,
		frame_width,
		frame_height,
		1.0,
		false
	)

	create_animation_from_frames(
		frames,
		"idle_up",
		IDLE_UP_FRAME,
		1,
		frame_width,
		frame_height,
		1.0,
		false
	)

	create_animation_from_frames(
		frames,
		"idle_down",
		IDLE_DOWN_FRAME,
		1,
		frame_width,
		frame_height,
		1.0,
		false
	)

	create_animation_from_frames(
		frames,
		"walk_side",
		SIDE_START_FRAME,
		MOVEMENT_FRAME_COUNT,
		frame_width,
		frame_height,
		walk_animation_speed,
		true
	)

	create_animation_from_frames(
		frames,
		"walk_up",
		UP_START_FRAME,
		MOVEMENT_FRAME_COUNT,
		frame_width,
		frame_height,
		walk_animation_speed,
		true
	)

	create_animation_from_frames(
		frames,
		"walk_down",
		DOWN_START_FRAME,
		MOVEMENT_FRAME_COUNT,
		frame_width,
		frame_height,
		walk_animation_speed,
		true
	)

	create_animation_from_frames(
		frames,
		"run_side",
		SIDE_START_FRAME,
		MOVEMENT_FRAME_COUNT,
		frame_width,
		frame_height,
		run_animation_speed,
		true
	)

	create_animation_from_frames(
		frames,
		"run_up",
		UP_START_FRAME,
		MOVEMENT_FRAME_COUNT,
		frame_width,
		frame_height,
		run_animation_speed,
		true
	)

	create_animation_from_frames(
		frames,
		"run_down",
		DOWN_START_FRAME,
		MOVEMENT_FRAME_COUNT,
		frame_width,
		frame_height,
		run_animation_speed,
		true
	)

	sprite.sprite_frames = frames

	sprite.play("idle_down")


func create_animation_from_frames(
	frames: SpriteFrames,
	animation_name: StringName,
	start_frame: int,
	frame_count: int,
	frame_width: int,
	frame_height: int,
	fps: float,
	loop: bool
) -> void:
	frames.add_animation(animation_name)

	frames.set_animation_speed(
		animation_name,
		fps
	)

	frames.set_animation_loop(
		animation_name,
		loop
	)

	for i in range(frame_count):
		var frame_number: int = start_frame + i

		add_frame_to_animation(
			frames,
			animation_name,
			frame_number,
			frame_width,
			frame_height
		)


func add_frame_to_animation(
	frames: SpriteFrames,
	animation_name: StringName,
	frame_number: int,
	frame_width: int,
	frame_height: int
) -> void:
	var frame_index: int = frame_number - 1

	var column: int = frame_index % SHEET_COLUMNS

	@warning_ignore("integer_division")
	var row: int = frame_index / SHEET_COLUMNS

	var atlas := AtlasTexture.new()

	atlas.atlas = sprite_sheet

	atlas.region = Rect2(
		column * frame_width,
		row * frame_height,
		frame_width,
		frame_height
	)

	frames.add_frame(
		animation_name,
		atlas
	)


func _process(delta: float) -> void:
	_update_interaction_prompt()

	if desperate:
		update_desperate_movement(delta)
		return

	if current_path != null and not path_finished:
		update_movement(delta)
		return

	if player_in_range and player_ref:
		update_direction()
		return


func update_movement(delta: float) -> void:
	if current_path == null:
		return

	if path_finished:
		return

	if path_points.is_empty():
		return

	if current_point < 0:
		return

	if current_point >= path_points.size():
		return

	var target: Vector2 = path_points[current_point]

	var speed: float = walk_speed

	if current_path.movement_type == NPCPath.MovementType.RUN:
		speed = run_speed

	var direction: Vector2 = global_position.direction_to(
		target
	)

	if direction != Vector2.ZERO:
		last_direction = direction

	global_position = global_position.move_toward(
		target,
		speed * delta
	)

	update_movement_animation(
		direction,
		current_path.movement_type
	)

	if global_position.distance_to(target) < 1.0:
		global_position = target

		go_to_next_path_point()


func go_to_next_path_point() -> void:
	current_point += 1

	if current_point < path_points.size():
		return

	if current_path == null:
		return

	var finished_path: NPCPath = current_path

	if finished_path.delete_npc_at_end:
		path_completed.emit(finished_path)
		if save_enabled:
			SaveGame.mark_checkpoint_actor_removed(self)
		npc_saiu.emit()
		queue_free()
		return

	if finished_path.loop_path:
		current_point = 0
		path_completed.emit(finished_path)
		return

	if finished_path.random_at_end:
		start_desperate_mode()
		path_completed.emit(finished_path)
		return

	path_finished = true
	current_point = -1

	play_idle(last_direction)
	path_completed.emit(finished_path)


func start_desperate_mode() -> void:
	path_finished = true
	current_point = -1

	desperate = true

	desperate_origin = global_position

	desperate_wait_timer = 0.0

	choose_random_desperate_target()


func choose_random_desperate_target() -> void:
	var random_angle: float = rng.randf_range(
		0.0,
		TAU
	)

	var min_distance: float = min(
		desperate_min_distance,
		desperate_radius
	)

	var max_distance: float = max(
		desperate_min_distance,
		desperate_radius
	)

	var random_distance: float = rng.randf_range(
		min_distance,
		max_distance
	)

	var offset: Vector2 = Vector2.RIGHT.rotated(
		random_angle
	) * random_distance

	desperate_target = desperate_origin + offset

	if rng.randf() <= desperate_run_chance:
		desperate_movement_type = NPCPath.MovementType.RUN
	else:
		desperate_movement_type = NPCPath.MovementType.WALK


func update_desperate_movement(
	delta: float
) -> void:
	if desperate_wait_timer > 0.0:
		desperate_wait_timer -= delta

		play_idle(last_direction)

		return

	var direction: Vector2 = global_position.direction_to(
		desperate_target
	)

	if direction != Vector2.ZERO:
		last_direction = direction

	var speed: float = walk_speed

	if desperate_movement_type == NPCPath.MovementType.RUN:
		speed = run_speed

	global_position = global_position.move_toward(
		desperate_target,
		speed * delta
	)

	update_movement_animation(
		direction,
		desperate_movement_type
	)

	if global_position.distance_to(
		desperate_target
	) < 0.2:
		global_position = desperate_target

		desperate_wait_timer = rng.randf_range(
			desperate_min_wait,
			desperate_max_wait
		)

		choose_random_desperate_target()


func update_movement_animation(
	direction: Vector2,
	movement_kind: int
) -> void:
	if direction == Vector2.ZERO:
		play_idle(last_direction)
		return

	var animation_prefix := "walk"

	if movement_kind == NPCPath.MovementType.RUN:
		animation_prefix = "run"

	if abs(direction.x) > abs(direction.y):
		sprite.play(
			animation_prefix + "_side"
		)

		if direction.x > 0:
			sprite.flip_h = false
		else:
			sprite.flip_h = true

	else:
		sprite.flip_h = false

		if direction.y > 0:
			sprite.play(
				animation_prefix + "_down"
			)

		else:
			sprite.play(
				animation_prefix + "_up"
			)


func play_idle(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		sprite.play("idle_side")

		if direction.x > 0:
			sprite.flip_h = false
		else:
			sprite.flip_h = true

	else:
		sprite.flip_h = false

		if direction.y > 0:
			sprite.play("idle_down")
		else:
			sprite.play("idle_up")


func _unhandled_input(
	event: InputEvent
) -> void:
	if (
		has_dialog()
		and player_in_range
		and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"))
		and not DialogManager.is_showing_dialog
	):
		DialogManager.start_dialog(
			dialog_texts,
			dialog_id
		)
		get_viewport().set_input_as_handled()


func _on_area_2d_body_entered(body) -> void:
	if body is Player:
		player_in_range = true

		player_ref = body

		interaction_icon.visible = has_dialog()


func _on_area_2d_body_exited(body) -> void:
	if body is Player:
		player_in_range = false

		player_ref = null

		interaction_icon.visible = false


func set_dialog_enabled(value: bool) -> void:
	dialog_enabled = value
	interaction_icon.visible = has_dialog() and player_in_range


func has_dialog() -> bool:
	return dialog_enabled and not dialog_texts.is_empty()


func _update_interaction_prompt() -> void:
	interaction_icon.visible = (
		has_dialog()
		and player_in_range
		and not DialogManager.is_showing_dialog
	)


func update_direction() -> void:
	if player_ref == null:
		return

	var dir: Vector2 = (
		player_ref.global_position
		- global_position
	)

	if dir == Vector2.ZERO:
		return

	last_direction = dir

	play_idle(dir)


func get_checkpoint_state() -> Dictionary:
	var paths: Dictionary = {}
	for path: NPCPath in cached_path_points:
		paths[str(get_path_to(path))] = PackedVector2Array(cached_path_points[path])
	return {
		"version": 1,
		"position": global_position,
		"current_path": str(get_path_to(current_path)) if current_path != null else "",
		"current_point": current_point,
		"path_finished": path_finished,
		"path_points": PackedVector2Array(path_points),
		"cached_paths": paths,
		"last_direction": last_direction,
		"desperate": desperate,
		"desperate_origin": desperate_origin,
		"desperate_target": desperate_target,
		"desperate_wait_timer": desperate_wait_timer,
		"desperate_movement_type": desperate_movement_type,
		"rng_seed": rng.seed,
		"rng_state": rng.state,
		"animation": sprite.animation,
		"frame": sprite.frame,
		"frame_progress": sprite.frame_progress,
		"animation_playing": sprite.is_playing(),
		"animation_speed": sprite.speed_scale,
		"flip_h": sprite.flip_h
	}


func load_checkpoint_state(saved: Dictionary) -> void:
	if saved.get("version", 0) != 1 or not saved.get("position") is Vector2:
		push_warning("Estado de NPC incompatível: " + str(name))
		return
	global_position = saved["position"]
	last_direction = saved.get("last_direction", Vector2.DOWN)
	# Os pontos são globais: nunca recalcular a rota a partir da posição restaurada.
	var paths: Variant = saved.get("cached_paths", {})
	if paths is Dictionary:
		for path_id in paths:
			var path := get_node_or_null(NodePath(str(path_id))) as NPCPath
			if path != null and cached_path_points.has(path) and paths[path_id] is PackedVector2Array:
				var points: Array[Vector2] = []
				points.assign(paths[path_id])
				cached_path_points[path] = points
	current_path = null
	path_points.clear()
	var active_path: String = str(saved.get("current_path", ""))
	if not active_path.is_empty():
		current_path = get_node_or_null(NodePath(active_path)) as NPCPath
		if not cached_path_points.has(current_path):
			current_path = null
	if current_path != null:
		var points: Variant = saved.get("path_points")
		if points is PackedVector2Array:
			path_points.assign(points)
		else:
			path_points.assign(cached_path_points[current_path])
	current_point = int(saved.get("current_point", -1))
	path_finished = bool(saved.get("path_finished", true))
	desperate = bool(saved.get("desperate", false))
	desperate_origin = saved.get("desperate_origin", global_position)
	desperate_target = saved.get("desperate_target", global_position)
	desperate_wait_timer = float(saved.get("desperate_wait_timer", 0.0))
	desperate_movement_type = int(saved.get("desperate_movement_type", NPCPath.MovementType.RUN))
	if not desperate and not path_finished and (current_path == null or current_point < 0 or current_point >= path_points.size()):
		# Uma rota removida numa edição futura não deve reiniciar toda a sequência.
		push_warning("Rota salva indisponível; NPC permanece na posição salva: " + str(name))
		stop_current_path()
	if saved.has("rng_seed"):
		rng.seed = int(saved["rng_seed"])
	if saved.has("rng_state"):
		rng.state = int(saved["rng_state"])
	# Referências ao jogador são reconstruídas pelos sinais de proximidade.
	player_in_range = false
	player_ref = null
	interaction_icon.hide()
	var animation: StringName = saved.get("animation", &"idle_down")
	if sprite.sprite_frames.has_animation(animation):
		sprite.play(animation)
		sprite.speed_scale = float(saved.get("animation_speed", 1.0))
		sprite.set_frame_and_progress(int(saved.get("frame", 0)), float(saved.get("frame_progress", 0.0)))
		sprite.flip_h = bool(saved.get("flip_h", false))
		if not saved.get("animation_playing", true):
			sprite.pause()
