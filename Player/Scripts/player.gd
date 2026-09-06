class_name Player extends CharacterBody2D


# Cenas isoladas como o tutorial usam o mesmo Player e a mesma física sem
# sobrescrever o checkpoint da campanha.
@export var checkpoint_enabled: bool = true


@onready var camera_2d: Camera2D = $Camera2D
@onready var sfx_walking: AudioStreamPlayer2D = $sfx_walking
@onready var occluder_side: LightOccluder2D = $Sprite2D/OccluderSide
@onready var occluder_back: LightOccluder2D = $Sprite2D/OccluderBack
@onready var occluder_front: LightOccluder2D = $Sprite2D/OccluderFront
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D

@onready var inteligencia: TextureProgressBar = $CanvasLayer/Control/Inteligencia
@onready var vida_1: TextureProgressBar = $CanvasLayer/Control/Vida1
@onready var vida_2: TextureProgressBar = $CanvasLayer/Control/Vida2
@onready var vida_3: TextureProgressBar = $CanvasLayer/Control/Vida3
@onready var inventory: Inventory = $Inventory

@onready var grab_left: Area2D = $GrabLeft
@onready var grab_right: Area2D = $GrabRight


@onready var control: Control = $CanvasLayer/Control
@onready var morreu: Control = $CanvasLayer/Morreu

var cardinal_direction: Vector2 = Vector2.DOWN
var direction: Vector2 = Vector2.ZERO
var move_speed: float = 40.0
var state: String = "idle"

var andando_de_costas: bool = false

const MOUSE_DEAD_ZONE_SQUARED: float = 16.0

var usando_lanterna: bool = false
var usando_arma: bool = false
var usando_cartao: bool = false
var usando_laptop: bool = false
var usando_faca: bool = false
var usando_extintor: bool = false
var empurrando: bool = false

var objeto_manipulado: ObjetoEmpurravel = null
var lado_objeto_manipulado: Vector2 = Vector2.ZERO

var objetos_grab_left: Array[ObjetoEmpurravel] = []
var objetos_grab_right: Array[ObjetoEmpurravel] = []

var correndo: bool = false
var andando: bool = false
var cansaco: float = 0.0

const vida_total: float = 300.0

const VELOCIDADE_NORMAL: float = 40.0
const VELOCIDADE_CORRIDA: float = 80.0

const CONSUMO_CANSACO: float = 0.06
const RECUPERACAO_CANSACO: float = 0.05
@onready var balao_de_pensamento: Sprite2D = $BalaoDePensamento

signal jogador_morreu

func _ready() -> void:
	add_to_group("player")
	UpdateAnimation()
	UpdateOccluderLight()
	
func _mostrar_no_balao_de_pensamento(texto: String) -> void:
	await balao_de_pensamento.mostrar_texto(texto)

func get_checkpoint_state() -> Dictionary:
	return {
		"cansaco": cansaco,
		"cardinal_direction": cardinal_direction,
		"inteligencia": inteligencia.value,
		"vida_1": vida_1.value,
		"vida_2": vida_2.value,
		"vida_3": vida_3.value,
		"inventario": inventory.get_save_state(),
		"pensamentos": balao_de_pensamento.get_checkpoint_state()
	}

func load_checkpoint_state(checkpoint_state: Dictionary) -> void:
	cansaco = checkpoint_state.get(
		"cansaco",
		cansaco
	)

	cardinal_direction = checkpoint_state.get(
		"cardinal_direction",
		cardinal_direction
	)

	inteligencia.value = checkpoint_state.get(
		"inteligencia",
		inteligencia.value
	)

	vida_1.value = checkpoint_state.get(
		"vida_1",
		vida_1.value
	)

	vida_2.value = checkpoint_state.get(
		"vida_2",
		vida_2.value
	)

	vida_3.value = checkpoint_state.get(
		"vida_3",
		vida_3.value
	)

	var inventario_salvo: Variant = checkpoint_state.get(
		"inventario",
		{}
	)

	if inventario_salvo is Dictionary:
		inventory.load_save_state(inventario_salvo)

	var pensamentos_salvos: Variant = checkpoint_state.get("pensamentos", {})
	balao_de_pensamento.load_checkpoint_state(
		pensamentos_salvos if pensamentos_salvos is Dictionary else {}
	)

	# Estados transitórios não devem sobreviver ao respawn.
	direction = Vector2.ZERO
	velocity = Vector2.ZERO
	state = "idle"

	correndo = false
	andando = false
	andando_de_costas = false

	move_speed = VELOCIDADE_NORMAL

	usando_lanterna = false
	usando_arma = false
	usando_cartao = false
	usando_laptop = false
	usando_faca = false
	usando_extintor = false
	inventory.set_equipped_item("")

	empurrando = false
	objeto_manipulado = null
	lado_objeto_manipulado = Vector2.ZERO

	sprite.scale.x = -1 if cardinal_direction == Vector2.LEFT else 1
	occluder_side.scale.x = -1 if cardinal_direction == Vector2.LEFT else 1

	UpdateAnimation()
	UpdateOccluderLight()

