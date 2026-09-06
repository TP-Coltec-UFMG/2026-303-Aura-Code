extends Node2D

@export var save_id: String = "extintor"
var no_inventario: bool = false

@onready var ligando: AudioStreamPlayer2D = $ligando
@onready var sfx_fumaca: AudioStreamPlayer2D = $sfx_fumaca
@onready var fumaca: GPUParticles2D = $Fumaca/fumaca
@onready var area_fumaca: Area2D = $Fumaca/fumaca/AreaFumaca
@onready var combustive: ProgressBar = $Combustive
@onready var indicador: Line2D = $Line2D
@onready var indicador_luz: PointLight2D = $Line2D/PointLight2D

const DURACAO_INDICADOR: float = 10.0
var _indicador_tween: Tween
var _indicador_timer: Timer
var _indicador_energia: float = 1.0

var player: Player = null
var material_fumaca: ParticleProcessMaterial = null
var extintor_ligado: bool = false
var no_chao: bool = true
var combustivel: float = 100
var consumo_combustivel: float = 20
var combustivel_acabou: bool = false
var fogos_em_extincao: Array[Node] = []
var ultima_animacao: StringName = &""
var ultimo_frame: int = -1
var ultima_direcao: Vector2 = Vector2.ZERO
var offset_fumaca: Vector2 = Vector2.ZERO
var angulo_base_fumaca: float = 0.0
var angulo_final_fumaca: float = 0.0
var ultimo_valor_combustivel: int = -1
var ultimo_angulo_material: float = INF

const FORCA_FUMACA: float = 1000.0
const LIMITE_EXTINTOR: float = 45.0
const MAX_PARTICULAS_FUMACA: int = 50
const FPS_PARTICULAS: int = 30

func _ready() -> void:
	_indicador_energia = indicador_luz.energy
	indicador.hide()
	indicador_luz.hide()
	_indicador_timer = Timer.new()
	_indicador_timer.one_shot = true
	_indicador_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	_indicador_timer.timeout.connect(_liberar_indicador)
	add_child(_indicador_timer)
	call_deferred("_conectar_indicador")

	if not no_inventario:
		if SaveGame.is_object_collected(save_id):
			queue_free()
			return

	fumaca.emitting = false
	area_fumaca.monitoring = false
	combustive.min_value = 0.0
	combustive.max_value = 100.0
	combustive.value = combustivel

	configurar_particulas()
	set_physics_process(false)


func _conectar_indicador() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var quest := get_tree().current_scene.get_node_or_null("QuestController")
	if quest == null or not quest.has_signal("pensamento_extintor_iniciado"):
		return
	if not quest.pensamento_extintor_iniciado.is_connected(_iniciar_indicador):
		quest.pensamento_extintor_iniciado.connect(_iniciar_indicador)
	if quest.orientar_extintor:
		_iniciar_indicador()


func _iniciar_indicador() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not _indicador_timer.is_stopped():
		return
	indicador.show()
	indicador_luz.show()
	_indicador_timer.start(DURACAO_INDICADOR)
	_indicador_tween = create_tween().set_loops()
	_indicador_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_indicador_tween.tween_property(indicador, "self_modulate:a", 0.2, 0.5)
	_indicador_tween.parallel().tween_property(indicador_luz, "energy", _indicador_energia * 0.2, 0.5)
	_indicador_tween.tween_property(indicador, "self_modulate:a", 1.0, 0.5)
	_indicador_tween.parallel().tween_property(indicador_luz, "energy", _indicador_energia, 0.5)


func _liberar_indicador() -> void:
	if _indicador_tween != null and _indicador_tween.is_valid():
		_indicador_tween.kill()
	_indicador_tween = null
	indicador.queue_free()
	indicador_luz.queue_free()


func _exit_tree() -> void:
	if is_instance_valid(_indicador_tween) and _indicador_tween.is_valid():
		_indicador_tween.kill()

func configurar_particulas() -> void:
	if fumaca.process_material is ParticleProcessMaterial:
		ultimo_angulo_material = INF
		material_fumaca = fumaca.process_material.duplicate() as ParticleProcessMaterial
		fumaca.process_material = material_fumaca

