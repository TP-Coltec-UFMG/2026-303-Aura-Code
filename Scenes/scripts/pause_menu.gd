extends Control

@onready var transition: AnimatedSprite2D = $Transition
@onready var panel_container: PanelContainer = $PanelContainer
@export var player : Player

const AJUSTE_LABEL_GRANDE: float = 6.0
const GRUPO_INTERFACE: String = "interface_escalavel"

var audio_state_before_pause: Dictionary = {}


func _ready() -> void:
	HighContrast.apply_to_tree(self)
	SaveLoad._load()
	var interface_index: int = int(Configs.configs.get("interface_size", 0))
	call_deferred("aplicar_tamanho_interface_por_index", interface_index)
	$AnimationPlayer.play("RESET")
	hide()
	var transparent_panel := StyleBoxEmpty.new()
	$PanelContainer.add_theme_stylebox_override(
		"panel",
		transparent_panel
	)


# ---- A P L I C A  E S C A L A  I N T E R F A C E  ----
func obter_fator_interface(index: int) -> float:
	match index:
		0:
			return 1.0 # Padrão
		1:
			return 0.8 # Pequeno
		2:
			return 1.1 # Grande
		_:
			return 1.0

func aplicar_tamanho_interface_por_index(index: int) -> void:
	var fator: float = obter_fator_interface(index)
	aplicar_tamanho_interface(self, fator, index)

func aplicar_tamanho_interface(node: Node, fator: float, interface_index: int) -> void:
	salvar_valores_originais(node)
	aplicar_escala_node(node, fator, interface_index)

	for child in node.get_children():
		aplicar_tamanho_interface(child, fator, interface_index)

func salvar_valores_originais(node: Node) -> void:
	if node.has_meta("valores_salvos"):
		return

	if node is OptionButton:
		var option_button := node as OptionButton

		var font_size: int = option_button.get_theme_font_size("font_size")
		var pos_y: float = option_button.position.y
		var minimum_size: Vector2 = option_button.custom_minimum_size

		option_button.set_meta("base_font_size", font_size)
		option_button.set_meta("base_position_y", pos_y)
		option_button.set_meta("base_minimum_size", minimum_size)

	elif node is CheckBox:
		var check_box := node as CheckBox

		var font_size: int = check_box.get_theme_font_size("font_size")
		var pos_y: float = check_box.position.y

		check_box.set_meta("base_font_size", font_size)
		check_box.set_meta("base_position_y", pos_y)

	elif node is Button:
		var button := node as Button

		var font_size: int = button.get_theme_font_size("font_size")
		var scale_base: Vector2 = button.scale
		var pos_y: float = button.position.y

		button.set_meta("base_font_size", font_size)
		button.set_meta("base_expand_icon", button.expand_icon)
		button.set_meta("base_scale", scale_base)
		button.set_meta("base_position_y", pos_y)

	elif node is Label:
		var label := node as Label

		var font_size: int = label.get_theme_font_size("font_size")
		var pos_y: float = label.position.y

		label.set_meta("base_font_size", font_size)
		label.set_meta("base_position_y", pos_y)

	elif node is Slider:
		var slider := node as Slider

		var pos_y: float = slider.position.y
		var minimum_size: Vector2 = slider.custom_minimum_size
		var scale_base: Vector2 = slider.scale

		slider.set_meta("base_position_y", pos_y)
		slider.set_meta("base_minimum_size", minimum_size)
		slider.set_meta("base_scale", scale_base)

	elif node is Sprite2D:
		var sprite := node as Sprite2D

		if not sprite.is_in_group(GRUPO_INTERFACE):
			node.set_meta("valores_salvos", true)
			return

		var scale_base: Vector2 = sprite.scale
		var pos_y: float = sprite.position.y

		sprite.set_meta("base_scale", scale_base)
		sprite.set_meta("base_position_y", pos_y)

	elif node is BoxContainer:
		var box := node as BoxContainer

		var pos_y: float = box.position.y
		var minimum_size: Vector2 = box.custom_minimum_size
		var separation: int = box.get_theme_constant("separation")

		box.set_meta("base_position_y", pos_y)
		box.set_meta("base_minimum_size", minimum_size)
		box.set_meta("base_separation", separation)

	node.set_meta("valores_salvos", true)

