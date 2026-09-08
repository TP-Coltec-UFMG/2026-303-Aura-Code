extends Node2D
## O mesmo raycast recorta o cone e verifica cobertura. Só paredes, camada 1.
@export var angulo_inicial: float = 90.0
@export var angulo_final: float = 180.0
@export var duracao_giro: float = 2.8
@export var intermitente: bool = false
@export var ligado_por: float = 2.2
@export var desligado_por: float = 1.5
@export var defasagem: float = 0.0
@export var alcance: float = 155.0
@export var abertura: float = 20.0
var tempo: float = 0.0
var ativo: bool = false
var aviso: bool = false
var alerta: bool = false
var pontos := PackedVector2Array()
var jogador: CharacterBody2D
const AQUECIMENTO := 0.65

func _ready() -> void:
	add_to_group("sensores")
	jogador = get_tree().get_first_node_in_group("jogador")

func _physics_process(delta: float) -> void:
	tempo += delta
	if not alerta:
		atualizar_estado(tempo)
		recortar_cone()
		if ativo and is_instance_valid(jogador) and pode_ver(jogador.global_position):
			alerta = true
			jogador.detectar()
	queue_redraw()

func atualizar_estado(t: float) -> void:
	if intermitente:
		rotation = deg_to_rad(angulo_inicial)
		var ciclo := fposmod(t + defasagem, ligado_por + desligado_por + AQUECIMENTO)
		aviso = ciclo >= desligado_por and ciclo < desligado_por + AQUECIMENTO
		ativo = ciclo >= desligado_por + AQUECIMENTO
	else:
		# Pausa curta nas pontas para o jogador ler o padrão.
		var periodo := duracao_giro + 0.7
		var ciclo := fposmod(t + defasagem, periodo * 2.0)
		var ida := ciclo < periodo
		var fra := clampf(fposmod(ciclo, periodo) / duracao_giro, 0.0, 1.0)
		rotation = deg_to_rad(lerpf(angulo_inicial, angulo_final, fra if ida else 1.0 - fra))
		ativo = t > AQUECIMENTO
		aviso = not ativo

func raio_ate(destino: Vector2) -> Vector2:
	var consulta := PhysicsRayQueryParameters2D.create(global_position, destino, 1)
	var resultado := get_world_2d().direct_space_state.intersect_ray(consulta)
	return resultado.position if not resultado.is_empty() else destino

func pode_ver(ponto: Vector2) -> bool:
	if not ativo:
		return false
	var local := to_local(ponto)
	if local.length() > alcance or local.length() < 3.0:
		return false
	if absf(Vector2.UP.angle_to(local)) > deg_to_rad(abertura):
		return false
	return raio_ate(ponto).distance_to(ponto) < 1.0

func recortar_cone() -> void:
	var novos_pontos := PackedVector2Array([Vector2.ZERO])
	for n in range(49):
		var a := deg_to_rad(lerpf(-abertura, abertura, n / 48.0))
		var destino := to_global(Vector2.UP.rotated(a) * alcance)
		var pt_local := to_local(raio_ate(destino))
		
		# Ignora vértices duplicados ou extremamente próximos do último inserido
		if pt_local.distance_squared_to(novos_pontos[-1]) > 0.1:
			novos_pontos.append(pt_local)

	pontos = novos_pontos

func _draw() -> void:
	if (ativo or aviso) and pontos.size() >= 3:
		var cor := VisualAsimov.AMARELO if aviso else VisualAsimov.VERMELHO
		cor.a = 0.14 if aviso else 0.27
		draw_colored_polygon(pontos, cor)
		cor.a = 0.5
		draw_line(Vector2.ZERO, pontos[1], cor, 1)
		draw_line(Vector2.ZERO, pontos[-1], cor, 1)
	var frame := 3 if alerta else (2 if ativo else (1 if aviso else 0))
	draw_texture_rect(VisualAsimov.quadro(1, frame), Rect2(-17, -17, 34, 34), false)