func foi_coletado() -> void:
	SaveGame.set_object_collected(save_id)

func marcar_como_item_inventario() -> void:
	no_inventario = true

func _physics_process(delta: float) -> void:
	if not extintor_ligado:
		return

	if player == null:
		set_fumaca(false)
		return

	atualizar_posicao()
	atualizar_combustivel(delta)

func atualizar_posicao() -> void:
	if player == null:
		return

	var animation: StringName = player.animation_player.current_animation
	var animation_frame: int = player.sprite.frame
	var direcao: Vector2 = player.cardinal_direction

	if (animation != ultima_animacao or animation_frame != ultimo_frame or direcao != ultima_direcao):
		atualizar_configuracao_fumaca(animation, animation_frame, direcao)
		ultima_animacao = animation
		ultimo_frame = animation_frame
		ultima_direcao = direcao

	fumaca.global_position = player.global_position + offset_fumaca
	atualizar_angulo_mouse()

func atualizar_angulo_mouse() -> void:
	if player == null:
		return

	var mouse_pos: Vector2 = get_global_mouse_position()
	var direcao_mouse: Vector2 = mouse_pos - fumaca.global_position

	if direcao_mouse.length_squared() < 0.001:
		angulo_final_fumaca = angulo_base_fumaca
		aplicar_direcao_fumaca()
		return

	var angulo_mouse: float = rad_to_deg(direcao_mouse.angle())
	var diferenca: float = wrapf(angulo_mouse - angulo_base_fumaca, -180.0, 180.0)

	diferenca = clampf(diferenca, -LIMITE_EXTINTOR, LIMITE_EXTINTOR)

	angulo_final_fumaca = angulo_base_fumaca + diferenca
	aplicar_direcao_fumaca()

func aplicar_direcao_fumaca() -> void:
	fumaca.rotation_degrees = angulo_final_fumaca

	if material_fumaca == null:
		return

	# O material é exclusivo deste extintor; a gravidade só muda com a mira.
	if angulo_final_fumaca == ultimo_angulo_material:
		return
	ultimo_angulo_material = angulo_final_fumaca

	var angulo_rad: float = deg_to_rad(angulo_final_fumaca)
	var direcao_jato: Vector2 = Vector2.RIGHT.rotated(angulo_rad)

	material_fumaca.gravity = Vector3(direcao_jato.x * FORCA_FUMACA, direcao_jato.y * FORCA_FUMACA, 0.0)

func atualizar_combustivel(delta: float) -> void:
	combustivel -= consumo_combustivel * delta

	if combustivel < 0.0:
		combustivel = 0.0

	var valor_combustivel: int = int(ceilf(combustivel))

	if valor_combustivel != ultimo_valor_combustivel:
		ultimo_valor_combustivel = valor_combustivel
		combustive.value = combustivel

	if combustivel <= 0.0:
		combustivel = 0.0
		combustive.value = 0.0
		combustivel_acabou = true
		set_fumaca(false)

func set_player(novo_player: Player) -> void:
	player = novo_player
	no_chao = false

func set_fumaca(ligada: bool) -> void:
	if ligada:
		if player == null:
			return

		if not player.usando_extintor:
			return

		if combustivel_acabou:
			return

		if extintor_ligado:
			return
	else:
		if not extintor_ligado:
			return

	extintor_ligado = ligada

	if ligada:
		ultima_animacao = &""
		ultimo_frame = -1
		ultima_direcao = Vector2.ZERO

		atualizar_posicao()

		fumaca.emitting = true
		area_fumaca.monitoring = true
		combustive.show()
		set_physics_process(true)

		if not sfx_fumaca.playing:
			sfx_fumaca.play()
	else:
		parar_extincao_dos_fogos()
		area_fumaca.monitoring = false
		fumaca.emitting = false
		combustive.hide()
		set_physics_process(false)
		sfx_fumaca.stop()

func parar_extincao_dos_fogos() -> void:
	for fogo in fogos_em_extincao:
		if not is_instance_valid(fogo):
			continue

		if fogo.has_method("parar_extincao"):
			fogo.parar_extincao()

	fogos_em_extincao.clear()