func _physics_process(delta: float) -> void:
	if DialogManager.is_showing_dialog:
		direction = Vector2.ZERO
		velocity = Vector2.ZERO
		correndo = false
		move_speed = VELOCIDADE_NORMAL
		if state != "idle":
			state = "idle"
			UpdateAnimation()
		_update_walking_sfx()
		return

	direction = Input.get_vector("left", "right", "up", "down")
	
	if objeto_manipulado != null:
		direction.y = 0.0
		if not is_zero_approx(direction.x):
			direction.x = -1.0 if direction.x < 0.0 else 1.0
	
	var mudou_estado: bool = SetState()
	var mudou_direcao: bool = SetDirection()
	var mudou_sentido_animacao: bool = SetWalkingBackwards()
	var correndo_antes: bool = correndo
	var animacao_corrida_rapida_antes: bool = correndo and cansaco <= 0.5
	atualizar_corrida(delta)
	var animacao_corrida_rapida_agora: bool = correndo and cansaco <= 0.5
	velocity = direction * move_speed
	_update_walking_sfx()
	
	if mudou_estado or mudou_direcao or mudou_sentido_animacao or correndo != correndo_antes or animacao_corrida_rapida_antes != animacao_corrida_rapida_agora:
		UpdateAnimation()
	
	if mudou_direcao:
		UpdateOccluderLight()
		if empurrando and objeto_manipulado == null:
			tentar_pegar_objeto()
	
	if objeto_manipulado != null:
		_physics_manipulando(delta)
		return
		
	move_and_slide()

func atualizar_corrida(delta: float) -> void:
	if Input.is_action_pressed("correr") and state != "idle" and objeto_manipulado == null and cansaco < 1.0:
		correndo = true
		andando = false
		move_speed = VELOCIDADE_CORRIDA - float(int(40.0 * cansaco))
		cansaco += CONSUMO_CANSACO * delta
		cansaco = minf(cansaco, 1.0)
	else:
		correndo = false
		move_speed = VELOCIDADE_NORMAL
		var cansaco_minimo: float = 1.0 - (get_vida() / vida_total)
		if cansaco > cansaco_minimo:
			cansaco -= RECUPERACAO_CANSACO * delta
			cansaco = maxf(cansaco, cansaco_minimo)

func _update_walking_sfx() -> void:
	var esta_andando: bool = direction.length_squared() > 0.0
	
	if esta_andando:
		if not sfx_walking.playing:
			sfx_walking.play()
		var novo_pitch: float = 1.0
		if move_speed > VELOCIDADE_NORMAL:
			novo_pitch = lerpf(1.0, 1.8, clampf(move_speed / VELOCIDADE_CORRIDA, 0.0, 1.0))
		if not is_equal_approx(sfx_walking.pitch_scale, novo_pitch):
			sfx_walking.pitch_scale = novo_pitch
	else:
		if sfx_walking.playing:
			sfx_walking.stop()

func tentar_pegar_objeto() -> void:
	if objeto_manipulado != null:
		return
	if cardinal_direction == Vector2.LEFT:
		for i in range(objetos_grab_left.size() - 1, -1, -1):
			var objeto: ObjetoEmpurravel = objetos_grab_left[i]
			if not is_instance_valid(objeto):
				objetos_grab_left.remove_at(i)
				continue
			pegar_objeto(objeto, Vector2.LEFT)
			return
	elif cardinal_direction == Vector2.RIGHT:
		for i in range(objetos_grab_right.size() - 1, -1, -1):
			var objeto: ObjetoEmpurravel = objetos_grab_right[i]
			if not is_instance_valid(objeto):
				objetos_grab_right.remove_at(i)
				continue
			pegar_objeto(objeto, Vector2.RIGHT)
			return