func aplicar_escala_node(node: Node, fator: float, interface_index: int) -> void:
	if node is OptionButton:
		var option_button := node as OptionButton

		if option_button.has_meta("base_font_size") and option_button.has_meta("base_position_y"):
			var base_font_size: int = int(option_button.get_meta("base_font_size"))
			var base_position_y: float = float(option_button.get_meta("base_position_y"))

			var novo_font_size: int = int(round(base_font_size * fator))
			var diferenca_fonte: int = novo_font_size - base_font_size

			option_button.add_theme_font_size_override("font_size", novo_font_size)

			var nova_posicao: Vector2 = option_button.position
			nova_posicao.y = base_position_y - diferenca_fonte
			option_button.position = nova_posicao

			var popup: PopupMenu = option_button.get_popup()
			if popup != null:
				popup.add_theme_font_size_override("font_size", novo_font_size)

		if option_button.has_meta("base_minimum_size"):
			var base_minimum_size: Vector2 = option_button.get_meta("base_minimum_size")
			option_button.custom_minimum_size = base_minimum_size * fator

	elif node is CheckBox:
		var check_box := node as CheckBox

		if check_box.has_meta("base_font_size") and check_box.has_meta("base_position_y"):
			var base_font_size: int = int(check_box.get_meta("base_font_size"))
			var base_position_y: float = float(check_box.get_meta("base_position_y"))

			var novo_font_size: int = int(round(base_font_size * fator))
			var diferenca_fonte: int = novo_font_size - base_font_size

			check_box.add_theme_font_size_override("font_size", novo_font_size)

			var nova_posicao: Vector2 = check_box.position
			nova_posicao.y = base_position_y - diferenca_fonte
			check_box.position = nova_posicao

	elif node is Button:
		var button := node as Button

		if button.has_meta("base_font_size"):
			var base_font_size: int = int(button.get_meta("base_font_size"))
			var novo_font_size: int = int(round(base_font_size * fator))

			button.add_theme_font_size_override("font_size", novo_font_size)

		if button.has_meta("base_scale"):
			var base_scale: Vector2 = button.get_meta("base_scale")
			button.scale = base_scale * fator

		if button.has_meta("base_position_y"):
			var base_position_y: float = float(button.get_meta("base_position_y"))

			var nova_posicao: Vector2 = button.position
			nova_posicao.y = base_position_y * fator
			button.position = nova_posicao

		if button.has_meta("base_expand_icon"):
			if interface_index == 2:
				if node.is_in_group("Botoes_Controles"):
					button.expand_icon = false
				else:
					button.expand_icon = true
			else:
				button.expand_icon = bool(button.get_meta("base_expand_icon"))

	elif node is Label:
		var label := node as Label

		if label.has_meta("base_font_size") and label.has_meta("base_position_y"):
			var base_font_size: int = int(label.get_meta("base_font_size"))
			var base_position_y: float = float(label.get_meta("base_position_y"))

			var novo_font_size: int = int(round(base_font_size * fator))
			var diferenca_fonte: int = novo_font_size - base_font_size

			if interface_index == 2 and esta_dentro_do_logo(label):
				novo_font_size = base_font_size
				diferenca_fonte = 0

			label.add_theme_font_size_override("font_size", novo_font_size)

			var nova_posicao: Vector2 = label.position
			nova_posicao.y = base_position_y - diferenca_fonte

			if interface_index == 2 and not esta_dentro_do_logo(label):
				nova_posicao.y -= AJUSTE_LABEL_GRANDE

			label.position = nova_posicao

	elif node is Slider:
		var slider := node as Slider

		if slider.has_meta("base_scale"):
			var base_scale: Vector2 = slider.get_meta("base_scale")
			slider.scale = base_scale * fator

		if slider.has_meta("base_minimum_size"):
			var base_minimum_size: Vector2 = slider.get_meta("base_minimum_size")
			slider.custom_minimum_size = base_minimum_size * fator

		if slider.has_meta("base_position_y"):
			var base_position_y: float = float(slider.get_meta("base_position_y"))

			var nova_posicao: Vector2 = slider.position
			nova_posicao.y = base_position_y * fator
			slider.position = nova_posicao

	elif node is Sprite2D:
		var sprite := node as Sprite2D

		if not sprite.is_in_group(GRUPO_INTERFACE):
			return

		if sprite.has_meta("base_scale") and sprite.has_meta("base_position_y"):
			var base_scale: Vector2 = sprite.get_meta("base_scale")
			var base_position_y: float = float(sprite.get_meta("base_position_y"))

			sprite.scale = base_scale * fator

			var nova_posicao: Vector2 = sprite.position
			nova_posicao.y = base_position_y * fator
			sprite.position = nova_posicao

	elif node is BoxContainer:
		var box := node as BoxContainer

		if box.has_meta("base_minimum_size"):
			var base_minimum_size: Vector2 = box.get_meta("base_minimum_size")
			box.custom_minimum_size = base_minimum_size * fator

			
		if box.has_meta("base_separation"):
			var base_separation: int = int(box.get_meta("base_separation"))
			var new_separation: int
			if fator == 1.1:
				@warning_ignore("narrowing_conversion")
				new_separation = base_separation+((base_separation * -1) * 0.1)
			if fator == 0.8:
				@warning_ignore("narrowing_conversion")
				new_separation = base_separation-((base_separation * -1) * 0.2)
			if fator == 1:
				@warning_ignore("narrowing_conversion")
				new_separation = base_separation * fator
			var nova_separation: int = int(round(new_separation))

			box.add_theme_constant_override("separation", nova_separation)