func atualizar_configuracao_fumaca(animation: StringName, animation_frame: int, direcao: Vector2) -> void:
	match animation:
		&"walk_down":
			offset_fumaca = Vector2(6.0, 4.0)
			fumaca.z_index = 0
			angulo_base_fumaca = 90.0

			match animation_frame:
				66:
					offset_fumaca = Vector2(5.0, 5.0)
				67:
					offset_fumaca = Vector2(4.0, 6.0)
				68:
					offset_fumaca = Vector2(4.5, 6.5)
				69, 70:
					offset_fumaca = Vector2(7.0, 2.0)

		&"idle_down":
			offset_fumaca = Vector2(5.0, 2.0)
			fumaca.z_index = 0
			angulo_base_fumaca = 90.0

			if animation_frame == 45:
				offset_fumaca = Vector2(5.0, 1.0)

		&"walk_up":
			offset_fumaca = Vector2(-6.0, -14.0)
			fumaca.z_index = 3
			angulo_base_fumaca = 270.0

			match animation_frame:
				54:
					offset_fumaca = Vector2(-6.0, -16.0)
				55:
					offset_fumaca = Vector2(-6.0, -17.0)
				56:
					offset_fumaca = Vector2(-6.0, -15.0)
				57, 58:
					offset_fumaca = Vector2(-7.0, -15.0)

		&"idle_up":
			offset_fumaca = Vector2(-6.0, -14.0)
			fumaca.z_index = 3
			angulo_base_fumaca = 270.0

			if animation_frame == 33:
				offset_fumaca = Vector2(-6.0, -15.0)

		&"walk_side":
			offset_fumaca = Vector2(-9.0 if direcao == Vector2.LEFT else 9.0, -2.0)

			if direcao == Vector2.LEFT:
				angulo_base_fumaca = 180.0
			else:
				angulo_base_fumaca = 0.0

			match animation_frame:
				48:
					offset_fumaca = Vector2(-10.5 if direcao == Vector2.LEFT else 10.5, -5.0)
				49:
					offset_fumaca = Vector2(-10.5 if direcao == Vector2.LEFT else 10.5, -4.5)
				50:
					offset_fumaca = Vector2(-9.0 if direcao == Vector2.LEFT else 9.0, -4.0)
				51:
					offset_fumaca = Vector2(-9.5 if direcao == Vector2.LEFT else 9.5, -4.5)
				52:
					offset_fumaca = Vector2(-12.0 if direcao == Vector2.LEFT else 12.0, -6.0)
				53:
					offset_fumaca = Vector2(-9.0 if direcao == Vector2.LEFT else 9.0, -4.0)

		&"idle_side":
			offset_fumaca = Vector2(-9.0 if direcao == Vector2.LEFT else 9.0, -2.0)

			if direcao == Vector2.LEFT:
				angulo_base_fumaca = 180.0
			else:
				angulo_base_fumaca = 0.0

			if animation_frame == 27:
				offset_fumaca = Vector2(-9.0 if direcao == Vector2.LEFT else 9.0, -3.0)

func _on_area_fumaca_area_entered(area: Area2D) -> void:
	var fogo: Node = area.get_parent()

	if not fogo.has_method("iniciar_extincao"):
		return

	if fogo in fogos_em_extincao:
		return

	fogos_em_extincao.append(fogo)
	fogo.iniciar_extincao()

func _on_area_fumaca_area_exited(area: Area2D) -> void:
	var fogo: Node = area.get_parent()
	var index: int = fogos_em_extincao.find(fogo)

	if index == -1:
		return

	fogos_em_extincao.remove_at(index)

	if not is_instance_valid(fogo):
		return

	if fogo.has_method("parar_extincao"):
		fogo.parar_extincao()

func _input(event: InputEvent) -> void:
	if player == null:
		return

	if not player.usando_extintor:
		return

	if (event.is_action_pressed("usar_extintor") and not combustivel_acabou):
		if not extintor_ligado:
			ligando.play()

		set_fumaca(true)

	if event.is_action_released("usar_extintor"):
		set_fumaca(false)

		if combustivel_acabou:
			player.reset_sprite_player()
			player.inventory.remove_item("extintor")
			queue_free()