func pegar_objeto(objeto: ObjetoEmpurravel, lado: Vector2) -> void:
	if objeto_manipulado != null:
		return
	
	if not is_instance_valid(objeto):
		return
	
	objeto_manipulado = objeto
	lado_objeto_manipulado = lado
	cardinal_direction = lado
	add_collision_exception_with(objeto_manipulado)
	objeto_manipulado.add_collision_exception_with(self)
	sprite.scale.x = -1 if cardinal_direction == Vector2.LEFT else 1
	occluder_side.scale.x = -1 if cardinal_direction == Vector2.LEFT else 1
	UpdateAnimation()
	UpdateOccluderLight()

func soltar_objeto() -> void:
	if objeto_manipulado != null and is_instance_valid(objeto_manipulado):
		remove_collision_exception_with(objeto_manipulado)
		objeto_manipulado.remove_collision_exception_with(self)

	if checkpoint_enabled:
		SaveGame.create_checkpoint(self)
	
	objeto_manipulado = null
	lado_objeto_manipulado = Vector2.ZERO

func _physics_manipulando(delta: float) -> void:
	if objeto_manipulado == null:
		return
	
	if not is_instance_valid(objeto_manipulado):
		soltar_objeto()
		return
	
	var movimento: Vector2 = Vector2(direction.x * move_speed * delta, 0.0)
	
	if is_zero_approx(movimento.x):
		return
	
	mover_com_objeto(movimento)

func mover_com_objeto(movimento: Vector2) -> void:
	if objeto_manipulado == null:
		return
	
	var player_bloqueado: bool = test_move(global_transform, movimento)
	var objeto_bloqueado: bool = objeto_manipulado.test_move(objeto_manipulado.global_transform, movimento)
	
	if not player_bloqueado and not objeto_bloqueado:
		move_and_collide(movimento)
		objeto_manipulado.move_and_collide(movimento)

func _on_grab_left_body_entered(body: Node2D) -> void:
	if not body is ObjetoEmpurravel:
		return
		
	var objeto: ObjetoEmpurravel = body as ObjetoEmpurravel
	
	if not objeto in objetos_grab_left:
		objetos_grab_left.append(objeto)
		
	if empurrando and objeto_manipulado == null and cardinal_direction == Vector2.LEFT:
		pegar_objeto(objeto, Vector2.LEFT)

func _on_grab_left_body_exited(body: Node2D) -> void:
	if not body is ObjetoEmpurravel:
		return
		
	var objeto: ObjetoEmpurravel = body as ObjetoEmpurravel
	
	if objeto in objetos_grab_left:
		objetos_grab_left.erase(objeto)

func _on_grab_right_body_entered(body: Node2D) -> void:
	if not body is ObjetoEmpurravel:
		return
		
	var objeto: ObjetoEmpurravel = body as ObjetoEmpurravel
	
	if not objeto in objetos_grab_right:
		objetos_grab_right.append(objeto)
		
	if empurrando and objeto_manipulado == null and cardinal_direction == Vector2.RIGHT:
		pegar_objeto(objeto, Vector2.RIGHT)

func _on_grab_right_body_exited(body: Node2D) -> void:
	if not body is ObjetoEmpurravel:
		return
		
	var objeto: ObjetoEmpurravel = body as ObjetoEmpurravel
	
	if objeto in objetos_grab_right:
		objetos_grab_right.erase(objeto)

func usando_item_com_mira() -> bool:
	return usando_lanterna or usando_arma or usando_extintor or usando_faca

func GetMouseCardinalDirection() -> Vector2:
	var mouse_offset: Vector2 = get_global_mouse_position() - global_position
	if mouse_offset.length_squared() < MOUSE_DEAD_ZONE_SQUARED:
		return cardinal_direction
	if abs(mouse_offset.x) > abs(mouse_offset.y):
		return Vector2.LEFT if mouse_offset.x < 0.0 else Vector2.RIGHT
	return Vector2.UP if mouse_offset.y < 0.0 else Vector2.DOWN