func esta_dentro_do_logo(node: Node) -> bool:
	var atual := node.get_parent()

	while atual != null:
		if atual.name.to_lower() == "logo":
			return true

		atual = atual.get_parent()

	return false
# ------------------------------------------------------
	

func resume():
	get_tree().paused = false
	audio_state_before_pause.clear()
	$AnimationPlayer.play_backwards("blur")
	hide()


func pause():
	# O AudioStreamPlayer pode informar playing=false depois que a SceneTree é
	# pausada. Guardamos antes disso o estado que realmente estava tocando.
	audio_state_before_pause = (
		MusicController.get_checkpoint_state().duplicate(true)
	)
	get_tree().paused = true
	$AnimationPlayer.play("blur")
	show()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("esc"):
		if DialogManager.is_showing_dialog:
			return
		if get_tree().paused:
			resume()
		else:
			pause()

		get_viewport().set_input_as_handled()


func _on_resume_pressed() -> void:
	if get_tree().paused:
		resume()


func _on_restart_pressed() -> void:
	if get_tree().paused:
		resume()
		# Resetar no pause volta ao último checkpoint; o reset completo fica no menu principal.
		SaveGame.load_last_checkpoint()


func _on_options_pressed() -> void:
	if get_tree().paused:
		transition.show()
		transition.play("default")
		#await transition.animation_finished
		$PanelContainer.visible = false
		$Opcoes.visible = true
		$BackgroundMenuOptions.visible = true
		transition.play_backwards("default")
	pass	


func _on_quit_pressed() -> void:
	if get_tree().paused:
		# Salva e silencia no próprio clique. Ao tirar o pause da SceneTree, o
		# Godot pode limpar o stream_paused automático dos AudioStreamPlayers;
		# por isso a fase atual só é removida depois do bloqueio. A SceneTree é
		# reativada quando os nós e áudios locais da fase já saíram da árvore.
		SaveGame.save_current_session(audio_state_before_pause)
		MusicController.pause_all_audio()
		transition.visible = true
		transition.play("default")
		await transition.animation_finished

		var scene_tree := get_tree()
		var erro := scene_tree.change_scene_to_file(
			"res://Scenes/principal.tscn"
		)

		if erro != OK:
			MusicController.allow_scene_audio()
			resume()
			push_error("Não foi possível voltar ao menu principal.")
			return

		# Não use resume() antes da troca: ele reativava por um frame todos os
		# AudioStreamPlayers locais da fase que estava sendo encerrada.
		scene_tree.paused = false
		MusicController.pause_all_audio()


# ---- M E N U  O P C O E S  ----
func _on_back_to_menu_button_pressed() -> void:
	SaveLoad.save_data = Configs.configs
	SaveLoad._save()
	transition.play("default")
	await transition.animation_finished
	$PanelContainer.visible = true
	$ColorRect.visible = true
	$Opcoes.visible = false
	$BackgroundMenuOptions.visible = false
	transition.play_backwards("default")

func _on_menu_sounds_settings_pressed() -> void:
	transition.play("default")
	await transition.animation_finished
	$Opcoes.visible = false
	$SettingSound.visible = true
	transition.play_backwards("default")

func _on_menu_controllers_pressed() -> void:
	transition.play("default")
	await transition.animation_finished
	$Opcoes.visible = false
	$Controles.visible = true
	transition.play_backwards("default")

func _on_menu_interface_pressed() -> void:
	transition.play("default")
	await transition.animation_finished
	$Opcoes.visible = false
	$Interface.visible = true
	transition.play_backwards("default")

func _on_menu_acessibilidadades_pressed() -> void:
	transition.play("default")
	await transition.animation_finished
	$Opcoes.visible = false
	$Accessibility.visible = true
	transition.play_backwards("default")
# --------------------------------


# ---- M E N U  V O L U M E  ----
func _on_back_to_menu_button_pressed_on_settings_sounds() -> void:
	transition.play("default")
	await transition.animation_finished
	$Opcoes.visible = true
	$SettingSound.visible = false
	transition.play_backwards("default")


# ---- M E N U  I N T E R F A C E  ----
func _on_back_to_menu_button_pressed_on_interface_menu() -> void:
	transition.play("default")
	await transition.animation_finished
	$Opcoes.visible = true
	$Interface.visible = false
	transition.play_backwards("default")

func _on_options_interface_size_item_selected(index: int) -> void:
	aplicar_tamanho_interface_por_index(index)


# ---- M E N U  A C E S S I B I L I D A D E S  ----
func _on_back_to_menu_button_pressed_on_acessibility() -> void:
	transition.play("default")
	await transition.animation_finished
	$Opcoes.visible = true
	$Accessibility.visible = false
	transition.play_backwards("default")


# --- MENU CONTROLES ---
func _on_back_to_menu_button_pressed_controles() -> void:
	transition.play("default")
	await transition.animation_finished
	$Opcoes.visible = true
	$Controles.visible = false
	transition.play_backwards("default")