func SetDirection() -> bool:
	if objeto_manipulado != null:
		return false
		
	var new_direction: Vector2 = cardinal_direction
	
	if usando_item_com_mira():
		new_direction = GetMouseCardinalDirection()
	else:
		if direction == Vector2.ZERO:
			return false
		if direction.y == 0.0:
			new_direction = Vector2.LEFT if direction.x < 0.0 else Vector2.RIGHT
		elif direction.x == 0.0:
			new_direction = Vector2.UP if direction.y < 0.0 else Vector2.DOWN
	if new_direction == cardinal_direction:
		return false
		
	cardinal_direction = new_direction
	sprite.scale.x = -1 if cardinal_direction == Vector2.LEFT else 1
	occluder_side.scale.x = -1 if cardinal_direction == Vector2.LEFT else 1
	return true

func SetWalkingBackwards() -> bool:
	var novo_andando_de_costas: bool = false
	if usando_item_com_mira() and direction != Vector2.ZERO:
		var movimento_normalizado: Vector2 = direction.normalized()
		var alinhamento: float = movimento_normalizado.dot(cardinal_direction)
		novo_andando_de_costas = alinhamento < -0.01
	if novo_andando_de_costas == andando_de_costas:
		return false
	andando_de_costas = novo_andando_de_costas
	return true

func SetState() -> bool:
	var new_state: String = "idle" if direction == Vector2.ZERO else "walk"
	if new_state == state:
		return false
	state = new_state
	return true

func UpdateAnimation() -> void:
	var nova_animacao: String = state + "_" + AnimDirection()
	var nova_velocidade: float = 1.0
	
	if correndo and cansaco <= 0.5:
		nova_velocidade = 2.0
		
	if not is_equal_approx(animation_player.speed_scale, nova_velocidade):
		animation_player.speed_scale = nova_velocidade
		
	var mudou_animacao: bool = animation_player.current_animation != nova_animacao
	var esta_tocando_ao_contrario: bool = animation_player.get_playing_speed() < 0.0
	var mudou_sentido: bool = esta_tocando_ao_contrario != andando_de_costas
	
	if not mudou_animacao and not mudou_sentido:
		return
	if andando_de_costas:
		animation_player.play_backwards(nova_animacao)
	else:
		animation_player.play(nova_animacao)

func UpdateOccluderLight() -> void:
	var _direction: String = AnimDirection()
	occluder_front.visible = _direction == "down"
	occluder_back.visible = _direction == "up"
	occluder_side.visible = _direction == "side"

func AnimDirection() -> String:
	if cardinal_direction == Vector2.DOWN:
		return "down"
	elif cardinal_direction == Vector2.UP:
		return "up"
	else:
		return "side"

func reset_sprite_player() -> void:
	usando_lanterna = false
	var lanterna = inventory.get_item_control("lanterna")
	if lanterna != null:
		lanterna.set_luz(false)
	var extintor = inventory.get_item_control("extintor")
	if extintor != null:
		extintor.set_fumaca(false)
	usando_arma = false
	usando_cartao = false
	usando_laptop = false
	usando_faca = false
	usando_extintor = false
	inventory.set_equipped_item("")
	soltar_objeto()
	empurrando = false
	$Sprite2D.texture = preload("res://Player/Sprites/Alex_16x16.png")

func _input(event: InputEvent) -> void:
	if DialogManager.is_showing_dialog:
		return

	if event.is_action_pressed("use_lanterna") and inventory.get_item_on_inventary("lanterna"):
		var lanterna = inventory.get_item_control("lanterna")
		lanterna.set_player(self)
		if usando_lanterna:
			lanterna.set_luz(false)
			reset_sprite_player()
		else:
			reset_sprite_player()
			usando_lanterna = true
			inventory.set_equipped_item("lanterna")
			lanterna.set_luz(true)
			$Sprite2D.texture = preload("res://Player/Sprites/Alex_com_lanterna16x16.png")
			
			
	if event.is_action_pressed("use_arma") and inventory.get_item_on_inventary("gun"):
		var gun = inventory.get_item_control("gun")
		gun.set_player(self)
		if usando_arma:
			reset_sprite_player()
		else:
			reset_sprite_player()
			usando_arma = true
			inventory.set_equipped_item("gun")
			$Sprite2D.texture = preload("res://Player/Sprites/Alex_com_arma16x16.png")
			
			
	if event.is_action_pressed("use_extintor") and inventory.get_item_on_inventary("extintor"):
		var extintor = inventory.get_item_control("extintor")
		if usando_extintor:
			extintor.set_fumaca(false)
			reset_sprite_player()
		else:
			reset_sprite_player()
			extintor.set_player(self)
			usando_extintor = true
			inventory.set_equipped_item("extintor")
			extintor.set_fumaca(false)
			$Sprite2D.texture = preload("res://Player/Sprites/Alex_16x16_com_extintor.png")
			
			
	if event.is_action_pressed("use_cartao") and inventory.get_item_on_inventary("cartao"):
		var cartao = inventory.get_item_control("cartao")
		cartao.set_player(self)
		if usando_cartao:
			reset_sprite_player()
		else:
			reset_sprite_player()
			usando_cartao = true
			inventory.set_equipped_item("cartao")
			if cartao.tipo == 3:
				$Sprite2D.texture = preload("res://Player/Sprites/Alex_com_cartao_chefe16x16.png")
			elif cartao.tipo == 2:
				$Sprite2D.texture = preload("res://Player/Sprites/Alex_com_cartao_forte16x16.png")
			else:
				$Sprite2D.texture = preload("res://Player/Sprites/Alex_com_cartao_padrao16x16.png")
				
				
	if event.is_action_pressed("use_laptop") and inventory.get_item_on_inventary("laptop"):
		var laptop = inventory.get_item_control("laptop")
		laptop.set_player(self)
		if usando_laptop:
			reset_sprite_player()
		else:
			reset_sprite_player()
			usando_laptop = true
			inventory.set_equipped_item("laptop")
			$Sprite2D.texture = preload("res://Player/Sprites/Alex_com_laptop16x16.png")
			
			
	if event.is_action_pressed("use_faca") and inventory.get_item_on_inventary("faca"):
		var faca = inventory.get_item_control("faca")
		faca.set_player(self)
		if usando_faca:
			reset_sprite_player()
		else:
			reset_sprite_player()
			usando_faca = true
			inventory.set_equipped_item("faca")
			$Sprite2D.texture = preload("res://Player/Sprites/Alex_com_faca16x16.png")
			
			
	if event.is_action_pressed("empurrar") and not usando_algum_item():
		if empurrando:
			soltar_objeto()
			empurrando = false
			$Sprite2D.texture = preload("res://Player/Sprites/Alex_16x16.png")
		else:
			empurrando = true
			tentar_pegar_objeto()
			$Sprite2D.texture = preload("res://Player/Sprites/Alex_16x16_empurrando.png")

func _on_animation_player_current_animation_changed(_name: StringName) -> void:
	pass

func put_conhecimento() -> void:
	inteligencia.value += 10

func usando_algum_item() -> bool:
	if usando_arma or usando_cartao or usando_faca or usando_lanterna or usando_laptop or usando_extintor:
		return true
	return false

func get_conhecimento() -> float:
	return inteligencia.value

func tomar_dano(dano: float) -> void:
	if vida_3.value + dano <= 100:
		vida_3.value += dano
		atualizar_estamina_apos_dano()
	else:
		var dano_restante: float = vida_3.value + dano - 100.0
		vida_3.value = 100
		if vida_2.value + dano_restante <= 100:
			vida_2.value += dano_restante
			atualizar_estamina_apos_dano()
		else:
			var dano_restante_2: float = vida_2.value + dano_restante - 100.0
			vida_2.value = 100
			if vida_1.value + dano_restante_2 < 100:
				vida_1.value += dano_restante_2
				atualizar_estamina_apos_dano()
			else:
				vida_1.value = 100
				tela_morreu()

func tela_morreu() -> void:
	get_tree().paused = true
	control.hide()
	morreu.show()
	jogador_morreu.emit()

func get_vida() -> float:
	return 300.0 - (vida_1.value + vida_2.value + vida_3.value)

func atualizar_estamina_apos_dano() -> void:
	cansaco = 1.0 - get_vida() / vida_total
